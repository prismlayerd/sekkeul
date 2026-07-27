import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';

/// 계산기가 약속한 환급액이 그 사람이 실제로 낸 세금을 넘지 않는지 본다.
///
/// 세액공제는 산출세액에서 빼는 것이라, 낼 세금이 없으면 돌려받을 것도 없다
/// (「결정세액 0원 법칙」 — 경정청구 리포트가 이미 지키고 있는 규칙).
/// 상한이 없던 시절 총급여 2,520만원인 사람에게 350만원(실제 33만원)을 약속했다.
void main() {
  String won(num v) {
    final s = v.round().abs().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '$b원';
  }

  /// 화면이 계산기에서 부르는 것과 같은 조합. 공제를 넉넉히 넣어 상한을 시험한다.
  EmployeeRefundEstimate run(double salary, {int dependents = 0, double rent = 0, double paidTax = 0}) {
    final rentCredit = EmployeeTaxCalculator.simulateRentRefund(
            grossIncome: salary, monthlyRent: rent, decidedTax: 999999999.0)
        .expectedRefund;
    final special = EmployeeTaxCalculator.calculateSpecialDeductions(
      grossIncome: salary,
      infertilityMedical: 0,
      selfAndSeniorAndDisabledMedical: 0,
      otherDependentMedical: 4000000,
      childrenEduExpense: 3000000,
      childrenCount: 1,
      generalDonation: 500000,
    );
    return EmployeeTaxCalculator.estimateEmployeeRefund(
      grossIncome: salary,
      dependentsIncludingSelf: 1 + dependents,
      paidTax: paidTax,
      rentCredit: rentCredit,
      medicalCredit: special.medicalTaxCredit,
      educationCredit: special.educationTaxCredit,
      donationCredit: special.donationTaxCredit,
      childCredit: EmployeeTaxCalculator.calculateChildTaxCredit(
          childrenCount: dependents > 0 ? 1 : 0, newbornCount: 0),
      pensionAccountCredit: EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
          pensionSavingsPayment: 6000000,
          retirementPensionPayment: 3000000,
          grossIncome: salary),
      insurancePremiumCredit: EmployeeTaxCalculator.calculateInsurancePremiumTaxCredit(
          generalInsurancePremium: 1000000, disabledInsurancePremium: 0),
    );
  }

  test('계산기가 약속한 환급 ≤ 실제로 낸 세금', () {
    final cases = <(String, double, int, double)>[
      ('최저임금 사회초년생', 25200000, 0, 500000),
      ('중소기업 3년차', 32000000, 0, 450000),
      ('4인 가구 외벌이', 42000000, 3, 600000),
      ('맞벌이 대리', 55000000, 1, 700000),
      ('부장', 90000000, 2, 0),
      ('아르바이트 겸업', 14000000, 0, 400000),
    ];
    for (final (name, salary, deps, rent) in cases) {
      final e = run(salary, dependents: deps, rent: rent);
      // ignore: avoid_print
      print('$name (총급여 ${won(salary)}): 공제 ${won(e.totalCredit)}'
          ' → 환급 ${won(e.refund)} (상한 ${won(e.cap)}${e.isCapped ? ', 걸림' : ''})');
      expect(e.refund, lessThanOrEqualTo(e.cap + 1),
          reason: '$name: 낸 것보다 더 돌려받을 수 없다');
      expect(e.refund, greaterThanOrEqualTo(0));
      // 화면에 그리는 행의 합이 곧 공제 합계여야 한다(행 따로 합계 따로 금지).
      final lineSum = e.lines.fold(0.0, (a, l) => a + l.amount);
      expect(lineSum, closeTo(e.totalCredit, 10),
          reason: '$name: 내역 행의 합이 공제 합계와 달라지면 안 된다');
      expect(e.lines.every((l) => l.amount > 0), isTrue, reason: '0원 항목은 그리지 않는다');
    }
  });

  test('기납부세액을 알면 그 값이 상한이 된다', () {
    final e = run(50000000, rent: 600000, paidTax: 300000);
    expect(e.cap, 300000);
    expect(e.refund, 300000);
    expect(e.capBasis, '기납부세액');
  });

  test('총급여 0 — 근거가 없으면 환급도 0', () {
    final e = run(0);
    expect(e.cap, 0);
    expect(e.refund, 0);
  });

  test('낼 세금이 없는 저소득자는 환급도 0', () {
    // 총급여 500만: 근로소득공제(350만)와 본인 인적공제(150만)만으로 과세표준이 0.
    final e = run(5000000, rent: 300000);
    expect(EmployeeTaxCalculator.estimateDecidedTaxBeforeCredits(grossIncome: 5000000), 0);
    expect(e.totalCredit, greaterThan(0), reason: '공제 자체는 잡히지만');
    expect(e.refund, 0, reason: '낸 세금이 없으면 돌려받을 것도 없다');
  });
}
