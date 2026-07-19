import '../data/occupation_data.dart';

/// 기장의무 유형. 5월 종합소득세 신고 시 갖춰야 할 장부 수준.
enum BookkeepingDuty {
  /// 간편장부대상자 — 수입·비용을 단식(가계부식)으로 기록해 신고 가능. 앱이 지원.
  simplified,

  /// 복식부기의무자 — 재무제표 수준의 복식부기 필요. 앱은 세무사 대행을 권장.
  doubleEntry,
}

/// 기장의무 판정 결과. 규칙 자체는 결정적이므로 [duty]는 단정하되,
/// 불확실성이 입력(겸업·중도개폐업)에 있는 경우만 [needsInputReview]로 표시한다.
class BookkeepingJudgment {
  /// 최종 기장의무.
  final BookkeepingDuty duty;

  /// 전문직 사업자라 직전연도 수입과 무관하게 복식부기의무인 경우.
  final bool isProfessional;

  /// 신규사업자(직전 과세기간 없음) — 전문직이 아니면 첫해는 간편장부대상자.
  final bool isNewBusiness;

  /// 업종그룹과 그룹별 복식부기의무 임계(직전연도 수입금액, 원).
  final BookkeepingGroup group;
  final int threshold;

  /// 판정에 사용한 직전연도 수입금액(원). 신규사업자면 0/무의미.
  final int priorYearIncome;

  /// 겸업(복수 업종) 등 규칙이 복잡해 사용자가 입력 전제를 확인해야 하는 경우.
  /// 판정 결과는 그대로 제시하되 "전제를 확인하세요" 톤을 붙이는 신호.
  final bool needsInputReview;

  /// 판정 근거 한 줄(사용자 노출용).
  final String reason;

  const BookkeepingJudgment({
    required this.duty,
    required this.isProfessional,
    required this.isNewBusiness,
    required this.group,
    required this.threshold,
    required this.priorYearIncome,
    required this.needsInputReview,
    required this.reason,
  });

  bool get isDoubleEntry => duty == BookkeepingDuty.doubleEntry;
  bool get isSimplified => duty == BookkeepingDuty.simplified;
}

/// 업종·직전연도 수입 등으로 기장의무를 판정한다.
///
/// 판정 우선순위(결정적):
/// 1. 전문직 → 수입·신규 무관 **복식부기**.
/// 2. 신규사업자(직전 과세기간 없음) → 첫해는 **간편장부**(전문직 제외).
/// 3. 직전연도 수입 ≥ 그룹 임계 → **복식부기**, 미만 → **간편장부**.
///
/// [hasMultipleBusinesses]가 참이면(겸업) 주업종 환산·합산 규칙이 복잡하므로
/// 결과는 계산하되 [BookkeepingJudgment.needsInputReview]를 세운다.
BookkeepingJudgment judgeBookkeepingDuty({
  required OccupationInfo occupation,
  required int priorYearIncome,
  bool isNewBusiness = false,
  bool hasMultipleBusinesses = false,
}) {
  final group = occupation.bookkeepingGroup;
  final threshold = occupation.complexBookkeepingThreshold;
  final professional = occupation.isProfessional;

  BookkeepingDuty duty;
  String reason;
  if (professional) {
    duty = BookkeepingDuty.doubleEntry;
    reason = '전문직 사업자는 수입금액과 관계없이 복식부기의무자예요.';
  } else if (isNewBusiness) {
    duty = BookkeepingDuty.simplified;
    reason = '올해 처음 사업을 시작했다면 첫 과세기간은 간편장부대상자예요.';
  } else if (priorYearIncome >= threshold) {
    duty = BookkeepingDuty.doubleEntry;
    reason = '직전연도 수입금액이 ${_manwon(threshold)} 이상이라 복식부기의무자예요.';
  } else {
    duty = BookkeepingDuty.simplified;
    reason = '직전연도 수입금액이 ${_manwon(threshold)} 미만이라 간편장부대상자예요.';
  }

  return BookkeepingJudgment(
    duty: duty,
    isProfessional: professional,
    isNewBusiness: isNewBusiness && !professional,
    group: group,
    threshold: threshold,
    priorYearIncome: priorYearIncome,
    // 전문직은 규칙이 단순(무조건 복식)해 겸업이어도 확인 불필요.
    needsInputReview: hasMultipleBusinesses && !professional,
    reason: reason,
  );
}

/// 추계신고 시 단순경비율을 적용할 수 있는지 판정한다.
/// (기장의무 판정과는 별개 규칙 — 임계 테이블이 다르다. 단순경비율 미대상이면
/// 기준경비율이 **강제** 적용되며, 세금이 낮은 쪽을 고를 수 있는 선택 사항이 아니다.)
///
/// 규칙(국세청 "기장의무와 추계신고시 적용할 경비율 판단기준", 확인일 2026-07-19):
/// 1. 전문직 → 수입 무관 단순경비율 배제(어차피 복식부기의무라 이 판정에 오지 않음).
/// 2. 당해연도 수입금액(연환산) ≥ 복식부기의무 임계 → 단순경비율 배제.
/// 3. 신규사업자 → (2 통과 시) 첫해는 단순경비율.
/// 4. 계속사업자 → 직전연도 수입 < 업종별 경비율 임계(가 6,000만/나 3,600만/
///    다 2,400만, 인적용역 940xxx는 3,600만)일 때만 단순경비율.
bool isSimpleExpenseRateEligible({
  required OccupationInfo occupation,
  required int priorYearIncome,
  bool isNewBusiness = false,
  double currentYearIncome = 0,
}) {
  if (occupation.isProfessional) return false;
  if (currentYearIncome >= occupation.complexBookkeepingThreshold) return false;
  if (isNewBusiness) return true;
  return priorYearIncome < occupation.simpleExpenseRateThreshold;
}

/// 원 단위 임계를 "3억 원"·"1억 5천만 원"·"7,500만 원" 식으로 표기.
String _manwon(int won) {
  switch (won) {
    case 300000000:
      return '3억 원';
    case 150000000:
      return '1억 5천만 원';
    case 75000000:
      return '7,500만 원';
    default:
      return '${won ~/ 10000}만 원';
  }
}
