import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/occupation_data.dart';
import 'package:secul/core/tax_engine/bookkeeping_duty.dart';

/// 기장의무 판정 엔진 (1단계 — 판정) 검증.
void main() {
  OccupationInfo occ(String code) => OccupationData.occupations[code]!;

  // 대표 코드: C그룹 프리랜서(작가 940100, 7,500만), B그룹(SW개발 722000, 1.5억),
  // A그룹(채소재배 011001, 3억), 전문직(변호사 741101).
  final freelancerC = occ('940100');
  final swB = occ('722000');
  final retailA = occ('011001');
  final lawyer = occ('741101');

  group('전문직 — 수입·신규 무관 복식부기', () {
    test('변호사는 수입 0이어도 복식부기의무자', () {
      final j = judgeBookkeepingDuty(occupation: lawyer, priorYearIncome: 0);
      expect(j.duty, BookkeepingDuty.doubleEntry);
      expect(j.isProfessional, isTrue);
      expect(j.isDoubleEntry, isTrue);
    });

    test('전문직은 신규사업자여도 복식부기', () {
      final j = judgeBookkeepingDuty(
          occupation: lawyer, priorYearIncome: 0, isNewBusiness: true);
      expect(j.duty, BookkeepingDuty.doubleEntry);
      expect(j.isNewBusiness, isFalse); // 전문직이면 신규 우대 무의미
    });

    test('전문직은 겸업이어도 확인 불필요(규칙 단순)', () {
      final j = judgeBookkeepingDuty(
          occupation: lawyer, priorYearIncome: 0, hasMultipleBusinesses: true);
      expect(j.needsInputReview, isFalse);
    });
  });

  group('신규사업자 — 첫해 간편장부', () {
    test('신규 프리랜서는 직전수입 무관 간편장부', () {
      final j = judgeBookkeepingDuty(
          occupation: freelancerC, priorYearIncome: 0, isNewBusiness: true);
      expect(j.duty, BookkeepingDuty.simplified);
      expect(j.isNewBusiness, isTrue);
    });
  });

  group('직전연도 수입 기준 판정 (C그룹 7,500만)', () {
    test('7,500만 미만 → 간편장부', () {
      final j = judgeBookkeepingDuty(occupation: freelancerC, priorYearIncome: 74999999);
      expect(j.duty, BookkeepingDuty.simplified);
      expect(j.threshold, 75000000);
    });

    test('임계 정확히 7,500만 → 복식부기(이상 포함)', () {
      final j = judgeBookkeepingDuty(occupation: freelancerC, priorYearIncome: 75000000);
      expect(j.duty, BookkeepingDuty.doubleEntry);
    });

    test('7,500만 초과 → 복식부기', () {
      final j = judgeBookkeepingDuty(occupation: freelancerC, priorYearIncome: 90000000);
      expect(j.duty, BookkeepingDuty.doubleEntry);
    });
  });

  group('그룹별 임계 차이', () {
    test('SW개발(B,1.5억): 1억은 간편, 2억은 복식', () {
      expect(judgeBookkeepingDuty(occupation: swB, priorYearIncome: 100000000).duty,
          BookkeepingDuty.simplified);
      expect(judgeBookkeepingDuty(occupation: swB, priorYearIncome: 200000000).duty,
          BookkeepingDuty.doubleEntry);
    });

    test('채소재배(A,3억): 2억은 간편, 3.5억은 복식', () {
      expect(judgeBookkeepingDuty(occupation: retailA, priorYearIncome: 200000000).duty,
          BookkeepingDuty.simplified);
      expect(judgeBookkeepingDuty(occupation: retailA, priorYearIncome: 350000000).duty,
          BookkeepingDuty.doubleEntry);
    });
  });

  group('겸업 — 결과는 내되 확인 신호', () {
    test('겸업 프리랜서는 needsInputReview', () {
      final j = judgeBookkeepingDuty(
          occupation: freelancerC,
          priorYearIncome: 50000000,
          hasMultipleBusinesses: true);
      expect(j.duty, BookkeepingDuty.simplified); // 결과는 계산됨
      expect(j.needsInputReview, isTrue);
    });
  });
}
