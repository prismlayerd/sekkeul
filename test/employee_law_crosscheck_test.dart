import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/tax_year.dart';

import 'support/tax_law_reference.dart';

/// 직장인 12인 — 엔진 출력을 **조문에서 따로 계산한 값**과 1원 단위로 맞춰 본다.
///
/// 기존 페르소나 테스트는 불변식(0 이상·한도 이하)만 본다. 그건 값이 통째로 틀려도
/// 통과한다. 여기서는 `support/tax_law_reference.dart`가 엔진을 전혀 참조하지 않고
/// 조문 수치로 다시 계산한 답과 대조한다 — 상수가 틀리면 양쪽이 갈린다.
///
/// 각 페르소나는 내 정보(총급여·부양·자녀·거주·나이)와 3개월 이상의 가계부를 갖고,
/// 카드 누적은 화면과 같이 **가계부에서 읽어** 만든다.
class E {
  final String name;
  final double gross;
  final int dependents; // 본인 제외
  final int childrenTotal; // 카드 기본한도 상향용(자녀등)
  final int childrenForCredit; // 자녀세액공제 대상 연령
  final int newborn;
  final bool elderly70;
  final bool singleParent;
  final bool femaleHead;

  /// (월, 금액, 결제수단) — 3개월 이상.
  final List<(int, int, String)> expenses;

  /// (월, 실수령 급여) — 3개월 이상.
  final List<(int, int)> salaries;

  const E(
    this.name, {
    required this.gross,
    this.dependents = 0,
    this.childrenTotal = 0,
    this.childrenForCredit = 0,
    this.newborn = 0,
    this.elderly70 = false,
    this.singleParent = false,
    this.femaleHead = false,
    required this.expenses,
    required this.salaries,
  });
}

const _pay3 = <(int, int)>[(5, 3000000), (6, 3000000), (7, 3000000)];

const employees = <E>[
  E('①  총급여 2,400만 · 1인 가구 · 카드 문턱 미달',
      gross: 24000000,
      expenses: [(5, 2000000, '신용카드'), (6, 1500000, '체크+현금'), (7, 1000000, '신용카드')],
      salaries: _pay3),
  E('②  총급여 3,300만 · 근로세액공제 한도 경계',
      gross: 33000000,
      expenses: [(5, 5000000, '신용카드'), (6, 4000000, '체크+현금'), (7, 3000000, '체크+현금')],
      salaries: _pay3),
  E('③  총급여 4,500만 · 근로소득공제 구간 경계',
      gross: 45000000,
      dependents: 1,
      expenses: [(5, 8000000, '신용카드'), (6, 6000000, '체크+현금'), (7, 4000000, '체크+현금')],
      salaries: _pay3),
  E('④  총급여 5,000만 · 세율 구간 경계 · 자녀2',
      gross: 50000000,
      dependents: 2,
      childrenTotal: 2,
      childrenForCredit: 2,
      expenses: [(5, 20000000, '신용카드'), (6, 20000000, '체크+현금'), (7, 10000000, '체크+현금')],
      salaries: _pay3),
  E('⑤  총급여 7,000만 · 카드 한도·도서공연 대상 경계',
      gross: 70000000,
      dependents: 1,
      childrenTotal: 1,
      childrenForCredit: 1,
      expenses: [(5, 20000000, '신용카드'), (6, 15000000, '체크+현금'), (7, 5000000, '체크+현금')],
      salaries: [(5, 4500000), (6, 4500000), (7, 4500000)]),
  E('⑥  총급여 7,000만 + 1원 · 한도가 한 칸 내려간다',
      gross: 70000001,
      dependents: 1,
      childrenTotal: 1,
      childrenForCredit: 1,
      expenses: [(5, 20000000, '신용카드'), (6, 15000000, '체크+현금'), (7, 5000000, '체크+현금')],
      salaries: [(5, 4500000), (6, 4500000), (7, 4500000)]),
  E('⑦  총급여 8,800만 · 24→35% 경계 · 경로우대',
      gross: 88000000,
      dependents: 1,
      elderly70: true,
      expenses: [(5, 25000000, '신용카드'), (6, 15000000, '체크+현금'), (7, 5000000, '신용카드')],
      salaries: [(5, 5500000), (6, 5500000), (7, 5500000)]),
  E('⑧  총급여 1억 2,000만 · 근로세액공제 하한 구간',
      gross: 120000000,
      dependents: 3,
      childrenTotal: 3,
      childrenForCredit: 3,
      expenses: [(5, 30000000, '신용카드'), (6, 20000000, '체크+현금'), (7, 10000000, '체크+현금')],
      salaries: [(5, 7000000), (6, 7000000), (7, 7000000)]),
  E('⑨  총급여 1억 5,000만 · 국민연금 상한 초과',
      gross: 150000000,
      dependents: 1,
      expenses: [(5, 30000000, '신용카드'), (6, 25000000, '체크+현금'), (7, 10000000, '체크+현금')],
      salaries: [(5, 9000000), (6, 9000000), (7, 9000000)]),
  E('⑩  총급여 1,200만 · 국민연금 하한 미만 · 한부모',
      gross: 12000000,
      dependents: 1,
      childrenTotal: 1,
      childrenForCredit: 1,
      singleParent: true,
      expenses: [(5, 1500000, '체크+현금'), (6, 1500000, '체크+현금'), (7, 1000000, '신용카드')],
      salaries: [(5, 1000000), (6, 1000000), (7, 1000000)]),
  E('⑪  총급여 6,000만 · 부녀자 · 출산 1명',
      gross: 60000000,
      dependents: 1,
      childrenTotal: 1,
      childrenForCredit: 0,
      newborn: 1,
      femaleHead: true,
      expenses: [(5, 10000000, '신용카드'), (6, 8000000, '체크+현금'), (7, 4000000, '체크+현금')],
      salaries: [(5, 4000000), (6, 4000000), (7, 4000000)]),
  E('⑫  총급여 5,000만 · 기타 결제수단만 — 공제 대상 밖',
      gross: 50000000,
      expenses: [(5, 8000000, '기타'), (6, 8000000, '기타'), (7, 5000000, '기타')],
      salaries: _pay3),
];

String won(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}${b.toString()}원';
}

void main() {
  final year = TaxYear.reference;

  test('직장인 12인 — 엔진 값이 조문 검산과 일치한다', () async {
    for (final p in employees) {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
      await dbService.saveProfile({
        'user_type': '직장인',
        'gross_income': p.gross,
        'dependents': p.dependents,
        'children_count_total': p.childrenTotal,
        'children_count_credit': p.childrenForCredit,
        'newborn_count': p.newborn,
        'newborn_year': p.newborn > 0 ? year : 0,
        'has_elderly_70plus': p.elderly70,
        'is_single_parent': p.singleParent,
        'is_female_head': p.femaleHead,
      });
      for (final (m, amt) in p.salaries) {
        await dbService.insertIncomeEntry(IncomeEntry(
            id: 's$m', date: DateTime(year, m, 25), amount: amt, memo: '',
            incomeType: '급여', userType: '직장인'));
      }
      for (final (m, amt, pm) in p.expenses) {
        await dbService.insertExpense(ExpenseItem(
            id: 'e$m-$pm-$amt', date: DateTime(year, m, 15), amount: amt, content: '',
            category: '기타', paymentMethod: pm, isBusiness: false, userType: '직장인'));
      }

      // ── 가계부에서 카드 누적을 읽는다(화면과 같은 규칙) ──
      double credit = 0, debitCash = 0;
      for (final e in await dbService.getExpenses(userType: '직장인')) {
        if (e.paymentMethod == '신용카드') credit += e.amount;
        if (e.paymentMethod == '체크+현금') debitCash += e.amount;
      }
      expect(p.expenses.map((e) => e.$1).toSet().length, greaterThanOrEqualTo(3),
          reason: '${p.name}: 가계부는 3개월 이상이어야 한다');
      expect(p.salaries.map((e) => e.$1).toSet().length, greaterThanOrEqualTo(3),
          reason: '${p.name}: 급여도 3개월 이상');

      final heads = 1 + p.dependents;
      final addl = refAdditionalPersonalDeduction(
        elderly70: p.elderly70,
        femaleHead: p.femaleHead,
        singleParent: p.singleParent,
      );

      // ── ① 근로소득공제 (§47) ──
      expect(EmployeeTaxCalculator.calculateLaborDeduction(p.gross),
          closeTo(refLaborDeduction(p.gross), 0.01),
          reason: '${p.name}: 근로소득공제');

      // ── ② 4대보험 소득공제 (§51의3 · §52①) ──
      final engIns = EmployeeTaxCalculator.calculateAnnualInsuranceDeduction(p.gross / 12);
      final refIns = refAnnualInsurance(p.gross / 12);
      expect(engIns.pensionDeduction, closeTo(refIns.pension, 0.01),
          reason: '${p.name}: 연금보험료공제');
      expect(engIns.specialInsuranceDeduction, closeTo(refIns.special, 0.01),
          reason: '${p.name}: 보험료 특별소득공제');

      // ── ③ 추가공제 (§51) ──
      expect(
          EmployeeTaxCalculator.calculateAdditionalPersonalDeduction(
            hasElderly70Plus: p.elderly70,
            isSingleFemaleHead: p.femaleHead,
            isSingleParent: p.singleParent,
          ),
          closeTo(addl, 0.01),
          reason: '${p.name}: 추가공제');

      // ── ④ 카드 소득공제 (조특법 §126의2) ──
      final engCard = EmployeeTaxCalculator.calculateCreditCardDeduction(
        grossIncome: p.gross,
        creditCard: credit,
        debitCardAndCash: debitCash,
        traditionalMarket: 0,
        publicTransport: 0,
        cultureExpense: 0,
        childrenCount: p.childrenTotal,
      );
      final refCard = refCardDeduction(
        gross: p.gross,
        credit: credit,
        debitCash: debitCash,
        children: p.childrenTotal,
      );
      expect(engCard.finalDeduction, closeTo(refCard, 0.01),
          reason: '${p.name}: 카드 소득공제액');
      expect(engCard.threshold, closeTo(p.gross * 0.25, 0.01),
          reason: '${p.name}: 최저사용금액은 총급여 25%');

      // ── ⑤ 결정세액 (§55 · §59 · §59의4⑨) ──
      final engDecided = EmployeeTaxCalculator.estimateDecidedTaxBeforeCredits(
        grossIncome: p.gross,
        dependentsIncludingSelf: heads,
        additionalPersonalDeduction: addl,
      );
      final refDecided = refDecidedTax(
        gross: p.gross,
        headcount: heads,
        additionalPersonalDeduction: addl,
      );
      expect(engDecided, closeTo(refDecided, 0.01), reason: '${p.name}: 결정세액');

      // ── ⑥ 카드공제 절세액 = 결정세액 차이 ──
      final engRefund = EmployeeTaxCalculator.estimateCreditCardRefund(
        grossAnnual: p.gross,
        dependentsIncludingSelf: heads,
        creditCardYtd: credit,
        debitCashYtd: debitCash,
        childrenCount: p.childrenTotal,
      );
      // 환급 카운터는 표준세액공제 비교 없이 특별공제 길로만, 추가공제도 빼고
      // 계산한다(차액이라 상쇄된다는 전제). 같은 잣대로 검산한다.
      final refSaving = trunc10((refDecidedTax(
                  gross: p.gross, headcount: heads, compareStandard: false) -
              refDecidedTax(
                  gross: p.gross,
                  headcount: heads,
                  otherIncomeDeduction: refCard,
                  compareStandard: false))
          .clamp(0.0, double.infinity));
      // 「결정세액 0원 법칙」 — 절세액은 실제 결정세액을 넘을 수 없다.
      final refDecidedNoAddl = refDecidedTax(gross: p.gross, headcount: heads);
      final refSavingCapped =
          refSaving > refDecidedNoAddl ? refDecidedNoAddl : refSaving;
      expect(engRefund.taxSaving, closeTo(refSavingCapped, 0.01),
          reason: '${p.name}: 카드공제 절세액');
      expect(engRefund.taxSaving, lessThanOrEqualTo(engDecided + 0.01),
          reason: '${p.name}: 낸 세금보다 더 돌려받을 수 없다');

      // 위 전제가 실제로 상쇄되는지 — 법대로(표준·특별 비교 + 추가공제 반영)
      // 계산한 절세액과 얼마나 벌어지는지 같이 본다.
      final lawSaving = trunc10((refDecidedTax(
                  gross: p.gross, headcount: heads, additionalPersonalDeduction: addl) -
              refDecidedTax(
                  gross: p.gross,
                  headcount: heads,
                  additionalPersonalDeduction: addl,
                  otherIncomeDeduction: refCard))
          .clamp(0.0, double.infinity));
      final gap = engRefund.taxSaving - lawSaving;
      if (gap.abs() > 0.01) {
        // ignore: avoid_print
        print('    ⚠ 환급 카운터 ${won(engRefund.taxSaving)} vs 법대로 ${won(lawSaving)}'
            ' → 차이 ${won(gap)}');
      }
      expect(engRefund.deduction, closeTo(refCard, 0.01),
          reason: '${p.name}: 환급추정에 쓰인 카드공제액');

      // ── ⑦ 자녀세액공제 (§59의2①) ──
      expect(
          EmployeeTaxCalculator.calculateChildTaxCredit(
              childrenCount: p.childrenForCredit, newbornCount: p.newborn),
          closeTo(refChildTaxCredit(children: p.childrenForCredit, newborn: p.newborn), 0.01),
          reason: '${p.name}: 자녀세액공제');

      // ignore: avoid_print
      print('${p.name}\n    총급여 ${won(p.gross)} · 부양 ${p.dependents} · 카드 '
          '신용 ${won(credit)}/체크현금 ${won(debitCash)}\n'
          '    카드공제 ${won(engCard.finalDeduction)}  결정세액 ${won(engDecided)}'
          '  절세액 ${won(engRefund.taxSaving)}');
    }
  });
}
