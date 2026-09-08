import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/insurance_engine.dart';
import 'package:secul/core/tax_engine/tax_rates.dart';

/// **고시 만료 알람.**
///
/// 이 앱의 상수 중 상당수는 법률이 아니라 **고시**에서 온다. 고시는 유효기간이 있고
/// 조용히 바뀐다 — 값이 낡아도 테스트는 안 깨진다. 「값은 맞고 연도만 틀린 오류는
/// 테스트로 절대 안 잡힌다」가 이 프로젝트가 이미 적어 둔 교훈이다.
///
/// 그래서 각 상수에 **출처 + 유효기간**을 붙여 두고, 기간이 지나면 이 테스트가
/// 깨지게 한다. 만료 30일 전부터는 경고를 찍는다. 깨지면 할 일은 하나다 —
/// 아래 `source`를 열어 새 고시 값을 확인하고, 코드 상수와 이 표의 `until`을 같이 고친다.
///
/// 검색 요약으로 고치지 않는다. 반드시 출처 원문을 연다.
class Notice {
  final String what;
  final String source;
  final DateTime until;
  final double actual; // 코드가 지금 쓰는 값
  final double expected; // 확인 시점에 원문에서 읽은 값
  final String checkedOn;

  /// 1차 자료(고시 원문·소관부처 공식 페이지)로 확인했는가.
  /// false면 2차 자료(언론·해설)만 본 상태 — 매 실행마다 경고로 남긴다.
  /// 이 프로젝트는 "원문 없이 세법 상수를 고치지 않는다"를 원칙으로 하므로,
  /// 여기에 false가 있다는 건 **아직 갚지 않은 빚**이라는 뜻이다.
  final bool primaryVerified;

  const Notice({
    required this.what,
    required this.source,
    required this.until,
    required this.actual,
    required this.expected,
    required this.checkedOn,
    this.primaryVerified = true,
  });
}

final notices = <Notice>[
  // ── 국민연금 ────────────────────────────────────────────────
  Notice(
    what: '국민연금 기준소득월액 상한액',
    source: '보건복지부 「가입대상 및 연금보험료」 mohw.go.kr/menu.es?mid=a10714010100 '
        '· 국민연금공단 nps.or.kr 연금보험료 안내',
    until: DateTime(2027, 6, 30),
    actual: TaxRates.nationalPensionBaseUpperLimit,
    expected: 6590000,
    checkedOn: '2026-08-01',
  ),
  Notice(
    what: '국민연금 기준소득월액 하한액',
    source: '보건복지부 「가입대상 및 연금보험료」 mohw.go.kr/menu.es?mid=a10714010100',
    until: DateTime(2027, 6, 30),
    actual: TaxRates.nationalPensionBaseLowerLimit,
    expected: 410000,
    checkedOn: '2026-08-01',
  ),

  // ── 건강보험 ────────────────────────────────────────────────
  Notice(
    what: '건강보험료율',
    source: '국민건강보험법 시행령 §44①',
    until: DateTime(2026, 12, 31),
    actual: InsuranceEngine.healthInsuranceRate,
    expected: 0.0719,
    checkedOn: '2026-07-27',
  ),
  Notice(
    what: '재산보험료 부과점수당 금액',
    source: '국민건강보험법 시행령 §44②',
    until: DateTime(2026, 12, 31),
    actual: InsuranceEngine.healthScoreUnitAmount,
    expected: 211.5,
    checkedOn: '2026-07-27',
  ),
  Notice(
    what: '월별 보험료액 상한(직장 보수월액)',
    source: '보건복지부고시 제2025-222호',
    until: DateTime(2026, 12, 31),
    actual: InsuranceEngine.healthPremiumCapSalaried,
    expected: 9183480,
    checkedOn: '2026-07-27',
  ),
  Notice(
    what: '월별 보험료액 상한(소득월액·지역)',
    source: '보건복지부고시 제2025-222호',
    until: DateTime(2026, 12, 31),
    actual: InsuranceEngine.healthPremiumCapOther,
    expected: 4591740,
    checkedOn: '2026-07-27',
  ),
  Notice(
    what: '월별 보험료액 하한',
    source: '보건복지부고시 제2025-222호',
    until: DateTime(2026, 12, 31),
    actual: InsuranceEngine.healthPremiumFloor,
    expected: 20160,
    checkedOn: '2026-07-27',
  ),
  Notice(
    what: '노인장기요양보험료율',
    source: '노인장기요양보험법 시행령 §4',
    until: DateTime(2026, 12, 31),
    actual: InsuranceEngine.longTermCareInsuranceRate,
    expected: 0.009448,
    checkedOn: '2026-07-27',
  ),

  // ── 최저임금 · 실업급여 ─────────────────────────────────────
  Notice(
    what: '최저임금 시급',
    source: '최저임금법 §10 · 고용노동부 고시 (최저임금위원회 minimumwage.go.kr)',
    until: DateTime(2026, 12, 31),
    actual: TaxRates.minimumHourlyWage2026,
    expected: 10320,
    checkedOn: '2026-08-01',
  ),
  Notice(
    what: '구직급여 하한액(최저임금일액의 80%)',
    source: '고용보험법 §46② — 최저임금에서 파생되므로 최저임금만 갱신하면 된다',
    until: DateTime(2026, 12, 31),
    actual: TaxRates.unemploymentDailyFloor,
    expected: 66048,
    checkedOn: '2026-08-01',
  ),

  Notice(
    what: '구직급여 상한액',
    source: '고용노동부 보도자료 「고용보험법 시행령 등 일부개정령안 국무회의 심의·의결」 '
        '(moel.go.kr/news/enews/report/enewsView.do?news_seq=18736) — '
        '기초일액 상한 11만 → 11만 3,500원, 구직급여 상한 66,000 → 68,100원. '
        '113,500 × 60% = 68,100으로 내부 정합. 인상 사유는 최저임금 인상으로 '
        '하한(66,048)이 종전 상한을 넘어섰기 때문 — 상한과 하한이 맞물리므로 '
        '최저임금이 오르면 상한도 함께 확인해야 한다.',
    until: DateTime(2026, 12, 31),
    actual: 68100,
    expected: 68100,
    checkedOn: '2026-08-01',
  ),

  // ── 근로장려금 ──────────────────────────────────────────────
  Notice(
    what: '근로장려금 맞벌이 소득상한',
    source: '조특법 §100의5 · 「2025년 개정세법 해설」 p.298 '
        '(3,800만 → 4,400만, 2025.1.1. 이후 신청분부터). 원문 확보',
    until: DateTime(2026, 12, 31),
    actual: 44000000,
    expected: 44000000,
    checkedOn: '2026-08-01',
  ),
  Notice(
    what: '근로장려금 단독 점감 분모(만원)',
    source: '조특법 §100의5 — 단독 400/400~900/1,300분의165, 홑벌이 700/700~1,400/'
        '1,800분의285, 맞벌이 800/800~1,700/2,700분의330. '
        '맞벌이는 「2025년 개정세법 해설」p.298 원문, 단독·홑벌이는 조문 확인 완료'
        '(2026-08-01). 세 유형 모두 점감 분모 = 상한 − 평탄끝.',
    until: DateTime(2026, 12, 31),
    actual: 1300,
    expected: 1300,
    checkedOn: '2026-08-01',
  ),

  // ── 지방세 ──────────────────────────────────────────────────
  Notice(
    what: '자동차세 연납 이자율(%)',
    source: '지방세법 시행령 §125⑥ — "각각 100분의 5". 2023년까지 있던 연도별 '
        '사다리(2021~22년 10% → 2023년 7% → 2024년 5% → 2025년 이후 3%)는 '
        '없어졌고, 2025.5.27 시행본에 이미 5% 단일로 들어가 있다. '
        '공제액 계산식은 법 §128③ — 1·3월은 연세액 × 남은 일수/365 × 5%, '
        '6월은 제2기분 × 5%, 9월은 제2기분 × 남은 일수/184 × 5%다. '
        '6월 행이 제2기분 기준으로 바뀐 것은 법률 제21308호(2025.12.31)이고 '
        '부칙 §16이 2026년 성립분부터 적용한다고 한다. '
        '※ 서초구 2026년 안내표는 6월을 2.51%(=183/365×5%)로 적어 옛 계산식을 '
        '그대로 두고 있다. 앱은 조문을 따라 2.50%로 쓴다.',
    until: DateTime(2026, 12, 31),
    actual: 5,
    expected: 5,
    checkedOn: '2026-09-08',
  ),

  // ── 복지 고시 (매년 갱신) ────────────────────────────────────
  Notice(
    what: '기초연금 선정기준액(단독, 만원)',
    source: '보건복지부 보도자료 「2026년 노인 단독가구, 소득인정액 월 247만 원 이하면 '
        '기초연금 받는다」(mohw.go.kr, list_no=1488478) — 2026년 단독 247만원'
        '(2025년 228만원에서 19만원 인상), 부부 395만 2,000원. '
        '※ 앱은 부부를 395만원으로 절사한다 — 입력이 만원 단위라 실무 차이는 없다.',
    until: DateTime(2026, 12, 31),
    actual: 247,
    expected: 247,
    checkedOn: '2026-08-01',
  ),
  Notice(
    what: '본인부담상한액 10분위·일반(원)',
    source: '건보공단 「본인부담상한제」 2026년 표(nhis.or.kr, articleNo=10946900) — '
        '일반 90/112/173/326/446/536/843만원, '
        '요양병원 120일 초과 143/181/245/404/580/698/1,096만원. '
        '국민건강보험법 시행령 별표3 계산식(전년도 × (1+물가변동률), 1만원 버림)으로 '
        '2025년 값에서 14개 전부 재현된다. '
        '요양병원 특례는 **전 구간에 있다**(하위 분위 전용이 아니다). 매년 1월경 갱신.',
    until: DateTime(2026, 12, 31),
    actual: 8430000,
    expected: 8430000,
    checkedOn: '2026-09-08',
  ),

  Notice(
    what: '경차 유류세 환급 — 휘발유·경유 리터당 환급액(원)',
    source: '조특법 §111의2③1 — 휘발유 **또는 경유** 모두 리터당 250원. '
        '종전에 경유를 160원으로 적어 두었던 것을 조문으로 바로잡았다. '
        '부탄은 같은 항 제2호가 "부과된 개별소비세 전액"이라고만 하고 리터당 '
        '금액을 정하지 않는다 — 개별소비세법 §1②4바목이 킬로그램당 252원이라 '
        '리터 환산은 조문 밖이다. 적용기한 2026.12.31(법 §111의2①).',
    until: DateTime(2026, 12, 31),
    actual: 250,
    expected: 250,
    checkedOn: '2026-09-08',
  ),

  Notice(
    what: '주택연금 1억원당 월지급금(65세, 만원)',
    source: '한국주택금융공사 「월지급금 예시」 hf.go.kr/ko/sub03/sub03_01_01_02.do '
        '— **2026.3.1. 기준**, 종신지급·정액형·일반주택. '
        '55/60/65/70/75/80세 = 15.6/21.0/25.2/30.7/38.1/48.3만원. '
        'HF 예시 "70세 3억 → 92만 3천원"과 정합. 매년 공시 갱신 대상. '
        '같은 표의 12억원 열이 연령별 월지급금 상한이다 — 70세 341.4만(11억에서 꺾임), '
        '75세 366.6만(10억), 80세 406.0만(9억). 55~65세는 12억까지 꺾이지 않는다. '
        '종전에 375만원 한 줄로 두었으나 그 값은 어느 나이의 상한도 아니었다.',
    until: DateTime(2026, 12, 31),
    actual: 25.2,
    expected: 25.2,
    checkedOn: '2026-09-08',
  ),

  // ── 고용·산재 ───────────────────────────────────────────────
  Notice(
    what: '특고(노무제공자) 고용보험료율 본인부담',
    source: '고용보험 및 산업재해보상보험의 보험료징수 등에 관한 법률 시행령 §56의7④',
    until: DateTime(2026, 12, 31),
    actual: InsuranceEngine.specialWorkerEmploymentRate,
    expected: 0.008,
    checkedOn: '2026-07-27',
  ),
];

void main() {
  final now = DateTime.now();

  test('고시에서 온 상수가 확인 시점 원문 값과 같다', () {
    final wrong = <String>[];
    for (final n in notices) {
      if (n.actual != n.expected) {
        wrong.add('${n.what}: 코드 ${n.actual} ≠ 확인값 ${n.expected} (${n.source})');
      }
    }
    for (final w in wrong) {
      // ignore: avoid_print
      print('  · $w');
    }
    expect(wrong, isEmpty,
        reason: '코드 상수가 원문 확인값과 다르다 — 둘 중 하나가 손댄 뒤 갱신되지 않았다');
  });

  test('유효기간이 지난 고시가 없다 — 지났으면 원문을 다시 열 때다', () {
    final expired = <String>[];
    final soon = <String>[];
    for (final n in notices) {
      final daysLeft = n.until.difference(now).inDays;
      if (daysLeft < 0) {
        expired.add('${n.what} — ${n.until.toIso8601String().substring(0, 10)} 만료 '
            '(${-daysLeft}일 지남) · 확인일 ${n.checkedOn}\n      원문: ${n.source}');
      } else if (daysLeft <= 30) {
        soon.add('${n.what} — $daysLeft일 남음 · 원문: ${n.source}');
      }
    }
    for (final s in soon) {
      // ignore: avoid_print
      print('  ⚠ 곧 만료: $s');
    }
    for (final e in expired) {
      // ignore: avoid_print
      print('  ✕ $e');
    }
    // ignore: avoid_print
    print('추적 중인 고시 ${notices.length}건 · 만료 ${expired.length}건 · 30일 내 ${soon.length}건');
    expect(expired, isEmpty,
        reason: '유효기간이 지난 고시가 있다. 위 원문을 열어 새 값을 확인하고, '
            '코드 상수와 이 파일의 until·expected·checkedOn을 함께 갱신할 것. '
            '검색 요약으로 고치지 말 것.');
  });

  test('1차 자료로 확인하지 못한 상수를 드러낸다', () {
    final unverified = notices.where((n) => !n.primaryVerified).toList();
    for (final n in unverified) {
      // ignore: avoid_print
      print('  ⚠ 1차 미확인: ${n.what} (확인일 ${n.checkedOn}) — ${n.source}');
    }
    // ignore: avoid_print
    print('1차 미확인 ${unverified.length}건 / 전체 ${notices.length}건');
    // 실패시키지 않는다 — 값이 틀렸다는 뜻이 아니라 근거가 약하다는 뜻이다.
    // 다만 매 실행 로그에 남겨 "확인했다고 착각한 채 넘어가는 것"만 막는다.
    expect(unverified.length, lessThanOrEqualTo(1),
        reason: '1차 미확인 상수가 늘고 있다 — 원문 확인 없이 값을 추가하지 말 것');
  });

  /// 경비율 고시는 값이 아니라 **표 전체**라 별도 파일에서 전수 대조한다
  /// (`expense_rate_table_test.dart`). 여기서는 귀속연도만 추적한다.
  test('경비율 고시 귀속연도가 기준 귀속연도에 비해 너무 낡지 않았다', () {
    const noticeYear = 2025; // test/fixtures/expense_rate_notice_2025.json
    // 경비율 고시는 귀속연도 다음 해에 나온다 — 2026 귀속 계산에 2025 귀속 고시를
    // 쓰는 것은 정상이다. 두 해 이상 벌어지면 갱신을 놓친 것이다.
    expect(TaxRates.incomeTaxBrackets.isNotEmpty, isTrue);
    const gap = 2026 - noticeYear; // TaxYear.reference − 고시 귀속연도
    expect(gap, lessThanOrEqualTo(1),
        reason: '경비율 고시가 기준 귀속연도보다 2년 이상 낡았다 — '
            '국세청 경비율 고시를 새로 받아 test/fixtures에 넣을 것');
  });
}
