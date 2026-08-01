import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/year_end_tax_screen.dart';

import 'support/tax_law_reference.dart';

/// **연말정산 화면 — 공제 내역표 전체를 조문과 대조한다.**
///
/// 이 화면은 사용자가 직접 타이핑해야 값이 나와서, 다른 화면을 훑던 값 대조가
/// 닿지 않았다. 그런데 여기는 총급여부터 추가납부까지 **계산 사슬 전체**를
/// 한 화면에 늘어놓는다 — 중간 한 칸만 틀려도 아래가 전부 어긋나므로,
/// 앱에서 값 검증 밀도가 가장 높은 자리다.
///
/// 기대값은 `tax_law_reference.dart`에서 온다. 엔진 상수를 빌려오지 않는다 —
/// 빌려오면 양쪽이 같이 틀린다.
void main() {
  /// `.keepWords`가 U+2060(word joiner)을 끼워 넣어서 그냥 비교하면 안 맞는다.
  String plain(String s) => s.replaceAll('⁠', '');

  /// 화면의 모든 Text를 훑어 라벨 다음에 오는 금액을 집는다.
  /// 표가 라벨/금액 두 Text를 나란히 그리므로 순서로 짝을 짓는다.
  Map<String, String> readRows(WidgetTester t) {
    final texts = <String>[
      for (final w in t.allWidgets)
        if (w is Text)
          plain((w.data ?? w.textSpan?.toPlainText() ?? '').trim()),
    ];
    final rows = <String, String>{};
    for (var i = 0; i < texts.length - 1; i++) {
      if (texts[i].isNotEmpty && RegExp(r'^-?[\d,]+원?$').hasMatch(texts[i + 1])) {
        rows.putIfAbsent(texts[i], () => texts[i + 1]);
      }
    }
    return rows;
  }

  int won(String s) => int.parse(s.replaceAll(RegExp(r'[^\d]'), ''));

  setUp(() async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
  });

  testWidgets('공제 내역 11행이 전부 조문값과 일치한다', (t) async {
    t.view.physicalSize = const Size(390, 6000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);

    const gross = 50000000.0;
    const credit = 12000000.0, debit = 6000000.0, prepaid = 1500000.0;
    const dependents = 1; // 부양가족 1명 → 인적공제는 본인 포함 2명

    await dbService.saveProfile({
      'user_type': '직장인',
      'gross_income': gross,
      'dependents': dependents,
    });

    await t.pumpWidget(
        const MaterialApp(home: YearEndTaxScreen(userType: '직장인')));
    await t.pump(const Duration(milliseconds: 400));

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(4), reason: '입력칸 구성이 바뀌면 이 대조가 헛돈다');
    for (final (i, v) in [gross, credit, debit, prepaid].indexed) {
      await t.enterText(fields.at(i), v.toInt().toString());
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.tap(find.text('연말정산 진단하기'));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }

    final rows = readRows(t);

    // ── 조문에서 기대값을 세운다 ─────────────────────────────────
    // 소법 §47① 근로소득공제
    final labor = refLaborDeduction(gross);
    // 소법 §50① 기본공제 — 본인 + 부양가족, 1명당 150만
    const personal = 1500000.0 * (1 + dependents);
    // 국민연금법·국민건강보험법·고용보험법 — 근로자 부담분 연간
    final insurance = refAnnualInsurance(gross / 12).total;
    // 조특법 §126의2 신용카드등 소득공제
    final card = refCardDeduction(
        gross: gross, credit: credit, debitCash: debit);
    final base = gross - labor - personal - insurance - card;
    // 소법 §55① 기본세율
    final calculated = refProgressiveTax(base);
    // 소법 §59 근로소득세액공제
    final laborCredit = refLaborTaxCredit(
        calculatedTax: calculated, gross: gross);
    // 국고금관리법 §47 — 10원 미만 절사
    final decided = trunc10(calculated - laborCredit);

    void row(String label, num expected) {
      expect(rows.containsKey(label), isTrue,
          reason: '"$label" 행이 화면에 없다. 실제 행: ${rows.keys.take(20)}');
      expect(won(rows[label]!), expected.round(),
          reason: '"$label" — 조문 기대 ${expected.round()}');
    }

    row('총급여', gross);
    row('근로소득공제', labor);
    row('인적공제 (본인 포함 ${1 + dependents}인)', personal);
    row('4대보험 소득공제', insurance);
    row('신용카드 소득공제', card);
    row('과세표준', base);
    row('산출세액', calculated);
    row('근로소득세액공제', laborCredit);
    row('결정세액', decided);
    row('기납부세액', prepaid);
    row('추가 납부', decided - prepaid);
  });

  /// 값이 맞아도 라벨이 틀리면 사용자는 틀린 걸 읽는다.
  ///
  /// 실제로 그랬다: `인적공제 (1인)`인데 금액은 300만원(=150만 × 본인 포함 2명)이었다.
  /// 사용자는 1인당 300만원으로 읽고, 부양가족을 하나 더 넣으면 600만원을 기대한다.
  testWidgets('인적공제 라벨의 인원수가 실제 공제액과 맞는다', (t) async {
    t.view.physicalSize = const Size(390, 6000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);

    for (final deps in [0, 2]) {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
      await dbService.saveProfile({
        'user_type': '직장인',
        'gross_income': 50000000.0,
        'dependents': deps,
      });

      await t.pumpWidget(MaterialApp(
        // 키를 안 주면 State가 재사용돼 initState가 다시 안 돈다.
        home: YearEndTaxScreen(key: ValueKey(deps), userType: '직장인'),
      ));
      await t.pump(const Duration(milliseconds: 400));

      final fields = find.byType(TextField);
      for (final (i, v) in ['50000000', '0', '0', '0'].indexed) {
        await t.enterText(fields.at(i), v);
        await t.pump(const Duration(milliseconds: 200));
      }
      await t.tap(find.text('연말정산 진단하기'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }

      final rows = readRows(t);
      final label = rows.keys.firstWhere((k) => k.startsWith('인적공제'),
          orElse: () => '');
      expect(label, isNotEmpty, reason: '인적공제 행을 못 찾았다');

      final stated = int.parse(RegExp(r'(\d+)인').firstMatch(label)!.group(1)!);
      final amount = won(rows[label]!);
      expect(stated, 1 + deps,
          reason: '부양가족 $deps명 → 본인 포함 ${1 + deps}인이어야 한다');
      expect(amount, stated * 1500000,
          reason: '"$label"인데 금액은 $amount원 — 라벨의 인원수와 공제액이 어긋난다');
    }
  });
}
