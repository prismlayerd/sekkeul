/// 조문에서 직접 옮겨 적은 **독립 검산기**.
///
/// 목적은 엔진을 다시 부르지 않고 같은 답이 나오는지 보는 것이다. 그래서 여기서는
/// `TaxRates`·`EmployeeTaxCalculator`를 **import하지 않는다** — 엔진 상수를 빌려 쓰면
/// 상수가 틀렸을 때 양쪽이 똑같이 틀려 대조가 통과해 버린다.
///
/// 모든 숫자는 아래 근거에서 옮겼다(2026 귀속 기준):
/// - 소득세법 §47 근로소득공제 / §50 인적공제 / §51 추가공제 / §51의3 연금보험료공제
/// - 소득세법 §52① 특별소득공제(보험료) / §55① 세율 / §59 근로소득세액공제
/// - 소득세법 §59의2 자녀세액공제 / §59의4⑨ 표준세액공제
/// - 조세특례제한법 §126의2 신용카드등 소득공제
/// - 국민연금법 §88 + 부칙(법률 제20903호) §4 / 국민건강보험법 시행령 §44①
/// - 노인장기요양보험법 시행령 §4 / 고용보험료징수법 시행령 §12①2
library;

/// 국고금관리법 §47 — 국세는 10원 미만 절사.
double trunc10(double v) => (v / 10).floorToDouble() * 10;

// ── 소득세법 §47① 근로소득공제 ────────────────────────────────────
// 500만 이하 70% / ~1,500만 350만+40% / ~4,500만 750만+15%
// / ~1억 1,200만+5% / 1억 초과 1,475만+2%, 공제한도 2,000만(§47②).
double refLaborDeduction(double gross) {
  if (gross <= 0) return 0;
  final double d = gross <= 5000000
      ? gross * 0.7
      : gross <= 15000000
          ? 3500000 + (gross - 5000000) * 0.4
          : gross <= 45000000
              ? 7500000 + (gross - 15000000) * 0.15
              : gross <= 100000000
                  ? 12000000 + (gross - 45000000) * 0.05
                  : 14750000 + (gross - 100000000) * 0.02;
  return d > 20000000 ? 20000000 : d;
}

// ── 소득세법 §55① 종합소득세율 (2023 개정 이후 8구간) ──────────────
const _brackets = <(double limit, double rate, double progressive)>[
  (14000000, 0.06, 0),
  (50000000, 0.15, 1260000),
  (88000000, 0.24, 5760000),
  (150000000, 0.35, 15440000),
  (300000000, 0.38, 19940000),
  (500000000, 0.40, 25940000),
  (1000000000, 0.42, 35940000),
  (double.infinity, 0.45, 65940000),
];

double refProgressiveTax(double taxBase) {
  if (taxBase <= 0) return 0;
  for (final (limit, rate, progressive) in _brackets) {
    if (taxBase <= limit) return taxBase * rate - progressive;
  }
  return 0;
}

// ── 소득세법 §59 근로소득세액공제 ─────────────────────────────────
// 산출세액 130만 이하 55% / 초과 71만 5천 + 초과분 30%.
// 한도(§59②): 3,300만 이하 74만 / ~7,000만 74만−(초과×0.008), 하한 66만
//            / ~1.2억 66만−(초과×1/2), 하한 50만 / 1.2억 초과 50만−(초과×1/2), 하한 20만.
double refLaborTaxCreditLimit(double gross) {
  if (gross <= 0) return 0;
  if (gross <= 33000000) return 740000;
  if (gross <= 70000000) {
    final v = 740000 - (gross - 33000000) * 0.008;
    return v < 660000 ? 660000 : v;
  }
  if (gross <= 120000000) {
    final v = 660000 - (gross - 70000000) * 0.5;
    return v < 500000 ? 500000 : v;
  }
  final v = 500000 - (gross - 120000000) * 0.5;
  return v < 200000 ? 200000 : v;
}

double refLaborTaxCredit({required double gross, required double calculatedTax}) {
  if (gross <= 0 || calculatedTax <= 0) return 0;
  final raw = calculatedTax <= 1300000
      ? calculatedTax * 0.55
      : 715000 + (calculatedTax - 1300000) * 0.3;
  final limit = refLaborTaxCreditLimit(gross);
  return raw > limit ? limit : raw;
}

// ── 4대보험 근로자 본인부담 (월) ──────────────────────────────────
// 국민연금 4.75% — 국민연금법 부칙(법률 제20903호) §4의 2026년 단계 요율(총 9.5%)의 절반.
//   기준소득월액 상한 659만 / 하한 41만으로 클램프한 뒤 부과.
// 건강보험 3.595% — 국민건강보험법 시행령 §44① 요율 7.19%의 절반.
// 장기요양 = 건강보험료 × 13.14% — 노인장기요양보험법 시행령 §4.
//   (소득 대비 0.9448% ÷ 건보요율 7.19% = 13.14%)
// 고용보험 0.9% — 보험료징수법 시행령 §12①2.
typedef RefInsurance = ({double pension, double special, double total});

RefInsurance refAnnualInsurance(double monthlyGross) {
  if (monthlyGross <= 0) return (pension: 0, special: 0, total: 0);
  final npBase = monthlyGross > 6590000
      ? 6590000.0
      : (monthlyGross < 410000 ? 410000.0 : monthlyGross);
  final np = trunc10(npBase * 0.0475);
  // 건강보험은 **보험료액 자체**에 상·하한이 걸린다(보건복지부고시 제2025-222호).
  // 소득에 캡을 씌우고 요율을 곱하면 하한이 어긋난다.
  // 고시액은 노사 합산이라 본인부담은 그 1/2.
  final rawHi = monthlyGross * 0.03595;
  final hi = trunc10(rawHi < 20160 / 2
      ? 20160 / 2
      : (rawHi > 9183480 / 2 ? 9183480 / 2 : rawHi));
  final ltc = trunc10(hi * (0.009448 / 0.0719));
  final ei = trunc10(monthlyGross * 0.009);
  final pension = np * 12;
  final special = (hi + ltc + ei) * 12;
  return (pension: pension, special: special, total: pension + special);
}

// ── 결정세액 (세액공제 반영 전, 근로세액공제까지만) ─────────────────
// 특별소득공제(보험료)를 택하는 길과 표준세액공제 13만을 택하는 길은 함께 갈 수 없다
// (소법 §59의4⑨). 회사는 유리한 쪽을 적용했을 것이므로 둘 중 작은 결정세액을 쓴다.
double refDecidedTax({
  required double gross,
  int headcount = 1,
  double additionalPersonalDeduction = 0,
  /// 카드공제처럼 표준세액공제를 택해도 살아남는 소득공제.
  double otherIncomeDeduction = 0,
  /// 주택자금처럼 §52 특별소득공제라 표준을 택하면 포기하는 소득공제.
  double specialIncomeDeduction = 0,
  /// false면 표준세액공제 길을 따지지 않고 특별공제 길로만 계산한다.
  /// (홈 '환급 카운터'가 쓰는 간이 경로와 같은 잣대로 맞춰볼 때 쓴다.)
  bool compareStandard = true,
}) {
  if (gross <= 0) return 0;
  final ins = refAnnualInsurance(gross / 12);
  final laborIncome = gross - refLaborDeduction(gross);
  final heads = headcount < 1 ? 1 : headcount;

  double path({required bool standard}) {
    double base = laborIncome -
        1500000.0 * heads - // §50① 기본공제 1인 150만
        additionalPersonalDeduction -
        ins.total -
        otherIncomeDeduction -
        (standard ? 0.0 : specialIncomeDeduction);
    if (base < 0) base = 0;
    // 표준세액공제를 택하면 보험료 특별소득공제(§52①)를 되돌린다.
    // 연금보험료공제(§51의3)는 특별소득공제가 아니라 그대로 남는다.
    if (standard) base += ins.special;
    final calculated = refProgressiveTax(base);
    final decided = calculated -
        refLaborTaxCredit(gross: gross, calculatedTax: calculated) -
        (standard ? 130000.0 : 0.0); // §59의4⑨ 표준세액공제 13만
    return decided < 0 ? 0 : decided;
  }

  final a = path(standard: false);
  if (!compareStandard) return a;
  final b = path(standard: true);
  return a < b ? a : b;
}

// ── 조특법 §126의2 신용카드등 소득공제 ────────────────────────────
// 최저사용금액 = 총급여 25%. 최저사용금액은 공제율이 낮은 결제수단부터 차감하므로,
// 초과분은 공제율이 높은 쪽(대중교통·전통시장 40% → 도서공연 30% → 체크·현금 30%
// → 신용카드 15%) 순서로 채워 넣은 것과 같다.
// 기본한도: 총급여 7천만 이하 300만 + 자녀 1명당 50만(2명 한도)
//          / 7천만 초과 250만 + 자녀 1명당 25만.
// 추가한도(전통시장·대중교통·도서공연 통합): 7천만 이하 300만 / 초과 200만.
double refCardBaseLimit({required double gross, int children = 0}) {
  final kids = children < 0 ? 0 : (children > 2 ? 2 : children);
  return gross <= 70000000 ? 3000000 + kids * 500000 : 2500000 + kids * 250000;
}

double refCardDeduction({
  required double gross,
  required double credit,
  required double debitCash,
  double market = 0,
  double transport = 0,
  double culture = 0,
  int children = 0,
}) {
  final threshold = gross * 0.25;
  final total = credit + debitCash + market + transport + culture;
  double rest = total > threshold ? total - threshold : 0;

  double take(double bucket) {
    final t = rest > bucket ? bucket : rest;
    rest -= t;
    return t;
  }

  final aTransport = take(transport);
  final aMarket = take(market);
  // 도서·공연 등은 총급여 7천만원 이하만 대상.
  final aCulture = gross <= 70000000 ? take(culture) : 0.0;
  final aDebit = take(debitCash);
  final aCredit = take(credit);

  final base = aDebit * 0.30 + aCredit * 0.15;
  final baseLimit = refCardBaseLimit(gross: gross, children: children);
  final extra = aTransport * 0.40 + aMarket * 0.40 + aCulture * 0.30;
  final extraLimit = gross <= 70000000 ? 3000000.0 : 2000000.0;

  return trunc10((base > baseLimit ? baseLimit : base) +
      (extra > extraLimit ? extraLimit : extra));
}

// ── 소득세법 §59의2① 자녀세액공제 ────────────────────────────────
// 공제대상 자녀: 첫째 25만 / 둘째 30만(누적 55만) / 셋째부터 1명당 40만.
// 출산·입양: 첫째 30만 / 둘째 50만 / 셋째 이상 70만.
double refChildTaxCredit({required int children, int newborn = 0}) {
  double c = 0;
  for (int i = 0; i < children; i++) {
    c += i == 0 ? 250000 : (i == 1 ? 300000 : 400000);
  }
  for (int i = 0; i < newborn; i++) {
    c += i == 0 ? 300000 : (i == 1 ? 500000 : 700000);
  }
  return c;
}

// ── 소득세법 §51① 추가공제 ───────────────────────────────────────
// 경로우대(70세 이상) 100만 / 장애인 200만 / 부녀자 50만 / 한부모 100만.
// 부녀자와 한부모가 겹치면 한부모만 적용(§51②).
double refAdditionalPersonalDeduction({
  bool elderly70 = false,
  bool femaleHead = false,
  bool singleParent = false,
}) {
  double d = 0;
  if (elderly70) d += 1000000;
  if (singleParent) {
    d += 1000000;
  } else if (femaleHead) {
    d += 500000;
  }
  return d;
}

// ── 소득세법 §21③·시행령 §87 기타소득금액 ────────────────────────
// 인적용역 기타소득의 필요경비는 총수입금액의 60% 정률 → 소득금액은 40%.
double refOtherIncomeAmount(double grossOther) => grossOther * 0.4;
