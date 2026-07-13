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

/// 특수형태근로자(노무제공자) 산재보험료율 매핑 테이블 (임의의 대표 요율 - 실무 고시안에 따라 변경 가능)
/// 기준: 2026년 본인 부담분 (%)
const Map<String, double> specialWorkerIndustrialRates = {
  '940918': 0.009, // 퀵서비스/배달 (0.9%)
  '940906': 0.004, // 보험설계사 (0.4%)
  '940913': 0.010, // 대리운전 (1.0%)
  '940903': 0.003, // 학습지/학원강사 (0.3%)
};

/// 2026년 기준 4대보험 계산 엔진 (오프라인 로컬 퍼스트)
class InsuranceEngine {
  // 국민연금(직장인 본인부담)·지역가입자 요율 — 2026-01-01 국민연금법 개정 시행으로
  // 9.0%→9.5%(지역), 4.5%→4.75%(직장 본인부담)로 인상됨(2033년까지 매년 0.5%p씩 13%로 단계 인상).
  // 출처: 보건복지부 보도자료(2026 국민연금 개혁, 시행일 2026-01-01) — 확인일 2026-07-13 (D-2).
  static const double empNationalPensionRate = 0.0475;
  // 건강보험(직장인 본인부담, 노사 각 50%) — 2026년 전체 요율 7.19%의 절반.
  // 출처: 보건복지부 고시 "2026년 건강보험료율 7.19%로 결정" — 확인일 2026-07-13.
  static const double empHealthInsuranceRate = 0.03595;
  // 장기요양보험료율 — 건강보험료 대비 비율. 2026년 13.14%(2025년 12.95%에서 인상).
  // 출처: 보건복지부 고시 "2026년도 장기요양보험료율 0.9448%" 보도자료 — 확인일 2026-07-13.
  static const double longTermCareRate = 0.1314;
  // 고용보험(실업급여분, 근로자 부담) — 2026년 0.9%로 수년째 동일.
  // 출처: 고용보험법 시행령 별표, 2026년 4대보험 요율 정리 — 확인일 2026-07-13.
  static const double empEmploymentInsuranceRate = 0.0090;

  // N잡러 소득월액보험료·지역가입자 건강보험료 — 직장인 본인부담(3.595%)의 2배인
  // 전체 요율 7.19%를 그대로 적용(소득월액/지역보험료는 노사 분담이 아니라 전액 부과).
  // 출처: 위 empHealthInsuranceRate와 동일 고시 — 확인일 2026-07-13.
  static const double njobHealthInsuranceRate = 0.0719;

  static const double freeNationalPensionRate = 0.095;
  // 지역가입자 재산 점수당 금액 — *2026-07-13 기준 미검증*, 국민건강보험공단 고시 대조 필요(다음 패스).
  static const double healthScoreUnitAmount = 211.5;

  // 특고 고용보험 본인부담 — *2026-07-13 기준 미검증*, 고용보험법 시행령 별표 대조 필요(다음 패스).
  static const double specialWorkerEmploymentRate = 0.008; // 0.8%

  // 국민연금 기준소득월액 상·하한 — TaxRates 단일 출처 참조(드리프트 방지).
  static const double pensionLowerBound = TaxRates.nationalPensionBaseLowerLimit;
  static const double pensionUpperBound = TaxRates.nationalPensionBaseUpperLimit;

  // 건강보험료 부과 기준소득월액 상·하한 — *2026-07-13 기준 미검증*,
  // 국민건강보험공단 고시 대조 필요(다음 패스).
  static const double healthLowerBound = 280667;
  static const double healthUpperBound = 127725731;

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

    // 연금/건보 소득에 캡 적용
    final double pensionIncome = applyCap(monthlyGrossIncome, pensionLowerBound, pensionUpperBound);
    final double healthIncome = applyCap(monthlyGrossIncome, healthLowerBound, healthUpperBound);

    final double nationalPension = TaxRates.truncateWon(pensionIncome * empNationalPensionRate);
    final double healthInsurance = TaxRates.truncateWon(healthIncome * empHealthInsuranceRate);
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
    // 소득월액보험료도 건보 상하한선 적용
    final double cappedIncome = applyCap(taxableMonthlyIncome, 0, healthUpperBound); 
    
    final double extraHealth = TaxRates.truncateWon(cappedIncome * njobHealthInsuranceRate);
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
    
    // 2) 건강보험료 (캡 적용)
    final double healthIncome = applyCap(monthlyReportedIncome, healthLowerBound, healthUpperBound);
    final double incomeHealthPremium = monthlyReportedIncome > 0 
        ? TaxRates.truncateWon(healthIncome * njobHealthInsuranceRate) 
        : 0.0;

    final double computedHealthScore = HealthInsuranceData.getPropertyScore(propertyValue);
    final double propertyHealthPremium = computedHealthScore > 0 
        ? TaxRates.truncateWon(computedHealthScore * healthScoreUnitAmount) 
        : 0.0;

    final double healthInsurance = incomeHealthPremium + propertyHealthPremium;
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
