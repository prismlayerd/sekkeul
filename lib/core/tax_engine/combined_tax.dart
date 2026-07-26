import 'package:intl/intl.dart';

import '../data/occupation_data.dart';
import 'employee_tax.dart';
import 'tax_rates.dart';

/// N잡러(근로소득 + 프리랜서/투잡) 전용 통합 세액 계산 및 시뮬레이션 엔진
class CombinedTaxCalculator {
  
  /// 금융소득 (이자·배당) 건보료 산정용 소득금액 도출식
  /// 연 1,000만 원 초과 시 전액 100% 소득금액으로 잡힘.
  static double calculateFinancialIncomeAmount(double annualFinancialIncome) {
    if (annualFinancialIncome > 10000000) {
      return annualFinancialIncome;
    }
    return 0.0;
  }

  /// 주택임대소득 분리과세(연 2,000만 원 이하) 건보료/세금 산정용 소득금액 도출식
  static double calculateRentalIncomeAmount({
    required double annualRentalIncome,
    required bool isRegisteredLandlord, // 등록 임대사업자 여부
    required bool isOtherIncomeUnder20M, // 임대소득 외 종합소득이 2,000만 원 이하인지 여부
  }) {
    final double basicDeduction = isRegisteredLandlord ? 4000000.0 : 2000000.0;
    final double taxablePortion = isRegisteredLandlord
        ? annualRentalIncome * 0.40
        : annualRentalIncome * 0.50;
    
    double incomeAmount = taxablePortion;
    
    // 타 소득 2천만원 이하일 때만 기본공제 적용
    if (isOtherIncomeUnder20M) {
      incomeAmount -= basicDeduction;
    }
    
    return incomeAmount < 0 ? 0.0 : incomeAmount;
  }

  /// N잡러 (본업 직장인 + 부업 프리랜서) 종합소득세 시뮬레이션
  static CombinedTaxResult calculateCombinedTax({
    required double grossIncome,
    required double accumulatedFreelancerIncome,
    required int inputMonths,
    required String occupationCode,
    required double creditCard,
    required double debitCardAndCash,
    required double traditionalMarket,
    required double publicTransport,
    required double cultureExpense,
    required int allowanceCount,
    required double decidedTax,
    required double monthlyRent,
    double yellowUmbrellaPayment = 0.0,
    bool isHomeless = false,
    double pensionIncome = 0.0,
    double otherIncome = 0.0,
    double insurancePremium = 0.0,
    double disabledInsurancePremium = 0.0,
    int childrenCount8Plus = 0,
    /// 자녀등 총 수 — 카드공제 기본한도 상향용(8세 미만 자녀·손자녀 포함).
    int childrenCountTotal = 0,
    int newbornCount = 0,
    double pensionSavings = 0.0,
    double irpPayment = 0.0,
    // 추가 인적공제 (프로필 자동 로드)
    bool hasElderly70Plus = false,
    bool isSingleParent = false,
    bool isSingleFemaleHead = false,
    // 소득공제 추가항목
    double mortgageInterest = 0.0,
    double hometownDonation = 0.0,
    // 민감항목 세액공제
    double infertilityMedical = 0.0,
    double selfSeniorDisabledMedical = 0.0,
    double otherDependentMedical = 0.0,
    double generalDonation = 0.0,
    double childrenEdu = 0.0,
    int childrenEduCount = 0,
    double collegeEdu = 0.0,
    int collegeEduCount = 0,
    // 혼인세액공제
    bool weddingCredit2426 = false,
    // 중소기업취업자 소득세 감면
    bool isSmeEmployee = false,
    int smeStartYear = 0,
    bool isYouthSme = false, // 청년 트랙(90%·5년) 여부 — 나이·군복무로 판정
    bool useStandardExpenseRate = false, // true면 단순경비율 대신 기준경비율(적립 범위 산출용) — 사업소득에만 적용
  }) {
    final months = inputMonths < 1 ? 1 : (inputMonths > 12 ? 12 : inputMonths);
    final freelancerIncome = accumulatedFreelancerIncome < 0 ? 0.0 : accumulatedFreelancerIncome;
    final dependents = allowanceCount < 0 ? 0 : allowanceCount;

    final double laborDeduction = EmployeeTaxCalculator.calculateLaborDeduction(grossIncome);
    final double laborIncomeAmount = grossIncome - laborDeduction;

    final double annualEstimatedFreelancerIncome = (freelancerIncome / months) * 12;

    final occupation = OccupationData.occupations[occupationCode];
    final double simpleBaseRate = (occupation?.simpleBaseRate ?? 0.0) / 100.0;
    double simpleExcessRate = (occupation?.simpleExcessRate ?? 0.0) / 100.0;
    if (simpleExcessRate == 0.0) {
      simpleExcessRate = simpleBaseRate;
    }
    final double standardExpenseRate = (occupation?.standardRate ?? 0.0) / 100.0;

    double estimatedFreelancerExpense = 0.0;
    if (useStandardExpenseRate) {
      estimatedFreelancerExpense = annualEstimatedFreelancerIncome * standardExpenseRate;
    } else if (annualEstimatedFreelancerIncome <= 40000000) {
      estimatedFreelancerExpense = annualEstimatedFreelancerIncome * simpleBaseRate;
    } else {
      estimatedFreelancerExpense = (40000000 * simpleBaseRate) +
          ((annualEstimatedFreelancerIncome - 40000000) * simpleExcessRate);
    }
    
    final double estimatedFreelancerBusinessIncome = annualEstimatedFreelancerIncome - estimatedFreelancerExpense;
    final double pensionIncomeAmount = EmployeeTaxCalculator.calculatePensionIncomeAmount(pensionIncome);
    final double otherIncomeAmount = EmployeeTaxCalculator.calculateOtherIncomeAmount(otherIncome);
    // 기타소득 분리과세 선택 여부는 소득공제 합계가 나온 뒤 판정하므로,
    // 종합소득금액은 일단 기타소득 제외분으로 계산해 둔다.
    final double globalIncomeWithoutOther = laborIncomeAmount + estimatedFreelancerBusinessIncome + pensionIncomeAmount;

    final double personalDeduction = (dependents + 1) * TaxRates.basicDeductionPerPerson;
    final double additionalPersonalDed = EmployeeTaxCalculator.calculateAdditionalPersonalDeduction(
      hasElderly70Plus: hasElderly70Plus,
      isSingleFemaleHead: isSingleFemaleHead,
      isSingleParent: isSingleParent,
    );

    final cardResult = EmployeeTaxCalculator.calculateCreditCardDeduction(
      grossIncome: grossIncome,
      creditCard: creditCard,
      debitCardAndCash: debitCardAndCash,
      traditionalMarket: traditionalMarket,
      publicTransport: publicTransport,
      cultureExpense: cultureExpense,
      // 카드공제 기본한도는 자녀등 수에 따라 올라간다(조특법 §126의2⑩, 2026 개정 —
      // 2026.1.1. 이후 사용분부터. 개정세법 해설 2026 p.216~217).
      childrenCount: childrenCountTotal,
    );
    final double cardDeduction = cardResult.finalDeduction;

    // 노란우산공제(소기업·소상공인 공제부금) 한도 — 2025~2026 귀속 동일
    // 사업소득금액 4천만 이하 600만 / 6천만 이하 500만 / 1억 이하 400만 / 1억 초과 200만
    double yellowUmbrellaLimit = 0.0;
    if (estimatedFreelancerBusinessIncome <= 40000000) {
      yellowUmbrellaLimit = 6000000.0;
    } else if (estimatedFreelancerBusinessIncome <= 60000000) {
      yellowUmbrellaLimit = 5000000.0;
    } else if (estimatedFreelancerBusinessIncome <= 100000000) {
      yellowUmbrellaLimit = 4000000.0;
    } else {
      yellowUmbrellaLimit = 2000000.0;
    }
    final double yellowUmbrellaDeduction = yellowUmbrellaPayment < yellowUmbrellaLimit ? yellowUmbrellaPayment : yellowUmbrellaLimit;

    // 4대보험 소득공제 (연금보험료공제 §51의3 + 특별소득공제 보험료 §52①)
    final InsuranceDeduction insDeduction = EmployeeTaxCalculator.calculateAnnualInsuranceDeduction(grossIncome / 12);
    final double mortgageDeduction = EmployeeTaxCalculator.calculateMortgageIncomeDeduction(mortgageInterest);
    // 고향사랑기부금은 소득공제가 아니라 세액공제(조특법 §58)라 여기서 빼지 않는다.
    final double deductionTotal = personalDeduction + additionalPersonalDed + cardDeduction
        + yellowUmbrellaDeduction + insDeduction.total + mortgageDeduction;

    // 기타소득 분리과세 선택 (소득세법 §14③8): 기타소득금액 300만원 이하(원천징수분)는
    // 종합과세와 분리과세(원천징수 8.8%로 종결) 중 유리한 쪽 선택 가능 — 합산 시
    // 한계세액(지방세 포함)이 원천징수액보다 크면 분리과세를 택한다.
    double taxBaseWithoutOther = globalIncomeWithoutOther - deductionTotal;
    if (taxBaseWithoutOther < 0) taxBaseWithoutOther = 0;
    double taxBaseWithOther = globalIncomeWithoutOther + otherIncomeAmount - deductionTotal;
    if (taxBaseWithOther < 0) taxBaseWithOther = 0;

    bool otherIncomeComprehensive = true;
    if (otherIncomeAmount > 0 && !EmployeeTaxCalculator.isOtherIncomeComprehensive(otherIncomeAmount)) {
      final double marginalComprehensiveTax =
          (TaxRates.calculateTax(taxBaseWithOther) - TaxRates.calculateTax(taxBaseWithoutOther)) * 1.1;
      final double separateFinalTax = otherIncome *
          (TaxRates.otherIncomeWithholdingRate + TaxRates.otherIncomeLocalWithholdingRate);
      if (marginalComprehensiveTax > separateFinalTax) otherIncomeComprehensive = false;
    }

    final double totalGlobalIncome =
        globalIncomeWithoutOther + (otherIncomeComprehensive ? otherIncomeAmount : 0.0);
    final double taxBase = otherIncomeComprehensive ? taxBaseWithOther : taxBaseWithoutOther;

    final double estimatedCalculatedTax = TaxRates.calculateTax(taxBase);

    double laborCalculatedTaxShare = 0.0;
    if (totalGlobalIncome > 0) {
      laborCalculatedTaxShare = estimatedCalculatedTax * (laborIncomeAmount / totalGlobalIncome);
    }
    // 중소기업취업자 감면(조특법 §30, 조특령 §27⑧)은 근로소득분 산출세액에만 걸린다 —
    // 감면세액 = 종합소득산출세액 × (근로소득금액/종합소득금액) × 감면급여비율.
    // 종합 산출세액 전체를 넘기면 부업 사업소득분까지 감면돼 세금이 과소해진다.
    // (감면대상 근무처가 하나라고 보고 감면급여비율은 1.) 확인일 2026-07-25.
    final double smeExemptionAmt = (isSmeEmployee && smeStartYear > 0)
        ? EmployeeTaxCalculator.calculateSmeExemption(
            calculatedTax: laborCalculatedTaxShare,
            smeStartYear: smeStartYear,
            isYouth: isYouthSme)
        : 0.0;
    // 감면을 받는 해에는 근로소득세액공제가 감면세액 비율만큼 깎인다
    // (국세청: 근로세액공제 × [1 - 감면세액/근로소득 산출세액]).
    final double laborTaxCredit = EmployeeTaxCalculator.laborTaxCreditAfterSmeExemption(
      laborTaxCredit: EmployeeTaxCalculator.calculateLaborTaxCredit(
        grossIncome: grossIncome,
        calculatedTaxShare: laborCalculatedTaxShare,
      ),
      smeExemption: smeExemptionAmt,
      laborCalculatedTax: laborCalculatedTaxShare,
    );

    // 월세 세액공제 (조특법 §95의2, 2024 귀속~): 총급여 8천만·종합소득금액 7천만 이하·무주택 세대주
    double rawRentTaxCredit = 0.0;
    if (monthlyRent > 0 && EmployeeTaxCalculator.isRentCreditEligible(
      grossIncome: grossIncome,
      globalIncomeAmount: totalGlobalIncome,
      isHomeless: isHomeless,
    )) {
      final double annualRent = monthlyRent * 12;
      final double rentLimit = annualRent > 10000000.0 ? 10000000.0 : annualRent;
      // 17% 구간은 총급여 5,500만 이하 **그리고** 종합소득금액 4,500만 이하일 때만이다
      // (조특법 §95의2 — "종합소득금액이 4천5백만원을 초과하는 사람은 제외").
      // N잡러는 부업 소득 때문에 총급여가 낮아도 종합소득금액이 4,500만을 넘기 쉬워,
      // 총급여만 보면 15%여야 할 사람에게 17%를 줘 환급이 과대해진다. 확인일 2026-07-25.
      final double rentCreditRate =
          (grossIncome <= 55000000.0 && totalGlobalIncome <= 45000000.0) ? 0.17 : 0.15;
      rawRentTaxCredit = rentLimit * rentCreditRate;
    }

    final double insuranceTaxCreditAmt = EmployeeTaxCalculator.calculateInsurancePremiumTaxCredit(
      generalInsurancePremium: insurancePremium,
      disabledInsurancePremium: disabledInsurancePremium,
    );
    final double childTaxCreditAmt = EmployeeTaxCalculator.calculateChildTaxCredit(
      childrenCount: childrenCount8Plus,
      newbornCount: newbornCount,
    );
    final double pensionTaxCreditAmt = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
      pensionSavingsPayment: pensionSavings,
      retirementPensionPayment: irpPayment,
      grossIncome: grossIncome,
    );
    final double medicalTaxCreditAmt = EmployeeTaxCalculator.calculateMedicalTaxCredit(
      grossIncome: grossIncome,
      infertilityExpense: infertilityMedical,
      selfAndSeniorAndDisabledExpense: selfSeniorDisabledMedical,
      otherDependentExpense: otherDependentMedical,
    );
    final double educationTaxCreditAmt = EmployeeTaxCalculator.calculateEducationTaxCredit(
      preschoolExpense: 0,
      preschoolCount: 0,
      childrenExpense: childrenEdu,
      childrenCount: childrenEduCount,
      collegeExpense: collegeEdu,
      collegeCount: collegeEduCount,
      selfExpense: 0,
      disabledSpecialExpense: 0,
    );
    final double donationTaxCreditAmt = EmployeeTaxCalculator.calculateDonationTaxCredit(
      generalDonation: generalDonation,
      politicalDonation: 0,
    );
    final double weddingTaxCreditAmt = weddingCredit2426 ? TaxRates.marriageTaxCredit : 0.0;
    final double hometownTaxCreditAmt =
        EmployeeTaxCalculator.calculateHometownDonationTaxCredit(hometownDonation);

    double estimatedIncomeTax = estimatedCalculatedTax - smeExemptionAmt - laborTaxCredit - rawRentTaxCredit
        - insuranceTaxCreditAmt - childTaxCreditAmt - pensionTaxCreditAmt
        - medicalTaxCreditAmt - educationTaxCreditAmt - donationTaxCreditAmt - weddingTaxCreditAmt
        - hometownTaxCreditAmt;
    if (estimatedIncomeTax < 0) estimatedIncomeTax = 0;
    
    final double finalIncomeTax = TaxRates.truncateWon(estimatedIncomeTax);
    final double finalLocalTax = TaxRates.truncateWon(finalIncomeTax * 0.1);
    final double finalTotalTax = finalIncomeTax + finalLocalTax;

    final double freelancerPaidIncomeTax = TaxRates.truncateWon(freelancerIncome * TaxRates.freelancerWithholdingRate);
    final double freelancerPaidLocalTax = TaxRates.truncateWon(freelancerIncome * TaxRates.freelancerLocalWithholdingRate);
    final double freelancerPaidTotal = freelancerPaidIncomeTax + freelancerPaidLocalTax;

    final double annualFreelancerWithholdingIncome = TaxRates.truncateWon(annualEstimatedFreelancerIncome * TaxRates.freelancerWithholdingRate);
    final double annualFreelancerWithholdingLocal = TaxRates.truncateWon(annualEstimatedFreelancerIncome * TaxRates.freelancerLocalWithholdingRate);
    final double annualEstimatedFreelancerWithholdingTotal = annualFreelancerWithholdingIncome + annualFreelancerWithholdingLocal;

    // 기타소득 8.8% 원천징수분 — 종합과세 선택 시에만 기납부세액으로 공제
    // (분리과세 선택 시 원천징수로 과세 종결이라 신고·정산 대상이 아님).
    final double annualOtherWithholdingIncome = otherIncomeComprehensive
        ? TaxRates.truncateWon(otherIncome * TaxRates.otherIncomeWithholdingRate)
        : 0.0;
    final double annualOtherWithholdingLocal = otherIncomeComprehensive
        ? TaxRates.truncateWon(otherIncome * TaxRates.otherIncomeLocalWithholdingRate)
        : 0.0;

    final double annualEstimatedTotalWithholding = decidedTax + annualEstimatedFreelancerWithholdingTotal
        + annualOtherWithholdingIncome + annualOtherWithholdingLocal;

    final double expectedRefundOrPayment = annualEstimatedTotalWithholding - finalTotalTax;
    final double expectedIncomeTaxRefundOrPayment =
        (decidedTax + annualFreelancerWithholdingIncome + annualOtherWithholdingIncome) - finalIncomeTax;
    final double expectedLocalTaxRefundOrPayment =
        (decidedTax * 0.1 + annualFreelancerWithholdingLocal + annualOtherWithholdingLocal) - finalLocalTax;

    double monthlyReserve = 0.0;
    String reserveNudgeMessage = '';

    if (expectedRefundOrPayment < 0) {
      final double additionalPayment = expectedRefundOrPayment.abs();
      final int remainingMonths = 12 - months;

      if (remainingMonths > 0) {
        monthlyReserve = additionalPayment / remainingMonths;
        monthlyReserve = TaxRates.truncateWon(monthlyReserve);
        reserveNudgeMessage = 'N잡러 수입 합산으로 인해 이번 달 소득에 대해 ${NumberFormat('#,###').format(monthlyReserve.toInt())}원을 준비해 주세요.';
      } else {
        monthlyReserve = TaxRates.truncateWon(additionalPayment);
        reserveNudgeMessage = '내년 5월 종합소득세 신고 시 요긴하게 쓰실 수 있도록 ${NumberFormat('#,###').format(monthlyReserve.toInt())}원을 준비해 주세요.';
      }
    } else {
      reserveNudgeMessage = '현재 환급이 예상되는 상태입니다! 신호등 넛지 지침에 맞춰 현명하게 지출하세요.';
    }

    return CombinedTaxResult(
      annualEstimatedIncome: annualEstimatedFreelancerIncome + grossIncome,
      laborIncomeAmount: laborIncomeAmount,
      estimatedFreelancerBusinessIncome: estimatedFreelancerBusinessIncome,
      pensionIncomeAmount: pensionIncomeAmount,
      otherIncomeAmount: otherIncomeAmount,
      totalGlobalIncome: totalGlobalIncome,
      taxBase: taxBase,
      calculatedTax: estimatedCalculatedTax,
      annualIncomeTax: finalIncomeTax,
      annualLocalTax: finalLocalTax,
      annualTotalTax: finalTotalTax,
      paidTotalWithholding: freelancerPaidTotal + decidedTax,
      annualEstimatedTotalWithholding: annualEstimatedTotalWithholding,
      expectedRefundOrPayment: expectedRefundOrPayment,
      expectedIncomeTaxRefundOrPayment: expectedIncomeTaxRefundOrPayment,
      expectedLocalTaxRefundOrPayment: expectedLocalTaxRefundOrPayment,
      monthlyReserve: monthlyReserve,
      reserveNudgeMessage: reserveNudgeMessage,
      cardResult: cardResult,
      rentTaxCredit: rawRentTaxCredit,
      yellowUmbrellaDeduction: yellowUmbrellaDeduction,
      yellowUmbrellaLimit: yellowUmbrellaLimit,
      insuranceDeduction: insDeduction.total,
      insuranceTaxCredit: insuranceTaxCreditAmt,
      childTaxCredit: childTaxCreditAmt,
      pensionTaxCredit: pensionTaxCreditAmt,
      additionalPersonalDeduction: additionalPersonalDed,
      mortgageDeduction: mortgageDeduction,
      hometownTaxCredit: hometownTaxCreditAmt,
      smeExemption: smeExemptionAmt,
      medicalTaxCredit: medicalTaxCreditAmt,
      educationTaxCredit: educationTaxCreditAmt,
      donationTaxCredit: donationTaxCreditAmt,
      weddingTaxCredit: weddingTaxCreditAmt,
    );
  }

  /// 단순경비율/기준경비율 두 가정을 각각 계산해 세금 적립 최소~최대 범위를 낸다.
  /// (가계부 적립 카드용 — 사업소득 부분에만 경비율 차이가 영향을 준다.)
  static ({CombinedTaxResult min, CombinedTaxResult max}) calculateTaxRange({
    required double grossIncome,
    required double accumulatedFreelancerIncome,
    required int inputMonths,
    required String occupationCode,
    required double creditCard,
    required double debitCardAndCash,
    required double traditionalMarket,
    required double publicTransport,
    required double cultureExpense,
    required int allowanceCount,
    required double decidedTax,
    required double monthlyRent,
    double yellowUmbrellaPayment = 0.0,
    bool isHomeless = false,
    double pensionIncome = 0.0,
    double otherIncome = 0.0,
    double insurancePremium = 0.0,
    double disabledInsurancePremium = 0.0,
    int childrenCount8Plus = 0,
    int childrenCountTotal = 0,
    int newbornCount = 0,
    double pensionSavings = 0.0,
    double irpPayment = 0.0,
    bool hasElderly70Plus = false,
    bool isSingleParent = false,
    bool isSingleFemaleHead = false,
    double mortgageInterest = 0.0,
    double hometownDonation = 0.0,
    double infertilityMedical = 0.0,
    double selfSeniorDisabledMedical = 0.0,
    double otherDependentMedical = 0.0,
    double generalDonation = 0.0,
    double childrenEdu = 0.0,
    int childrenEduCount = 0,
    double collegeEdu = 0.0,
    int collegeEduCount = 0,
    bool weddingCredit2426 = false,
    bool isSmeEmployee = false,
    int smeStartYear = 0,
    bool isYouthSme = false,
  }) {
    CombinedTaxResult run(bool useStandard) => calculateCombinedTax(
          grossIncome: grossIncome,
          accumulatedFreelancerIncome: accumulatedFreelancerIncome,
          inputMonths: inputMonths,
          occupationCode: occupationCode,
          creditCard: creditCard,
          debitCardAndCash: debitCardAndCash,
          traditionalMarket: traditionalMarket,
          publicTransport: publicTransport,
          cultureExpense: cultureExpense,
          allowanceCount: allowanceCount,
          decidedTax: decidedTax,
          monthlyRent: monthlyRent,
          yellowUmbrellaPayment: yellowUmbrellaPayment,
          isHomeless: isHomeless,
          pensionIncome: pensionIncome,
          otherIncome: otherIncome,
          insurancePremium: insurancePremium,
          disabledInsurancePremium: disabledInsurancePremium,
          childrenCount8Plus: childrenCount8Plus,
          childrenCountTotal: childrenCountTotal,
          newbornCount: newbornCount,
          pensionSavings: pensionSavings,
          irpPayment: irpPayment,
          hasElderly70Plus: hasElderly70Plus,
          isSingleParent: isSingleParent,
          isSingleFemaleHead: isSingleFemaleHead,
          mortgageInterest: mortgageInterest,
          hometownDonation: hometownDonation,
          infertilityMedical: infertilityMedical,
          selfSeniorDisabledMedical: selfSeniorDisabledMedical,
          otherDependentMedical: otherDependentMedical,
          generalDonation: generalDonation,
          childrenEdu: childrenEdu,
          childrenEduCount: childrenEduCount,
          collegeEdu: collegeEdu,
          collegeEduCount: collegeEduCount,
          weddingCredit2426: weddingCredit2426,
          isSmeEmployee: isSmeEmployee,
          smeStartYear: smeStartYear,
          isYouthSme: isYouthSme,
          useStandardExpenseRate: useStandard,
        );
    final simple = run(false);
    final standard = run(true);
    final lower = simple.annualTotalTax <= standard.annualTotalTax ? simple : standard;
    final higher = simple.annualTotalTax <= standard.annualTotalTax ? standard : simple;
    return (min: lower, max: higher);
  }

  /// 금융소득 비교과세 시뮬레이션 (소득세법 §62, 2025~2026 귀속 동일)
  ///
  /// • 2,000만원 이하 → 분리과세 14% 원천징수 완납, 종합과세 불필요
  /// • 2,000만원 초과 → 비교과세:
  ///   ① 분리과세세액 = 금융소득 전액 × 14%
  ///   ② 종합과세세액 = (otherTaxableIncome + financialIncome) 누진세율
  ///   결정세액 = Max(①, ②)
  ///
  /// 배당 Gross-up은 단순화하여 미적용 (시뮬레이터 용도).
  static FinancialIncomeTaxResult calculateFinancialIncomeTax({
    required double annualFinancialIncome,
    required double otherTaxableIncome,
  }) {
    final bool isSeparateTax = annualFinancialIncome <= TaxRates.financialIncomeThreshold;
    final bool isHealthImpacted = annualFinancialIncome > TaxRates.financialIncomeHealthThreshold;

    final double separateTax = TaxRates.truncateWon(
      annualFinancialIncome * TaxRates.financialIncomeSeparateTaxRate,
    );

    if (isSeparateTax) {
      return FinancialIncomeTaxResult(
        annualFinancialIncome: annualFinancialIncome,
        isSeparateTax: true,
        separateTaxAmount: separateTax,
        comprehensiveTaxAmount: separateTax,
        additionalTaxBurden: 0.0,
        isHealthInsuranceImpacted: isHealthImpacted,
      );
    }

    final double totalBase = otherTaxableIncome + annualFinancialIncome;
    final double comprehensiveTaxOnTotal = TaxRates.truncateWon(TaxRates.calculateTax(totalBase));
    final double decidedTax = comprehensiveTaxOnTotal > separateTax ? comprehensiveTaxOnTotal : separateTax;
    final double baseTaxWithoutFinancial = TaxRates.truncateWon(TaxRates.calculateTax(otherTaxableIncome));
    final double additionalBurden = (decidedTax - baseTaxWithoutFinancial).clamp(0.0, double.infinity);

    return FinancialIncomeTaxResult(
      annualFinancialIncome: annualFinancialIncome,
      isSeparateTax: false,
      separateTaxAmount: separateTax,
      comprehensiveTaxAmount: decidedTax,
      additionalTaxBurden: additionalBurden,
      isHealthInsuranceImpacted: isHealthImpacted,
    );
  }

}
class CombinedTaxResult {
  final double annualEstimatedIncome;
  final double laborIncomeAmount;
  final double estimatedFreelancerBusinessIncome;
  final double pensionIncomeAmount;
  final double otherIncomeAmount;
  final double totalGlobalIncome;
  final double taxBase;
  /// 종합소득산출세액(국세, 세액공제 차감 전) — 무기장가산세 산식의 기준값.
  final double calculatedTax;
  final double annualIncomeTax;
  final double annualLocalTax;
  final double annualTotalTax;
  final double paidTotalWithholding;
  final double annualEstimatedTotalWithholding;
  final double expectedRefundOrPayment;
  final double expectedIncomeTaxRefundOrPayment;
  final double expectedLocalTaxRefundOrPayment;
  final double monthlyReserve;
  final String reserveNudgeMessage;
  final CreditCardDeductionResult cardResult;
  /// 적용된 월세 세액공제액 (조특법 §95의2).
  final double rentTaxCredit;
  final double yellowUmbrellaDeduction;
  final double yellowUmbrellaLimit;
  final double insuranceDeduction;
  final double insuranceTaxCredit;
  final double childTaxCredit;
  final double pensionTaxCredit;
  final double additionalPersonalDeduction;
  final double mortgageDeduction;
  /// 고향사랑기부금 세액공제액 (조특법 §58).
  final double hometownTaxCredit;
  final double smeExemption;
  final double medicalTaxCredit;
  final double educationTaxCredit;
  final double donationTaxCredit;
  final double weddingTaxCredit;

  CombinedTaxResult({
    required this.annualEstimatedIncome,
    required this.laborIncomeAmount,
    required this.estimatedFreelancerBusinessIncome,
    required this.pensionIncomeAmount,
    required this.otherIncomeAmount,
    required this.totalGlobalIncome,
    required this.taxBase,
    required this.calculatedTax,
    required this.annualIncomeTax,
    required this.annualLocalTax,
    required this.annualTotalTax,
    required this.paidTotalWithholding,
    required this.annualEstimatedTotalWithholding,
    required this.expectedRefundOrPayment,
    required this.expectedIncomeTaxRefundOrPayment,
    required this.expectedLocalTaxRefundOrPayment,
    required this.monthlyReserve,
    required this.reserveNudgeMessage,
    required this.cardResult,
    required this.rentTaxCredit,
    required this.yellowUmbrellaDeduction,
    required this.yellowUmbrellaLimit,
    required this.insuranceDeduction,
    required this.insuranceTaxCredit,
    required this.childTaxCredit,
    required this.pensionTaxCredit,
    required this.additionalPersonalDeduction,
    required this.mortgageDeduction,
    required this.hometownTaxCredit,
    required this.smeExemption,
    required this.medicalTaxCredit,
    required this.educationTaxCredit,
    required this.donationTaxCredit,
    required this.weddingTaxCredit,
  });
}

/// 금융소득 비교과세 결과
class FinancialIncomeTaxResult {
  final double annualFinancialIncome;
  final bool isSeparateTax;          // 2,000만원 이하 → 분리과세 완납
  final double separateTaxAmount;    // 분리과세 세액 (14%)
  final double comprehensiveTaxAmount; // 종합과세 결정세액 (비교과세 후)
  final double additionalTaxBurden;  // 종합과세 추가 세부담 (종합 - 분리)
  final bool isHealthInsuranceImpacted; // 건보료 추가 산정 여부 (1,000만 초과)

  const FinancialIncomeTaxResult({
    required this.annualFinancialIncome,
    required this.isSeparateTax,
    required this.separateTaxAmount,
    required this.comprehensiveTaxAmount,
    required this.additionalTaxBurden,
    required this.isHealthInsuranceImpacted,
  });
}

