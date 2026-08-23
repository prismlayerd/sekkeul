import '../parsing/simplified_data_parser.dart';
import '../parsing/withholding_parser.dart';
import '../tax_engine/employee_tax.dart';

/// 공제 항목 1종의 표시·매핑 메타데이터.
/// 계산(한도·세율)은 엔진이 처리하므로 여기선 표시·홈택스 안내·필드 매핑만 담는다.
/// [id] 는 `GansoDeductions`/`getAnnualRecord`의 필드명과 일치시켜 변환을 단순화한다.
class DeductionCategory {
  final String id;        // 'medical' | 'education' | ...
  final String name;      // 의료비
  final String summary;   // 한 줄 설명
  final String findHint;  // 어디서 찾나 (간소화 자료)
  final String fileHint;  // 홈택스 어디에 입력하나

  const DeductionCategory({
    required this.id,
    required this.name,
    required this.summary,
    required this.findHint,
    required this.fileHint,
  });
}

/// 연말정산에서 빠뜨리기 쉬운 세액공제 6종 (직장인·N잡러 공통).
const List<DeductionCategory> kDeductionCatalog = [
  DeductionCategory(
    id: 'medical',
    name: '의료비',
    summary: '총급여 3% 초과분을 15% 돌려받아요 (난임시술 30%).',
    findHint: '홈택스 → 연말정산 간소화 → 의료비. 실손보험으로 받은 금액은 빼요.',
    fileHint: '세액공제 → 의료비 칸에 본인부담 의료비 합계를 적어요.',
  ),
  DeductionCategory(
    id: 'education',
    name: '교육비',
    summary: '본인·자녀 교육비를 15% 공제받아요.',
    findHint: '홈택스 → 연말정산 간소화 → 교육비 (납입액 합계).',
    fileHint: '세액공제 → 교육비 칸에 대상자별 납입액을 적어요.',
  ),
  DeductionCategory(
    id: 'donation',
    name: '기부금',
    summary: '기부금을 15% (1천만 초과분 30%) 공제받아요.',
    findHint: '홈택스 → 연말정산 간소화 → 기부금, 또는 기부금영수증 합계.',
    fileHint: '세액공제 → 기부금 칸에 기부처별 금액을 적어요.',
  ),
  DeductionCategory(
    id: 'lifeInsurance',
    name: '보장성보험',
    summary: '보장성보험료를 연 100만원 한도로 12% 공제받아요.',
    findHint: '홈택스 → 연말정산 간소화 → 보장성보험료.',
    fileHint: '세액공제 → 보험료 칸에 납입액(최대 100만원)을 적어요.',
  ),
  DeductionCategory(
    id: 'pensionSavings',
    name: '연금저축',
    summary: '연금저축 납입액을 600만원 한도로 12~15% 공제받아요.',
    findHint: '홈택스 → 연말정산 간소화 → 연금저축, 또는 금융사 납입증명.',
    fileHint: '세액공제 → 연금계좌 칸에 납입액을 적어요.',
  ),
  DeductionCategory(
    id: 'rent',
    name: '월세액',
    summary: '무주택 세대주는 월세를 연 1천만 한도로 15~17% 공제받아요.',
    findHint: '임대차계약서·계좌이체 내역. 총급여 8천만원 이하·무주택 세대주만.',
    fileHint: '세액공제 → 월세액 칸에 1년치 월세 합계를 적어요.',
  ),
  DeductionCategory(
    id: 'housingSubscription',
    name: '주택청약저축',
    summary: '납입액을 연 300만원 한도로 40% 소득공제받아요 (최대 120만원).',
    findHint: '가입 은행의 납입증명서. 은행에 무주택확인서를 먼저 내야 해요.',
    fileHint: '소득공제 → 주택마련저축 칸에 1년치 납입액을 적어요.',
  ),
  DeductionCategory(
    id: 'leaseLoan',
    name: '전세대출 원리금',
    summary: '원리금 상환액의 40%를 청약저축과 합쳐 연 400만원까지 공제받아요.',
    findHint: '은행 원리금상환증명서. 은행이 집주인 계좌로 바로 넣어 준 대출만 돼요.',
    fileHint: '소득공제 → 주택임차차입금 원리금상환액 칸에 적어요.',
  ),
];

/// 이 사람에게 **실제로 걸리는** 항목만 남긴다.
///
/// 열다섯 줄을 늘어놓으면 사용자는 자기와 상관없는 줄에서 판단을 낭비한다.
/// 앱은 거주 형태·세대주·총급여를 이미 알고 있으니 앱이 걸러야 한다 —
/// 자가인 사람에게 월세 세액공제를 권하는 사고를 막는 것이 먼저다.
///
/// [residence] 는 `residenceOf(profile)` 결과(`전세|월세|반전세|자가`).
List<DeductionCategory> deductionsFor({
  String? residence,
  bool isHouseholdHead = false,
  double grossIncome = 0,
}) {
  bool keep(String id) {
    switch (id) {
      // 조특법 §95의2 — 무주택 세대주가 실제로 월세를 내야 한다(반전세 포함).
      case 'rent':
        return (residence == '월세' || residence == '반전세') && isHouseholdHead;
      // 조특법 §87② — 무주택 세대주(또는 배우자), 총급여 7천만 이하.
      case 'housingSubscription':
        return residence != '자가' &&
            isHouseholdHead &&
            (grossIncome <= 0 || grossIncome <= 70000000);
      // 소법 §52④ — 보증금이 걸려 있어야 한다. 소득 요건은 없다.
      case 'leaseLoan':
        return (residence == '전세' || residence == '반전세') && isHouseholdHead;
      default:
        return true;
    }
  }

  return [for (final c in kDeductionCatalog) if (keep(c.id)) c];
}

/// 선택 금액(id→금액)으로 `GansoDeductions`(가능액) 구성.
GansoDeductions gansoFromAmounts(Map<String, int> amounts) => GansoDeductions(
      medical: amounts['medical'] ?? 0,
      education: amounts['education'] ?? 0,
      donation: amounts['donation'] ?? 0,
      lifeInsurance: amounts['lifeInsurance'] ?? 0,
      pensionSavings: amounts['pensionSavings'] ?? 0,
      rent: amounts['rent'] ?? 0,
    );

/// 잊은 항목은 '신고액 0' — 총급여·결정세액만 채운 `WithholdingReceipt`.
WithholdingReceipt forgottenReceipt({
  required int accrualYear,
  required int grossSalary,
  required int decidedTax,
}) =>
    WithholdingReceipt(
        accrualYear: accrualYear, grossSalary: grossSalary, decidedTax: decidedTax);

/// `getAnnualRecord` 맵에서 카탈로그 id별 가능액을 뽑아낸다(PDF 보조 프리필).
Map<String, int> amountsFromAnnualRecord(Map<String, dynamic> record) {
  int v(String k) => (record[k] as num?)?.toInt() ?? 0;
  final out = <String, int>{};
  for (final c in kDeductionCatalog) {
    final amt = v(c.id);
    if (amt > 0) out[c.id] = amt;
  }
  return out;
}


/// 골라 넣은 금액(id→금액)으로 **올해 더 돌려받을 금액**을 낸다.
///
/// 경정청구(`buildCorrectionReport`)와 다른 점: 저쪽은 지난 해 귀속연도 규정으로
/// 「이미 신고한 것과의 차액」을 내고, 이쪽은 올해 규정으로 「지금 모아 둔 것의
/// 값어치」를 낸다. 상한(낸 세금)은 양쪽 다 지킨다.
///
/// 항목별 버킷 배분은 경정청구 쪽 관례를 그대로 따른다 — 세부 구분을 안 받으므로
/// 의료비는 일반(부양가족) 버킷, 교육비는 본인(무제한) 버킷에 넣는다.
EmployeeRefundEstimate estimateYearRefund({
  required Map<String, int> amounts,
  required double grossIncome,
  int dependentsIncludingSelf = 1,
  double cardDeduction = 0,
  bool isHouseholdHead = false,
  bool ownsHome = false,
  bool leaseLoanFromInstitution = true,
}) {
  double a(String id) => (amounts[id] ?? 0).toDouble();

  final rentPaid = a('rent');
  double rentCredit = 0;
  if (rentPaid > 0 &&
      EmployeeTaxCalculator.isRentCreditEligible(
          grossIncome: grossIncome,
          // 근로소득만 있다고 본다 — 종합소득금액 7천만 요건은 총급여에서 근로소득
          // 공제를 뺀 값으로 판정한다.
          globalIncomeAmount:
              grossIncome - EmployeeTaxCalculator.calculateLaborDeduction(grossIncome),
          isHomeless: !ownsHome)) {
    // 조특법 §95의2 — 연 1,000만원 한도.
    final base = rentPaid > 10000000 ? 10000000.0 : rentPaid;
    rentCredit = base * EmployeeTaxCalculator.rentCreditRate(grossIncome);
  }

  return EmployeeTaxCalculator.estimateEmployeeRefund(
    grossIncome: grossIncome,
    dependentsIncludingSelf: dependentsIncludingSelf,
    cardDeduction: cardDeduction,
    rentCredit: rentCredit,
    medicalCredit: EmployeeTaxCalculator.calculateMedicalTaxCredit(
      grossIncome: grossIncome,
      infertilityExpense: 0,
      selfAndSeniorAndDisabledExpense: 0,
      otherDependentExpense: a('medical'),
    ),
    educationCredit: EmployeeTaxCalculator.calculateEducationTaxCredit(
      preschoolExpense: 0, preschoolCount: 0,
      childrenExpense: 0, childrenCount: 0,
      collegeExpense: 0, collegeCount: 0,
      selfExpense: a('education'),
      disabledSpecialExpense: 0,
    ),
    donationCredit: EmployeeTaxCalculator.calculateDonationTaxCredit(
      generalDonation: a('donation'), politicalDonation: 0),
    insurancePremiumCredit: EmployeeTaxCalculator.calculateInsurancePremiumTaxCredit(
      generalInsurancePremium: a('lifeInsurance'), disabledInsurancePremium: 0),
    pensionAccountCredit: EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
      pensionSavingsPayment: a('pensionSavings'),
      retirementPensionPayment: 0,
      grossIncome: grossIncome,
    ),
    housingSubscription: a('housingSubscription'),
    leaseLoanRepayment: a('leaseLoan'),
    isHouseholdHead: isHouseholdHead,
    ownsHome: ownsHome,
    leaseLoanFromInstitution: leaseLoanFromInstitution,
  );
}
