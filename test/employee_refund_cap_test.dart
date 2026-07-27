import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/tax_rates.dart';

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

  test('상한은 특별공제 길과 표준세액공제 길 중 작은 쪽이다 (소법 §59의4⑨)', () {
    // 회사가 어느 쪽을 적용했는지 앱은 모르지만, 유리한 쪽을 적용했을 것이다.
    // 특별공제 길로만 잡으면 저소득자의 상한이 높게 나와 환급이 과대해진다.
    double cap(double g) =>
        EmployeeTaxCalculator.estimateDecidedTaxBeforeCredits(grossIncome: g);

    // 총급여 2,400만: 6% 구간이라 보험료 소득공제(약 119만)의 절세액이
    // 13만원에 못 미친다 → 표준 길이 유리 → 상한이 그만큼 낮아진다.
    final low = cap(24000000);
    // ignore: avoid_print
    print('총급여 2,400만 상한 ${won(low)}');
    expect(low, lessThan(280000), reason: '표준 길(약 22만)이 특별 길(약 32만)보다 작다');

    // 중간소득은 보험료 소득공제가 13만원보다 커서 특별 길이 그대로 유지된다.
    final mid = cap(50000000);
    final midSpecialOnly = () {
      final base = EmployeeTaxCalculator.estimateSalaryTaxBase(grossIncome: 50000000);
      final calc = TaxRates.calculateTax(base);
      return calc -
          EmployeeTaxCalculator.calculateLaborTaxCredit(
              grossIncome: 50000000, calculatedTaxShare: calc);
    }();
    expect(mid, closeTo(midSpecialOnly, 1), reason: '이 구간에선 특별공제가 유리해 그대로다');

    // 어떤 총급여에서도 상한은 음수가 아니고 소득이 오르면 같이 오른다.
    double prev = -1;
    for (double g = 5000000; g <= 200000000; g += 2500000) {
      final c = cap(g);
      expect(c, greaterThanOrEqualTo(0));
      expect(c, greaterThanOrEqualTo(prev - 1), reason: '총급여 $g에서 상한이 줄었다');
      prev = c;
    }
  });

  test('낼 세금이 없는 저소득자는 환급도 0', () {
    // 총급여 500만: 근로소득공제(350만)와 본인 인적공제(150만)만으로 과세표준이 0.
    final e = run(5000000, rent: 300000);
    expect(EmployeeTaxCalculator.estimateDecidedTaxBeforeCredits(grossIncome: 5000000), 0);
    expect(e.totalCredit, greaterThan(0), reason: '공제 자체는 잡히지만');
    expect(e.refund, 0, reason: '낸 세금이 없으면 돌려받을 것도 없다');
  });
}
