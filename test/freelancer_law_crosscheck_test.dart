import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/core/data/occupation_data.dart';
import 'package:secul/core/tax_engine/freelancer_tax.dart';
import 'package:secul/core/tax_engine/tax_year.dart';

import 'support/tax_law_reference.dart';

/// 프리랜서 10인 — 종소세 결과를 조문 검산과 대조한다.
///
/// 경비율 **표 자체**(업종코드 1,542종)는 국세청 고시라 여기서 다시 만들 수 없다.
/// 그래서 표의 값은 `OccupationData`에서 읽고, **그 값을 어떻게 쓰는지**(4,000만원
/// 기본율·초과율 분리, 기준경비율 분기, 소득상한배율)를 조문으로 검산한다.
///
/// 근거: 소득세법 §51 인적·추가공제 / §51의3 연금보험료공제 / §55① 세율
///      / §59의2 자녀세액공제 / §59의4⑨ 표준세액공제(근로소득 없는 자 7만)
///      / 시행령 §143③ 추계결정(단순·기준경비율, 소득상한배율)
///      / 조특법 §86의3 노란우산 / 지방세법 §92 지방소득세 10%
class F {
  final String name;
  final String occ;
  final int dependents;
  final int disabledDeps;
  final bool selfDisability;
  final double yellowUmbrella;
  final int childrenForCredit;
  final int newborn;
  final bool paysPension;

  /// (월, 세전 사업소득 수입)
  final List<(int, int)> income;

  /// (월, 세전 기타소득 수입)
  final List<(int, int)> otherIncome;

  /// (월, 금액, 사업경비 여부)
  final List<(int, int, bool)> expenses;

  const F(
    this.name, {
    required this.occ,
    this.dependents = 0,
    this.disabledDeps = 0,
    this.selfDisability = false,
    this.yellowUmbrella = 0,
    this.childrenForCredit = 0,
    this.newborn = 0,
    this.paysPension = false,
    required this.income,
    this.otherIncome = const [],
    required this.expenses,
  });
}

const freelancers = <F>[
  F('①  1인미디어 · 연환산 3,600만 — 단순경비율 기본율만',
      occ: '940306',
      income: [(5, 3000000), (6, 3000000), (7, 3000000)],
      expenses: [(5, 500000, true), (6, 400000, true), (7, 300000, false)]),
  F('②  1인미디어 · 연환산 9,600만 — 4,000만 초과분 초과율',
      occ: '940306',
      income: [(5, 8000000), (6, 8000000), (7, 8000000)],
      expenses: [(5, 2000000, true), (6, 2000000, true), (7, 1500000, true)]),
  F('③  연환산 4,000만 정확히 — 기본율·초과율 경계',
      occ: '940306',
      income: [(5, 3333334), (6, 3333333), (7, 3333333)],
      expenses: [(5, 500000, true), (6, 500000, true), (7, 500000, true)]),
  F('④  부양 3 · 노란우산 600만 한도 초과 납입',
      occ: '940306',
      dependents: 3,
      yellowUmbrella: 8000000,
      income: [(5, 4000000), (6, 4000000), (7, 4000000)],
      expenses: [(5, 800000, true), (6, 800000, true), (7, 800000, true)]),
  F('⑤  사업소득금액 6,000만 초과 — 노란우산 한도 400만 구간',
      occ: '940306',
      yellowUmbrella: 6000000,
      income: [(5, 20000000), (6, 20000000), (7, 20000000)],
      expenses: [(5, 3000000, true), (6, 3000000, true), (7, 3000000, true)]),
  F('⑥  본인 장애 + 부양 장애 1 — 추가공제 400만',
      occ: '940306',
      dependents: 1,
      disabledDeps: 1,
      selfDisability: true,
      income: [(5, 5000000), (6, 5000000), (7, 5000000)],
      expenses: [(5, 1000000, true), (6, 1000000, true), (7, 1000000, true)]),
  F('⑦  기타소득 혼재 · 기타소득금액 300만 이하 — 분리과세 선택 가능',
      occ: '940306',
      income: [(5, 4000000), (6, 4000000), (7, 4000000)],
      otherIncome: [(6, 1500000)],
      expenses: [(5, 600000, true), (6, 600000, true), (7, 600000, true)]),
  F('⑧  기타소득금액 300만 초과 — 무조건 종합과세',
      occ: '940306',
      income: [(5, 4000000), (6, 4000000), (7, 4000000)],
      otherIncome: [(5, 8000000), (6, 8000000), (7, 8000000)],
      expenses: [(5, 600000, true), (6, 600000, true), (7, 600000, true)]),
  F('⑨  저소득 — 결정세액 0원',
      occ: '940306',
      income: [(5, 1200000), (6, 1200000), (7, 1200000)],
      expenses: [(5, 200000, true), (6, 200000, true), (7, 150000, true)]),
  F('⑩  국민연금 지역가입 · 자녀 2 · 출산 1',
      occ: '940306',
      dependents: 2,
      childrenForCredit: 2,
      newborn: 1,
      paysPension: true,
      income: [(5, 6000000), (6, 6000000), (7, 6000000)],
      expenses: [(5, 1200000, true), (6, 1200000, true), (7, 1200000, true)]),
  F('⑪  배우 등(940302) · 경비율이 크게 다른 업종',
      occ: '940302',
      dependents: 1,
      income: [(5, 4500000), (6, 4500000), (7, 4500000)],
      expenses: [(5, 900000, true), (6, 900000, true), (7, 900000, true)]),
  F('⑫  학원강사(940903) · 연환산 1억 2,000만 — 35% 구간',
      occ: '940903',
      dependents: 2,
      income: [(5, 10000000), (6, 10000000), (7, 10000000)],
      expenses: [(5, 2500000, true), (6, 2500000, true), (7, 2500000, true)]),
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
  const months = 3; // 5·6·7월 3개월 입력

  test('프리랜서 12인 — 추계 종소세가 조문 검산과 일치한다', () async {
    for (final p in freelancers) {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
      await dbService.saveProfile({
        'user_type': '프리랜서',
        'occupation_code': p.occ,
        'dependents': p.dependents,
        'disabled_dependent_count': p.disabledDeps,
        'has_self_disability': p.selfDisability,
        'yellow_umbrella': p.yellowUmbrella,
        'children_count_credit': p.childrenForCredit,
        'newborn_count': p.newborn,
        'newborn_year': p.newborn > 0 ? year : 0,
        'pension_enrolled': p.paysPension,
      });
      for (final (m, amt) in p.income) {
        await dbService.insertIncomeEntry(IncomeEntry(
            id: 'i$m', date: DateTime(year, m, 10), amount: amt, memo: '',
            incomeType: '사업소득', isWithheld: false, userType: '프리랜서'));
      }
      for (final (m, amt) in p.otherIncome) {
        await dbService.insertIncomeEntry(IncomeEntry(
            id: 'o$m', date: DateTime(year, m, 11), amount: amt, memo: '',
            incomeType: '기타소득', isWithheld: false, userType: '프리랜서'));
      }
      for (final (m, amt, biz) in p.expenses) {
        await dbService.insertExpense(ExpenseItem(
            id: 'e$m-$amt', date: DateTime(year, m, 15), amount: amt, content: '',
            category: '기타', paymentMethod: '신용카드', isBusiness: biz,
            userType: '프리랜서'));
      }
      expect(p.income.map((e) => e.$1).toSet().length, greaterThanOrEqualTo(3),
          reason: '${p.name}: 가계부 수입은 3개월 이상');
      expect(p.expenses.map((e) => e.$1).toSet().length, greaterThanOrEqualTo(3),
          reason: '${p.name}: 가계부 지출은 3개월 이상');

      // ── 가계부에서 누적을 읽는다 ──
      double accIncome = 0, accOther = 0;
      for (int m = 1; m <= 12; m++) {
        for (final e in await dbService.getIncomeEntriesForMonth(year, m, userType: '프리랜서')) {
          if (e.incomeType == '사업소득') accIncome += e.amount;
          if (e.incomeType == '기타소득') accOther += e.amount;
        }
      }

      final r = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: accIncome,
        accumulatedOtherIncome: accOther,
        inputMonths: months,
        allowanceCount: p.dependents,
        occupationCode: p.occ,
        yellowUmbrellaPayment: p.yellowUmbrella,
        childrenCountForCredit: p.childrenForCredit,
        newbornCount: p.newborn,
        disabledDependentCount: p.disabledDeps,
        hasSelfDisability: p.selfDisability,
        paysNationalPension: p.paysPension,
      );

      // ── ① 연환산 (누적 ÷ 개월 × 12) ──
      final annual = accIncome / months * 12;
      expect(r.annualEstimatedIncome, closeTo(annual, 0.01), reason: '${p.name}: 연환산 수입');

      // ── ② 단순경비율 — 시행령 §143③1의2: 4,000만 이하 기본율, 초과분 초과율 ──
      final occ = OccupationData.occupations[p.occ]!;
      final base = occ.simpleBaseRate / 100.0;
      final excess = occ.simpleExcessRate == 0 ? base : occ.simpleExcessRate / 100.0;
      final refExpense = annual <= 40000000
          ? annual * base
          : 40000000 * base + (annual - 40000000) * excess;
      expect(r.estimatedExpense, closeTo(refExpense, 0.01), reason: '${p.name}: 단순경비율 필요경비');
      expect(r.estimatedBusinessIncome, closeTo(annual - refExpense, 0.01),
          reason: '${p.name}: 사업소득금액');

      // ── ③ 소득공제 — §50① 150만/인 · §51① 장애인 200만 · 조특법 §86의3 노란우산 ──
      final bizIncome = annual - refExpense;
      final refYellowLimit = bizIncome <= 40000000
          ? 6000000.0
          : bizIncome <= 60000000
              ? 5000000.0
              : bizIncome <= 100000000
                  ? 4000000.0
                  : 2000000.0;
      final refYellow =
          p.yellowUmbrella < refYellowLimit ? p.yellowUmbrella : refYellowLimit;
      expect(r.yellowUmbrellaLimit, closeTo(refYellowLimit, 0.01),
          reason: '${p.name}: 노란우산 한도');
      expect(r.yellowUmbrellaDeduction, closeTo(refYellow, 0.01),
          reason: '${p.name}: 노란우산 공제액');

      final refPersonal = (p.dependents + 1) * 1500000.0;
      final refDisability = (p.disabledDeps + (p.selfDisability ? 1 : 0)) * 2000000.0;
      final refTotalDeduction =
          refPersonal + refDisability + refYellow + r.pensionPremiumDeduction;
      expect(r.totalDeduction, closeTo(refTotalDeduction, 0.01),
          reason: '${p.name}: 소득공제 합계');

      // ── ④ 기타소득 — 시행령 §87 필요경비 60% 정률, §14③8 300만 이하 분리과세 선택 ──
      final annualOther = accOther / months * 12;
      final refOtherAmount = refOtherIncomeAmount(annualOther);
      if (refOtherAmount > 3000000) {
        expect(r.otherIncomeComprehensive, isTrue,
            reason: '${p.name}: 기타소득금액 300만 초과는 종합과세 강제(§14③8)');
      }
      final includedOther = r.otherIncomeComprehensive ? refOtherAmount : 0.0;
      if (r.otherIncomeComprehensive) {
        expect(r.otherIncomeAmount, closeTo(refOtherAmount, 0.01),
            reason: '${p.name}: 기타소득금액 = 수입 × 40%');
      }

      // ── ⑤ 과세표준 · 산출세액 (§55①) ──
      final refBase =
          (bizIncome + includedOther - refTotalDeduction).clamp(0.0, double.infinity);
      expect(r.taxBase, closeTo(refBase, 0.01), reason: '${p.name}: 과세표준');
      expect(r.calculatedTax, closeTo(refProgressiveTax(refBase), 0.01),
          reason: '${p.name}: 산출세액');

      // ── ⑥ 결정세액 — 표준세액공제 7만(§59의4⑨) + 자녀세액공제(§59의2) ──
      final refChild =
          refChildTaxCredit(children: p.childrenForCredit, newborn: p.newborn);
      expect(r.childTaxCredit, closeTo(refChild, 0.01), reason: '${p.name}: 자녀세액공제');
      expect(r.taxCredit, 70000.0, reason: '${p.name}: 표준세액공제는 언제나 7만원');
      final refIncomeTax =
          (refProgressiveTax(refBase) - 70000 - refChild).clamp(0.0, double.infinity);
      expect(r.annualIncomeTax, closeTo(trunc10(refIncomeTax), 0.01),
          reason: '${p.name}: 종합소득세 결정세액');
      // 지방소득세는 소득세의 10% (지방세법 §92).
      expect(r.annualLocalTax, closeTo(trunc10(refIncomeTax * 0.1), 0.01),
          reason: '${p.name}: 지방소득세');

      // ── ⑦ 기납부세액 — 사업 3.3%(§127) · 기타 8.8%(§129①6) ──
      final refPaid = trunc10(accIncome * 0.03) + trunc10(accIncome * 0.003);
      final refPaidOther = r.otherIncomeComprehensive
          ? trunc10(accOther * 0.08) + trunc10(accOther * 0.008)
          : 0.0;
      expect(r.paidTotalWithholding, closeTo(refPaid + refPaidOther, 0.01),
          reason: '${p.name}: 누적 기납부세액');

      // ignore: avoid_print
      print('${p.name}\n    연환산 ${won(annual)} · 경비 ${won(r.estimatedExpense)}'
          ' · 소득금액 ${won(r.estimatedBusinessIncome)}\n'
          '    과세표준 ${won(r.taxBase)}  결정세액 ${won(r.annualTotalTax)}'
          '  환급/납부 ${won(r.expectedRefundOrPayment)}');
    }
  });

  /// 시행령 §143③1 — 기준경비율로 계산한 소득금액은 「단순경비율 소득금액 × 배율」을
  /// 넘을 수 없다(간편장부대상자 2.8배).
  ///
  /// 앱은 기준경비율을 수입에 그대로 곱할 뿐 배율 상한을 걸지 않는다. 기준경비율은
  /// **주요경비(매입·임차료·인건비)를 증빙으로 따로 빼는 것을 전제**한 율이라,
  /// 주요경비를 0으로 두면 소득금액이 과대해진다. 배율 상한이 그 안전판이다.
  ///
  /// 앱의 대상은 인적용역(940xxx) 프리랜서다. 그 범위에서는 단순경비율이 중간대라
  /// 배율이 걸리지 않는 것을 못박는다. 농업·제조처럼 주요경비가 큰 업종은
  /// 상한이 걸리지만 애초에 이 앱의 대상 밖이다(업종 선택기에는 들어 있다).
  test('기준경비율 소득금액에 소득상한배율 2.8배가 걸린다 — 전 업종', () {
    const revenue = 60000000.0; // 연환산 수입 6,000만
    final breached = <String>[];
    int capped = 0;

    for (final e in OccupationData.occupations.entries) {
      final o = e.value;
      if (o.simpleBaseRate <= 0 || o.standardRate <= 0) continue;

      final r = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: revenue,
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: e.key,
        useStandardExpenseRate: true,
      );

      // 조문 상한 = 단순경비율 소득금액 × 2.8
      final simpleExpense = revenue <= 40000000
          ? revenue * (o.simpleBaseRate / 100.0)
          : 40000000 * (o.simpleBaseRate / 100.0) +
              (revenue - 40000000) *
                  ((o.simpleExcessRate == 0 ? o.simpleBaseRate : o.simpleExcessRate) / 100.0);
      final cap = (revenue - simpleExpense) * 2.8;
      final rawStandard = revenue * (1 - o.standardRate / 100.0);

      if (r.estimatedBusinessIncome > cap + 0.01) {
        breached.add('${e.key} ${o.name} '
            '(소득금액 ${won(r.estimatedBusinessIncome)} > 상한 ${won(cap)})');
      }
      if (rawStandard > cap + 0.01) capped++;
    }

    // ignore: avoid_print
    print('연환산 수입 ${won(revenue)} 기준 — 상한이 실제로 걸린 업종 $capped건 '
        '/ 전체 ${OccupationData.occupations.length}건, 상한 위반 ${breached.length}건');
    expect(breached, isEmpty,
        reason: '기준경비율 소득금액이 단순경비율 소득금액의 2.8배를 넘는다 — '
            '시행령 §143③1 소득상한배율 미적용');
    expect(capped, greaterThan(0), reason: '상한이 한 건도 안 걸리면 이 검사가 무의미하다');
  });

  /// 상한이 실제로 세금을 얼마나 바꾸는지 — 앱의 핵심 타깃 업종으로 확인.
  test('보험설계사(940906) — 소득상한배율이 세금을 낮춘다', () {
    const revenue = 60000000.0;
    final o = OccupationData.occupations['940906']!;
    final r = FreelancerTaxCalculator.calculateTaxSimulation(
      accumulatedIncome: revenue,
      inputMonths: 12,
      allowanceCount: 0,
      occupationCode: '940906',
      useStandardExpenseRate: true,
    );
    final simpleIncome = revenue -
        (40000000 * (o.simpleBaseRate / 100.0) +
            (revenue - 40000000) * (o.simpleExcessRate / 100.0));
    final cap = simpleIncome * 2.8;
    final uncapped = revenue * (1 - o.standardRate / 100.0);

    // ignore: avoid_print
    print('보험설계사 수입 ${won(revenue)} — 상한 미적용 소득금액 ${won(uncapped)}'
        ' → 상한 ${won(cap)} (차이 ${won(uncapped - cap)})');
    expect(uncapped, greaterThan(cap), reason: '이 업종은 상한이 걸리는 업종이어야 한다');
    expect(r.estimatedBusinessIncome, closeTo(cap, 0.01),
        reason: '상한이 적용된 소득금액이어야 한다');
  });
}
