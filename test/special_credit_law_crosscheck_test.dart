import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';

import 'support/tax_law_reference.dart';

/// 특별세액공제(의료비·교육비·기부금) — 엔진과 조문 검산을 1원 단위로 대조한다.
///
/// 이 세 항목은 페르소나 회귀가 건드리지 않던 영역이다. 문턱·한도·공제율 구간이
/// 겹쳐 있어 경계에서 틀리기 쉽다.
///
/// 근거: 소득세법 §59의4② 의료비 / §59의4③ 교육비 / §59의4④ 기부금
///      / 조세특례제한법 §76① 정치자금기부금
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
  group('의료비 (§59의4②)', () {
    // (이름, 총급여, 난임, 미숙아, 본인·65세↑·장애인, 그 밖의 부양가족)
    const cases = <(String, double, double, double, double, double)>[
      ('문턱 정확히 — 공제 0', 50000000, 0, 0, 1500000, 0),
      ('문턱 + 1원', 50000000, 0, 0, 1500001, 0),
      ('본인만 크게', 50000000, 0, 0, 10000000, 0),
      ('부양가족만 — 700만 한도 미달', 50000000, 0, 0, 0, 8000000),
      ('부양가족만 — 700만 한도 초과', 50000000, 0, 0, 0, 30000000),
      ('난임만 — 30%', 50000000, 10000000, 0, 0, 0),
      ('난임 + 부양가족 혼합 — 배분 순서', 50000000, 5000000, 0, 0, 5000000),
      ('미숙아 20% 포함 4종 혼합', 50000000, 3000000, 3000000, 3000000, 3000000),
      ('저소득 — 문턱이 낮다', 20000000, 0, 0, 2000000, 0),
      ('고소득 — 문턱이 높다', 150000000, 0, 0, 4000000, 0),
      ('전부 0', 50000000, 0, 0, 0, 0),
    ];

    test('11개 조합이 조문 검산과 일치한다', () {
      for (final (name, gross, inf, pre, self, other) in cases) {
        final eng = EmployeeTaxCalculator.calculateMedicalTaxCredit(
          grossIncome: gross,
          infertilityExpense: inf,
          prematureBabyExpense: pre,
          selfAndSeniorAndDisabledExpense: self,
          otherDependentExpense: other,
        );
        final ref = refMedicalTaxCredit(
          gross: gross,
          infertility: inf,
          prematureBaby: pre,
          selfSeniorDisabled: self,
          otherDependent: other,
        );
        // ignore: avoid_print
        print('  $name → ${won(eng)}');
        expect(eng, closeTo(ref, 0.01), reason: '의료비 $name');
      }
    });

    test('총급여 3%를 넘지 않으면 한 푼도 공제되지 않는다', () {
      for (final gross in [20000000.0, 50000000.0, 100000000.0]) {
        final atThreshold = gross * 0.03;
        expect(
            EmployeeTaxCalculator.calculateMedicalTaxCredit(
              grossIncome: gross,
              infertilityExpense: 0,
              selfAndSeniorAndDisabledExpense: atThreshold,
              otherDependentExpense: 0,
            ),
            0.0,
            reason: '총급여 ${won(gross)}: 3% 문턱에서는 0원');
      }
    });

    test('그 밖의 부양가족분만 700만원 한도가 걸린다', () {
      // 부양가족 의료비를 아무리 늘려도 공제는 700만 × 15% = 105만을 넘지 않는다.
      const gross = 50000000.0;
      final huge = EmployeeTaxCalculator.calculateMedicalTaxCredit(
        grossIncome: gross,
        infertilityExpense: 0,
        selfAndSeniorAndDisabledExpense: 0,
        otherDependentExpense: 100000000,
      );
      expect(huge, closeTo(7000000 * 0.15, 0.01));
      // 본인분은 한도가 없다 — 같은 금액이면 훨씬 크다.
      final selfOnly = EmployeeTaxCalculator.calculateMedicalTaxCredit(
        grossIncome: gross,
        infertilityExpense: 0,
        selfAndSeniorAndDisabledExpense: 100000000,
        otherDependentExpense: 0,
      );
      expect(selfOnly, greaterThan(huge));
    });
  });

  group('교육비 (§59의4③)', () {
    test('1인당 한도가 인원 수에 비례한다 — 취학전·초중고 300만 / 대학 900만', () {
      // 자녀 2명 초중고에 1,000만원 → 한도 600만 → 90만
      final a = EmployeeTaxCalculator.calculateEducationTaxCredit(
        preschoolExpense: 0, preschoolCount: 0,
        childrenExpense: 10000000, childrenCount: 2,
        collegeExpense: 0, collegeCount: 0,
        selfExpense: 0, disabledSpecialExpense: 0,
      );
      expect(a, closeTo(refEducationTaxCredit(children: 10000000, childrenCount: 2), 0.01));
      expect(a, closeTo(6000000 * 0.15, 0.01));

      // 대학생 1명에 1,000만원 → 한도 900만 → 135만
      final b = EmployeeTaxCalculator.calculateEducationTaxCredit(
        preschoolExpense: 0, preschoolCount: 0,
        childrenExpense: 0, childrenCount: 0,
        collegeExpense: 10000000, collegeCount: 1,
        selfExpense: 0, disabledSpecialExpense: 0,
      );
      expect(b, closeTo(9000000 * 0.15, 0.01));
    });

    test('본인·장애인 특수교육비는 한도가 없다', () {
      final r = EmployeeTaxCalculator.calculateEducationTaxCredit(
        preschoolExpense: 0, preschoolCount: 0,
        childrenExpense: 0, childrenCount: 0,
        collegeExpense: 0, collegeCount: 0,
        selfExpense: 30000000, disabledSpecialExpense: 20000000,
      );
      expect(r, closeTo(refEducationTaxCredit(self: 30000000, disabledSpecial: 20000000), 0.01));
      expect(r, closeTo(50000000 * 0.15, 0.01));
    });

    test('인원이 0이면 그 항목은 통째로 공제되지 않는다', () {
      // 금액만 있고 인원이 0이면 한도가 0이라 공제도 0이어야 한다.
      final r = EmployeeTaxCalculator.calculateEducationTaxCredit(
        preschoolExpense: 5000000, preschoolCount: 0,
        childrenExpense: 5000000, childrenCount: 0,
        collegeExpense: 5000000, collegeCount: 0,
        selfExpense: 0, disabledSpecialExpense: 0,
      );
      expect(r, 0.0, reason: '인원 0인데 공제가 잡혔다');
    });

    test('여러 조합이 조문 검산과 일치한다', () {
      const cases = <(String, double, int, double, int, double, int, double, double)>[
        ('취학전 1명 200만', 2000000, 1, 0, 0, 0, 0, 0, 0),
        ('초중고 3명 1,200만 — 한도 900만', 0, 0, 12000000, 3, 0, 0, 0, 0),
        ('대학 2명 2,000만 — 한도 1,800만', 0, 0, 0, 0, 20000000, 2, 0, 0),
        ('전부 섞임', 2000000, 1, 5000000, 2, 8000000, 1, 4000000, 1000000),
      ];
      for (final (name, pre, preN, ch, chN, col, colN, self, dis) in cases) {
        final eng = EmployeeTaxCalculator.calculateEducationTaxCredit(
          preschoolExpense: pre, preschoolCount: preN,
          childrenExpense: ch, childrenCount: chN,
          collegeExpense: col, collegeCount: colN,
          selfExpense: self, disabledSpecialExpense: dis,
        );
        final ref = refEducationTaxCredit(
          preschool: pre, preschoolCount: preN,
          children: ch, childrenCount: chN,
          college: col, collegeCount: colN,
          self: self, disabledSpecial: dis,
        );
        // ignore: avoid_print
        print('  $name → ${won(eng)}');
        expect(eng, closeTo(ref, 0.01), reason: '교육비 $name');
      }
    });
  });

  group('기부금 (§59의4④ · 조특법 §76①)', () {
    test('일반기부금 1,000만원 경계에서 15%→30%로 꺾인다', () {
      for (final amount in [
        9999999.0, 10000000.0, 10000001.0, 30000000.0, 50000000.0,
      ]) {
        final eng = EmployeeTaxCalculator.calculateDonationTaxCredit(
          generalDonation: amount, politicalDonation: 0,
        );
        expect(eng, closeTo(refDonationTaxCredit(general: amount), 0.01),
            reason: '일반기부금 ${won(amount)}');
      }
      // 1,000만 이하는 정확히 15%
      expect(
          EmployeeTaxCalculator.calculateDonationTaxCredit(
              generalDonation: 10000000, politicalDonation: 0),
          closeTo(1500000, 0.01));
    });

    test('정치자금 10만원은 110분의 100 — "전액 환급"이 아니다', () {
      final r = EmployeeTaxCalculator.calculateDonationTaxCredit(
        generalDonation: 0, politicalDonation: 100000,
      );
      // 소득세 90,909원. 지방소득세 9,091원을 합쳐야 10만원이 된다.
      expect(r, closeTo(trunc10(100000 * 100 / 110), 0.01));
      expect(r, lessThan(100000), reason: '소득세 세액공제를 100%로 두면 부풀려진다');
      expect(r, closeTo(refDonationTaxCredit(political: 100000), 0.01));
    });

    test('정치자금 10만 초과분 15%, 그 초과분이 3천만 넘으면 25%', () {
      for (final amount in [
        100001.0, 1000000.0, 30100000.0, 30100001.0, 50000000.0,
      ]) {
        final eng = EmployeeTaxCalculator.calculateDonationTaxCredit(
          generalDonation: 0, politicalDonation: amount,
        );
        expect(eng, closeTo(refDonationTaxCredit(political: amount), 0.01),
            reason: '정치자금 ${won(amount)}');
      }
    });

    test('일반 + 정치자금 동시', () {
      final eng = EmployeeTaxCalculator.calculateDonationTaxCredit(
        generalDonation: 15000000, politicalDonation: 500000,
      );
      // ignore: avoid_print
      print('  일반 1,500만 + 정치 50만 → ${won(eng)}');
      expect(eng,
          closeTo(refDonationTaxCredit(general: 15000000, political: 500000), 0.01));
    });
  });
}
