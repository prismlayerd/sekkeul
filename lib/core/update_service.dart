import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// **Play가 새 버전을 갖고 있는지 묻고, 앱 안에서 받아 설치한다.**
///
/// 세끌은 서버가 없어서 "세법이 바뀌었다"를 사용자에게 알릴 길이 앱 업데이트뿐이다.
/// 그런데 Play 자동 업데이트는 꺼져 있을 수 있고, 켜져 있어도 며칠 걸린다.
/// 이 API는 **자동 업데이트 설정과 무관하게** 동작한다.
///
/// 두 방식 중 어느 쪽으로 뜰지는 코드가 아니라 **업로드할 때 Play Console에서**
/// 정한다(`inAppUpdatePriority` 0~5). 세법·복지 값이 바뀐 릴리스에 높은 우선순위를
/// 주면 [UpdateState.immediate]로, 그 밖에는 [UpdateState.flexible]로 온다.
///
/// Google이 그리는 대화상자는 문구가 "업데이트 사용 가능"으로 고정이라 **왜**
/// 지금 해야 하는지는 말해주지 않는다. 이유는 우리 카드가 말한다.
enum UpdateState {
  /// 확인 전이거나 확인 중.
  unknown,

  /// 최신이거나, 이 플랫폼에서는 확인할 수 없다(웹·iOS·개발 빌드).
  none,

  /// 받아둘 수 있는 업데이트가 있다 — 카드를 띄운다.
  flexible,

  /// 옛 버전을 쓰면 안 되는 업데이트다 — 전체 화면으로 막는다.
  immediate,

  /// 내려받는 중.
  downloading,

  /// 다 받았다 — 재시작만 하면 된다.
  readyToInstall,
}

class UpdateService extends ChangeNotifier {
  UpdateState _state = UpdateState.unknown;
  UpdateState get state => _state;

  /// 이 업데이트가 **세법·복지 기준이 바뀐 릴리스**인가.
  ///
  /// 우리가 올릴 때 손으로 붙이는 우선순위(`tool/play_publish.py --priority`)를
  /// 그대로 읽는다. 예전에는 카드가 무슨 업데이트든 "세법·복지 기준이 바뀐
  /// 버전이 있어요"라고 말했다 — 테마만 바꾼 릴리스에도 그렇게 말해서,
  /// 급하게 받은 사용자가 세법은 그대로인 걸 보게 됐다. 세금 앱에서 그 거짓말은
  /// 다음번에 진짜 세법이 바뀌었을 때 안 믿게 만든다.
  bool _taxUpdate = false;
  bool get isTaxUpdate => _taxUpdate;

  bool get hasUpdate =>
      _state == UpdateState.flexible ||
      _state == UpdateState.downloading ||
      _state == UpdateState.readyToInstall;

  void _set(UpdateState s) {
    if (_state == s) return;
    _state = s;
    notifyListeners();
  }

  /// Play 스토어로 설치된 Android 앱에서만 동작한다.
  /// 웹·에뮬레이터·`flutter run` 빌드에서는 조용히 [UpdateState.none]으로 끝난다 —
  /// 로컬에서 확인이 안 되는 종류라 실패를 오류로 취급하지 않는다.
  static bool get _supported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Play가 준 정보를 화면 상태로 옮긴다.
  ///
  /// 판단만 하고 아무것도 실행하지 않는 순수 함수로 뺐다 — 이 결정이 틀리면
  /// 다 받아 둔 업데이트가 영영 설치되지 않는데, 실기기에서만 도는 코드라
  /// 눈으로 확인할 방법이 없어서다. 테스트가 대신 본다.
  @visibleForTesting
  static UpdateState stateFor(AppUpdateInfo info) {
    // **이미 받아 두고 설치 전에 앱을 닫은 경우.**
    //
    // Play는 이 상태를 `updateAvailable`이 아니라
    // `developerTriggeredUpdateInProgress`로 알려준다. 예전에는 이 값을
    // "업데이트 없음"으로 흘려보냈다. 그래서 사용자가 다 받아 놓고 재시작 전에
    // 앱을 닫으면, 다음에 켰을 때 카드가 사라지고 받아 둔 파일은 영영 설치되지
    // 않았다. 받는 데 든 데이터만 버린 셈이다.
    if (info.updateAvailability ==
        UpdateAvailability.developerTriggeredUpdateInProgress) {
      return switch (info.installStatus) {
        InstallStatus.downloaded => UpdateState.readyToInstall,
        InstallStatus.downloading || InstallStatus.pending =>
          UpdateState.downloading,
        _ => UpdateState.none,
      };
    }
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return UpdateState.none;
    }
    // 우선순위가 높은 릴리스는 막고 간다.
    //
    // 이 값은 **Play Console 화면에서 못 정한다.** Developer API의
    // `Edits.tracks.releases.inAppUpdatePriority`로만 들어가고, 안 넣으면 0이다.
    // 콘솔에서 손으로 올리는 동안에는 이 가지가 한 번도 참이 되지 않는다.
    if (info.immediateUpdateAllowed && info.updatePriority >= 4) {
      return UpdateState.immediate;
    }
    return info.flexibleUpdateAllowed ? UpdateState.flexible : UpdateState.none;
  }

  Future<void> check() async {
    if (!_supported) {
      _set(UpdateState.none);
      return;
    }
    try {
      final info = await InAppUpdate.checkForUpdate();
      _taxUpdate = info.updatePriority >= 4;
      final next = stateFor(info);
      _set(next);
      if (next == UpdateState.immediate) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      // Play가 없거나 서명이 다른 빌드다. 사용자에게 보일 일이 아니다.
      debugPrint('업데이트 확인 실패: $e');
      _set(UpdateState.none);
    }
  }

  /// 카드를 눌렀을 때 — 앱을 나가지 않고 백그라운드로 받는다.
  Future<void> download() async {
    if (_state != UpdateState.flexible) return;
    _set(UpdateState.downloading);
    try {
      // **거절은 예외로 오지 않는다.** 결과값을 안 보고 넘기면, 사용자가
      // Google 대화상자에서 「나중에」를 눌러도 카드가 「새 버전을 받았어요」로
      // 바뀐다. 그걸 누르면 설치가 조용히 실패하는 막다른 길이 된다.
      final r = await InAppUpdate.startFlexibleUpdate();
      _set(r == AppUpdateResult.success
          ? UpdateState.readyToInstall
          : UpdateState.flexible);
    } catch (e) {
      debugPrint('업데이트 내려받기 실패: $e');
      _set(UpdateState.flexible);
    }
  }

  /// 카드는 Play가 있는 실기기에서만 뜬다. 상태별 렌더를 확인하려면 직접 세운다.
  @visibleForTesting
  void debugSet(UpdateState s, {bool tax = false}) {
    _taxUpdate = tax;
    _set(s);
  }

  @visibleForTesting
  void reset() => _set(UpdateState.unknown);

  /// 재시작하고 설치한다.
  Future<void> install() async {
    if (_state != UpdateState.readyToInstall) return;
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('업데이트 설치 실패: $e');
    }
  }
}

/// 앱 전역에서 하나만 쓴다. 홈이 구독한다.
final updateService = UpdateService();
