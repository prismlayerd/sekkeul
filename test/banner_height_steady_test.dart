import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/home/home_status_section.dart';
import 'package:secul/ui/screens/home_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/screen_registry.dart';

/// **배너가 돌아도 아래가 움직이면 안 된다.**
///
/// 6초마다 카드가 바뀔 때 그 아래 절취선부터 화면 전체가 위아래로 들썩였다.
/// 읽고 있던 줄이 손 밑에서 도망간다.
///
/// 카드 높이를 눈으로 맞추는 건 이미 두 번 실패했다. 여기서는 **아래 것의
/// 위치를 직접 재서** 붙잡는다 — 원인이 무엇이든 이 값이 흔들리면 실패다.
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  testWidgets('카드가 넘어가도 아래 절취선이 제자리다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    ));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }

    // 배너 아래에 있는 첫 덩어리. 배너가 커지거나 작아지면 이게 따라 움직인다.
    double belowY() => t.getTopLeft(find.byType(HomeStatusSection)).dy;

    final ticks = find.bySemanticsLabel(RegExp(r'^\d+번째 소식$'));
    final count = ticks.evaluate().length;
    expect(count, greaterThan(1), reason: '돌아갈 카드가 없으면 이 테스트는 의미가 없다');

    final seen = <int, double>{0: belowY()};
    for (var i = 1; i < count; i++) {
      await t.tap(ticks.at(i));
      // 카드 전환은 500ms 페이드다. 전환 **도중에도** 움직이면 안 되므로
      // 중간과 끝을 둘 다 본다 — 예전에 AnimatedSize가 여기서 늘었다 줄었다.
      await t.pump(const Duration(milliseconds: 250));
      final mid = belowY();
      await t.pump(const Duration(milliseconds: 400));
      seen[i] = belowY();
      expect(mid, seen[0],
          reason: '$i번째 카드로 넘어가는 **도중**에 아래가 ${mid - seen[0]!}픽셀 움직였다');
    }

    final moved = seen.entries.where((e) => e.value != seen[0]).toList();
    expect(moved, isEmpty,
        reason: '카드마다 아래 위치가 다르다 (0번=${seen[0]}):\n'
            '${moved.map((e) => '  ${e.key}번째 → ${e.value} (${e.value - seen[0]!}픽셀)').join('\n')}');
  });
}
