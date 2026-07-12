import '../data/db_helper.dart';
import '../data/occupation_data.dart';
import 'combined_tax.dart';
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
    double minAnnualTax;
    double maxAnnualTax;

    if (userType == '프리랜서') {
      final range = FreelancerTaxCalculator.calculateTaxRange(
        accumulatedIncome: ytdBusinessIncome + ytdOtherIncome,
        inputMonths: now.month,
        allowanceCount: allowanceCount,
        occupationCode: occupationCode,
      );
      minAnnualTax = range.min.annualTotalTax;
      maxAnnualTax = range.max.annualTotalTax;
    } else {
      // N잡러 — 근로소득은 프로필의 예상 연봉을 우선 쓰고, 없으면 지금까지 기록을 연환산한다.
      final annualGrossLabor = profileGrossIncome > 0
          ? profileGrossIncome
          : (ytdLaborIncome / now.month) * 12;
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
        decidedTax: 0,
        monthlyRent: 0,
        otherIncome: annualOtherIncome,
      );
      minAnnualTax = range.min.annualTotalTax;
      maxAnnualTax = range.max.annualTotalTax;
    }

    // 연간 예상세액을 12로 균등 분배 — "이번 달분"을 직관적으로 보여주기 위함.
    final minMonthlyTaxReserve = minAnnualTax / 12;
    final maxMonthlyTaxReserve = maxAnnualTax / 12;

    double insuranceReserve = 0;
    if (userType == 'N잡러') {
      // N잡러는 이미 직장가입자 — 국민연금·건강보험을 지역가입자처럼 스스로 내지 않는다.
      // 부업(사업+기타)소득이 연 2,000만원을 넘는 분에 대해서만 건보 소득월액보험료가 추가 부과된다.
      final annualBusinessIncome = ((ytdBusinessIncome + ytdOtherIncome) / now.month) * 12;
      final extra = InsuranceEngine.calculateNJobExtraInsurance(annualBusinessIncome);
      insuranceReserve += extra.totalMonthlyExtraPremium;
      if (employmentEnrolled || industrialEnrolled) {
        final ins = InsuranceEngine.calculateFreelancerInsurance(
          annualIncome: annualBusinessIncome,
          propertyValue: propertyValue,
          occupationCode: hasOccupation ? occupationCode : null,
        );
        if (employmentEnrolled) insuranceReserve += ins.employmentInsurance;
        if (industrialEnrolled) insuranceReserve += ins.industrialAccident;
      }
    } else if (pensionEnrolled || healthEnrolled || employmentEnrolled || industrialEnrolled) {
      final annualBusinessIncome = ((ytdBusinessIncome + ytdOtherIncome) / now.month) * 12;
      final ins = InsuranceEngine.calculateFreelancerInsurance(
        annualIncome: annualBusinessIncome,
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
