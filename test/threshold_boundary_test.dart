import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/combined_tax.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/freelancer_tax.dart';
import 'package:secul/core/tax_engine/insurance_engine.dart';
import 'package:secul/core/tax_engine/tax_year.dart';
import 'package:secul/core/tax_engine/tax_rates.dart';

/// 소득 구간이 갈리는 **경계값**을 1원 단위로 밟아 본다.
///
/// 세법은 "5,500만원 이하", "7,000만원 초과"처럼 경계를 말로 정한다.
/// 코드가 `<`를 써야 할 곳에 `<=`를 쓰면 딱 그 금액인 사람만 틀린 답을 받는데,
/// 중간값만 넣어 보는 테스트로는 절대 안 걸린다.
///
/// 여기서 보는 것은 두 가지다.
/// 1) **경계가 조문과 같은 쪽에 있는가** (이하 = 포함, 초과 = 불포함)
/// 2) **경계에서 값이 튀지 않는가** — 1원 더 벌었다고 세금이 만원 뛰면 안 된다.
void main() {
  String won(num v) {
    final s = v.round().abs().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '$b';
  }

  group('과세표준 세율 구간 (소법 §55)', () {
    const edges = [14000000, 50000000, 88000000, 150000000, 300000000, 500000000, 1000000000];

    test('경계에서 세액이 튀지 않는다 (누진공제가 맞다)', () {
      for (final e in edges) {
        final at = TaxRates.calculateTax(e.toDouble());
        final next = TaxRates.calculateTax(e + 1.0);
        // ignore: avoid_print
        print('과표 ${won(e)} → ${won(at)} · +1원 → ${won(next)} (차 ${won(next - at)})');
        expect(next - at, lessThan(1.0),
            reason: '과표 $e에서 1원 더 벌었는데 세금이 ${won(next - at)}원 뛴다');
        expect(next, greaterThanOrEqualTo(at), reason: '과표 $e에서 세금이 역전됐다');
      }
    });

    test('경계 금액은 낮은 세율 구간에 든다 ("이하")', () {
      // 1,400만원 "이하" 6% → 딱 1,400만이면 84만원.
      expect(TaxRates.calculateTax(14000000), 840000);
      // 5,000만원 "이하" 15% → 5,000만×15% − 126만.
      expect(TaxRates.calculateTax(50000000), 50000000 * 0.15 - 1260000);
    });
  });

  group('근로소득공제 구간 (소법 §47)', () {
    const edges = [5000000, 15000000, 45000000, 100000000];

    test('경계에서 공제액이 튀지 않는다', () {
      for (final e in edges) {
        final at = EmployeeTaxCalculator.calculateLaborDeduction(e.toDouble());
        final next = EmployeeTaxCalculator.calculateLaborDeduction(e + 1.0);
        // ignore: avoid_print
        print('총급여 ${won(e)} → 근로소득공제 ${won(at)} (+1원 시 ${won(next)})');
        expect((next - at).abs(), lessThan(1.0), reason: '총급여 $e에서 공제가 튄다');
      }
    });

    test('공제 한도 2,000만원을 넘지 않는다', () {
      for (double g = 100000000; g <= 1000000000; g += 25000000) {
        expect(EmployeeTaxCalculator.calculateLaborDeduction(g), lessThanOrEqualTo(20000000));
      }
    });

    test('총급여가 오르면 근로소득금액도 오른다 (공제가 소득을 앞지르지 않는다)', () {
      double prev = -1;
      for (double g = 1000000; g <= 300000000; g += 500000) {
        final amount = g - EmployeeTaxCalculator.calculateLaborDeduction(g);
        expect(amount, greaterThanOrEqualTo(prev - 1), reason: '총급여 $g에서 역전');
        prev = amount;
      }
    });
  });

  group('근로소득세액공제 한도 (소법 §59②)', () {
    test('3,300만 · 7,000만 · 1.2억 경계에서 튀지 않는다', () {
      for (final e in [33000000, 70000000, 120000000]) {
        final at = EmployeeTaxCalculator.calculateLaborTaxCreditLimit(e.toDouble());
        final next = EmployeeTaxCalculator.calculateLaborTaxCreditLimit(e + 1.0);
        // ignore: avoid_print
        print('총급여 ${won(e)} → 근로세액공제 한도 ${won(at)} (+1원 시 ${won(next)})');
        expect((next - at).abs(), lessThan(1.0), reason: '총급여 $e에서 한도가 튄다');
      }
      expect(EmployeeTaxCalculator.calculateLaborTaxCreditLimit(33000000), 740000,
          reason: '3,300만원 "이하"는 74만원');
    });

    test('한도는 20만원 아래로 내려가지 않는다', () {
      for (double g = 120000000; g <= 1000000000; g += 20000000) {
        expect(EmployeeTaxCalculator.calculateLaborTaxCreditLimit(g),
            greaterThanOrEqualTo(200000));
      }
    });
  });

  group('신용카드 공제 (조특법 §126의2)', () {
    test('기본한도는 7,000만원 "이하"까지 300만원', () {
      expect(EmployeeTaxCalculator.creditCardBaseLimit(grossIncome: 70000000), 3000000);
      expect(EmployeeTaxCalculator.creditCardBaseLimit(grossIncome: 70000001), 2500000);
    });

    test('자녀 가산은 이하 구간 50만·초과 구간 25만, 2명에서 멈춘다', () {
      for (final kids in [0, 1, 2, 3, 5]) {
        final capped = kids > 2 ? 2 : kids;
        expect(EmployeeTaxCalculator.creditCardBaseLimit(grossIncome: 70000000, childrenCount: kids),
            3000000 + capped * 500000, reason: '자녀 $kids명 · 7천만 이하');
        expect(EmployeeTaxCalculator.creditCardBaseLimit(grossIncome: 80000000, childrenCount: kids),
            2500000 + capped * 250000, reason: '자녀 $kids명 · 7천만 초과');
      }
    });

    test('추가한도도 7,000만원에서 300만 → 200만으로 갈린다', () {
      CreditCardDeductionResult run(double g) =>
          EmployeeTaxCalculator.calculateCreditCardDeduction(
            grossIncome: g,
            creditCard: 0,
            debitCardAndCash: 0,
            // 추가한도만 시험한다 — 전통시장·대중교통을 한도보다 훨씬 크게 넣는다.
            traditionalMarket: g,
            publicTransport: g,
            cultureExpense: 0,
          );
      final under = run(70000000);
      final over = run(70000001);
      // ignore: avoid_print
      print('추가한도 — 7,000만 ${won(under.finalDeduction)} / +1원 ${won(over.finalDeduction)}');
      expect(under.finalDeduction, 3000000, reason: '7,000만 "이하"는 300만');
      expect(over.finalDeduction, 2000000, reason: '초과는 200만');
    });

    test('문턱은 정확히 총급여의 25%이고, 딱 문턱이면 돌파로 본다', () {
      final r = EmployeeTaxCalculator.calculateCreditCardDeduction(
        grossIncome: 40000000,
        creditCard: 10000000,
        debitCardAndCash: 0,
        traditionalMarket: 0, publicTransport: 0, cultureExpense: 0,
      );
      expect(r.threshold, 10000000);
      expect(r.passedThreshold, isTrue, reason: '"초과분"이 0이어도 문턱은 넘은 것');
      expect(r.finalDeduction, 0, reason: '초과분이 없으니 공제도 0');
    });

    test('쓸수록 공제가 늘고, 한도를 넘지 않는다', () {
      double prev = -1;
      for (double spend = 0; spend <= 200000000; spend += 2000000) {
        final r = EmployeeTaxCalculator.calculateCreditCardDeduction(
          grossIncome: 50000000,
          creditCard: spend,
          debitCardAndCash: 0,
          traditionalMarket: 0, publicTransport: 0, cultureExpense: 0,
        );
        expect(r.finalDeduction, greaterThanOrEqualTo(prev - 1), reason: '지출 $spend에서 역전');
        expect(r.finalDeduction, lessThanOrEqualTo(3000000 + 1));
        prev = r.finalDeduction;
      }
    });
  });

  group('월세 세액공제 (조특법 §95의2)', () {
    test('공제율은 5,500만원 "이하"까지 17%', () {
      expect(EmployeeTaxCalculator.rentCreditRate(55000000), 0.17);
      expect(EmployeeTaxCalculator.rentCreditRate(55000001), 0.15);
    });

    test('자격은 총급여 8,000만원 "이하"까지', () {
      bool ok(double g) => EmployeeTaxCalculator.isRentCreditEligible(
            grossIncome: g,
            globalIncomeAmount: g - EmployeeTaxCalculator.calculateLaborDeduction(g),
            isHomeless: true,
          );
      expect(ok(80000000), isTrue);
      expect(ok(80000001), isFalse);
    });

    test('종합소득금액 7,000만원 "초과"는 제외', () {
      bool ok(double amount) => EmployeeTaxCalculator.isRentCreditEligible(
          grossIncome: 50000000, globalIncomeAmount: amount, isHomeless: true);
      expect(ok(70000000), isTrue);
      expect(ok(70000001), isFalse);
    });

    test('월세액 한도는 연 1,000만원', () {
      final r = EmployeeTaxCalculator.simulateRentRefund(
          grossIncome: 40000000, monthlyRent: 2000000, decidedTax: 999999999);
      expect(r.expectedRefund, TaxRates.truncateWon(10000000 * 0.17));
    });
  });

  group('연금계좌 세액공제 (소법 §59의3)', () {
    test('공제율은 총급여 5,500만원 "이하"까지 15%', () {
      double credit(double g) => EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
          pensionSavingsPayment: 6000000, retirementPensionPayment: 0, grossIncome: g);
      expect(credit(55000000), TaxRates.truncateWon(6000000 * 0.15));
      expect(credit(55000001), TaxRates.truncateWon(6000000 * 0.12));
    });

    test('연금저축 600만·합산 900만 한도', () {
      double credit(double sav, double irp) =>
          EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
              pensionSavingsPayment: sav, retirementPensionPayment: irp, grossIncome: 50000000);
      expect(credit(10000000, 0), TaxRates.truncateWon(6000000 * 0.15), reason: '연금저축 600만 한도');
      expect(credit(6000000, 10000000), TaxRates.truncateWon(9000000 * 0.15), reason: '합산 900만 한도');
    });
  });

  group('의료비 (소법 §59의4②)', () {
    test('문턱은 총급여의 3%이고, 딱 문턱이면 공제가 0', () {
      double credit(double spend) => EmployeeTaxCalculator.calculateMedicalTaxCredit(
            grossIncome: 50000000,
            infertilityExpense: 0,
            selfAndSeniorAndDisabledExpense: 0,
            otherDependentExpense: spend,
          );
      expect(credit(1500000), 0, reason: '3% "초과분"만 공제 대상');
      expect(credit(1500001), TaxRates.truncateWon(1 * 0.15));
    });

    test('일반 부양가족 의료비는 700만원 한도, 본인·난임은 한도 없음', () {
      final capped = EmployeeTaxCalculator.calculateMedicalTaxCredit(
        grossIncome: 50000000,
        infertilityExpense: 0,
        selfAndSeniorAndDisabledExpense: 0,
        otherDependentExpense: 50000000,
      );
      expect(capped, TaxRates.truncateWon(7000000 * 0.15));

      final uncapped = EmployeeTaxCalculator.calculateMedicalTaxCredit(
        grossIncome: 50000000,
        infertilityExpense: 0,
        selfAndSeniorAndDisabledExpense: 50000000,
        otherDependentExpense: 0,
      );
      expect(uncapped, greaterThan(capped), reason: '본인 의료비는 한도가 없다');
    });
  });

  group('기부금 (소법 §59의3 · 조특법 §76·§58)', () {
    test('일반기부금 1,000만 · 3,000만 경계에서 튀지 않는다', () {
      for (final e in [10000000, 30000000]) {
        final at = EmployeeTaxCalculator.calculateDonationTaxCredit(
            generalDonation: e.toDouble(), politicalDonation: 0);
        final next = EmployeeTaxCalculator.calculateDonationTaxCredit(
            generalDonation: e + 1.0, politicalDonation: 0);
        // ignore: avoid_print
        print('기부 ${won(e)} → ${won(at)} (+1원 시 ${won(next)})');
        expect(next - at, lessThan(10.0), reason: '기부금 $e에서 공제가 튄다');
        expect(next, greaterThanOrEqualTo(at));
      }
    });

    test('고향사랑 10만 · 20만 · 2,000만 경계', () {
      double c(double v) => EmployeeTaxCalculator.calculateHometownDonationTaxCredit(v);
      expect(c(100000), TaxRates.truncateWon(100000 * 100 / 110));
      expect(c(200000), TaxRates.truncateWon(100000 * 100 / 110 + 100000 * 0.40));
      // 2,000만원 초과분은 공제 대상이 아니다.
      expect(c(30000000), c(20000000));
      for (final e in [100000, 200000, 20000000]) {
        final at = c(e.toDouble());
        final next = c(e + 1.0);
        expect(next - at, lessThan(10.0), reason: '고향사랑 $e에서 공제가 튄다');
      }
    });
  });

  group('노란우산공제 한도 (조특법 §86의3)', () {
    test('사업소득금액 4,000만 · 6,000만 · 1억 경계', () {
      double limitFor(double businessIncome) {
        // 경비율 0인 업종코드로 두면 총수입 = 사업소득금액이 된다.
        final r = FreelancerTaxCalculator.calculateTaxSimulation(
          accumulatedIncome: businessIncome,
          inputMonths: 12,
          allowanceCount: 0,
          occupationCode: '__없는코드__',
          yellowUmbrellaPayment: 100000000,
        );
        return r.yellowUmbrellaLimit;
      }

      expect(limitFor(40000000), 6000000, reason: '4,000만 "이하" 600만');
      expect(limitFor(40000001), 5000000);
      expect(limitFor(60000000), 5000000, reason: '6,000만 "이하" 500만');
      expect(limitFor(60000001), 4000000);
      expect(limitFor(100000000), 4000000, reason: '1억 "이하" 400만');
      expect(limitFor(100000001), 2000000);
    });
  });

  group('기타소득 · 금융소득', () {
    test('기타소득금액 300만원 "초과"부터 종합과세 의무', () {
      expect(EmployeeTaxCalculator.isOtherIncomeComprehensive(3000000), isFalse);
      expect(EmployeeTaxCalculator.isOtherIncomeComprehensive(3000001), isTrue);
    });

    test('금융소득 2,000만원 "이하"는 분리과세 완납', () {
      final at = CombinedTaxCalculator.calculateFinancialIncomeTax(
          annualFinancialIncome: 20000000, otherTaxableIncome: 50000000);
      final over = CombinedTaxCalculator.calculateFinancialIncomeTax(
          annualFinancialIncome: 20000001, otherTaxableIncome: 50000000);
      expect(at.isSeparateTax, isTrue);
      expect(over.isSeparateTax, isFalse);
      // ignore: avoid_print
      print('금융 2,000만 더 낼 세금 ${won(at.additionalTaxBurden)}'
          ' / +1원 ${won(over.additionalTaxBurden)}');
      expect(over.additionalTaxBurden - at.additionalTaxBurden, lessThan(10.0),
          reason: '2,000만원 경계에서 세부담이 튄다');
    });
  });

  group('부녀자공제 (소법 §51①3)', () {
    test('종합소득금액 3,000만원 "이하"까지', () {
      double add(double income) => EmployeeTaxCalculator.calculateAdditionalPersonalDeduction(
            hasElderly70Plus: false,
            isSingleFemaleHead: true,
            isSingleParent: false,
            globalIncomeAmount: income,
          );
      expect(add(30000000), 500000);
      expect(add(30000001), 0);
    });
  });

  group('국민연금 기준소득월액 상·하한', () {
    test('하한 아래·상한 위에서는 보험료가 고정된다', () {
      final low = InsuranceEngine.calculateEmployeeInsurance(100000).nationalPension;
      final atLow = InsuranceEngine.calculateEmployeeInsurance(
              TaxRates.nationalPensionBaseLowerLimit)
          .nationalPension;
      expect(low, atLow, reason: '하한 미만은 하한으로 부과');

      final high = InsuranceEngine.calculateEmployeeInsurance(50000000).nationalPension;
      final atHigh = InsuranceEngine.calculateEmployeeInsurance(
              TaxRates.nationalPensionBaseUpperLimit)
          .nationalPension;
      expect(high, atHigh, reason: '상한 초과는 상한으로 부과');
      // ignore: avoid_print
      print('국민연금 — 하한 ${won(atLow)} · 상한 ${won(atHigh)}');
    });

    test('월급이 오르면 4대보험도 오른다', () {
      double prev = -1;
      for (double m = 100000; m <= 20000000; m += 100000) {
        final t = InsuranceEngine.calculateEmployeeInsurance(m).totalMonthlyPremium;
        expect(t, greaterThanOrEqualTo(prev - 1), reason: '월급 $m에서 보험료가 줄었다');
        prev = t;
      }
    });
  });

  group('총급여 전 구간 — 1원 더 벌어서 손해 보는 지점이 없다', () {
    test('결정세액 상한이 매끄럽게 오른다', () {
      double prev = -1;
      double worstJump = 0;
      double worstAt = 0;
      for (double g = 5000000; g <= 200000000; g += 100000) {
        final c = EmployeeTaxCalculator.estimateDecidedTaxBeforeCredits(grossIncome: g);
        expect(c, greaterThanOrEqualTo(prev - 1), reason: '총급여 $g에서 역전');
        if (prev >= 0 && c - prev > worstJump) {
          worstJump = c - prev;
          worstAt = g;
        }
        prev = c;
      }
      // ignore: avoid_print
      print('10만원 구간당 최대 상승폭 ${won(worstJump)}원 (총급여 ${won(worstAt)} 부근)');
      // 10만원을 더 벌었는데 세금이 10만원 넘게 늘면 실수령이 줄어든다.
      expect(worstJump, lessThan(100000), reason: '총급여 $worstAt 부근에서 실수령이 역전된다');
    });
  });

  /// 3차 변이에서 드러난 것 — 누진식 경계에서 부등호를 뒤집어도 값이 안 변한다.
  /// 그건 버그가 없다는 뜻이지만, **연속성이 깨지면 즉시 버그**가 된다.
  /// 경계에서 값이 튀면 1원 차이로 세금이 계단처럼 뛴다.
  group('경계 연속성 — 부등호를 어느 쪽에 두든 값이 같아야 한다', () {
    test('단순경비율 4,000만 경계 (시행령 §143③1의2)', () {
      // 4,000만 이하는 기본율, 초과분은 초과율. 경계에서 두 식이 만나야 한다.
      const base = 0.641, excess = 0.497;
      final atBoundary = TaxRates.simpleRateExpense(
          revenue: 40000000, baseRate: base, excessRate: excess);
      final justOver = TaxRates.simpleRateExpense(
          revenue: 40000001, baseRate: base, excessRate: excess);
      expect(atBoundary, closeTo(40000000 * base, 0.01));
      // 1원 더 벌어서 경비가 줄어들면 안 된다(소득금액이 튄다).
      expect(justOver, greaterThanOrEqualTo(atBoundary));
      expect(justOver - atBoundary, closeTo(excess, 0.01),
          reason: '경계 바로 위 1원에는 초과율만 붙어야 한다');
    });

    test('근로소득공제 1억 경계 (소법 §47①)', () {
      final at = EmployeeTaxCalculator.calculateLaborDeduction(100000000);
      final over = EmployeeTaxCalculator.calculateLaborDeduction(100000001);
      expect(at, closeTo(14750000, 0.01));
      expect(over - at, closeTo(0.02, 0.001),
          reason: '경계 바로 위 1원에는 2%만 붙어야 한다');
    });
  });

  /// 기준 귀속연도는 세법 판정의 뿌리다. 바꾸면 앱 전체가 다른 해를 계산한다.
  /// 지금은 화면 테스트가 우연히 잡지만, 뿌리 자체를 직접 못박는다.
  group('기준 귀속연도', () {
    test('TaxYear.reference가 자녀세액공제 연령 판정을 실제로 움직인다', () {
      // 연도가 바뀌면 대상 출생연도도 바뀌어야 한다 — 상수로 굳어 있으면 안 된다.
      expect(TaxRates.childTaxCreditBirthYearCutoff(2025), 2017);
      expect(TaxRates.childTaxCreditBirthYearCutoff(2026), 2016);
      expect(TaxRates.childTaxCreditBirthYearCutoff(2030), 2017);
      // 현재 기준연도가 무엇이든 그 해의 규칙을 따라야 한다.
      expect(TaxRates.childTaxCreditEligibilityLabel(),
          '${TaxRates.childTaxCreditBirthYearCutoff(TaxYear.reference)}년생 이하');
    });

    test('기준 귀속연도가 2026이다', () {
      // 해가 바뀌면 이 값을 올려야 하고, 그때 경비율 고시·자녀 연령·요율을
      // 함께 확인해야 한다. 만료 알람(notice_expiry_test)이 그 목록을 갖고 있다.
      expect(TaxYear.reference, 2026,
          reason: '기준 귀속연도를 바꿨다면 notice_expiry_test의 고시 19건도 함께 확인할 것');
    });
  });
}
