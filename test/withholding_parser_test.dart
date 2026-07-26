import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/parsing/withholding_parser.dart';

void main() {
  group('원천징수영수증 파서 — 실제 추출 텍스트(골든)', () {
    late WithholdingReceipt w;

    setUpAll(() {
      final text = File('test/fixtures/wonchun_sample.txt').readAsStringSync();
      w = parseWithholdingText(text);
    });

    test('총급여·세액 추출', () {
      expect(w.grossSalary, 33295138);
      expect(w.paidTax, 806640, reason: '75 주(현)근무지 기납부세액');
      expect(w.decidedTax, 509066, reason: '73 결정세액');
      expect(w.finalSettlement, -297570, reason: '77 차감징수(음수=환급)');
      expect(w.isRefund, true);
      expect(w.settlementAbs, 297570);
    });

    test('이미 신고된 공제대상금액', () {
      expect(w.claimedMedical, 0);
      expect(w.claimedEducation, 0);
      expect(w.claimedRent, 0);
      expect(w.claimedLifeInsurance, 1000000, reason: '61 보장성 공제대상');
      expect(w.claimedPensionSavings, 0);
    });
  });
}
