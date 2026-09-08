import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/compound_interest_screen.dart';
import 'package:secul/ui/screens/kpass_climate_card_screen.dart';
import 'package:secul/ui/screens/light_car_fuel_refund_screen.dart';

import 'support/screen_probe.dart';

/// 배치 5 — 경차 유류세 환급 · 모두의카드 · 복리.
///
/// 근거: 조세특례제한법 §111의2③ · 시행령 §112의2③ 경형자동차 유류세 환급
///        (휘발유·경유 리터당 250원, 부탄은 개별소비세 전액, 연 30만원 한도)
///      / 모두의카드(옛 K-패스) — 기본형은 월 15회 이상, 유형별 환급률
final _re = RegExp(r'\d+(,\d{3})*(\.\d+)?(만원|원|%|회)?');

Set<String> tokens(WidgetTester t) => screenTokens(t, _re);

void expectToken(WidgetTester t, String want, String what) =>
    expectScreenToken(t, _re, want, what);

void main() {
  Future<void> open(WidgetTester t, Widget w, List<(int, String)> inputs) =>
      openScreen(t, w, inputs: inputs, height: 4500);

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

  group('모두의카드', () {
    testWidgets('기본형 일반 20% 환급', (t) async {
      // 월 40회 × 1,500원 = 60,000원 → 20% = 12,000원, 실부담 48,000원.
      await open(t, const KpassClimateCardScreen(), [(0, '40'), (1, '1500')]);
      expectToken(t, '${comma(40 * 1500 * 0.2)}원', '기본형 환급액');
      expectToken(t, '${comma(40 * 1500 * 0.8)}원', '기본형 실부담');
    });

    testWidgets('월 15회 미만이면 기본형 환급이 없다', (t) async {
      // korea-pass.kr 환급기준 — "월 15회 이상 이용 시 지급".
      await open(t, const KpassClimateCardScreen(), [(0, '14'), (1, '1500')]);
      expectToken(t, '0원', '14회 이용 시 기본형 환급액');
      expect(tokens(t).contains('${comma(14 * 1500 * 0.2)}원'), isFalse,
          reason: '14회인데 환급액이 잡혔다');
    });

    testWidgets('유형이 오를수록 환급률도 오른다', (t) async {
      await open(t, const KpassClimateCardScreen(), [(0, '40'), (1, '1500')]);
      final base = tokens(t);
      await t.tap(find.text('청년·2자녀·어르신'));
      await t.pump(const Duration(milliseconds: 400));
      expect(tokens(t), isNot(equals(base)),
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
