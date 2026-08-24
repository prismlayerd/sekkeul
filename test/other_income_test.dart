import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/core/data/ledger_profile.dart';
import 'package:secul/core/data/other_income.dart';
import 'package:secul/core/data/year_coverage.dart';
import 'package:secul/core/data/year_snapshot.dart';
import 'package:secul/ui/screens/home/other_income_section.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **근로소득「만」이 언제 깨지는가.**
///
/// 소법 §73①1은 근로소득만 있는 사람의 확정신고를 면제한다. 그 「만」이 깨지는
/// 지점이 소득마다 다르고, 하나(사업소득)는 문턱이 아예 없다.
void main() {
  final year = DateTime.now().year;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  group('문턱 판정', () {
    test('사업소득은 문턱이 없다 — 1원이라도 신고 대상', () {
      final t = incomeThresholds(
          businessIncome: 100000,
          otherIncomeAmount: 0,
          other: const OtherIncome());
      expect(t.single.over, isTrue);
      expect(t.single.limit, 0, reason: '문턱이 있는 척하면 안 된다');
      expect(mustFileReturn(t), isTrue);
    });

    test('기타소득은 소득금액 300만이 문턱이다', () {
      // 수입이 아니라 **소득금액**(수입 − 필요경비)으로 본다 — 강의료 500만원은
      // 필요경비 60%를 빼면 200만원이라 아직 아래다.
      expect(
          incomeThresholds(
                  businessIncome: 0,
                  otherIncomeAmount: 3000000,
                  other: const OtherIncome())
              .single
              .over,
          isFalse);
      expect(
          incomeThresholds(
                  businessIncome: 0,
                  otherIncomeAmount: 3000001,
                  other: const OtherIncome())
              .single
              .over,
          isTrue);
    });

    test('금융소득·임대소득은 2,000만이 문턱이다', () {
      final under = incomeThresholds(
          businessIncome: 0,
          otherIncomeAmount: 0,
          other: const OtherIncome(financial: 20000000, rental: 20000000));
      expect(under.every((t) => !t.over), isTrue);
      expect(mustFileReturn(under), isFalse, reason: '분리과세로 끝나는데 신고하라고 하면 안 된다');

      final over = incomeThresholds(
          businessIncome: 0,
          otherIncomeAmount: 0,
          other: const OtherIncome(financial: 20000001));
      expect(over.single.over, isTrue);
    });

    test('아무것도 없으면 목록도 비어 있다', () {
      expect(
          incomeThresholds(
              businessIncome: 0,
              otherIncomeAmount: 0,
              other: const OtherIncome()),
          isEmpty);
    });
  });

  group('저장', () {
    setUp(() async {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
    });

    test('넣은 값이 그대로 돌아온다', () async {
      await OtherIncomeStore.save(
          year, const OtherIncome(financial: 5000000, rental: 12000000));
      final v = await OtherIncomeStore.load(year);
      expect(v.financial, 5000000);
      expect(v.rental, 12000000);
      expect(v.isEmpty, isFalse);
    });

    test('안 넣었으면 비어 있다', () async {
      expect((await OtherIncomeStore.load(year)).isEmpty, isTrue);
    });
  });

  test('직장인도 사업소득을 적을 수 있다', () {
    // 적을 데가 없으면 부업이 생긴 걸 앱이 영영 모르고, 신고 의무도 못 알린다.
    expect(LedgerProfile.of('직장인').incomeTypes, contains('사업소득'));
    // 다만 사업경비·적립카드는 아직 없다 — 그건 N잡러로 옮겨야 열린다.
    expect(LedgerProfile.of('직장인').tracksBusinessExpense, isFalse);
  });

  test('유형을 옮겨도 연봉이 따라간다', () async {
    // 부업이 생겨 직장인 → N잡러로 가는 사람은 **같은 사람이고 연봉도 같다**.
    // 새 유형에서 빈 칸을 다시 채우게 하면 옮긴 걸 후회한다.
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.setProfileTypeValues('직장인',
        grossIncome: 50000000, expenseTarget: 1500000);

    final before = await dbService.getProfileTypeValues('N잡러');
    expect(before['gross_income'] ?? 0, 0, reason: '유형별 저장이라 처음엔 비어 있다');
  });

  testWidgets('02 절이 홈 1장에 있고, 사업소득이 있으면 전환을 권한다', (t) async {
    t.view.physicalSize = const Size(390, 2000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await YearCoverage.markComplete(year);
    await dbService.insertIncomeEntry(IncomeEntry(
      id: 'b1',
      date: DateTime(year, 4, 3),
      amount: 1200000,
      incomeType: '사업소득',
      memo: '외주',
      userType: '직장인',
    ));
    final snap = await YearSnapshot.load('직장인');

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: OtherIncomeSection(
            snapshot: snap,
            onChanged: () {},
            onSwitchType: () {},
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    expect(findKo('다른 소득'), findsWidgets);
    expect(findKo('5월에 종합소득세를 신고해야 해요'), findsWidgets);

    await t.tap(findKo('다른 소득').first);
    await t.pumpAndSettle();
    expect(findKo('N잡러로 바꾸면'), findsWidgets);
    expect(findKo('가계부와 내 정보는 그대로 따라가요'), findsWidgets);
  });
}
