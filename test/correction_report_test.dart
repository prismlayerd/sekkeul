import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/parsing/simplified_data_parser.dart';
import 'package:secul/core/parsing/withholding_parser.dart';
import 'package:secul/core/parsing/correction_report.dart';
import 'package:secul/core/tax_engine/tax_year_rules.dart';

void main() {
  group('경정청구 추가환급 산출 — 실제 한 쌍', () {
    test('김경미 쌍 → 추가환급 0 (문턱/한도 충족, 누락 없음)', () {
      final g = parseSimplifiedText(File('test/fixtures/ganso_sample.txt').readAsStringSync());
      final w = parseWithholdingText(File('test/fixtures/wonchun_sample.txt').readAsStringSync());
      final r = buildCorrectionReport(g, w);
      expect(r.accrualYear, 2025, reason: '⑪근무기간에서 귀속연도를 읽어야 한다');
      expect(r.isBlocked, false);
      expect(r.additionalRefund, 0);
      expect(r.lines, isEmpty);
      expect(r.hasMissed, false);
    });
  });

  group('경정청구 추가환급 산출 — 합성', () {
    test('기부금+보장성 미신고 → 추가환급 = 두 세액공제 합', () {
      const g = GansoDeductions(donation: 1000000, lifeInsurance: 2000000);
      const w = WithholdingReceipt(
          accrualYear: 2025, grossSalary: 40000000, decidedTax: 5000000);
      final r = buildCorrectionReport(g, w);
      // 기부금 1,000,000×15%=150,000 + 보장성 min(2,000,000,1M)×12%=120,000
      expect(r.additionalRefund, 270000);
      expect(r.lines.length, 2);
      expect(r.lines.firstWhere((l) => l.category == '기부금').missedCredit, 150000);
      expect(r.lines.firstWhere((l) => l.category == '보장성보험').missedCredit, 120000);
    });

    test('추가환급은 결정세액을 넘지 못함(cap)', () {
      const g = GansoDeductions(pensionSavings: 6000000);
      const w = WithholdingReceipt(
          accrualYear: 2025, grossSalary: 40000000, decidedTax: 100000);
      final r = buildCorrectionReport(g, w);
      // 연금저축 600만×15%=900,000 이지만 결정세액 100,000 한도
      expect(r.additionalRefund, 100000);
    });

    test('난임시술비는 30% 고율로 분리 계산', () {
      // 총급여 3천만(문턱 90만), 난임 500만 → 초과 410만 전액 30% = 123만
      const g = GansoDeductions(medical: 5000000, medicalInfertility: 5000000);
      const w = WithholdingReceipt(
          accrualYear: 2025, grossSalary: 30000000, decidedTax: 5000000);
      final med = buildCorrectionReport(g, w).lines.firstWhere((l) => l.category == '의료비');
      expect(med.missedCredit, 1230000);
    });

    test('난임 없이 일반 의료비는 15%', () {
      const g = GansoDeductions(medical: 5000000, medicalInfertility: 0);
      const w = WithholdingReceipt(
          accrualYear: 2025, grossSalary: 30000000, decidedTax: 5000000);
      final med = buildCorrectionReport(g, w).lines.firstWhere((l) => l.category == '의료비');
      expect(med.missedCredit, 615000);
    });

    test('결정세액 0이면 환급 0', () {
      const g = GansoDeductions(donation: 1000000);
      const w = WithholdingReceipt(
          accrualYear: 2025, grossSalary: 40000000, decidedTax: 0);
      expect(buildCorrectionReport(g, w).additionalRefund, 0);
    });

    test('이미 신고한 만큼은 추가 아님', () {
      const g = GansoDeductions(lifeInsurance: 2000000);
      const w = WithholdingReceipt(
          accrualYear: 2025,
          grossSalary: 40000000,
          decidedTax: 5000000,
          claimedLifeInsurance: 1000000);
      // 보장성 이미 한도(100만) 신고 → 추가 0
      expect(buildCorrectionReport(g, w).additionalRefund, 0);
    });
  });

  // 월세 세액공제 자격 게이트 (P1-A)
  group('월세 자격 게이트', () {
    const g = GansoDeductions(rent: 6000000);

    test('소득 요건 충족(연봉 3,600만) 무주택 → 월세 환급 발생', () {
      const w = WithholdingReceipt(
          accrualYear: 2025, grossSalary: 36000000, decidedTax: 5000000);
      final lines = buildCorrectionReport(g, w).lines;
      expect(lines.any((l) => l.category == '월세액'), isTrue);
    });

    test('총급여 8천 초과(연봉 1억) → 자격 없음, 월세 줄 제외', () {
      const w = WithholdingReceipt(
          accrualYear: 2025, grossSalary: 100000000, decidedTax: 10000000);
      final lines = buildCorrectionReport(g, w).lines;
      expect(lines.any((l) => l.category == '월세액'), isFalse);
    });

    test('무주택 아님(isHomeless=false) → 월세 줄 제외', () {
      const w = WithholdingReceipt(
          accrualYear: 2025, grossSalary: 36000000, decidedTax: 5000000);
      final lines = buildCorrectionReport(g, w, isHomeless: false).lines;
      expect(lines.any((l) => l.category == '월세액'), isFalse);
    });
  });

  // ── 귀속연도 분기 ────────────────────────────────────────────────
  // 경정청구는 지난 5년치를 다루므로 당해연도 상수로 계산하면 안 된다.
  // 출처: 국세청 「개정세법 해설」 2022~2026년판.
  group('귀속연도별 규정 분기', () {
    int credit(GansoDeductions g, int year, int salary, String cat) {
      final w = WithholdingReceipt(
          accrualYear: year, grossSalary: salary, decidedTax: 900000000);
      final lines = buildCorrectionReport(g, w).lines;
      final hit = lines.where((l) => l.category == cat);
      return hit.isEmpty ? 0 : hit.first.missedCredit;
    }

    test('기부금 한시 상향 — 2021·2022는 20%, 2023부터 15%', () {
      const g = GansoDeductions(donation: 1000000);
      expect(credit(g, 2021, 40000000, '기부금'), 200000);
      expect(credit(g, 2022, 40000000, '기부금'), 200000);
      expect(credit(g, 2023, 40000000, '기부금'), 150000);
    });

    test('고액기부 3천만 초과 40%는 2024 귀속만', () {
      const g = GansoDeductions(donation: 50000000);
      // 2024: 1천만×15% + 2천만×30% + 2천만×40% = 150만+600만+800만 = 1,550만
      expect(credit(g, 2024, 40000000, '기부금'), 15500000);
      // 2023·2025: 1천만×15% + 4천만×30% = 150만+1,200만 = 1,350만
      expect(credit(g, 2023, 40000000, '기부금'), 13500000);
      expect(credit(g, 2025, 40000000, '기부금'), 13500000);
    });

    test('난임시술비 — 2021은 20%, 2022부터 30%', () {
      const g = GansoDeductions(medical: 5000000, medicalInfertility: 5000000);
      // 총급여 3천만 → 문턱 90만, 공제대상 410만
      expect(credit(g, 2021, 30000000, '의료비'), 820000); // 410만×20%
      expect(credit(g, 2022, 30000000, '의료비'), 1230000); // 410만×30%
    });

    test('연금저축 한도 — 2022 이하 400만, 2023부터 600만', () {
      const g = GansoDeductions(pensionSavings: 6000000);
      expect(credit(g, 2022, 40000000, '연금저축'), 600000); // 400만×15%
      expect(credit(g, 2023, 40000000, '연금저축'), 900000); // 600만×15%
    });

    test('월세 공제율 — 2021은 12%, 2022부터 17%(총급여 5,500만 이하)', () {
      const g = GansoDeductions(rent: 6000000);
      expect(credit(g, 2021, 36000000, '월세액'), 720000); // 600만×12%
      expect(credit(g, 2022, 36000000, '월세액'), 1020000); // 600만×17%
    });

    test('월세 한도 — 2023까지 750만, 2024부터 1,000만', () {
      const g = GansoDeductions(rent: 9000000);
      expect(credit(g, 2023, 36000000, '월세액'), 1275000); // min(900만,750만)×17%
      expect(credit(g, 2024, 36000000, '월세액'), 1530000); // 900만×17%
    });

    test('월세 소득요건 — 총급여 7,500만은 2023 탈락, 2024 통과', () {
      const g = GansoDeductions(rent: 6000000);
      expect(credit(g, 2023, 75000000, '월세액'), 0); // 총급여 7천만 초과
      expect(credit(g, 2024, 75000000, '월세액'), 900000); // 600만×15%
    });
  });

  // ── 계산 불가 게이트 ──────────────────────────────────────────────
  // 근거 없는 금액을 내놓느니 왜 못 냈는지 말한다. 경정청구는 이 숫자를
  // 그대로 세무서에 내는 기능이라, 틀린 금액이 빈 결과보다 나쁘다.
  group('계산 불가 게이트', () {
    const g = GansoDeductions(donation: 1000000, lifeInsurance: 2000000);

    test('귀속연도를 못 읽으면 계산하지 않는다', () {
      const w = WithholdingReceipt(grossSalary: 40000000, decidedTax: 5000000);
      final r = buildCorrectionReport(g, w);
      expect(r.isBlocked, true);
      expect(r.additionalRefund, 0);
      expect(r.lines, isEmpty);
      expect(r.blockedReason, contains('귀속연도'));
    });

    test('규정을 확인하지 못한 연도는 계산하지 않는다', () {
      const w = WithholdingReceipt(
          accrualYear: 2020, grossSalary: 40000000, decidedTax: 5000000);
      final r = buildCorrectionReport(g, w);
      expect(r.isBlocked, true);
      expect(r.additionalRefund, 0);
      expect(r.blockedReason, contains('2020'));
    });

    test('총급여를 못 읽으면 계산하지 않는다', () {
      const w = WithholdingReceipt(accrualYear: 2025, decidedTax: 5000000);
      final r = buildCorrectionReport(g, w);
      expect(r.isBlocked, true);
      expect(r.additionalRefund, 0);
      expect(r.blockedReason, contains('총급여'));
    });

    test('청구 기한이 지난 연도는 계산하지 않는다', () {
      const w = WithholdingReceipt(
          accrualYear: 2021, grossSalary: 40000000, decidedTax: 5000000);
      // 2021 귀속 기한 = 2027.3.10.
      expect(
          buildCorrectionReport(g, w, now: DateTime(2027, 3, 1)).isBlocked, false);
      final late = buildCorrectionReport(g, w, now: DateTime(2027, 3, 11));
      expect(late.isBlocked, true);
      expect(late.blockedReason, contains('기한'));
    });
  });

  // 국세기본법 §45의2 ⑤: 연말정산 대상자는 "법정신고기한"이 아니라
  // "연말정산세액의 납부기한"(소득세법 §137①·§128① → 다음 연도 3.10.) 기준.
  group('경정청구 기한 (국세기본법 §45의2 ⑤)', () {
    test('귀속연도 다음 해 3월 10일 + 5년', () {
      expect(correctionDeadline(2021), DateTime(2027, 3, 10));
      expect(correctionDeadline(2025), DateTime(2031, 3, 10));
    });

    test('마감 당일은 아직 청구 가능', () {
      expect(isCorrectionOpen(2021, DateTime(2027, 3, 10)), isTrue);
      expect(isCorrectionOpen(2021, DateTime(2027, 3, 11)), isFalse);
    });
  });
}
