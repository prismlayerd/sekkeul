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

    // 적립 카드의 "올해 쌓인 예상 환급" 카운터는 세액 감소분을 환급 증가분으로 쓴다.
    // 프리랜서는 신용카드 소득공제 대상이 아니라(직장인 전용) 이 기전으로 자란다.
    group('환급 증가분 = 세액 감소분 (A/B/C 카운터 근거)', () {
      test('기납부 3.3%는 신고방식과 무관하게 같다 — 그래서 세액이 준 만큼 환급이 는다', () {
        final r = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
          accumulatedIncome: 50000000,
          accumulatedActualExpense: 45000000,
          inputMonths: 12,
          allowanceCount: 0,
          occupationCode: occCode,
        );
        // 원천징수는 수입에만 걸리므로 경비를 얼마로 잡든 동일해야 한다.
        expect(r.bookkeeping.annualEstimatedTotalWithholding,
            closeTo(r.estimate.annualEstimatedTotalWithholding, 1));
        // 따라서 환급 차이와 세액 차이가 일치한다.
        final refundGain = r.bookkeeping.expectedRefundOrPayment -
            r.estimate.expectedRefundOrPayment;
        final taxDrop = r.estimate.annualTotalTax - r.bookkeeping.annualTotalTax;
        expect(refundGain, closeTo(taxDrop, 1));
      });

      test('기타소득을 합산해도 등가는 유지된다 — 8.8% 원천징수도 신고방식과 무관', () {
        final r = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
          accumulatedIncome: 50000000,
          accumulatedOtherIncome: 6000000,
          accumulatedActualExpense: 40000000,
          inputMonths: 12,
          allowanceCount: 0,
          occupationCode: occCode,
        );
        expect(r.bookkeeping.annualEstimatedTotalWithholding,
            closeTo(r.estimate.annualEstimatedTotalWithholding, 1));
        final refundGain = r.bookkeeping.expectedRefundOrPayment -
            r.estimate.expectedRefundOrPayment;
        final taxDrop = r.estimate.annualTotalTax - r.bookkeeping.annualTotalTax;
        expect(refundGain, closeTo(taxDrop, 1));
      });

      test('소득공제(부양가족·노란우산)를 반영하면 격차가 줄어든다 — 미반영 시 환급 과대', () {
        double gapWith({int allowance = 0, double umbrella = 0}) {
          final r = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
            accumulatedIncome: 50000000,
            accumulatedActualExpense: 40000000,
            inputMonths: 12,
            allowanceCount: allowance,
            occupationCode: occCode,
            yellowUmbrellaPayment: umbrella,
          );
          return r.estimate.annualTotalTax - r.bookkeeping.annualTotalTax;
        }

        final bare = gapWith();
        expect(gapWith(allowance: 2), lessThan(bare));
        expect(gapWith(umbrella: 3000000), lessThan(bare));
      });

      test('결정세액이 0이 되면 환급 증가분이 추계 세액에서 멈춘다 — C단계 상한', () {
        final r = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
          accumulatedIncome: 50000000,
          accumulatedActualExpense: 49000000, // 경비를 극단적으로 크게
          inputMonths: 12,
          allowanceCount: 0,
          occupationCode: occCode,
        );
        expect(r.bookkeeping.annualTotalTax, 0);
        // 낸 것보다 더 돌려받을 수 없으므로 이득은 추계 세액이 상한이다.
        final gain = r.estimate.annualTotalTax - r.bookkeeping.annualTotalTax;
        expect(gain, r.estimate.annualTotalTax);
      });
    });

    // "○○원 더 찾으면 환급이 쌓이기 시작해요"(A단계)는 아래 성질에 기댄다:
    // 추계가 인정하는 경비(estimate.estimatedExpense)가 곧 분기점이라는 것.
    // 이게 깨지면 카드가 잘못된 목표 금액을 알려주게 된다.
    group('분기점 = 추계 경비 (A단계 목표 금액 근거)', () {
      const income = 50000000.0;

      double taxAt(double expense) => FreelancerTaxCalculator
          .compareBookkeepingVsEstimate(
            accumulatedIncome: income,
            accumulatedActualExpense: expense,
            inputMonths: 12,
            allowanceCount: 0,
            occupationCode: occCode,
          )
          .bookkeeping
          .annualTotalTax;

      final probe = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
        accumulatedIncome: income,
        accumulatedActualExpense: 0,
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: occCode,
      );
      final breakeven = probe.estimate.estimatedExpense;
      final estimateTax = probe.estimate.annualTotalTax;

      test('추계 경비와 똑같이 기록하면 두 방식의 세액이 같다', () {
        expect(breakeven, greaterThan(0));
        expect(taxAt(breakeven), closeTo(estimateTax, 1));
      });

      test('분기점을 넘기면 간편장부가 유리해진다', () {
        final r = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
          accumulatedIncome: income,
          accumulatedActualExpense: breakeven + 1000000,
          inputMonths: 12,
          allowanceCount: 0,
          occupationCode: occCode,
        );
        expect(r.bookkeepingIsBetter, isTrue);
        expect(r.bookkeeping.annualTotalTax, lessThan(estimateTax));
      });

      test('분기점에 못 미치면 추계가 유리하다', () {
        final r = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
          accumulatedIncome: income,
          accumulatedActualExpense: breakeven - 1000000,
          inputMonths: 12,
          allowanceCount: 0,
          occupationCode: occCode,
        );
        expect(r.bookkeepingIsBetter, isFalse);
        expect(r.bookkeeping.annualTotalTax, greaterThan(estimateTax));
      });
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
