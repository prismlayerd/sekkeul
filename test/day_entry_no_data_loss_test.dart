import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/day_entry_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **하루 입력이 그날의 다른 기록을 지우지 않는다.**
///
/// 예전 입력 화면은 저장할 때 그날 기록을 **전부 삭제하고** 고정 4칸을 다시
/// 넣었다. 그래서 고정지출·문자 불러오기 등 다른 경로로 들어온 기록이 그날을
/// 한 번 열었다 저장하는 것만으로 조용히 사라졌다.
///
/// 목록형으로 바꾸면서 그 경로를 없앴는데, 없앤 걸 코드 읽기로만 확인하면
/// 나중에 누가 "일괄 저장"을 다시 붙일 때 아무도 못 막는다. 이 테스트가 막는다.
void main() {
  ExpenseItem seed(String id, int amount, String category) => ExpenseItem(
        id: id,
        date: DateTime(2026, 8, 10),
        amount: amount,
        content: '',
        category: category,
        paymentMethod: '신용카드',
        userType: '직장인',
      );

  testWidgets('지출을 추가해도 그날의 기존 기록이 남아 있다', (t) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();

    // 다른 경로로 이미 들어와 있던 기록 두 건.
    final existing = [seed('pre_1', 12000, '식비'), seed('pre_2', 3400, '교통')];
    for (final e in existing) {
      await dbService.insertExpense(e);
    }

    final day = DateTime(2026, 8, 10);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: DayEntryScreen(
        dates: {day},
        userType: '직장인',
        incomesByDay: const {},
        expensesByDay: {'2026-08-10': existing},
      ),
    ));
    await t.pumpAndSettle();

    // 새 지출 한 건 추가.
    await t.tap(findKo('지출 추가하기'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '5000');
    await t.pumpAndSettle();
    await t.tap(findKo('저장'));
    await t.pumpAndSettle();

    final after = await dbService.getExpenses();
    final ids = after.map((e) => e.id).toSet();

    expect(ids.contains('pre_1'), isTrue, reason: '기존 기록이 지워졌다');
    expect(ids.contains('pre_2'), isTrue, reason: '기존 기록이 지워졌다');
    expect(after.length, 3, reason: '추가 한 건이 그날 기록을 덮어썼다');
    expect(after.map((e) => e.amount).toList()..sort(), [3400, 5000, 12000]);
  });

  testWidgets('여러 날을 고르면 날짜마다 항목이 하나씩 생긴다', (t) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: DayEntryScreen(
        dates: {DateTime(2026, 8, 10), DateTime(2026, 8, 11), DateTime(2026, 8, 12)},
        userType: '직장인',
        incomesByDay: const {},
        expensesByDay: const {},
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(findKo('지출 추가하기'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '9000');
    await t.pumpAndSettle();
    await t.tap(findKo('저장'));
    await t.pumpAndSettle();

    final after = await dbService.getExpenses();
    // 기간 항목 하나가 아니라 **날짜별 항목 셋**이어야 집계가 맞는다.
    expect(after.length, 3);
    expect(after.every((e) => e.endDate == null), isTrue,
        reason: '기간 항목을 새로 만들면 금액이 첫날에 몰려 월별 집계가 틀어진다');
    expect(after.map((e) => e.date.day).toSet(), {10, 11, 12});
  });
}
