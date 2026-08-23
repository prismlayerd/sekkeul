import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/freelancer_tax.dart';

/// 법제처 원문과 손으로 맞춰 본 두 자리.
///
/// 둘 다 **엔진이 조문보다 세금을 많이 매기던** 곳이다. 보수적으로 틀린 것도
/// 틀린 것이다 — 사용자는 받을 수 있는 돈을 못 받는다.
void main() {
  group('조특법 §126의2⑩⑪ — 다 합쳐서 자르고 되돌린다', () {
    test('기본공제가 한도에 못 미쳐도 특례분이 버려지지 않는다', () {
      // 총급여 4천만 → 최저사용금액 1천만.
      // 신용 1천만 + 전통시장 2천만 = 3천만, 초과분 2천만이 전부 전통시장.
      //   ② 1호 = 2,000만 × 40% = 800만
      //   ⑩ 기본한도 300만 → 한도초과금액 500만
      //   ⑪ min(500만, min(800만, 300만)) = 300만
      //   합계 600만
      final r = EmployeeTaxCalculator.calculateCreditCardDeduction(
        grossIncome: 40000000,
        creditCard: 10000000,
        debitCardAndCash: 0,
        traditionalMarket: 20000000,
        publicTransport: 0,
        cultureExpense: 0,
      );
      expect(r.finalDeduction, 6000000,
          reason: '기본·추가 한도를 따로 씌워 더하면 300만으로 깎인다');
    });

    test('특례가 없으면 기본한도에서 끝난다', () {
      // 신용 4천만, 문턱 1천만 → 초과 3천만 × 15% = 450만 → 한도 300만.
      final r = EmployeeTaxCalculator.calculateCreditCardDeduction(
        grossIncome: 40000000,
        creditCard: 40000000,
        debitCardAndCash: 0,
        traditionalMarket: 0,
        publicTransport: 0,
        cultureExpense: 0,
      );
      expect(r.finalDeduction, 3000000);
    });

    test('추가한도는 총급여 7천만 초과면 200만으로 줄어든다', () {
      // 총급여 1억 → 문턱 2,500만. 신용 2,500만 + 대중교통 3,000만.
      // 초과 3,000만이 전부 대중교통 → 1,200만. ⑩ 250만 → 초과 950만.
      // ⑪ min(950만, min(1,200만, 200만)) = 200만 → 450만.
      final r = EmployeeTaxCalculator.calculateCreditCardDeduction(
        grossIncome: 100000000,
        creditCard: 25000000,
        debitCardAndCash: 0,
        traditionalMarket: 0,
        publicTransport: 30000000,
        cultureExpense: 0,
      );
      expect(r.finalDeduction, 4500000);
    });
  });

  group('소득세법 시행령 §55①11의3 — 지역가입자 건보료는 필요경비', () {
    ({double withHealth, double without}) run() {
      const args = (income: 60000000.0, expense: 10000000.0);
      double tax(bool health) => FreelancerTaxCalculator.calculateTaxSimulation(
            accumulatedIncome: args.income,
            inputMonths: 12,
            allowanceCount: 0,
            occupationCode: '940909',
            actualExpense: args.expense,
            paysLocalHealth: health,
          ).annualTotalTax;
      return (withHealth: tax(true), without: tax(false));
    }

    test('장부 신고면 건보료만큼 세금이 준다', () {
      final r = run();
      expect(r.withHealth, lessThan(r.without),
          reason: '건보료를 필요경비에 안 넣으면 프리랜서에게 세금을 더 매긴다');
    });

    test('추계에는 더하지 않는다 — 경비율이 이미 경비를 의제한다', () {
      double tax(bool health) => FreelancerTaxCalculator.calculateTaxSimulation(
            accumulatedIncome: 60000000,
            inputMonths: 12,
            allowanceCount: 0,
            occupationCode: '940909',
            paysLocalHealth: health, // actualExpense 없음 = 추계
          ).annualTotalTax;
      expect(tax(true), tax(false));
    });
  });
}
