import '../tax_engine/employee_tax.dart';
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
  const CorrectionReport({
    required this.lines,
    required this.additionalRefund,
    required this.decidedTax,
  });

  bool get hasMissed => additionalRefund > 0;
}

int _min(int a, int b) => a < b ? a : b;

/// 간소화(가능) × 원천(신고)을 엔진 세액공제 함수에 연결해, 미신고분의
/// 추가 세액공제(=경정청구 추가환급)를 계산한다.
///
/// v1 근사: 간소화 합계가 lumped(세부버킷 없음)라 일반 버킷에 투입.
/// 정밀 버킷 파싱은 후속.
CorrectionReport buildCorrectionReport(GansoDeductions g, WithholdingReceipt w,
    {bool isHomeless = true}) {
  final salary = w.grossSalary.toDouble();
  // 총급여를 못 읽으면(파싱 실패·미입력) 의료비 3% 문턱이 0이 되어 공제가 과대 계산되고,
  // 연금저축·월세 공제율 구간도 판정할 수 없다. 근거 없는 금액을 내느니 빈 결과를 준다.
  if (salary <= 0) {
    return CorrectionReport(lines: const [], additionalRefund: 0, decidedTax: w.decidedTax);
  }
  final pensionRate = salary <= 55000000.0 ? 0.15 : 0.12;
  final rentRate = salary <= 55000000.0 ? 0.17 : 0.15;

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
  // 난임시술비(30%)를 분리하고 나머지는 일반(15%) 버킷에 — 정밀도 개선.
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
    ).round(),
    (w.claimedMedical * 0.15).round(),
  );

  // 교육비 (15%) — 세부 인원/구분 미상이라 본인 교육비 버킷(무제한)에 근사
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

  // 기부금 (일반 15%/30%)
  consider(
    '기부금',
    g.donation,
    w.claimedDonation,
    EmployeeTaxCalculator.calculateDonationTaxCredit(
      generalDonation: g.donation.toDouble(),
      politicalDonation: 0,
    ).round(),
    (w.claimedDonation * 0.15).round(),
  );

  // 보장성보험 (한도 100만, 12%)
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

  // 연금저축 (한도 600만)
  consider(
    '연금저축',
    g.pensionSavings,
    w.claimedPensionSavings,
    EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
      pensionSavingsPayment: g.pensionSavings.toDouble(),
      retirementPensionPayment: 0,
      grossIncome: salary,
    ).round(),
    (_min(w.claimedPensionSavings, 6000000) * pensionRate).round(),
  );

  // 월세액 (조특법 §95의2, 연 1천만 한도, 15~17%): 총급여 8천·종합소득금액 7천 이하
  // 무주택 세대주만 대상. 무주택·세대주는 자가신고 영역이라 월세 기록자는 충족으로
  // 보되(기본 true), 계산 가능한 소득 요건은 게이트해 고소득자 과대 환급을 막는다.
  final laborIncomeAmount = salary - EmployeeTaxCalculator.calculateLaborDeduction(salary);
  if (EmployeeTaxCalculator.isRentCreditEligible(
    grossIncome: salary,
    globalIncomeAmount: laborIncomeAmount,
    isHomeless: isHomeless,
  )) {
    consider(
      '월세액',
      g.rent,
      w.claimedRent,
      (_min(g.rent, 10000000) * rentRate).round(),
      (_min(w.claimedRent, 10000000) * rentRate).round(),
    );
  }

  final sum = lines.fold<int>(0, (s, l) => s + l.missedCredit);
  // 추가 환급은 결정세액을 넘을 수 없음(이미 낸 세금 한도).
  final refund = w.decidedTax > 0 ? _min(sum, w.decidedTax) : 0;

  return CorrectionReport(lines: lines, additionalRefund: refund, decidedTax: w.decidedTax);
}
