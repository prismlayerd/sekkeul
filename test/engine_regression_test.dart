import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/combined_tax.dart';
import 'package:secul/core/tax_engine/freelancer_tax.dart';
import 'package:secul/core/tax_engine/tax_rates.dart';
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
}
