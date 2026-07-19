import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/occupation_data.dart';
import 'package:secul/core/tax_engine/bookkeeping_duty.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/freelancer_tax.dart';

// 2026-07-19 세법 재검증에서 추가된 규칙들의 회귀 테스트.
// 출처: 국세청 "기장의무와 추계신고시 적용할 경비율 판단기준",
//       국세청 "월세액 세액공제", 소득세법 §14③8(기타소득 선택적 분리과세).
void main() {
  group('단순경비율 적용 판정 (isSimpleExpenseRateEligible)', () {
    // 그룹 판정은 code 접두로 파생되므로 합성 OccupationInfo로 임계만 검증한다.
    OccupationInfo occ(String code) => OccupationInfo(
        code: code, name: 't', simpleBaseRate: 60, simpleExcessRate: 40, standardRate: 10);

    test('인적용역(940xxx) 특례 — 기장의무는 다군이지만 경비율 임계는 나군 3,600만', () {
      final o = occ('940909');
      expect(o.simpleExpenseRateThreshold, 36000000);
      // 2,400만~3,600만 구간: 특례가 없었다면 배제됐을 구간에서 단순경비율 허용.
      expect(isSimpleExpenseRateEligible(occupation: o, priorYearIncome: 30000000), isTrue);
      expect(isSimpleExpenseRateEligible(occupation: o, priorYearIncome: 36000000), isFalse);
    });

    test('다군(서비스 등, 940 외)은 2,400만 임계', () {
      final o = occ('930100');
      expect(o.simpleExpenseRateThreshold, 24000000);
      expect(isSimpleExpenseRateEligible(occupation: o, priorYearIncome: 23999999), isTrue);
      expect(isSimpleExpenseRateEligible(occupation: o, priorYearIncome: 24000000), isFalse);
    });

    test('가군(도소매) 6,000만 / 나군(제조 등) 3,600만 임계', () {
      expect(occ('513001').simpleExpenseRateThreshold, 60000000);
      expect(occ('552101').simpleExpenseRateThreshold, 36000000);
    });

    test('신규사업자는 첫해 단순경비율 — 단, 당해 수입이 복식부기 임계 이상이면 배제', () {
      final o = occ('940909'); // 다군 복식 임계 7,500만
      expect(
          isSimpleExpenseRateEligible(
              occupation: o, priorYearIncome: 0, isNewBusiness: true, currentYearIncome: 74000000),
          isTrue);
      expect(
          isSimpleExpenseRateEligible(
              occupation: o, priorYearIncome: 0, isNewBusiness: true, currentYearIncome: 75000000),
          isFalse);
    });

    test('계속사업자도 당해 수입이 복식부기 임계 이상이면 단순경비율 배제', () {
      final o = occ('940909');
      expect(
          isSimpleExpenseRateEligible(
              occupation: o, priorYearIncome: 10000000, currentYearIncome: 80000000),
          isFalse);
    });
  });

  group('기장 vs 추계 비교 — 경비율 강제', () {
    test('forceStandardExpenseRate=true면 추계는 기준경비율로 계산된다', () {
      final forced = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
        accumulatedIncome: 30000000,
        accumulatedActualExpense: 5000000,
        inputMonths: 6,
        allowanceCount: 0,
        occupationCode: '940100',
        forceStandardExpenseRate: true,
      );
      final standardOnly = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: 30000000,
        inputMonths: 6,
        allowanceCount: 0,
        occupationCode: '940100',
        useStandardExpenseRate: true,
      );
      expect(forced.estimate.annualTotalTax, standardOnly.annualTotalTax);
      // 작가(단순 58.7% vs 기준 7.2%)는 기준경비율 강제 시 추계 세금이 훨씬 커진다.
      final free = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: 30000000,
        inputMonths: 6,
        allowanceCount: 0,
        occupationCode: '940100',
      );
      expect(forced.estimate.annualTotalTax, greaterThan(free.annualTotalTax));
    });
  });

  group('기타소득 선택적 분리과세 (소득세법 §14③8)', () {
    test('고소득: 한계세율 > 8.8% → 분리과세 선택(종합 제외, 세액 불변)', () {
      // 수입 2억(작가): 과표 ~1억 → 한계세율 35%(지방 포함 38.5%) > 8.8% → 분리과세 유리.
      final withOther = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: 200000000,
        accumulatedOtherIncome: 1000000, // 기타소득금액 40만 ≤ 300만
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: '940100',
      );
      final withoutOther = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: 200000000,
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: '940100',
      );
      expect(withOther.annualTotalTax, withoutOther.annualTotalTax);
      expect(withOther.paidTotalWithholding, withoutOther.paidTotalWithholding);
    });

    test('저소득: 한계세율 < 8.8% → 종합과세 선택(합산 + 원천징수 8.8% 기납부 공제)', () {
      final withOther = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: 12000000,
        accumulatedOtherIncome: 1000000,
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: '940100',
      );
      final withoutOther = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: 12000000,
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: '940100',
      );
      // 합산돼 세액은 늘고, 기납부에는 기타소득 원천징수(1,000,000×8.8%=88,000)가 잡힌다.
      expect(withOther.annualTotalTax, greaterThan(withoutOther.annualTotalTax));
      expect(withOther.paidTotalWithholding - withoutOther.paidTotalWithholding, 88000);
      // 종합 합산이 유리하려면 한계세액(추가 세금)이 원천징수액(88,000)보다 작아야 한다.
      expect(withOther.annualTotalTax - withoutOther.annualTotalTax, lessThan(88000));
    });

    test('기타소득금액 300만 초과는 무조건 종합과세', () {
      // 총수입 1,000만 → 기타소득금액 400만 > 300만.
      final withOther = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: 100000000,
        accumulatedOtherIncome: 10000000,
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: '940100',
      );
      final withoutOther = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: 100000000,
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: '940100',
      );
      expect(withOther.annualTotalTax, greaterThan(withoutOther.annualTotalTax));
    });
  });

  group('월세 세액공제 현행화 (조특법 §95의2, 2024 귀속~)', () {
    test('종합소득금액 6,000만~7,000만 구간도 이제 대상', () {
      expect(
          EmployeeTaxCalculator.isRentCreditEligible(
              grossIncome: 60000000, globalIncomeAmount: 65000000, isHomeless: true),
          isTrue);
      expect(
          EmployeeTaxCalculator.isRentCreditEligible(
              grossIncome: 60000000, globalIncomeAmount: 70000001, isHomeless: true),
          isFalse);
    });

    test('일반 프리랜서는 월세 공제 제외, 성실사업자만 적용', () {
      final normal = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: 30000000,
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: '940100',
        monthlyRent: 500000,
        isHomeless: true,
      );
      expect(normal.rentTaxCredit, 0);

      final faithful = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: 30000000,
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: '940100',
        monthlyRent: 500000,
        isHomeless: true,
        isQualifiedFaithfulTaxpayer: true,
      );
      // 종합소득금액 4,500만 이하 → 17%: 연 600만 × 0.17 = 1,020,000.
      expect(faithful.rentTaxCredit, 1020000);
    });
  });
}
