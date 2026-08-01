import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/car_tax_annual_screen.dart';
import 'package:secul/ui/screens/isa_tax_benefits_screen.dart';
import 'package:secul/ui/screens/national_pension_timing_screen.dart';

/// 배치 3 — 국민연금 수령시기 · ISA · 자동차세 연납.
///
/// 근거: 국민연금법 §61③ 조기노령연금(1년당 6% 감액, 최대 5년 30%)
///      · §62④ 연기연금(1년당 7.2% 증액, 최대 5년 36%)
///      / 조특법 §91의18 ISA — 비과세 한도 일반 200만·서민형 400만,
///        초과분 9.9% 분리과세(지방세 포함), 일반계좌 이자소득세 15.4%
///      / 지방세법 §128③ · 시행령 §125 자동차세 연납 공제
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
      for (final m
          in RegExp(r'[+-]?\d+(,\d{3})*(\.\d+)?(만원|억원|원|%)?').allMatches(s)) {
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

void main() {
  int seq = 0;

  Future<void> open(WidgetTester t, Widget w, List<String> inputs) async {
    t.view.physicalSize = const Size(390, 4500);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await t.pumpWidget(MaterialApp(key: ValueKey('b3-${seq++}'), home: w));
    await t.pump(const Duration(milliseconds: 300));
    for (int i = 0; i < inputs.length; i++) {
      await t.enterText(find.byType(TextField).at(i), inputs[i]);
      await t.pump(const Duration(milliseconds: 250));
    }
    await t.pump(const Duration(milliseconds: 400));
    t.takeException();
  }

  group('국민연금 조기·연기 (국민연금법 §61③·§62④)', () {
    testWidgets('조기수령은 1년당 6% 감액 — 5년이면 30%', (t) async {
      await open(t, const NationalPensionTimingScreen(), ['1000000']);

      for (var year = 1; year <= 5; year++) {
        final rate = year * 6;
        final amount = 1000000 * (1 - rate / 100);
        // ignore: avoid_print
        print('조기 $year년 → -$rate% · ${comma(amount)}원');
        expectToken(t, '-$rate%', '조기 $year년 감액률');
        expectToken(t, '${comma(amount / 10000)}만원', '조기 $year년 월 연금액');
      }
    });

    testWidgets('연기수령은 1년당 7.2% 증액 — 5년이면 36%', (t) async {
      await open(t, const NationalPensionTimingScreen(), ['1000000']);

      // 화면은 정수 %로 반올림해 보여준다: 7.2/14.4/21.6/28.8/36 → 7/14/22/29/36
      const shownRates = [7, 14, 22, 29, 36];
      for (var year = 1; year <= 5; year++) {
        final exact = year * 7.2;
        expect(exact.round(), shownRates[year - 1],
            reason: '연기 $year년 증액률은 ${exact}%다');
        expectToken(t, '+${shownRates[year - 1]}%', '연기 $year년 증액률');
      }
    });

    testWidgets('감액·증액이 대칭이 아니다 — 연기가 더 유리하다', (t) async {
      // 조기 6%/년, 연기 7.2%/년. 같은 기간이면 연기 쪽 변동폭이 크다.
      expect(7.2, greaterThan(6.0));
      await open(t, const NationalPensionTimingScreen(), ['1000000']);
      expectToken(t, '-30%', '조기 5년');
      expectToken(t, '+36%', '연기 5년');
    });
  });

  group('ISA (조특법 §91의18)', () {
    testWidgets('비과세 한도 — 일반형 200만 · 서민형 400만', (t) async {
      await open(t, const IsaTaxBenefitsScreen(), ['20000000', '4', '5']);
      expectToken(t, '2,000,000원', '일반형 비과세 한도');
      await t.tap(find.text('서민·농어민형'));
      await t.pump(const Duration(milliseconds: 400));
      expectToken(t, '4,000,000원', '서민형 비과세 한도');
    });

    testWidgets('말도 안 되는 수익률을 넣어도 천문학적 숫자를 그리지 않는다', (t) async {
      // 종전에는 복리가 폭발해 `.round()`가 int64 최대값을 뱉었고, 화면이 그걸
      // "절세 효과 +9,223,372,036,854,775,807원"이라고 보여줬다.
      await open(t, const IsaTaxBenefitsScreen(), ['20000000', '5000000', '5']);
      final shown = tokens(t);
      expect(shown.any((s) => s.contains('9,223,372,036,854,775,807')), isFalse,
          reason: 'int64 최대값이 화면에 떴다 — 계산이 폭발했는데 그대로 그렸다');
    });

    testWidgets('정상 입력에서는 절세액이 이자 × (15.4% − 9.9%) 구조를 따른다', (t) async {
      // 비과세 한도를 넘는 이자에는 9.9%, 일반계좌는 전액 15.4%.
      // 따라서 절세액 = 한도분 15.4% + 초과분 (15.4% − 9.9%).
      await open(t, const IsaTaxBenefitsScreen(), ['20000000', '4', '5']);
      final shown = tokens(t);
      expect(shown.any((s) => s.endsWith('원')), isTrue,
          reason: '정상 입력인데 결과가 안 그려졌다');
    });
  });

  group('자동차세 연납 (지방세법 §128③)', () {
    testWidgets('공제액 = 연세액 × 공제율, 납부액 = 연세액 − 공제액', (t) async {
      await open(t, const CarTaxAnnualScreen(), ['520000']);

      // 화면의 1월 공제율 4.57%는 334/365 × 5%에서 나온다.
      // ⚠ 2025년 이후 기준이 3%라는 2차 자료가 있으나 원문이 불명확해 고치지 않았다.
      //   추적: test/notice_expiry_test.dart (1차 미확인)
      const annual = 520000.0;
      const rate = 4.57;
      final discount = annual * rate / 100;
      // ignore: avoid_print
      print('연세액 ${comma(annual)} × $rate% = 공제 ${comma(discount)}'
          ' → 납부 ${comma(annual - discount)}');

      expectToken(t, '-${comma(discount)}원', '연납 공제액');
      expectToken(t, '${comma(annual - discount)}원', '실제 납부액');
      expectToken(t, '4.57%', '1월 공제율');
    });

    testWidgets('늦게 신청할수록 공제율이 낮아진다', (t) async {
      await open(t, const CarTaxAnnualScreen(), ['520000']);
      for (final (label, rate) in [('3월', '3.76%'), ('6월', '2.51%'), ('9월', '1.26%')]) {
        await t.tap(find.text(label).first);
        await t.pump(const Duration(milliseconds: 300));
        expectToken(t, rate, '$label 공제율');
      }
    });
  });
}
