import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';

/// estimateCreditCardRefund — 홈 "올해 쌓인 예상 환급" 3단계(A/B/C) 회귀.
/// 연봉 4,000만(문턱 1,000만) 기준.
void main() {
  const gross = 40000000.0;

  test('A단계 — 문턱 미달이면 환급 0', () {
    final r = EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: gross, creditCardYtd: 5000000, debitCashYtd: 0,
    );
    expect(r.totalEligibleSpend < r.threshold, isTrue);
    expect(r.taxSaving, 0);
    expect(r.isCapped, isFalse);
  });

  test('B단계 — 문턱 초과·한도 미도달이면 환급 > 0, 미포화', () {
    // 신용 2,000만: 초과 1,000만 × 15% = 공제 150만 (기본한도 300만 미만)
    final r = EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: gross, creditCardYtd: 20000000, debitCashYtd: 0,
    );
    expect(r.taxSaving, greaterThan(0));
    expect(r.isCapped, isFalse);
  });

  test('C단계 — 공제 한도 도달 시 isCapped', () {
    // 체크·현금 2,000만: 초과 1,000만 × 30% = 공제 300만 = 기본한도 → 포화
    final r = EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: gross, creditCardYtd: 0, debitCashYtd: 20000000,
    );
    expect(r.taxSaving, greaterThan(0));
    expect(r.isCapped, isTrue);
  });

  test('연봉 0이면 안전하게 0', () {
    final r = EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: 0, creditCardYtd: 5000000, debitCashYtd: 5000000,
    );
    expect(r.taxSaving, 0);
    expect(r.threshold, 0);
  });
}
