import 'tax_rates.dart';
import '../data/health_insurance_data.dart';

class EmployeeInsuranceResult {
  final double nationalPension;
  final double healthInsurance;
  final double longTermCare;
  final double employmentInsurance;
  final double industrialAccident;
  final double totalMonthlyPremium;

  EmployeeInsuranceResult({
    required this.nationalPension,
    required this.healthInsurance,
    required this.longTermCare,
    required this.employmentInsurance,
    required this.industrialAccident,
    required this.totalMonthlyPremium,
  });
}

class NJobInsuranceResult {
  final double extraHealthInsurance;
  final double extraLongTermCare;
  final double totalMonthlyExtraPremium;

  NJobInsuranceResult({
    required this.extraHealthInsurance,
    required this.extraLongTermCare,
    required this.totalMonthlyExtraPremium,
  });
}

class FreelancerInsuranceResult {
  final double nationalPension;
  final double healthInsurance;
  final double longTermCare;
  final double employmentInsurance;
  final double industrialAccident;
  final double totalMonthlyPremium;
  final double computedHealthScore;

  FreelancerInsuranceResult({
    required this.nationalPension,
    required this.healthInsurance,
    required this.longTermCare,
    required this.employmentInsurance,
    required this.industrialAccident,
    required this.totalMonthlyPremium,
    required this.computedHealthScore,
  });
}

/// 노무제공자(특고) 직종별 산재보험료율 — **본인 부담분**.
///
/// 요율: 고용노동부고시 제2025-92호「노무제공자 직종별 산재보험료율」
///       (2025.12.31. 고시, 시행 2026.1.1.~2026.12.31.). 단위는 천분율(‰).
/// 부담: 보험료징수법 §48의6⑥ 본문 — 사업주와 노무제공자가 각각 2분의 1.
///       같은 법 시행령 §56의10이 "산재보험료율의 2분의 1을 곱한 금액"으로 확인.
///       ⑥ 단서(사업주 전액 부담 직종)의 위임 규정은 시행령에 없다 → 전 직종 1/2.
///
/// ⚠ 매년 갱신 대상. 고시 유효기간이 2026.12.31.로 끝난다.
/// ※ 시행령 §56의11의 감경·면제(저소득 등)는 반영하지 않는다 — 과다 표시 방향(보수적).
const Map<String, double> specialWorkerIndustrialRates = {
  '940918': 0.0085, // 퀵서비스(늘찬배달원) — 고시 7. 17‰ ÷ 2
  '940906': 0.0025, // 보험설계사 — 고시 1. 5‰ ÷ 2
  '940913': 0.0090, // 대리운전 — 고시 10. 18‰ ÷ 2
  '940903': 0.0035, // 학습지 방문강사 — 고시 4. 7‰ ÷ 2
};

/// 2026년 기준 4대보험 계산 엔진 (오프라인 로컬 퍼스트)
class InsuranceEngine {
  // ── 국민연금 (국민연금법 §88③④ + 부칙 <법률 제20903호, 2025.4.2.> §4) ──
  // 본칙은 사업장 1천분의 65(6.5%)·지역 1천분의 130(13%)이지만, 부칙 §4가
  // 2026~2032년을 단계 인상으로 따로 정한다. 2033년 귀속부터 본칙이 그대로 적용된다.
  //   사업장 기여금: '26 1만분의 475 · '27 500 · '28 525 · '29 550 · '30 575 · '31 600 · '32 625
  //   지역·임의가입: '26 1천분의 95 · '27 100 · '28 105 · '29 110 · '30 115 · '31 120 · '32 125
  // 확인: 국가법령정보센터 조문·부칙 원문 — 2026-07-27.
  static const double empNationalPensionRate = 0.0475;  // 2026년 사업장가입자 본인 기여금
  static const double freeNationalPensionRate = 0.095;  // 2026년 지역·임의·임의계속가입자

  // ── 건강보험 (국민건강보험법 시행령 §44) ──
  // ① 직장·지역가입자 보험료율: 1만분의 719 (2025.12.23. 개정)
  static const double healthInsuranceRate = 0.0719;
  // 직장가입자는 노사가 각 1/2 부담(법 §76①) → 본인부담은 절반.
  static const double empHealthInsuranceRate = healthInsuranceRate / 2;
  // 소득월액보험료·지역가입자 보험료는 노사 분담이 없어 전액 부과.
  static const double njobHealthInsuranceRate = healthInsuranceRate;
  // ② 지역가입자 재산보험료부과점수당 금액: 211.5원 (2025.12.23. 개정)
  static const double healthScoreUnitAmount = 211.5;

  // 월별 보험료액의 상한·하한 (보건복지부고시 제2025-222호, 시행 2026.1.1.)
  //
  // ⚠ 고시가 정하는 것은 '소득'이 아니라 **보험료액**이다. 소득에 캡을 걸고 요율을
  //   곱하면 상한은 우연히 맞아도 하한이 어긋난다(종전 구현이 그랬다).
  static const double healthPremiumCapSalaried = 9183480.0; // 직장 보수월액보험료(노사 합산)
  static const double healthPremiumCapOther = 4591740.0;    // 소득월액보험료·지역 월별보험료액
  static const double healthPremiumFloor = 20160.0;         // 직장 보수월액보험료·지역 공통
  // ※ 소득월액보험료에는 하한이 없다(고시 §3은 보수월액보험료와 지역가입자만 정함).

  // ── 장기요양 (노인장기요양보험법 §9① + 같은 법 시행령 §4) ──
  // 시행령 §4: 장기요양보험료율 100만분의 9,448 (2025.12.30. 개정)
  // 법 §9①: 장기요양보험료 = 건강보험료액 × (건강보험료율 대비 장기요양보험료율의 비율)
  // 나눗셈으로 두면 둘 중 하나만 바뀌어도 비율이 자동으로 맞는다.
  static const double longTermCareInsuranceRate = 0.009448;
  static const double longTermCareRate = longTermCareInsuranceRate / healthInsuranceRate;

  // ── 고용보험 (고용보험 및 산재보험의 보험료징수 등에 관한 법률 시행령) ──
  // §12①2 실업급여 보험료율 1천분의 18 → 사업주·근로자 각 1/2.
  static const double empEmploymentInsuranceRate = 0.0090;
  // §56의7④ 노무제공자(특고) 고용보험료율 1천분의 16 → 노무제공자·사업주 각 1/2.
  static const double specialWorkerEmploymentRate = 0.008;

  // 국민연금 기준소득월액 상·하한 — 이쪽은 실제로 '소득'의 상하한이 맞다(보건복지부 고시).
  // TaxRates 단일 출처 참조(드리프트 방지).
  static const double pensionLowerBound = TaxRates.nationalPensionBaseLowerLimit;
  static const double pensionUpperBound = TaxRates.nationalPensionBaseUpperLimit;

  /// 유틸리티: 상하한선 캡(Cap) 적용
  static double applyCap(double income, double lower, double upper) {
    if (income < lower) return lower;
    if (income > upper) return upper;
    return income;
  }

  /// 1. 직장인 4대보험 계산 (매월)
  static EmployeeInsuranceResult calculateEmployeeInsurance(double monthlyGrossIncome) {
    if (monthlyGrossIncome <= 0) {
      return EmployeeInsuranceResult(
        nationalPension: 0, healthInsurance: 0, longTermCare: 0, 
        employmentInsurance: 0, industrialAccident: 0, totalMonthlyPremium: 0
      );
    }

    // 국민연금은 기준소득월액(소득)에 상·하한을 적용한다.
    final double pensionIncome = applyCap(monthlyGrossIncome, pensionLowerBound, pensionUpperBound);
    final double nationalPension = TaxRates.truncateWon(pensionIncome * empNationalPensionRate);

    // 건강보험은 보험료액 자체에 상·하한이 걸린다. 여기 값은 본인부담분이라 고시액의 1/2로 캡.
    final double healthInsurance = TaxRates.truncateWon(applyCap(
      monthlyGrossIncome * empHealthInsuranceRate,
      healthPremiumFloor / 2,
      healthPremiumCapSalaried / 2,
    ));
    final double longTermCare = TaxRates.truncateWon(healthInsurance * longTermCareRate);
    
    // 고용/산재는 상하한액 없음 (무제한)
    final double employmentInsurance = TaxRates.truncateWon(monthlyGrossIncome * empEmploymentInsuranceRate);
    final double industrialAccident = 0.0;

    final double total = nationalPension + healthInsurance + longTermCare + employmentInsurance + industrialAccident;

    return EmployeeInsuranceResult(
      nationalPension: nationalPension,
      healthInsurance: healthInsurance,
      longTermCare: longTermCare,
      employmentInsurance: employmentInsurance,
      industrialAccident: industrialAccident,
      totalMonthlyPremium: total,
    );
  }

  /// 2. N잡러 소득월액보험료 추가 부과 계산 (매월 기준)
  static NJobInsuranceResult calculateNJobExtraInsurance(double annualExtraIncome) {
    if (annualExtraIncome <= 20000000) {
      return NJobInsuranceResult(extraHealthInsurance: 0, extraLongTermCare: 0, totalMonthlyExtraPremium: 0);
    }

    final double taxableMonthlyIncome = (annualExtraIncome - 20000000) / 12;
    // 소득월액보험료는 보험료액에 상한만 있다(하한 없음 — 고시 §3).
    final double extraHealth = TaxRates.truncateWon(applyCap(
      taxableMonthlyIncome * njobHealthInsuranceRate,
      0,
      healthPremiumCapOther,
    ));
    final double extraLongTermCare = TaxRates.truncateWon(extraHealth * longTermCareRate);

    return NJobInsuranceResult(
      extraHealthInsurance: extraHealth,
      extraLongTermCare: extraLongTermCare,
      totalMonthlyExtraPremium: extraHealth + extraLongTermCare,
    );
  }

  /// 3. 프리랜서 및 특수형태근로자 4대보험 계산 (매월 기준)
  static FreelancerInsuranceResult calculateFreelancerInsurance({
    required double annualIncome,
    required double propertyValue, 
    String? occupationCode, // 업종코드 추가 (특고 매핑용)
  }) {
    final double monthlyReportedIncome = annualIncome / 12;
    
    // 1) 국민연금 (캡 적용)
    final double pensionIncome = applyCap(monthlyReportedIncome, pensionLowerBound, pensionUpperBound);
    final double nationalPension = monthlyReportedIncome > 0 
        ? TaxRates.truncateWon(pensionIncome * freeNationalPensionRate) 
        : 0.0;
    
    // 2) 건강보험료 — 지역가입자는 소득분(정률) + 재산분(점수제)을 합한
    //    **월별 보험료액**에 상·하한이 걸린다(고시 제2025-222호).
    final double incomeHealthPremium =
        monthlyReportedIncome > 0 ? monthlyReportedIncome * njobHealthInsuranceRate : 0.0;

    final double computedHealthScore = HealthInsuranceData.getPropertyScore(propertyValue);
    final double propertyHealthPremium =
        computedHealthScore > 0 ? computedHealthScore * healthScoreUnitAmount : 0.0;

    final double rawHealthPremium = incomeHealthPremium + propertyHealthPremium;
    final double healthInsurance = rawHealthPremium > 0
        ? TaxRates.truncateWon(
            applyCap(rawHealthPremium, healthPremiumFloor, healthPremiumCapOther))
        : 0.0;
    final double longTermCare = healthInsurance > 0
        ? TaxRates.truncateWon(healthInsurance * longTermCareRate) 
        : 0.0;

    // 3) 특수형태근로자(노무제공자) 고용/산재 부과
    double employmentInsurance = 0.0;
    double industrialAccident = 0.0;

    if (occupationCode != null && specialWorkerIndustrialRates.containsKey(occupationCode)) {
      employmentInsurance = TaxRates.truncateWon(monthlyReportedIncome * specialWorkerEmploymentRate);
      double indRate = specialWorkerIndustrialRates[occupationCode]!;
      industrialAccident = TaxRates.truncateWon(monthlyReportedIncome * indRate);
    }

    final double total = nationalPension + healthInsurance + longTermCare + employmentInsurance + industrialAccident;

    return FreelancerInsuranceResult(
      nationalPension: nationalPension,
      healthInsurance: healthInsurance,
      longTermCare: longTermCare,
      employmentInsurance: employmentInsurance,
      industrialAccident: industrialAccident,
      totalMonthlyPremium: total,
      computedHealthScore: computedHealthScore,
    );
  }
}
