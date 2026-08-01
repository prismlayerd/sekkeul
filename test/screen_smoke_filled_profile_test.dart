import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/screen_registry.dart';

/// **채워진 프로필 + 3개월 가계부로 모든 화면을 연다. 예외가 나면 실패한다.**
///
/// 넘침 전수검사(`small_screen_overflow_test.dart`)는 화면이 못 뜨는 걸 일부러
/// 삼킨다 — 그쪽 관심사가 레이아웃이라서다. 그래서 「프로필을 저장한 사용자
/// 전원이 겪는 크래시」가 297개 테스트를 통과한 채로 알파 트랙까지 나갔다
/// (`bool` 값을 `as int?`로 캐스팅 → TypeError, 빈 프로필에서는 null이라 무사통과).
///
/// 여기서는 반대로 **예외를 전부 실패로 본다.** 레이아웃 넘침만 넘긴다.
bool _isLayoutOnly(Object e) {
  final s = e.toString();
  return s.contains('overflowed') ||
      s.contains('RenderFlex') ||
      // ListTile을 DecoratedBox로 감쌌을 때 나오는 잉크 경고 — 그리기 힌트다.
      s.contains('ink splashes may be invisible');
}

void main() {
  // 프로덕션은 NotificationHelper.init()에서 타임존을 초기화한다. 테스트가 그걸
  // 안 따라하면 예약 알림 경로가 tz.local에서 터져 화면 검사가 아니라 환경을 본다.
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  final problems = <String>[];
  String current = '';

  void install() {
    FlutterError.onError = (d) {
      if (_isLayoutOnly(d.exception)) return;
      final line = '$current — ${d.exception}';
      if (!problems.contains(line)) problems.add(line);
    };
  }

  Future<void> open(WidgetTester t, Widget w) async {
    try {
      await t.pumpWidget(MaterialApp(home: w));
      for (int i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }
    } catch (e) {
      if (!_isLayoutOnly(e)) {
        final line = '$current — $e';
        if (!problems.contains(line)) problems.add(line);
      }
    }
    final taken = t.takeException();
    if (taken != null && !_isLayoutOnly(taken)) {
      final line = '$current — $taken';
      if (!problems.contains(line)) problems.add(line);
    }
  }

  testWidgets('채워진 프로필로 전 화면이 예외 없이 뜬다', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final old = FlutterError.onError;
    addTearDown(() => FlutterError.onError = old);

    problems.clear();

    // 인자 없는 화면 — 유형은 프로필에서 읽으므로 3유형 모두 돌린다.
    for (final userType in ['직장인', '프리랜서', 'N잡러']) {
      for (final (name, build) in noArgScreens) {
        current = '$name($userType)';
        await seedRealisticUser(userType);
        install();
        await open(t, build());
      }
      for (final (name, build) in byTypeScreens) {
        current = '$name($userType)';
        await seedRealisticUser(userType);
        install();
        await open(t, build(userType));
      }
    }
    FlutterError.onError = old;

    for (final p in problems) {
      // ignore: avoid_print
      print('  ✕ $p');
    }
    final total = (noArgScreens.length + byTypeScreens.length) * 3;
    // ignore: avoid_print
    print('채워진 프로필로 연 화면 $total개 · 예외 ${problems.length}건');
    expect(problems, isEmpty, reason: '실제 사용자 프로필에서 화면이 죽는다');
  });

  testWidgets('빈 프로필에서도 전 화면이 예외 없이 뜬다', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final old = FlutterError.onError;
    addTearDown(() => FlutterError.onError = old);

    problems.clear();

    // 설치 직후(프로필 저장 전) — 반대쪽 극단. 여기만 보다가 위쪽을 놓쳤었다.
    for (final userType in ['직장인', '프리랜서', 'N잡러']) {
      for (final (name, build) in byTypeScreens) {
        current = '$name($userType) 빈프로필';
        dbService = InMemoryDatabaseHelper();
        await dbService.initDatabase();
        install();
        await open(t, build(userType));
      }
    }
    FlutterError.onError = old;

    for (final p in problems) {
      // ignore: avoid_print
      print('  ✕ $p');
    }
    // ignore: avoid_print
    print('빈 프로필로 연 화면 ${byTypeScreens.length * 3}개 · 예외 ${problems.length}건');
    expect(problems, isEmpty, reason: '프로필이 없는 첫 실행에서 화면이 죽는다');
  });
}
