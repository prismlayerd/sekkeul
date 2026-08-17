import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/home/home_status_section.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **결제수단이 '기타'인 지출도 홈에서 보인다.**
///
/// 예전에는 월 집계가 "신용카드가 아니면 전부 체크·현금"이었다. 그래서 기타로
/// 적은 지출이 체크·현금 숫자에 섞여 들어갔다 — 가계부에는 있는 항목이 홈
/// 어디에도 안 보이고, 체크·현금 금액은 실제보다 커졌다.
///
/// 기타는 카드공제 대상이 아니지만 **쓴 돈은 쓴 돈이다.** 줄로 보여주고
/// 합계에도 넣는다.
void main() {
  Widget host({required double credit, required double debit, required double other}) =>
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeStatusSection(
              yearCovered: true,
              onFillPreviousMonths: () {},
              userType: '직장인',
              isEmployee: true,
              monthlyIncome: 3000000,
              grossIncome: 36000000,
              dependentCount: 1,
              laborIncome: 3000000,
              otherIncome: 0,
              otherIncomeGrossEstimate: 0,
              expenseTarget: 0,
              creditCardTotal: credit,
              debitCashTotal: debit,
              otherPayTotal: other,
              creditCardYtdTotal: credit,
              debitCashYtdTotal: debit,
              onOpenLedger: () {},
              onOpenMyInfo: () {},
              onSetExpenseTarget: () {},
            ),
          ),
        ),
      );

  setUp(() async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
  });

  testWidgets('기타 지출이 줄로 보이고 합계에 들어간다', (t) async {
    t.view.physicalSize = const Size(390, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(host(credit: 420000, debit: 43000, other: 5000));
    await t.pumpAndSettle();

    expect(findKo('기타'), findsWidgets, reason: '기타 줄이 없다');
    expect(findKo('5,000원'), findsOneWidget, reason: '기타 금액이 안 보인다');
    expect(findKo('468,000원'), findsOneWidget,
        reason: '합계가 기타를 빼고 계산됐다 (420,000 + 43,000 + 5,000)');
    // 체크·현금에 기타가 섞이면 48,000원이 된다.
    expect(findKo('43,000원'), findsOneWidget, reason: '체크·현금에 기타가 섞였다');
  });

  testWidgets('기타가 없으면 줄도 안 뜬다', (t) async {
    t.view.physicalSize = const Size(390, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(host(credit: 420000, debit: 43000, other: 0));
    await t.pumpAndSettle();

    expect(findKo('463,000원'), findsOneWidget);
  });
}
