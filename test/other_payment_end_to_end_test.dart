import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/day_entry_screen.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **'기타'로 적은 지출이 적은 그대로 보인다.**
///
/// 하루 입력에서 결제수단을 기타로 골라 저장한 뒤, 달력 칸과 홈 02에 그대로
/// 나타나는지 끝까지 태워 본다. 어느 한 곳이라도 문자열이 어긋나면 기록은
/// 저장돼 있는데 화면에서만 사라진다 — 사용자에게는 "안 적힌 것"으로 보인다.
void main() {
  testWidgets('기타로 저장하면 저장까지 간다', (t) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();

    final day = DateTime(2026, 8, 20);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: DayEntryScreen(
        dates: {day},
        userType: '직장인',
        incomesByDay: const {},
        expensesByDay: const {},
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(findKo('지출 추가하기'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '12000');
    await t.pumpAndSettle();

    // 결제수단 칸에서 '기타'를 고른다.
    await t.tap(findKo('기타').last);
    await t.pumpAndSettle();
    await t.tap(findKo('저장'));
    await t.pumpAndSettle();

    final saved = await dbService.getExpenses();
    expect(saved.length, 1);
    expect(saved.single.paymentMethod, '기타',
        reason: '기타를 골랐는데 다른 결제수단으로 저장됐다');
  });

  testWidgets('기타 기록이 달력 칸에 뜬다', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();

    final now = DateTime.now();
    await dbService.insertExpense(ExpenseItem(
      id: 'o1',
      date: now,
      amount: 12000,
      content: '',
      category: '기타',
      paymentMethod: '기타',
      userType: '직장인',
    ));

    await t.pumpWidget(const MaterialApp(home: ExpenseCalendarScreen()));
    await t.pumpAndSettle();

    // 확대해야 금액 줄이 뜬다. 그 전에는 도형만 찍힌다.
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

    expect(findKo('12,000'), findsWidgets,
        reason: '기타로 적은 금액이 달력 칸에 안 뜬다');
  });
}
