import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/parsing/correction_form_fill.dart';
import 'package:secul/core/parsing/correction_report.dart';
import 'package:secul/core/parsing/simplified_data_parser.dart';
import 'package:secul/core/data/deduction_catalog.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// 공식 서식에 값을 찍는다 — **좌표가 맞는지는 눈으로 확인했다.**
/// 여기서는 파일이 만들어지고 원본 페이지 수가 유지되는지만 지킨다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('공식 경정청구서에 값이 찍힌다', () async {
    final form = await rootBundle.load('assets/forms/gyeongjeong_national.pdf');
    final font = await rootBundle.load('assets/fonts/NanumGothicCoding-Regular.ttf');
    final report = buildCorrectionReport(
      const GansoDeductions(medical: 3000000, rent: 6000000),
      forgottenReceipt(accrualYear: 2024, grossSalary: 50000000, decidedTax: 1500000),
    );
    final bytes = await fillCorrectionForm(
      formBytes: form.buffer.asUint8List(),
      koreanFont: font.buffer.asUint8List(),
      report: report,
      itemNames: const ['의료비', '월세액'],
      claimedOn: DateTime(2026, 8, 24),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(form.lengthInBytes));

    final out = Platform.environment['SEKKEUL_PDF_OUT'];
    if (out != null) await File(out).writeAsBytes(bytes);
  });

  test('원본 4쪽이 그대로 남는다', () async {
    final form = await rootBundle.load('assets/forms/gyeongjeong_national.pdf');
    final font = await rootBundle.load('assets/fonts/NanumGothicCoding-Regular.ttf');
    final bytes = await fillCorrectionForm(
      formBytes: form.buffer.asUint8List(),
      koreanFont: font.buffer.asUint8List(),
      report: buildCorrectionReport(
        const GansoDeductions(donation: 1000000),
        forgottenReceipt(accrualYear: 2024, grossSalary: 40000000, decidedTax: 900000),
      ),
      itemNames: const ['기부금'],
    );
    // 뒷장에 작성 요령과 접수증이 있다. 한 장만 남기면 세무서가 못 받는다.
    expect(PdfDocument(inputBytes: bytes).pages.count, 4);
  });

  test('지방세 서식에도 값이 찍힌다', () async {
    final form = await rootBundle.load('assets/forms/gyeongjeong_local.pdf');
    final font = await rootBundle.load('assets/fonts/NanumGothicCoding-Regular.ttf');
    final bytes = await fillLocalCorrectionForm(
      formBytes: form.buffer.asUint8List(),
      koreanFont: font.buffer.asUint8List(),
      accrualYear: 2024,
      claimedOn: DateTime(2026, 8, 24),
    );
    final text = PdfTextExtractor(PdfDocument(inputBytes: bytes))
        .extractText(startPageIndex: 0, endPageIndex: 0);
    expect(text, contains('개인지방소득세'));
    expect(text, contains('2025. 5. 31.'));

    final out = Platform.environment['SEKKEUL_LOCAL_OUT'];
    if (out != null) await File(out).writeAsBytes(bytes);
  });

  test('청구이유에 고른 항목 이름이 들어간다', () async {
    // 「공제 누락」만 쓰면 세무서가 무엇을 뺐는지 몰라 보정을 요구한다.
    final form = await rootBundle.load('assets/forms/gyeongjeong_national.pdf');
    final font = await rootBundle.load('assets/fonts/NanumGothicCoding-Regular.ttf');
    final bytes = await fillCorrectionForm(
      formBytes: form.buffer.asUint8List(),
      koreanFont: font.buffer.asUint8List(),
      report: buildCorrectionReport(
        const GansoDeductions(rent: 6000000),
        forgottenReceipt(accrualYear: 2024, grossSalary: 40000000, decidedTax: 900000),
      ),
      itemNames: const ['월세액'],
    );
    final text = PdfTextExtractor(PdfDocument(inputBytes: bytes))
        .extractText(startPageIndex: 0, endPageIndex: 0);
    expect(text, contains('월세액'));
    expect(text, contains('2024년 귀속'));
    expect(text, contains('종합소득세'));
  });
}
