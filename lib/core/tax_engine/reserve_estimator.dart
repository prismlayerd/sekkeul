import '../data/db_helper.dart';
import '../data/occupation_data.dart';
import 'bookkeeping_duty.dart';
import 'combined_tax.dart';
import 'employee_tax.dart';
import 'freelancer_tax.dart';
import 'insurance_engine.dart';

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

  ReserveEstimate({
    required this.minMonthlyTaxReserve,
    required this.maxMonthlyTaxReserve,
    required this.insuranceReserve,
    required this.monthlyIncome,
    required this.monthlyBusinessExpense,
    required this.minUsable,
    required this.maxUsable,
    required this.hasOccupationCode,
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
    int allowanceCount = 0,
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

    final now = DateTime.now();
    double ytdBusinessIncome = 0;
    double ytdOtherIncome = 0;
    double ytdLaborIncome = 0;
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
    // 건보료(소득월액·지역가입자) 부과 기준은 수입금액(매출)이 아니라 필요경비를 차감한
    // "소득금액"(기타소득은 정률 40%) — 국민건강보험법 §71·시행령 §41, 확인일 2026-07-19.
    double incomeAmountForInsurance;

    if (userType == '프리랜서') {
      if (pinnedStandardRate != null) {
        final result = FreelancerTaxCalculator.calculateTaxSimulation(
          accumulatedIncome: ytdBusinessIncome,
          accumulatedOtherIncome: ytdOtherIncome,
          inputMonths: now.month,
          allowanceCount: allowanceCount,
          occupationCode: occupationCode,
          useStandardExpenseRate: pinnedStandardRate,
        );
        // 연간 예상세액을 12로 균등 분배 — "이번 달분"을 직관적으로 보여주기 위함.
        minMonthlyTaxReserve = result.annualTotalTax / 12;
        maxMonthlyTaxReserve = minMonthlyTaxReserve;
        incomeAmountForInsurance = result.estimatedBusinessIncome +
            EmployeeTaxCalculator.calculateOtherIncomeAmount(annualOtherIncome);
      } else {
        final range = FreelancerTaxCalculator.calculateTaxRange(
          accumulatedIncome: ytdBusinessIncome,
          accumulatedOtherIncome: ytdOtherIncome,
          inputMonths: now.month,
          allowanceCount: allowanceCount,
          occupationCode: occupationCode,
        );
        // 연간 예상세액을 12로 균등 분배 — "이번 달분"을 직관적으로 보여주기 위함.
        minMonthlyTaxReserve = range.min.annualTotalTax / 12;
        maxMonthlyTaxReserve = range.max.annualTotalTax / 12;
        // 보험료는 단일 값만 표시하므로 소득금액이 큰 쪽(기준경비율)으로 보수적으로 잡는다.
        incomeAmountForInsurance = range.max.estimatedBusinessIncome +
            EmployeeTaxCalculator.calculateOtherIncomeAmount(annualOtherIncome);
      }
    } else {
      // N잡러 — 근로소득은 프로필의 예상 연봉을 우선 쓰고, 없으면 지금까지 기록을 연환산한다.
      final annualGrossLabor = profileGrossIncome > 0
          ? profileGrossIncome
          : (ytdLaborIncome / now.month) * 12;
      // 근로소득분은 매달 회사가 간이세액표로 이미 원천징수 중이므로, 그 추정 결정세액을
      // decidedTax로 넘겨 "이미 낸 돈"으로 반영한다. 0으로 넘기면 근로소득 전체 세액까지
      // 부업 수입에서 적립하라는 요구가 되어 이중으로 걷어가는 결과가 된다.
      final estimatedLaborDecidedTax = EmployeeTaxCalculator.estimateMonthlyIncomeTax(
            grossAnnual: annualGrossLabor,
            dependentsIncludingSelf: 1 + allowanceCount,
          ) *
          12;
      if (pinnedStandardRate != null) {
        final result = CombinedTaxCalculator.calculateCombinedTax(
          grossIncome: annualGrossLabor,
          accumulatedFreelancerIncome: ytdBusinessIncome,
          inputMonths: now.month,
          occupationCode: occupationCode,
          creditCard: 0,
          debitCardAndCash: 0,
          traditionalMarket: 0,
          publicTransport: 0,
          cultureExpense: 0,
          allowanceCount: allowanceCount,
          decidedTax: estimatedLaborDecidedTax,
          monthlyRent: 0,
          otherIncome: annualOtherIncome,
          useStandardExpenseRate: pinnedStandardRate,
        );
        // monthlyReserve는 이미 "원천징수 대비 부족분"만 남은 개월수로 나눈 값이라
        // annualTotalTax(근로+사업 합산 전체 세액)를 그대로 12분할하지 않는다.
        minMonthlyTaxReserve = result.monthlyReserve;
        maxMonthlyTaxReserve = minMonthlyTaxReserve;
        incomeAmountForInsurance = result.estimatedFreelancerBusinessIncome + result.otherIncomeAmount;
      } else {
        final range = CombinedTaxCalculator.calculateTaxRange(
          grossIncome: annualGrossLabor,
          accumulatedFreelancerIncome: ytdBusinessIncome,
          inputMonths: now.month,
          occupationCode: occupationCode,
          creditCard: 0,
          debitCardAndCash: 0,
          traditionalMarket: 0,
          publicTransport: 0,
          cultureExpense: 0,
          allowanceCount: allowanceCount,
          decidedTax: estimatedLaborDecidedTax,
          monthlyRent: 0,
          otherIncome: annualOtherIncome,
        );
        // monthlyReserve는 이미 "원천징수 대비 부족분"만 남은 개월수로 나눈 값이라
        // annualTotalTax(근로+사업 합산 전체 세액)를 그대로 12분할하지 않는다.
        minMonthlyTaxReserve = range.min.monthlyReserve;
        maxMonthlyTaxReserve = range.max.monthlyReserve;
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
    );
  }
}
