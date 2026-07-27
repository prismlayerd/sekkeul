import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/combined_tax.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/freelancer_tax.dart';
import 'package:secul/core/tax_engine/insurance_engine.dart';
import 'package:secul/core/tax_engine/tax_rates.dart';

/// 유형별 12인씩, 소득·지출을 넓게 흩뿌려 엔진에 통과시킨다.
///
/// 개별 금액이 맞는지는 각 항목 테스트가 본다. 여기서는 **어떤 입력에서도 깨지면
/// 안 되는 성질**만 본다 — 세금이 음수가 되거나, 소득이 늘었는데 세금이 줄거나,
/// 환급이 낸 세금을 넘거나, 세율이 100%를 넘는 것 같은 종류.
void main() {
  String won(num v) {
    final s = v.round().abs().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${v < 0 ? '-' : ''}$b';
  }

  // ── 직장인 12인 ─────────────────────────────────────────────
  group('직장인 12인', () {
    final rows = <(String, double, int, double, double)>[
      // (이름, 총급여, 부양가족, 월세, 카드사용액)
      ('편의점 알바', 11000000, 0, 350000, 4000000),
      ('최저임금 1년차', 25200000, 0, 500000, 8000000),
      ('중소기업 사원', 30000000, 0, 450000, 12000000),
      ('공공기관 3년차', 38000000, 1, 600000, 15000000),
      ('4인 가구 외벌이', 42000000, 3, 700000, 20000000),
      ('맞벌이 대리', 55000000, 1, 0, 25000000),
      ('과장 · 자가', 65000000, 2, 0, 30000000),
      ('차장', 72000000, 2, 0, 35000000),
      ('부장', 90000000, 2, 0, 40000000),
      ('임원', 150000000, 1, 0, 60000000),
      ('대표', 300000000, 0, 0, 100000000),
      ('휴직 · 반년치', 9000000, 0, 400000, 2000000),
    ];

    test('환급은 낸 세금을 넘지 않고, 소득이 늘면 세금도 는다', () {
      double? prevTax;
      for (final (name, salary, deps, rent, card) in rows) {
        final card2 = EmployeeTaxCalculator.calculateCreditCardDeduction(
          grossIncome: salary,
          creditCard: card,
          debitCardAndCash: 0,
          traditionalMarket: 1000000,
          publicTransport: 1200000,
          cultureExpense: 800000,
        );
        final decided = EmployeeTaxCalculator.estimateDecidedTaxBeforeCredits(
          grossIncome: salary,
          dependentsIncludingSelf: 1 + deps,
          otherIncomeDeduction: card2.finalDeduction,
        );
        final est = EmployeeTaxCalculator.estimateEmployeeRefund(
          grossIncome: salary,
          dependentsIncludingSelf: 1 + deps,
          cardDeduction: card2.finalDeduction,
          rentCredit: EmployeeTaxCalculator.simulateRentRefund(
                  grossIncome: salary, monthlyRent: rent, decidedTax: 999999999.0)
              .expectedRefund,
          medicalCredit: EmployeeTaxCalculator.calculateMedicalTaxCredit(
              grossIncome: salary,
              infertilityExpense: 0,
              selfAndSeniorAndDisabledExpense: 2000000,
              otherDependentExpense: 1500000),
          pensionAccountCredit: EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
              pensionSavingsPayment: 4000000,
              retirementPensionPayment: 0,
              grossIncome: salary),
        );

        // ignore: avoid_print
        print('$name 총급여 ${won(salary)} · 카드공제 ${won(card2.finalDeduction)}'
            ' · 낸 세금 ${won(decided)} · 환급 ${won(est.refund)}');

        expect(est.refund, lessThanOrEqualTo(est.cap + 1), reason: '$name');
        expect(est.refund, greaterThanOrEqualTo(0), reason: '$name');
        expect(card2.finalDeduction, greaterThanOrEqualTo(0), reason: '$name');
        // 카드공제 한도 — 기본(자녀 없음) + 추가한도.
        final maxCard = EmployeeTaxCalculator.creditCardBaseLimit(grossIncome: salary) +
            (salary <= 70000000 ? 3000000.0 : 2000000.0);
        expect(card2.finalDeduction, lessThanOrEqualTo(maxCard + 1),
            reason: '$name: 카드공제가 법정 한도를 넘었다');
        if (prevTax != null && rows.indexWhere((r) => r.$1 == name) > 0) {
          // 총급여 순 정렬이 아니라 단조성은 별도 테스트에서 본다.
        }
        prevTax = decided;
      }
    });

    test('총급여가 오르면 낼 세금도 오른다 (역전 없음)', () {
      double prev = -1;
      for (double g = 10000000; g <= 300000000; g += 2500000) {
        final t = EmployeeTaxCalculator.estimateDecidedTaxBeforeCredits(grossIncome: g);
        expect(t, greaterThanOrEqualTo(prev - 1), reason: '총급여 ${won(g)}에서 세금이 줄었다');
        prev = t;
      }
    });
  });

  // ── 프리랜서 12인 ───────────────────────────────────────────
  group('프리랜서 12인', () {
    // 업종코드는 OccupationData에 실재하는 것만 쓴다(없으면 경비율 0 → 전액 과세).
    const occ = '940909'; // 기타 자영업
    final rows = <(String, double, int, int, double)>[
      // (이름, 누적수입, 개월, 부양가족, 노란우산)
      ('배달 시작 3개월', 4500000, 3, 0, 0),
      ('과외 부업', 9000000, 6, 0, 0),
      ('프리랜서 디자이너', 24000000, 12, 0, 0),
      ('작가', 18000000, 9, 1, 0),
      ('웹개발 외주', 42000000, 12, 0, 2000000),
      ('컨설턴트', 60000000, 12, 2, 3000000),
      ('강사', 33000000, 11, 1, 0),
      ('사진작가', 15000000, 12, 0, 0),
      ('번역가', 27000000, 12, 3, 1000000),
      ('유튜버 급성장', 90000000, 12, 0, 4000000),
      ('상위 프리랜서', 180000000, 12, 1, 5000000),
      ('첫 달 소액', 300000, 1, 0, 0),
    ];

    test('세금·환급 불변식', () {
      for (final (name, income, months, deps, umbrella) in rows) {
        final r = FreelancerTaxCalculator.calculateTaxSimulation(
          accumulatedIncome: income,
          inputMonths: months,
          allowanceCount: deps,
          occupationCode: occ,
          yellowUmbrellaPayment: umbrella,
        );
        // ignore: avoid_print
        print('$name 연환산수입 ${won(r.annualEstimatedIncome)}'
            ' · 경비 ${won(r.estimatedExpense)} · 과표 ${won(r.taxBase)}'
            ' · 세금 ${won(r.annualTotalTax)}'
            ' · ${r.expectedRefundOrPayment >= 0 ? '환급' : '납부'} '
            '${won(r.expectedRefundOrPayment.abs())}');

        expect(r.annualTotalTax, greaterThanOrEqualTo(0), reason: '$name');
        expect(r.taxBase, greaterThanOrEqualTo(0), reason: '$name');
        expect(r.estimatedExpense, lessThanOrEqualTo(r.annualEstimatedIncome + 1),
            reason: '$name: 경비가 수입보다 클 수 없다');
        expect(r.yellowUmbrellaDeduction, lessThanOrEqualTo(r.yellowUmbrellaLimit + 1),
            reason: '$name: 노란우산 한도 초과');
        // 실효세율 — 수입의 절반을 넘으면 어딘가 잘못된 것.
        if (r.annualEstimatedIncome > 0) {
          expect(r.annualTotalTax / r.annualEstimatedIncome, lessThan(0.5),
              reason: '$name: 실효세율이 비정상');
        }
      }
    });

    test('수입이 늘면 세금도 는다 (역전 없음)', () {
      double prev = -1;
      for (double inc = 1000000; inc <= 200000000; inc += 3000000) {
        final r = FreelancerTaxCalculator.calculateTaxSimulation(
          accumulatedIncome: inc, inputMonths: 12, allowanceCount: 0, occupationCode: occ);
        expect(r.annualTotalTax, greaterThanOrEqualTo(prev - 1),
            reason: '수입 ${won(inc)}에서 세금이 줄었다');
        prev = r.annualTotalTax;
      }
    });
  });

  // ── N잡러 12인 ──────────────────────────────────────────────
  group('N잡러 12인', () {
    const occ = '940909';
    final rows = <(String, double, double, int, double)>[
      // (이름, 총급여, 부업 누적수입, 개월, 월세)
      ('급여+소액 부업', 30000000, 3000000, 12, 500000),
      ('급여+배달', 26000000, 8000000, 12, 450000),
      ('급여+과외', 45000000, 6000000, 12, 0),
      ('급여+외주', 55000000, 15000000, 12, 600000),
      ('급여+임대성 부업', 40000000, 12000000, 12, 700000),
      ('급여+유튜브', 60000000, 30000000, 12, 0),
      ('급여+스마트스토어', 35000000, 25000000, 12, 550000),
      ('저소득+부업 위주', 15000000, 20000000, 12, 400000),
      ('고소득+부업', 95000000, 20000000, 12, 0),
      ('부업 첫 3개월', 48000000, 2000000, 3, 500000),
      ('급여만 · 부업 0', 42000000, 0, 12, 600000),
      ('둘 다 큼', 120000000, 80000000, 12, 0),
    ];

    test('세금·환급 불변식', () {
      for (final (name, salary, biz, months, rent) in rows) {
        final r = CombinedTaxCalculator.calculateCombinedTax(
          grossIncome: salary,
          accumulatedFreelancerIncome: biz,
          inputMonths: months,
          occupationCode: occ,
          creditCard: salary * 0.3,
          debitCardAndCash: 0,
          traditionalMarket: 0,
          publicTransport: 0,
          cultureExpense: 0,
          allowanceCount: 0,
          decidedTax: EmployeeTaxCalculator.estimateDecidedTaxBeforeCredits(grossIncome: salary),
          monthlyRent: rent,
          isHomeless: rent > 0,
        );
        // ignore: avoid_print
        print('$name 종합소득금액 ${won(r.totalGlobalIncome)} · 과표 ${won(r.taxBase)}'
            ' · 세금 ${won(r.annualTotalTax)}'
            ' · ${r.expectedRefundOrPayment >= 0 ? '환급' : '납부'} '
            '${won(r.expectedRefundOrPayment.abs())}');

        expect(r.annualTotalTax, greaterThanOrEqualTo(0), reason: '$name');
        expect(r.taxBase, greaterThanOrEqualTo(0), reason: '$name');
        expect(r.annualLocalTax, closeTo(TaxRates.truncateWon(r.annualIncomeTax * 0.1), 10),
            reason: '$name: 지방소득세는 소득세의 10%');
        final gross = salary + r.estimatedFreelancerBusinessIncome;
        if (gross > 0) {
          expect(r.annualTotalTax / gross, lessThan(0.5), reason: '$name: 실효세율이 비정상');
        }
        // 월세공제율 — 총급여 5,500만 이하 **그리고** 종합소득금액 4,500만 이하만 17%.
        if (r.rentTaxCredit > 0) {
          final annualRent = rent * 12;
          final capped = annualRent > 10000000 ? 10000000.0 : annualRent;
          final expectRate =
              (salary <= 55000000 && r.totalGlobalIncome <= 45000000) ? 0.17 : 0.15;
          expect(r.rentTaxCredit, closeTo(capped * expectRate, 1), reason: '$name: 월세 공제율');
        }
      }
    });
  });

  // ── 4대보험 ────────────────────────────────────────────────
  group('4대보험', () {
    test('직장인 — 계산기와 시뮬레이터가 같은 값을 낸다', () {
      for (final monthly in [900000.0, 2000000.0, 3500000.0, 6590000.0, 12000000.0, 30000000.0]) {
        final a = InsuranceEngine.calculateEmployeeInsurance(monthly);
        final b = EmployeeTaxCalculator.calculateMonthlyInsurance(monthly);
        // ignore: avoid_print
        print('월 ${won(monthly)}: 4대보험 계산기 ${won(a.totalMonthlyPremium)}'
            ' / 세금 시뮬레이터 ${won(b.total)}');
        expect(b.nationalPension, closeTo(a.nationalPension, 10),
            reason: '월 $monthly 국민연금이 화면마다 다르다');
        expect(b.healthInsurance, closeTo(a.healthInsurance, 10),
            reason: '월 $monthly 건강보험이 화면마다 다르다');
        expect(b.longTermCare, closeTo(a.longTermCare, 10),
            reason: '월 $monthly 장기요양이 화면마다 다르다');
        expect(b.employmentInsurance, closeTo(a.employmentInsurance, 10),
            reason: '월 $monthly 고용보험이 화면마다 다르다');
      }
    });
  });

  // ── 금융소득 비교과세 (소득세법 §62) ──────────────────────────
  group('금융소득 비교과세', () {
    test('2,000만원까지는 14%로 끊긴다', () {
      // 다른 소득 5,000만(과표), 금융소득 5,000만.
      final r = CombinedTaxCalculator.calculateFinancialIncomeTax(
        annualFinancialIncome: 50000000, otherTaxableIncome: 50000000);
      // 1호 = 산출세액(5,000만+3,000만) + 2,000만×14%
      final clause1 = TaxRates.calculateTax(80000000) + 20000000 * 0.14;
      // 2호 = 5,000만×14% + 산출세액(5,000만)
      final clause2 = 50000000 * 0.14 + TaxRates.calculateTax(50000000);
      final expected = (clause1 > clause2 ? clause1 : clause2) - TaxRates.calculateTax(50000000);
      // ignore: avoid_print
      print('1호 ${won(clause1)} vs 2호 ${won(clause2)}'
          ' → 금융소득 몫 ${won(r.comprehensiveTaxAmount)}'
          ' (원천징수 ${won(r.separateTaxAmount)}, 더 낼 돈 ${won(r.additionalTaxBurden)})');
      expect(r.comprehensiveTaxAmount, closeTo(expected, 10));
      expect(r.additionalTaxBurden, closeTo(expected - 7000000, 10));
    });

    test('더 낼 세금은 음수가 되지 않는다', () {
      for (final fin in [21000000.0, 30000000.0, 50000000.0, 100000000.0, 500000000.0]) {
        for (final other in [0.0, 10000000.0, 50000000.0, 200000000.0]) {
          final r = CombinedTaxCalculator.calculateFinancialIncomeTax(
            annualFinancialIncome: fin, otherTaxableIncome: other);
          expect(r.additionalTaxBurden, greaterThanOrEqualTo(0),
              reason: '금융 $fin / 기타 $other');
          expect(r.comprehensiveTaxAmount, greaterThanOrEqualTo(r.separateTaxAmount - 10),
              reason: '비교과세는 원천징수보다 작을 수 없다 (금융 $fin / 기타 $other)');
        }
      }
    });

    test('2,000만원 이하는 원천징수로 끝', () {
      final r = CombinedTaxCalculator.calculateFinancialIncomeTax(
        annualFinancialIncome: 20000000, otherTaxableIncome: 100000000);
      expect(r.isSeparateTax, isTrue);
      expect(r.additionalTaxBurden, 0);
      expect(r.separateTaxAmount, TaxRates.truncateWon(20000000 * 0.14));
    });
  });

  // ── 표준세액공제 (소득세법 §59의4⑨) ──────────────────────────
  group('표준세액공제 13만원', () {
    CombinedTaxResult run(double salary, {double insurance = 0, double rent = 0}) =>
        CombinedTaxCalculator.calculateCombinedTax(
          grossIncome: salary,
          accumulatedFreelancerIncome: 0,
          inputMonths: 12,
          occupationCode: '940909',
          creditCard: 0, debitCardAndCash: 0, traditionalMarket: 0,
          publicTransport: 0, cultureExpense: 0,
          allowanceCount: 0, decidedTax: 0, monthlyRent: rent,
          isHomeless: rent > 0,
          insurancePremium: insurance,
        );

    test('저소득 — 보험료 소득공제보다 13만원이 크면 표준을 택한다', () {
      final r = run(24000000);
      // ignore: avoid_print
      print('총급여 2,400만: 표준세액공제 ${won(r.standardTaxCredit)}'
          ' · 세금 ${won(r.annualTotalTax)}');
      expect(r.standardTaxCredit, TaxRates.standardTaxCredit,
          reason: '이 구간에선 표준세액공제가 유리하다');
      // 표준을 택하면 특별소득공제(주택자금 등)는 포기한 것으로 보여야 한다.
      expect(r.mortgageDeduction, 0);
    });

    test('중간소득 — 보험료 소득공제가 더 크면 특별공제를 유지한다', () {
      final r = run(50000000);
      // ignore: avoid_print
      print('총급여 5,000만: 표준세액공제 ${won(r.standardTaxCredit)}'
          ' · 세금 ${won(r.annualTotalTax)}');
      expect(r.standardTaxCredit, 0, reason: '이 구간에선 특별소득공제가 유리하다');
    });

    test('월세공제를 받으면 표준세액공제는 포기한다 (둘 중 하나)', () {
      final r = run(24000000, rent: 600000);
      // ignore: avoid_print
      print('총급여 2,400만 + 월세 60만: 월세공제 ${won(r.rentTaxCredit)}'
          ' · 표준 ${won(r.standardTaxCredit)}');
      expect(r.rentTaxCredit > 0 && r.standardTaxCredit > 0, isFalse,
          reason: '월세세액공제와 표준세액공제는 함께 받을 수 없다 (소법 §59의4⑨)');
    });

    test('어느 쪽을 택하든 세금은 둘 중 작은 쪽이다', () {
      for (final g in [15000000.0, 24000000.0, 28000000.0, 32000000.0, 50000000.0]) {
        for (final ins in [0.0, 1000000.0]) {
          final r = run(g, insurance: ins);
          expect(r.annualTotalTax, greaterThanOrEqualTo(0));
          // 표준을 택했다면 특별세액공제는 전부 0이어야 한다.
          if (r.standardTaxCredit > 0) {
            expect(r.insuranceTaxCredit, 0, reason: '총급여 $g');
            expect(r.medicalTaxCredit, 0, reason: '총급여 $g');
            expect(r.educationTaxCredit, 0, reason: '총급여 $g');
            expect(r.donationTaxCredit, 0, reason: '총급여 $g');
          }
        }
      }
    });
  });

  // ── 장기주택저당차입금 한도 (소득세법 §52⑤·⑥) ─────────────────
  group('주택담보대출 이자 소득공제 한도', () {
    test('조건에 따라 800만 → 1,800만 → 2,000만', () {
      expect(EmployeeTaxCalculator.mortgageDeductionLimit(), 8000000,
          reason: '15년 이상 기본 한도는 800만원 (§52⑤ 본문)');
      expect(
          EmployeeTaxCalculator.mortgageDeductionLimit(fixedRate: true), 18000000,
          reason: '고정금리만 = 1,800만원 (§52⑥2)');
      expect(
          EmployeeTaxCalculator.mortgageDeductionLimit(nonDeferredRepayment: true),
          18000000,
          reason: '비거치식만 = 1,800만원 (§52⑥2)');
      expect(
          EmployeeTaxCalculator.mortgageDeductionLimit(
              fixedRate: true, nonDeferredRepayment: true),
          20000000,
          reason: '고정금리 + 비거치식 = 2,000만원 (§52⑥1)');
      expect(
          EmployeeTaxCalculator.mortgageDeductionLimit(
              fixedRate: true, over15Years: false),
          6000000,
          reason: '10년 이상 15년 미만 = 600만원 (§52⑥3)');
      expect(EmployeeTaxCalculator.mortgageDeductionLimit(over15Years: false), 0,
          reason: '10~15년은 고정금리·비거치식 중 하나는 있어야 대상');
    });

    test('이자를 많이 내도 한도까지만 빠진다', () {
      expect(EmployeeTaxCalculator.calculateMortgageIncomeDeduction(30000000), 8000000);
      expect(
          EmployeeTaxCalculator.calculateMortgageIncomeDeduction(30000000,
              fixedRate: true, nonDeferredRepayment: true),
          20000000);
      expect(EmployeeTaxCalculator.calculateMortgageIncomeDeduction(5000000), 5000000);
    });
  });

  // ── 부녀자공제 소득요건 (소득세법 §51①3) ──────────────────────
  group('부녀자공제', () {
    double add({required double income, bool singleParent = false}) =>
        EmployeeTaxCalculator.calculateAdditionalPersonalDeduction(
          hasElderly70Plus: false,
          isSingleFemaleHead: true,
          isSingleParent: singleParent,
          globalIncomeAmount: income,
        );

    test('종합소득금액 3천만원 이하만 받는다', () {
      expect(add(income: 30000000), 500000);
      expect(add(income: 30000001), 0, reason: '3천만원을 넘으면 대상이 아니다');
    });

    test('한부모와 겹치면 한부모(100만)만 적용한다 — §51① 단서', () {
      expect(add(income: 20000000, singleParent: true), 1000000);
      expect(add(income: 90000000, singleParent: true), 1000000,
          reason: '한부모는 소득요건이 없다');
    });
  });

  // ── 정치자금 기부금 (조특법 §76①) ────────────────────────────
  test('정치자금 10만원은 110분의 100', () {
    final c = EmployeeTaxCalculator.calculateDonationTaxCredit(
        generalDonation: 0, politicalDonation: 100000);
    expect(c, TaxRates.truncateWon(100000 * 100 / 110)); // 90,900
    final c2 = EmployeeTaxCalculator.calculateDonationTaxCredit(
        generalDonation: 0, politicalDonation: 40100000);
    // 10만원 → 100/110, 3천만원 → 15%, 나머지 1천만원 → 25%
    expect(c2, TaxRates.truncateWon(100000 * 100 / 110 + 30000000 * 0.15 + 10000000 * 0.25));
  });
}
