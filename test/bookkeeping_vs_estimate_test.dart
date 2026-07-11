import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/freelancer_tax.dart';

/// 간편장부(실제경비) vs 추계(경비율) 비교 (2단계) 검증.
void main() {
  // 1인미디어콘텐츠창작자(940306) — 단순경비율 없음/낮음, 실제경비 유무에 따라 결과가 갈리는 대표 케이스.
  const occCode = '940306';

  group('간편장부 vs 추계 비교', () {
    test('실제경비가 경비율 추정보다 훨씬 크면 간편장부가 유리', () {
      // 940306 단순경비율 추정경비 ≈ 30.61M(4천만×64.1%+1천만×49.7%) — 이를 명확히 넘는 값으로 검증.
      final r = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
        accumulatedIncome: 50000000,
        accumulatedActualExpense: 45000000, // 90% — 경비율 추정보다 확실히 큰 실제 지출
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: occCode,
      );
      expect(r.bookkeeping.estimatedExpense, 45000000);
      expect(r.bookkeepingIsBetter, isTrue);
      expect(r.bookkeeping.annualTotalTax, lessThan(r.estimate.annualTotalTax));
    });

    test('실제경비가 0이면(경비 없음) 추계가 유리하거나 같음', () {
      final r = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
        accumulatedIncome: 50000000,
        accumulatedActualExpense: 0,
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: occCode,
      );
      expect(r.bookkeeping.estimatedExpense, 0);
      expect(r.bookkeepingIsBetter, isFalse);
      expect(r.estimate.annualTotalTax, lessThanOrEqualTo(r.bookkeeping.annualTotalTax));
    });

    test('실제경비는 소득과 같은 방식으로 연환산된다(누적→×12/개월)', () {
      final r = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
        accumulatedIncome: 25000000, // 6개월 누적
        accumulatedActualExpense: 6000000, // 6개월간 실제경비
        inputMonths: 6,
        allowanceCount: 0,
        occupationCode: occCode,
      );
      // 연환산: 6,000,000 / 6 * 12 = 12,000,000
      expect(r.bookkeeping.estimatedExpense, 12000000);
    });

    test('음수 실제경비는 0으로 방어', () {
      final r = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
        accumulatedIncome: 30000000,
        accumulatedActualExpense: -500000,
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: occCode,
      );
      expect(r.bookkeeping.estimatedExpense, 0);
    });

    test('세액공제는 간편장부·추계 모두 표준세액공제(7만원)로 동일 — 기장세액공제 아님', () {
      final r = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
        accumulatedIncome: 50000000,
        accumulatedActualExpense: 10000000,
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: occCode,
      );
      expect(r.bookkeeping.taxCredit, 70000.0);
      expect(r.estimate.taxCredit, 70000.0);
    });
  });
}
