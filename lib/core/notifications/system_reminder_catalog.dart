/// 시스템(앱 기본) 알림 카탈로그 — 토글 전용. 사용자가 만들지 않고 켜고/끄기만 한다.
/// reminders 테이블이 아니라 코드에 정적 정의하고, on/off는 reminder_settings(key)로 저장.
/// 켜짐 판정은 "행이 없으면 ON"(getReminderSettings에 키 없으면 켜진 것).
library;

enum SysCategory { deadline, moment } // 기한 · 맞춤(이벤트)

extension SysCategoryX on SysCategory {
  String get label => this == SysCategory.deadline ? '기한' : '맞춤';
}

/// UI에서 같은 그룹으로 묶어 1행으로 표시하는 그룹별 이름·일정.
const kGroupLabels = {
  'year_end':  '연말정산',
  'global_tax': '종합소득세',
  'eitc':      '근로·자녀장려금',
  'vat':       '부가가치세',
  'midprepay': '종합소득세 중간예납',
  'biz_status_report': '사업장현황신고',
  'car_tax_prepay': '자동차세 연납',
  'car_tax_regular': '자동차세 정기분',
  'energy_voucher': '에너지바우처',
  'ev_subsidy': 'EV 보조금',
  'startup_academy': '청년창업사관학교',
  'kmove': 'K-Move 해외취업',
  'property_tax': '재산세',
  'comprehensive_tax': '종합부동산세',
  'payment_report': '지급명세서',
  'resident_tax': '주민세',
};

const kGroupSchedules = {
  'year_end':   '1월 15일 · 3월 5일 · 11월 1일 · 12월 1일',
  'global_tax': '4월 25일 · 5월 1일 · 5월 25일',
  'eitc':       '매년 3월 1일 · 5월 1일 · 9월 1일',
  'vat':        '1월 20일 · 7월 20일',
  'midprepay':  '매년 11월 25일',
  'biz_status_report': '매년 2월 5일',
  'car_tax_prepay': '1월 16일 · 3월 16일 · 6월 16일 · 9월 16일',
  'car_tax_regular': '6월 16일 · 12월 16일',
  'energy_voucher': '5월 27일 · 12월 15일',
  'ev_subsidy': '매년 2월 1일',
  'startup_academy': '매년 1월 10일',
  'kmove': '매년 2월 1일 · 8월 1일',
  'property_tax': '7월 16일 · 9월 16일',
  'comprehensive_tax': '매년 12월 1일',
  'payment_report': '매년 3월 12일',
  'resident_tax': '매년 8월 16일',
};

/// 큐레이션된 시스템 알림 1건.
class SystemReminder {
  final String key;        // reminder_settings 안정 키
  final int notifId;       // flutter_local_notifications 고정 ID (1001~)
  final SysCategory category;
  final String? group;     // UI 그룹 ID — 같은 값끼리 1행으로 묶어 표시
  final String topCategory; // 알림 설정 화면 상단 섹션 헤더("세금 일정","교통·에너지" 등)
  final String title;      // 알림 제목
  final String body;       // 알림 본문
  final String scheduleLabel; // 표시용 ("매년 1월 15일", "공제 문턱 도달 시")
  final int? month;        // 예약 월 (이벤트형이면 null)
  final int? day;          // 예약 일
  final int hour;          // 예약 시각(시)
  final bool employee;     // 직장인·N잡러 대상
  final bool business;     // 프리랜서·N잡러 대상
  final bool requiresCar;   // 차량 보유자에게만 해당
  final bool requiresHouse; // 주택 보유자에게만 해당
  final bool requiresVatLiable; // 부가세 과세 대상만(인적용역 면세 업종은 제외)
  final bool requiresVatExempt; // 부가세 면세 업종만(인적용역 등 — 사업장현황신고 대상)

  const SystemReminder({
    required this.key,
    required this.notifId,
    required this.category,
    required this.title,
    required this.body,
    required this.scheduleLabel,
    this.group,
    this.topCategory = '세금 일정',
    this.month,
    this.day,
    this.hour = 9,
    this.employee = false,
    this.business = false,
    this.requiresCar = false,
    this.requiresHouse = false,
    this.requiresVatLiable = false,
    this.requiresVatExempt = false,
  });

  bool get isEvent => month == null || day == null;

  bool appliesTo(String userType,
      {bool ownsCar = true, bool ownsHouse = true, bool isVatExempt = false}) {
    final isEmp = userType == '직장인' || userType == 'N잡러';
    final isBiz = userType == '프리랜서' || userType == 'N잡러';
    if (requiresCar && !ownsCar) return false;
    if (requiresHouse && !ownsHouse) return false;
    if (requiresVatLiable && isVatExempt) return false;
    if (requiresVatExempt && !isVatExempt) return false;
    return (employee && isEmp) || (business && isBiz);
  }
}

/// 전체 카탈로그. ReminderScheduler의 고정 ID·문구와 1:1로 맞춘다.
const List<SystemReminder> kSystemReminderCatalog = [
  // ── 기한 (직장인·N잡러) ──
  SystemReminder(
    key: 'sys_year_end',
    notifId: 1001,
    category: SysCategory.deadline,
    group: 'year_end',
    title: '연말정산 시즌이 왔어요',
    body: '홈택스 간소화 자료가 열렸어요. 서류 체크리스트도 미리 확인해보세요. 회사에 알리고 싶지 않은 항목이 있다면 지금 골라두면 5월에 직접 신고할 수 있어요.',
    scheduleLabel: '매년 1월 15일',
    month: 1, day: 15,
    employee: true,
  ),
  SystemReminder(
    key: 'sys_year_end_refund',
    notifId: 1006,
    category: SysCategory.deadline,
    group: 'year_end',
    title: '연말정산 추가 환급, 아직 늦지 않았어요',
    body: '회사가 지급명세서를 제출하는 3/10 전이라면 아직 늦지 않았어요 — 담당자에게 놓친 공제를 정정해 다시 제출해달라고 요청해보세요.',
    scheduleLabel: '매년 3월 5일',
    month: 3, day: 5,
    employee: true,
  ),
  SystemReminder(
    key: 'sys_year_end_preview',
    notifId: 1015,
    category: SysCategory.deadline,
    group: 'year_end',
    title: '연말정산 미리보기가 열렸어요',
    body: '홈택스 연말정산 미리보기로 올해 예상 세액을 확인하세요. 남은 두 달 카드·기부·연금저축 전략을 조정할 수 있어요.',
    scheduleLabel: '매년 11월 1일',
    month: 11, day: 1,
    employee: true,
  ),
  SystemReminder(
    key: 'sys_prep_december',
    notifId: 1010,
    category: SysCategory.deadline,
    group: 'year_end',
    title: '연말정산 막차 — 올해가 가기 전에',
    body: '카드·기부·의료비·연금저축·IRP는 12월 31일까지 쓴(납입한) 만큼만 공제돼요. 막판 점검하세요.',
    scheduleLabel: '매년 12월 1일',
    month: 12, day: 1,
    employee: true,
  ),

  // ── 기한 (공통) ──
  SystemReminder(
    key: 'sys_may_prep',
    notifId: 1012,
    category: SysCategory.deadline,
    group: 'global_tax',
    title: '종합소득세 신고 준비하세요',
    body: '한 달 뒤면 5월 종합소득세 신고예요. 지금 서류 체크리스트를 확인해두세요.',
    scheduleLabel: '매년 4월 25일',
    month: 4, day: 25,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_may_start',
    notifId: 1002,
    category: SysCategory.deadline,
    group: 'global_tax',
    title: '5월 종합소득세 신고 시작',
    body: '오늘부터 종합소득세 신고예요. 환급 대상인지 미리 확인해보세요.',
    scheduleLabel: '매년 5월 1일',
    month: 5, day: 1,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_may_dday',
    notifId: 1003,
    category: SysCategory.deadline,
    group: 'global_tax',
    title: '종합소득세 신고 마감 임박',
    body: '5월 말이 신고 마감이에요. 아직이라면 지금 준비하세요.',
    scheduleLabel: '매년 5월 25일',
    month: 5, day: 25,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_eitc',
    notifId: 1013,
    category: SysCategory.deadline,
    group: 'eitc',
    title: '근로·자녀장려금 신청 기간',
    body: '5월 한 달간 정기신청이에요. 소득이 적은 가구라면 놓치지 말고 신청하세요.',
    scheduleLabel: '매년 5월 1일',
    month: 5, day: 1,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_eitc_half1',
    notifId: 1016,
    category: SysCategory.deadline,
    group: 'eitc',
    title: '근로장려금 하반기 반기신청',
    body: '3/1~3/15 — 지난해 하반기 소득분 반기신청 기간이에요.',
    scheduleLabel: '매년 3월 1일',
    month: 3, day: 1,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_eitc_half2',
    notifId: 1017,
    category: SysCategory.deadline,
    group: 'eitc',
    title: '근로장려금 상반기 반기신청',
    body: '9/1~9/15 — 올해 상반기 소득분 반기신청 기간이에요.',
    scheduleLabel: '매년 9월 1일',
    month: 9, day: 1,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_resident_tax',
    notifId: 1021,
    category: SysCategory.deadline,
    group: 'resident_tax',
    title: '주민세(개인분) 납부 기간이에요',
    body: '8/16~8/31 — 세대주에게 부과되는 균등분 주민세 납부 기간이에요.',
    scheduleLabel: '매년 8월 16일',
    month: 8, day: 16,
    employee: true, business: true,
  ),

  // ── 기한 (교통·에너지) ──
  SystemReminder(
    key: 'sys_car_tax_jan',
    notifId: 1101,
    category: SysCategory.deadline,
    group: 'car_tax_prepay',
    topCategory: '교통·에너지',
    title: '자동차세 연납 신청 시작',
    body: '오늘부터 1월 연납 신청이에요. 최대 약 4.57% 절감돼요.',
    scheduleLabel: '매년 1월 16일',
    month: 1, day: 16,
    employee: true, business: true,
    requiresCar: true,
  ),
  SystemReminder(
    key: 'sys_car_tax_mar',
    notifId: 1102,
    category: SysCategory.deadline,
    group: 'car_tax_prepay',
    topCategory: '교통·에너지',
    title: '자동차세 연납 신청 시작',
    body: '오늘부터 3월 연납 신청이에요. 약 3.76% 절감돼요.',
    scheduleLabel: '매년 3월 16일',
    month: 3, day: 16,
    employee: true, business: true,
    requiresCar: true,
  ),
  SystemReminder(
    key: 'sys_car_tax_jun',
    notifId: 1103,
    category: SysCategory.deadline,
    group: 'car_tax_prepay',
    topCategory: '교통·에너지',
    title: '자동차세 연납 신청 시작',
    body: '오늘부터 6월 연납 신청이에요. 약 2.51% 절감돼요.',
    scheduleLabel: '매년 6월 16일',
    month: 6, day: 16,
    employee: true, business: true,
    requiresCar: true,
  ),
  SystemReminder(
    key: 'sys_car_tax_sep',
    notifId: 1104,
    category: SysCategory.deadline,
    group: 'car_tax_prepay',
    topCategory: '교통·에너지',
    title: '자동차세 연납 신청 시작',
    body: '오늘부터 9월 연납 신청이에요. 약 1.26% 절감돼요.',
    scheduleLabel: '매년 9월 16일',
    month: 9, day: 16,
    employee: true, business: true,
    requiresCar: true,
  ),
  SystemReminder(
    key: 'sys_car_tax_regular_jun',
    notifId: 1108,
    category: SysCategory.deadline,
    group: 'car_tax_regular',
    topCategory: '교통·에너지',
    title: '자동차세 정기분(1기) 납부 기간이에요',
    body: '6/16~6/30 — 연납을 안 했다면 상반기분을 정기 납부하세요.',
    scheduleLabel: '매년 6월 16일',
    month: 6, day: 16,
    employee: true, business: true,
    requiresCar: true,
  ),
  SystemReminder(
    key: 'sys_car_tax_regular_dec',
    notifId: 1109,
    category: SysCategory.deadline,
    group: 'car_tax_regular',
    topCategory: '교통·에너지',
    title: '자동차세 정기분(2기) 납부 기간이에요',
    body: '12/16~12/31 — 올해 하반기분 자동차세를 납부하세요.',
    scheduleLabel: '매년 12월 16일',
    month: 12, day: 16,
    employee: true, business: true,
    requiresCar: true,
  ),
  SystemReminder(
    key: 'sys_energy_voucher_start',
    notifId: 1105,
    category: SysCategory.deadline,
    group: 'energy_voucher',
    topCategory: '교통·에너지',
    title: '에너지바우처 신청이 시작됐어요',
    body: '생계·의료·주거·교육급여 수급자나 차상위계층이라면 지금 신청하세요. 12월 31일까지예요.',
    scheduleLabel: '매년 5월 27일',
    month: 5, day: 27,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_energy_voucher_deadline',
    notifId: 1106,
    category: SysCategory.deadline,
    group: 'energy_voucher',
    topCategory: '교통·에너지',
    title: '에너지바우처 신청 마감이 얼마 남지 않았어요',
    body: '12월 31일까지 신청하지 않으면 올해 지원을 받을 수 없어요.',
    scheduleLabel: '매년 12월 15일',
    month: 12, day: 15,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_ev_subsidy',
    notifId: 1107,
    category: SysCategory.deadline,
    group: 'ev_subsidy',
    topCategory: '교통·에너지',
    title: 'EV 보조금 공고를 확인해보세요',
    body: '지자체별 전기차 보조금 공고가 2~3월에 발표돼요. 예산 소진 전에 서둘러보세요.',
    scheduleLabel: '매년 2월 1일',
    month: 2, day: 1,
    employee: true, business: true,
  ),

  // ── 기한 (일자리·행정) ──
  SystemReminder(
    key: 'sys_startup_academy',
    notifId: 1201,
    category: SysCategory.deadline,
    group: 'startup_academy',
    topCategory: '일자리·행정',
    title: '청년창업사관학교 모집을 확인해보세요',
    body: '만 39세 이하 예비·초기 창업자 대상 모집이 1~3월에 진행돼요.',
    scheduleLabel: '매년 1월 10일',
    month: 1, day: 10,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_kmove_h1',
    notifId: 1202,
    category: SysCategory.deadline,
    group: 'kmove',
    topCategory: '일자리·행정',
    title: 'K-Move 해외취업 모집을 확인해보세요',
    body: '만 34세 이하 미취업 청년 대상 해외취업 연수 모집이 연 2~3회 진행돼요.',
    scheduleLabel: '매년 2월 1일',
    month: 2, day: 1,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_kmove_h2',
    notifId: 1203,
    category: SysCategory.deadline,
    group: 'kmove',
    topCategory: '일자리·행정',
    title: 'K-Move 해외취업 모집을 확인해보세요',
    body: '만 34세 이하 미취업 청년 대상 해외취업 연수 모집이 연 2~3회 진행돼요.',
    scheduleLabel: '매년 8월 1일',
    month: 8, day: 1,
    employee: true, business: true,
  ),

  // ── 기한 (프리랜서·N잡러) ──
  SystemReminder(
    key: 'sys_vat_jan',
    notifId: 1007,
    category: SysCategory.deadline,
    group: 'vat',
    title: '부가가치세 확정신고(2기)',
    body: '1/25까지 — 작년 하반기분 부가세를 신고·납부하세요.',
    scheduleLabel: '매년 1월 20일',
    month: 1, day: 20,
    business: true,
    requiresVatLiable: true,
  ),
  SystemReminder(
    key: 'sys_vat_jul',
    notifId: 1008,
    category: SysCategory.deadline,
    group: 'vat',
    title: '부가가치세 확정신고(1기)',
    body: '7/25까지 — 올해 상반기분 부가세를 신고·납부하세요.',
    scheduleLabel: '매년 7월 20일',
    month: 7, day: 20,
    business: true,
    requiresVatLiable: true,
  ),
  SystemReminder(
    key: 'sys_biz_status_report',
    notifId: 1014,
    category: SysCategory.deadline,
    group: 'biz_status_report',
    title: '사업장현황신고 기간이에요',
    body: '2/10까지 — 면세사업자(인적용역 등)는 부가세 대신 지난해 수입·경비 현황을 신고해요.',
    scheduleLabel: '매년 2월 5일',
    month: 2, day: 5,
    business: true,
    requiresVatExempt: true,
  ),
  SystemReminder(
    key: 'sys_midprepay',
    notifId: 1009,
    category: SysCategory.deadline,
    group: 'midprepay',
    title: '종합소득세 중간예납',
    body: '11/30까지 — 상반기 소득 기준으로 미리 납부해요.',
    scheduleLabel: '매년 11월 25일',
    month: 11, day: 25,
    business: true,
  ),

  // ── 기한 (주택 보유자) ──
  SystemReminder(
    key: 'sys_property_tax_1',
    notifId: 1018,
    category: SysCategory.deadline,
    group: 'property_tax',
    title: '재산세 납부 기간이에요',
    body: '7/16~7/31 — 주택분 재산세(1기분) 납부 기간이에요.',
    scheduleLabel: '매년 7월 16일',
    month: 7, day: 16,
    employee: true, business: true,
    requiresHouse: true,
  ),
  SystemReminder(
    key: 'sys_property_tax_2',
    notifId: 1019,
    category: SysCategory.deadline,
    group: 'property_tax',
    title: '재산세 납부 기간이에요',
    body: '9/16~9/30 — 주택분 재산세(2기분) 납부 기간이에요.',
    scheduleLabel: '매년 9월 16일',
    month: 9, day: 16,
    employee: true, business: true,
    requiresHouse: true,
  ),
  SystemReminder(
    key: 'sys_comprehensive_tax',
    notifId: 1020,
    category: SysCategory.deadline,
    group: 'comprehensive_tax',
    title: '종합부동산세 납부 기간이에요',
    body: '12/1~12/15 — 공시가격 합산 기준 종부세 납부 기간이에요.',
    scheduleLabel: '매년 12월 1일',
    month: 12, day: 1,
    employee: true, business: true,
    requiresHouse: true,
  ),
  SystemReminder(
    key: 'sys_payment_report_check',
    notifId: 1004,
    category: SysCategory.deadline,
    group: 'payment_report',
    title: '지급명세서 제출됐는지 확인해보세요',
    body: '사업소득·기타소득 지급명세서 제출기한(3/10)이 지났어요. 홈택스 로그인 > My홈택스 > 지급명세서 등 제출내역에서 제출 여부를 확인해보세요.',
    scheduleLabel: '매년 3월 12일',
    month: 3, day: 12,
    business: true,
  ),

  // ── 맞춤 (이벤트, 직장인·N잡러) ──
  SystemReminder(
    key: 'sys_threshold',
    notifId: 1005,
    category: SysCategory.moment,
    title: '신용카드 공제 문턱 돌파',
    body: '연봉의 25%를 넘겼어요. 지금부터는 체크·현금이 공제율 2배(30%)예요.',
    scheduleLabel: '공제 문턱(연봉 25%) 도달 시',
    employee: true,
  ),
  SystemReminder(
    key: 'sys_threshold_near',
    notifId: 1011,
    category: SysCategory.moment,
    title: '공제 문턱이 코앞이에요',
    body: '신용카드가 공제 문턱의 80%에 도달했어요. 곧 체크·현금 공제율이 2배가 돼요.',
    scheduleLabel: '공제 문턱 80% 도달 시',
    employee: true,
  ),
];

/// 유형에 해당하는 시스템 알림만.
List<SystemReminder> systemRemindersFor(String userType,
        {bool ownsCar = true, bool ownsHouse = true, bool isVatExempt = false}) =>
    kSystemReminderCatalog
        .where((s) => s.appliesTo(userType,
            ownsCar: ownsCar, ownsHouse: ownsHouse, isVatExempt: isVatExempt))
        .toList();

SystemReminder? systemReminderByKey(String key) {
  for (final s in kSystemReminderCatalog) {
    if (s.key == key) return s;
  }
  return null;
}
