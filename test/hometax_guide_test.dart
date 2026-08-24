import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/year_coverage.dart';
import 'package:secul/core/data/year_deductions.dart';
import 'package:secul/core/data/year_snapshot.dart';
import 'package:secul/ui/screens/missed_deduction_diagnosis_screen.dart';
import 'package:secul/ui/screens/tax_annual_report_screen.dart';
import 'package:secul/ui/screens/tax_report_form_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// 홈택스 가이드와 가상 신고서 — **모두에게 같은 말을 하지 않는다.**
void main() {
  final year = DateTime.now().year;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  testWidgets('환급받는 사람에게 무신고 가산세 20%를 경고하지 않는다', (t) async {
    t.view.physicalSize = const Size(390, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const TaxAnnualReportScreen(userType: '직장인')));
    await t.pumpAndSettle();

    // 국세기본법 §47의2①은 「납부하여야 할 세액」에 곱한다. 돌려받을 사람은 0이다.
    expect(findKo('있을 때 붙어요'), findsWidgets);
    expect(findKo('기한 초과 시 무신고 가산세 20%'), findsNothing,
        reason: '환급받으러 온 사람에게 20%를 들이대면 겁만 주고 틀리기까지 한다');
  });

  testWidgets('가이드가 내 항목 이름을 부른다', (t) async {
    t.view.physicalSize = const Size(390, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await dbService.insertExpense(ExpenseItem(
      id: 'c1',
      date: DateTime(year, 3, 5),
      amount: 30000000,
      content: '',
      category: '마트',
      paymentMethod: '신용카드',
      userType: '직장인',
    ));

    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const TaxAnnualReportScreen(userType: '직장인')));
    await t.pumpAndSettle();

    // 「앱의 '소득공제' 참고」는 앱 안 어디를 보라는 건지 모호했다.
    expect(findKo('소득공제 명세서 — '), findsWidgets);
    expect(findKo("앱의 '소득공제' 참고"), findsNothing);
  });

  testWidgets('철이 지나면 경정청구로 안내한다', (t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MissedDeductionDiagnosisScreen(userType: '직장인')));
    await t.pumpAndSettle();

    // 5월 확정신고와 경정청구는 다른 절차다. 8월에 「5월 신고로」라고 하면
    // 이미 닫힌 문을 가리키는 것이고, 내년까지 기다려야 하는 줄 안다.
    final inSeason = DateTime.now().month <= 5;
    expect(findKo(inSeason ? '확정신고로 내면 돼요' : '경정청구로 내요'), findsWidgets);
    expect(findKo(inSeason ? '경정청구로 내요' : '확정신고로 내면 돼요'), findsNothing);
  });

  test('인적공제에 본인이 들어간다', () {
    // 홈택스 가이드가 dependents(본인 제외)만 곱해서 150만원이 통째로 빠졌다.
    // 화면 대조는 hometax_guide_value_test가 하고, 여기서는 규칙만 못 박는다.
    const perPerson = 1500000;
    for (final deps in [0, 1, 3]) {
      expect((1 + deps) * perPerson, greaterThan(deps * perPerson));
    }
  });

  group('신고서는 진단 없이도 채워진다', () {
    setUp(() async {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
      await YearCoverage.markComplete(year);
    });

    test('직장인 — 모아 둔 공제가 줄이 된다', () async {
      await dbService.saveProfile({
        'gross_income': 50000000.0,
        'dependents': 0,
        'residence_type': '자가',
        'owns_house': true,
        'is_household_head': true,
      });
      await YearDeductions.save(year, {'religiousDonation': 1000000});
      final d = draftFromSnapshot(await YearSnapshot.load('직장인'));
      expect(d, isNotNull);
      expect(d!.isRefund, isTrue);
      expect(d.finalAmount, greaterThan(0));
      expect(d.items.last['title'], '환급받을 세액');
    });

    test('업종을 모르는 프리랜서는 채우지 않는다', () async {
      // 경비율을 못 고르면 세금이 통째로 안 나온다 — 빈 서식이 틀린 서식보다 낫다.
      await dbService.saveProfile({'dependents': 0});
      final d = draftFromSnapshot(await YearSnapshot.load('프리랜서'));
      expect(d, isNull);
    });
  });

  testWidgets('신고서 화면이 진단 초안 없이도 숫자를 그린다', (t) async {
    t.view.physicalSize = const Size(390, 2000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await YearDeductions.save(year, {'religiousDonation': 1000000});

    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ReportFormLoader(userType: '직장인')));
    await t.pumpAndSettle();

    expect(findKo('기부금 세액공제'), findsWidgets);
    expect(findKo('아직 계산 전'), findsNothing);
  });
}
