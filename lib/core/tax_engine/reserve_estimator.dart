import '../data/db_helper.dart';
import '../data/occupation_data.dart';
import 'bookkeeping_duty.dart';
import 'combined_tax.dart';
import 'employee_tax.dart';
import 'freelancer_tax.dart';
import 'insurance_engine.dart';

/// 적은 경비가 만들어낸 환급 — 적립 카드의 A/B/C 블록용.
///
/// 직장인 홈의 '올해 쌓인 예상 환급' 카운터와 같은 구조를 프리랜서 기전으로 옮긴 것.
/// 직장인은 신용카드 소득공제로 자라지만 프리랜서는 그 제도 대상이 아니라(적용 불가),
/// 대신 "필요경비 → 소득금액 감소 → 이미 뗀 3.3% 환급"으로 자란다.
///
/// - A: 분기점 아래 — 더 적어도 환급이 안 는다(추계가 유리해 기록이 세금을 안 바꾼다)
/// - B: 분기점 위 — 적을수록 환급이 는다
/// - C: 결정세액 0 — 낸 3.3%를 다 돌려받아 더는 안 는다
class RefundProgress {
  /// 올해 1월~이번 달에 사업경비로 적은 지출 누적액.
  final double recordedExpense;

  /// 같은 기간으로 환산한 분기점 — 추계(경비율)가 인정해주는 경비액.
  /// 기장과 추계는 경비가 같으면 세액도 같으므로(기장세액공제는 복식부기 전용이라
  /// 양쪽 다 표준세액공제) 추계 경비가 곧 분기점이 된다.
  final double breakevenExpense;

  /// 기장(실제 경비)이 추계보다 세금이 낮은가 — 엔진 판정을 그대로 쓴다.
  final bool isAhead;

  /// 기록으로 얻는 환급 증가분 = 추계 세액 − 장부 세액.
  /// 기납부 3.3%는 두 경우 모두 같으므로 세액 감소분이 곧 환급 증가분이다.
  /// 노란우산·건보 등 양쪽에 똑같이 걸리는 공제는 빼고 계산해 어림값이다.
  final double refundGain;

  /// 장부로 신고했을 때 결정세액. 0이면 낸 3.3%를 다 돌려받는 상태(C).
  final double bookkeepingTax;

  /// 추계로 신고했을 때 결정세액. 0이면 어느 쪽으로 신고해도 낼 세금이 없다.
  final double estimateTax;

  const RefundProgress({
    required this.recordedExpense,
    required this.breakevenExpense,
    required this.isAhead,
    required this.refundGain,
    required this.bookkeepingTax,
    required this.estimateTax,
  });

  /// 환급이 자라기 시작하는 지점까지 더 찾아 적어야 할 경비. 이미 넘었으면 0.
  double get shortfall {
    final gap = breakevenExpense - recordedExpense;
    return gap > 0 ? gap : 0;
  }

  /// 결정세액이 0이라 더 적어도 환급이 안 느는 상태.
  bool get isCapped => bookkeepingTax <= 0;

  /// 소득이 과세 문턱 아래라 어느 쪽으로 신고해도 낼 세금이 없는 상태.
  /// 이때는 기록해도 돌려받을 게 없으므로 환급 카운터를 띄우면 안 된다.
  bool get noTaxEitherWay => estimateTax <= 0;

  /// 경비를 아무리 더 찾아도 얻을 수 있는 환급의 천장 = 추계 세액.
  /// 세금은 0 아래로 못 내려가므로 추계로 낼 세액이 곧 최대 이득이다.
  double get maxGain => estimateTax;

  /// 분기점까지 남은 경비를 더 찾을 값어치가 있는가.
  ///
  /// 부양가족·노란우산 등으로 이미 세금이 거의 0인 사람에게는 분기점이 멀어도
  /// 실익이 몇천 원뿐이다. 그런 사람에게 "수백만원어치 더 찾으세요"는 노력과
  /// 보상이 어긋난 요구라 유도하지 않는다.
  // ponytail: 5만원 고정 임계 — 실익 대비 영수증 찾는 수고의 균형점. 사용자 피드백이
  // 쌓이면 소득 대비 비율로 바꿀 것.
  bool get worthPursuing => maxGain >= 50000;
}

/// 프리랜서·N잡러 가계부 적립 카드용 — 이번 달 세금·4대보험 적립 추정치와
/// 사용 가능 금액을 계산한다. 저장하지 않고 매번 프로필 최신값 + 가계부 기록으로 재계산한다.
class ReserveEstimate {
  final double minMonthlyTaxReserve;
  final double maxMonthlyTaxReserve;
  final double insuranceReserve; // 4대보험 월 예상 적립액(가입한 항목만 합산)
  final double monthlyIncome; // 이번 달 사업소득+기타소득 합계(근로소득 제외)
  final double monthlyBusinessExpense; // 이번 달 사업경비로 인정된 지출
  final double minUsable;
  final double maxUsable;
  final bool hasOccupationCode;
  /// 보험 적립을 계산할 수 있을 만큼 프로필(가입 보험)이 설정됐는지.
  /// false면 insuranceReserve 0은 "몰라서 0"이므로 UI에서 '0원' 대신 설정 유도 표현을 쓴다.
  final bool insuranceProfileSet;

  /// 적은 경비가 만들어낸 환급 진행도. null이면 계산 근거가 없다 —
  /// 업종 미설정·직전연도 수입 미입력(경비율 확정 불가)·복식부기 의무자·N잡러.
  final RefundProgress? refundProgress;

  /// 기장의무 판정. null이면 업종 미설정이라 판정 불가.
  /// 화면은 이걸로 "복식부기의무자예요 / 장부 없이 신고하면 20% 가산세" 안내를 띄운다.
  final BookkeepingJudgment? bookkeepingJudgment;

  /// 이번 적립액에 무기장가산세(산출세액 20%)가 포함됐는가.
  /// 소규모사업자(신규·직전연도 4,800만 미만)는 면제라 false.
  final bool includesNoBookkeepingPenalty;

  /// N잡러 카드공제로 줄어드는 연간 세액 — 종합 과세표준 기준.
  /// null이면 해당 없음(프리랜서·직장인). 직장인은 사업소득이 없어
  /// EmployeeTaxCalculator.estimateCreditCardRefund와 결과가 같으므로 쓰지 않는다.
  final double? cardDeductionTaxSaving;

  ReserveEstimate({
    required this.minMonthlyTaxReserve,
    required this.maxMonthlyTaxReserve,
    required this.insuranceReserve,
    required this.monthlyIncome,
    required this.monthlyBusinessExpense,
    required this.minUsable,
    required this.maxUsable,
    required this.hasOccupationCode,
    required this.insuranceProfileSet,
    this.refundProgress,
    this.bookkeepingJudgment,
    this.includesNoBookkeepingPenalty = false,
    this.cardDeductionTaxSaving,
  });
}

class ReserveEstimator {
  /// 세후(원천징수 후) 기록 금액을 세전으로 역산 — 가계부 입력 화면과 동일한 상수 사용.
  static double _grossOf(int amount, String incomeType, bool isWithheld) {
    if (!isWithheld) return amount.toDouble();
    final divisor = incomeType == '기타소득' ? 0.912 : 0.967;
    return amount / divisor;
  }

  static Future<ReserveEstimate> estimateForCurrentMonth({
    required String userType, // '프리랜서' | 'N잡러'
    // null이면 프로필의 부양가족 수를 쓴다. 과거엔 기본값 0이라 호출부 4곳 전부
    // 인적공제가 본인 1명으로 고정되는 버그가 있었다(2026-07-25 수정).
    int? allowanceCount,
  }) async {
    final profile = await dbService.getProfile();
    final occupationCode = (profile?['occupation_code'] as String?) ?? '';
    final hasOccupation = OccupationData.occupations.containsKey(occupationCode);
    final propertyValue = (profile?['property_value'] as num?)?.toDouble() ?? 0.0;
    final pensionEnrolled = profile?['pension_enrolled'] == true;
    final healthEnrolled = profile?['health_enrolled'] == true;
    final employmentEnrolled = profile?['employment_enrolled'] == true;
    final industrialEnrolled = profile?['industrial_accident_enrolled'] == true;
    final profileGrossIncome = (profile?['gross_income'] as num?)?.toDouble() ?? 0.0;
    // ── 프로필의 공제 항목 — 세액 계산에 반영해야 적립액·환급액이 과대되지 않는다 ──
    final allowance = allowanceCount ?? (profile?['dependents'] as int?) ?? 0;
    final disabledDeps = (profile?['disabled_dependent_count'] as int?) ?? 0;
    final selfDisability = profile?['has_self_disability'] == true;
    final yellowUmbrella = (profile?['yellow_umbrella'] as num?)?.toDouble() ?? 0.0;
    final isMonthlyRent = profile?['is_monthly_rent'] == true;
    final ownsHouse = profile?['owns_house'] == true;
    final monthlyRent =
        isMonthlyRent ? ((profile?['monthly_rent'] as num?)?.toDouble() ?? 0.0) : 0.0;
    final childrenCountForCredit = (profile?['children_count_credit'] as int?) ?? 0;
    // 카드공제 기본한도 상향용 — 8세 미만 자녀도 자녀등에 포함된다(조특법 §126의2⑩).
    final childrenCountTotal = (profile?['children_count_total'] as int?) ?? 0;
    final newbornCount = (profile?['newborn_count'] as int?) ?? 0;
    final hasElderly70Plus = profile?['has_elderly_70plus'] == true;
    final isSingleParent = profile?['is_single_parent'] == true;
    final isFemaleHead = profile?['is_female_head'] == true;

    final now = DateTime.now();
    double ytdBusinessIncome = 0;
    double ytdOtherIncome = 0;
    double ytdLaborIncome = 0;
    double thisMonthLaborIncome = 0;
    double thisMonthBusinessIncome = 0;
    double thisMonthOtherIncome = 0;

    for (int m = 1; m <= now.month; m++) {
      final entries = await dbService.getIncomeEntriesForMonth(now.year, m, userType: userType);
      for (final e in entries) {
        switch (e.incomeType) {
          case '사업소득':
            final gross = _grossOf(e.amount, e.incomeType, e.isWithheld);
            ytdBusinessIncome += gross;
            if (m == now.month) thisMonthBusinessIncome += gross;
            break;
          case '기타소득':
            final gross = _grossOf(e.amount, e.incomeType, e.isWithheld);
            ytdOtherIncome += gross;
            if (m == now.month) thisMonthOtherIncome += gross;
            break;
          case '급여':
            ytdLaborIncome += e.amount;
            if (m == now.month) thisMonthLaborIncome += e.amount;
            break;
          default:
            // 레거시 '기타'(N잡러 구분 추가 이전 기록) — 사업소득(3.3%)에 준해 근사 처리.
            final gross = _grossOf(e.amount, '사업소득', e.isWithheld);
            ytdBusinessIncome += gross;
            if (m == now.month) thisMonthBusinessIncome += gross;
        }
      }
    }

    final allExpenses = await dbService.getExpenses(userType: userType);
    final thisMonthBusinessExpense = allExpenses
        .where((x) => x.isBusiness && x.date.year == now.year && x.date.month == now.month)
        .fold<double>(0, (s, x) => s + x.amount);
    // 성과 줄은 수입과 같은 기간(1월~이번 달)을 봐야 같은 기준에서 비교된다.
    final ytdBusinessExpense = allExpenses
        .where((x) => x.isBusiness && x.date.year == now.year && x.date.month <= now.month)
        .fold<double>(0, (s, x) => s + x.amount);
    // N잡러 신용카드 소득공제용 연 누적 사용액 — 근로소득이 있으므로 카드공제 대상.
    // 0으로 넘기면 카드공제가 통째로 빠져 세액·적립액이 과대된다(2026-07-25 수정).
    final ytdCreditCard = allExpenses
        .where((x) => x.paymentMethod == '신용카드' && x.date.year == now.year)
        .fold<double>(0, (s, x) => s + x.amount);
    final ytdDebitCash = allExpenses
        .where((x) => x.paymentMethod == '체크+현금' && x.date.year == now.year)
        .fold<double>(0, (s, x) => s + x.amount);

    final annualOtherIncome = (ytdOtherIncome / now.month) * 12;
    final annualBusinessRevenue = (ytdBusinessIncome / now.month) * 12;

    // 경비율 확정: ①진단에서 저장한 직전연도 수입·신규 여부가 있으면 단순/기준 중
    // 실제 적용될 경비율이 정해진다(min~max 범위가 한 점으로 수렴). 입력한 적이
    // 없으면(직전수입 0·신규 아님) 판정 근거가 없으므로 범위 표시를 유지한다.
    final priorYearIncome = (profile?['prior_year_income'] as num?)?.toInt() ?? 0;
    final isNewBusiness = profile?['is_new_business'] == true;
    final occupation = OccupationData.occupations[occupationCode];
    bool? pinnedStandardRate; // null=판정 불가(범위 유지), true=기준경비율, false=단순경비율
    if (occupation != null && (isNewBusiness || priorYearIncome > 0)) {
      pinnedStandardRate = !isSimpleExpenseRateEligible(
        occupation: occupation,
        priorYearIncome: priorYearIncome,
        isNewBusiness: isNewBusiness,
        currentYearIncome: annualBusinessRevenue,
      );
    }

    double minMonthlyTaxReserve;
    double maxMonthlyTaxReserve;
    double? cardDeductionTaxSaving; // N잡러만 채워진다
    // 건보료(소득월액·지역가입자) 부과 기준은 수입금액(매출)이 아니라 필요경비를 차감한
    // "소득금액"(기타소득은 정률 40%) — 국민건강보험법 §71·시행령 §41, 확인일 2026-07-19.
    double incomeAmountForInsurance;

    // ── 무기장가산세(소득세법 §81의5) ──────────────────────────────
    // 적립액은 "장부 없이 추계신고" 시나리오라, 소규모사업자가 아니면 산출세액의
    // 20%가 더 붙는다. 이걸 빼놓으면 적립액이 실제 낼 돈보다 적게 나온다.
    // 산식: 산출세액 × (무기장 사업소득금액 ÷ 종합소득금액) × 20% — 국세청 요약표.
    final bookkeepingJudgment = occupation == null
        ? null
        : judgeBookkeepingDuty(
            occupation: occupation,
            priorYearIncome: priorYearIncome,
            isNewBusiness: isNewBusiness,
          );
    final penaltyExempt =
        bookkeepingJudgment?.isSmallBusinessExemptFromPenalty ?? true;

    /// 추계 결과에 무기장가산세를 얹는다. 사업소득금액·종합소득금액 비율로 안분.
    /// 가산세 기준은 지방세 포함 결정세액이 아니라 국세 **산출세액**이다
    /// (소득세법 §81의5 — `종합소득산출세액 × 무기장 소득금액/종합소득금액 × 20%`).
    double withPenalty(double annualTotalTax, double calculatedTax,
        double bizIncomeAmount, double otherAmount) {
      if (penaltyExempt || annualTotalTax <= 0) return annualTotalTax;
      final penalty = calculateNoBookkeepingPenalty(
        calculatedTax: calculatedTax,
        businessIncomeAmount: bizIncomeAmount,
        globalIncomeAmount: bizIncomeAmount + otherAmount,
      );
      return annualTotalTax + penalty;
    }

    if (userType == '프리랜서') {
      // 월세 세액공제는 미반영 — 근로소득 없는 사업소득자는 성실사업자(조특법 §122의3)만
      // 대상인데 그 요건 충족 여부를 저장하지 않는다. 미반영은 세액 과대(보수적) 방향.
      if (pinnedStandardRate != null) {
        final result = FreelancerTaxCalculator.calculateTaxSimulation(
          accumulatedIncome: ytdBusinessIncome,
          accumulatedOtherIncome: ytdOtherIncome,
          inputMonths: now.month,
          allowanceCount: allowance,
          occupationCode: occupationCode,
          yellowUmbrellaPayment: yellowUmbrella,
          childrenCountForCredit: childrenCountForCredit,
          newbornCount: newbornCount,
          disabledDependentCount: disabledDeps,
          hasSelfDisability: selfDisability,
          useStandardExpenseRate: pinnedStandardRate,
        );
        // 연간 예상세액을 12로 균등 분배 — "이번 달분"을 직관적으로 보여주기 위함.
        final otherAmt = EmployeeTaxCalculator.calculateOtherIncomeAmount(annualOtherIncome);
        minMonthlyTaxReserve = withPenalty(result.annualTotalTax, result.calculatedTax,
                result.estimatedBusinessIncome, otherAmt) /
            12;
        maxMonthlyTaxReserve = minMonthlyTaxReserve;
        incomeAmountForInsurance = result.estimatedBusinessIncome + otherAmt;
      } else {
        final range = FreelancerTaxCalculator.calculateTaxRange(
          accumulatedIncome: ytdBusinessIncome,
          accumulatedOtherIncome: ytdOtherIncome,
          inputMonths: now.month,
          allowanceCount: allowance,
          occupationCode: occupationCode,
          yellowUmbrellaPayment: yellowUmbrella,
          childrenCountForCredit: childrenCountForCredit,
          newbornCount: newbornCount,
          disabledDependentCount: disabledDeps,
          hasSelfDisability: selfDisability,
        );
        // 연간 예상세액을 12로 균등 분배 — "이번 달분"을 직관적으로 보여주기 위함.
        final otherAmt = EmployeeTaxCalculator.calculateOtherIncomeAmount(annualOtherIncome);
        minMonthlyTaxReserve = withPenalty(range.min.annualTotalTax, range.min.calculatedTax,
                range.min.estimatedBusinessIncome, otherAmt) /
            12;
        maxMonthlyTaxReserve = withPenalty(range.max.annualTotalTax, range.max.calculatedTax,
                range.max.estimatedBusinessIncome, otherAmt) /
            12;
        // 보험료는 단일 값만 표시하므로 소득금액이 큰 쪽(기준경비율)으로 보수적으로 잡는다.
        incomeAmountForInsurance = range.max.estimatedBusinessIncome + otherAmt;
      }
    } else {
      // N잡러 — 근로소득은 프로필의 예상 연봉을 우선 쓴다. 없으면 이번 달 급여 × 12로
      // 잡는다(급여는 매달 규칙적이라 자연스러운 연환산이고, 무엇보다 홈이 카드공제
      // 문턱을 그 기준으로 그리므로 같은 카드 안 두 숫자가 어긋나지 않는다).
      // 이번 달 기록이 아직 없으면(급여일 전) 누적을 경과월로 나눠 대신한다.
      final annualGrossLabor = profileGrossIncome > 0
          ? profileGrossIncome
          : (thisMonthLaborIncome > 0
              ? thisMonthLaborIncome * 12
              : (ytdLaborIncome / now.month) * 12);
      // 근로소득분은 매달 회사가 간이세액표로 이미 원천징수 중이므로, 그 추정 결정세액을
      // decidedTax로 넘겨 "이미 낸 돈"으로 반영한다. 0으로 넘기면 근로소득 전체 세액까지
      // 부업 수입에서 적립하라는 요구가 되어 이중으로 걷어가는 결과가 된다.
      final estimatedLaborDecidedTax = EmployeeTaxCalculator.estimateMonthlyIncomeTax(
            grossAnnual: annualGrossLabor,
            dependentsIncludingSelf: 1 + allowance,
          ) *
          12;
      // 카드 사용액·월세(무주택 월세 거주 시)·인적공제를 실제 기록·프로필에서 넘긴다 —
      // 근로소득이 있는 N잡러는 카드공제·월세 세액공제 대상이라 0으로 두면 세액이 과대된다.
      CombinedTaxResult combined({
        required double creditCard,
        required double debitCardAndCash,
        required bool useStandardRate,
      }) =>
          CombinedTaxCalculator.calculateCombinedTax(
            grossIncome: annualGrossLabor,
            accumulatedFreelancerIncome: ytdBusinessIncome,
            inputMonths: now.month,
            occupationCode: occupationCode,
            creditCard: creditCard,
            debitCardAndCash: debitCardAndCash,
            traditionalMarket: 0,
            publicTransport: 0,
            cultureExpense: 0,
            allowanceCount: allowance,
            decidedTax: estimatedLaborDecidedTax,
            monthlyRent: monthlyRent,
            isHomeless: isMonthlyRent && !ownsHouse,
            yellowUmbrellaPayment: yellowUmbrella,
            childrenCountForCredit: childrenCountForCredit,
            childrenCountTotal: childrenCountTotal,
            newbornCount: newbornCount,
            hasElderly70Plus: hasElderly70Plus,
            isSingleParent: isSingleParent,
            isSingleFemaleHead: isFemaleHead,
            otherIncome: annualOtherIncome,
            useStandardExpenseRate: useStandardRate,
          );

      // ── 카드공제 절세액 (홈 '올해 쌓인 예상 환급' 카운터용) ──────────────
      // 공제액·한도·문턱은 총급여 기준이 맞다(조특법 §126의2 — "근로소득금액에서
      // 공제"). 다만 그렇게 줄어든 과세표준은 종합소득 구간에서 세율이 매겨지므로,
      // 절세액을 근로소득만으로 계산하면 부업이 구간을 밀어올린 만큼 과소 추정된다
      // (실측: 급여 4,000만·부업 8,000만에서 45만 → 79.2만).
      // 경비율은 미확정이면 단순경비율로 둔다 — 차액이라 경비율 선택의 영향은 2차적이다.
      final cardRateBasis = pinnedStandardRate ?? false;
      final taxWithCard = combined(
          creditCard: ytdCreditCard,
          debitCardAndCash: ytdDebitCash,
          useStandardRate: cardRateBasis);
      final taxWithoutCard = combined(
          creditCard: 0, debitCardAndCash: 0, useStandardRate: cardRateBasis);
      final rawCardSaving = taxWithoutCard.annualTotalTax - taxWithCard.annualTotalTax;
      cardDeductionTaxSaving = rawCardSaving > 0 ? rawCardSaving : 0;

      if (pinnedStandardRate != null) {
        final result = combined(
          creditCard: ytdCreditCard,
          debitCardAndCash: ytdDebitCash,
          useStandardRate: pinnedStandardRate,
        );
        // monthlyReserve는 이미 "원천징수 대비 부족분"만 남은 개월수로 나눈 값이라
        // annualTotalTax(근로+사업 합산 전체 세액)를 그대로 12분할하지 않는다.
        // 무기장가산세는 남은 개월로 나눠 붙인다 — monthlyReserve와 같은 잣대를 쓰기 위함.
        final remainMonths = (12 - now.month) < 1 ? 1 : (12 - now.month);
        final penalty = penaltyExempt
            ? 0.0
            : calculateNoBookkeepingPenalty(
                calculatedTax: result.calculatedTax,
                businessIncomeAmount: result.estimatedFreelancerBusinessIncome,
                globalIncomeAmount: result.totalGlobalIncome,
              );
        minMonthlyTaxReserve = result.monthlyReserve + penalty / remainMonths;
        maxMonthlyTaxReserve = minMonthlyTaxReserve;
        incomeAmountForInsurance = result.estimatedFreelancerBusinessIncome + result.otherIncomeAmount;
      } else {
        final range = CombinedTaxCalculator.calculateTaxRange(
          grossIncome: annualGrossLabor,
          accumulatedFreelancerIncome: ytdBusinessIncome,
          inputMonths: now.month,
          occupationCode: occupationCode,
          creditCard: ytdCreditCard,
          debitCardAndCash: ytdDebitCash,
          traditionalMarket: 0,
          publicTransport: 0,
          cultureExpense: 0,
          allowanceCount: allowance,
          decidedTax: estimatedLaborDecidedTax,
          monthlyRent: monthlyRent,
          isHomeless: isMonthlyRent && !ownsHouse,
          yellowUmbrellaPayment: yellowUmbrella,
          childrenCountForCredit: childrenCountForCredit,
          childrenCountTotal: childrenCountTotal,
          newbornCount: newbornCount,
          hasElderly70Plus: hasElderly70Plus,
          isSingleParent: isSingleParent,
          isSingleFemaleHead: isFemaleHead,
          otherIncome: annualOtherIncome,
        );
        // monthlyReserve는 이미 "원천징수 대비 부족분"만 남은 개월수로 나눈 값이라
        // annualTotalTax(근로+사업 합산 전체 세액)를 그대로 12분할하지 않는다.
        final remainMonths = (12 - now.month) < 1 ? 1 : (12 - now.month);
        double pen(CombinedTaxResult x) => penaltyExempt
            ? 0.0
            : calculateNoBookkeepingPenalty(
                calculatedTax: x.calculatedTax,
                businessIncomeAmount: x.estimatedFreelancerBusinessIncome,
                globalIncomeAmount: x.totalGlobalIncome,
              );
        minMonthlyTaxReserve = range.min.monthlyReserve + pen(range.min) / remainMonths;
        maxMonthlyTaxReserve = range.max.monthlyReserve + pen(range.max) / remainMonths;
        incomeAmountForInsurance =
            range.max.estimatedFreelancerBusinessIncome + range.max.otherIncomeAmount;
      }
    }

    double insuranceReserve = 0;
    if (userType == 'N잡러') {
      // N잡러는 이미 직장가입자 — 국민연금·건강보험을 지역가입자처럼 스스로 내지 않는다.
      // 부업 소득금액(수입-필요경비, 기타소득은 40%)이 연 2,000만원을 넘는 분에 대해서만
      // 건보 소득월액보험료가 추가 부과된다. 과거엔 수입금액(매출)을 그대로 넣어 과대 산정했다.
      final extra = InsuranceEngine.calculateNJobExtraInsurance(incomeAmountForInsurance);
      insuranceReserve += extra.totalMonthlyExtraPremium;
      if (employmentEnrolled || industrialEnrolled) {
        final ins = InsuranceEngine.calculateFreelancerInsurance(
          annualIncome: incomeAmountForInsurance,
          propertyValue: propertyValue,
          occupationCode: hasOccupation ? occupationCode : null,
        );
        if (employmentEnrolled) insuranceReserve += ins.employmentInsurance;
        if (industrialEnrolled) insuranceReserve += ins.industrialAccident;
      }
    } else if (pensionEnrolled || healthEnrolled || employmentEnrolled || industrialEnrolled) {
      final ins = InsuranceEngine.calculateFreelancerInsurance(
        annualIncome: incomeAmountForInsurance,
        propertyValue: propertyValue,
        occupationCode: hasOccupation ? occupationCode : null,
      );
      if (pensionEnrolled) insuranceReserve += ins.nationalPension;
      if (healthEnrolled) insuranceReserve += ins.healthInsurance + ins.longTermCare;
      if (employmentEnrolled) insuranceReserve += ins.employmentInsurance;
      if (industrialEnrolled) insuranceReserve += ins.industrialAccident;
    }

    // ── 환급 진행도: 적은 경비가 환급을 얼마나 키웠는가 ────────────────────
    // 프리랜서·간편장부대상자만. N잡러는 근로소득까지 합산해야 세액이 맞는데
    // CombinedTaxCalculator가 실제경비 입력을 받지 않아 아직 계산할 수 없다.
    // pinnedStandardRate가 null이면 적용 경비율 자체가 미정이라 분기점을 못 잡는다.
    RefundProgress? refundProgress;
    if (userType == '프리랜서' &&
        occupation != null &&
        pinnedStandardRate != null &&
        ytdBusinessIncome > 0) {
      final duty = judgeBookkeepingDuty(
        occupation: occupation,
        priorYearIncome: priorYearIncome,
        isNewBusiness: isNewBusiness,
      );
      if (duty.isSimplified) {
        // 적립액과 같은 공제 조건으로 계산해야 카드 안 두 숫자가 같은 세계에 있다.
        final cmp = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
          accumulatedIncome: ytdBusinessIncome,
          accumulatedOtherIncome: ytdOtherIncome,
          accumulatedActualExpense: ytdBusinessExpense,
          inputMonths: now.month,
          allowanceCount: allowance,
          occupationCode: occupationCode,
          yellowUmbrellaPayment: yellowUmbrella,
          childrenCountForCredit: childrenCountForCredit,
          newbornCount: newbornCount,
          disabledDependentCount: disabledDeps,
          hasSelfDisability: selfDisability,
          forceStandardExpenseRate: pinnedStandardRate,
        );
        final gain = cmp.estimate.annualTotalTax - cmp.bookkeeping.annualTotalTax;
        refundProgress = RefundProgress(
          recordedExpense: ytdBusinessExpense,
          // 추계 경비는 연환산값이라 누적 기간으로 되돌려야 기록액과 같은 잣대가 된다.
          breakevenExpense: cmp.estimate.estimatedExpense * now.month / 12,
          isAhead: cmp.bookkeepingIsBetter,
          refundGain: gain > 0 ? gain : 0,
          bookkeepingTax: cmp.bookkeeping.annualTotalTax,
          estimateTax: cmp.estimate.annualTotalTax,
        );
      }
    }

    final monthlyIncome = thisMonthBusinessIncome + thisMonthOtherIncome;
    final minUsableRaw = monthlyIncome - thisMonthBusinessExpense - maxMonthlyTaxReserve - insuranceReserve;
    final maxUsableRaw = monthlyIncome - thisMonthBusinessExpense - minMonthlyTaxReserve - insuranceReserve;

    return ReserveEstimate(
      minMonthlyTaxReserve: minMonthlyTaxReserve,
      maxMonthlyTaxReserve: maxMonthlyTaxReserve,
      insuranceReserve: insuranceReserve,
      monthlyIncome: monthlyIncome,
      monthlyBusinessExpense: thisMonthBusinessExpense,
      minUsable: minUsableRaw < 0 ? 0 : minUsableRaw,
      maxUsable: maxUsableRaw < 0 ? 0 : maxUsableRaw,
      hasOccupationCode: hasOccupation,
      // N잡러 건보 소득월액은 프로필 없이도 소득 기반 자동 산정(0이면 실제 미부과)이라 '설정됨'으로 본다.
      // 프리랜서는 가입 보험을 하나라도 켜야 계산 가능 — 아무것도 없으면 '몰라서 0'.
      insuranceProfileSet: userType == 'N잡러' ||
          pensionEnrolled ||
          healthEnrolled ||
          employmentEnrolled ||
          industrialEnrolled,
      refundProgress: refundProgress,
      bookkeepingJudgment: bookkeepingJudgment,
      includesNoBookkeepingPenalty: !penaltyExempt,
      cardDeductionTaxSaving: cardDeductionTaxSaving,
    );
  }
}
