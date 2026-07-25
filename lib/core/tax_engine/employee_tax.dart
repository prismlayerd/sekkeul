import 'tax_rates.dart';

class CreditCardDeductionResult {
  final double threshold;
  final double totalSpend;
  final double excessSpend;
  final double finalDeduction;
  final String guideMessage;

  CreditCardDeductionResult({
    required this.threshold,
    required this.totalSpend,
    required this.excessSpend,
    required this.finalDeduction,
    required this.guideMessage,
  });
}

/// 신용카드 등 소득공제로 줄어드는 결정세액(=연말정산 환급 예상분) 추정 결과.
/// "올해 쌓인 예상 환급" 홈 표시용 — 카드공제만 반영(의료·교육·기부 등은 별도).
class CreditCardRefundEstimate {
  final double deduction;          // 카드 소득공제액
  final double taxSaving;          // 카드공제로 줄어든 결정세액(=환급 예상)
  final bool isCapped;             // 공제 한도(기본 300/250만) 도달 여부
  final double threshold;          // 공제 문턱(연봉 25%)
  final double totalEligibleSpend; // 공제 대상 연 누적(신용+체크·현금)

  const CreditCardRefundEstimate({
    required this.deduction,
    required this.taxSaving,
    required this.isCapped,
    required this.threshold,
    required this.totalEligibleSpend,
  });
}

class RentRefundResult {
  final double totalAnnualRent;
  final double expectedRefund;
  final bool isRefundCapped;

  RentRefundResult({
    required this.totalAnnualRent,
    required this.expectedRefund,
    required this.isRefundCapped,
  });
}

class SpecialDeductionResult {
  final double medicalTaxCredit;
  final double educationTaxCredit;
  final double donationTaxCredit;
  final double mortgageIncomeDeduction;

  SpecialDeductionResult({
    required this.medicalTaxCredit,
    required this.educationTaxCredit,
    required this.donationTaxCredit,
    required this.mortgageIncomeDeduction,
  });
}

/// 직장인 4대보험 월 공제액 내역 (지식_변환/JSON/직장인_4대보험_가이드.json 기준)
class InsuranceBreakdown {
  final double nationalPension;    // 국민연금 4.75%
  final double healthInsurance;    // 건강보험 3.595%
  final double longTermCare;       // 장기요양 건강보험료 × 13.14%
  final double employmentInsurance; // 고용보험 0.90%
  final double total;

  const InsuranceBreakdown({
    required this.nationalPension,
    required this.healthInsurance,
    required this.longTermCare,
    required this.employmentInsurance,
    required this.total,
  });
}

/// 4대보험 연간 소득공제액 (연금보험료공제 + 특별소득공제 보험료)
class InsuranceDeduction {
  final double pensionDeduction;          // 국민연금 본인부담 전액
  final double specialInsuranceDeduction; // 건강+장기요양+고용 전액
  final double total;

  const InsuranceDeduction({
    required this.pensionDeduction,
    required this.specialInsuranceDeduction,
    required this.total,
  });
}

/// 직장인(근로소득자) 전용 세액 계산 및 소비/경정청구 시뮬레이션 엔진
class EmployeeTaxCalculator {

  /// 직장인 4대보험 월 본인부담금 계산
  static InsuranceBreakdown calculateMonthlyInsurance(double monthlyGross) {
    if (monthlyGross <= 0) {
      return const InsuranceBreakdown(
        nationalPension: 0, healthInsurance: 0,
        longTermCare: 0, employmentInsurance: 0, total: 0,
      );
    }
    // 국민연금은 기준소득월액 상·하한으로 클램프한 소득에만 부과 (고소득자 과대부과 방지).
    final npBase = monthlyGross > TaxRates.nationalPensionBaseUpperLimit
        ? TaxRates.nationalPensionBaseUpperLimit
        : (monthlyGross < TaxRates.nationalPensionBaseLowerLimit
            ? TaxRates.nationalPensionBaseLowerLimit
            : monthlyGross);
    final np  = TaxRates.truncateWon(npBase * 0.0475);
    final hi  = TaxRates.truncateWon(monthlyGross * 0.03595);
    final ltc = TaxRates.truncateWon(hi * 0.1314);
    final ei  = TaxRates.truncateWon(monthlyGross * 0.009);
    return InsuranceBreakdown(
      nationalPension: np,
      healthInsurance: hi,
      longTermCare: ltc,
      employmentInsurance: ei,
      total: np + hi + ltc + ei,
    );
  }

  /// 연말정산 과세표준 차감용 4대보험 연간 소득공제액.
  /// - 연금보험료공제: 국민연금 본인부담 전액 (소법 §51의3)
  /// - 특별소득공제 보험료: 건강보험+노인장기요양+고용보험 전액 (소법 §52①)
  /// 월 보험료를 모를 때 월급여 기준 추정. 실제 납입액을 알면 직접 합산해도 됨.
  static InsuranceDeduction calculateAnnualInsuranceDeduction(double monthlyGross) {
    final m = calculateMonthlyInsurance(monthlyGross);
    final double pension = m.nationalPension * 12;
    final double special = (m.healthInsurance + m.longTermCare + m.employmentInsurance) * 12;
    return InsuranceDeduction(
      pensionDeduction: pension,
      specialInsuranceDeduction: special,
      total: pension + special,
    );
  }

  /// 자녀세액공제 (소법 §59의2, 2025 귀속 개정)
  /// - 8세 이상 자녀·손자녀: 첫째 25만/둘째 30만(누적55)/셋째이상 1명당 40만
  /// - 출산·입양 자녀: 첫째 30만/둘째 50만/셋째이상 70만
  /// 참고: 2024귀속까지는 15/20/30이었으나 2025 개정으로 상향
  static double calculateChildTaxCredit({
    required int childrenCount,         // 8세 이상 자녀 수
    required int newbornCount,          // 출산·입양 자녀 수
  }) {
    if (childrenCount <= 0 && newbornCount <= 0) return 0.0;

    double credit = 0.0;

    // 기본 자녀(8세 이상)
    if (childrenCount > 0) {
      for (int i = 0; i < childrenCount; i++) {
        if (i == 0) credit += 250000.0;        // 첫째: 25만
        else if (i == 1) credit += 300000.0;   // 둘째: 30만
        else credit += 400000.0;                // 셋째이상: 40만/명
      }
    }

    // 출산·입양 자녀 (신생아 공제, 기본 자녀와 합산)
    if (newbornCount > 0) {
      for (int i = 0; i < newbornCount; i++) {
        if (i == 0) credit += 300000.0;        // 첫째: 30만
        else if (i == 1) credit += 500000.0;   // 둘째: 50만
        else credit += 700000.0;                // 셋째이상: 70만/명
      }
    }

    return TaxRates.truncateWon(credit);
  }

  /// 연금계좌 세액공제 (연금저축 + 퇴직연금/IRP, 소법 §59의3, 2025 귀속)
  /// - 연금저축 공제대상 한도 600만, (연금저축+퇴직연금) 합산 900만
  /// - 공제율 12% (총급여 5,500만 이하 또는 종합소득금액 4,500만 이하는 15%)
  static double calculatePensionAccountTaxCredit({
    required double pensionSavingsPayment,    // 연금저축 납입액
    required double retirementPensionPayment, // 퇴직연금(DC/IRP) 납입액
    required double grossIncome,              // 총급여(직장인) 또는 종합소득금액
    bool isSalariedIncome = true,             // true=근로(5,500만 기준), false=종합(4,500만 기준)
  }) {
    if (pensionSavingsPayment <= 0 && retirementPensionPayment <= 0) return 0.0;
    final double eligibleSavings =
        pensionSavingsPayment > 6000000.0 ? 6000000.0 : pensionSavingsPayment;
    double eligibleTotal = eligibleSavings + retirementPensionPayment;
    if (eligibleTotal > 9000000.0) eligibleTotal = 9000000.0;
    final double threshold = isSalariedIncome ? 55000000.0 : 45000000.0;
    final double rate = grossIncome <= threshold ? 0.15 : 0.12;
    return TaxRates.truncateWon(eligibleTotal * rate);
  }

  /// 보장성보험료 세액공제 (소법 §59의4, 2025 귀속)
  /// - 보장성보험: 연 100만 한도 12%
  /// - 장애인전용보장성보험: 연 100만 한도 15%
  static double calculateInsurancePremiumTaxCredit({
    required double generalInsurancePremium,
    required double disabledInsurancePremium,
  }) {
    final double general =
        (generalInsurancePremium > 1000000.0 ? 1000000.0 : generalInsurancePremium) * 0.12;
    final double disabled =
        (disabledInsurancePremium > 1000000.0 ? 1000000.0 : disabledInsurancePremium) * 0.15;
    return TaxRates.truncateWon(general + disabled);
  }

  /// 표준세액공제 (소법 §59의5, 2025 귀속 13만원)
  /// 특별소득공제·특별세액공제·월세세액공제를 신청하지 않는 경우 일괄 공제
  /// 사용자가 공제항목이 적을 때 자동으로 표준공제(13만)가 더 유리하면 적용
  static double getStandardTaxCredit() {
    return 130000.0;
  }

  /// 중소기업취업자 소득세 감면 (조특법 §30, 2025 귀속)
  /// - 청년(만15~34세, 군복무기간 최대 6년 차감): 취업 후 5년간 90% 감면
  /// - 60세이상·장애인·경력단절여성: 취업 후 3년간 70% 감면
  /// - 공통: 연 200만원 한도
  /// [isYouth] 가 true면 청년 트랙(90%·5년), 아니면 기타 트랙(70%·3년).
  static double calculateSmeExemption({
    required double calculatedTax,
    required int smeStartYear,
    bool isYouth = false,
  }) {
    final int yearsWorked = DateTime.now().year - smeStartYear;
    final int periodYears = isYouth ? 5 : 3;
    if (yearsWorked >= periodYears || yearsWorked < 0) return 0.0;
    final double rate = isYouth ? 0.90 : 0.70;
    final double credit = TaxRates.truncateWon(calculatedTax * rate);
    return credit > 2000000.0 ? 2000000.0 : credit;
  }

  /// 중소기업취업자 청년 감면 적격 판정 (조특법 §30).
  /// 만 34세 이하면 청년. 군 복무기간(최대 6년)만큼 나이 상한을 늘려준다
  /// (= 실효 나이에서 복무개월을 차감해 비교).
  static bool isYouthSmeEligible({required int age, int militaryMonths = 0}) {
    if (age <= 0) return false;
    final int militaryYears = (militaryMonths / 12).floor().clamp(0, 6);
    return (age - militaryYears) <= 34;
  }

  /// 월 원천징수 소득세 추정 (간이세액표 근사) — 실수령액(세후) 계산용.
  /// 연 결정세액(국세)을 산출해 12로 나눈 근사값. 지방소득세는 제외.
  /// 프로필의 부양가족 수가 있으면 인적공제에 반영해 정확도를 높인다.
  static double estimateMonthlyIncomeTax({
    required double grossAnnual,
    int dependentsIncludingSelf = 1,
  }) {
    if (grossAnnual <= 0) return 0.0;
    final double laborDeduction = calculateLaborDeduction(grossAnnual);
    final double laborIncome = grossAnnual - laborDeduction;
    final int heads = dependentsIncludingSelf < 1 ? 1 : dependentsIncludingSelf;
    final double personalDeduction = TaxRates.basicDeductionPerPerson * heads;
    final double insuranceDeduction =
        calculateAnnualInsuranceDeduction(grossAnnual / 12).total;
    double taxBase = laborIncome - personalDeduction - insuranceDeduction;
    if (taxBase < 0) taxBase = 0;
    final double calculatedTax = TaxRates.calculateTax(taxBase);
    final double laborCredit = calculateLaborTaxCredit(
        grossIncome: grossAnnual, calculatedTaxShare: calculatedTax);
    double decidedTax = calculatedTax - laborCredit;
    if (decidedTax < 0) decidedTax = 0;
    return TaxRates.truncateWon(decidedTax / 12);
  }

  /// 인적공제 추가공제 계산 (소득세법 §51)
  /// - 경로우대(만70세이상): 100만원
  /// - 부녀자(여성세대주): 50만원
  /// - 한부모 (배우자 없고 부양가족 있음): 100만원
  /// 참고: 경로우대와 한부모, 부녀자 중복 불가 (중복 선택 시 큰 것만)
  static double calculateAdditionalPersonalDeduction({
    required bool hasElderly70Plus,      // 70세이상 부양가족 (경로우대)
    required bool isSingleFemaleHead,    // 여성 세대주 (부녀자)
    required bool isSingleParent,        // 배우자없고 부양가족있음 (한부모)
  }) {
    double deduction = 0.0;

    if (hasElderly70Plus) {
      deduction += 1000000.0; // 경로우대 100만
    }

    // 부녀자 vs 한부모 중복 불가 (큰 것 선택)
    if (isSingleFemaleHead && isSingleParent) {
      deduction += 1000000.0; // 한부모 100만 > 부녀자 50만
    } else if (isSingleFemaleHead) {
      deduction += 500000.0; // 부녀자 50만
    } else if (isSingleParent) {
      deduction += 1000000.0; // 한부모 100만
    }

    return deduction;
  }

  /// 월세액 세액공제 자격 판정 (조특법 §95의2, 2024 귀속부터 8천만원으로 상향)
  /// - 총급여 8,000만원 이하 (종합소득금액 6,000만원 초과자 제외)
  /// - 무주택 세대주(또는 세대원)
  static bool isRentCreditEligible({
    required double grossIncome,
    required double globalIncomeAmount, // 종합소득금액 (직장인은 근로소득금액)
    required bool isHomeless,
  }) {
    // 조특법 §95의2 (2024 귀속~): 총급여 8,000만 이하 + 종합소득금액 7,000만 이하 + 무주택.
    // 출처: 국세청 "월세액 세액공제" 안내 — 확인일 2026-07-19 (종전 6,000만에서 상향).
    if (!isHomeless) return false;
    if (grossIncome > 80000000.0) return false;
    if (globalIncomeAmount > 70000000.0) return false;
    return true;
  }

  /// 연금소득공제 계산 (소득세법 §47의2, 2025 귀속)
  /// 총연금액 구간별 차등 공제, 한도 900만원
  static double calculatePensionIncomeDeduction(double totalPension) {
    if (totalPension <= 0) return 0.0;
    double deduction;
    if (totalPension <= 3500000) {
      deduction = totalPension;
    } else if (totalPension <= 7000000) {
      deduction = 3500000 + (totalPension - 3500000) * 0.4;
    } else if (totalPension <= 14000000) {
      deduction = 4900000 + (totalPension - 7000000) * 0.2;
    } else if (totalPension <= 21000000) {
      deduction = 6300000 + (totalPension - 14000000) * 0.1;
    } else {
      deduction = 7000000 + (totalPension - 21000000) * 0.05;
    }
    return deduction > 9000000.0 ? 9000000.0 : deduction;
  }

  /// 연금소득금액 = 총연금액 - 연금소득공제 (소득세법 §47의2)
  static double calculatePensionIncomeAmount(double totalPension) {
    if (totalPension <= 0) return 0.0;
    final amount = totalPension - calculatePensionIncomeDeduction(totalPension);
    return amount < 0 ? 0.0 : amount;
  }

  /// 기타소득금액 계산 (소득세법 §21, 강사료·원고료·상금 등)
  /// 필요경비율 60% 적용 → 기타소득금액 = 총수입금액 × 40%
  /// 기타소득금액 300만원 초과 시 종합과세 의무, 이하 선택적 분리과세(20%)
  static double calculateOtherIncomeAmount(double grossOtherIncome) {
    if (grossOtherIncome <= 0) return 0.0;
    return grossOtherIncome * 0.4;
  }

  /// 기타소득 종합과세 대상 여부 (기타소득금액 기준 300만원 초과)
  static bool isOtherIncomeComprehensive(double otherIncomeAmount) {
    return otherIncomeAmount > 3000000.0;
  }

  /// 근로소득공제 계산 (소득세법 제47조). 공제 한도 2,000만원(2020 귀속 이후).
  static double calculateLaborDeduction(double grossIncome) {
    if (grossIncome <= 0) return 0.0;
    double deduction;
    if (grossIncome <= 5000000) {
      deduction = grossIncome * 0.7;
    } else if (grossIncome <= 15000000) {
      deduction = 3500000 + (grossIncome - 5000000) * 0.4;
    } else if (grossIncome <= 45000000) {
      deduction = 7500000 + (grossIncome - 15000000) * 0.15;
    } else if (grossIncome <= 100000000) {
      deduction = 12000000 + (grossIncome - 45000000) * 0.05;
    } else {
      deduction = 14750000 + (grossIncome - 100000000) * 0.02;
    }
    return deduction > 20000000.0 ? 20000000.0 : deduction;
  }

  /// 근로소득세액공제 한도 계산 (소득세법 제59조)
  static double calculateLaborTaxCreditLimit(double grossIncome) {
    if (grossIncome <= 0) return 0.0;
    if (grossIncome <= 33000000) {
      return 740000.0;
    } else if (grossIncome <= 70000000) {
      final double val = 740000.0 - (grossIncome - 33000000) * 0.008;
      return val < 660000.0 ? 660000.0 : val;
    } else if (grossIncome <= 120000000) {
      final double val = 660000.0 - (grossIncome - 70000000) * 0.5;
      return val < 500000.0 ? 500000.0 : val;
    } else {
      final double val = 500000.0 - (grossIncome - 120000000) * 0.5;
      return val < 200000.0 ? 200000.0 : val;
    }
  }

  /// 근로소득세액공제 계산 (소득세법 제59조)
  static double calculateLaborTaxCredit({
    required double grossIncome,
    required double calculatedTaxShare,
  }) {
    if (grossIncome <= 0 || calculatedTaxShare <= 0) return 0.0;
    final double limit = calculateLaborTaxCreditLimit(grossIncome);
    if (calculatedTaxShare <= 1300000) {
      final double val = calculatedTaxShare * 0.55;
      return val > limit ? limit : val;
    } else {
      final double val = 715000.0 + (calculatedTaxShare - 1300000) * 0.3;
      return val > limit ? limit : val;
    }
  }

  /// 의료비 세액공제 (소득세법 제59조의4)
  /// - 난임시술비: 총급여 3% 초과분, 공제율 30%, 한도 없음
  /// - 본인·65세이상·장애인 의료비: 총급여 3% 초과분, 공제율 15%, 한도 없음
  /// - 일반 부양가족 의료비: 총급여 3% 초과분, 공제율 15%, 700만원 한도
  static double calculateMedicalTaxCredit({
    required double grossIncome,
    required double infertilityExpense,              // 난임시술비 (30%, 한도 없음)
    required double selfAndSeniorAndDisabledExpense, // 본인·65세이상·장애인·건강보험산정특례자 (15%, 한도 없음)
    required double otherDependentExpense,           // 일반 부양가족 (15%, 700만원 한도)
    double prematureBabyExpense = 0.0,               // 미숙아·선천성이상아 (20%, 한도 없음)
  }) {
    final double threshold = grossIncome * 0.03;
    final double total = infertilityExpense + prematureBabyExpense +
        selfAndSeniorAndDisabledExpense + otherDependentExpense;
    if (total <= threshold) return 0.0;

    // 3% 초과분을 고율(30%→20%→15%) 항목부터 우선 배분하여 공제 최대화
    double excess = total - threshold;

    final double infertilityAllowable = excess < infertilityExpense ? excess : infertilityExpense;
    excess -= infertilityAllowable;

    final double prematureAllowable = excess < prematureBabyExpense ? excess : prematureBabyExpense;
    excess -= prematureAllowable;

    final double selfAllowable = excess < selfAndSeniorAndDisabledExpense
        ? excess
        : selfAndSeniorAndDisabledExpense;
    excess -= selfAllowable;

    final double otherAllowable = excess < otherDependentExpense ? excess : otherDependentExpense;
    final double cappedOther = otherAllowable > 7000000.0 ? 7000000.0 : otherAllowable;

    return TaxRates.truncateWon(
      infertilityAllowable * 0.30 +
          prematureAllowable * 0.20 +
          (selfAllowable + cappedOther) * 0.15,
    );
  }

  /// 교육비 세액공제 (소득세법 제59조의4, 2025 귀속)
  /// - 취학전아동: 1인당 300만원 한도, 공제율 15%
  /// - 유치원~고등학생: 1인당 300만원 한도, 공제율 15%
  /// - 대학생: 1인당 900만원 한도, 공제율 15%
  /// - 본인 교육비(대학원 포함): 무제한, 공제율 15%
  /// - 장애인 특수교육비: 무제한, 공제율 15%
  static double calculateEducationTaxCredit({
    required double preschoolExpense,      // 취학전아동 교육비 합산
    required int preschoolCount,           // 취학전아동 인원 수
    required double childrenExpense,       // 유치원~고등학생 교육비 합산
    required int childrenCount,            // 유치원~고등학생 인원 수
    required double collegeExpense,        // 대학생 교육비 합산
    required int collegeCount,             // 대학생 인원 수
    required double selfExpense,           // 본인 교육비(대학원 포함)
    required double disabledSpecialExpense, // 장애인 특수교육비
  }) {
    double totalAllowable = 0.0;

    // 취학전아동: 1인당 300만 한도
    final double preschoolLimit = 3000000.0 * preschoolCount;
    totalAllowable += (preschoolExpense > preschoolLimit) ? preschoolLimit : preschoolExpense;

    // 유치원~고등학생: 1인당 300만 한도
    final double childLimit = 3000000.0 * childrenCount;
    totalAllowable += (childrenExpense > childLimit) ? childLimit : childrenExpense;

    // 대학생: 1인당 900만 한도
    final double collegeLimit = 9000000.0 * collegeCount;
    totalAllowable += (collegeExpense > collegeLimit) ? collegeLimit : collegeExpense;

    // 본인 교육비: 무제한
    totalAllowable += selfExpense;

    // 장애인 특수교육비: 무제한
    totalAllowable += disabledSpecialExpense;

    return TaxRates.truncateWon(totalAllowable * 0.15);
  }

  /// 기부금 세액공제 (소득세법 제59조의3, 2025 귀속)
  /// - 일반기부금/지정기부금: 1천만 이하 15%, 초과 30%
  /// - 정치자금기부금: 10만원까지 100% (환급), 초과 15% (3천만 초과시 25%)
  /// - 고향사랑기부금(2025신설): 2천만 한도 공제율 100% → 세액공제 아님, 과표차감
  /// 참고: 고향사랑기부금은 여기서는 과표 차감으로 처리하므로, 세액공제는 정치자금·일반기부금만
  static double calculateDonationTaxCredit({
    required double generalDonation,      // 일반 지정기부금
    required double politicalDonation,    // 정치자금기부금
  }) {
    double credit = 0.0;

    // 일반/지정 기부금: 1천만 이하 15%, 초과 30%
    if (generalDonation > 0) {
      if (generalDonation <= 10000000.0) {
        credit += generalDonation * 0.15;
      } else {
        credit += (10000000.0 * 0.15) + ((generalDonation - 10000000.0) * 0.30);
      }
    }

    // 정치자금기부금: 10만원까지 환급(100%), 초과는 15%(3천만초과 25%)
    if (politicalDonation > 0) {
      if (politicalDonation <= 100000.0) {
        credit += politicalDonation;  // 100% 환급
      } else {
        credit += 100000.0;  // 10만원 환급
        final double excess = politicalDonation - 100000.0;
        // 단순화: 3천만 초과 확인은 총급여 기준으로 별도 구현 (여기선 15%만)
        credit += excess * 0.15;
      }
    }

    return TaxRates.truncateWon(credit);
  }

  /// 고향사랑기부금 과표차감 (2025신설, 조특법 신설)
  /// - 연간 2천만원 한도, 100% 과표차감 (세액공제 아님)
  /// 참고: 이 메서드는 과표 계산 시 소득공제로 사용
  static double calculateHometownDonationDeduction(double hometownDonation) {
    if (hometownDonation <= 0) return 0.0;
    final double limit = 20000000.0; // 2천만원 한도
    return hometownDonation > limit ? limit : hometownDonation;
  }

  /// 주택담보대출 이자상환액 소득공제 (15년 이상 고정+비거치 기준 최대 2000만원 한도 소득공제)
  static double calculateMortgageIncomeDeduction(double mortgageInterestExpense) {
    double limit = 20000000.0; // 최고 한도만 단순화 적용
    return mortgageInterestExpense > limit ? limit : mortgageInterestExpense;
  }

  /// 특별공제 패키지 자동화 도출
  static SpecialDeductionResult calculateSpecialDeductions({
    required double grossIncome,
    required double infertilityMedical,              // 난임시술비
    required double selfAndSeniorAndDisabledMedical, // 본인·경로우대자·장애인 의료비
    required double otherDependentMedical,           // 일반 부양가족 의료비
    double prematureBabyMedical = 0.0,               // 미숙아·선천성이상아 의료비 (20%)
    // 교육비 - 확장됨
    double preschoolExpense = 0.0,                   // 취학전아동 교육비
    int preschoolCount = 0,                          // 취학전아동 인원
    double childrenEduExpense = 0.0,                 // 유치원~고등 교육비
    int childrenCount = 0,                           // 유치원~고등 인원
    double collegeEduExpense = 0.0,                  // 대학생 교육비
    int collegeCount = 0,                            // 대학생 인원
    double selfEduExpense = 0.0,                     // 본인 교육비(대학원)
    double disabledSpecialExpense = 0.0,             // 장애인 특수교육비
    // 기부금 - 확장됨
    double generalDonation = 0.0,                    // 일반/지정 기부금
    double politicalDonation = 0.0,                  // 정치자금 기부금
    double mortgageInterestExpense = 0.0,
  }) {
    return SpecialDeductionResult(
      medicalTaxCredit: calculateMedicalTaxCredit(
        grossIncome: grossIncome,
        infertilityExpense: infertilityMedical,
        selfAndSeniorAndDisabledExpense: selfAndSeniorAndDisabledMedical,
        otherDependentExpense: otherDependentMedical,
        prematureBabyExpense: prematureBabyMedical,
      ),
      educationTaxCredit: calculateEducationTaxCredit(
        preschoolExpense: preschoolExpense,
        preschoolCount: preschoolCount,
        childrenExpense: childrenEduExpense,
        childrenCount: childrenCount,
        collegeExpense: collegeEduExpense,
        collegeCount: collegeCount,
        selfExpense: selfEduExpense,
        disabledSpecialExpense: disabledSpecialExpense,
      ),
      donationTaxCredit: calculateDonationTaxCredit(
        generalDonation: generalDonation,
        politicalDonation: politicalDonation,
      ),
      mortgageIncomeDeduction: calculateMortgageIncomeDeduction(mortgageInterestExpense),
    );
  }

  /// 신용카드 소득공제 연산
  /// 카드공제 기본한도 — 조특법 §126의2⑩ (2025 귀속 개정, 2028.12.31까지).
  /// 자녀등(자녀·손자녀 등 기본공제대상 부양가족) 1명당 50만원씩, 최대 100만원 상향.
  ///
  /// | 총급여 | 무자녀 | 자녀등 1명 | 자녀등 2명 이상 |
  /// |---|---|---|---|
  /// | 7천만 이하 | 300만 | 350만 | 400만 |
  /// | 7천만 초과 | 250만 | 275만 | 300만 |
  ///
  /// 7천만 초과 구간은 1명당 25만원(최대 50만원) 상향이다 — 이하 구간과 폭이 다르다.
  static double creditCardBaseLimit({
    required double grossIncome,
    int childrenCount = 0,
  }) {
    final int kids = childrenCount < 0 ? 0 : (childrenCount > 2 ? 2 : childrenCount);
    if (grossIncome <= 70000000) {
      return 3000000.0 + kids * 500000.0;
    }
    return 2500000.0 + kids * 250000.0;
  }

  static CreditCardDeductionResult calculateCreditCardDeduction({
    required double grossIncome,
    required double creditCard,
    required double debitCardAndCash,
    required double traditionalMarket,
    required double publicTransport,
    required double cultureExpense,
    /// 자녀등 수 — 기본한도 상향(2025 개정)에 쓰인다.
    int childrenCount = 0,
  }) {
    final double threshold = grossIncome * 0.25;
    final double totalSpend = creditCard + debitCardAndCash + traditionalMarket + publicTransport + cultureExpense;
    final double excessSpend = totalSpend > threshold ? (totalSpend - threshold) : 0.0;
    double remainingExcess = excessSpend;

    final double allocatedTransport = remainingExcess > publicTransport ? publicTransport : remainingExcess;
    remainingExcess -= allocatedTransport;

    final double allocatedMarket = remainingExcess > traditionalMarket ? traditionalMarket : remainingExcess;
    remainingExcess -= allocatedMarket;

    double allocatedCulture = 0.0;
    if (grossIncome <= 70000000) {
      allocatedCulture = remainingExcess > cultureExpense ? cultureExpense : remainingExcess;
      remainingExcess -= allocatedCulture;
    }

    final double allocatedDebit = remainingExcess > debitCardAndCash ? debitCardAndCash : remainingExcess;
    remainingExcess -= allocatedDebit;

    final double allocatedCredit = remainingExcess > creditCard ? creditCard : remainingExcess;
    remainingExcess -= allocatedCredit;

    final double transportDeduction = allocatedTransport * 0.40;
    final double marketDeduction = allocatedMarket * 0.40;
    final double cultureDeduction = allocatedCulture * 0.30;
    final double debitDeduction = allocatedDebit * 0.30;
    final double creditDeduction = allocatedCredit * 0.15;

    final double baseLimit =
        creditCardBaseLimit(grossIncome: grossIncome, childrenCount: childrenCount);
    final double rawBaseDeduction = creditDeduction + debitDeduction;
    final double baseDeduction = rawBaseDeduction > baseLimit ? baseLimit : rawBaseDeduction;

    final double rawExtraDeduction = transportDeduction + marketDeduction + cultureDeduction;
    final double extraDeduction = rawExtraDeduction > 3000000.0 ? 3000000.0 : rawExtraDeduction;

    final double totalDeductionRaw = baseDeduction + extraDeduction;
    final double finalDeduction = totalDeductionRaw > 7000000.0 ? 7000000.0 : totalDeductionRaw;

    String guideMessage = '아직 공제 문턱에 미달했습니다. 신용카드 할인/포인트 혜택 위주로 현명하게 소비하세요.';

    if (totalSpend >= threshold) {
      guideMessage = '문턱 돌파 완료! 지금부터 체크카드 및 현금영수증 결제 시 30% 고율 공제가 적용됩니다.';
    }

    return CreditCardDeductionResult(
      threshold: threshold,
      totalSpend: totalSpend,
      excessSpend: excessSpend,
      finalDeduction: TaxRates.truncateWon(finalDeduction),
      guideMessage: guideMessage,
    );
  }

  /// 카드 소득공제로 줄어드는 결정세액(=연말정산 환급 예상분)을 추정한다.
  /// 카드공제만 반영 — 홈 "올해 쌓인 예상 환급"의 자라는 숫자용.
  /// taxSaving = 결정세액(카드공제 전) − 결정세액(카드공제 후). 근로세액공제까지 반영해
  /// 정직한 환급 예상액을 낸다. 과표가 0(무세액)이면 saving도 0.
  static CreditCardRefundEstimate estimateCreditCardRefund({
    required double grossAnnual,
    int dependentsIncludingSelf = 1,
    required double creditCardYtd,
    required double debitCashYtd,
    /// 자녀등 수 — 기본한도 상향(조특법 §126의2⑩, 2025 개정).
    int childrenCount = 0,
  }) {
    final double threshold = grossAnnual * 0.25;
    final double totalEligible = creditCardYtd + debitCashYtd;
    if (grossAnnual <= 0) {
      return const CreditCardRefundEstimate(
        deduction: 0, taxSaving: 0, isCapped: false, threshold: 0, totalEligibleSpend: 0);
    }

    final cc = calculateCreditCardDeduction(
      grossIncome: grossAnnual,
      creditCard: creditCardYtd,
      debitCardAndCash: debitCashYtd,
      traditionalMarket: 0, publicTransport: 0, cultureExpense: 0,
      childrenCount: childrenCount,
    );
    final double deduction = cc.finalDeduction;

    // 과세표준(카드공제 제외) 구성 — estimateMonthlyIncomeTax와 동일 조합.
    final double laborIncome = grossAnnual - calculateLaborDeduction(grossAnnual);
    final int heads = dependentsIncludingSelf < 1 ? 1 : dependentsIncludingSelf;
    final double personal = TaxRates.basicDeductionPerPerson * heads;
    final double insurance = calculateAnnualInsuranceDeduction(grossAnnual / 12).total;
    double baseBeforeCard = laborIncome - personal - insurance;
    if (baseBeforeCard < 0) baseBeforeCard = 0;
    double baseAfterCard = baseBeforeCard - deduction;
    if (baseAfterCard < 0) baseAfterCard = 0;

    double decidedTaxOf(double taxBase) {
      final double calc = TaxRates.calculateTax(taxBase);
      final double labor =
          calculateLaborTaxCredit(grossIncome: grossAnnual, calculatedTaxShare: calc);
      final double d = calc - labor;
      return d < 0 ? 0 : d;
    }

    final double saving = decidedTaxOf(baseBeforeCard) - decidedTaxOf(baseAfterCard);
    // 카드공제만 쓰면 기본한도가 실질 상한 — 추가한도(전통시장 등)는 미반영.
    final double baseLimit =
        creditCardBaseLimit(grossIncome: grossAnnual, childrenCount: childrenCount);

    return CreditCardRefundEstimate(
      deduction: deduction,
      taxSaving: saving < 0 ? 0 : TaxRates.truncateWon(saving),
      isCapped: deduction >= baseLimit - 1,
      threshold: threshold,
      totalEligibleSpend: totalEligible,
    );
  }

  /// 5월 종합소득세 신고 및 월세 경정청구 환급 시뮬레이터
  /// 자격: 총급여 8천·근로소득금액 6천 이하 무주택 세대주 (조특법 §95의2).
  /// 무주택·세대주는 자가신고 영역이라 월세 입력자는 충족으로 보되(기본 true),
  /// 계산 가능한 소득 요건은 게이트해 고소득자 과대 환급을 막는다.
  static RentRefundResult simulateRentRefund({
    required double grossIncome,
    required double monthlyRent,
    required double decidedTax,
    bool isHomeless = true,
  }) {
    final double annualRent = monthlyRent * 12;
    final double laborIncomeAmount = grossIncome - calculateLaborDeduction(grossIncome);
    if (!isRentCreditEligible(
      grossIncome: grossIncome,
      globalIncomeAmount: laborIncomeAmount,
      isHomeless: isHomeless,
    )) {
      return RentRefundResult(
        totalAnnualRent: annualRent,
        expectedRefund: 0,
        isRefundCapped: false,
      );
    }
    final double rentLimit = annualRent > 10000000.0 ? 10000000.0 : annualRent;
    final double creditRate = grossIncome <= 55000000.0 ? 0.17 : 0.15;
    
    final double calculatedRefund = rentLimit * creditRate;
    bool isCapped = false;
    double actualRefund = calculatedRefund;

    if (calculatedRefund > decidedTax) {
      actualRefund = decidedTax;
      isCapped = true;
    }

    return RentRefundResult(
      totalAnnualRent: annualRent,
      expectedRefund: TaxRates.truncateWon(actualRefund),
      isRefundCapped: isCapped,
    );
  }
}
