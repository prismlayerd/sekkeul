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

    IncomeThreshold only(OtherIncome o) => incomeThresholds(
        businessIncome: 0, otherIncomeAmount: 0, other: o).single;

    test('금융소득은 2,000만이 문턱이다', () {
      expect(only(const OtherIncome(financial: 20000000)).over, isFalse);
      expect(only(const OtherIncome(financial: 20000001)).over, isTrue);
    });

    test('원천징수 안 된 금융소득은 금액과 무관하게 종합과세 (§14③6)', () {
      // 조문은 「2천만원 이하이면서 원천징수된」 **둘 다**를 요구한다.
      // 국외 계좌 이자·배당은 원천징수가 없어 1원부터 종합과세다.
      final t = only(const OtherIncome(financial: 1000000, financialWithheld: false));
      expect(t.over, isTrue);
      expect(t.limit, 0);
    });

    test('1주택은 비과세다 — 없는 신고 의무를 만들지 않는다 (§12 2호 나목)', () {
      final t = only(const OtherIncome(rentalRent: 18000000, houseCount: 1));
      expect(t.over, isFalse);
      expect(t.consequence, contains('비과세'));
      // 기준시가 12억을 넘으면 그 예외가 깨진다.
      expect(
          only(const OtherIncome(
                  rentalRent: 18000000, houseCount: 1, overHighValue: true))
              .over,
          isFalse,
          reason: '12억 초과라도 2,000만원 이하면 분리과세를 고를 수 있다');
      expect(
          only(const OtherIncome(
                  rentalRent: 21000000, houseCount: 1, overHighValue: true))
              .over,
          isTrue);
    });

    test('2주택부터는 2,000만이 문턱이다', () {
      expect(only(const OtherIncome(rentalRent: 20000000, houseCount: 2)).over,
          isFalse);
      expect(only(const OtherIncome(rentalRent: 20000001, houseCount: 2)).over,
          isTrue);
    });

    test('3주택 + 보증금 3억 초과면 판정을 보류한다', () {
      // 간주임대료에 쓰이는 정기예금이자율은 재정경제부령 고시라 앱이 검증한
      // 값을 갖고 있지 않다. 모르는 값으로 단정하느니 모른다고 말한다.
      final t = only(const OtherIncome(
          rentalRent: 15000000, houseCount: 3, deposit: 500000000));
      expect(t.undecided, isTrue);
      expect(hasUndecided([t]), isTrue);

      // 보증금이 3억 이하면 간주임대료가 0이라 보류할 이유가 없다.
      expect(
          only(const OtherIncome(
                  rentalRent: 15000000, houseCount: 3, deposit: 200000000))
              .undecided,
          isFalse);
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
          year,
          const OtherIncome(
              financial: 5000000,
              financialWithheld: false,
              rentalRent: 12000000,
              houseCount: 3,
              deposit: 400000000));
      final v = await OtherIncomeStore.load(year);
      expect(v.financial, 5000000);
      expect(v.financialWithheld, isFalse);
      expect(v.rentalRent, 12000000);
      expect(v.houseCount, 3);
      expect(v.deposit, 400000000);
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
