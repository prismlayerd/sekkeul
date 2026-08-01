import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/earned_income_tax_credit_screen.dart';
import 'package:secul/ui/screens/loan_interest_screen.dart';
import 'package:secul/ui/screens/loan_schedule_screen.dart';

/// 배치 2 — 대출 계산기와 근로장려금.
///
/// 대출은 세법이 아니라 **금융 공식**이라 검산이 명확하다(원리금균등 상환식).
/// 정책금리는 요약.md 규칙대로 화면이 범위만 안내하고 계산은 사용자가 넣은
/// 금리로 하므로, 검증 대상은 금리표가 아니라 **공식**이다.
///
/// 근로장려금 근거: 조세특례제한법 §100의5
///   · 「2025년 개정세법 해설」 p.298 (맞벌이 소득상한 3,800만 → 4,400만)
String comma(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$b';
}

Set<String> tokens(WidgetTester t) {
  final out = <String>{};
  for (final w in t.allWidgets) {
    if (w is Text) {
      final s = w.data ?? w.textSpan?.toPlainText();
      if (s == null) continue;
      for (final m in RegExp(r'\d+(,\d{3})*(\.\d+)?(만원|억원|원|%)?').allMatches(s)) {
        out.add(m.group(0)!);
      }
    }
  }
  return out;
}

void expectToken(WidgetTester t, String want, String what) {
  final shown = tokens(t);
  if (!shown.contains(want)) {
    // ignore: avoid_print
    print('  ✕ $what — 기대 $want, 화면: ${(shown.toList()..sort()).take(40).join(' / ')}');
  }
  expect(shown, contains(want), reason: '$what — 화면 값이 검산과 다르다 (기대 $want)');
}

/// 원리금균등 월 상환액 — M = P·r(1+r)^n / ((1+r)^n − 1)
double refAnnuity({required double principal, required double annualRate, required int months}) {
  final r = annualRate / 12;
  if (r == 0) return principal / months;
  final p = math.pow(1 + r, months).toDouble();
  return principal * r * p / (p - 1);
}

void main() {
  int seq = 0;

  Future<void> open(WidgetTester t, Widget w, List<String> inputs) async {
    t.view.physicalSize = const Size(390, 4000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await t.pumpWidget(MaterialApp(key: ValueKey('b2-${seq++}'), home: w));
    await t.pump(const Duration(milliseconds: 300));
    for (int i = 0; i < inputs.length; i++) {
      await t.enterText(find.byType(TextField).at(i), inputs[i]);
      await t.pump(const Duration(milliseconds: 250));
    }
    await t.pump(const Duration(milliseconds: 400));
    t.takeException();
  }

  group('대출 — 원리금균등 상환식', () {
    testWidgets('1억 · 연 4% · 30년 → 월 상환액이 공식과 일치한다', (t) async {
      await open(t, const LoanInterestScreen(), ['100000000', '4.0', '30']);

      final m = refAnnuity(principal: 100000000, annualRate: 0.04, months: 360);
      final total = m.round() * 360;
      // ignore: avoid_print
      print('1억 · 4% · 360개월 → 월 ${comma(m)} · 총 ${comma(total)}'
          ' · 이자 ${comma(total - 100000000)}');
      expect(m, closeTo(477415, 1), reason: '원리금균등 공식값');

      expectToken(t, '${comma(m)}원', '월 상환액');
      expectToken(t, '${comma(total)}원', '총 상환액');
      expectToken(t, '${comma(total - 100000000)}원', '총 이자');
    });

    testWidgets('상환 스케줄 1회차 — 이자는 잔금 × 월이율, 원금은 나머지', (t) async {
      await open(t, const LoanScheduleScreen(), ['100000000', '4.0', '30']);

      final m = refAnnuity(principal: 100000000, annualRate: 0.04, months: 30);
      final firstInterest = 100000000 * 0.04 / 12;
      final firstPrincipal = m - firstInterest;
      // ignore: avoid_print
      print('1억 · 4% · 30개월 → 월 ${comma(m)}'
          ' · 1회차 이자 ${comma(firstInterest)} 원금 ${comma(firstPrincipal)}'
          ' 잔금 ${comma(100000000 - firstPrincipal)}');

      expectToken(t, comma(firstInterest), '1회차 이자');
      expectToken(t, comma(firstPrincipal), '1회차 원금');
      expectToken(t, comma(100000000 - firstPrincipal), '1회차 후 잔금');
    });

    testWidgets('금리 0%면 원금을 개월수로 나눈 값이다', (t) async {
      await open(t, const LoanInterestScreen(), ['120000000', '0', '10']);
      final m = refAnnuity(principal: 120000000, annualRate: 0, months: 120);
      expect(m, closeTo(1000000, 0.01));
      expectToken(t, '1,000,000원', '무이자 월 상환액');
    });
  });

  group('근로장려금 (조특법 §100의5)', () {
    /// 맞벌이 — 「2025년 개정세법 해설」 p.298 원문 그대로.
    /// 800만 미만: ×800분의330 / 800~1,700만: 330만 / 1,700~4,400만: 330만−(초과)×2,700분의330
    double refDual(double manwon) {
      if (manwon <= 0) return 0;
      if (manwon < 800) return manwon / 800 * 330;
      if (manwon < 1700) return 330;
      if (manwon < 4400) return 330 - (manwon - 1700) * 330 / 2700;
      return 0;
    }

    Future<void> openDual(WidgetTester t, String income) async {
      await open(t, const EarnedIncomeTaxCreditScreen(), [income]);
      await t.tap(find.text('맞벌이'));
      await t.pump(const Duration(milliseconds: 400));
    }


    /// 세 가구 유형이 같은 구조를 따른다 — 조특법 §100의5.
    ///   점증: 총급여액 등 × (최대액 / 점증경계)
    ///   평탄: 최대액
    ///   점감: 최대액 − (초과분) × (최대액 / (상한 − 평탄끝))
    double refByType(double manwon, double rise, double flat, double cap, double max) {
      if (manwon <= 0) return 0;
      if (manwon < rise) return manwon / rise * max;
      if (manwon < flat) return max;
      if (manwon < cap) return max - (manwon - flat) * max / (cap - flat);
      return 0;
    }

    test('점감 분모는 언제나 상한 − 평탄끝이다 — 세 유형 공통 구조', () {
      // 맞벌이는 「2025년 개정세법 해설」p.298 원문으로 확인된 값이다.
      // 그 구조가 단독·홑벌이에도 성립해야 한다.
      const types = [
        ('단독', 400.0, 900.0, 2200.0, 165.0, 1300.0),
        ('홑벌이', 700.0, 1400.0, 3200.0, 285.0, 1800.0),
        ('맞벌이', 800.0, 1700.0, 4400.0, 330.0, 2700.0),
      ];
      for (final (name, rise, flat, cap, max, denom) in types) {
        expect(cap - flat, denom, reason: '$name: 점감 분모 ≠ 상한 − 평탄끝');
        // 평탄 끝에서 최대액, 상한에서 0 — 구간이 이어진다.
        expect(refByType(flat, rise, flat, cap, max), max);
        expect(refByType(cap - 0.01, rise, flat, cap, max), lessThan(0.1));
      }
    });

    testWidgets('단독가구 — 총급여 1,500만은 88.8만원이지 165만원이 아니다', (t) async {
      // 종전 코드는 900~2,100만을 평탄 구간으로 봐서 165만원 전액을 안내했다.
      // 조문은 900만부터 점감이 시작된다 — 76만원 과대였다.
      await open(t, const EarnedIncomeTaxCreditScreen(), ['15000000']);
      final v = refByType(1500, 400, 900, 2200, 165);
      // ignore: avoid_print
      print('단독 1,500만 → ${v.toStringAsFixed(1)}만원 (종전 코드는 165만원)');
      expect(v, closeTo(88.8, 0.1));
      expectToken(t, '${v.round()}만원', '단독 점감 구간');
      // 안내 문구의 "최대 165만원"은 설명이라 화면에 남는다. 확인할 것은
      // **계산 결과**가 최대액이 아니라는 것 — 89만원과 165만원은 다른 값이다.
      expect(v, lessThan(165), reason: '900만원을 넘으면 최대액이 아니다');
    });

    testWidgets('단독가구 — 저소득 구간은 400분의 165로 가파르게 오른다', (t) async {
      // 총급여 300만 → 300/400 × 165 = 123.8만. 종전 코드(900분의 165)는 55만이었다.
      await open(t, const EarnedIncomeTaxCreditScreen(), ['3000000']);
      final v = refByType(300, 400, 900, 2200, 165);
      // ignore: avoid_print
      print('단독 300만 → ${v.toStringAsFixed(1)}만원 (종전 코드는 55만원)');
      expect(v, closeTo(123.75, 0.1));
      expectToken(t, '${v.round()}만원', '단독 점증 구간');
    });

    testWidgets('홑벌이 — 700만에서 최대액에 도달하고 1,400만부터 줄어든다', (t) async {
      await open(t, const EarnedIncomeTaxCreditScreen(), ['7000000']);
      await t.tap(find.text('홑벌이'));
      await t.pump(const Duration(milliseconds: 400));
      expect(refByType(700, 700, 1400, 3200, 285), 285);
      expectToken(t, '285만원', '홑벌이 최대액 도달점');
    });

    testWidgets('점증 구간 — 총급여 600만 → 800분의 330', (t) async {
      await openDual(t, '6000000');
      final v = refDual(600);
      // ignore: avoid_print
      print('맞벌이 600만 → ${v.toStringAsFixed(1)}만원');
      expect(v, closeTo(247.5, 0.1));
      expectToken(t, '${v.round()}만원', '맞벌이 점증 구간');
    });

    testWidgets('평탄 구간 — 800만~1,700만은 330만원 정액', (t) async {
      await openDual(t, '12000000');
      expect(refDual(1200), 330);
      expectToken(t, '330만원', '맞벌이 평탄 구간');
    });

    testWidgets('점감 구간 — 2,000만은 2,700분의 330으로 깎인다', (t) async {
      await openDual(t, '20000000');
      final v = refDual(2000);
      // ignore: avoid_print
      print('맞벌이 2,000만 → ${v.toStringAsFixed(1)}만원 '
          '(옛 산정식 2,100분의330이면 ${(330 - 300 * 330 / 2100).toStringAsFixed(1)}만원)');
      expect(v, closeTo(293.3, 0.1));
      expectToken(t, '${v.round()}만원', '맞벌이 점감 구간');
    });

    testWidgets('소득상한 4,400만 — 개정 전 3,800만이면 0원이 나온다', (t) async {
      // 4,000만원은 개정 후에만 지급 대상이다. 옛 상한(3,800만)을 쓰면 0원.
      await openDual(t, '40000000');
      final v = refDual(4000);
      // ignore: avoid_print
      print('맞벌이 4,000만 → ${v.toStringAsFixed(1)}만원 (개정 전 상한이면 0원)');
      expect(v, greaterThan(0),
          reason: '2025.1.1. 이후 신청분은 4,400만 미만까지 지급 대상이다');
      expect(v, closeTo(48.9, 0.1));
      expectToken(t, '${v.round()}만원', '맞벌이 상한 근처');
    });

    testWidgets('4,400만 이상은 0원', (t) async {
      await openDual(t, '45000000');
      expect(refDual(4500), 0);
      expectToken(t, '0원', '소득상한 초과');
    });
  });
}
