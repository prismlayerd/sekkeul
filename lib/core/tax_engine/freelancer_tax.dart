import '../data/occupation_data.dart';
import 'tax_rates.dart';

/// 간편장부(실제경비) vs 추계(경비율) 비교 결과.
typedef BookkeepingComparison = ({
  FreelancerTaxResult bookkeeping,
  FreelancerTaxResult estimate,
  bool bookkeepingIsBetter,
});

/// 프리랜서 전용 세액 계산 및 시뮬레이션 엔진
class FreelancerTaxCalculator {
  /// 프리랜서 종합소득세 및 지방소득세 시뮬레이션 결과 클래스
  static FreelancerTaxResult calculateTaxSimulation({
    required double accumulatedIncome, // 현재까지의 누적 세전 수입 (원 단위)
    required int inputMonths,          // 입력 기간 (1개월 ~ 12개월)
    required int allowanceCount,       // 본인 제외 부양가족 수
    required String occupationCode,    // 업종코드 (예: '940909')
    bool isBookkeeping = false,        // 기장 신고 여부 (기본값 false)
    double yellowUmbrellaPayment = 0.0, // 연간 노란우산공제 납입액
    double monthlyRent = 0.0,          // 월 납부 임차료
    bool isHomeless = false,           // 무주택 세대주 여부
    double freelancerHealthInsurance = 0.0, // 건강보험 지역가입자 연간 납부액 (전액 소득공제)
    int disabledDependentCount = 0,    // 장애인 부양가족 수 (추가공제 200만/명)
    bool hasSelfDisability = false,    // 본인 장애인 여부
    bool useStandardExpenseRate = false, // true면 단순경비율 대신 기준경비율 적용(적립 범위 산출용)
    double? actualExpense,             // 연환산 실제 필요경비(가계부 기록). 주어지면 경비율 추정 대신 이 값을 사용(간편장부 기장).
  }) {
    // 0. 입력값 방어 코드
    final months = inputMonths < 1 ? 1 : (inputMonths > 12 ? 12 : inputMonths);
    final income = accumulatedIncome < 0 ? 0.0 : accumulatedIncome;
    final dependents = allowanceCount < 0 ? 0 : allowanceCount;

    // 1. 업종 정보 조회 (로컬 데이터 매핑)
    final occupation = OccupationData.occupations[occupationCode];
    final double simpleBaseRate = (occupation?.simpleBaseRate ?? 0.0) / 100.0;
    // 초과율이 없거나 0.0인 경우 기본율을 적용하도록 처리
    double simpleExcessRate = (occupation?.simpleExcessRate ?? 0.0) / 100.0;
    if (simpleExcessRate == 0.0) {
      simpleExcessRate = simpleBaseRate;
    }
    final double standardExpenseRate = (occupation?.standardRate ?? 0.0) / 100.0;
    // 2. 미래 예측 (A안 연환산 연소득 추정)
    // 공식: 누적 수입 / 입력 개월 수 * 12개월
    final double annualEstimatedIncome = (income / months) * 12;

    // 3. 연간 필요경비 산출
    // actualExpense가 주어지면(간편장부 기장) 경비율 추정 대신 실제 경비를 그대로 사용.
    // 아니면 경비율 추정(단순경비율 기준, useStandardExpenseRate이면 기준경비율).
    // 단순경비율 적용 시, 수입 4,000만 원 이하 분은 기본율, 초과분은 초과율 적용
    double estimatedExpense = 0.0;
    if (actualExpense != null) {
      estimatedExpense = actualExpense < 0 ? 0.0 : actualExpense;
    } else if (useStandardExpenseRate) {
      estimatedExpense = annualEstimatedIncome * standardExpenseRate;
    } else if (annualEstimatedIncome <= 40000000) {
      estimatedExpense = annualEstimatedIncome * simpleBaseRate;
    } else {
      estimatedExpense = (40000000 * simpleBaseRate) +
          ((annualEstimatedIncome - 40000000) * simpleExcessRate);
    }

    // 4. 추정 사업소득금액 산출
    final double estimatedBusinessIncome = annualEstimatedIncome - estimatedExpense;

    // 5. 소득공제 차감
    // 인적공제: 본인 공제(150만 원) + 부양가족 수 * 150만 원
    final double basicDeduction = (dependents + 1) * TaxRates.basicDeductionPerPerson;
    // 장애인 추가공제 (200만/명)
    final double disabilityDeduction = (disabledDependentCount + (hasSelfDisability ? 1 : 0)) * 2000000.0;

    // 노란우산공제 한도 산출
    // 노란우산공제(소기업·소상공인 공제부금) 한도 — 2025년 귀속
    // 사업소득금액 4천만 이하 600만 / 6천만 이하 500만 / 1억 이하 400만 / 1억 초과 200만
    double yellowUmbrellaLimit = 0.0;
    if (estimatedBusinessIncome <= 40000000) {
      yellowUmbrellaLimit = 6000000.0;
    } else if (estimatedBusinessIncome <= 60000000) {
      yellowUmbrellaLimit = 5000000.0;
    } else if (estimatedBusinessIncome <= 100000000) {
      yellowUmbrellaLimit = 4000000.0;
    } else {
      yellowUmbrellaLimit = 2000000.0;
    }
    
    // 실제 공제액 (납입액과 한도 중 작은 값)
    final double yellowUmbrellaDeduction = yellowUmbrellaPayment < yellowUmbrellaLimit ? yellowUmbrellaPayment : yellowUmbrellaLimit;
    
    final double totalDeduction = basicDeduction + disabilityDeduction + yellowUmbrellaDeduction + freelancerHealthInsurance;

    // 과세표준
    double taxBase = estimatedBusinessIncome - totalDeduction;
    if (taxBase < 0) {
      taxBase = 0;
    }

    // 6. 종합소득세 산출세액 (국세)
    final double estimatedCalculatedTax = TaxRates.calculateTax(taxBase);

    // 7. 세액공제 적용 — 표준세액공제 7만 원.
    // 기장세액공제(산출세액 20%, 한도 100만)는 간편장부대상자가 "복식부기"로
    // 자발적 기장했을 때만 적용되는 별도 공제(소득세법 §56의2)로, 이 앱이 지원하는
    // 간편장부 기장과는 무관하다. 간편장부·추계 모두 표준세액공제로 동일 적용.
    double taxCredit = 70000.0;
    
    // 월세 세액공제 (조특법 §95의2): 프리랜서는 종합소득금액 6천만 이하 + 무주택
    double rentTaxCredit = 0.0;
    if (monthlyRent > 0 && isHomeless && estimatedBusinessIncome <= 60000000.0) {
      final double annualRent = monthlyRent * 12;
      final double rentLimit = annualRent > 10000000.0 ? 10000000.0 : annualRent;
      final double rentCreditRate = estimatedBusinessIncome <= 55000000.0 ? 0.17 : 0.15;
      rentTaxCredit = TaxRates.truncateWon(rentLimit * rentCreditRate);
    }

    // 결정세액 (산출세액 - 세액공제, 0원 미만 절사)
    double estimatedIncomeTax = estimatedCalculatedTax - taxCredit - rentTaxCredit;
    if (estimatedIncomeTax < 0) {
      estimatedIncomeTax = 0;
    }

    // 8. 지방소득세 결정세액 (지방세 = 결정 소득세의 10%)
    final double estimatedLocalTax = estimatedIncomeTax * 0.1;

    // 결정세액 합산 (원화 절사 적용)
    final double finalAnnualIncomeTax = TaxRates.truncateWon(estimatedIncomeTax);
    final double finalAnnualLocalTax = TaxRates.truncateWon(estimatedLocalTax);
    final double finalAnnualTotalTax = finalAnnualIncomeTax + finalAnnualLocalTax;

    // 9. 기납부세액 계산 (현재까지 실제로 원천징수된 3.3% 누적액)
    // 국세 3% + 지방세 0.3%
    final double paidIncomeTax = TaxRates.truncateWon(income * TaxRates.freelancerWithholdingRate);
    final double paidLocalTax = TaxRates.truncateWon(income * TaxRates.freelancerLocalWithholdingRate);
    final double paidTotalWithholding = paidIncomeTax + paidLocalTax;

    // 연환산 기준 기납부세액 예측치
    final double annualEstimatedWithholdingIncome = TaxRates.truncateWon(annualEstimatedIncome * TaxRates.freelancerWithholdingRate);
    final double annualEstimatedWithholdingLocal = TaxRates.truncateWon(annualEstimatedIncome * TaxRates.freelancerLocalWithholdingRate);
    final double annualEstimatedTotalWithholding = annualEstimatedWithholdingIncome + annualEstimatedWithholdingLocal;

    // 10. 예상 환급액 / 추가 납부액 계산 (예측 연환산 기납부세액 - 추정 결정세액)
    // 결과가 양수(+)이면 돌려받음(환급), 음수(-)이면 추가 납부해야 함
    final double expectedRefundOrPayment = annualEstimatedTotalWithholding - finalAnnualTotalTax;
    final double expectedIncomeTaxRefundOrPayment = annualEstimatedWithholdingIncome - finalAnnualIncomeTax;
    final double expectedLocalTaxRefundOrPayment = annualEstimatedWithholdingLocal - finalAnnualLocalTax;

    // 11. 세금 비축 넛지용 월 권장 저축액 산출
    double monthlyReserve = 0.0;
    String reserveNudgeMessage = '';
    
    if (expectedRefundOrPayment < 0) {
      final double additionalPayment = expectedRefundOrPayment.abs();
      final int remainingMonths = 12 - months;
      
      if (remainingMonths > 0) {
        monthlyReserve = additionalPayment / remainingMonths;
        // 10원 단위 절사하여 저축액 산출
        monthlyReserve = TaxRates.truncateWon(monthlyReserve);
        reserveNudgeMessage = '이번 달 소득에 대해 ${monthlyReserve.toInt()}원을 준비해 주세요. 내년 5월 종합소득세 신고 시 요긴하게 쓰실 수 있어요.';
      } else {
        // 12월의 경우 남은 달이 없으므로 추가 납부액 총액 자체를 준비하도록 안내
        monthlyReserve = TaxRates.truncateWon(additionalPayment);
        reserveNudgeMessage = '내년 5월 종합소득세 신고 시 요긴하게 쓰실 수 있도록 이번 달 소득에 대해 ${monthlyReserve.toInt()}원을 준비해 주세요.';
      }
    } else {
      reserveNudgeMessage = '현재 환급이 예상되는 상태입니다! 남은 기간 동안 사업 필요경비 적격증빙(사업용 신용카드, 지출증빙용 현금영수증)을 꼼꼼히 챙겨두시면 세금을 더 줄일 수 있어요.';
    }

    return FreelancerTaxResult(
      annualEstimatedIncome: annualEstimatedIncome,
      estimatedExpense: estimatedExpense,
      estimatedBusinessIncome: estimatedBusinessIncome,
      taxBase: taxBase,
      annualIncomeTax: finalAnnualIncomeTax,
      annualLocalTax: finalAnnualLocalTax,
      annualTotalTax: finalAnnualTotalTax,
      paidTotalWithholding: paidTotalWithholding,
      annualEstimatedTotalWithholding: annualEstimatedTotalWithholding,
      expectedRefundOrPayment: expectedRefundOrPayment,
      expectedIncomeTaxRefundOrPayment: expectedIncomeTaxRefundOrPayment,
      expectedLocalTaxRefundOrPayment: expectedLocalTaxRefundOrPayment,
      monthlyReserve: monthlyReserve,
      reserveNudgeMessage: reserveNudgeMessage,
      occupationName: occupation?.name ?? '미등록 업종',
      simpleBaseRate: occupation?.simpleBaseRate ?? 0.0,
      simpleExcessRate: occupation?.simpleExcessRate ?? 0.0,
      standardRate: occupation?.standardRate ?? 0.0,
      isBookkeeping: isBookkeeping,
      taxCredit: taxCredit,
      yellowUmbrellaDeduction: yellowUmbrellaDeduction,
      yellowUmbrellaLimit: yellowUmbrellaLimit,
      rentTaxCredit: rentTaxCredit,
      healthInsuranceDeduction: freelancerHealthInsurance,
    );
  }

  /// 단순경비율/기준경비율 두 가정을 각각 계산해 세금 적립 최소~최대 범위를 낸다.
  /// (가계부 적립 카드용 — 어느 쪽이 더 큰지는 업종마다 달라 직접 계산해 정렬한다.)
  static ({FreelancerTaxResult min, FreelancerTaxResult max}) calculateTaxRange({
    required double accumulatedIncome,
    required int inputMonths,
    required int allowanceCount,
    required String occupationCode,
    bool isBookkeeping = false,
    double yellowUmbrellaPayment = 0.0,
    double monthlyRent = 0.0,
    bool isHomeless = false,
    double freelancerHealthInsurance = 0.0,
    int disabledDependentCount = 0,
    bool hasSelfDisability = false,
  }) {
    final simple = calculateTaxSimulation(
      accumulatedIncome: accumulatedIncome,
      inputMonths: inputMonths,
      allowanceCount: allowanceCount,
      occupationCode: occupationCode,
      isBookkeeping: isBookkeeping,
      yellowUmbrellaPayment: yellowUmbrellaPayment,
      monthlyRent: monthlyRent,
      isHomeless: isHomeless,
      freelancerHealthInsurance: freelancerHealthInsurance,
      disabledDependentCount: disabledDependentCount,
      hasSelfDisability: hasSelfDisability,
      useStandardExpenseRate: false,
    );
    final standard = calculateTaxSimulation(
      accumulatedIncome: accumulatedIncome,
      inputMonths: inputMonths,
      allowanceCount: allowanceCount,
      occupationCode: occupationCode,
      isBookkeeping: isBookkeeping,
      yellowUmbrellaPayment: yellowUmbrellaPayment,
      monthlyRent: monthlyRent,
      isHomeless: isHomeless,
      freelancerHealthInsurance: freelancerHealthInsurance,
      disabledDependentCount: disabledDependentCount,
      hasSelfDisability: hasSelfDisability,
      useStandardExpenseRate: true,
    );
    final lower = simple.annualTotalTax <= standard.annualTotalTax ? simple : standard;
    final higher = simple.annualTotalTax <= standard.annualTotalTax ? standard : simple;
    return (min: lower, max: higher);
  }

  /// 간편장부(실제 경비) vs 추계(경비율) 중 어느 쪽 세액이 더 낮은지 비교한다.
  /// [accumulatedActualExpense]는 가계부에 기록된 사업용 지출 누적액(같은 [inputMonths] 기간 기준) —
  /// 소득과 동일한 방식(누적→연환산)으로 처리해 두 방식을 같은 기준에서 비교한다.
  static BookkeepingComparison compareBookkeepingVsEstimate({
    required double accumulatedIncome,
    required double accumulatedActualExpense,
    required int inputMonths,
    required int allowanceCount,
    required String occupationCode,
    double yellowUmbrellaPayment = 0.0,
    double monthlyRent = 0.0,
    bool isHomeless = false,
    double freelancerHealthInsurance = 0.0,
    int disabledDependentCount = 0,
    bool hasSelfDisability = false,
  }) {
    final months = inputMonths < 1 ? 1 : (inputMonths > 12 ? 12 : inputMonths);
    final rawExpense = accumulatedActualExpense < 0 ? 0.0 : accumulatedActualExpense;
    final annualActualExpense = (rawExpense / months) * 12;

    final bookkeeping = calculateTaxSimulation(
      accumulatedIncome: accumulatedIncome,
      inputMonths: inputMonths,
      allowanceCount: allowanceCount,
      occupationCode: occupationCode,
      isBookkeeping: true,
      actualExpense: annualActualExpense,
      yellowUmbrellaPayment: yellowUmbrellaPayment,
      monthlyRent: monthlyRent,
      isHomeless: isHomeless,
      freelancerHealthInsurance: freelancerHealthInsurance,
      disabledDependentCount: disabledDependentCount,
      hasSelfDisability: hasSelfDisability,
    );

    final range = calculateTaxRange(
      accumulatedIncome: accumulatedIncome,
      inputMonths: inputMonths,
      allowanceCount: allowanceCount,
      occupationCode: occupationCode,
      yellowUmbrellaPayment: yellowUmbrellaPayment,
      monthlyRent: monthlyRent,
      isHomeless: isHomeless,
      freelancerHealthInsurance: freelancerHealthInsurance,
      disabledDependentCount: disabledDependentCount,
      hasSelfDisability: hasSelfDisability,
    );

    return (
      bookkeeping: bookkeeping,
      estimate: range.min,
      bookkeepingIsBetter: bookkeeping.annualTotalTax <= range.min.annualTotalTax,
    );
  }
}

/// 프리랜서 시뮬레이션 결과 데이터 구조 클래스
class FreelancerTaxResult {
  final double annualEstimatedIncome;       // 연환산 추정 세전 수입
  final double estimatedExpense;            // 단순경비율 적용 추정 필요경비
  final double estimatedBusinessIncome;     // 추정 사업소득금액
  final double taxBase;                     // 추정 과세표준
  final double annualIncomeTax;             // 연간 추정 종합소득세 (국세)
  final double annualLocalTax;              // 연간 추정 지방소득세 (지방세)
  final double annualTotalTax;              // 연간 추정 세액 합계
  final double paidTotalWithholding;         // 현재까지 기납부한 3.3% 세액 (누적)
  final double annualEstimatedTotalWithholding; // 연환산 추정 기납부 3.3% 세액 합계
  final double expectedRefundOrPayment;     // 예상 환급액(+) 또는 추가 납부액(-)
  final double expectedIncomeTaxRefundOrPayment; // 예상 종합소득세 환급/납부액
  final double expectedLocalTaxRefundOrPayment;  // 예상 지방소득세 환급/납부액
  final double monthlyReserve;              // 월별 세금 비축 권장 저축액 (추가 납부 발생 시)
  final String reserveNudgeMessage;         // 사용자 친화적 세금 비축 넛지 메시지
  final String occupationName;              // 조회된 업종명
  final double simpleBaseRate;              // 업종 단순경비율 기본율
  final double simpleExcessRate;            // 업종 단순경비율 초과율
  final double standardRate;                // 업종 기준경비율
  final bool isBookkeeping;                 // 기장 신고 여부
  final double taxCredit;                   // 적용된 세액공제액 (기장세액공제 또는 표준세액공제)
  final double yellowUmbrellaDeduction;     // 적용된 노란우산공제액
  final double yellowUmbrellaLimit;         // 산출된 노란우산공제 한도
  final double rentTaxCredit;               // 월세 세액공제액
  final double healthInsuranceDeduction;    // 건강보험 지역가입자 소득공제액

  FreelancerTaxResult({
    required this.annualEstimatedIncome,
    required this.estimatedExpense,
    required this.estimatedBusinessIncome,
    required this.taxBase,
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
    required this.occupationName,
    required this.simpleBaseRate,
    required this.simpleExcessRate,
    required this.standardRate,
    required this.isBookkeeping,
    required this.taxCredit,
    required this.yellowUmbrellaDeduction,
    required this.yellowUmbrellaLimit,
    required this.rentTaxCredit,
    required this.healthInsuranceDeduction,
  });
}
