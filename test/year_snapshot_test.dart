import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/year_coverage.dart';
import 'package:secul/core/data/year_deductions.dart';
import 'package:secul/core/data/year_snapshot.dart';
import 'package:secul/ui/screens/tax_report_form_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **올해 숫자는 한 곳에서 나온다.**
///
/// 예전엔 화면마다 `getExpenses`를 돌려 각자의 규칙으로 다시 셌다. 그래서
/// 홈 02와 연말정산 진단이 다른 카드공제액을 말했다.
void main() {
  final year = DateTime.now().year;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  ExpenseItem exp(String id, int amount, String pay,
          {String? deduction, bool business = false, int? y}) =>
      ExpenseItem(
        id: id,
        date: DateTime(y ?? year, 3, 5),
        amount: amount,
        content: '',
        category: '기타',
        paymentMethod: pay,
        deductionType: deduction,
        isBusiness: business,
        userType: '직장인',
      );

  group('갈래 나누기 — 규칙은 한 곳에만', () {
    test('「기타」는 공제 대상이 아니다', () {
      expect(cardBucket(exp('a', 1000, '기타')), isNull);
      // 표식이 붙어 있어도 영수증이 없으면 대상이 아니다.
      expect(cardBucket(exp('b', 1000, '기타', deduction: '전통시장')), isNull);
    });

    test('공제 구분이 붙으면 신용카드가 아니라 그 갈래로 센다', () {
      // 안 그러면 같은 돈이 15%와 40%로 두 번 계산된다(조특법 §126의2②).
      expect(cardBucket(exp('c', 1000, '신용카드', deduction: '전통시장')), '전통시장');
      expect(cardBucket(exp('d', 1000, '신용카드')), '신용카드');
      expect(cardBucket(exp('e', 1000, '체크+현금')), '체크+현금');
    });
  });

  group('스냅샷', () {
    setUp(() async {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
      await dbService.saveProfile({
        'gross_income': 50000000.0,
        'dependents': 0,
        'residence_type': '전세',
        'owns_house': false,
        'is_monthly_rent': false,
        'is_household_head': true,
      });
      await YearCoverage.markComplete(year);
    });

    test('작년 지출은 안 센다', () async {
      await dbService.insertExpense(exp('now', 1000000, '신용카드'));
      await dbService.insertExpense(exp('old', 9000000, '신용카드', y: year - 1));
      final s = await YearSnapshot.load('직장인');
      expect(s.creditCard, 1000000);
    });

    test('특례는 신용카드에서 빠져 따로 쌓인다', () async {
      await dbService.insertExpense(exp('c', 1000000, '신용카드'));
      await dbService.insertExpense(
          exp('m', 300000, '신용카드', deduction: '전통시장'));
      await dbService.insertExpense(exp('o', 500000, '기타'));
      final s = await YearSnapshot.load('직장인');
      expect(s.creditCard, 1000000, reason: '전통시장이 신용카드에 남아 있으면 두 번 센다');
      expect(s.market, 300000);
      expect(s.excluded, 500000);
      expect(s.cardTotal, 1300000);
    });

    test('백필이 누계에 더해진다', () async {
      await YearCoverage.setBackfill(
          year, const Backfill(credit: 4000000, debit: 1000000));
      await dbService.insertExpense(exp('c', 1000000, '신용카드'));
      final s = await YearSnapshot.load('직장인');
      expect(s.creditCard, 5000000);
      expect(s.debitCash, 1000000);
    });

    test('「올해 받을 공제」가 함께 실려 온다', () async {
      await YearDeductions.save(year, {'medical': 900000});
      final s = await YearSnapshot.load('직장인');
      expect(s.deductions['medical'], 900000);
    });
  });

  group('무엇이 비었는지 앱이 말한다', () {
    setUp(() async {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
    });

    test('아무것도 없으면 연봉과 백필이 blocking이다', () async {
      await dbService.saveProfile({'gross_income': 0.0});
      final s = await YearSnapshot.load('직장인');
      final labels = s.missing.map((m) => m.label).toList();
      expect(labels, contains('예상 연봉'));
      expect(labels, contains('1월~지난달 기록'));
      expect(s.hasBlocking, isTrue);
    });

    test('다 채우면 blocking이 없다', () async {
      await dbService.saveProfile({
        'gross_income': 50000000.0,
        'dependents': 1,
        'residence_type': '자가',
        'owns_house': true,
        'is_household_head': true,
      });
      await YearCoverage.markComplete(year);
      await YearDeductions.save(year, {'medical': 500000});
      final s = await YearSnapshot.load('직장인');
      expect(s.hasBlocking, isFalse, reason: s.missing.map((m) => m.label).join(','));
    });

    test('프리랜서는 업종코드가 없으면 계산이 안 된다', () async {
      await dbService.saveProfile({'dependents': 0});
      await YearCoverage.markComplete(year);
      final s = await YearSnapshot.load('프리랜서');
      final blocking = s.missing.where((m) => m.blocking).map((m) => m.label);
      expect(blocking, contains('업종'));
      expect(blocking, isNot(contains('예상 연봉')),
          reason: '프리랜서에게 연봉을 채우라고 하면 안 된다');
    });

    test('직장인에게 사업 경비를 채우라고 하지 않는다', () async {
      await dbService.saveProfile({'gross_income': 50000000.0, 'dependents': 0});
      final s = await YearSnapshot.load('직장인');
      final labels = s.missing.map((m) => m.label);
      expect(labels, isNot(contains('사업 경비')));
      expect(labels, isNot(contains('업종')));
    });
  });

  testWidgets('신고서는 진단을 안 돌려도 올해 모인 것을 보여준다', (t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await dbService.insertExpense(exp('c', 2400000, '신용카드'));
    await YearDeductions.save(year, {'medical': 900000});

    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ReportFormLoader(userType: '직장인')));
    await t.pumpAndSettle();

    // 진단(saveReportDraft)을 한 번도 안 돌렸는데도 숫자가 보여야 한다.
    expect(findKo('년에 모인 것'), findsOneWidget);
    expect(findKo('신용카드'), findsWidgets);
    expect(findKo('의료비'), findsWidgets);
  });
}
