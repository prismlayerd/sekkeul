import 'tax_year.dart';

/// 종합소득세 및 각종 세제 혜택 산정에 필요한 세율 구간 및 요율 정의 클래스
class TaxRates {
  /// 종합소득세 세율 구간 정의 정보 (2024~2026년 귀속 기준 동일)
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

  /// 인적공제 추가공제액 (2025~2026 귀속 동일)
  static const double additionalDeductionElderly = 1000000.0;  // 경로우대(70세 이상)
  static const double additionalDeductionDisabled = 2000000.0; // 장애인
  static const double additionalDeductionFemale = 500000.0;    // 부녀자
  static const double additionalDeductionSingleParent = 1000000.0; // 한부모

  /// 표준세액공제 (특별소득·특별세액·월세공제 미신청 근로자) — 소득세법 §59의4④, 연도 무관 고정액.
  static const double standardTaxCredit = 130000.0;

  /// 혼인세액공제 (2024~2026 혼인신고, 생애 1회)
  static const double marriageTaxCredit = 500000.0;

  /// 자녀세액공제 금액 (소득세법 §59의2①)
  /// 첫째 25만, 둘째 30만(누적 55), 셋째부터 1명당 40만. 금액은 2025~2026 동일.
  ///
  /// **대상 자녀의 연령 요건은 [childTaxCreditMinAge]로 따로 판정한다** — 2026.4.21.
  /// 개정으로 연도마다 달라졌다.
  static double calculateChildTaxCredit(int eligibleChildrenCount) {
    if (eligibleChildrenCount <= 0) return 0.0;
    if (eligibleChildrenCount == 1) return 250000.0;
    if (eligibleChildrenCount == 2) return 550000.0;
    return 550000.0 + (eligibleChildrenCount - 2) * 400000.0;
  }

  /// 자녀세액공제 대상 최소 연령 (소득세법 §59의2①).
  ///
  /// 아동수당 지급 연령이 8세 미만 → 13세 미만으로 2030년까지 매년 한 살씩 상향되면서,
  /// 중복 수혜를 막으려고 자녀세액공제 연령도 같이 올라간다
  /// (법률 제21548호, 2026.4.21. 개정·공포한 날 시행).
  ///
  /// 부칙 §2② — 2026년 9세, 2027년 10세, 2028년 11세, 2029년 12세.
  /// 본칙(§59의2①)은 13세이며 2030년 귀속부터 그대로 적용된다.
  ///
  /// ⚠ 이 개정은 2026.4.21.자라 「2026년 개정세법 해설」(2026.4.15. 발간)에 없다.
  ///   연 1회 발간물만 보면 발간 이후 개정을 놓친다.
  static int childTaxCreditMinAge(int taxYear) {
    if (taxYear <= 2025) return 8;
    if (taxYear >= 2030) return 13;
    return taxYear - 2017; // 2026:9 · 2027:10 · 2028:11 · 2029:12
  }

  /// 자녀세액공제 대상 자녀의 출생연도 상한 — 이 해 12월 31일 이전 출생이면 대상.
  ///
  /// 소득세법의 연령 환산은 **나이 = 귀속연도 − 출생연도**다. 국세청 연말정산 안내가
  /// 2025 귀속 기준으로 "60세 이상=1965.12.31. 이전, 20세 이하=2005.1.1. 이후,
  /// 70세 이상=1955.12.31. 이전"으로 안내하는 것과 같은 방식이다
  /// (`../sekkeul-지식/JSON/2025_연말정산_공제율_정답지.json`).
  ///
  /// 부칙 §2③이 **2017년생을 §2②(경과 연령)에서 배제**한다. 그래서 2026~2029 귀속
  /// 동안 상한이 2016년생에 고정되고, 본칙이 적용되는 2030 귀속에 2017년생이 들어온다.
  static int childTaxCreditBirthYearCutoff(int taxYear) {
    final int cutoff = taxYear - childTaxCreditMinAge(taxYear);
    // 부칙 §2③ — 2017.1.1.~2017.12.31. 출생자는 경과규정 대상이 아니다.
    if (taxYear >= 2026 && taxYear <= 2029 && cutoff == 2017) return 2016;
    return cutoff;
  }

  /// 화면에 쓰는 자녀세액공제 대상 안내 — "2016년생 이하".
  ///
  /// 나이("9세 이상")로 안내하면 사용자가 만 나이인지 연 나이인지 헷갈리고,
  /// 2017년생 예외(부칙 §2③)를 표현할 수도 없다. 출생연도로 못박는다.
  static String childTaxCreditEligibilityLabel([int? taxYear]) =>
      '${childTaxCreditBirthYearCutoff(taxYear ?? kReferenceTaxYear)}년생 이하';

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

  /// 기타소득 원천징수 소득세율 — 총수입금액 대비 8.0%.
  /// (기타소득금액(=수입의 40%)에 20% 원천징수 → 수입 기준 8%. 지방세 포함 8.8%,
  /// 가계부 세전 역산 ÷0.912와 동일한 상수 체계.) 소득세법 §129①6.
  static const double otherIncomeWithholdingRate = 0.08;

  /// 기타소득 원천징수 지방소득세율 — 총수입금액 대비 0.8%.
  static const double otherIncomeLocalWithholdingRate = 0.008;

  /// 국민연금 기준소득월액 상·하한 (2026.7~2027.6 적용 — 단일 출처).
  /// 보험료는 이 범위로 클램프한 월소득에 부과된다. (국민연금법 시행령)
  /// 출처: 보건복지부 고시, 2026-07 시행("659만원→상한, 41만원→하한" 보도) — 확인일 2026-07-13.
  /// 세법유지보수: 매년 7월 고시값으로 갱신. insurance_engine도 이 상수를 참조함.
  static const double nationalPensionBaseUpperLimit = 6590000.0;
  static const double nationalPensionBaseLowerLimit = 410000.0;

  /// 단순경비율 필요경비 — 소득세법 시행령 §143③1의2.
  /// 수입금액 4,000만원 이하분은 기본율, 초과분은 초과율.
  static double simpleRateExpense({
    required double revenue,
    required double baseRate,
    required double excessRate,
  }) {
    if (revenue <= 0) return 0;
    final ex = excessRate == 0 ? baseRate : excessRate;
    if (revenue <= 40000000) return revenue * baseRate;
    return 40000000 * baseRate + (revenue - 40000000) * ex;
  }

  /// 기준경비율 추계 소득금액 — 소득세법 시행령 §143③1.
  ///
  /// 기준경비율은 **주요경비(매입비용·임차료·인건비)를 증빙으로 따로 빼는 것을 전제**한
  /// 율이다. 이 앱은 주요경비를 받지 않으므로 수입에 (1−기준경비율)을 곱하기만 하는데,
  /// 그러면 소득금액이 과대해진다. 조문은 그 안전판으로 상한을 둔다 —
  /// **단순경비율로 계산한 소득금액 × 배율**(간편장부 2.8배 / 복식부기 3.4배)이 한도다.
  /// 적용기한은 2027.12.31.까지 연장됐다(2025년 개정세법 해설).
  ///
  /// 이 상한이 없으면 보험설계사·골프장캐디·퀵서비스배달원·개인간병인 등
  /// 단순경비율이 높은 인적용역 업종에서 세금이 크게 과대 계산된다.
  static double standardRateIncome({
    required double revenue,
    required double standardRate,
    required double simpleIncomeAmount,
    /// 복식부기의무자면 3.4. 이 앱은 복식부기 판정 시 계산을 멈추므로 기본은 간편장부.
    double multiple = 2.8,
  }) {
    if (revenue <= 0) return 0;
    final raw = revenue * (1 - standardRate);
    final cap = simpleIncomeAmount * multiple;
    return raw > cap ? cap : raw;
  }

  /// 최저임금 시급 — 최저임금법 §10, 고용노동부 고시. **매년 바뀐다.**
  ///
  /// 종전에는 이 값이 시급 계산기·최저임금 영향·주휴수당 세 화면에 따로 박혀
  /// 있었다. 갱신할 때 하나를 빠뜨리면 화면마다 다른 최저임금을 말하게 된다.
  /// 실업급여 구직급여 하한액도 여기서 파생된다(§46② 최저임금일액의 80%).
  static const double minimumHourlyWage2026 = 10320.0;
  static const double minimumHourlyWage2025 = 10030.0;

  /// 구직급여 하한액 — 고용보험법 §46②: 최저임금일액(시급 × 8시간)의 80%.
  static const double unemploymentDailyFloor = minimumHourlyWage2026 * 8 * 0.8;

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

  /// 과세표준이 속한 한계세율(%) — 안내 문구용.
  ///
  /// 화면이 세율 구간표를 따로 들고 있으면 개정 때 반드시 낡는다. 실제로 홈
  /// N잡러 배너가 2022년 이전 표(1,200만·4,600만)를 들고 "2024년 기준"이라고
  /// 주석까지 달아 둔 채 굳어 있었다. 구간표는 [incomeTaxBrackets] 하나만 본다.
  static int marginalRatePercent(double taxBase) {
    for (final b in incomeTaxBrackets) {
      if (taxBase <= b.limit) return (b.rate * 100).round();
    }
    return (incomeTaxBrackets.last.rate * 100).round();
  }

  /// 10원 미만 절사 (국고금관리법 §47).
  ///
  /// **먼저 원 단위로 반올림한 뒤** 10원 미만을 버린다. 곧바로 버리면 부동소수점
  /// 오차 때문에 딱 떨어지는 금액이 10원씩 깎인다 —
  /// `3,000,000 × 0.009`는 `26999.999999999996`이라 27,000원이 26,990원이 됐다.
  /// 법이 정하는 최소 단위가 원이므로 원으로 맞춘 뒤 절사하는 것이 조문에도 맞다.
  static double truncateWon(double amount) {
    return (amount.roundToDouble() / 10).floorToDouble() * 10;
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
