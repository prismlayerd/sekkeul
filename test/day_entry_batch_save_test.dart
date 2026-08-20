import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/day_entry_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **하루치를 몰아 적고 한 번에 저장한다.**
///
/// 예전에는 항목마다 즉시 DB에 썼다. 그래서 아래 「저장」 버튼이 무엇을 저장하는
/// 건지 알 수 없었다 — 이미 다 저장돼 있었으니까.
///
/// 위험했던 것은 «일괄»이 아니라 **전부 지우고 다시 넣기**였다. 그 경로는 없다.
/// 지금은 새 항목만 담아 뒀다가 항목 하나씩 insert만 한다.
void main() {
  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: DayEntryScreen(
        dates: {DateTime.now()},
        userType: '직장인',
        incomesByDay: const {},
        expensesByDay: const {},
      ),
    ));
    await t.pumpAndSettle();
  }

  /// 지출 하나를 적고 「확인」까지.
  Future<void> addExpense(WidgetTester t, String amount) async {
    await t.tap(findKo('지출 추가하기'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, amount);
    await t.pumpAndSettle();
    await t.tap(findKo('확인'));
    await t.pumpAndSettle();
  }

  testWidgets('확인만으로는 아직 안 쓴다', (t) async {
    await pump(t);
    await addExpense(t, '30000');

    expect(await dbService.getExpenses(), isEmpty,
        reason: '「확인」은 목록에 올리는 것이지 저장이 아니다');
    expect(findKo('저장 전'), findsOneWidget,
        reason: '아직 안 쓴 줄임을 화면이 말해야 한다');
    expect(findKo('1건 저장'), findsOneWidget,
        reason: '아래 버튼이 무엇을 저장하는지 개수로 말해야 한다');
  });

  testWidgets('여러 건을 적고 한 번에 저장한다', (t) async {
    await pump(t);
    await addExpense(t, '30000');
    await addExpense(t, '12000');
    await addExpense(t, '5000');

    expect(findKo('3건 저장'), findsOneWidget);
    expect(await dbService.getExpenses(), isEmpty);

    await t.tap(findKo('3건 저장'));
    await t.pumpAndSettle();

    final saved = await dbService.getExpenses();
    expect(saved.map((e) => e.amount).toList()..sort(), [5000, 12000, 30000],
        reason: '세 건을 다 써야 한다');
  });

  testWidgets('안 쓴 것을 지우면 DB를 건드리지 않는다', (t) async {
    await pump(t);
    await addExpense(t, '30000');
    await t.tap(findKo('저장 전'));
    await t.pumpAndSettle();
    await t.tap(findKo('삭제'));
    await t.pumpAndSettle();

    expect(findKo('저장 전'), findsNothing);
    expect(findKo('완료'), findsOneWidget, reason: '쌓아 둔 게 없으면 완료로 돌아온다');
    expect(await dbService.getExpenses(), isEmpty);
  });
}
