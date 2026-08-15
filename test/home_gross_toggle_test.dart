import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/ui/screens/home/home_status_section.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **세전/세후 전환은 실제로 달라질 때만 그렇게 말한다.**
///
/// 실기기에서 "탭해도 계산 안 해준다"는 제보를 받았다. 두 가지가 겹쳐 있었다.
/// 하나는 기록이 없어도 "탭해서 세전 보기"라고 적어 둔 것(눌러도 아무 일이
/// 없다), 다른 하나는 원천징수를 안 뗀 기록만 있으면 세전과 세후가 같은
/// 숫자라 역시 아무 일이 없어 보이는 것.
void main() {
  Widget host({
    required String userType,
    required bool isEmployee,
    required double monthly,
    required double other,
    required double otherGross,
    double labor = 0,
  }) =>
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeStatusSection(
              userType: userType,
              isEmployee: isEmployee,
              monthlyIncome: monthly,
              grossIncome: 0,
              dependentCount: 1,
              laborIncome: labor,
              otherIncome: other,
              otherIncomeGrossEstimate: otherGross,
              expenseTarget: 0,
              creditCardTotal: 0,
              debitCashTotal: 0,
              creditCardYtdTotal: 0,
              debitCashYtdTotal: 0,
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

  testWidgets('기록이 없으면 세전 안내를 걸지 않는다', (t) async {
    await t.pumpWidget(host(
        userType: '프리랜서',
        isEmployee: false,
        monthly: 0,
        other: 0,
        otherGross: 0));
    await t.pumpAndSettle();

    expect(findKo('탭해서 세전 보기'), findsNothing,
        reason: '누를 수 없는데 누르라고 적혀 있었다');
  });

  testWidgets('원천징수를 안 뗐으면 세전 안내를 걸지 않는다', (t) async {
    // 세전과 세후가 같은 숫자라 눌러도 화면이 안 바뀐다.
    await t.pumpWidget(host(
        userType: '프리랜서',
        isEmployee: false,
        monthly: 1000000,
        other: 1000000,
        otherGross: 1000000));
    await t.pumpAndSettle();

    expect(findKo('탭해서 세전 보기'), findsNothing);
  });

  testWidgets('원천징수를 뗐으면 탭해서 세전이 보인다', (t) async {
    await t.pumpWidget(host(
        userType: '프리랜서',
        isEmployee: false,
        monthly: 967000,
        other: 967000,
        otherGross: 1000000));
    await t.pumpAndSettle();

    expect(findKo('탭해서 세전 보기'), findsOneWidget);
    expect(findKo('967,000'), findsOneWidget);

    await t.tap(findKo('967,000'));
    await t.pumpAndSettle();
    expect(findKo('1,000,000'), findsOneWidget, reason: '세전으로 안 바뀐다');
  });

  testWidgets('급여가 섞여 있어도 세전이 세후보다 작아지지 않는다', (t) async {
    // 세전 환산은 급여가 아닌 소득만 역산한다. 예전에는 급여분을 빼고 찍어
    // "세전"이 세후보다 작은 숫자로 나왔다.
    await t.pumpWidget(host(
        userType: '프리랜서',
        isEmployee: false,
        monthly: 1967000, // 급여 100만 + 사업소득 96.7만
        other: 967000,
        otherGross: 1000000));
    await t.pumpAndSettle();

    await t.tap(findKo('1,967,000'));
    await t.pumpAndSettle();

    expect(findKo('2,000,000'), findsOneWidget,
        reason: '역산 안 되는 급여 100만이 빠져 세후보다 작아졌다');
  });

  testWidgets('N잡러 다른소득도 같은 규칙을 따른다', (t) async {
    await t.pumpWidget(host(
        userType: 'N잡러',
        isEmployee: true, // N잡러는 isEmployee가 참이다 — 여기서 막히면 안 된다
        monthly: 3967000,
        labor: 3000000,
        other: 967000,
        otherGross: 1000000));
    await t.pumpAndSettle();

    expect(findKo('탭해서 세전 보기'), findsOneWidget,
        reason: 'N잡러의 다른소득 전환이 유형 조건에 걸려 죽었다');
  });
}
