import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/screen_registry.dart';

/// 확대해도 달력이 **멈춘다**.
///
/// 프레임이 계속 잡히면 화면은 멀쩡해 보여도 배터리를 먹고 스크롤이 끊긴다.
/// 실기기 제보("가계부가 유독 버벅인다")와 같은 증상이다.
void main() {
  Future<void> pinchOut(WidgetTester t) async {
    final center = t.getCenter(find.byType(ExpenseCalendarScreen));
    final a = await t.startGesture(center - const Offset(30, 0));
    final b = await t.startGesture(center + const Offset(30, 0));
    await t.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 6; i++) {
      await a.moveBy(const Offset(-14, 0));
      await b.moveBy(const Offset(14, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
  }

  testWidgets('확대 단계마다 애니메이션이 끝난다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const ExpenseCalendarScreen(),
    ));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 1));
    expect(t.binding.hasScheduledFrame, isFalse,
        reason: '아무것도 안 했는데 프레임이 계속 잡힌다');

    for (var step = 2; step <= 3; step++) {
      await pinchOut(t);
      // 확대하면 칸 31개가 저마다 페이드한다 — 티커가 62개 붙는다.
      // 짧지만(180ms) 한 번에 다 도는 건 중저가 기기에서 눈에 띈다.
      await t.pumpAndSettle(const Duration(milliseconds: 16),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      expect(t.binding.hasScheduledFrame, isFalse,
          reason: '$step단계 전환이 5초 안에 안 끝난다');
    }
  });
}
