import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/ui/screens/tax_annual_report_screen.dart';

import 'support/tax_law_reference.dart';

/// **홈택스 가이드 — 공제 내역표 전체를 조문과 대조한다.**
///
/// 총급여부터 결정세액까지 **계산 사슬 전체**를 한 화면에 늘어놓는 자리라,
/// 중간 한 칸만 틀려도 아래가 전부 어긋난다 — 앱에서 값 검증 밀도가 가장 높다.
/// 게다가 이 화면의 숫자는 사용자가 그대로 홈택스에 옮겨 적는다.
///
/// 원래 「연말정산 진단」 화면을 대상으로 하던 테스트다. 그 화면을 지우면서
/// (하는 일이 전부 홈 02·04와 겹쳤다) 사슬이 남아 있는 이 화면으로 옮겼다.
/// 옮기다 인적공제에서 본인이 빠진 것을 찾았다.
///
/// 기대값은 `tax_law_reference.dart`에서 온다. 엔진 상수를 빌려오지 않는다 —
/// 빌려오면 양쪽이 같이 틀린다.
void main() {
  /// `.keepWords`가 U+2060(word joiner)을 끼워 넣어서 그냥 비교하면 안 맞는다.
  String plain(String s) => s.replaceAll('⁠', '');

  /// 화면의 모든 Text를 훑어 라벨 뒤에 오는 첫 금액을 집는다.
  ///
  /// 행이 「라벨 · 설명 · 금액」 세 조각으로 그려지는 자리가 있어서, 바로
  /// 다음 하나만 보면 설명에 걸려 못 찾는다. 두 칸까지 본다.
  Map<String, String> readRows(WidgetTester t) {
    final texts = <String>[
      for (final w in t.allWidgets)
        if (w is Text)
          plain((w.data ?? w.textSpan?.toPlainText() ?? '').trim()),
    ];
    final money = RegExp(r'^-?[\d,]+원?$');
    final rows = <String, String>{};
    for (var i = 0; i < texts.length - 1; i++) {
      if (texts[i].isEmpty || money.hasMatch(texts[i])) continue;
      for (var j = i + 1; j <= i + 2 && j < texts.length; j++) {
        if (money.hasMatch(texts[j])) {
          rows.putIfAbsent(texts[i], () => texts[j]);
          break;
        }
      }
    }
    return rows;
  }

  int won(String s) => int.parse(s.replaceAll(RegExp(r'[^\d]'), ''));

  setUp(() async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
  });

  testWidgets('공제 내역 8행이 전부 조문값과 일치한다', (t) async {
    t.view.physicalSize = const Size(390, 6000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);

    const gross = 50000000.0;
    const credit = 12000000.0, debit = 6000000.0;
    const dependents = 1; // 부양가족 1명 → 인적공제는 본인 포함 2명

    await dbService.saveProfile({
      'user_type': '직장인',
      'gross_income': gross,
      'dependents': dependents,
    });
    // 카드 사용액은 타이핑이 아니라 가계부에서 온다(YearSnapshot). 화면 구성이
    // 바뀌어도 안 흔들리고, 실제 사용자가 겪는 경로와 같다.
    final y = DateTime.now().year;
    for (final (id, amount, pay) in [
      ('c', credit.toInt(), '신용카드'),
      ('d', debit.toInt(), '체크+현금'),
    ]) {
      await dbService.insertExpense(ExpenseItem(
        id: id,
        date: DateTime(y, 3, 5),
        amount: amount,
        content: '',
        category: '마트',
        paymentMethod: pay,
        userType: '직장인',
      ));
    }

    await t.pumpWidget(
        const MaterialApp(home: TaxAnnualReportScreen(userType: '직장인')));
    await t.pumpAndSettle();

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

    row('근로소득공제', labor);
    row('인적공제 (본인 포함 ${1 + dependents}인)', personal);
    row('4대보험 소득공제', insurance);
    row('신용카드 등 소득공제', card);
    row('과세표준', base);
    row('산출세액', calculated);
    row('근로소득세액공제', laborCredit);
    row('결정세액', decided);
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
        home: TaxAnnualReportScreen(key: ValueKey(deps), userType: '직장인'),
      ));
      await t.pumpAndSettle();

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
