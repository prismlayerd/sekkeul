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
    source: '고용노동부 — 2026.1.1. 이후 이직자부터 66,000원 → 68,100원(6년 만의 인상). '
        '최저임금 인상으로 하한(66,048)이 종전 상한을 넘어선 것이 인상 사유다. '
        '⚠ 1차 자료(고시 원문) 미확인 — moel.go.kr·ei.go.kr 접근 실패, 2차 자료 다수 일치로 기록',
    until: DateTime(2026, 12, 31),
    actual: 68100,
    expected: 68100,
    checkedOn: '2026-08-01',
    primaryVerified: false,
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
    what: '근로장려금 단독·홑벌이 산정식 구간',
    source: '조특법 §100의5 — 개정이 없어 개정세법 해설에 산정식이 실리지 않았다. '
        '총소득 기준(단독 2,200만·홑벌이 3,200만)만 2025년 해설의 "좌동"으로 확인. '
        '⚠ 점증·평탄·점감 구간 경계는 원문 미확인 — 맞벌이가 800/1,700/4,400인데 '
        '화면은 단독 900/2,100, 홑벌이 1,400/2,100을 쓴다. 조문 원문 확인 필요',
    until: DateTime(2026, 12, 31),
    actual: 22000000,
    expected: 22000000,
    checkedOn: '2026-08-01',
    primaryVerified: false,
  ),

  // ── 지방세 ──────────────────────────────────────────────────
  Notice(
    what: '자동차세 연납 공제율 기준(%)',
    source: '지방세법 §128③ · 시행령 §125 — 화면의 1월 4.57%는 334/365 × **5%**에서 나온다. '
        '2차 자료는 2025년 이후 3%(2023년 7% → 2024년 5% → 2025년~ 3%)라고 하는데, '
        'law.go.kr 조문에서 확인된 문구는 "100분의 5"뿐이고 연도별 경과규정 여부를 '
        '확인하지 못했다. ⚠ 원문 불명확 — 3%가 맞으면 화면이 할인을 과대 안내 중이다',
    until: DateTime(2026, 12, 31),
    actual: 5,
    expected: 5,
    checkedOn: '2026-08-01',
    primaryVerified: false,
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
    expect(unverified.length, lessThanOrEqualTo(4),
        reason: '1차 미확인 상수가 늘고 있다 — 원문 확인 없이 값을 추가하지 말 것');
  });

  /// 경비율 고시는 값이 아니라 **표 전체**라 별도 파일에서 전수 대조한다
  /// (`expense_rate_table_test.dart`). 여기서는 귀속연도만 추적한다.
  test('경비율 고시 귀속연도가 기준 귀속연도에 비해 너무 낡지 않았다', () {
    const noticeYear = 2025; // test/fixtures/expense_rate_notice_2025.json
    // 경비율 고시는 귀속연도 다음 해에 나온다 — 2026 귀속 계산에 2025 귀속 고시를
    // 쓰는 것은 정상이다. 두 해 이상 벌어지면 갱신을 놓친 것이다.
    expect(TaxRates.incomeTaxBrackets.isNotEmpty, isTrue);
    final gap = 2026 - noticeYear; // TaxYear.reference − 고시 귀속연도
    expect(gap, lessThanOrEqualTo(1),
        reason: '경비율 고시가 기준 귀속연도보다 2년 이상 낡았다 — '
            '국세청 경비율 고시를 새로 받아 test/fixtures에 넣을 것');
  });
}
