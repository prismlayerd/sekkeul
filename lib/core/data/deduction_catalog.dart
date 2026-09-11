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

  /// **간소화가 놓치는가.** 참이면 04 「공제」 화면에 뜬다.
  ///
  /// 간소화에 자동으로 뜨는 금액을 앱에 옮겨 적게 하는 건 순수 손해다 —
  /// 사용자는 홈택스에서 클릭 한 번이면 되는 걸 두 번 한다. 앱의 값어치는
  /// **홈택스가 안 알려주는 것**에 있다.
  final bool missable;

  /// 세무서에 낼 때 **같이 내야 하는 서류.**
  ///
  /// 홈택스 경정청구는 첨부 파일로, 우편·방문은 종이로 낸다. 어느 쪽이든
  /// 서류가 빠지면 보정 요구가 오고 환급이 몇 달 늦는다 — 고른 항목마다
  /// 무엇이 필요한지 그 자리에서 말해 주는 게 이 필드의 일이다.
  final List<String> documents;

  /// 금액을 넣어도 **단독으로는 환급액을 확정할 수 없을 때** 붙는 조건.
  ///
  /// 의료비만 그렇다 — 총급여 3%를 넘은 만큼만 공제되는데(소법 §59의4②1),
  /// 간소화 자동분을 앱이 안 받으므로 넘겼는지 모른다. 그래도 금액은 받는다:
  /// 「돌려받을지는 몰라도 일단 적어 두고 신고서를 완성한다」가 사용자의 일이고,
  /// 앱이 대신 결정할 일이 아니다.
  final String? conditional;

  const DeductionCategory({
    required this.id,
    required this.name,
    required this.summary,
    required this.findHint,
    required this.fileHint,
    this.missable = false,
    this.conditional,
    this.documents = const [],
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
    documents: [
      '의료비 지급명세서 (병원·약국 발급)',
      '실손보험금 수령내역 (받았다면)',
    ],
  ),
  DeductionCategory(
    id: 'education',
    name: '교육비',
    summary: '본인·자녀 교육비를 15% 공제받아요.',
    findHint: '홈택스 → 연말정산 간소화 → 교육비 (납입액 합계).',
    fileHint: '세액공제 → 교육비 칸에 대상자별 납입액을 적어요.',
    documents: [
      '교육비 납입증명서 (학교·학원 발급)',
    ],
  ),
  DeductionCategory(
    id: 'donation',
    name: '기부금',
    summary: '기부금을 15% (1천만 초과분 30%) 공제받아요.',
    findHint: '홈택스 → 연말정산 간소화 → 기부금, 또는 기부금영수증 합계.',
    fileHint: '세액공제 → 기부금 칸에 기부처별 금액을 적어요.',
    documents: [
      '기부금영수증 (기부처 발급)',
      '기부금 명세서',
    ],
  ),
  DeductionCategory(
    id: 'lifeInsurance',
    name: '보장성보험',
    summary: '보장성보험료를 연 100만원 한도로 12% 공제받아요.',
    findHint: '홈택스 → 연말정산 간소화 → 보장성보험료.',
    fileHint: '세액공제 → 보험료 칸에 납입액(최대 100만원)을 적어요.',
    documents: [
      '보험료 납입증명서 (보험사 발급)',
    ],
  ),
  DeductionCategory(
    id: 'pensionSavings',
    name: '연금저축',
    summary: '연금저축 납입액을 600만원 한도로 12~15% 공제받아요.',
    findHint: '홈택스 → 연말정산 간소화 → 연금저축, 또는 금융사 납입증명.',
    fileHint: '세액공제 → 연금계좌 칸에 납입액을 적어요.',
    documents: [
      '연금저축 납입증명서 (금융사 발급)',
    ],
  ),
  DeductionCategory(
    id: 'rent',
    name: '월세액',
    summary: '무주택 세대주는 월세를 연 1천만 한도로 15~17% 공제받아요.',
    findHint: '임대차계약서·계좌이체 내역. 총급여 8천만원 이하·무주택 세대주만.',
    fileHint: '세액공제 → 월세액 칸에 1년치 월세 합계를 적어요.',
    missable: true,
    documents: [
      '임대차계약서 사본 (집주인 서명본)',
      '월세 이체확인서 또는 계좌 거래내역',
      '주민등록등본 (해당 주소지)',
    ],
  ),
  DeductionCategory(
    id: 'housingSubscription',
    name: '주택청약저축',
    summary: '납입액을 연 300만원 한도로 40% 소득공제받아요 (최대 120만원).',
    findHint: '가입 은행의 납입증명서. 은행에 무주택확인서를 먼저 내야 해요.',
    fileHint: '소득공제 → 주택마련저축 칸에 1년치 납입액을 적어요.',
    missable: true,
    documents: [
      '주택마련저축 납입증명서 (가입 은행)',
      '무주택확인서 제출 사실 확인',
    ],
  ),
  DeductionCategory(
    id: 'leaseLoan',
    name: '전세대출 원리금',
    summary: '원리금 상환액의 40%를 청약저축과 합쳐 연 400만원까지 공제받아요.',
    findHint: '은행 원리금상환증명서. 은행이 집주인 계좌로 바로 넣어 준 대출만 돼요.',
    fileHint: '소득공제 → 주택임차차입금 원리금상환액 칸에 적어요.',
    missable: true,
    documents: [
      '원리금상환증명서 (대출 은행)',
      '임대차계약서 사본',
      '주민등록등본',
    ],
  ),
  DeductionCategory(
    id: 'glasses',
    name: '안경·콘택트렌즈',
    summary: '가족 1명당 연 50만원까지 의료비로 인정돼요.',
    findHint: '간소화에 안 나와요. 안경점 영수증(구입자 이름·시력교정용 표기)이 필요해요.',
    fileHint: '세액공제 → 의료비 칸에 더해서 적어요.',
    missable: true,
    conditional: '의료비는 총급여의 3%를 넘은 만큼만 공제돼요',
    documents: [
      '안경점 영수증 (구입자 이름·시력교정용 표기 필수)',
    ],
  ),
  DeductionCategory(
    id: 'postpartum',
    name: '산후조리원',
    summary: '출산 1회당 200만원까지 의료비로 인정돼요.',
    findHint: '간소화에 안 나오는 경우가 많아요. 조리원 영수증을 챙기세요.',
    fileHint: '세액공제 → 의료비 칸에 더해서 적어요.',
    missable: true,
    conditional: '의료비는 총급여의 3%를 넘은 만큼만 공제돼요',
    documents: [
      '산후조리원 이용 영수증',
      '출산 사실 확인 서류 (가족관계증명서 등)',
    ],
  ),
  DeductionCategory(
    id: 'uniform',
    name: '교복·체육복',
    summary: '중·고등학생 1명당 연 50만원까지 15% 공제받아요.',
    findHint: '간소화에 안 나와요. 교복 구입 영수증이 필요해요.',
    fileHint: '세액공제 → 교육비 칸에 더해서 적어요.',
    missable: true,
    documents: [
      '교복 구입 영수증 (학교명·학생명 표기)',
    ],
  ),
  DeductionCategory(
    id: 'preschoolAcademy',
    name: '취학전 학원비·체육시설',
    summary: '초등학교 들어가기 전 아이의 학원비도 교육비로 15% 공제돼요.',
    findHint: '간소화에 안 나와요. 학원에서 교육비납입증명서를 받으세요.',
    fileHint: '세액공제 → 교육비 칸에 더해서 적어요.',
    missable: true,
    documents: [
      '교육비 납입증명서 (학원·체육시설 발급)',
    ],
  ),
  // 소법 §59의4③1마 (2025-12-23 개정, 2026-01-01 시행) — 취학전 아동뿐 아니라
  // 초1~2학년(9세 미만)의 예체능 학원·체육시설비도 교육비 공제에 새로 들어왔다.
  DeductionCategory(
    id: 'earlyElemArtsAcademy',
    name: '초1~2학년 예체능 학원비',
    summary: '9세 미만이거나 초등 1~2학년인 아이의 예체능 학원비·체육시설비도 교육비로 15% 공제돼요.',
    findHint: '간소화에 안 나와요. 학원에서 교육비납입증명서를 받으세요.',
    fileHint: '세액공제 → 교육비 칸에 더해서 적어요.',
    missable: true,
    documents: [
      '교육비 납입증명서 (학원·체육시설 발급)',
    ],
  ),
  DeductionCategory(
    id: 'religiousDonation',
    name: '종교단체 기부금',
    summary: '헌금·시주도 15% 공제받아요 (소득금액의 10% 한도).',
    findHint: '간소화에서 자주 빠져요. 교회·성당·사찰에서 기부금영수증을 받으세요.',
    fileHint: '세액공제 → 기부금 칸에 종교단체분으로 적어요.',
    missable: true,
    documents: [
      '기부금영수증 (종교단체 고유번호증 사본 포함)',
    ],
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

/// 04 「공제」 안의 두 갈래.
///
/// - **자동으로 안 불러와지는 것** (월세·청약·전세대출): 제도상 간소화에 실리지
///   않아 증명서를 직접 떼야 한다. 금액이 커서 놓치면 손해가 크고, 해당하는
///   사람이면 거의 다 해당한다.
/// - **놓치기 쉬운 것** (안경·산후조리원·교복·학원비·종교기부금): 영수증을 직접
///   챙겨야 하는 자잘한 것들. **해당하는 사람이 적어 홈 밖으로 꺼내지 않는다** —
///   안 하는 사람이 대부분인 항목을 첫 화면에 늘어놓으면 그게 소음이다.
const Set<String> kNotAutoLoaded = {'rent', 'housingSubscription', 'leaseLoan'};

/// [missableFor] 결과를 위 두 갈래로 가른다.
({List<DeductionCategory> notAuto, List<DeductionCategory> easyToMiss}) splitMissable(
        List<DeductionCategory> items) =>
    (
      notAuto: [for (final c in items) if (kNotAutoLoaded.contains(c.id)) c],
      easyToMiss: [for (final c in items) if (!kNotAutoLoaded.contains(c.id)) c],
    );

/// 04 「공제」 화면에 그릴 목록 — 간소화가 놓치는 것만, 그중에서도
/// 이 사람에게 걸리는 것만.
///
/// 경정청구는 이 목록을 안 쓴다. 거기는 **모든 항목이 빈 채로** 있어야 한다 —
/// 「아 이것도 공제받을 수 있었어?」를 깨달았을 때 여는 화면이라, 목록이 좁으면
/// 깨달을 기회 자체가 없다. 그리고 앱은 5년 전 지출을 알 리가 없다.
List<DeductionCategory> missableFor({
  String? residence,
  bool isHouseholdHead = false,
  double grossIncome = 0,
  int childrenCount = 0,
}) =>
    [
      for (final c in deductionsFor(
          residence: residence,
          isHouseholdHead: isHouseholdHead,
          grossIncome: grossIncome))
        if (c.missable)
          // 자녀가 없으면 교복·취학전·초1~2 학원비를 물어볼 이유가 없다.
          if (childrenCount > 0 ||
              (c.id != 'uniform' &&
                  c.id != 'preschoolAcademy' &&
                  c.id != 'earlyElemArtsAcademy'))
            c,
    ];

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
  int childrenCount = 0,
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
    // 새 항목은 **기존 버킷에 더한다.** 안경·산후조리원은 의료비고, 교복·취학전
    // 학원비는 교육비고, 종교단체 기부금은 기부금이다 — 세법이 따로 두는 공제가
    // 아니라 그 공제 안에서 사람들이 빠뜨리는 조각이다.
    //
    // 한도는 조각마다 따로 있다: 안경 1인 50만(시행령 §118의5①4), 산후조리원
    // 출산 1회 200만(§118의5①7), 교복 1인 50만(§118의6①4호).
    medicalCredit: EmployeeTaxCalculator.calculateMedicalTaxCredit(
      grossIncome: grossIncome,
      infertilityExpense: 0,
      selfAndSeniorAndDisabledExpense: 0,
      otherDependentExpense: a('medical') +
          _cap(a('glasses'), 500000) +
          _cap(a('postpartum'), 2000000),
    ),
    educationCredit: EmployeeTaxCalculator.calculateEducationTaxCredit(
      preschoolExpense: a('preschoolAcademy'),
      preschoolCount: childrenCount < 1 ? 1 : childrenCount,
      // 교복은 시행령 한도(1인 50만)를 먼저 적용한다. 초1~2 예체능 학원비는
      // 시행령 §118의6⑧⑨⑩이 대상만 정하고 별도 금액 한도를 안 두므로 그대로
      // 더한다 — 아래 childLimit(1인 300만)이 유일한 한도다(확인됨, 2026-09-11).
      childrenExpense: _cap(a('uniform'), 500000.0 * (childrenCount < 1 ? 1 : childrenCount)) +
          a('earlyElemArtsAcademy'),
      childrenCount: childrenCount < 1 ? 1 : childrenCount,
      collegeExpense: 0, collegeCount: 0,
      selfExpense: a('education'),
      disabledSpecialExpense: 0,
    ),
    donationCredit: EmployeeTaxCalculator.calculateDonationTaxCredit(
      generalDonation: a('donation') + a('religiousDonation'),
      politicalDonation: 0),
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


double _cap(double v, double limit) => v > limit ? limit : v;
