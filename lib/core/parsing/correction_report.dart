import '../tax_engine/employee_tax.dart';
import '../tax_engine/tax_year_rules.dart';
import 'simplified_data_parser.dart';
import 'withholding_parser.dart';

/// 빠진 공제 1건 → 추가 세액공제(환급).
class CorrectionLine {
  final String category;
  final int available; // 간소화 가능액
  final int claimed; // 원천 신고 공제대상
  final int missedCredit; // 미신고분 세액공제(추가 환급)
  const CorrectionLine({
    required this.category,
    required this.available,
    required this.claimed,
    required this.missedCredit,
  });
}

/// 경정청구(추가환급) 신고서 산출 결과.
class CorrectionReport {
  final List<CorrectionLine> lines; // missedCredit > 0 만
  final int additionalRefund; // Σ missedCredit, 단 결정세액 한도 cap
  final int decidedTax;

  /// 계산에 쓴 귀속연도. 0이면 영수증에서 읽지 못했다는 뜻.
  final int accrualYear;

  /// 계산을 못 한 이유(사용자에게 그대로 보여줄 문구). null이면 정상 계산.
  final String? blockedReason;

  const CorrectionReport({
    required this.lines,
    required this.additionalRefund,
    required this.decidedTax,
    this.accrualYear = 0,
    this.blockedReason,
  });

  bool get hasMissed => additionalRefund > 0;
  bool get isBlocked => blockedReason != null;
}

int _min(int a, int b) => a < b ? a : b;

/// 간소화(가능) × 원천(신고)을 엔진 세액공제 함수에 연결해, 미신고분의
/// 추가 세액공제(=경정청구 추가환급)를 계산한다.
///
/// 공제율·한도는 **영수증의 귀속연도** 규정을 쓴다([rulesForYear]). 당해연도
/// 상수로 과거를 계산하면 틀린 금액이 나오고, 경정청구는 그 금액을 그대로
/// 세무서에 내는 기능이라 틀린 값보다 빈 결과가 낫다.
///
/// v1 근사: 간소화 합계가 lumped(세부버킷 없음)라 일반 버킷에 투입.
/// 정밀 버킷 파싱은 후속.
CorrectionReport buildCorrectionReport(GansoDeductions g, WithholdingReceipt w,
    {bool isHomeless = true, DateTime? now}) {
  CorrectionReport blocked(String reason) => CorrectionReport(
        lines: const [],
        additionalRefund: 0,
        decidedTax: w.decidedTax,
        accrualYear: w.accrualYear,
        blockedReason: reason,
      );

  final year = w.accrualYear;
  if (year <= 0) {
    return blocked('원천징수영수증에서 귀속연도를 읽지 못했습니다. '
        '연도마다 공제율이 달라 계산할 수 없어요.');
  }

  final rules = rulesForYear(year);
  if (rules == null) {
    return blocked('$year년 귀속은 아직 지원하지 않습니다. '
        '$kOldestCorrectionYear~$kNewestCorrectionYear년 귀속만 계산할 수 있어요.');
  }

  final today = now ?? DateTime.now();
  if (!isCorrectionOpen(year, today)) {
    final d = correctionDeadline(year);
    return blocked('$year년 귀속 경정청구는 ${d.year}.${d.month}.${d.day}.에 '
        '기한이 지났습니다.');
  }

  final salary = w.grossSalary.toDouble();
  // 총급여를 못 읽으면(파싱 실패·미입력) 의료비 3% 문턱이 0이 되어 공제가 과대 계산되고,
  // 연금저축·월세 공제율 구간도 판정할 수 없다. 근거 없는 금액을 내느니 빈 결과를 준다.
  if (salary <= 0) {
    return blocked('원천징수영수증에서 총급여를 읽지 못했습니다.');
  }

  // 연금계좌 15%/12% 경계(총급여 5,500만)와 월세 17%/15% 경계는 2021~2026 동안 불변.
  final pensionRate = salary <= 55000000.0 ? 0.15 : 0.12;
  final rentRate = salary <= 55000000.0 ? rules.rentRateLow : rules.rentRateHigh;
  // 2022 귀속 이하는 총급여 1.2억 초과 시 연금저축 한도가 더 낮았다.
  final pensionSavingsLimit = salary > 120000000.0
      ? rules.pensionSavingsLimitHighIncome
      : rules.pensionSavingsLimit;

  final lines = <CorrectionLine>[];

  void consider(String cat, int available, int claimed, int fullCredit, int claimedCredit) {
    final missed = fullCredit - claimedCredit;
    if (missed > 0) {
      lines.add(CorrectionLine(
        category: cat,
        available: available,
        claimed: claimed,
        missedCredit: missed,
      ));
    }
  }

  // 의료비 (총급여 3% 문턱은 엔진이 적용)
  // 난임시술비를 분리하고 나머지는 일반(15%) 버킷에 — 정밀도 개선.
  // 난임 공제율은 2021 귀속 20%, 2022 귀속부터 30%.
  final infert = g.medicalInfertility;
  final generalMedical = (g.medicalNet - infert) > 0 ? (g.medicalNet - infert) : 0;
  consider(
    '의료비',
    g.medicalNet,
    w.claimedMedical,
    EmployeeTaxCalculator.calculateMedicalTaxCredit(
      grossIncome: salary,
      infertilityExpense: infert.toDouble(),
      selfAndSeniorAndDisabledExpense: 0,
      otherDependentExpense: generalMedical.toDouble(),
      infertilityRate: rules.infertilityRate,
    ).round(),
    (w.claimedMedical * 0.15).round(),
  );

  // 교육비 (15%) — 2021~2026 공제율·한도 불변. 세부 인원/구분 미상이라
  // 본인 교육비 버킷(무제한)에 근사.
  consider(
    '교육비',
    g.education,
    w.claimedEducation,
    EmployeeTaxCalculator.calculateEducationTaxCredit(
      preschoolExpense: 0, preschoolCount: 0,
      childrenExpense: 0, childrenCount: 0,
      collegeExpense: 0, collegeCount: 0,
      selfExpense: g.education.toDouble(),
      disabledSpecialExpense: 0,
    ).round(),
    (w.claimedEducation * 0.15).round(),
  );

  // 기부금 — 2021·2022 귀속은 한시 상향(20/35%), 2024 귀속은 3천만 초과 40%.
  consider(
    '기부금',
    g.donation,
    w.claimedDonation,
    EmployeeTaxCalculator.calculateDonationTaxCredit(
      generalDonation: g.donation.toDouble(),
      politicalDonation: 0,
      rateLow: rules.donationRateLow,
      rateHigh: rules.donationRateHigh,
      rateTop: rules.donationRateTop,
    ).round(),
    (w.claimedDonation * rules.donationRateLow).round(),
  );

  // 보장성보험 (한도 100만, 12%) — 2021~2026 불변.
  consider(
    '보장성보험',
    g.lifeInsurance,
    w.claimedLifeInsurance,
    EmployeeTaxCalculator.calculateInsurancePremiumTaxCredit(
      generalInsurancePremium: g.lifeInsurance.toDouble(),
      disabledInsurancePremium: 0,
    ).round(),
    (_min(w.claimedLifeInsurance, 1000000) * 0.12).round(),
  );

  // 연금저축 — 2022 귀속 이하는 한도 400만(합산 700만), 2023 귀속부터 600만(900만).
  consider(
    '연금저축',
    g.pensionSavings,
    w.claimedPensionSavings,
    EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
      pensionSavingsPayment: g.pensionSavings.toDouble(),
      retirementPensionPayment: 0,
      grossIncome: salary,
      savingsLimit: pensionSavingsLimit,
      accountLimit: rules.pensionAccountLimit,
    ).round(),
    (_min(w.claimedPensionSavings, pensionSavingsLimit.round()) * pensionRate).round(),
  );

  // 월세액 (조특법 §95의2) — 공제율·한도·소득요건이 연도마다 다르다.
  // 2021 귀속 10/12%·750만·총급여 7천만 → 2022 귀속 15/17% → 2024 귀속 1,000만·8천만.
  // 무주택·세대주는 자가신고 영역이라 월세 기록자는 충족으로 보되(기본 true),
  // 계산 가능한 소득 요건은 게이트해 고소득자 과대 환급을 막는다.
  final laborIncomeAmount = salary - EmployeeTaxCalculator.calculateLaborDeduction(salary);
  if (EmployeeTaxCalculator.isRentCreditEligible(
    grossIncome: salary,
    globalIncomeAmount: laborIncomeAmount,
    isHomeless: isHomeless,
    grossIncomeLimit: rules.rentGrossIncomeLimit,
    globalIncomeLimit: rules.rentGlobalIncomeLimit,
  )) {
    final rentCap = rules.rentLimit.round();
    consider(
      '월세액',
      g.rent,
      w.claimedRent,
      (_min(g.rent, rentCap) * rentRate).round(),
      (_min(w.claimedRent, rentCap) * rentRate).round(),
    );
  }

  final sum = lines.fold<int>(0, (s, l) => s + l.missedCredit);
  // 추가 환급은 결정세액을 넘을 수 없음(이미 낸 세금 한도).
  final refund = w.decidedTax > 0 ? _min(sum, w.decidedTax) : 0;

  return CorrectionReport(
    lines: lines,
    additionalRefund: refund,
    decidedTax: w.decidedTax,
    accrualYear: year,
  );
}
