import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/ui/screens/tax_simulator_screen.dart';

/// 페르소나가 계산기 화면을 실제로 열었을 때 **화면에 뜨는 글자 전부**를 찍어 본다.
///
/// 엔진 테스트는 숫자만 본다. 사용자가 헷갈리는 건 대개 숫자가 아니라
/// "행의 합이 합계와 다르다", "상한에 걸렸는데 아무 말이 없다" 같은 화면 쪽 문제라
/// 렌더된 글자를 직접 봐야 잡힌다.
void main() {
  final now = DateTime.now();

  Future<void> seed({
    required String userType,
    double gross = 0,
    int dependents = 0,
    double monthlyRent = 0,
    String? occupationCode,
    double priorYearIncome = 0,
    List<(int, int, String)> incomes = const [],
    List<(int, int, String, bool)> expenses = const [],
  }) async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({
      'user_type': userType,
      'gross_income': gross,
      'dependents': dependents,
      'monthly_rent': monthlyRent,
      if (occupationCode != null) 'occupation_code': occupationCode,
      'prior_year_income': priorYearIncome,
    });
    for (final (m, amt, type) in incomes) {
      if (m > now.month) continue;
      await dbService.insertIncomeEntry(IncomeEntry(
        id: 'i$m-$amt-$type', date: DateTime(now.year, m, 25),
        amount: amt, memo: '', incomeType: type, userType: userType));
    }
    for (final (m, amt, pm, biz) in expenses) {
      if (m > now.month) continue;
      await dbService.insertExpense(ExpenseItem(
        id: 'e$m-$amt-$pm', date: DateTime(now.year, m, 15),
        amount: amt, content: '', category: '기타', paymentMethod: pm,
        isBusiness: biz, userType: userType));
    }
  }

  /// 화면에 실제로 그려진 문자열을 순서대로 모은다. 입력칸에 채워진 값도 포함한다
  /// (자동기입이 실제로 됐는지는 Text가 아니라 EditableText에만 나타난다).
  List<String> renderedText(WidgetTester t) {
    final out = <String>[];
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      final s = (w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll('⁠', '');
      if (s.trim().isNotEmpty) out.add(s);
    }
    for (final e in t.widgetList<EditableText>(find.byType(EditableText))) {
      if (e.controller.text.trim().isNotEmpty) out.add('[입력칸=${e.controller.text}]');
    }
    return out;
  }

  Future<List<String>> open(WidgetTester t, String userType) async {
    t.view.physicalSize = const Size(400, 4000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: TaxSimulatorScreen(userType: userType)));
    await t.pumpAndSettle();
    return renderedText(t);
  }

  group('직장인 — 계산기 화면', () {
    final rows = <(String, double, int, double, int)>[
      // (이름, 연봉, 부양가족, 월세, 카드사용액)
      ('최저임금 사회초년생', 25200000, 0, 500000, 8000000),
      ('중소기업 사원', 32000000, 0, 450000, 12000000),
      ('4인 가구 외벌이', 42000000, 3, 700000, 20000000),
      ('맞벌이 대리', 55000000, 1, 0, 25000000),
      ('과장 자가', 65000000, 2, 0, 30000000),
      ('부장', 90000000, 2, 0, 40000000),
      ('임원', 150000000, 1, 0, 60000000),
      ('휴직 반년', 9000000, 0, 400000, 2000000),
      ('연봉 미설정', 0, 0, 0, 5000000),
      ('무월세 저소득', 18000000, 0, 0, 6000000),
    ];

    for (final (name, gross, deps, rent, card) in rows) {
      testWidgets(name, (t) async {
        await seed(
          userType: '직장인', gross: gross, dependents: deps, monthlyRent: rent,
          incomes: [for (var m = 1; m <= now.month; m++) (m, (gross ~/ 12), '급여')],
          expenses: [(1, card ~/ 2, '신용카드', false), (now.month, card ~/ 2, '신용카드', false)],
        );
        final texts = await open(t, '직장인');
        // ignore: avoid_print
        print('\n═══ 직장인 · $name (연봉 ${gross ~/ 10000}만) ═══\n${texts.join(' | ')}');

        reportException(t, '직장인 · $name');
        // 숫자가 NaN·Infinity로 새어 나오면 안 된다.
        for (final s in texts) {
          expect(s.contains('NaN'), isFalse, reason: '$name: NaN이 화면에 보인다 — "$s"');
          expect(s.contains('Infinity'), isFalse, reason: '$name: Infinity가 보인다 — "$s"');
          expect(s.contains('-0원'), isFalse, reason: '$name: -0원이 보인다 — "$s"');
        }
      });
    }
  });

  group('프리랜서 — 계산기 화면', () {
    final rows = <(String, String, int, int)>[
      // (이름, 업종코드, 직전연도수입, 올해수입)
      ('배달 시작', '940918', 0, 12000000),
      ('과외', '940903', 8000000, 18000000),
      ('디자이너', '940909', 20000000, 30000000),
      ('웹개발 외주', '940909', 40000000, 55000000),
      ('보험설계사', '940906', 30000000, 45000000),
      ('대리운전', '940913', 15000000, 22000000),
      ('강사', '940903', 25000000, 33000000),
      ('유튜버 급성장', '940909', 30000000, 90000000),
      ('업종 미선택', '', 0, 20000000),
      ('첫해 신규', '940909', 0, 6000000),
    ];

    for (final (name, occ, prior, income) in rows) {
      testWidgets(name, (t) async {
        await seed(
          userType: '프리랜서', gross: income.toDouble(),
          occupationCode: occ.isEmpty ? null : occ,
          priorYearIncome: prior.toDouble(),
          incomes: [for (var m = 1; m <= now.month; m++) (m, income ~/ 12, '사업소득')],
          expenses: [(1, 500000, '체크+현금', true), (now.month, 500000, '체크+현금', true)],
        );
        final texts = await open(t, '프리랜서');
        // ignore: avoid_print
        print('\n═══ 프리랜서 · $name (수입 ${income ~/ 10000}만) ═══\n${texts.join(' | ')}');
        reportException(t, '프리랜서 · $name');
        for (final s in texts) {
          expect(s.contains('NaN'), isFalse, reason: '$name: NaN — "$s"');
          expect(s.contains('Infinity'), isFalse, reason: '$name: Infinity — "$s"');
        }
      });
    }
  });

  group('N잡러 — 계산기 화면', () {
    final rows = <(String, double, int, String, int)>[
      // (이름, 연봉, 부업수입, 업종, 직전연도수입)
      ('급여+소액 부업', 30000000, 3000000, '940909', 2000000),
      ('급여+배달', 26000000, 8000000, '940918', 6000000),
      ('급여+과외', 45000000, 6000000, '940903', 5000000),
      ('급여+외주', 55000000, 15000000, '940909', 12000000),
      ('급여+유튜브', 60000000, 30000000, '940909', 25000000),
      ('저소득+부업 위주', 15000000, 20000000, '940909', 18000000),
      ('고소득+부업', 95000000, 20000000, '940909', 18000000),
      ('부업 첫해', 48000000, 2000000, '940909', 0),
      ('둘 다 큼', 120000000, 80000000, '940909', 75000000),
      ('부업 0', 42000000, 0, '940909', 0),
    ];

    for (final (name, gross, biz, occ, prior) in rows) {
      testWidgets(name, (t) async {
        await seed(
          userType: 'N잡러', gross: gross, occupationCode: occ,
          priorYearIncome: prior.toDouble(),
          incomes: [
            for (var m = 1; m <= now.month; m++) (m, gross ~/ 12, '급여'),
            for (var m = 1; m <= now.month; m++) (m, biz ~/ 12, '사업소득'),
          ],
          expenses: [(1, 1000000, '신용카드', false), (now.month, 800000, '체크+현금', true)],
        );
        final texts = await open(t, 'N잡러');
        // ignore: avoid_print
        print('\n═══ N잡러 · $name (연봉 ${gross ~/ 10000}만 + 부업 ${biz ~/ 10000}만) ═══\n'
            '${texts.join(' | ')}');
        reportException(t, 'N잡러 · $name');
        for (final s in texts) {
          expect(s.contains('NaN'), isFalse, reason: '$name: NaN — "$s"');
          expect(s.contains('Infinity'), isFalse, reason: '$name: Infinity — "$s"');
        }
      });
    }
  });
}

/// RenderFlex 오버플로 같은 렌더 예외를 그대로 찍는다 — 어디가 넘쳤는지 봐야 고친다.
void reportException(WidgetTester t, String who) {
  final e = t.takeException();
  if (e != null) {
    final msg = e.toString().replaceAll('\n', ' / ');
    // ignore: avoid_print
    print('!!! 렌더 예외 [$who]: $msg');
  }
}
