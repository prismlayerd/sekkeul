import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/ui/screens/day_entry_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// 편집기를 **연달아 옮겨 다녀도** 죽지 않는다.
///
/// 저장·삭제 버튼을 화면 아래로 내리면서 폼에 GlobalKey를 달았다(아래 버튼이
/// 열려 있는 폼을 불러야 해서). GlobalKey가 붙은 위젯이 목록 안에서 자리를
/// 옮기면 프레임워크가 그 요소를 통째로 옮기는데, 잘못 얽히면
/// `_dependents.isEmpty` 단언에서 앱이 죽는다 — 실기기에서 빨간 화면을 봤다.
void main() {
  testWidgets('수익↔지출 편집기를 옮겨 다녀도 죽지 않는다', (t) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();

    final day = DateTime(2026, 8, 10);
    final incomes = [
      IncomeEntry(
          id: 'i1', date: day, amount: 300000, memo: '강의료',
          incomeType: '기타소득', userType: '직장인'),
    ];
    final expenses = [
      ExpenseItem(
          id: 'e1', date: day, amount: 12000, content: '김밥',
          category: '음식/배달', paymentMethod: '신용카드', userType: '직장인'),
      ExpenseItem(
          id: 'e2', date: day, amount: 3400, content: '버스',
          category: '교통', paymentMethod: '체크+현금', userType: '직장인'),
    ];
    for (final e in incomes) {
      await dbService.insertIncomeEntry(e);
    }
    for (final e in expenses) {
      await dbService.insertExpense(e);
    }

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: DayEntryScreen(
        dates: {day},
        userType: '직장인',
        incomesByDay: {'2026-08-10': incomes},
        expensesByDay: {'2026-08-10': expenses},
      ),
    ));
    await t.pumpAndSettle();

    // 목록의 여러 줄을 번갈아 연다 — 폼이 목록 안에서 자리를 옮겨 다닌다.
    for (final title in ['김밥', '버스', '강의료', '김밥']) {
      await t.tap(findKo(title));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '$title 편집기를 여는 중에 죽었다');
    }

    // 추가 칸으로도 옮겨 본다(id → 'exp' → 'inc').
    await t.tap(findKo('취소'));
    await t.pumpAndSettle();
    await t.tap(findKo('지출 추가하기'));
    await t.pumpAndSettle();
    await t.tap(findKo('취소'));
    await t.pumpAndSettle();
    await t.tap(findKo('수익 추가하기'));
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
  });
}
