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

  Future<void> check() async {
    if (!_supported) {
      _set(UpdateState.none);
      return;
    }
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        _set(UpdateState.none);
        return;
      }
      // 우선순위가 높은 릴리스는 막고 간다. Play Console에서 정한 값이다.
      if (info.immediateUpdateAllowed && (info.updatePriority) >= 4) {
        _set(UpdateState.immediate);
        await InAppUpdate.performImmediateUpdate();
        return;
      }
      _set(info.flexibleUpdateAllowed ? UpdateState.flexible : UpdateState.none);
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
      await InAppUpdate.startFlexibleUpdate();
      _set(UpdateState.readyToInstall);
    } catch (e) {
      debugPrint('업데이트 내려받기 실패: $e');
      _set(UpdateState.flexible);
    }
  }

  /// 카드는 Play가 있는 실기기에서만 뜬다. 상태별 렌더를 확인하려면 직접 세운다.
  @visibleForTesting
  void debugSet(UpdateState s) => _set(s);

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
