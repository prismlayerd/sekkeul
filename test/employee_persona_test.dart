import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/core/data/ledger_profile.dart';
import 'package:secul/core/parsing/correction_report.dart';
import 'package:secul/core/parsing/simplified_data_parser.dart';
import 'package:secul/core/parsing/withholding_parser.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/tax_rates.dart';
import 'package:secul/core/tax_engine/tax_year.dart';

/// 직장인 12인 페르소나 — 내 정보 → 수익지출카드 → 가계부 → 세무도구 전 구간.
///
/// 화면이 부르는 것과 같은 함수를 그대로 호출한다:
/// - 수익지출카드/가계부: estimateCreditCardRefund (카드공제 A/B/C)
/// - 세무도구: buildCorrectionReport (경정청구 추가환급)
///
/// 모든 페르소나는 수입·지출 각각 3개월 이상(이번 달 포함).
class P {
  final String name;
  final double grossIncome;
  final int dependents;
  final int childrenTotal;
  final int children8Plus;
  final bool isHomeless;

  /// (월, 급여액)
  final List<(int, int)> salaries;

  /// (월, 금액, 결제수단)
  final List<(int, int, String)> expenses;

  /// 세무도구 — 간소화 자료(받을 수 있었던 것)
  final GansoDeductions ganso;

  /// 세무도구 — 원천징수영수증(실제 신고한 것)
  final WithholdingReceipt receipt;

  const P(this.name, {
    required this.grossIncome,
    this.dependents = 0,
    this.childrenTotal = 0,
    this.children8Plus = 0,
    this.isHomeless = true,
    required this.salaries,
    required this.expenses,
    this.ganso = const GansoDeductions(),
    this.receipt = const WithholdingReceipt(),
  });
}

/// 총급여로 결정세액을 근사해 원천징수영수증을 만든다 — 경정청구 한도(결정세액)용.
WithholdingReceipt receiptFor(double gross, {
  int claimedMedical = 0,
  int claimedEducation = 0,
  int claimedRent = 0,
  int claimedLifeInsurance = 0,
  int claimedPensionSavings = 0,
  int claimedDonation = 0,
}) {
  final labor = gross - EmployeeTaxCalculator.calculateLaborDeduction(gross);
  final base = (labor - 1500000).clamp(0, double.infinity).toDouble();
  final raw = TaxRates.calculateTax(base);
  final credit =
      EmployeeTaxCalculator.calculateLaborTaxCredit(grossIncome: gross, calculatedTaxShare: raw);
  final calc = (raw - credit).clamp(0, double.infinity).toDouble();
  return WithholdingReceipt(
    accrualYear: TaxYear.reference,
    grossSalary: gross.round(),
    taxableBase: base.round(),
    calculatedTax: calc.round(),
    decidedTax: calc.round(),
    claimedMedical: claimedMedical,
    claimedEducation: claimedEducation,
    claimedRent: claimedRent,
    claimedLifeInsurance: claimedLifeInsurance,
    claimedPensionSavings: claimedPensionSavings,
    claimedDonation: claimedDonation,
  );
}

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
  final now = DateTime.now();

  // 3개월치 급여를 만든다(이번 달 포함) — 홈 카드가 이번 달만 보므로 필수.
  List<(int, int)> pay(int monthly) {
    final months = <int>{1, (now.month / 2).ceil(), now.month}.toList()..sort();
    while (months.length < 3) {
      months.add(months.last + 1);
    }
    return [for (final m in months.where((m) => m <= now.month)) (m, monthly)];
  }

  final personas = <P>[
    P('① 문턱 미달', grossIncome: 50000000,
      salaries: pay(3500000),
      expenses: [(2, 2000000, '신용카드'), (4, 2000000, '체크+현금'), (7, 2000000, '신용카드')]),

    P('② 문턱 돌파(B)', grossIncome: 50000000,
      salaries: pay(3500000),
      expenses: [(2, 8000000, '신용카드'), (4, 6000000, '체크+현금'), (7, 4000000, '체크+현금')]),

    P('③ 한도 도달(C)', grossIncome: 50000000,
      salaries: pay(3500000),
      expenses: [(2, 20000000, '신용카드'), (4, 20000000, '체크+현금'), (7, 10000000, '체크+현금')]),

    P('④ 자녀2 — 한도 상향', grossIncome: 50000000, dependents: 2,
      childrenTotal: 2, children8Plus: 2,
      salaries: pay(3500000),
      expenses: [(2, 20000000, '신용카드'), (4, 20000000, '체크+현금'), (7, 10000000, '체크+현금')]),

    P('⑤ 고소득 — 한도 250만 계열', grossIncome: 90000000,
      salaries: pay(6000000),
      expenses: [(2, 20000000, '신용카드'), (4, 20000000, '체크+현금'), (7, 15000000, '체크+현금')]),

    P('⑥ 고소득+자녀1', grossIncome: 90000000, dependents: 1,
      childrenTotal: 1, children8Plus: 0,
      salaries: pay(6000000),
      expenses: [(2, 20000000, '신용카드'), (4, 20000000, '체크+현금'), (7, 15000000, '체크+현금')]),

    P('⑦ 저소득 — 결정세액 작음', grossIncome: 18000000,
      salaries: pay(1500000),
      expenses: [(2, 3000000, '신용카드'), (4, 3000000, '체크+현금'), (7, 2000000, '체크+현금')]),

    P('⑧ 기타 결제수단만 — 공제 대상 밖', grossIncome: 50000000,
      salaries: pay(3500000),
      expenses: [(2, 8000000, '기타'), (4, 8000000, '기타'), (7, 5000000, '기타')]),

    // ── 세무도구(경정청구) 검증 ──
    P('⑨ 의료비 누락', grossIncome: 50000000,
      salaries: pay(3500000),
      expenses: [(2, 3000000, '신용카드'), (4, 3000000, '체크+현금'), (7, 2000000, '신용카드')],
      ganso: const GansoDeductions(medical: 5000000, medicalReimbursed: 500000)),

    P('⑩ 월세 누락(무주택)', grossIncome: 50000000, isHomeless: true,
      salaries: pay(3500000),
      expenses: [(2, 3000000, '신용카드'), (4, 3000000, '체크+현금'), (7, 2000000, '신용카드')],
      ganso: const GansoDeductions(rent: 9000000)),

    P('⑪ 월세 있으나 고소득(대상 제외)', grossIncome: 85000000, isHomeless: true,
      salaries: pay(6500000),
      expenses: [(2, 5000000, '신용카드'), (4, 5000000, '체크+현금'), (7, 3000000, '신용카드')],
      ganso: const GansoDeductions(rent: 9000000)),

    P('⑫ 전부 신고 완료 — 누락 없음', grossIncome: 50000000,
      salaries: pay(3500000),
      expenses: [(2, 3000000, '신용카드'), (4, 3000000, '체크+현금'), (7, 2000000, '신용카드')],
      ganso: const GansoDeductions(lifeInsurance: 1000000, pensionSavings: 6000000)),
  ];

  test('직장인 12인 — 내 정보 / 수익지출카드 / 가계부 / 세무도구', () async {
    for (final p in personas) {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
      await dbService.saveProfile({
        'user_type': '직장인',
        'gross_income': p.grossIncome,
        'dependents': p.dependents,
        'children_count_total': p.childrenTotal,
        'children_count_8plus': p.children8Plus,
        'is_monthly_rent': p.isHomeless,
        'owns_house': !p.isHomeless,
      });

      final sal = p.salaries.where((e) => e.$1 <= now.month).toList();
      final exp = p.expenses.where((e) => e.$1 <= now.month).toList();
      for (final (m, amt) in sal) {
        await dbService.insertIncomeEntry(IncomeEntry(
          id: 's$m-$amt', date: DateTime(now.year, m, 25),
          amount: amt, memo: '', incomeType: '급여', userType: '직장인'));
      }
      for (final (m, amt, pm) in exp) {
        await dbService.insertExpense(ExpenseItem(
          id: 'e$m-$amt-$pm', date: DateTime(now.year, m, 15),
          amount: amt, content: '', category: '기타', paymentMethod: pm,
          isBusiness: false, userType: '직장인'));
      }

      // ── 가계부·홈이 쓰는 연 누적 집계 (home_screen._loadMonthlyExpenses 규칙) ──
      double creditYtd = 0, debitYtd = 0, thisMonthExp = 0, thisMonthSalary = 0;
      for (final (m, amt, pm) in exp) {
        if (pm == '신용카드') creditYtd += amt;
        if (pm == '체크+현금') debitYtd += amt;
        if (m == now.month) thisMonthExp += amt;
      }
      for (final (m, amt) in sal) {
        if (m == now.month) thisMonthSalary += amt;
      }

      final cc = EmployeeTaxCalculator.estimateCreditCardRefund(
        grossAnnual: p.grossIncome,
        dependentsIncludingSelf: 1 + p.dependents,
        creditCardYtd: creditYtd,
        debitCashYtd: debitYtd,
        childrenCount: p.childrenTotal,
      );

      final String stage;
      if (cc.totalEligibleSpend < cc.threshold || cc.taxSaving <= 0) {
        stage = 'A(문턱 전)';
      } else if (cc.isCapped) {
        stage = 'C(한도 도달)';
      } else {
        stage = 'B(자람)';
      }

      // 원천징수영수증은 총급여에 맞춰 만든다 — 총급여가 0이면 의료비 3% 문턱과
      // 연금저축·월세 공제율 구간을 판정할 수 없어 엔진이 빈 결과를 낸다.
      final receipt = p.receipt.grossSalary > 0 ? p.receipt : receiptFor(p.grossIncome);
      final report = buildCorrectionReport(p.ganso, receipt, isHomeless: p.isHomeless);

      // ignore: avoid_print
      print('\n═══ ${p.name} ═══');
      // ignore: avoid_print
      print(' [내 정보]  예상연봉=${won(p.grossIncome)}  부양=${p.dependents}명'
          '  자녀=${p.childrenTotal}명(8세+ ${p.children8Plus})  무주택=${p.isHomeless}');
      // ignore: avoid_print
      print(' [수익지출카드] 이번 달 수령액 ${won(thisMonthSalary)}   지출 ${won(thisMonthExp)}');
      // ignore: avoid_print
      print(' [가계부·카드공제] $stage  문턱=${won(cc.threshold)}  누적=${won(cc.totalEligibleSpend)}');
      // ignore: avoid_print
      print('                  신용=${won(creditYtd)} 체크·현금=${won(debitYtd)}'
          '  공제=${won(cc.deduction)}  환급=${won(cc.taxSaving)}');
      // ignore: avoid_print
      print(' [세무도구]   누락 ${report.lines.length}건'
          '  추가환급=${won(report.additionalRefund)}  (결정세액 ${won(report.decidedTax)})');
      for (final l in report.lines) {
        // ignore: avoid_print
        print('              · ${l.category}: 가능 ${won(l.available)} / 신고 ${won(l.claimed)}'
            ' → +${won(l.missedCredit)}');
      }

      // ── 유형 경계 ──
      final lp = LedgerProfile.of('직장인');
      expect(lp.showsCardThreshold, isTrue);
      expect(lp.tracksBusinessExpense, isFalse);

      // ── 값 불변식 ──
      expect(cc.taxSaving, greaterThanOrEqualTo(0));
      expect(cc.threshold, closeTo(p.grossIncome * 0.25, 1),
          reason: '${p.name}: 문턱은 총급여의 25%');
      final expectedLimit = EmployeeTaxCalculator.creditCardBaseLimit(
          grossIncome: p.grossIncome, childrenCount: p.childrenTotal);
      expect(cc.deduction, lessThanOrEqualTo(expectedLimit + 1),
          reason: '${p.name}: 카드공제만 쓰면 기본한도가 상한');
      // 추가환급은 이미 낸 세금(결정세액)을 넘을 수 없다 — 결정세액 0원 법칙.
      expect(report.additionalRefund, lessThanOrEqualTo(report.decidedTax),
          reason: '${p.name}: 낸 것보다 더 돌려받을 수 없다');
      expect(report.additionalRefund, greaterThanOrEqualTo(0));
      // 입력 커버리지
      expect(sal.map((e) => e.$1).toSet().length, greaterThanOrEqualTo(3),
          reason: '${p.name}: 급여 3개월 이상');
      expect(exp.map((e) => e.$1).toSet().length, greaterThanOrEqualTo(3),
          reason: '${p.name}: 지출 3개월 이상');
      expect(thisMonthSalary, greaterThan(0), reason: '${p.name}: 이번 달 급여 필요');
      expect(thisMonthExp, greaterThan(0), reason: '${p.name}: 이번 달 지출 필요');
    }
  });

  test('월세 세액공제 소득요건 — 총급여 8천 초과면 대상 아님 (조특법 §95의2)', () {
    const ganso = GansoDeductions(rent: 9000000);
    final under = buildCorrectionReport(ganso, receiptFor(50000000), isHomeless: true);
    final over = buildCorrectionReport(ganso, receiptFor(85000000), isHomeless: true);
    final owner = buildCorrectionReport(ganso, receiptFor(50000000), isHomeless: false);

    // ignore: avoid_print
    print('\n[월세 게이트] 총급여 5,000만=${won(under.additionalRefund)}'
        '  8,500만=${won(over.additionalRefund)}  유주택=${won(owner.additionalRefund)}');
    expect(under.lines.any((l) => l.category == '월세액'), isTrue);
    expect(over.lines.any((l) => l.category == '월세액'), isFalse,
        reason: '총급여 8,000만 초과는 월세 세액공제 대상이 아니다');
    expect(owner.lines.any((l) => l.category == '월세액'), isFalse,
        reason: '무주택이 아니면 대상이 아니다');
  });

  test('총급여를 못 읽으면 빈 결과 — 의료비 3% 문턱이 0이 되어 과대 계산되던 것', () {
    const ganso = GansoDeductions(medical: 5000000, medicalReimbursed: 500000);
    // 총급여 0인 영수증(파싱 실패). 예전엔 문턱 0이라 450만 전액에 15%가 붙었다.
    final broken = buildCorrectionReport(
        ganso, const WithholdingReceipt(accrualYear: 2025, decidedTax: 3000000));
    final ok = buildCorrectionReport(ganso, receiptFor(50000000));
    // ignore: avoid_print
    print('\n[총급여 미상] 빈 결과=${won(broken.additionalRefund)} (${broken.lines.length}건)'
        '  vs 정상=${won(ok.additionalRefund)} (${ok.lines.length}건)');
    expect(broken.lines, isEmpty, reason: '근거 없는 금액을 내면 안 된다');
    expect(broken.additionalRefund, 0);
    // 정상 케이스는 3% 문턱(150만)이 빠진 뒤 15%가 적용된다.
    final medical = ok.lines.firstWhere((l) => l.category == '의료비');
    expect(medical.missedCredit, closeTo((4500000 - 1500000) * 0.15, 1),
        reason: '(450만 − 총급여 3% 150만) × 15%');
  });

  test('추가환급은 결정세액을 넘지 못한다 — 결정세액 0원 법칙', () {
    const ganso = GansoDeductions(
        medical: 20000000, education: 10000000, donation: 10000000,
        pensionSavings: 6000000, lifeInsurance: 1000000);
    // 결정세액이 아주 작은 저소득자
    final r = buildCorrectionReport(ganso, receiptFor(20000000), isHomeless: false);
    // ignore: avoid_print
    print('[환급 상한] 누락합계가 커도 추가환급=${won(r.additionalRefund)}'
        ' ≤ 결정세액 ${won(r.decidedTax)}');
    expect(r.additionalRefund, lessThanOrEqualTo(r.decidedTax));
  });
}
