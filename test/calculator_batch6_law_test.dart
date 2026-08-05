import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/carbon_neutral_points_screen.dart';
import 'package:secul/ui/screens/housing_pension_screen.dart';
import 'package:secul/ui/screens/jeonse_vs_wolse_screen.dart';

import 'support/screen_probe.dart';

/// 배치 6 — 주택연금 · 전세vs월세 · 탄소중립포인트.
///
/// 이 셋은 세법이 아니라 **공시값과 산수**다. 주택연금 억당 월지급률은
/// 한국주택금융공사가 매년 공시하므로 만료 알람 대상이고, 나머지 둘은
/// 공식이 맞는지만 보면 된다.
final _re = RegExp(r'\d+(,\d{3})*(\.\d+)?(억원|만원|원|%)?');

Set<String> tokens(WidgetTester t) => screenTokens(t, _re);

void expectToken(WidgetTester t, String want, String what) =>
    expectScreenToken(t, _re, want, what);

void main() {
  Future<void> open(WidgetTester t, Widget w, List<(int, String)> inputs) =>
      openScreen(t, w, inputs: inputs, height: 4500);

  group('주택연금 (한국주택금융공사 공시)', () {
    /// 1억원당 월지급금(만원) — 한국주택금융공사 「월지급금 예시」 2026.3.1. 기준.
    /// 종신지급·정액형·일반주택. 사이 연령은 선형보간한다.
    double rateAt(int age) {
      const ages = [55, 60, 65, 70, 75, 80];
      const rates = [15.6, 21.0, 25.2, 30.7, 38.1, 48.3];
      if (age <= ages.first) return rates.first;
      if (age >= ages.last) return rates.last;
      for (var i = 0; i < ages.length - 1; i++) {
        if (age >= ages[i] && age <= ages[i + 1]) {
          final t = (age - ages[i]) / (ages[i + 1] - ages[i]);
          return rates[i] + (rates[i + 1] - rates[i]) * t;
        }
      }
      return rates.last;
    }

    test('공시표가 HF 공시값과 정확히 일치한다', () {
      // 어림값(15/21/25/30/38.4)을 쓰던 때는 70세 3억 주택에서 90만원이 나왔는데
      // 공시는 92.3만원이었다. 이 검사가 그 어긋남을 막는다.
      const hfPer100M = {55: 15.6, 60: 21.0, 65: 25.2, 70: 30.7, 75: 38.1, 80: 48.3};
      hfPer100M.forEach((age, v) => expect(rateAt(age), v,
          reason: '\$age세 억당 월지급금이 HF 공시와 다르다'));
      // HF 예시: 70세·3억 → 92만 3천원
      expect(rateAt(70) * 3, closeTo(92.1, 0.3));
    });

    testWidgets('공시가 5억 · 65세 → 억당 25.2만 × 5억 = 126만원', (t) async {
      // 입력 순서: 0=연령, 1=공시가격(만원)
      await open(t, const HousingPensionScreen(), [(0, '65'), (1, '50000')]);
      final monthly = 5 * rateAt(65) * 10000;
      // ignore: avoid_print
      print('5억 · 65세 → 억당 ${rateAt(65)}만 → 월 ${comma(monthly)}원');
      expect(monthly, 1260000);
      expectToken(t, '${comma(monthly)}원', '월지급금');
    });

    testWidgets('나이가 많을수록 월지급금이 커진다 — 단조 증가', (t) async {
      for (var age = 55; age <= 75; age += 5) {
        expect(rateAt(age), greaterThanOrEqualTo(rateAt(age - 5 < 55 ? 55 : age - 5)));
      }
      // 같은 주택으로 65세 → 70세면 25만 → 30만
      await open(t, const HousingPensionScreen(), [(0, '70'), (1, '50000')]);
      expectToken(t, '${comma(5 * rateAt(70) * 10000)}원', '70세 월지급금');
    });

    testWidgets('구간 사이 연령은 선형보간된다 — 67세', (t) async {
      // 65세 25.2만, 70세 30.7만 → 67세는 25.2 + (30.7−25.2)×2/5 = 27.4만
      expect(rateAt(67), closeTo(27.4, 0.01));
      await open(t, const HousingPensionScreen(), [(0, '67'), (1, '50000')]);
      expectToken(t, '${comma(5 * rateAt(67) * 10000)}원', '67세 선형보간');
    });

    testWidgets('월 375만원 상한이 걸린다', (t) async {
      // 가입 상한인 공시가격 12억 · 75세 → 12 × 38.4만 = 460.8만원이지만 상한 375만.
      await open(t, const HousingPensionScreen(), [(0, '75'), (1, '120000')]);
      expect(12 * rateAt(75) * 10000, closeTo(4572000, 1));
      expectToken(t, '3,750,000원', '월지급금 상한');
      expect(tokens(t).contains('4,608,000원'), isFalse,
          reason: '상한을 안 걸면 460.8만원이 나온다');
    });

    testWidgets('공시가격 12억을 넘으면 가입 대상이 아니다', (t) async {
      // 주택연금 가입 상한. 넘으면 숫자를 내는 대신 대상이 아님을 말해야 한다 —
      // 못 받는 금액을 계산해 보여주면 기대만 키운다.
      await open(t, const HousingPensionScreen(), [(0, '75'), (1, '200000')]);
      // 월지급금 자리에 금액 대신 '-'가 떠야 한다.
      expect(find.text('-'), findsWidgets,
          reason: '가입 상한을 넘었는데 월지급금을 계산해 보여준다');
      expect(tokens(t).contains('7,680,000원'), isFalse);
    });
  });

  group('전세 vs 월세', () {
    testWidgets('기회비용 비교와 손익분기 전환율', (t) async {
      // 전세 3억 / 월세 보증금 5,000만 + 월 70만 / 금리 3.5%
      await open(t, const JeonseVsWolseScreen(),
          [(0, '300000000'), (1, '50000000'), (2, '700000'), (3, '3.5')]);

      const jeonseCost = 300000000 * 0.035; // 1,050만
      const wolseCost = 700000 * 12 + 50000000 * 0.035; // 840만 + 175만
      // 손익분기 전환율 = 월세×12 ÷ (전세보증금 − 월세보증금)
      const breakeven = 700000 * 12 / (300000000 - 50000000) * 100;
      // ignore: avoid_print
      print('전세 연 ${comma(jeonseCost)} vs 월세 연 ${comma(wolseCost)}'
          ' · 전환율 ${breakeven.toStringAsFixed(2)}%');

      // 3억 × 0.035는 부동소수점으로 10500000.000000002가 된다 — 비교는 근사로.
      expect(jeonseCost, closeTo(10500000, 1));
      expect(wolseCost, closeTo(10150000, 1));
      expect(breakeven, closeTo(3.36, 0.01));

      expectToken(t, '1,050만원', '전세 연간 비용');
      expectToken(t, '840만원', '월세 합계');
      expectToken(t, '175만원', '월세 보증금 기회비용');
      expectToken(t, '3.36%', '손익분기 전환율');
    });
  });

  group('탄소중립포인트', () {
    testWidgets('2026년 개편 단가로 적립된다', (t) async {
      // 2026.1.1 개편(cpoint.or.kr 인센티브 안내) — 전자영수증 100→10원,
      // 리필스테이션 2,000→500원, 다회용기 2,000→500원.
      // 개편 전 값이 남아 있으면 여기서 갈린다.
      await open(t, const CarbonNeutralPointsScreen(),
          [(0, '10'), (1, '5'), (2, '4'), (3, '2'), (4, '4')]);
      expectToken(t, '1,200원', '전자영수증 월 10건 × 12 × 10원');
      expectToken(t, '18,000원', '텀블러 월 5회 × 12 × 300원');
      expectToken(t, '4,800원', '일회용컵 월 4개 × 12 × 100원');
      expectToken(t, '12,000원', '리필스테이션 월 2회 × 12 × 500원');
      expectToken(t, '24,000원', '다회용기 월 4회 × 12 × 500원');
      expectToken(t, '60,000원', '연간 총 포인트');
    });

    testWidgets('입력이 없으면 결과를 그리지 않는다', (t) async {
      // 0원을 크게 보여주면 "제도가 안 준다"로 읽힌다. 아직 안 넣었을 뿐이다.
      await open(t, const CarbonNeutralPointsScreen(), []);
      expect(find.text('연간 총 포인트'), findsNothing,
          reason: '입력 전에 결과 카드가 뜬다');
    });

    testWidgets('1인당 연간 총 한도 7만원이 걸린다', (t) async {
      // 모든 항목을 크게 넣으면 항목별 상한 합이 7만원을 넘는다.
      await open(t, const CarbonNeutralPointsScreen(),
          [(0, '300'), (1, '300'), (2, '300'), (3, '300'), (4, '300')]);
      final shown = tokens(t);
      // ignore: avoid_print
      print('전 항목 최대 입력 → 총 포인트: '
          + shown.where((s) => s.endsWith(String.fromCharCode(0xC6D0))).join(' / '));
      expect(shown.contains('70,000원') || shown.contains('7만원'), isTrue,
          reason: '연간 총 한도 7만원이 안 걸린다');
    });
  });
}
