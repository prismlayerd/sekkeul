import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/screen_registry.dart';

/// 작은 화면(360×800 — 갤럭시 S/아이폰 SE급)에서 화면이 넘치는 곳을 전수로 찾는다.
///
/// 오버플로는 실기기에서 노란·검정 줄무늬로 보이고, 잘린 쪽 글자는 아예 읽을 수 없다.
/// 개발용 큰 화면에서는 절대 드러나지 않아 눈으로는 못 잡는다.
void main() {
  // 프로덕션은 NotificationHelper.init()에서 타임존을 초기화한다. 안 맞춰 두면
  // 예약 알림 경로가 tz.local에서 터져 레이아웃이 아니라 환경을 보게 된다.
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  // 루트 키를 매번 바꿔 State 재사용을 막는다 — 같은 타입이 연이어 오면
  // initState가 다시 돌지 않아 앞 화면 상태로 검사하게 된다.
  int seq = 0;
  final screens = noArgScreens;

  testWidgets('360×800에서 넘치는 화면이 없다', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    final problems = <String>[];
    String current = '';
    // 오버플로만 걷어 담고 나머지는 삼킨다. 테스트 환경에는 알림 플러그인 같은
    // 네이티브 채널이 없어서 화면마다 무관한 비동기 예외가 딸려 나온다.
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exception.toString();
      if (!s.contains('overflowed')) return;
      final where =
          RegExp(r'(\w+_screen\.dart|\w+\.dart):(\d+)').firstMatch(d.toString());
      final line = '$current — ${s.split('.').first} @ ${where?.group(0) ?? '?'}';
      if (!problems.contains(line)) problems.add(line);
    };
    addTearDown(() => FlutterError.onError = old);

    for (final (name, build) in screens) {
      current = name;
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
      try {
        await t.pumpWidget(MaterialApp(key: ValueKey('pump-${seq++}'), home: build()));
        await t.pump(const Duration(milliseconds: 400));
        await t.pump(const Duration(milliseconds: 400));
      } catch (_) {
        // 화면 자체가 못 뜨는 건 이 테스트의 관심사가 아니다.
      }
      t.takeException();
    }
    FlutterError.onError = old;

    for (final p in problems) {
      // ignore: avoid_print
      print('넘침: $p');
    }
    // ignore: avoid_print
    print('검사한 화면 ${screens.length}개 · 넘친 곳 ${problems.length}건');
    expect(problems, isEmpty, reason: '작은 화면에서 잘리는 곳이 있다');
  });

  testWidgets('유형별 화면도 360×800에서 넘치지 않는다', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    // userType 하나만 받는 화면들 — 인자가 있다는 이유로 지금까지 한 번도
    // 열어 본 적이 없었다. 이모지가 섞인 문구에서 렌더링이 죽던 버그도 여기 있었다.
    final byType = byTypeScreens;

    final problems = <String>[];
    String current = '';
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exception.toString();
      final isOverflow = s.contains('overflowed');
      final isUtf16 = s.contains('not well-formed UTF-16');
      if (!isOverflow && !isUtf16) return;
      final where =
          RegExp(r'(\w+_screen\.dart|\w+\.dart):(\d+)').firstMatch(d.toString());
      final line = '$current — ${s.split('.').first} @ ${where?.group(0) ?? '?'}';
      if (!problems.contains(line)) problems.add(line);
    };
    addTearDown(() => FlutterError.onError = old);

    // 빈 상태로만 훑으면 **데이터가 있을 때만 나타나는 넘침**을 통째로 놓친다.
    // 실제로 '카드 공제 문턱 (연봉의 25%)' + '12,500,000원 남음'이 한 줄에 안 들어가
    // 60px 넘치던 것을 이 시드가 없어서 못 잡고 있었다.
    for (final userType in ['직장인', '프리랜서', 'N잡러']) {
      for (final (name, build) in byType) {
        current = '$name($userType)';
        await seedRealisticUser(userType);
        try {
          await t.pumpWidget(MaterialApp(key: ValueKey('pump-${seq++}'), home: build(userType)));
          await t.pump(const Duration(milliseconds: 400));
          await t.pump(const Duration(milliseconds: 400));
        } catch (_) {
          // 화면이 못 뜨는 건 이 테스트의 관심사가 아니다.
        }
        t.takeException();
      }
    }
    FlutterError.onError = old;

    for (final p in problems) {
      // ignore: avoid_print
      print('넘침: $p');
    }
    // ignore: avoid_print
    print('유형별 화면 ${byType.length}개 × 3유형 · 문제 ${problems.length}건');
    expect(problems, isEmpty, reason: '작은 화면에서 잘리거나 렌더링이 죽는 곳이 있다');
  });
}
