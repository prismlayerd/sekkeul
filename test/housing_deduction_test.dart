import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/deduction_catalog.dart';
import 'package:secul/core/data/residence.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';

/// 집에 들어간 돈으로 받는 공제 — **한도를 나눠 쓰는 셋**이라 따로 계산하면 틀린다.
///
/// - 주택청약종합저축 (조특법 §87②)
/// - 주택임차차입금 원리금 (소법 §52④)
/// - 장기주택저당차입금 이자 (소법 §52⑤⑥)
void main() {
  double housing({
    double gross = 40000000,
    double sub = 0,
    double lease = 0,
    double mortgage = 0,
    bool fixed = false,
    bool nonDeferred = false,
    bool head = true,
    bool owns = false,
    bool institution = true,
  }) =>
      EmployeeTaxCalculator.calculateHousingDeduction(
        grossIncome: gross,
        subscriptionPaid: sub,
        leaseLoanRepaid: lease,
        mortgageInterest: mortgage,
        fixedRate: fixed,
        nonDeferredRepayment: nonDeferred,
        isHouseholdHead: head,
        ownsHome: owns,
        leaseLoanFromInstitution: institution,
      );

  group('한도', () {
    test('청약은 납입 300만까지만 센다 — 40%면 120만', () {
      expect(housing(sub: 3000000), 1200000);
      expect(housing(sub: 5000000), 1200000, reason: '납입한도 300만을 넘겨 세면 안 된다');
    });

    test('청약 + 전세는 합쳐 400만에서 잘린다', () {
      // 청약 120만 + 전세 원리금 1,000만×40% = 400만 → 합 520만 → 400만.
      expect(housing(sub: 3000000, lease: 10000000), 4000000);
    });

    test('주담대까지 합치면 800만에서 잘린다', () {
      // 청약·전세 400만 + 주담대 이자 800만 = 1,200만 → 800만.
      expect(housing(sub: 3000000, lease: 10000000, mortgage: 8000000), 8000000);
    });

    test('고정금리·비거치식이면 통합 한도가 2,000만으로 열린다', () {
      expect(
          housing(
              sub: 3000000,
              lease: 10000000,
              mortgage: 15000000,
              fixed: true,
              nonDeferred: true),
          19000000,
          reason: '400만 + 1,500만');
    });
  });

  group('요건', () {
    test('세대주가 아니면 청약·전세가 통째로 없다', () {
      expect(housing(sub: 3000000, lease: 10000000, head: false), 0);
    });

    test('자가면 청약·전세가 없다 — 주담대는 남는다', () {
      expect(housing(sub: 3000000, lease: 10000000, owns: true), 0);
      expect(housing(sub: 3000000, mortgage: 5000000, owns: true), 5000000);
    });

    test('청약은 총급여 7천만에서 끊기고, 전세는 안 끊긴다', () {
      // **§52④에는 소득 요건이 없다.** 한쪽만 끊기는 게 이 조문의 함정이다.
      expect(housing(gross: 70000000, sub: 3000000), 1200000);
      expect(housing(gross: 70000001, sub: 3000000), 0);
      expect(housing(gross: 70000001, lease: 5000000), 2000000);
    });

    test('개인에게 빌린 전세자금만 총급여 5천만에서 끊긴다 (시행령 §112④2호)', () {
      expect(housing(gross: 50000001, lease: 5000000, institution: false), 0);
      expect(housing(gross: 50000001, lease: 5000000), 2000000,
          reason: '은행에서 빌려 임대인 계좌로 들어간 돈(1호)은 소득과 무관하다');
    });
  });

  group('거주 형태 — 반전세는 둘 다다', () {
    Map<String, dynamic> p(String type) =>
        {...residenceFields(type), 'is_household_head': true};

    test('반전세는 월세도 전세도 받는다', () {
      expect(paysMonthlyRent(p('반전세')), isTrue);
      expect(hasLeaseDeposit(p('반전세')), isTrue);
    });

    test('반전세를 저장하면 반전세로 돌아온다', () {
      // 예전엔 불리언 둘로만 저장해 「전세」로 뭉개졌다.
      expect(residenceOf(p('반전세')), '반전세');
      expect(residenceOf(p('전세')), '전세');
      expect(residenceOf(p('월세')), '월세');
      expect(residenceOf(p('자가')), '자가');
    });

    test('v45 이전 프로필도 읽힌다', () {
      expect(residenceOf({'is_monthly_rent': true}), '월세');
      expect(residenceOf({'owns_house': true}), '자가');
      expect(residenceOf({'owns_house': false, 'is_monthly_rent': false}), '전세');
      expect(residenceOf({}), isNull, reason: '아직 안 정한 사람을 전세로 단정하면 안 된다');
    });
  });

  group('목록 거르기 — 앱이 아는 건 앱이 거른다', () {
    List<String> ids({
      String? residence,
      bool head = true,
      double gross = 40000000,
    }) =>
        deductionsFor(
                residence: residence, isHouseholdHead: head, grossIncome: gross)
            .map((c) => c.id)
            .toList();

    test('자가는 집 관련 셋이 다 빠진다', () {
      final r = ids(residence: '자가');
      expect(r, isNot(contains('rent')));
      expect(r, isNot(contains('housingSubscription')));
      expect(r, isNot(contains('leaseLoan')));
      expect(r, contains('medical'), reason: '집과 무관한 항목까지 지우면 안 된다');
    });

    test('전세는 청약·전세만, 월세는 청약·월세만', () {
      expect(ids(residence: '전세'), containsAll(['housingSubscription', 'leaseLoan']));
      expect(ids(residence: '전세'), isNot(contains('rent')));
      expect(ids(residence: '월세'), containsAll(['housingSubscription', 'rent']));
      expect(ids(residence: '월세'), isNot(contains('leaseLoan')));
    });

    test('반전세는 셋 다 뜬다', () {
      expect(ids(residence: '반전세'),
          containsAll(['housingSubscription', 'leaseLoan', 'rent']));
    });

    test('세대주가 아니면 집 관련이 다 빠진다', () {
      final r = ids(residence: '전세', head: false);
      expect(r, isNot(contains('housingSubscription')));
      expect(r, isNot(contains('leaseLoan')));
    });

    test('총급여 7천만 초과면 청약만 빠진다', () {
      final r = ids(residence: '전세', gross: 80000000);
      expect(r, isNot(contains('housingSubscription')));
      expect(r, contains('leaseLoan'));
    });
  });

  test('모아 둔 금액이 환급으로 이어진다', () {
    final none = estimateYearRefund(amounts: const {}, grossIncome: 50000000);
    final some = estimateYearRefund(
      amounts: const {'medical': 3000000, 'housingSubscription': 2400000},
      grossIncome: 50000000,
      isHouseholdHead: true,
    );
    expect(none.refund, 0);
    expect(some.refund, greaterThan(0));
    expect(some.lines.map((l) => l.label), contains('주택자금 소득공제'));
  });
}
