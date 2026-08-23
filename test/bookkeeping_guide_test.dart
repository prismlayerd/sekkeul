import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/core/data/year_coverage.dart';
import 'package:secul/core/tax_engine/simple_ledger_builder.dart';
import 'package:secul/ui/screens/bookkeeping_guide_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **장부는 연도가 맞아야 쓸모가 있다.**
///
/// 5월에 신고하는 건 작년 장부인데, 화면이 올해로 못 박혀 있었다.
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  Future<void> pump(WidgetTester t, String type) async {
    t.view.physicalSize = const Size(390, 2200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme, home: BookkeepingGuideScreen(userType: type)));
    await t.pumpAndSettle();
  }

  testWidgets('올해와 작년을 고를 수 있다', (t) async {
    await seedRealisticUser('프리랜서');
    await pump(t, '프리랜서');
    final now = DateTime.now().year;
    expect(findKo('$now년 장부'), findsOneWidget);
    expect(findKo('${now - 1}년 장부'), findsOneWidget);
  });

  testWidgets('백필이 있으면 장부에 없다고 말한다', (t) async {
    await seedRealisticUser('프리랜서');
    final year = DateTime.now().month <= 5
        ? DateTime.now().year - 1
        : DateTime.now().year;
    await YearCoverage.setBackfill(
        year, const Backfill(bizIncome: 12000000, bizExpense: 3000000));
    await dbService.insertIncomeEntry(IncomeEntry(
      id: 'i1',
      date: DateTime(year, 9, 3),
      amount: 2000000,
      incomeType: '사업소득',
      memo: '용역비',
      userType: '프리랜서',
    ));

    await pump(t, '프리랜서');
    // 합계로 받은 값은 거래 줄로 못 쪼갠다 — 조용히 빠지면 장부가 소득을 축소한다.
    expect(findKo('장부에 없어요'), findsOneWidget);
  });

  test('백필은 장부 줄로 만들지 않는다', () {
    final year = DateTime.now().year;
    final r = SimpleLedgerBuilder.build(
      year: year,
      incomes: [
        IncomeEntry(
          id: 'a',
          date: DateTime(year, 9, 3),
          amount: 1000000,
          incomeType: '사업소득',
          memo: '',
          userType: '프리랜서',
        ),
      ],
      expenses: [
        ExpenseItem(
          id: 'b',
          date: DateTime(year, 9, 4),
          amount: 200000,
          content: '',
          category: '기타',
          paymentMethod: '신용카드',
          isBusiness: true,
          userType: '프리랜서',
        ),
        // 개인 지출은 장부에 들어가면 안 된다.
        ExpenseItem(
          id: 'c',
          date: DateTime(year, 9, 5),
          amount: 50000,
          content: '',
          category: '카페',
          paymentMethod: '신용카드',
          userType: '프리랜서',
        ),
      ],
    );
    expect(r.rows.length, 2);
    expect(r.totalExpense, 200000);
    expect(r.blankDescriptionCount, 2, reason: '거래내용이 비면 채우라고 해야 한다');
  });
}
