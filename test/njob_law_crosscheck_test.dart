import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/core/data/occupation_data.dart';
import 'package:secul/core/tax_engine/combined_tax.dart';
import 'package:secul/core/tax_engine/tax_year.dart';

import 'support/tax_law_reference.dart';

/// N잡러 12인 — 근로+사업+기타 합산 종소세를 조문 검산과 대조한다.
///
/// 합산은 "근로 따로 · 사업 따로"가 아니다. 종합소득금액을 합쳐 하나의 누진세율을
/// 태우고(§14·§55), 근로소득세액공제는 **근로소득금액이 차지하는 비율만큼만**
/// 산출세액에서 뺀다(§59①, 소득세법 집행기준 59-0-1).
///
/// 근거: 소득세법 §14 종합소득 / §47 근로소득공제 / §50·§51 인적·추가공제
///      / §51의3 연금보험료공제 / §52① 특별소득공제 / §55① 세율
///      / §59 근로소득세액공제 / §59의2 자녀 / §59의4⑨ 표준세액공제 13만
///      / 조특법 §126의2 카드 / 시행령 §143③ 단순경비율
class N {
  final String name;
  final double gross; // 근로 총급여(예상 연봉)
  final String occ;
  final int dependents;
  final int childrenTotal;
  final int childrenForCredit;
  final bool elderly70;
  final bool singleParent;
  final double yellowUmbrella;

  /// (월, 세전 사업소득 수입)
  final List<(int, int)> bizIncome;

  /// (월, 세전 기타소득 수입)
  final List<(int, int)> otherIncome;

  /// (월, 금액, 결제수단)
  final List<(int, int, String)> expenses;

  const N(
    this.name, {
    required this.gross,
    required this.occ,
    this.dependents = 0,
    this.childrenTotal = 0,
    this.childrenForCredit = 0,
    this.elderly70 = false,
    this.singleParent = false,
    this.yellowUmbrella = 0,
    required this.bizIncome,
    this.otherIncome = const [],
    required this.expenses,
  });
}

const _exp3 = <(int, int, String)>[
  (5, 3000000, '신용카드'),
  (6, 2500000, '체크+현금'),
  (7, 2000000, '신용카드'),
];

const njobs = <N>[
  N('①  급여 3,600만 + 부업 연환산 1,200만',
      gross: 36000000, occ: '940306',
      bizIncome: [(5, 1000000), (6, 1000000), (7, 1000000)],
      expenses: _exp3),
  N('②  급여 4,800만 + 부업 연환산 4,800만 — 부업이 구간을 밀어올린다',
      gross: 48000000, occ: '940306', dependents: 1,
      bizIncome: [(5, 4000000), (6, 4000000), (7, 4000000)],
      expenses: _exp3),
  N('③  급여 3,000만 + 부업 연환산 3,600만 · 자녀 2',
      gross: 30000000, occ: '940306', dependents: 2,
      childrenTotal: 2, childrenForCredit: 2,
      bizIncome: [(5, 3000000), (6, 3000000), (7, 3000000)],
      expenses: _exp3),
  N('④  급여 7,000만 + 부업 연환산 2,400만 — 카드 한도 경계',
      gross: 70000000, occ: '940306', dependents: 1,
      childrenTotal: 1, childrenForCredit: 1,
      bizIncome: [(5, 2000000), (6, 2000000), (7, 2000000)],
      expenses: [(5, 12000000, '신용카드'), (6, 8000000, '체크+현금'), (7, 4000000, '체크+현금')]),
  N('⑤  급여 9,600만 + 부업 연환산 4,800만 — 35% 구간',
      gross: 96000000, occ: '940306', dependents: 2,
      bizIncome: [(5, 4000000), (6, 4000000), (7, 4000000)],
      expenses: [(5, 15000000, '신용카드'), (6, 10000000, '체크+현금'), (7, 5000000, '체크+현금')]),
  N('⑥  급여 2,400만 + 부업 연환산 1,200만 — 저소득 · 표준세액공제가 유리',
      gross: 24000000, occ: '940306',
      bizIncome: [(5, 1000000), (6, 1000000), (7, 1000000)],
      expenses: [(5, 1500000, '신용카드'), (6, 1000000, '체크+현금'), (7, 800000, '신용카드')]),
  N('⑦  기타소득만 있는 N잡러 — 기타소득금액 300만 이하',
      gross: 42000000, occ: '940306',
      bizIncome: [(5, 0), (6, 0), (7, 0)],
      otherIncome: [(5, 600000), (6, 600000), (7, 600000)],
      expenses: _exp3),
  N('⑧  사업 + 기타 동시 — 기타소득금액 300만 초과',
      gross: 42000000, occ: '940306', dependents: 1,
      bizIncome: [(5, 2000000), (6, 2000000), (7, 2000000)],
      otherIncome: [(5, 3000000), (6, 3000000), (7, 3000000)],
      expenses: _exp3),
  N('⑨  노란우산 500만 · 경로우대',
      gross: 54000000, occ: '940306', dependents: 1, elderly70: true,
      yellowUmbrella: 5000000,
      bizIncome: [(5, 3000000), (6, 3000000), (7, 3000000)],
      expenses: _exp3),
  N('⑩  한부모 · 자녀 1 · 급여 3,300만 경계',
      gross: 33000000, occ: '940306', dependents: 1, singleParent: true,
      childrenTotal: 1, childrenForCredit: 1,
      bizIncome: [(5, 1500000), (6, 1500000), (7, 1500000)],
      expenses: _exp3),
  N('⑪  부업이 본업보다 큰 경우 — 연환산 9,600만',
      gross: 30000000, occ: '940306',
      bizIncome: [(5, 8000000), (6, 8000000), (7, 8000000)],
      expenses: _exp3),
  N('⑫  학원강사 부업(940903) · 다른 경비율',
      gross: 45000000, occ: '940903', dependents: 2,
      childrenTotal: 2, childrenForCredit: 1,
      bizIncome: [(5, 2500000), (6, 2500000), (7, 2500000)],
      expenses: _exp3),
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
  const months = 3;

  test('N잡러 12인 — 합산 종소세가 조문 검산과 일치한다', () async {
    for (final p in njobs) {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
      await dbService.saveProfile({
        'user_type': 'N잡러',
        'gross_income': p.gross,
        'occupation_code': p.occ,
        'dependents': p.dependents,
        'children_count_total': p.childrenTotal,
        'children_count_credit': p.childrenForCredit,
        'has_elderly_70plus': p.elderly70,
        'is_single_parent': p.singleParent,
        'yellow_umbrella': p.yellowUmbrella,
      });
      for (final (m, amt) in p.bizIncome) {
        if (amt <= 0) continue;
        await dbService.insertIncomeEntry(IncomeEntry(
            id: 'b$m', date: DateTime(year, m, 10), amount: amt, memo: '',
            incomeType: '사업소득', isWithheld: false, userType: 'N잡러'));
      }
      for (final (m, amt) in p.otherIncome) {
        await dbService.insertIncomeEntry(IncomeEntry(
            id: 'o$m', date: DateTime(year, m, 11), amount: amt, memo: '',
            incomeType: '기타소득', isWithheld: false, userType: 'N잡러'));
      }
      for (final (m, amt, pm) in p.expenses) {
        await dbService.insertExpense(ExpenseItem(
            id: 'e$m-$pm', date: DateTime(year, m, 15), amount: amt, content: '',
            category: '기타', paymentMethod: pm, isBusiness: false, userType: 'N잡러'));
      }
      expect(p.expenses.map((e) => e.$1).toSet().length, greaterThanOrEqualTo(3),
          reason: '${p.name}: 가계부 3개월 이상');

      double accBiz = 0, accOther = 0, credit = 0, debitCash = 0;
      for (int m = 1; m <= 12; m++) {
        for (final e in await dbService.getIncomeEntriesForMonth(year, m, userType: 'N잡러')) {
          if (e.incomeType == '사업소득') accBiz += e.amount;
          if (e.incomeType == '기타소득') accOther += e.amount;
        }
      }
      for (final e in await dbService.getExpenses(userType: 'N잡러')) {
        if (e.paymentMethod == '신용카드') credit += e.amount;
        if (e.paymentMethod == '체크+현금') debitCash += e.amount;
      }

      final r = CombinedTaxCalculator.calculateCombinedTax(
        grossIncome: p.gross,
        accumulatedFreelancerIncome: accBiz,
        inputMonths: months,
        occupationCode: p.occ,
        creditCard: credit,
        debitCardAndCash: debitCash,
        traditionalMarket: 0,
        publicTransport: 0,
        cultureExpense: 0,
        allowanceCount: p.dependents,
        decidedTax: 0,
        monthlyRent: 0,
        yellowUmbrellaPayment: p.yellowUmbrella,
        otherIncome: accOther / months * 12,
        childrenCountForCredit: p.childrenForCredit,
        childrenCountTotal: p.childrenTotal,
        hasElderly70Plus: p.elderly70,
        isSingleParent: p.singleParent,
      );

      // ── ① 근로소득금액 (§47) ──
      final laborIncome = p.gross - refLaborDeduction(p.gross);
      expect(r.laborIncomeAmount, closeTo(laborIncome, 0.01),
          reason: '${p.name}: 근로소득금액');

      // ── ② 사업소득금액 — 단순경비율(시행령 §143③1의2) ──
      final annualBiz = accBiz / months * 12;
      final occ = OccupationData.occupations[p.occ]!;
      final baseRate = occ.simpleBaseRate / 100.0;
      final excessRate = occ.simpleExcessRate == 0 ? baseRate : occ.simpleExcessRate / 100.0;
      final bizExpense = annualBiz <= 40000000
          ? annualBiz * baseRate
          : 40000000 * baseRate + (annualBiz - 40000000) * excessRate;
      final bizIncomeAmount = annualBiz - bizExpense;
      expect(r.estimatedFreelancerBusinessIncome, closeTo(bizIncomeAmount, 0.01),
          reason: '${p.name}: 사업소득금액');

      // ── ③ 기타소득금액 — 시행령 §87 정률 60% 경비 ──
      final annualOther = accOther / months * 12;
      final otherAmount = refOtherIncomeAmount(annualOther);

      // ── ④ 소득공제 ──
      final personal = (p.dependents + 1) * 1500000.0;
      final addl = refAdditionalPersonalDeduction(
          elderly70: p.elderly70, singleParent: p.singleParent);
      expect(r.additionalPersonalDeduction, closeTo(addl, 0.01),
          reason: '${p.name}: 추가공제');

      final card = refCardDeduction(
        gross: p.gross, credit: credit, debitCash: debitCash,
        children: p.childrenTotal,
      );
      expect(r.cardResult.finalDeduction, closeTo(card, 0.01),
          reason: '${p.name}: 카드 소득공제 (문턱은 총급여 25% 기준)');

      final yellowLimit = bizIncomeAmount <= 40000000
          ? 6000000.0
          : bizIncomeAmount <= 60000000
              ? 5000000.0
              : bizIncomeAmount <= 100000000
                  ? 4000000.0
                  : 2000000.0;
      final yellow = p.yellowUmbrella < yellowLimit ? p.yellowUmbrella : yellowLimit;
      expect(r.yellowUmbrellaDeduction, closeTo(yellow, 0.01),
          reason: '${p.name}: 노란우산 공제액');

      final ins = refAnnualInsurance(p.gross / 12);

      // ── ⑤ 과세표준·산출세액·근로세액공제·결정세액 ──
      // §59의4⑨ — 특별소득공제 길과 표준세액공제 13만 길 중 세금이 적은 쪽.
      ({double tax, double base}) pass({required bool standard}) {
        final deductions = personal +
            addl +
            card +
            yellow +
            ins.pension +
            (standard ? 0.0 : ins.special);
        final withoutOther = (laborIncome + bizIncomeAmount - deductions)
            .clamp(0.0, double.infinity);
        final withOther = (laborIncome + bizIncomeAmount + otherAmount - deductions)
            .clamp(0.0, double.infinity);

        // §14③8 — 기타소득금액 300만 이하면 분리과세(8.8% 종결)와 종합과세 중 유리한 쪽.
        bool comprehensive = true;
        if (otherAmount > 0 && otherAmount <= 3000000) {
          final marginal =
              (refProgressiveTax(withOther) - refProgressiveTax(withoutOther)) * 1.1;
          final separate = annualOther * (0.08 + 0.008);
          if (marginal > separate) comprehensive = false;
        }
        final globalIncome =
            laborIncome + bizIncomeAmount + (comprehensive ? otherAmount : 0.0);
        final base = comprehensive ? withOther : withoutOther;
        final calculated = refProgressiveTax(base);
        // §59① — 근로세액공제는 근로소득금액 몫의 산출세액에만 걸린다.
        final laborShare =
            globalIncome > 0 ? calculated * (laborIncome / globalIncome) : 0.0;
        final laborCredit =
            refLaborTaxCredit(gross: p.gross, calculatedTax: laborShare);
        final child = refChildTaxCredit(
            children: p.childrenForCredit, newborn: 0);
        final tax = (calculated -
                laborCredit -
                child -
                (standard ? 130000.0 : 0.0))
            .clamp(0.0, double.infinity);
        return (tax: tax, base: base);
      }

      final special = pass(standard: false);
      final std = pass(standard: true);
      final chosen = special.tax <= std.tax ? special : std;

      expect(r.taxBase, closeTo(chosen.base, 0.01), reason: '${p.name}: 과세표준');
      expect(r.calculatedTax, closeTo(refProgressiveTax(chosen.base), 0.01),
          reason: '${p.name}: 산출세액');
      expect(r.annualIncomeTax, closeTo(trunc10(chosen.tax), 0.01),
          reason: '${p.name}: 종합소득세 결정세액');
      expect(r.annualLocalTax, closeTo(trunc10(trunc10(chosen.tax) * 0.1), 0.01),
          reason: '${p.name}: 지방소득세는 소득세의 10%');
      expect(r.childTaxCredit,
          closeTo(refChildTaxCredit(children: p.childrenForCredit), 0.01),
          reason: '${p.name}: 자녀세액공제');

      // ignore: avoid_print
      print('${p.name}\n    근로소득금액 ${won(laborIncome)} · 사업소득금액 '
          '${won(bizIncomeAmount)} · 기타 ${won(otherAmount)}\n'
          '    과세표준 ${won(r.taxBase)}  결정세액 ${won(r.annualTotalTax)}'
          '  (표준 유리 ${std.tax < special.tax})');
    }
  });
}
