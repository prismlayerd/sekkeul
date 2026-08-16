import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/screen_registry.dart';

/// 달력을 **돌아다녀도** 죽지 않는다.
///
/// 칸마다 붙는 GlobalKey를 달 단위로 재사용하게 바꿨다(매 프레임 새로 만들던
/// 것을 고치면서). GlobalKey는 붙은 요소를 통째로 옮기는 물건이라, 달을
/// 넘기거나 확대할 때 잘못 얽히면 `_dependents.isEmpty` 단언에서 죽는다.
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
    await t.pumpAndSettle(const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
  }

  testWidgets('달 넘기기와 확대를 섞어도 죽지 않는다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    final now = DateTime.now();
    await dbService.insertExpense(ExpenseItem(
        id: 'e1', date: now, amount: 12000, content: '김밥',
        category: '음식/배달', paymentMethod: '신용카드', userType: '직장인'));

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const ExpenseCalendarScreen(),
    ));
    await t.pumpAndSettle();

    // 확대 → 달 넘김 → 축소 → 달 넘김. 키를 비우는 시점과 확대가 겹친다.
    await pinchOut(t);
    expect(t.takeException(), isNull, reason: '확대 중에 죽었다');

    for (var i = 0; i < 3; i++) {
      await t.tap(find.byTooltip('다음달'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '다음달로 넘기다 죽었다');
    }

    await pinchOut(t);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byTooltip('지난달'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '지난달로 넘기다 죽었다');
    }
  });
}
