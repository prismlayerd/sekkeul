/// 경정청구 전용 — 귀속연도별 공제 규정.
///
/// 앱의 다른 계산은 전부 [TaxYear.reference](올해) 기준이면 되지만, 경정청구만은
/// 지난 5년치를 다루므로 **영수증의 귀속연도 규정**으로 계산해야 한다. 당해연도
/// 상수로 과거를 계산하면 틀린 환급액을 자신 있게 내놓게 된다.
///
/// 여기에는 **연도별로 실제 값이 갈리는 항목만** 담는다. 2021~2026 귀속 동안
/// 값이 변하지 않은 항목(교육비 15%, 보장성보험 100만·12%, 의료비 3% 문턱·700만
/// 한도, 연금계좌 15%/12% 소득경계 5,500만)은 엔진 상수를 그대로 쓴다.
///
/// 출처: 국세청 「개정세법 해설」 2022~2026년판 (../sekkeul-지식/원문텍스트/).
/// 각 값 옆 주석의 페이지는 그 값이 바뀐 판의 원문 위치다.
library;

class YearRules {
  final int year;

  // ── 기부금 (소득세법 §59의4⑧) ──
  /// 1천만원 이하분 공제율.
  final double donationRateLow;

  /// 1천만원 초과분 공제율.
  final double donationRateHigh;

  /// 3천만원 초과분 공제율. 한시 특례가 없는 해는 [donationRateHigh]와 같다.
  final double donationRateTop;

  // ── 의료비 (소득세법 §59의4②) ──
  /// 난임시술비 공제율.
  final double infertilityRate;

  // ── 연금계좌 (소득세법 §59의3) ──
  /// 연금저축 단독 납입한도.
  final double pensionSavingsLimit;

  /// 연금저축+퇴직연금 합산 납입한도.
  final double pensionAccountLimit;

  /// 총급여 1.2억(종합소득금액 1억) 초과 시 연금저축 한도.
  /// 2023 귀속부터 이 구분이 폐지되어 [pensionSavingsLimit]과 같다.
  final double pensionSavingsLimitHighIncome;

  // ── 월세액 (조특법 §95의2) ──
  /// 대상자 총급여 상한.
  final double rentGrossIncomeLimit;

  /// 대상자 종합소득금액 상한(직장인은 근로소득금액).
  final double rentGlobalIncomeLimit;

  /// 총급여 5,500만원 초과자 공제율.
  final double rentRateHigh;

  /// 총급여 5,500만원 이하자 공제율.
  final double rentRateLow;

  /// 연간 월세액 공제한도.
  final double rentLimit;

  const YearRules({
    required this.year,
    required this.donationRateLow,
    required this.donationRateHigh,
    required this.donationRateTop,
    required this.infertilityRate,
    required this.pensionSavingsLimit,
    required this.pensionAccountLimit,
    required this.pensionSavingsLimitHighIncome,
    required this.rentGrossIncomeLimit,
    required this.rentGlobalIncomeLimit,
    required this.rentRateHigh,
    required this.rentRateLow,
    required this.rentLimit,
  });
}

/// 앱이 경정청구를 계산할 수 있는 귀속연도 범위.
const int kOldestCorrectionYear = 2021;
const int kNewestCorrectionYear = 2026;

const Map<int, YearRules> _rulesByYear = {
  // 2021 귀속 — 기부금 한시 상향(20/35%)이 살아 있고, 난임은 아직 20%,
  // 연금저축 한도 400만, 월세는 10/12%·750만·총급여 7천만.
  2021: YearRules(
    year: 2021,
    donationRateLow: 0.20, // 2022년판 p.35: '21.1.1.~'21.12.31. 기부분 5%p 한시 상향
    donationRateHigh: 0.35,
    donationRateTop: 0.35,
    infertilityRate: 0.20, // 2022년판 p.34: 20% → 30%는 2022.1.1. 이후 지출분부터
    pensionSavingsLimit: 4000000.0, // 2023년판 p.60 '종전' 표(50세 미만 기준)
    pensionAccountLimit: 7000000.0,
    pensionSavingsLimitHighIncome: 3000000.0, // 총급여 1.2억 초과
    rentGrossIncomeLimit: 70000000.0,
    rentGlobalIncomeLimit: 60000000.0,
    rentRateHigh: 0.10, // 2023년판 p.309: 15/17%는 2023.1.1. 이후 연말정산분부터
    rentRateLow: 0.12,
    rentLimit: 7500000.0,
  ),

  // 2022 귀속 — 기부금 한시 상향 1년 연장(2023년판 p.58). 난임 30%로 인상.
  // 월세 공제율 상향은 '2023.1.1. 이후 연말정산하는 분'이라 2022 귀속부터 적용.
  2022: YearRules(
    year: 2022,
    donationRateLow: 0.20, // 2023년판 p.58: '22.1.1.~'22.12.31. 기부분까지 연장
    donationRateHigh: 0.35,
    donationRateTop: 0.35,
    infertilityRate: 0.30,
    pensionSavingsLimit: 4000000.0,
    pensionAccountLimit: 7000000.0,
    pensionSavingsLimitHighIncome: 3000000.0,
    rentGrossIncomeLimit: 70000000.0,
    rentGlobalIncomeLimit: 60000000.0,
    rentRateHigh: 0.15, // 2023년판 p.309 적용시기: 2023.1.1. 이후 연말정산분
    rentRateLow: 0.17,
    rentLimit: 7500000.0,
  ),

  // 2023 귀속 — 연금계좌 한도 600/900만으로 확대(2023년판 p.60, 2023.1.1. 납입분부터).
  // 월세 한도·소득기준 상향은 아직(2024.1.1. 개시 과세연도부터).
  2023: YearRules(
    year: 2023,
    donationRateLow: 0.15,
    donationRateHigh: 0.30,
    donationRateTop: 0.30,
    infertilityRate: 0.30,
    pensionSavingsLimit: 6000000.0,
    pensionAccountLimit: 9000000.0,
    pensionSavingsLimitHighIncome: 6000000.0,
    rentGrossIncomeLimit: 70000000.0,
    rentGlobalIncomeLimit: 60000000.0,
    rentRateHigh: 0.15,
    rentRateLow: 0.17,
    rentLimit: 7500000.0,
  ),

  // 2024 귀속 — 월세 소득기준 8천만·한도 1,000만(2024년판 p.271).
  // 고액기부 3천만 초과 40% 한시(2024년판 p.64, 2024.12.31.까지 기부분에 한함).
  2024: YearRules(
    year: 2024,
    donationRateLow: 0.15,
    donationRateHigh: 0.30,
    donationRateTop: 0.40,
    infertilityRate: 0.30,
    pensionSavingsLimit: 6000000.0,
    pensionAccountLimit: 9000000.0,
    pensionSavingsLimitHighIncome: 6000000.0,
    rentGrossIncomeLimit: 80000000.0,
    rentGlobalIncomeLimit: 70000000.0,
    rentRateHigh: 0.15,
    rentRateLow: 0.17,
    rentLimit: 10000000.0,
  ),

  // 2025·2026 귀속 — 6개 항목 모두 개정 없음(2025년판·2026년판 확인).
  2025: YearRules(
    year: 2025,
    donationRateLow: 0.15,
    donationRateHigh: 0.30,
    donationRateTop: 0.30,
    infertilityRate: 0.30,
    pensionSavingsLimit: 6000000.0,
    pensionAccountLimit: 9000000.0,
    pensionSavingsLimitHighIncome: 6000000.0,
    rentGrossIncomeLimit: 80000000.0,
    rentGlobalIncomeLimit: 70000000.0,
    rentRateHigh: 0.15,
    rentRateLow: 0.17,
    rentLimit: 10000000.0,
  ),
  2026: YearRules(
    year: 2026,
    donationRateLow: 0.15,
    donationRateHigh: 0.30,
    donationRateTop: 0.30,
    infertilityRate: 0.30,
    pensionSavingsLimit: 6000000.0,
    pensionAccountLimit: 9000000.0,
    pensionSavingsLimitHighIncome: 6000000.0,
    rentGrossIncomeLimit: 80000000.0,
    rentGlobalIncomeLimit: 70000000.0,
    rentRateHigh: 0.15,
    rentRateLow: 0.17,
    rentLimit: 10000000.0,
  ),
};

/// 귀속연도의 규정. 원문으로 확인하지 못한 연도는 null — 계산하지 않는다.
YearRules? rulesForYear(int year) => _rulesByYear[year];

/// 경정청구 기한 (국세기본법 §45의2 ①·⑤).
///
/// ⑤항이 연말정산 대상자에게는 "법정신고기한"을 **"연말정산세액의 납부기한"**으로
/// 바꿔 읽게 한다. 연말정산은 다음 연도 2월분 급여 지급 시 원천징수하고
/// (소득세법 §137①), 원천징수세액은 징수일이 속한 달의 다음 달 10일까지 납부한다
/// (소득세법 §128①). 그래서 기한은 5월 31일이 아니라 **다음 연도 3월 10일 + 5년**이다.
///
/// 반기별 납부 특례(§128②)를 쓰는 사업장은 이보다 뒤지만, 짧은 쪽으로 안내한다.
DateTime correctionDeadline(int accrualYear) =>
    DateTime(accrualYear + 6, 3, 10);

/// 해당 귀속연도를 [now] 시점에 아직 경정청구할 수 있는가.
bool isCorrectionOpen(int accrualYear, DateTime now) =>
    !now.isAfter(correctionDeadline(accrualYear));
