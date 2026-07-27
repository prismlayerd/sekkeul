import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/core/tax_engine/combined_tax.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/freelancer_tax.dart';
import 'package:secul/ui/screens/tax_simulator_screen.dart';

/// 유형 3 × 연령대 5 × 소득 10 = **150명**을 만들어 계산기 화면을 열어 본다.
///
/// 엔진 값이 맞는지는 다른 테스트가 본다. 여기서 보는 것은 **화면이 엔진에
/// 올바른 값을 넘기는가**다 — 내 정보와 가계부에 있는 숫자가 입력칸에 그대로
/// 들어갔는지, 그 입력칸으로 엔진을 직접 돌린 값이 화면에 뜬 금액과 같은지.
///
/// 오늘 나온 월세 12% 오기처럼, 엔진이 맞아도 화면이 딴 값을 쓰면 사용자는
/// 틀린 답을 받는다. 그 층은 엔진 테스트로는 절대 안 걸린다.
class Persona {
  final String name;
  final String userType;
  final int age;
  final double gross;        // 직장인·N잡러 총급여 (프리랜서는 0)
  final double bizIncome;    // 사업 총수입 (직장인은 0)
  final int dependents;
  final int childrenForCredit;
  final double monthlyRent;
  final String occupationCode;
  final bool paysNationalPension;
  final List<(int, int, String)> incomes;          // (월, 금액, 소득종류)
  final List<(int, int, String, bool)> expenses;   // (월, 금액, 결제수단, 사업경비)

  const Persona({
    required this.name,
    required this.userType,
    required this.age,
    required this.gross,
    required this.bizIncome,
    required this.dependents,
    required this.childrenForCredit,
    required this.monthlyRent,
    required this.occupationCode,
    required this.paysNationalPension,
    required this.incomes,
    required this.expenses,
  });

  double get creditCardYtd => expenses
      .where((e) => e.$3 == '신용카드')
      .fold(0.0, (a, e) => a + e.$2);
}

void main() {
  final now = DateTime.now();
  // 씨앗 고정 — 매번 같은 150명이 나와야 실패를 재현할 수 있다.
  final rnd = Random(20260728);

  String won(num v) {
    final s = v.round().abs().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '$b';
  }

  /// 연령대별 현실적인 소득 범위 (만원).
  (int, int) incomeRange(int decade) => switch (decade) {
        20 => (2000, 4500),
        30 => (3000, 7000),
        40 => (3500, 10000),
        50 => (3000, 12000),
        _ => (1500, 8000), // 60대
      };

  const occupations = ['940909', '940918', '940903', '940906', '940913'];

  List<Persona> buildAll() {
    final out = <Persona>[];
    for (final userType in ['직장인', '프리랜서', 'N잡러']) {
      for (final decade in [20, 30, 40, 50, 60]) {
        final (lo, hi) = incomeRange(decade);
        for (int i = 0; i < 10; i++) {
          final age = decade + rnd.nextInt(10);
          final manwon = lo + rnd.nextInt(hi - lo + 1);
          final annual = manwon * 10000.0;

          // 연령대에 따라 부양가족·자녀·주거가 달라진다.
          final dependents = switch (decade) {
            20 => rnd.nextInt(2),
            30 => rnd.nextInt(3),
            40 => 1 + rnd.nextInt(3),
            50 => rnd.nextInt(3),
            _ => rnd.nextInt(2),
          };
          final children = decade == 30 || decade == 40
              ? rnd.nextInt(dependents + 1)
              : (decade == 50 ? rnd.nextInt(2) : 0);
          // 월세는 젊을수록 흔하다.
          final hasRent = rnd.nextInt(100) < switch (decade) {
            20 => 70,
            30 => 45,
            40 => 25,
            50 => 20,
            _ => 30,
          };
          final rent = hasRent ? (30 + rnd.nextInt(60)) * 10000.0 : 0.0;

          final isEmployee = userType != '프리랜서';
          final isFreelance = userType != '직장인';
          // N잡러는 급여가 주, 부업이 종.
          final gross = isEmployee ? (userType == 'N잡러' ? annual * 0.75 : annual) : 0.0;
          final biz = isFreelance ? (userType == 'N잡러' ? annual * 0.25 : annual) : 0.0;

          // 가계부 — 최소 3개월, 달마다 금액이 다르게.
          final monthCount = 3 + rnd.nextInt(4); // 3~6개월
          final months = <int>[];
          for (int m = 0; m < monthCount; m++) {
            final mm = now.month - m;
            if (mm >= 1) months.add(mm);
          }
          if (months.length < 3) {
            for (int mm = 1; months.length < 3 && mm <= now.month; mm++) {
              if (!months.contains(mm)) months.add(mm);
            }
          }

          final incomes = <(int, int, String)>[];
          final expenses = <(int, int, String, bool)>[];
          for (final m in months) {
            // 달마다 ±15% 흔들어 실제 기록처럼 만든다.
            double jitter() => 0.85 + rnd.nextDouble() * 0.30;
            if (gross > 0) {
              incomes.add((m, (gross / 12 * jitter()).round(), '급여'));
            }
            if (biz > 0) {
              incomes.add((m, (biz / 12 * jitter()).round(), '사업소득'));
            }
            final spend = (annual / 12 * (0.25 + rnd.nextDouble() * 0.45)).round();
            final method = ['신용카드', '체크+현금', '기타'][rnd.nextInt(3)];
            expenses.add((m, spend, method, isFreelance && rnd.nextBool()));
          }

          out.add(Persona(
            name: '$userType ${age}세 ${manwon}만',
            userType: userType,
            age: age,
            gross: gross,
            bizIncome: biz,
            dependents: dependents,
            childrenForCredit: children,
            monthlyRent: rent,
            occupationCode: occupations[rnd.nextInt(occupations.length)],
            paysNationalPension: isFreelance && rnd.nextBool(),
            incomes: incomes,
            expenses: expenses,
          ));
        }
      }
    }
    return out;
  }

  final personas = buildAll();

  Future<void> seed(Persona p) async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({
      'user_type': p.userType,
      'gross_income': p.userType == '프리랜서' ? p.bizIncome : p.gross,
      'age': p.age,
      'dependents': p.dependents,
      'children_count_credit': p.childrenForCredit,
      'monthly_rent': p.monthlyRent,
      'is_monthly_rent': p.monthlyRent > 0,
      'occupation_code': p.occupationCode,
      'prior_year_income': p.bizIncome * 0.8,
      'pension_enrolled': p.paysNationalPension,
      'has_elderly_70plus': p.age >= 50 && p.dependents > 0,
    });
    for (final (m, amt, type) in p.incomes) {
      await dbService.insertIncomeEntry(IncomeEntry(
        id: 'i$m-$type-$amt', date: DateTime(now.year, m, 25),
        amount: amt, memo: '', incomeType: type, userType: p.userType));
    }
    for (final (m, amt, pm, biz) in p.expenses) {
      await dbService.insertExpense(ExpenseItem(
        id: 'e$m-$pm-$amt', date: DateTime(now.year, m, 15),
        amount: amt, content: '', category: '기타',
        paymentMethod: pm, isBusiness: biz, userType: p.userType));
    }
  }

  /// 화면에 그려진 Text를 순서대로. 워드조이너는 지운다.
  List<String> textsOf(WidgetTester t) => t
      .widgetList<Text>(find.byType(Text))
      .map((w) => (w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll('⁠', ''))
      .where((s) => s.trim().isNotEmpty)
      .toList();

  /// 입력칸에 실제로 들어간 값 — 화면이 프로필·가계부에서 무엇을 읽었는지.
  Map<String, double> fieldsOf(WidgetTester t) {
    final out = <String, double>{};
    var i = 0;
    for (final e in t.widgetList<EditableText>(find.byType(EditableText))) {
      final v = double.tryParse(e.controller.text.replaceAll(',', ''));
      if (v != null) out['field${i++}'] = v;
    }
    return out;
  }

  /// '예상 환급액'·'5월 예상 환급액' 뒤에 오는 첫 금액을 뽑는다.
  double? shownAmount(List<String> texts, String label) {
    final idx = texts.indexWhere((s) => s.contains(label));
    if (idx < 0) return null;
    for (int i = idx + 1; i < texts.length && i < idx + 4; i++) {
      final m = RegExp(r'^([\d,]+)\s*원?$').firstMatch(texts[i].trim());
      if (m != null) return double.parse(m.group(1)!.replaceAll(',', ''));
    }
    return null;
  }

  group('연령대 × 소득 매트릭스 150명', () {
    for (final userType in ['직장인', '프리랜서', 'N잡러']) {
      testWidgets('$userType 50명 — 화면이 엔진에 넘기는 값', (t) async {
        t.view.physicalSize = const Size(400, 4000);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);

        final problems = <String>[];
        final mine = personas.where((p) => p.userType == userType).toList();

        for (final p in mine) {
          await seed(p);
          // 키를 안 주면 위젯 타입이 같아 State가 재사용된다 — 앞 페르소나의
          // 입력값이 그대로 남아 150명이 전부 같은 값으로 검사된다.
          await t.pumpWidget(MaterialApp(
              home: TaxSimulatorScreen(key: ValueKey(p.name), userType: p.userType)));
          await t.pumpAndSettle();

          final err = t.takeException();
          if (err != null) {
            problems.add('${p.name}: 렌더 예외 — ${err.toString().split('\n').first}');
            continue;
          }

          // 세액공제 카드는 기본이 접힘이라 자녀 칸이 트리에 없다. 실제 사용자가
          // 하듯 펼친 뒤에 봐야 "프로필 값이 칸까지 왔는가"를 확인할 수 있다.
          final creditHeader = find.byWidgetPredicate((w) =>
              w is Text && (w.data ?? '').replaceAll('⁠', '').contains('세액공제 (선택)'));
          if (creditHeader.evaluate().isNotEmpty) {
            await t.tap(creditHeader.first);
            await t.pumpAndSettle();
          }

          final texts = textsOf(t);
          final fields = fieldsOf(t);
          // 복식부기의무자는 사업소득 입력칸을 화면이 일부러 숨긴다(경비율 미적용).
          final isDoubleEntry = texts.any((s) => s.contains('복식부기의무자예요'));

          // ① 화면에 소득이 실제로 들어갔는가 — 0이면 엔진에 0을 넘긴 것이다.
          final expectIncome = p.userType == '프리랜서' ? p.bizIncome : p.gross;
          if (!isDoubleEntry &&
              expectIncome > 0 &&
              !fields.values.any((v) => (v - expectIncome).abs() < 1)) {
            problems.add('${p.name}: 소득 ${won(expectIncome)}이 입력칸에 없다'
                ' (칸 값 ${fields.values.map((e) => won(e)).join('/')})');
          }

          // ② 월세가 있으면 월세칸에도 들어갔는가 (직장인·N잡러만 노출).
          if (p.monthlyRent > 0 && p.userType != '프리랜서') {
            if (!fields.values.any((v) => (v - p.monthlyRent).abs() < 1)) {
              problems.add('${p.name}: 월세 ${won(p.monthlyRent)}이 입력칸에 없다');
            }
          }

          // ③ 자녀 수가 프로필에서 넘어왔는가.
          if (!isDoubleEntry &&
              p.childrenForCredit > 0 &&
              !fields.values.any((v) => v == p.childrenForCredit.toDouble())) {
            problems.add('${p.name}: 자녀 ${p.childrenForCredit}명이 입력칸에 없다');
          }

          // ④ 화면이 보여준 금액이 엔진 값과 같은가.
          if (p.userType == '직장인') {
            final shown = shownAmount(texts, '예상 환급액');
            if (shown != null) {
              final cardDed = EmployeeTaxCalculator.calculateCreditCardDeduction(
                grossIncome: p.gross,
                creditCard: p.creditCardYtd,
                debitCardAndCash: 0,
                traditionalMarket: 0, publicTransport: 0, cultureExpense: 0,
              ).finalDeduction;
              final cap = EmployeeTaxCalculator.estimateDecidedTaxBeforeCredits(
                grossIncome: p.gross,
                dependentsIncludingSelf: 1 + p.dependents,
                additionalPersonalDeduction:
                    EmployeeTaxCalculator.calculateAdditionalPersonalDeduction(
                  hasElderly70Plus: p.age >= 50 && p.dependents > 0,
                  isSingleFemaleHead: false,
                  isSingleParent: false,
                  globalIncomeAmount:
                      p.gross - EmployeeTaxCalculator.calculateLaborDeduction(p.gross),
                ),
                otherIncomeDeduction: cardDed,
              );
              if (shown > cap + 1) {
                problems.add('${p.name}: 화면 환급 ${won(shown)} > 낸 세금 ${won(cap)}');
              }
              if (shown < 0) problems.add('${p.name}: 환급이 음수');
            }
          }

          // ⑤ 어떤 페르소나에서도 나오면 안 되는 것들.
          for (final s in texts) {
            if (s.contains('NaN') || s.contains('Infinity') || s.contains('-0원')) {
              problems.add('${p.name}: 화면에 "$s"');
            }
          }
        }

        // ignore: avoid_print
        print('$userType ${mine.length}명 검사 · 문제 ${problems.length}건');
        for (final x in problems.take(25)) {
          // ignore: avoid_print
          print('  · $x');
        }
        expect(problems, isEmpty, reason: '$userType에서 화면↔엔진이 어긋난다');
      });
    }
  });

  group('엔진 직접 — 150명 전원 불변식', () {
    test('세금·환급이 상식을 벗어나지 않는다', () {
      final problems = <String>[];
      for (final p in personas) {
        if (p.userType == '프리랜서') {
          final r = FreelancerTaxCalculator.calculateTaxSimulation(
            accumulatedIncome: p.bizIncome,
            inputMonths: 12,
            allowanceCount: p.dependents,
            occupationCode: p.occupationCode,
            childrenCountForCredit: p.childrenForCredit,
            paysNationalPension: p.paysNationalPension,
          );
          if (r.annualTotalTax < 0) problems.add('${p.name}: 세금이 음수');
          if (r.taxBase < 0) problems.add('${p.name}: 과세표준이 음수');
          if (p.bizIncome > 0 && r.annualTotalTax / p.bizIncome > 0.45) {
            problems.add('${p.name}: 실효세율 '
                '${(r.annualTotalTax / p.bizIncome * 100).toStringAsFixed(1)}%');
          }
          if (r.estimatedExpense > r.annualEstimatedIncome + 1) {
            problems.add('${p.name}: 경비 > 수입');
          }
        } else {
          final r = CombinedTaxCalculator.calculateCombinedTax(
            grossIncome: p.gross,
            accumulatedFreelancerIncome: p.bizIncome,
            inputMonths: 12,
            occupationCode: p.occupationCode,
            creditCard: p.creditCardYtd,
            debitCardAndCash: 0,
            traditionalMarket: 0, publicTransport: 0, cultureExpense: 0,
            allowanceCount: p.dependents,
            decidedTax: EmployeeTaxCalculator.estimateDecidedTaxBeforeCredits(
                grossIncome: p.gross, dependentsIncludingSelf: 1 + p.dependents),
            monthlyRent: p.monthlyRent,
            isHomeless: p.monthlyRent > 0,
            childrenCountForCredit: p.childrenForCredit,
            hasElderly70Plus: p.age >= 50 && p.dependents > 0,
          );
          if (r.annualTotalTax < 0) problems.add('${p.name}: 세금이 음수');
          if (r.taxBase < 0) problems.add('${p.name}: 과세표준이 음수');
          final total = p.gross + r.estimatedFreelancerBusinessIncome;
          if (total > 0 && r.annualTotalTax / total > 0.45) {
            problems.add('${p.name}: 실효세율 '
                '${(r.annualTotalTax / total * 100).toStringAsFixed(1)}%');
          }
          // 월세공제는 자격이 될 때만, 그리고 법정 한도·요율로만.
          if (r.rentTaxCredit > 0) {
            final annual = p.monthlyRent * 12;
            final capped = annual > 10000000 ? 10000000.0 : annual;
            final rate = (p.gross <= 55000000 && r.totalGlobalIncome <= 45000000) ? 0.17 : 0.15;
            if ((r.rentTaxCredit - capped * rate).abs() > 1) {
              problems.add('${p.name}: 월세공제 ${won(r.rentTaxCredit)}'
                  ' ≠ ${won(capped * rate)}');
            }
          }
        }
      }
      // ignore: avoid_print
      print('엔진 150명 · 문제 ${problems.length}건');
      for (final x in problems.take(25)) {
        // ignore: avoid_print
        print('  · $x');
      }
      expect(problems, isEmpty);
    });
  });
}
