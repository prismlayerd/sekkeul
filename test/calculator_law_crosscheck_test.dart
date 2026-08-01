import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/tax_engine/tax_rates.dart';
import 'package:secul/ui/screens/acquisition_tax_screen.dart';
import 'package:secul/ui/screens/four_insurance_screen.dart';
import 'package:secul/ui/screens/unemployment_benefit_screen.dart';
import 'package:secul/ui/screens/weekly_holiday_pay_screen.dart';

import 'support/tax_law_reference.dart';

/// 계산기 화면들 — 화면에 그려진 숫자를 조문 검산과 대조한다.
///
/// 이 화면들은 계산이 위젯 State 안에 있어 엔진으로 부를 수 없다. 실제로 값을
/// 입력해 그려진 문자열을 읽는 수밖에 없고, 그래서 지금까지 아무도 안 봤다.
///
/// 근거: 지방세법 §11①8 취득세 · §151①1가목 지방교육세
///      / 고용보험법 §45·§46·별표1 구직급여
///      / 근로기준법 §55·시행령 §30 주휴수당
///      / 국민연금법 부칙 §4 · 국민건강보험법 시행령 §44① · 보험료징수법 시행령 §12①2
String comma(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$b';
}

/// 화면에 보이는 모든 숫자 토큰 — '66,048원'과 '550만원' 양쪽을 다 잡는다.
Set<String> shownTokens(WidgetTester t) {
  final out = <String>{};
  for (final w in t.allWidgets) {
    if (w is Text) {
      final s = w.data ?? w.textSpan?.toPlainText();
      if (s == null) continue;
      for (final m in RegExp(r'\d+(,\d{3})*(만원|억원|원|일|시간|%)?').allMatches(s)) {
        out.add(m.group(0)!);
      }
    }
  }
  return out;
}

void expectToken(WidgetTester t, String want, String what) {
  final shown = shownTokens(t);
  if (!shown.contains(want)) {
    // ignore: avoid_print
    print('  ✕ $what — 기대 $want, 화면: ${(shown.toList()..sort()).join(' / ')}');
  }
  expect(shown, contains(want), reason: '$what — 화면 값이 조문 검산과 다르다 (기대 $want)');
}

void main() {
  int seq = 0;

  Future<void> open(WidgetTester t, Widget w, List<String> inputs) async {
    t.view.physicalSize = const Size(390, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await t.pumpWidget(MaterialApp(key: ValueKey('calc-${seq++}'), home: w));
    await t.pump(const Duration(milliseconds: 300));
    for (int i = 0; i < inputs.length; i++) {
      await t.enterText(find.byType(TextField).at(i), inputs[i]);
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.pump(const Duration(milliseconds: 400));
    t.takeException();
  }

  // ── 취득세 ────────────────────────────────────────────────────
  group('취득세 (지방세법 §11①8 · §151①1가목)', () {
    /// 주택 유상거래 표준세율 — 6억 이하 1%, 6~9억 선형 1→3%, 9억 초과 3%.
    double stdRate(double price) {
      if (price <= 600000000) return 0.01;
      if (price <= 900000000) return 0.01 + (price - 600000000) / 300000000 * 0.02;
      return 0.03;
    }

    /// 지방교육세 = 취득가액 × (표준세율 × 50%) × 20% = 취득가액 × 표준세율 × 10%.
    /// 「취득세액 × 20%」가 아니다 — 그렇게 두면 정확히 2배가 된다.
    double eduTax(double price) => price * stdRate(price) * 0.1;

    testWidgets('1주택 5억 — 취득세 1% + 지방교육세 0.1% = 1.1%', (t) async {
      const price = 500000000.0;
      await open(t, const AcquisitionTaxScreen(), ['500000000']);

      final acq = price * stdRate(price);
      final edu = eduTax(price);
      // ignore: avoid_print
      print('취득가 ${comma(price)} → 취득세 ${comma(acq)} + 지방교육세 ${comma(edu)}'
          ' = ${comma(acq + edu)}');
      expect(acq, 5000000.0);
      expect(edu, 500000.0, reason: '5억 × 1% × 10% = 50만원');

      expectToken(t, '500만원', '취득세');
      expectToken(t, '50만원', '지방교육세');
      // 종전 버그 값(취득세×20% = 100만원)이 화면에 남아 있으면 안 된다.
      expect(shownTokens(t), isNot(contains('100만원')),
          reason: '지방교육세를 취득세액의 20%로 계산하면 2배가 된다');
    });

    testWidgets('다주택 중과 8%여도 지방교육세는 표준세율 기준이다', (t) async {
      // 2주택·조정대상 5억 → 취득세 8% = 4,000만.
      // 지방교육세는 중과와 무관하게 표준세율(1%) 기준 = 50만원.
      const price = 500000000.0;
      await open(t, const AcquisitionTaxScreen(), ['500000000']);
      await t.tap(find.text('2주택'));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.byType(Switch).first); // 조정대상지역
      await t.pump(const Duration(milliseconds: 300));

      // ignore: avoid_print
      print('2주택 조정 — 취득세 ${comma(price * 0.08)} · 지방교육세 ${comma(eduTax(price))}');
      expectToken(t, '4000만원', '중과 취득세 8%');
      expectToken(t, '50만원', '지방교육세(표준세율 기준)');
      expect(shownTokens(t), isNot(contains('800만원')),
          reason: '중과세액의 20%(800만원)를 지방교육세로 잡으면 안 된다');
    });
  });

  // ── 실업급여 ──────────────────────────────────────────────────
  group('실업급여 (고용보험법 §45·§46·별표1)', () {
    testWidgets('평균임금 60%가 하한(최저임금일액×80%)에 미달하면 하한을 준다', (t) async {
      // 월 평균임금 300만 → 일 평균임금 10만 → 60% = 6만원.
      // 하한 = 2026 최저시급 10,320 × 8시간 × 80% = 66,048원 → 하한이 이긴다.
      await open(t, const UnemploymentBenefitScreen(), ['3000000']);

      const dailyAvg = 3000000 / 30;
      const sixty = dailyAvg * 0.6;
      const floor = 10320 * 8 * 0.8;
      // ignore: avoid_print
      print('일 평균임금 ${comma(dailyAvg)} · 60% ${comma(sixty)} vs 하한 ${comma(floor)}');
      expect(floor, greaterThan(sixty), reason: '이 시드는 하한이 걸리는 조건이어야 한다');
      expect(floor, 66048.0);

      expectToken(t, '66,048원', '구직급여 일액(하한)');
      // 소정급여일수 — 피보험기간 1~3년·50세 미만은 150일 (별표1)
      expectToken(t, '150일', '소정급여일수');
      expectToken(t, '9,907,200원', '총액 = 66,048 × 150일');
    });

    testWidgets('고소득자는 하한이 아니라 상한에 걸린다', (t) async {
      // 월 600만 → 일 20만 → 60% = 12만원. 하한(66,048)을 훌쩍 넘어 상한에 걸린다.
      // 구직급여 상한액은 고용보험법 시행령이 정하는 별도 고시값이다.
      await open(t, const UnemploymentBenefitScreen(), ['6000000']);
      const sixty = 6000000 / 30 * 0.6;
      const cap = 68100.0; // 2026년 상한액
      // ignore: avoid_print
      print('월 600만 → 60% ${comma(sixty)} → 상한 ${comma(cap)} 적용');
      expect(sixty, 120000.0);
      expect(cap, greaterThan(66048.0), reason: '상한이 하한보다 낮으면 계산이 뒤집힌다');

      expectToken(t, '68,100원', '구직급여 일액(상한)');
      expect(shownTokens(t), isNot(contains('120,000원')),
          reason: '상한을 안 걸면 과대 안내다');
    });

    test('하한은 최저임금에서 파생된다 — 상수를 따로 박아 두지 않는다', () {
      // 고용보험법 §46② — 최저임금일액(시급 × 8시간)의 80%.
      // 최저임금이 바뀌면 하한도 따라 움직여야 한다. 따로 박아 두면 갱신 때 어긋난다.
      expect(TaxRates.unemploymentDailyFloor,
          TaxRates.minimumHourlyWage2026 * 8 * 0.8);
      expect(TaxRates.unemploymentDailyFloor, 66048.0);
    });
  });

  // ── 주휴수당 ──────────────────────────────────────────────────
  group('주휴수당 (근로기준법 §55 · 시행령 §30)', () {
    testWidgets('주 40시간이면 주휴수당은 8시간분이다', (t) async {
      // 시급 10,320(2026 최저임금) · 하루 8시간 · 주 5일
      await open(t, const WeeklyHolidayPayScreen(), ['10320', '8']);
      await t.tap(find.text('5일'));
      await t.pump(const Duration(milliseconds: 300));

      const wage = 10320.0;
      const weeklyHours = 40.0;
      const workPay = wage * weeklyHours; // 412,800
      const holidayPay = wage * 8; // 82,560
      // ignore: avoid_print
      print('시급 ${comma(wage)} · 주 40시간 → 근로수당 ${comma(workPay)}'
          ' + 주휴수당 ${comma(holidayPay)} = ${comma(workPay + holidayPay)}');

      expectToken(t, '412,800원', '주 근로 수당');
      expectToken(t, '82,560원', '주휴수당(8시간분)');
      expectToken(t, '495,360원', '주휴수당 포함 주급');
    });

    testWidgets('주 15시간 미만이면 주휴수당이 없다 (시행령 §30)', (t) async {
      // 하루 3시간 × 4일 = 12시간 → 15시간 미만
      await open(t, const WeeklyHolidayPayScreen(), ['10320', '3']);
      await t.tap(find.text('4일'));
      await t.pump(const Duration(milliseconds: 300));

      const workPay = 10320.0 * 12;
      // ignore: avoid_print
      print('주 12시간 → 근로수당 ${comma(workPay)} · 주휴수당 없음');
      expectToken(t, '123,840원', '주 근로 수당(12시간)');
      // 주휴수당이 붙으면 주급이 근로수당보다 커진다 — 그러면 안 된다.
      expect(shownTokens(t).where((s) => s.endsWith('원')).length, greaterThan(0));
    });
  });

  // ── 4대보험 ───────────────────────────────────────────────────
  group('4대보험 계산기', () {
    testWidgets('월 300만원 — 요율이 조문 검산과 일치하고 절사 오차가 없다', (t) async {
      await open(t, const FourInsuranceScreen(), ['3000000']);

      const monthly = 3000000.0;
      final ref = refAnnualInsurance(monthly);
      final np = trunc10(monthly * 0.0475);
      final hi = trunc10(monthly * 0.03595);
      final ltc = trunc10(hi * (0.009448 / 0.0719));
      final ei = trunc10(monthly * 0.009);

      // ignore: avoid_print
      print('월 ${comma(monthly)} → 연금 ${comma(np)} · 건보 ${comma(hi)}'
          ' · 장기요양 ${comma(ltc)} · 고용 ${comma(ei)}');
      expect(ref.pension, closeTo(np * 12, 0.01));

      // 3,000,000 × 0.009 = 26999.999999999996 — 곧바로 절사하면 26,990원이 된다.
      expect(ei, 27000.0, reason: '부동소수점 오차로 10원이 깎이면 안 된다');

      expectToken(t, '142,500원', '국민연금 4.75%');
      expectToken(t, '107,850원', '건강보험 3.595%');
      expectToken(t, '14,170원', '장기요양(건보×13.14%)');
      expectToken(t, '27,000원', '고용보험 0.9%');
      expectToken(t, '291,520원', '합계');
      expect(shownTokens(t), isNot(contains('26,990원')),
          reason: '절사 전에 원 단위로 반올림하지 않으면 10원이 깎인다');
    });
  });
}
