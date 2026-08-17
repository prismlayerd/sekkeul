import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:secul/core/update_service.dart';

/// **Play가 준 정보를 어떤 화면 상태로 옮기는가.**
///
/// 이 판단은 Play 스토어가 있는 실기기에서만 돌아서 눈으로 볼 수가 없다.
/// 틀리면 조용히 틀린다 — 다 받아 둔 업데이트가 영영 설치되지 않는 식으로.
/// 그래서 판단만 순수 함수로 떼어내 여기서 붙잡는다.
void main() {
  AppUpdateInfo info({
    required UpdateAvailability availability,
    InstallStatus status = InstallStatus.unknown,
    bool flexible = true,
    bool immediate = true,
    int priority = 0,
  }) =>
      AppUpdateInfo(
        updateAvailability: availability,
        immediateUpdateAllowed: immediate,
        immediateAllowedPreconditions: null,
        flexibleUpdateAllowed: flexible,
        flexibleAllowedPreconditions: null,
        availableVersionCode: 10,
        installStatus: status,
        packageName: 'com.sekkeul.app',
        clientVersionStalenessDays: 1,
        updatePriority: priority,
      );

  test('받아만 두고 안 깐 업데이트를 놓치지 않는다', () {
    // 다 받고 재시작 전에 앱을 닫은 경우. Play는 updateAvailable이 아니라
    // developerTriggeredUpdateInProgress로 알려준다. 예전에는 이걸
    // "업데이트 없음"으로 흘려서 받아 둔 파일이 영영 안 깔렸다.
    expect(
      UpdateService.stateFor(info(
        availability: UpdateAvailability.developerTriggeredUpdateInProgress,
        status: InstallStatus.downloaded,
      )),
      UpdateState.readyToInstall,
    );
  });

  test('받는 중이면 받는 중으로 이어 그린다', () {
    for (final s in [InstallStatus.downloading, InstallStatus.pending]) {
      expect(
        UpdateService.stateFor(info(
          availability: UpdateAvailability.developerTriggeredUpdateInProgress,
          status: s,
        )),
        UpdateState.downloading,
        reason: '$s',
      );
    }
  });

  test('최신이면 아무것도 안 띄운다', () {
    expect(
      UpdateService.stateFor(
          info(availability: UpdateAvailability.updateNotAvailable)),
      UpdateState.none,
    );
  });

  test('우선순위 4 이상은 막고 간다', () {
    expect(
      UpdateService.stateFor(info(
          availability: UpdateAvailability.updateAvailable, priority: 4)),
      UpdateState.immediate,
    );
  });

  test('우선순위를 안 넣으면(0) 카드로만 뜬다', () {
    // 이게 지금 실제로 올라가는 모든 릴리스의 모습이다 —
    // inAppUpdatePriority는 Play Console 화면에 없고 Developer API로만 들어간다.
    // 콘솔에서 손으로 올리는 한 이 값은 늘 0이라 immediate는 절대 안 뜬다.
    expect(
      UpdateService.stateFor(
          info(availability: UpdateAvailability.updateAvailable)),
      UpdateState.flexible,
    );
  });

  test('flexible이 막혀 있으면 카드도 안 띄운다', () {
    // 띄워 봐야 눌렀을 때 아무 일도 안 일어난다.
    expect(
      UpdateService.stateFor(info(
          availability: UpdateAvailability.updateAvailable,
          flexible: false,
          immediate: false)),
      UpdateState.none,
    );
  });
}
