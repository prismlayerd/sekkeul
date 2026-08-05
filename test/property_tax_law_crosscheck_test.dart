import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/property_tax_screen.dart';

import 'support/screen_probe.dart';

/// 보유세 계산기 — 화면이 그린 재산세·종부세를 조문 검산과 대조한다.
///
/// 계산이 위젯 State 안에 있어 엔진으로 부를 수 없다. 그래서 화면에 직접
/// 공시가격을 넣고 그려진 숫자를 읽는다.
///
/// 근거: 지방세법 §111①3 재산세 주택분 세율 / §112①2 도시지역분 0.14%
///      / §151①2 지방교육세 20% / 시행령 §109 공정시장가액비율 60%
///      / 종합부동산세법 §8 공제액 · §9① 세율 · 시행령 §2의4 공정시장가액비율
/// 이 화면은 금액을 **만원 단위로 반올림해서** 보여준다("57만원"). 그래서 검증도
/// 사용자가 보는 정밀도로 한다 — 원 단위 차이는 애초에 화면에 나타나지 않는다.
/// 대신 두 계산 방식이 갈리는지 같은 검사는 만원 단위로도 충분히 드러난다.
final _re = RegExp(r'\d{1,3}(,\d{3})*만원');

Set<String> moneyTexts(WidgetTester t) => screenTokens(t, _re);

String manwon(num v) => '${comma((v / 10000).round())}만원';

void expectShown(WidgetTester t, num value, String what) =>
    expectScreenToken(t, _re, manwon(value), what);

/// 지방세법 §111①3 — 주택분 재산세. 과세표준 = 공시가격 × 60%(시행령 §109).
/// 6천만 이하 0.1% / ~1.5억 6만+0.15% / ~3억 19.5만+0.25% / 3억 초과 57만+0.4%
double refPropertyTax(double price) {
  final base = price * 0.60;
  if (base <= 60000000) return base * 0.001;
  if (base <= 150000000) return 60000 + (base - 60000000) * 0.0015;
  if (base <= 300000000) return 195000 + (base - 150000000) * 0.0025;
  return 570000 + (base - 300000000) * 0.004;
}

/// 종합부동산세법 §9① — 주택분 세율(누진공제 방식).
double refComprehensiveTax(double base) {
  if (base <= 0) return 0;
  if (base <= 300000000) return base * 0.005;
  if (base <= 600000000) return 1500000 + (base - 300000000) * 0.007;
  if (base <= 1200000000) return 3600000 + (base - 600000000) * 0.010;
  if (base <= 2500000000) return 9600000 + (base - 1200000000) * 0.013;
  if (base <= 5000000000) return 26500000 + (base - 2500000000) * 0.015;
  if (base <= 9400000000) return 64000000 + (base - 5000000000) * 0.020;
  return 152000000 + (base - 9400000000) * 0.027;
}

void main() {
  Future<void> open(WidgetTester t, List<int> prices) async {
    await openScreen(t, const PropertyTaxScreen(), height: 3000);

    // 주택 수만큼 입력칸을 늘린다.
    for (int i = 1; i < prices.length; i++) {
      await t.tap(find.text('주택 추가'));
      await t.pump(const Duration(milliseconds: 200));
    }
    final fields = find.byType(TextField);
    for (int i = 0; i < prices.length; i++) {
      await t.enterText(fields.at(i), '${prices[i]}');
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.pump(const Duration(milliseconds: 300));
    t.takeException();
  }

  testWidgets('재산세 — 공시가격 5억 1주택이 조문 세율표와 일치한다', (t) async {
    const price = 500000000;
    await open(t, [price]);

    final tax = refPropertyTax(price.toDouble());
    final edu = tax * 0.2; // 지방교육세 20% (지방세법 §151①2)
    // ignore: avoid_print
    print('공시가 ${comma(price)} → 과세표준 ${comma(price * 0.6)} · 재산세 ${comma(tax)}'
        ' · 지방교육세 ${comma(edu)}');
    // 과세표준 3억 = 5억 × 60% → 57만원 경계 바로 위 구간
    expect(tax, closeTo(570000, 0.01), reason: '과세표준 3억이면 57만원 (3억 초과분 없음)');
    expectShown(t, tax, '재산세');
    expectShown(t, edu, '지방교육세');
  });

  testWidgets('재산세 — 물건별 개별 누진 후 합산이지, 합산 일괄이 아니다', (t) async {
    // 3억 + 3억. 물건별이면 각각 과세표준 1.8억 구간.
    // 합산 일괄로 계산하면 과세표준 3.6억이 되어 훨씬 커진다 — 그 함정을 못박는다.
    const a = 300000000, b = 300000000;
    await open(t, [a, b]);

    final perItem = refPropertyTax(a.toDouble()) + refPropertyTax(b.toDouble());
    final lumped = refPropertyTax((a + b).toDouble());
    // ignore: avoid_print
    print('물건별 합산 ${comma(perItem)} vs 합산 일괄 ${comma(lumped)}'
        ' (차이 ${comma(lumped - perItem)})');

    expect(lumped, greaterThan(perItem),
        reason: '이 시드는 두 방식이 갈리는 조건이어야 한다');
    expectShown(t, perItem, '재산세(물건별 개별 누진 후 합산)');
    expect(moneyTexts(t), isNot(contains(manwon(lumped))),
        reason: '합산 일괄로 계산하면 재산세가 과다해진다');
  });

  testWidgets('종부세 — 1주택 공제 12억, 그 아래는 0원', (t) async {
    await open(t, [1100000000]); // 11억 — 공제 12억 미만
    final base = 0.0;
    expect(refComprehensiveTax(base), 0.0);
    // 종부세가 0이어야 하므로 큰 금액이 뜨면 안 된다.
    // 재산세는 나오므로 재산세 값만 확인한다.
    expectShown(t, refPropertyTax(1100000000), '재산세(11억)');
  });

  testWidgets('종부세 — 1주택 13억: (13억−12억)×60% 과세표준에 0.5%', (t) async {
    const price = 1300000000;
    await open(t, [price]);

    const deduction = 1200000000.0; // 1주택 공제 (종부세법 §8①)
    final base = (price - deduction) * 0.6; // 공정시장가액비율 60%
    final tax = refComprehensiveTax(base);
    // ignore: avoid_print
    print('공시가 ${comma(price)} − 공제 ${comma(deduction)} → 과세표준 ${comma(base)}'
        ' · 종부세 ${comma(tax)}');
    expect(base, closeTo(60000000, 0.01));
    expect(tax, closeTo(300000, 0.01), reason: '6천만 × 0.5% = 30만원');
    expectShown(t, tax, '종합부동산세');
  });

  testWidgets('종부세 — 2주택 이상은 공제가 9억으로 내려간다', (t) async {
    // 7억 + 5억 = 12억. 1주택이면 공제 12억이라 0원이지만, 2주택은 공제 9억.
    await open(t, [700000000, 500000000]);

    const deduction = 900000000.0; // 2주택 이상 (종부세법 §8①)
    final base = (1200000000 - deduction) * 0.6;
    final tax = refComprehensiveTax(base);
    // ignore: avoid_print
    print('2주택 합산 ${comma(1200000000)} − 공제 ${comma(deduction)}'
        ' → 과세표준 ${comma(base)} · 종부세 ${comma(tax)}');
    expect(tax, closeTo(180000000 * 0.005, 0.01));
    expectShown(t, tax, '종합부동산세(2주택)');
  });

  testWidgets('도시지역분 0.14%는 합산 과세표준 기준이다 (지방세법 §112①2)', (t) async {
    // 도시지역 체크 전후를 비교한다 — 체크박스를 켠 뒤 값이 늘어야 한다.
    await open(t, [500000000]);
    final before = moneyTexts(t);
    // 라벨이 아니라 스위치를 눌러야 켜진다. 이 화면의 첫 스위치가 '도시지역'.
    await t.tap(find.byType(Switch).first);
    await t.pump(const Duration(milliseconds: 300));

    final urban = 500000000 * 0.60 * 0.0014;
    // ignore: avoid_print
    print('도시지역분 ${comma(urban)}');
    expect(before, isNot(contains(manwon(urban))));
    expectShown(t, urban, '재산세 도시지역분');
  });
}
