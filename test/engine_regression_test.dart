import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/combined_tax.dart';
import 'package:secul/core/tax_engine/freelancer_tax.dart';
import 'package:secul/core/tax_engine/tax_rates.dart';
import 'package:secul/core/tax_engine/tax_year.dart';
import 'package:secul/core/tax_engine/insurance_engine.dart';

/// 세끌 세금 엔진 검산 회귀테스트
/// 각 테스트는 실제 법령·고시 수치를 기준으로 산출값을 검증한다.
void main() {
  // ──────────────────────────────────────────
  // 인적공제 (3건)
  // ──────────────────────────────────────────
  group('인적공제 추가공제', () {
    test('person_1: 경로우대 100만 + 한부모 100만 = 200만', () {
      final result = EmployeeTaxCalculator.calculateAdditionalPersonalDeduction(
        hasElderly70Plus: true,
        isSingleFemaleHead: false,
        isSingleParent: true,
      );
      expect(result, 2000000.0);
    });

    test('person_2: 부녀자·한부모 동시 → 한부모(100만) 선택, 경로우대 없음', () {
      final result = EmployeeTaxCalculator.calculateAdditionalPersonalDeduction(
        hasElderly70Plus: false,
        isSingleFemaleHead: true,
        isSingleParent: true,
      );
      expect(result, 1000000.0);
    });

    test('person_3: 부녀자만 → 50만', () {
      final result = EmployeeTaxCalculator.calculateAdditionalPersonalDeduction(
        hasElderly70Plus: false,
        isSingleFemaleHead: true,
        isSingleParent: false,
      );
      expect(result, 500000.0);
    });
  });

  // ──────────────────────────────────────────
  // 신용카드 소득공제 (2건)
  // ──────────────────────────────────────────
  group('신용카드 소득공제', () {
    test('card_1: 총급여5천만, 신용카드1,500만 → 공제 발생', () {
      final r = EmployeeTaxCalculator.calculateCreditCardDeduction(
        grossIncome: 50000000,
        creditCard: 15000000,
        debitCardAndCash: 0,
        traditionalMarket: 0,
        publicTransport: 0,
        cultureExpense: 0,
      );
      // 최저사용액 = 50000000 * 0.25 = 12,500,000
      // 초과액 = 15000000 - 12500000 = 2,500,000
      // 신용카드 공제율 15% → 375,000
      expect(r.finalDeduction, greaterThan(0));
    });

    test('card_2: 총급여5천만, 신용카드1,200만 → 최저사용액 미달, 공제 0', () {
      final r = EmployeeTaxCalculator.calculateCreditCardDeduction(
        grossIncome: 50000000,
        creditCard: 12000000, // 12,500,000 미달
        debitCardAndCash: 0,
        traditionalMarket: 0,
        publicTransport: 0,
        cultureExpense: 0,
      );
      expect(r.finalDeduction, 0.0);
    });
  });

  // ──────────────────────────────────────────
  // 혼인·출산 세액공제 (3건) — 자녀세액공제로 대리 검증
  // ──────────────────────────────────────────
  group('자녀세액공제 (2025 귀속 개정)', () {
    test('child_1: 자녀 1명 → 25만', () {
      final credit = EmployeeTaxCalculator.calculateChildTaxCredit(
        childrenCount: 1,
        newbornCount: 0,
      );
      expect(credit, 250000.0);
    });

    test('child_2: 자녀 2명 → 25만 + 30만 = 55만', () {
      final credit = EmployeeTaxCalculator.calculateChildTaxCredit(
        childrenCount: 2,
        newbornCount: 0,
      );
      expect(credit, 550000.0);
    });

    test('child_3: 자녀 3명 → 25+30+40 = 95만', () {
      final credit = EmployeeTaxCalculator.calculateChildTaxCredit(
        childrenCount: 3,
        newbornCount: 0,
      );
      expect(credit, 950000.0);
    });
  });

  // ──────────────────────────────────────────
  // 연금계좌 세액공제 (8건)
  // ──────────────────────────────────────────
  group('연금계좌 세액공제', () {
    test('pension_acc_1: 총급여5,500만이하, 연금저축 600만 → 15% = 90만', () {
      final credit = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
        pensionSavingsPayment: 6000000,
        retirementPensionPayment: 0,
        grossIncome: 55000000,
      );
      expect(credit, 900000.0);
    });

    test('pension_acc_2: 총급여5,500만초과, 연금저축 600만 → 12% = 72만', () {
      final credit = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
        pensionSavingsPayment: 6000000,
        retirementPensionPayment: 0,
        grossIncome: 55000001,
      );
      expect(credit, 720000.0);
    });

    test('pension_acc_3: 연금저축900만 → 한도초과 600만만 인정, 15% = 90만', () {
      final credit = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
        pensionSavingsPayment: 9000000,
        retirementPensionPayment: 0,
        grossIncome: 40000000,
      );
      expect(credit, 900000.0);
    });

    test('pension_acc_4: 연금저축600만+IRP300만 = 합산 900만, 15% = 135만', () {
      final credit = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
        pensionSavingsPayment: 6000000,
        retirementPensionPayment: 3000000,
        grossIncome: 40000000,
      );
      expect(credit, 1350000.0);
    });

    test('pension_acc_5: 연금저축600만+IRP600만 → 합산 한도 900만, 15% = 135만', () {
      final credit = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
        pensionSavingsPayment: 6000000,
        retirementPensionPayment: 6000000,
        grossIncome: 40000000,
      );
      expect(credit, 1350000.0);
    });

    test('pension_acc_6: IRP 300만만 납입 (연금저축 0), 15% = 45만', () {
      final credit = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
        pensionSavingsPayment: 0,
        retirementPensionPayment: 3000000,
        grossIncome: 40000000,
      );
      expect(credit, 450000.0);
    });

    test('pension_acc_7: 납입액 0 → 공제 0', () {
      final credit = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
        pensionSavingsPayment: 0,
        retirementPensionPayment: 0,
        grossIncome: 40000000,
      );
      expect(credit, 0.0);
    });

    test('pension_acc_8: 총급여정확히5,500만, 15% 적용 경계', () {
      final credit = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
        pensionSavingsPayment: 6000000,
        retirementPensionPayment: 0,
        grossIncome: 55000000,
      );
      expect(credit, 900000.0); // ≤ 5,500만이므로 15%
    });
  });

  // ──────────────────────────────────────────
  // 보험료 세액공제 (2건)
  // ──────────────────────────────────────────
  group('보험료 세액공제', () {
    test('insurance_1: 일반100만+장애인100만 → 최대 12만+15만=27만', () {
      final credit = EmployeeTaxCalculator.calculateInsurancePremiumTaxCredit(
        generalInsurancePremium: 1000000,
        disabledInsurancePremium: 1000000,
      );
      expect(credit, 270000.0);
    });

    test('insurance_2: 일반50만 → 50만×12% = 6만', () {
      final credit = EmployeeTaxCalculator.calculateInsurancePremiumTaxCredit(
        generalInsurancePremium: 500000,
        disabledInsurancePremium: 0,
      );
      expect(credit, 60000.0);
    });
  });

  // ──────────────────────────────────────────
  // 의료비 세액공제 (7건)
  // ──────────────────────────────────────────
  group('의료비 세액공제', () {
    // grossIncome의 3% 초과분부터 공제 대상
    // 총급여5천만 → 최저의료비 = 1,500,000

    test('medical_1: 총급여5천만, 일반의료비200만 → 최저미달(200<150), 공제발생', () {
      // 최저의료비 = 5000만 × 3% = 150만
      // 초과분 = 200만 - 150만 = 50만 × 15% = 7.5만
      final r = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: 50000000,
        infertilityMedical: 0,
        selfAndSeniorAndDisabledMedical: 0,
        otherDependentMedical: 2000000,
        childrenEduExpense: 0,
        childrenCount: 0,
        collegeEduExpense: 0,
        collegeCount: 0,
        generalDonation: 0,
        mortgageInterestExpense: 0,
      );
      expect(r.medicalTaxCredit, greaterThan(0));
    });

    test('medical_2: 총급여5천만, 일반의료비100만 → 최저미달(100<150), 공제 0', () {
      final r = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: 50000000,
        infertilityMedical: 0,
        selfAndSeniorAndDisabledMedical: 0,
        otherDependentMedical: 1000000,
        childrenEduExpense: 0,
        childrenCount: 0,
        collegeEduExpense: 0,
        collegeCount: 0,
        generalDonation: 0,
        mortgageInterestExpense: 0,
      );
      expect(r.medicalTaxCredit, 0.0);
    });

    test('medical_3: 난임시술비 300만, 총급여5천만 → 30% 공제율', () {
      // 최저의료비 150만 → 초과분 = 300만-150만 = 150만 × 30% = 45만
      final r = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: 50000000,
        infertilityMedical: 3000000,
        selfAndSeniorAndDisabledMedical: 0,
        otherDependentMedical: 0,
        childrenEduExpense: 0,
        childrenCount: 0,
        collegeEduExpense: 0,
        collegeCount: 0,
        generalDonation: 0,
        mortgageInterestExpense: 0,
      );
      expect(r.medicalTaxCredit, greaterThan(0));
    });

    test('medical_4: 본인의료비 200만 + 일반의료비 200만, 총급여5천만', () {
      // 최저 = 150만
      // 본인분: 200만 × 15% = 30만 (한도 없음)
      // 일반분: (200만 - 150만) × 15% = 7.5만
      // 합계 ≈ 37.5만
      final r = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: 50000000,
        infertilityMedical: 0,
        selfAndSeniorAndDisabledMedical: 2000000,
        otherDependentMedical: 2000000,
        childrenEduExpense: 0,
        childrenCount: 0,
        collegeEduExpense: 0,
        collegeCount: 0,
        generalDonation: 0,
        mortgageInterestExpense: 0,
      );
      expect(r.medicalTaxCredit, greaterThan(0));
    });

    test('medical_5: 일반의료비 한도 700만 초과분 cap 확인', () {
      // 일반 의료비 1,000만 입력해도 700만 한도
      final r1 = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: 50000000,
        infertilityMedical: 0,
        selfAndSeniorAndDisabledMedical: 0,
        otherDependentMedical: 10000000,
        childrenEduExpense: 0,
        childrenCount: 0,
        collegeEduExpense: 0,
        collegeCount: 0,
        generalDonation: 0,
        mortgageInterestExpense: 0,
      );
      final r2 = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: 50000000,
        infertilityMedical: 0,
        selfAndSeniorAndDisabledMedical: 0,
        otherDependentMedical: 20000000,
        childrenEduExpense: 0,
        childrenCount: 0,
        collegeEduExpense: 0,
        collegeCount: 0,
        generalDonation: 0,
        mortgageInterestExpense: 0,
      );
      // 한도 적용으로 공제액이 동일해야 함
      expect(r1.medicalTaxCredit, equals(r2.medicalTaxCredit));
    });

    test('medical_6: 총급여 0 → 최저의료비 0, 전액 공제 대상', () {
      // grossIncome 0이면 최저사용액 0
      final r = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: 0,
        infertilityMedical: 0,
        selfAndSeniorAndDisabledMedical: 0,
        otherDependentMedical: 1000000,
        childrenEduExpense: 0,
        childrenCount: 0,
        collegeEduExpense: 0,
        collegeCount: 0,
        generalDonation: 0,
        mortgageInterestExpense: 0,
      );
      expect(r.medicalTaxCredit, greaterThan(0));
    });

    test('medical_7: 모든 의료비 0 → 공제 0', () {
      final r = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: 50000000,
        infertilityMedical: 0,
        selfAndSeniorAndDisabledMedical: 0,
        otherDependentMedical: 0,
        childrenEduExpense: 0,
        childrenCount: 0,
        collegeEduExpense: 0,
        collegeCount: 0,
        generalDonation: 0,
        mortgageInterestExpense: 0,
      );
      expect(r.medicalTaxCredit, 0.0);
    });
  });

  // ──────────────────────────────────────────
  // 교육비 세액공제 (1건)
  // ──────────────────────────────────────────
  group('교육비 세액공제', () {
    test('edu_1: 대학생 1명 교육비 500만 → 500만×15% = 75만', () {
      final r = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: 50000000,
        infertilityMedical: 0,
        selfAndSeniorAndDisabledMedical: 0,
        otherDependentMedical: 0,
        childrenEduExpense: 0,
        childrenCount: 0,
        collegeEduExpense: 5000000,
        collegeCount: 1,
        generalDonation: 0,
        mortgageInterestExpense: 0,
      );
      expect(r.educationTaxCredit, 750000.0);
    });
  });

  // ──────────────────────────────────────────
  // 기부금 세액공제 (3건)
  // ──────────────────────────────────────────
  group('기부금 세액공제', () {
    test('donation_1: 기부 500만 → 500만×15% = 75만', () {
      final r = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: 50000000,
        infertilityMedical: 0,
        selfAndSeniorAndDisabledMedical: 0,
        otherDependentMedical: 0,
        childrenEduExpense: 0,
        childrenCount: 0,
        collegeEduExpense: 0,
        collegeCount: 0,
        generalDonation: 5000000,
        mortgageInterestExpense: 0,
      );
      expect(r.donationTaxCredit, 750000.0);
    });

    test('donation_2: 기부 1,000만 → 1,000만×15% = 150만', () {
      final r = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: 50000000,
        infertilityMedical: 0,
        selfAndSeniorAndDisabledMedical: 0,
        otherDependentMedical: 0,
        childrenEduExpense: 0,
        childrenCount: 0,
        collegeEduExpense: 0,
        collegeCount: 0,
        generalDonation: 10000000,
        mortgageInterestExpense: 0,
      );
      expect(r.donationTaxCredit, 1500000.0);
    });

    test('donation_3: 기부 1,500만 → 1,000만×15% + 500만×30% = 300만', () {
      final r = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: 50000000,
        infertilityMedical: 0,
        selfAndSeniorAndDisabledMedical: 0,
        otherDependentMedical: 0,
        childrenEduExpense: 0,
        childrenCount: 0,
        collegeEduExpense: 0,
        collegeCount: 0,
        generalDonation: 15000000,
        mortgageInterestExpense: 0,
      );
      expect(r.donationTaxCredit, 3000000.0);
    });
  });

  // ──────────────────────────────────────────
  // 월세 세액공제 (3건)
  // ──────────────────────────────────────────
  group('월세 세액공제', () {
    test('rent_1: 총급여 8,001만원 → 자격 없음', () {
      final eligible = EmployeeTaxCalculator.isRentCreditEligible(
        grossIncome: 80010000,
        globalIncomeAmount: 50000000,
        isHomeless: true,
      );
      expect(eligible, false);
    });

    test('rent_2: 총급여 7천만, 무주택 → 자격 있음 (8천만 기준 이하)', () {
      final eligible = EmployeeTaxCalculator.isRentCreditEligible(
        grossIncome: 70000000,
        globalIncomeAmount: 50000000,
        isHomeless: true,
      );
      expect(eligible, true);
    });

    test('rent_3: 총급여 5천만, 월세60만 → simulateRentRefund 환급 발생', () {
      final r = EmployeeTaxCalculator.simulateRentRefund(
        grossIncome: 50000000,
        monthlyRent: 600000,
        decidedTax: 9999999,
      );
      // 연월세 720만 × 17% = 122.4만
      expect(r.expectedRefund, closeTo(1224000, 1000));
    });

    test('rent_4: 총급여 9천만(8천 초과) → simulateRentRefund 환급 0 (자격 게이트)', () {
      final r = EmployeeTaxCalculator.simulateRentRefund(
        grossIncome: 90000000,
        monthlyRent: 600000,
        decidedTax: 9999999,
      );
      expect(r.expectedRefund, 0);
    });

    test('rent_5: 무주택 아님(isHomeless=false) → simulateRentRefund 환급 0', () {
      final r = EmployeeTaxCalculator.simulateRentRefund(
        grossIncome: 50000000,
        monthlyRent: 600000,
        decidedTax: 9999999,
        isHomeless: false,
      );
      expect(r.expectedRefund, 0);
    });
  });

  // ──────────────────────────────────────────
  // 연금소득공제 (4건) — 신규
  // ──────────────────────────────────────────
  group('연금소득공제', () {
    test('pension_inc_1: 총연금액 350만(1구간) → 공제 = 전액 350만', () {
      final d = EmployeeTaxCalculator.calculatePensionIncomeDeduction(3500000);
      expect(d, 3500000.0);
    });

    test('pension_inc_2: 총연금액 700만(2구간) → 350+(700-350)×0.4 = 490만', () {
      final d = EmployeeTaxCalculator.calculatePensionIncomeDeduction(7000000);
      expect(d, 4900000.0);
    });

    test('pension_inc_3: 총연금액 1억 → 한도 900만', () {
      final d = EmployeeTaxCalculator.calculatePensionIncomeDeduction(100000000);
      expect(d, 9000000.0);
    });

    test('pension_inc_4: 연금소득금액 = 총연금 - 공제, 음수 없음', () {
      final amount = EmployeeTaxCalculator.calculatePensionIncomeAmount(3000000);
      // 300만 ≤ 350만이므로 공제=전액, 소득금액=0
      expect(amount, 0.0);
    });
  });

  // ──────────────────────────────────────────
  // 기타소득금액 (2건) — 신규
  // ──────────────────────────────────────────
  group('기타소득금액', () {
    test('other_1: 총수입 1,000만 → 기타소득금액 = 400만 (60% 필요경비)', () {
      final amount = EmployeeTaxCalculator.calculateOtherIncomeAmount(10000000);
      expect(amount, 4000000.0);
    });

    test('other_2: 기타소득금액 300만 이하 → 분리과세 선택 가능', () {
      final amount = EmployeeTaxCalculator.calculateOtherIncomeAmount(7000000);
      // 700만 × 40% = 280만 ≤ 300만
      final isComprehensive = EmployeeTaxCalculator.isOtherIncomeComprehensive(amount);
      expect(amount, 2800000.0);
      expect(isComprehensive, false);
    });
  });

  // ──────────────────────────────────────────
  // 금융소득 비교과세 (2건)
  // ──────────────────────────────────────────
  group('금융소득 비교과세', () {
    test('fin_1: 금융소득 1,500만 → 분리과세 완납 (2,000만 이하)', () {
      final r = CombinedTaxCalculator.calculateFinancialIncomeTax(
        annualFinancialIncome: 15000000,
        otherTaxableIncome: 30000000,
      );
      expect(r.isSeparateTax, true);
      expect(r.separateTaxAmount, 15000000 * TaxRates.financialIncomeSeparateTaxRate);
      expect(r.additionalTaxBurden, 0.0);
    });

    test('fin_2: 금융소득 3,000만 → 종합과세 대상, 추가세부담 > 0', () {
      final r = CombinedTaxCalculator.calculateFinancialIncomeTax(
        annualFinancialIncome: 30000000,
        otherTaxableIncome: 50000000,
      );
      expect(r.isSeparateTax, false);
      expect(r.additionalTaxBurden, greaterThan(0));
    });
  });

  // ──────────────────────────────────────────
  // 근로소득공제 경계값 (3건)
  // ──────────────────────────────────────────
  group('근로소득공제 경계값', () {
    test('labor_1: 총급여 0 → 공제 0', () {
      expect(EmployeeTaxCalculator.calculateLaborDeduction(0), 0.0);
    });

    test('labor_2: 총급여 3,000만 → 구간3: 750만+(3,000만-1,500만)×15%=975만', () {
      final d = EmployeeTaxCalculator.calculateLaborDeduction(30000000);
      // 750만 + (3,000만-1,500만)*0.15 = 750만 + 225만 = 975만
      expect(d, closeTo(9750000, 1));
    });

    test('labor_3: 총급여 4억 → 한도 2,000만 적용', () {
      // 14,750,000 + (400,000,000 - 100,000,000) × 0.02 = 20,750,000 → 한도 20,000,000
      final d = EmployeeTaxCalculator.calculateLaborDeduction(400000000);
      expect(d, 20000000.0);
    });
  });

  // ──────────────────────────────────────────
  // 세율 누진세 (2건)
  // ──────────────────────────────────────────
  group('누진세율 (tax_rates)', () {
    test('tax_1: 과세표준 1,200만 → 6% = 72만', () {
      final tax = TaxRates.calculateTax(12000000);
      expect(tax, closeTo(720000, 1));
    });

    test('tax_2: 과세표준 5,000만 → 15% 구간 산출세액 (5,000만×15% - 126만 = 624만)', () {
      // 세율표: ≤5,000만 → rate 15%, deduction 1,260,000
      // 50,000,000 × 0.15 - 1,260,000 = 7,500,000 - 1,260,000 = 6,240,000
      final tax = TaxRates.calculateTax(50000000);
      expect(tax, closeTo(6240000, 100));
    });
  });

  // ──────────────────────────────────────────
  // 국민연금 기준소득월액 상·하한 (P1-B)
  // ──────────────────────────────────────────
  group('국민연금 상한 클램프', () {
    test('np_cap_1: 상한 이하(월 500만)는 그대로 4.75% 부과', () {
      final ins = EmployeeTaxCalculator.calculateMonthlyInsurance(5000000);
      expect(ins.nationalPension, TaxRates.truncateWon(5000000 * 0.0475));
    });

    test('np_cap_2: 상한 초과(월 800만)는 상한(617만) 기준으로 클램프', () {
      final ins = EmployeeTaxCalculator.calculateMonthlyInsurance(8000000);
      final expected = TaxRates.truncateWon(TaxRates.nationalPensionBaseUpperLimit * 0.0475);
      expect(ins.nationalPension, expected);
      // 상한 미적용 시(8백만×4.75%)보다 작아야 한다.
      expect(ins.nationalPension, lessThan(8000000 * 0.0475));
    });

    test('np_cap_3: 건강보험은 상한 클램프 대상 아님(월급 비례 유지)', () {
      final ins = EmployeeTaxCalculator.calculateMonthlyInsurance(8000000);
      expect(ins.healthInsurance, TaxRates.truncateWon(8000000 * 0.03595));
    });
  });

  // ──────────────────────────────────────────
  // InsuranceEngine 국민연금 요율 (D-2: 4.5%→4.75%, 9.0%→9.5% 정정 확인)
  // ──────────────────────────────────────────
  group('InsuranceEngine 국민연금 요율 (D-2)', () {
    test('employee_np: 직장인 본인부담 4.75% 부과(상한 이하 월 500만)', () {
      final ins = InsuranceEngine.calculateEmployeeInsurance(5000000);
      expect(ins.nationalPension, TaxRates.truncateWon(5000000 * InsuranceEngine.empNationalPensionRate));
      expect(InsuranceEngine.empNationalPensionRate, 0.0475);
    });

    test('freelancer_np: 지역가입자 9.5% 부과(연 6천만원, 상한 이하)', () {
      final ins = InsuranceEngine.calculateFreelancerInsurance(
        annualIncome: 60000000,
        propertyValue: 0,
      );
      const monthlyIncome = 60000000 / 12;
      expect(ins.nationalPension, TaxRates.truncateWon(monthlyIncome * InsuranceEngine.freeNationalPensionRate));
      expect(InsuranceEngine.freeNationalPensionRate, 0.095);
    });

    test('njob_health: N잡러 소득월액 건보료는 7.19% 전체 요율 적용', () {
      final result = InsuranceEngine.calculateNJobExtraInsurance(50000000);
      const taxableMonthlyIncome = (50000000 - 20000000) / 12;
      expect(result.extraHealthInsurance, TaxRates.truncateWon(taxableMonthlyIncome * InsuranceEngine.njobHealthInsuranceRate));
      expect(InsuranceEngine.njobHealthInsuranceRate, 0.0719);
    });

    test('pension_bounds: 기준소득월액 상·하한이 TaxRates와 동일 출처(659만/41만)', () {
      expect(InsuranceEngine.pensionUpperBound, TaxRates.nationalPensionBaseUpperLimit);
      expect(InsuranceEngine.pensionLowerBound, TaxRates.nationalPensionBaseLowerLimit);
      expect(InsuranceEngine.pensionUpperBound, 6590000.0);
      expect(InsuranceEngine.pensionLowerBound, 410000.0);
    });
  });

  // ──────────────────────────────────────────
  // 세금 적립 min~max 범위 (단순경비율 vs 기준경비율)
  // ──────────────────────────────────────────
  group('프리랜서 세금 적립 범위', () {
    test('range_1: 업종코드 011001(단순93.5% vs 기준9.7%) → min <= max', () {
      final range = FreelancerTaxCalculator.calculateTaxRange(
        accumulatedIncome: 60000000,
        inputMonths: 6,
        allowanceCount: 0,
        occupationCode: '011001',
      );
      expect(range.min.annualTotalTax, lessThanOrEqualTo(range.max.annualTotalTax));
      // 경비율 격차가 커서 두 시나리오 결과가 달라야 한다.
      expect(range.min.annualTotalTax, isNot(equals(range.max.annualTotalTax)));
    });

    test('range_2: 미등록 업종코드(경비율 0%) → min == max(둘 다 경비 미인정)', () {
      final range = FreelancerTaxCalculator.calculateTaxRange(
        accumulatedIncome: 30000000,
        inputMonths: 6,
        allowanceCount: 0,
        occupationCode: 'unknown_code',
      );
      expect(range.min.annualTotalTax, range.max.annualTotalTax);
    });
  });

  group('N잡러 세금 적립 범위', () {
    test('range_3: 업종코드 011001 사업소득 병행 → min <= max', () {
      final range = CombinedTaxCalculator.calculateTaxRange(
        grossIncome: 40000000,
        accumulatedFreelancerIncome: 30000000,
        inputMonths: 6,
        occupationCode: '011001',
        creditCard: 0,
        debitCardAndCash: 0,
        traditionalMarket: 0,
        publicTransport: 0,
        cultureExpense: 0,
        allowanceCount: 0,
        decidedTax: 0,
        monthlyRent: 0,
      );
      expect(range.min.annualTotalTax, lessThanOrEqualTo(range.max.annualTotalTax));
    });
  });

  group('고향사랑기부금 세액공제 (조특법 §58, 2026 개정)', () {
    // 소득공제가 아니라 세액공제다. 과거 앱은 기부액 전액을 과세표준에서 빼
    // 저소득자에겐 과소·고소득자에겐 과대 계산했다.
    double credit(double d) =>
        EmployeeTaxCalculator.calculateHometownDonationTaxCredit(d);

    test('10만원 이하 — 110분의 100', () {
      expect(credit(100000), 90900); // 90,909 → 10원 절사
    });
    test('10만~20만 구간 — 40% (2026 신설)', () {
      // 10만×100/110 + 10만×40% = 90,909 + 40,000 = 130,909
      expect(credit(200000), 130900);
    });
    test('20만 초과분 — 15%', () {
      // 130,909 + 80만×15% = 130,909 + 120,000 = 250,909
      expect(credit(1000000), 250900);
    });
    test('연 2천만원 한도', () {
      expect(credit(30000000), credit(20000000));
    });
    test('0 이하는 0', () {
      expect(credit(0), 0);
      expect(credit(-1), 0);
    });
  });

  // 소득세법 §59의2① 개정(법률 제21548호, 2026.4.21. 공포·시행) — 아동수당 연령
  // 상향에 맞춰 자녀세액공제 대상 연령이 2030년까지 매년 한 살씩 올라간다.
  // 부칙 §2②는 2026~2029 경과 연령을, §2③은 2017년생 배제를 정한다.
  group('자녀세액공제 대상 연령 (소득세법 §59의2① + 부칙 §2)', () {
    test('경과 연령 — 2026년 9세부터 2029년 12세, 2030년부터 본칙 13세', () {
      expect(TaxRates.childTaxCreditMinAge(2025), 8);
      expect(TaxRates.childTaxCreditMinAge(2026), 9);
      expect(TaxRates.childTaxCreditMinAge(2027), 10);
      expect(TaxRates.childTaxCreditMinAge(2028), 11);
      expect(TaxRates.childTaxCreditMinAge(2029), 12);
      expect(TaxRates.childTaxCreditMinAge(2030), 13);
      expect(TaxRates.childTaxCreditMinAge(2031), 13);
    });

    test('출생연도 상한 — 2017년생 배제(부칙 §2③)로 2026~2029는 2016년생에 고정', () {
      // 나이 = 귀속연도 − 출생연도 (국세청 연말정산 안내의 인적공제 연령 환산과 동일)
      expect(TaxRates.childTaxCreditBirthYearCutoff(2025), 2017);
      expect(TaxRates.childTaxCreditBirthYearCutoff(2026), 2016);
      expect(TaxRates.childTaxCreditBirthYearCutoff(2027), 2016);
      expect(TaxRates.childTaxCreditBirthYearCutoff(2028), 2016);
      expect(TaxRates.childTaxCreditBirthYearCutoff(2029), 2016);
      // 본칙(13세)이 적용되는 2030 귀속에 2017년생이 들어온다.
      expect(TaxRates.childTaxCreditBirthYearCutoff(2030), 2017);
      expect(TaxRates.childTaxCreditBirthYearCutoff(2031), 2018);
    });

    test('화면 문구는 출생연도로 못박는다 — 만/연 나이 혼동 방지', () {
      expect(TaxRates.childTaxCreditEligibilityLabel(2026), '2016년생 이하');
      expect(TaxRates.childTaxCreditEligibilityLabel(2025), '2017년생 이하');
      // 인자를 안 주면 앱 기준 귀속연도
      expect(TaxRates.childTaxCreditEligibilityLabel(),
          TaxRates.childTaxCreditEligibilityLabel(kReferenceTaxYear));
    });

    test('금액 산식은 그대로 — 첫째 25만·둘째 55만·셋째부터 +40만', () {
      expect(TaxRates.calculateChildTaxCredit(1), 250000);
      expect(TaxRates.calculateChildTaxCredit(2), 550000);
      expect(TaxRates.calculateChildTaxCredit(3), 950000);
      expect(TaxRates.calculateChildTaxCredit(0), 0);
    });
  });

  // 4대보험 요율·상하한 — 전부 법령/고시 원문 대조(2026-07-27).
  //   국민연금법 §88③④ + 부칙 <법률 제20903호> §4
  //   국민건강보험법 시행령 §44 / 보건복지부고시 제2025-222호
  //   노인장기요양보험법 §9① + 시행령 §4
  //   보험료징수법 시행령 §12①2 · §56의7④
  group('4대보험 요율·상하한 (법령 원문)', () {
    test('요율 상수가 조문값과 일치한다', () {
      expect(InsuranceEngine.empNationalPensionRate, 0.0475);   // 1만분의 475 (2026년)
      expect(InsuranceEngine.freeNationalPensionRate, 0.095);   // 1천분의 95 (2026년)
      expect(InsuranceEngine.healthInsuranceRate, 0.0719);      // 1만분의 719
      expect(InsuranceEngine.empHealthInsuranceRate, 0.03595);  // 노사 각 1/2
      expect(InsuranceEngine.njobHealthInsuranceRate, 0.0719);  // 전액 부과
      expect(InsuranceEngine.healthScoreUnitAmount, 211.5);     // 재산보험료부과점수당 금액
      expect(InsuranceEngine.longTermCareInsuranceRate, 0.009448); // 100만분의 9,448
      expect(InsuranceEngine.empEmploymentInsuranceRate, 0.0090);  // 1천분의 18 ÷ 2
      expect(InsuranceEngine.specialWorkerEmploymentRate, 0.008);  // 1천분의 16 ÷ 2
    });

    test('장기요양은 건강보험료 대비 비율 — 법 §9①', () {
      // 상수를 나눗셈으로 두면 두 요율 중 하나만 개정돼도 비율이 따라간다.
      expect(InsuranceEngine.longTermCareRate, closeTo(0.009448 / 0.0719, 1e-12));
      expect(InsuranceEngine.longTermCareRate, closeTo(0.131405, 1e-6));
    });

    test('직장 건강보험료는 보험료액에 상·하한 — 소득이 아니다', () {
      // 하한 20,160원의 본인부담 절반
      final low = InsuranceEngine.calculateEmployeeInsurance(100000);
      expect(low.healthInsurance, 10080);
      // 상한 9,183,480원의 본인부담 절반
      final high = InsuranceEngine.calculateEmployeeInsurance(200000000);
      expect(high.healthInsurance, 4591740);
      // 종전 구현은 소득에 캡을 걸어 하한이 10,089원으로 어긋났다.
    });

    test('국민연금은 기준소득월액(소득)에 상·하한', () {
      final high = InsuranceEngine.calculateEmployeeInsurance(200000000);
      expect(high.nationalPension,
          TaxRates.truncateWon(TaxRates.nationalPensionBaseUpperLimit * 0.0475));
      final low = InsuranceEngine.calculateEmployeeInsurance(100000);
      expect(low.nationalPension,
          TaxRates.truncateWon(TaxRates.nationalPensionBaseLowerLimit * 0.0475));
    });

    test('N잡러 소득월액보험료 상한은 4,591,740원 (하한 없음)', () {
      // 보수외소득 연 100억 → 상한에 걸려야 한다.
      final r = InsuranceEngine.calculateNJobExtraInsurance(10000000000);
      expect(r.extraHealthInsurance, 4591740);
      // 2천만원 이하는 부과 자체가 없다.
      expect(InsuranceEngine.calculateNJobExtraInsurance(20000000).extraHealthInsurance, 0);
    });

    test('노무제공자 산재보험료율 — 고시 요율의 1/2이 본인부담', () {
      // 고용노동부고시 제2025-92호 (단위 ‰) ÷ 2 (징수법 §48의6⑥·시행령 §56의10)
      expect(specialWorkerIndustrialRates['940918'], 0.017 / 2); // 늘찬배달원 17‰
      expect(specialWorkerIndustrialRates['940906'], 0.005 / 2); // 보험설계사 5‰
      expect(specialWorkerIndustrialRates['940913'], 0.018 / 2); // 대리운전 18‰
      expect(specialWorkerIndustrialRates['940903'], 0.007 / 2); // 방문강사 7‰
    });

    test('지역가입자는 소득분+재산분 합계에 상·하한', () {
      final high = InsuranceEngine.calculateFreelancerInsurance(
          annualIncome: 10000000000, propertyValue: 0);
      expect(high.healthInsurance, 4591740);
      final low = InsuranceEngine.calculateFreelancerInsurance(
          annualIncome: 120000, propertyValue: 0);
      expect(low.healthInsurance, 20160);
      // 소득·재산이 모두 없으면 부과하지 않는다.
      final none = InsuranceEngine.calculateFreelancerInsurance(
          annualIncome: 0, propertyValue: 0);
      expect(none.healthInsurance, 0);
    });
  });

  // 자녀세액공제(소득세법 §59의2)는 "종합소득이 있는 거주자"가 대상이다.
  // ①(기본)과 ③(출산·입양)을 ④가 묶어 '자녀세액공제'라 부른다 — 프리랜서도 둘 다 받는다.
  // 앱은 오랫동안 프리랜서에게 ①만 주고 ③을 빠뜨렸다.
  group('프리랜서 출산·입양 세액공제 (소득세법 §59의2③)', () {
    FreelancerTaxResult run({int children = 0, int newborn = 0}) =>
        FreelancerTaxCalculator.calculateTaxSimulation(
          accumulatedIncome: 60000000,
          inputMonths: 12,
          allowanceCount: 0,
          occupationCode: '940909',
          childrenCountForCredit: children,
          newbornCount: newborn,
        );

    test('출산 1명 → 30만원이 자녀세액공제에 더해진다', () {
      expect(run(newborn: 1).childTaxCredit - run().childTaxCredit, 300000);
    });

    test('둘째 50만·셋째 이상 70만 — 직장인 산식과 같다', () {
      expect(run(newborn: 2).childTaxCredit, 800000);   // 30만 + 50만
      expect(run(newborn: 3).childTaxCredit, 1500000);  // + 70만
    });

    test('기본 자녀공제와 합산된다 (①+③)', () {
      // 자녀 1명(25만) + 출산 1명(30만) = 55만
      expect(run(children: 1, newborn: 1).childTaxCredit, 550000);
    });

    test('출산이 없으면 종전과 동일 — 회귀 없음', () {
      expect(run(children: 2).childTaxCredit, 550000);
    });
  });

  // 아무것도 입력하지 않은 상태에서 totalSpend와 threshold가 둘 다 0이라
  // `0 >= 0`으로 "🎉 25% 문턱 돌파!"가 떴다. 빈 화면이 사용자에게 거짓말을 했다.
  group('카드공제 문턱 안내', () {
    CreditCardDeductionResult run({double gross = 0, double credit = 0}) =>
        EmployeeTaxCalculator.calculateCreditCardDeduction(
          grossIncome: gross,
          creditCard: credit,
          debitCardAndCash: 0,
          traditionalMarket: 0,
          publicTransport: 0,
          cultureExpense: 0,
        );

    test('아무것도 안 넣었으면 돌파가 아니다', () {
      expect(run().passedThreshold, isFalse);
      expect(run(gross: 45000000).passedThreshold, isFalse);
    });

    test('문턱을 못 넘으면 돌파가 아니다', () {
      // 총급여 4,500만 → 문턱 1,125만
      expect(run(gross: 45000000, credit: 5000000).passedThreshold, isFalse);
    });

    test('문턱을 넘으면 돌파다', () {
      expect(run(gross: 45000000, credit: 20000000).passedThreshold, isTrue);
    });

    test('쓴 게 없으면 안내 문구가 다음 할 일을 말한다', () {
      expect(run(gross: 45000000).guideMessage, contains('넣으면'));
    });
  });
}
