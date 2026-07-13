/// 종합소득세 및 각종 세제 혜택 산정에 필요한 세율 구간 및 요율 정의 클래스
class TaxRates {
  /// 종합소득세 세율 구간 정의 정보 (2024~2025년 귀속 기준 동일)
  static const List<TaxBracket> incomeTaxBrackets = [
    TaxBracket(limit: 14000000, rate: 0.06, deduction: 0),
    TaxBracket(limit: 50000000, rate: 0.15, deduction: 1260000),
    TaxBracket(limit: 88000000, rate: 0.24, deduction: 5760000),
    TaxBracket(limit: 150000000, rate: 0.35, deduction: 15440000),
    TaxBracket(limit: 300000000, rate: 0.38, deduction: 19940000),
    TaxBracket(limit: 500000000, rate: 0.40, deduction: 25940000),
    TaxBracket(limit: 1000000000, rate: 0.42, deduction: 35940000),
    TaxBracket(limit: double.infinity, rate: 0.45, deduction: 65940000),
  ];

  /// 인적공제 기본 공제액 (1인당 150만 원) — 소득세법 §50①, 연도 무관 고정액.
  static const double basicDeductionPerPerson = 1500000.0;

  /// 인적공제 추가공제액 (2025 귀속)
  static const double additionalDeductionElderly = 1000000.0;  // 경로우대(70세 이상)
  static const double additionalDeductionDisabled = 2000000.0; // 장애인
  static const double additionalDeductionFemale = 500000.0;    // 부녀자
  static const double additionalDeductionSingleParent = 1000000.0; // 한부모

  /// 표준세액공제 (특별소득·특별세액·월세공제 미신청 근로자) — 소득세법 §59의4④, 연도 무관 고정액.
  static const double standardTaxCredit = 130000.0;

  /// 혼인세액공제 (2024~2026 혼인신고, 생애 1회)
  static const double marriageTaxCredit = 500000.0;

  /// 자녀세액공제 (소법 §59의2, 2025 귀속 개정)
  /// 8세 이상 기본공제대상 자녀·손자녀: 첫째 25만, 둘째 30만(누적55), 셋째부터 1명당 40만
  static double calculateChildTaxCredit(int childrenCount8OrOlder) {
    if (childrenCount8OrOlder <= 0) return 0.0;
    if (childrenCount8OrOlder == 1) return 250000.0;
    if (childrenCount8OrOlder == 2) return 550000.0;
    return 550000.0 + (childrenCount8OrOlder - 2) * 400000.0;
  }

  /// 출산·입양 세액공제: 첫째 30만, 둘째 50만, 셋째 이상 70만 (해당 과세기간 출산·입양아 순서 기준)
  static double calculateBirthAdoptionTaxCredit({
    required int firstChild,  // 첫째 출산·입양 수(0 또는 1)
    required int secondChild, // 둘째
    required int thirdOrMore, // 셋째 이상 인원
  }) {
    return firstChild.clamp(0, 1) * 300000.0 +
        secondChild.clamp(0, 1) * 500000.0 +
        (thirdOrMore < 0 ? 0 : thirdOrMore) * 700000.0;
  }

  /// 금융소득 분리과세 세율 (소득세법 §129①, 이자·배당 원천징수 14%)
  static const double financialIncomeSeparateTaxRate = 0.14;

  /// 금융소득 분리과세 세율 — 지방소득세(1.4%) 포함 합계 15.4%
  static const double financialIncomeSeparateTaxWithLocal = 0.154;

  /// 금융소득 종합과세 기준 금액 (소득세법 §14③, 연 2,000만원 초과 시 종합합산)
  static const double financialIncomeThreshold = 20000000.0;

  /// 금융소득 건강보험료 추가 산정 기준 (연 1,000만원 초과 시 소득월액 건보료 부과)
  static const double financialIncomeHealthThreshold = 10000000.0;

  /// 프리랜서 원천징수 소득세율 (3.3% 중 국세 3.0%) — 소득세법 §127, 연도 무관 고정율.
  static const double freelancerWithholdingRate = 0.03;

  /// 프리랜서 원천징수 지방소득세율 (3.3% 중 지방세 0.3%) — 지방세법 §103의13, 연도 무관 고정율.
  static const double freelancerLocalWithholdingRate = 0.003;

  /// 국민연금 기준소득월액 상·하한 (2026.7~2027.6 적용 — 단일 출처).
  /// 보험료는 이 범위로 클램프한 월소득에 부과된다. (국민연금법 시행령)
  /// 출처: 보건복지부 고시, 2026-07 시행("659만원→상한, 41만원→하한" 보도) — 확인일 2026-07-13.
  /// 세법유지보수: 매년 7월 고시값으로 갱신. insurance_engine도 이 상수를 참조함.
  static const double nationalPensionBaseUpperLimit = 6590000.0;
  static const double nationalPensionBaseLowerLimit = 410000.0;

  /// 종합소득 과세표준에 따른 산출세액 연산 함수 (세전 금액 기준)
  static double calculateTax(double taxBase) {
    if (taxBase <= 0) return 0;
    
    for (final bracket in incomeTaxBrackets) {
      if (taxBase <= bracket.limit) {
        return (taxBase * bracket.rate) - bracket.deduction;
      }
    }
    return 0;
  }

  /// 10원 미만 절사 (국고금관리법에 의한 원 단위 버림)
  static double truncateWon(double amount) {
    return (amount / 10).floorToDouble() * 10;
  }
}

/// 과세표준 구간 정보 클래스
class TaxBracket {
  final double limit;
  final double rate;
  final double deduction;

  const TaxBracket({
    required this.limit,
    required this.rate,
    required this.deduction,
  });
}
