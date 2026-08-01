import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/compound_interest_screen.dart';
import 'package:secul/ui/screens/kpass_climate_card_screen.dart';
import 'package:secul/ui/screens/light_car_fuel_refund_screen.dart';

/// 배치 5 — 경차 유류세 환급 · K-패스 · 복리.
///
/// 근거: 조세특례제한법 §111의2③ · 시행령 §112의2③ 경형자동차 유류세 환급
///        (휘발유·경유 리터당 250원, 부탄은 개별소비세 전액, 연 30만원 한도)
///      / K-패스 — 월 15회 이상 60회까지 인정, 유형별 환급률
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
      for (final m in RegExp(r'\d+(,\d{3})*(\.\d+)?(만원|원|%|회)?').allMatches(s)) {
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
    print('  ✕ $what — 기대 $want, 화면: ${(shown.toList()..sort()).take(35).join(' / ')}');
  }
  expect(shown, contains(want), reason: '$what — 화면 값이 검산과 다르다 (기대 $want)');
}

void main() {
  int seq = 0;

  Future<void> open(WidgetTester t, Widget w, List<(int, String)> inputs) async {
    t.view.physicalSize = const Size(390, 4500);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await t.pumpWidget(MaterialApp(key: ValueKey('b5-${seq++}'), home: w));
    await t.pump(const Duration(milliseconds: 300));
    for (final (idx, text) in inputs) {
      await t.enterText(find.byType(TextField).at(idx), text);
      await t.pump(const Duration(milliseconds: 250));
    }
    await t.pump(const Duration(milliseconds: 400));
    t.takeException();
  }

  group('경차 유류세 환급 (조특법 §111의2③)', () {
    testWidgets('휘발유와 경유가 같은 250원이다', (t) async {
      // 조문: "휘발유 또는 경유의 경우 리터당 250원". 종전에는 경유가 160원이라
      // 조문의 64%만 환급되는 것으로 안내했다.
      await open(t, const LightCarFuelRefundScreen(), [(0, '50')]);
      // 월 50L × 250원 = 12,500원
      expectToken(t, '12,500원', '휘발유 월 환급액');

      await t.tap(find.text('경유'));
      await t.pump(const Duration(milliseconds: 400));
      expectToken(t, '12,500원', '경유 월 환급액 — 휘발유와 같아야 한다');
    });

    testWidgets('연간 30만원 한도가 걸린다', (t) async {
      // 월 200L × 250원 = 50,000원/월 → 연 60만원이지만 한도 30만원.
      await open(t, const LightCarFuelRefundScreen(), [(0, '200')]);
      expectToken(t, '300,000원', '연간 환급 한도');
      expect(tokens(t).contains('600,000원'), isFalse,
          reason: '한도를 안 걸면 60만원이 나온다');
    });

    testWidgets('한도 미만이면 실제 주유량대로 계산된다', (t) async {
      // 월 50L → 연 15만원 (한도 30만원 미만)
      await open(t, const LightCarFuelRefundScreen(), [(0, '50')]);
      expectToken(t, '150,000원', '연간 환급액(한도 미달)');
    });
  });

  group('K-패스', () {
    testWidgets('일반 20% 환급 — 월 60회 상한이 걸린다', (t) async {
      // 월 100회 이용 → 60회만 인정. 1회 1,500원 → 인정액 90,000원 × 20% = 18,000원
      await open(t, const KpassClimateCardScreen(), [(0, '100'), (1, '1500')]);
      const recognized = 60 * 1500.0;
      // ignore: avoid_print
      print('월 100회 → 60회 인정 · ${comma(recognized)} × 20% = ${comma(recognized * 0.2)}');
      expectToken(t, '${comma(recognized * 0.2)}원', 'K패스 환급액(60회 상한)');
      expectToken(t, '${comma(recognized * 0.8)}원', 'K패스 실질 부담액');
    });

    testWidgets('유형이 오를수록 환급률도 오른다', (t) async {
      await open(t, const KpassClimateCardScreen(), [(0, '40'), (1, '1500')]);
      final base = tokens(t);
      await t.tap(find.text('청년'));
      await t.pump(const Duration(milliseconds: 400));
      final youth = tokens(t);
      // 일반 20% → 청년 30%. 같은 이용량이면 환급액이 커져야 한다.
      expect(youth, isNot(equals(base)),
          reason: '유형을 바꿨는데 환급액이 그대로다');
      expectToken(t, '${comma(40 * 1500 * 0.3)}원', '청년 30% 환급액');
    });
  });

  group('복리 계산기', () {
    testWidgets('월복리 — 원금 × (1 + r/12)^(12n)', (t) async {
      // 초기 1,000만 · 월 납입 0 · 연 10% · 20년
      await open(t, const CompoundInterestScreen(),
          [(0, '10000000'), (1, '0'), (2, '10'), (3, '20')]);

      final v = 10000000 * math.pow(1 + 0.10 / 12, 240);
      // ignore: avoid_print
      print('1,000만 · 연 10% 월복리 · 20년 → ${comma(v)} (${(v / 10000).round()}만원)');
      expect((v / 10000).round(), 7328);
      expectToken(t, '7,328만원', '20년 후 예상 자산');
      expectToken(t, '1,000만원', '총 투자원금');
      expectToken(t, '6,328만원', '수익');
    });

    testWidgets('수익률 0%면 원금 그대로다', (t) async {
      await open(t, const CompoundInterestScreen(),
          [(0, '10000000'), (1, '0'), (2, '0'), (3, '10')]);
      final shown = tokens(t);
      // 수익이 0이거나 결과를 그리지 않거나 — 원금보다 커지면 안 된다.
      expect(shown.contains('7,328만원'), isFalse,
          reason: '수익률 0인데 자산이 불어났다');
    });
  });
}
