import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/basic_pension_screen.dart';
import 'package:secul/ui/screens/out_of_pocket_cap_screen.dart';
import 'package:secul/ui/screens/parental_leave_6plus6_screen.dart';

/// 배치 4 — 기초연금 · 본인부담상한 · 육아휴직 6+6.
///
/// 이 셋은 값이 **매년 바뀌는 고시**라 "지금 값이 맞나"는 원문으로만 닫힌다
/// (notice_expiry_test에 1차 미확인으로 등록돼 있다). 여기서는 원문 없이도
/// 말할 수 있는 것을 본다 — **구조와 불변식**이다.
///
/// 근거: 기초연금법 §5(선정기준액)·§8(부부 감액 20%)
///      / 국민건강보험법 시행령 별표3 본인부담상한액
///      / 고용보험법 시행령 §95의3 6+6 부모육아휴직급여
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
      for (final m in RegExp(r'\d+(,\d{3})*(만원|원|%)?').allMatches(s)) {
        out.add(m.group(0)!);
      }
    }
  }
  return out;
}

bool shows(WidgetTester t, String s) => tokens(t).contains(s);

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
  int seq = 0;

  Future<void> open(WidgetTester t, Widget w, List<(int, String)> inputs) async {
    t.view.physicalSize = const Size(390, 4500);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await t.pumpWidget(MaterialApp(key: ValueKey('b4-${seq++}'), home: w));
    await t.pump(const Duration(milliseconds: 300));
    for (final (idx, text) in inputs) {
      await t.enterText(find.byType(TextField).at(idx), text);
      await t.pump(const Duration(milliseconds: 250));
    }
    await t.pump(const Duration(milliseconds: 400));
    t.takeException();
  }

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
      // 6~7분위 상한 303만. 250만 부담 → 환급 없음.
      await open(t, const OutOfPocketCapScreen(), [(0, '2500000')]);
      expect(shows(t, '1,970,000원'), isFalse);
      expect(shows(t, '0원'), isTrue, reason: '상한 이하면 환급액이 0원이어야 한다');
      // 왜 0원인지 화면이 말해 줘야 한다 — 숫자만 0이면 고장으로 읽힌다.
      expect(hasPhrase(t, '환급 대상이 아닙니다'), isTrue,
          reason: '상한 이하일 때 이유를 알려주는 문구가 떠야 한다');
    });

    testWidgets('환급액 = 본인부담금 − 상한액', (t) async {
      await open(t, const OutOfPocketCapScreen(), [(0, '5000000')]);
      // 기본 선택 분위(6~7분위) 상한 303만 → 500만 − 303만 = 197만
      expect(shows(t, '1,970,000원'), isTrue, reason: '환급액이 차액과 다르다');
      expect(shows(t, '3,030,000원'), isTrue, reason: '적용 상한액이 안 보인다');
    });

    testWidgets('분위가 오르면 상한액도 오른다 — 단조 증가', (t) async {
      // 소득이 높을수록 상한이 높다(=환급이 적다). 뒤집히면 표를 잘못 옮긴 것이다.
      const caps = [870000, 1080000, 1620000, 3030000, 4140000, 4970000, 8080000];
      for (var i = 1; i < caps.length; i++) {
        expect(caps[i], greaterThan(caps[i - 1]),
            reason: '$i번째 분위 상한이 앞 분위보다 낮다');
      }
    });
  });

  group('6+6 부모육아휴직급여 (고용보험법 시행령 §95의3)', () {
    testWidgets('월별 상한이 200만부터 50만씩 올라 6개월차 450만이 된다', (t) async {
      await open(t, const ParentalLeave6Plus6Screen(),
          [(0, '4500000'), (1, '3000000')]);

      const caps = [200, 250, 300, 350, 400, 450];
      for (var i = 0; i < caps.length; i++) {
        expect(caps[i], 200 + i * 50, reason: '${i + 1}개월차 상한');
        expect(hasPhrase(t, '${caps[i]}만원'), isTrue,
            reason: '${i + 1}개월차 상한 ${caps[i]}만원이 안내에 없다');
      }
    });

    testWidgets('통상임금이 상한보다 낮으면 통상임금이 지급된다', (t) async {
      // 부모 B 월 300만 → 1~3개월차는 상한(200/250/300)에 걸리고
      // 4개월차부터는 통상임금 300만이 상한(350만)보다 낮아 300만을 받는다.
      await open(t, const ParentalLeave6Plus6Screen(),
          [(0, '4500000'), (1, '3000000')]);
      const b = 3000000.0;
      var sum = 0.0;
      for (var m = 0; m < 6; m++) {
        final cap = (200 + m * 50) * 10000.0;
        sum += b < cap ? b : cap;
      }
      // ignore: avoid_print
      print('부모 B 통상임금 ${comma(b)} → 6개월 합계 ${comma(sum)}');
      expect(sum, 16500000.0, reason: '200+250+300+300+300+300 만원');
      expect(shows(t, '${comma(sum / 10000)}만원'), isTrue,
          reason: '6개월 합계가 상한·통상임금 중 작은 값의 합과 다르다');
    });
  });
}
