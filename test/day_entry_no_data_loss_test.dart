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
/// 「확인」으로 목록에 올리고, 쌓인 게 있으면 아래 「N건 저장」까지 눌러 준다.
///
/// 새 항목은 이제 바로 안 써진다 — 하루치를 몰아 적을 수 있게 담아 뒀다가 한
/// 번에 쓴다(day_entry_batch_save_test). 이 파일이 보는 것은 «그렇게 써도 그날의
/// 다른 기록이 안 사라지는가»다.
Future<void> commit(WidgetTester t) async {
  await t.tap(findKo('확인'));
  await t.pumpAndSettle();
  final save = find.byWidgetPredicate((w) =>
      w is Text && RegExp(r'^\d+건 저장$').hasMatch(w.data ?? ''));
  if (save.evaluate().isNotEmpty) {
    await t.tap(save.first);
    await t.pumpAndSettle();
  }
}

void main() {
  ExpenseItem seed(String id, int amount, String category, {String content = ''}) =>
      ExpenseItem(
        id: id,
        date: DateTime(2026, 8, 10),
        amount: amount,
        content: content,
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
    await commit(t);

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
    await commit(t);

    final after = await dbService.getExpenses();
    // 기간 항목 하나가 아니라 **날짜별 항목 셋**이어야 집계가 맞는다.
    expect(after.length, 3);
    expect(after.every((e) => e.endDate == null), isTrue,
        reason: '기간 항목을 새로 만들면 금액이 첫날에 몰려 월별 집계가 틀어진다');
    expect(after.map((e) => e.date.day).toSet(), {10, 11, 12});
  });

  /// 화면을 열고 목록에서 [title] 줄을 눌러 편집기를 편다.
  Future<void> openRow(WidgetTester t, String title) async {
    await t.tap(findKo(title));
    await t.pumpAndSettle();
  }

  Future<void> pumpDay(
    WidgetTester t, {
    List<ExpenseItem> expenses = const [],
    List<IncomeEntry> incomes = const [],
  }) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    for (final e in expenses) {
      await dbService.insertExpense(e);
    }
    for (final e in incomes) {
      await dbService.insertIncomeEntry(e);
    }

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: DayEntryScreen(
        dates: {DateTime(2026, 8, 10)},
        userType: '직장인',
        incomesByDay: incomes.isEmpty ? const {} : {'2026-08-10': incomes},
        expensesByDay: expenses.isEmpty ? const {} : {'2026-08-10': expenses},
      ),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('지출을 고치면 그 항목만 바뀐다', (t) async {
    final a = seed('a', 12000, '음식/배달', content: '김밥');
    final b = seed('b', 3400, '교통', content: '버스');
    await pumpDay(t, expenses: [a, b]);

    await openRow(t, '김밥');
    await t.enterText(find.byType(TextField).first, '20000');
    await t.pumpAndSettle();
    await commit(t);

    final after = await dbService.getExpenses();
    expect(after.length, 2, reason: '수정이 항목을 하나 더 만들었다');
    expect(after.firstWhere((e) => e.id == 'a').amount, 20000);
    expect(after.firstWhere((e) => e.id == 'b').amount, 3400,
        reason: '옆 항목까지 건드렸다');
  });

  testWidgets('지출을 지우면 그 항목만 사라진다', (t) async {
    final a = seed('a', 12000, '음식/배달', content: '김밥');
    final b = seed('b', 3400, '교통', content: '버스');
    await pumpDay(t, expenses: [a, b]);

    await openRow(t, '김밥');
    await t.tap(findKo('삭제'));
    await t.pumpAndSettle();

    final after = await dbService.getExpenses();
    expect(after.map((e) => e.id).toList(), ['b']);
  });

  testWidgets('옛 기간 기록을 고쳐도 기간이 사라지지 않는다', (t) async {
    // 기간 항목은 이제 새로 만들지 않지만, 이미 적어 둔 사람의 기록은 남아 있다.
    // 그걸 열어 금액만 고쳤을 때 endDate가 날아가면 달력에서 통째로 사라진다.
    final ranged = ExpenseItem(
      id: 'r',
      date: DateTime(2026, 8, 10),
      endDate: DateTime(2026, 8, 13),
      amount: 50000,
      content: '여행',
      category: '음식/배달',
      paymentMethod: '신용카드',
      userType: '직장인',
    );
    await pumpDay(t, expenses: [ranged]);

    await openRow(t, '여행');
    await t.enterText(find.byType(TextField).first, '60000');
    await t.pumpAndSettle();
    await commit(t);

    final after = (await dbService.getExpenses()).single;
    expect(after.amount, 60000);
    expect(after.endDate, DateTime(2026, 8, 13), reason: '기간이 날아갔다');
  });

  testWidgets('수익도 추가·수정·삭제된다', (t) async {
    await pumpDay(t);

    await t.tap(findKo('수익 추가하기'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '300000');
    await t.pumpAndSettle();
    await commit(t);

    var rows = await dbService.getIncomeEntriesForMonth(2026, 8);
    expect(rows.length, 1);
    expect(rows.single.amount, 300000);

    // 방금 적은 줄을 다시 열어 고친다 — 메모가 없으니 소득유형이 제목이다.
    await openRow(t, rows.single.incomeType);
    await t.enterText(find.byType(TextField).first, '250000');
    await t.pumpAndSettle();
    await commit(t);

    rows = await dbService.getIncomeEntriesForMonth(2026, 8);
    expect(rows.single.amount, 250000, reason: '수익 수정이 안 먹었다');

    await openRow(t, rows.single.incomeType);
    await t.tap(findKo('삭제'));
    await t.pumpAndSettle();

    rows = await dbService.getIncomeEntriesForMonth(2026, 8);
    expect(rows, isEmpty);
  });
}
