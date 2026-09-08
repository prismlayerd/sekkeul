import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/basic_pension_screen.dart';
import 'package:secul/ui/screens/out_of_pocket_cap_screen.dart';
import 'package:secul/ui/screens/parental_leave_6plus6_screen.dart';

import 'support/screen_probe.dart';

/// 배치 4 — 기초연금 · 본인부담상한 · 육아휴직 6+6.
///
/// 이 셋은 값이 **매년 바뀌는 고시**라 "지금 값이 맞나"는 원문으로만 닫힌다
/// (notice_expiry_test에 1차 미확인으로 등록돼 있다). 여기서는 원문 없이도
/// 말할 수 있는 것을 본다 — **구조와 불변식**이다.
///
/// 근거: 기초연금법 §5(선정기준액)·§8(부부 감액 20%)
///      / 국민건강보험법 시행령 별표3 본인부담상한액
///      / 고용보험법 시행령 §95의3 6+6 부모육아휴직급여
final _re = RegExp(r'\d+(,\d{3})*(만원|원|%)?');

Set<String> tokens(WidgetTester t) => screenTokens(t, _re);

bool shows(WidgetTester t, String s) => tokens(t).contains(s);

/// 1234567 → '1,234,567원' — 화면 표기 그대로.
String won(int v) => '${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}원';

/// `.keepWords`가 어절 사이에 word-joiner(U+2060)를 끼워 넣기 때문에
/// `find.textContaining`으로는 그 문구를 못 찾는다. 조이너를 걷어내고 본다.
bool hasPhrase(WidgetTester t, String phrase) {
  for (final w in t.allWidgets) {
    if (w is Text) {
      final s = (w.data ?? w.textSpan?.toPlainText())?.replaceAll('⁠', '');
      if (s != null && s.contains(phrase)) return true;
    }
  }
  return false;
}

void main() {
  Future<void> open(WidgetTester t, Widget w, List<(int, String)> inputs) =>
      openScreen(t, w, inputs: inputs, height: 4500);

  group('기초연금 (기초연금법 §5·§8)', () {
    testWidgets('소득인정액이 선정기준액 이하면 수급 가능', (t) async {
      // 만 65세 · 소득인정액 150만원 (단독 선정기준액 247만원 이하)
      await open(t, const BasicPensionScreen(), [(0, '65'), (1, '150')]);
      expect(find.text('수급 가능'), findsOneWidget,
          reason: '선정기준액 이하인데 수급 불가로 나온다');
    });

    testWidgets('선정기준액을 넘으면 수급 불가', (t) async {
      await open(t, const BasicPensionScreen(), [(0, '65'), (1, '300')]);
      expect(find.text('수급 불가'), findsOneWidget,
          reason: '선정기준액 초과인데 수급 가능으로 나온다');
    });

    testWidgets('만 65세 미만은 나이 요건으로 걸러진다', (t) async {
      await open(t, const BasicPensionScreen(), [(0, '64'), (1, '100')]);
      expect(find.text('수급 불가'), findsOneWidget,
          reason: '만 65세 미만은 대상이 아니다');
    });

    testWidgets('부부가구 선정기준액은 단독의 160%다', (t) async {
      // 단독 247만 × 1.6 = 395.2만 → 395만
      expect((247 * 1.6).round(), 395);
      // 단독 기준으로는 탈락하는 300만이 부부 기준으로는 통과해야 한다.
      await open(t, const BasicPensionScreen(), [(0, '70'), (1, '300')]);
      expect(find.text('수급 불가'), findsOneWidget);
      await t.tap(find.text('부부가구'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('수급 가능'), findsOneWidget,
          reason: '부부 선정기준액(395만)은 단독(247만)보다 높아야 한다');
    });
  });

  group('본인부담상한 (국민건강보험법 시행령 별표3)', () {
    testWidgets('본인부담금이 상한 이하면 환급이 0이다', (t) async {
      // 기본 분위(6~7) 상한보다 100만 적게 넣으면 환급이 없어야 한다.
      final under = outOfPocketCapTiers[3].$2 - 1000000;
      await open(t, const OutOfPocketCapScreen(), [(0, '$under')]);
      expect(shows(t, '0원'), isTrue, reason: '상한 이하면 환급액이 0원이어야 한다');
      // 왜 0원인지 화면이 말해 줘야 한다 — 숫자만 0이면 고장으로 읽힌다.
      expect(hasPhrase(t, '환급 대상이 아닙니다'), isTrue,
          reason: '상한 이하일 때 이유를 알려주는 문구가 떠야 한다');
    });

    testWidgets('환급액 = 본인부담금 − 상한액', (t) async {
      const paid = 5000000;
      final cap = outOfPocketCapTiers[3].$2; // 기본 선택 분위(6~7)
      await open(t, const OutOfPocketCapScreen(), [(0, '$paid')]);
      expect(shows(t, won(paid - cap)), isTrue, reason: '환급액이 차액과 다르다');
      expect(shows(t, won(cap)), isTrue, reason: '적용 상한액이 안 보인다');
    });

    // 표는 outOfPocketCapTiers 한 벌뿐이다. 여기 다시 적으면 한쪽만 갱신된다.
    final general = [for (final t in outOfPocketCapTiers) t.$2];
    final longTerm = [for (final t in outOfPocketCapTiers) t.$3];

    test('종전 표보다 오르고 요양병원 열이 더 높다', () {
      // 종전 값은 어느 연도와도 맞지 않았다 — 7개 중 3개만 2024년과 같고
      // 나머지는 2024·2025 어느 쪽도 아니었다.
      const old = [870000, 1080000, 1620000, 3030000, 4140000, 4970000, 8080000];
      for (var i = 0; i < 7; i++) {
        expect(general[i], greaterThan(old[i]),
            reason: '$i번째 구간: 고시값이 종전 값보다 커야 한다');
      }
      // 요양병원 특례는 **전 구간**에 있다. 하위 분위에만 있는 게 아니다.
      for (var i = 0; i < 7; i++) {
        expect(longTerm[i], greaterThan(general[i]),
            reason: '$i번째 구간: 요양병원 상한이 일반보다 낮을 수 없다');
      }
    });

    test('분위가 오르면 상한액도 오른다 — 두 열 모두 단조 증가', () {
      for (var i = 1; i < 7; i++) {
        expect(general[i], greaterThan(general[i - 1]),
            reason: '일반 $i번째 분위 상한이 앞 분위보다 낮다');
        expect(longTerm[i], greaterThan(longTerm[i - 1]),
            reason: '요양병원 $i번째 분위 상한이 앞 분위보다 낮다');
      }
    });

    testWidgets('요양병원 120일 초과를 켜면 상한액이 특례값으로 바뀐다', (t) async {
      // 안 물으면 일반 상한으로 계산해 환급액을 크게 부풀린다.
      await open(t, const OutOfPocketCapScreen(), [(0, '5000000')]);
      expect(shows(t, won(outOfPocketCapTiers[3].$2)), isTrue, reason: '기본은 일반 상한');
      // 스크롤 안에 있으므로 먼저 보이게 한 뒤 누른다.
      expect(find.byType(Switch), findsOneWidget, reason: '요양병원 토글이 없다');
      await t.ensureVisible(find.byType(Switch));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.byType(Switch));
      await t.pump(const Duration(milliseconds: 400));
      final special = outOfPocketCapTiers[3].$3;
      expect(shows(t, won(special)), isTrue, reason: '요양병원 특례 상한');
      expect(shows(t, won(5000000 - special)), isTrue, reason: '환급액이 차액과 다르다');
    });
  });

  group('6+6 부모육아휴직급여 (고용보험법 시행령 §95의3)', () {
    // 사다리는 parentalLeave6Plus6Caps 한 벌뿐이다. 시행령 §95의3①1 바목이
    // 첫 **두 달**을 250만원으로 정한다 — 1개월차를 200만원으로 두면 50만원 적다.
    test('상한 사다리가 시행령 바목과 같다', () {
      expect(parentalLeave6Plus6Caps,
          [2500000, 2500000, 3000000, 3500000, 4000000, 4500000]);
      expect(parentalLeave6Plus6Floor, 700000);
    });

    testWidgets('월별 상한이 안내에 그대로 나온다', (t) async {
      await open(t, const ParentalLeave6Plus6Screen(),
          [(0, '4500000'), (1, '3000000')]);
      for (var i = 0; i < parentalLeave6Plus6Caps.length; i++) {
        final man = parentalLeave6Plus6Caps[i] ~/ 10000;
        expect(hasPhrase(t, '$man만원'), isTrue,
            reason: '${i + 1}개월차 상한 $man만원이 안내에 없다');
      }
    });

    testWidgets('통상임금이 상한보다 낮으면 통상임금이 지급된다', (t) async {
      // 부모 B 월 300만 → 앞 세 달은 상한(250/250/300)에 걸리고
      // 4개월차부터는 통상임금 300만이 상한(350만)보다 낮아 300만을 받는다.
      await open(t, const ParentalLeave6Plus6Screen(),
          [(0, '4500000'), (1, '3000000')]);
      const b = 3000000.0;
      var sum = 0.0;
      for (final cap in parentalLeave6Plus6Caps) {
        sum += b < cap ? b : cap;
      }
      expect(sum, 17000000.0, reason: '250+250+300+300+300+300 만원');
      expect(shows(t, '${comma(sum / 10000)}만원'), isTrue,
          reason: '6개월 합계가 상한·통상임금 중 작은 값의 합과 다르다');
    });
  });
}
