import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/capital_gains_tax_screen.dart';
import 'package:secul/ui/screens/inheritance_gift_tax_screen.dart';
import 'package:secul/ui/screens/retirement_pension_screen.dart';

import 'support/tax_law_reference.dart';

/// 계산이 **위젯 State 안에** 있는 화면들 — 엔진의 조문 검증 체계가 닿지 않는다.
/// 이 앱에는 그런 화면이 37개 있고, 값 대조를 붙이자마자 오류가 나오고 있다.
/// (양도소득세 세율표가 2022년 이전 값이었던 것도 여기서 나왔다.)
///
/// 근거: 소득세법 §55① 세율 · §95② 장기보유특별공제 · §103① 양도소득기본공제
///      · §104①1(§55① 준용) / 상속세 및 증여세법 §26 세율 · §21 일괄공제
///      / 근로자퇴직급여 보장법 §8① 퇴직금
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
    print('  ✕ $what — 기대 $want, 화면: ${(shown.toList()..sort()).join(' / ')}');
  }
  expect(shown, contains(want), reason: '$what — 화면 값이 조문 검산과 다르다 (기대 $want)');
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
    await t.pumpWidget(MaterialApp(key: ValueKey('b1-${seq++}'), home: w));
    await t.pump(const Duration(milliseconds: 300));
    for (int i = 0; i < inputs.length; i++) {
      await t.enterText(find.byType(TextField).at(i), inputs[i]);
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.pump(const Duration(milliseconds: 400));
    t.takeException();
  }

  group('양도소득세 (소법 §95·§103·§104)', () {
    /// 양도차익 − 장기보유특별공제 − 기본공제 250만 → 누진세율(§55① 준용).
    /// 일반 부동산은 보유 3년부터 연 2%, 최대 30%(15년).
    double refLongHold(double gain, int years, {bool oneHouse = false}) {
      if (years < 3) return 0;
      final rate = oneHouse
          ? (years * 0.08).clamp(0.0, 0.80)
          : (years * 0.02).clamp(0.0, 0.30);
      return gain * rate;
    }

    testWidgets('과세표준 4,600만~5,000만 구간 — 2023 개정 세율이어야 한다', (t) async {
      // 취득 3억 · 양도 3억 5,500만 · 보유 3년 → 양도차익 5,500만
      // 장특공제 6% = 330만 → 5,170만 − 기본공제 250만 = 과세표준 4,920만
      //
      // 이 값이 정확히 경계를 가른다:
      //   현행 §55① (5,000만 경계) → 15% − 126만 = 612만
      //   2022년 이전 표 (4,600만 경계) → 24% − 522만 = 658.8만
      // 46.8만원 차이. 옛 표를 쓰면 사용자가 그만큼 더 낼 것으로 안다.
      await open(t, const CapitalGainsTaxScreen(),
          ['300000000', '355000000', '3']);

      const gain = 55000000.0;
      final longHold = refLongHold(gain, 3);
      final base = gain - longHold - 2500000;
      final national = refProgressiveTax(base);
      final local = national * 0.1; // 지방소득세 10%

      // ignore: avoid_print
      print('양도차익 ${comma(gain)} − 장특 ${comma(longHold)} − 기본 2,500,000'
          ' = 과세표준 ${comma(base)}\n    산출세액 ${comma(national)}'
          ' + 지방세 ${comma(local)} = ${comma(national + local)}');

      expect(base, closeTo(49200000, 1), reason: '경계를 걸치는 과세표준이어야 한다');
      expect(base, greaterThan(46000000),
          reason: '옛 표의 15% 상한(4,600만)을 넘어야 두 표가 갈린다');
      expect(base, lessThanOrEqualTo(50000000),
          reason: '현행 15% 상한(5,000만) 안이어야 한다');
      // 옛 표였다면 이만큼 더 나왔다.
      final oldTable = base * 0.24 - 5220000;
      expect(oldTable - refProgressiveTax(base), closeTo(468000, 1),
          reason: '두 표의 차이가 46.8만원인 시드다');
      // 옛 표라면 24% 구간이라 세금이 크게 달라진다.
      expect(national, closeTo(base * 0.15 - 1260000, 1),
          reason: '4,670만원은 15% 구간이다 (2023 개정 전 표라면 24%)');
      expectToken(t, '${comma(((national + local) / 10000).round())}만원', '양도세 합계');
    });

    testWidgets('1세대 1주택 장기보유특별공제는 연 8%·최대 80%', (t) async {
      await open(t, const CapitalGainsTaxScreen(),
          ['500000000', '1500000000', '12']);
      await t.tap(find.byType(Switch).first); // 1세대 1주택
      await t.pump(const Duration(milliseconds: 300));

      // 보유 12년 × 8% = 96% → 80% 상한
      expectToken(t, '80%', '1세대 1주택 장특공제율(상한)');
    });

    testWidgets('보유 3년 미만이면 장기보유특별공제가 없다 (§95②)', (t) async {
      await open(t, const CapitalGainsTaxScreen(),
          ['300000000', '400000000', '2']);
      expectToken(t, '0%', '보유 2년 장특공제율');
    });
  });

  group('상속·증여세 (상증세법 §21·§26)', () {
    /// §26 세율 — 1억 이하 10% / 5억 이하 20%(누진공제 1천만) /
    /// 10억 이하 30%(6천만) / 30억 이하 40%(1.6억) / 30억 초과 50%(4.6억).
    double refTax(double base) {
      if (base <= 0) return 0;
      if (base <= 100000000) return base * 0.10;
      if (base <= 500000000) return base * 0.20 - 10000000;
      if (base <= 1000000000) return base * 0.30 - 60000000;
      if (base <= 3000000000) return base * 0.40 - 160000000;
      return base * 0.50 - 460000000;
    }

    testWidgets('상속 10억 · 일괄공제 5억 → 과세표준 5억, 세금 9,000만원', (t) async {
      await open(t, const InheritanceGiftTaxScreen(), ['1000000000']);

      const base = 500000000.0; // 10억 − 일괄공제 5억(§21①)
      final tax = refTax(base);
      // ignore: avoid_print
      print('상속 10억 − 일괄공제 5억 = 과세표준 ${comma(base)} → ${comma(tax)}');
      expect(tax, closeTo(90000000, 1), reason: '5억 × 20% − 1천만 = 9,000만');
      expectToken(t, '9000만원', '상속세');
    });

    test('세율 구간 경계 — 5억/10억/30억에서 누진공제가 이어진다', () {
      // 구간이 이어지지 않으면 경계에서 세금이 튄다(1원 더 벌어 손해 보는 지점).
      for (final edge in [100000000.0, 500000000.0, 1000000000.0, 3000000000.0]) {
        final below = refTax(edge);
        final above = refTax(edge + 1);
        expect(above - below, lessThan(1.0),
            reason: '과세표준 ${comma(edge)} 경계에서 세금이 튄다');
      }
    });
  });

  group('퇴직급여 (근퇴법 §8①)', () {
    testWidgets('DB형 = 월평균임금 × 근속연수', (t) async {
      // 월평균임금 350만 · 근속 10년 → 3,500만원
      await open(t, const RetirementPensionScreen(), ['3500000', '10']);
      const expected = 3500000.0 * 10;
      // ignore: avoid_print
      print('월평균임금 3,500,000 × 10년 = ${comma(expected)}');
      expectToken(t, '${comma(expected / 10000)}만원', 'DB형 퇴직급여');
    });
  });
}
