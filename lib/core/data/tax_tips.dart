/// 유형·시기에 맞춘 "득 되는 정보" 데이터.
/// 출처: 국세청 2026 세금절약 가이드 I(주요 세무 일정·절약 팁), 2026 개정세법 해설.
/// 지식 정리: 지식_변환/마크다운/2026_세금가이드_득되는정보.md, 2026_개정세법_앱영향분석.md
///
/// 계산 엔진과 무관한 안내 레이어. 홈 '이달의 절세' 카드가 이번 달+유형에 맞는 팁을 고른다.
library;

class TaxTip {
  final String label; // 분류 칩: '5월 신고' / '2026 혜택' / '꿀팁' 등
  final String title; // 한 줄 헤드라인
  final String body; // 부연 한 줄
  final Set<int> months; // 관련 월(비면 상시). 일정성 팁은 해당 월에만 노출.
  final Set<String> types; // 적용 유형(비면 전체). '직장인'/'프리랜서'/'N잡러'
  final String? action; // 탭 시 이동할 화면 의미키('simulator'/'record'/'book'). null=정보성
  const TaxTip({
    required this.label,
    required this.title,
    required this.body,
    this.months = const {},
    this.types = const {},
    this.action,
  });
}

/// 큐레이션 팁 — 상시 가치(2026 개정 혜택 + 유형별 꿀팁)만.
/// 세무 마감(연말정산·5월·부가세·중간예납·장려금)은 시즌 배너 + 시스템 푸시가 담당하므로
/// 인앱 3중 노출을 피하려고 '이달의 절세' 팁에서는 제외한다.
const List<TaxTip> _allTips = [
  // ── 상시 안내(특정 월 아님) ──
  TaxTip(
    label: '소득파악',
    title: '내 소득은 매월 국세청에 잡혀요',
    body: '실시간 소득파악 — 3.3% 사업소득도 매월 반영돼요. 빠짐없이 기록하세요.',
    types: {'프리랜서', 'N잡러'},
  ),
  TaxTip(
    label: '지급명세서',
    title: '사람 쓰면 지급명세서 잊지 마세요',
    body: '용역비 지급 시 다음 달 말일까지 제출 — 미제출 0.25% 가산세.',
    types: {'프리랜서', 'N잡러'},
  ),

  // ── 2026 개정 혜택 (상시) ──
  TaxTip(
    label: '2026 혜택',
    title: '월세 세액공제 대상 확대',
    body: '2026년부터 무주택 주말부부 배우자·다자녀 주택까지 넓어졌어요.',
    types: {'직장인', 'N잡러'},
    action: 'simulator',
  ),
  TaxTip(
    label: '2026 혜택',
    title: '대학생 교육비 공제 확대',
    body: '자녀 대학 교육비, 소득요건이 폐지됐어요(한도 900만).',
    types: {'직장인', 'N잡러'},
    action: 'simulator',
  ),
  TaxTip(
    label: '2026 혜택',
    title: '노란우산 납입한도 확대',
    body: '2026년부터 연 1,800만원까지 — 소득공제로 절세하세요.',
    types: {'프리랜서', 'N잡러'},
    action: 'simulator',
  ),
  TaxTip(
    label: '꿀팁',
    title: '월세공제 문턱, 생각보다 넓어요',
    body: '총급여 8,000만(종합소득 7,000만)까지 대상 — 한도는 연 1,000만원.',
    types: {'직장인', 'N잡러'},
    action: 'simulator',
  ),

  // ── 유형별 꿀팁 (상시) ──
  TaxTip(
    label: '꿀팁',
    title: '따로 사는 부모님도 공제',
    body: '만 60세 이상·소득 적으면 부양가족 공제를 받을 수 있어요.',
    types: {'직장인', 'N잡러'},
    action: 'simulator',
  ),
  TaxTip(
    label: '꿀팁',
    title: '장부 쓰면 경비 더 인정',
    body: '간편장부를 쓰면 단순경비율보다 넓게 경비를 인정받아요.',
    types: {'프리랜서', 'N잡러'},
    action: 'book',
  ),
];

/// 이번 달 + 유형에 맞는 팁 상위 N개. 일정성(이번 달) → 2026 혜택 → 꿀팁 순.
List<TaxTip> taxTipsFor(String userType, int month, {int limit = 2}) {
  int score(TaxTip t) {
    final typeOk = t.types.isEmpty || t.types.contains(userType);
    if (!typeOk) return 0;
    if (t.months.contains(month)) return 3; // 이번 달 일정 — 최우선
    if (t.months.isNotEmpty) return 0; // 다른 달 일정 — 제외
    if (t.label == '2026 혜택') return 2; // 상시 혜택
    return 1; // 상시 꿀팁
  }

  final scored = <MapEntry<TaxTip, int>>[];
  for (final t in _allTips) {
    final s = score(t);
    if (s > 0) scored.add(MapEntry(t, s));
  }
  scored.sort((a, b) => b.value.compareTo(a.value));
  return scored.take(limit).map((e) => e.key).toList();
}
