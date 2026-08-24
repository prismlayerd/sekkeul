import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/deduction_catalog.dart';
import 'package:secul/core/parsing/correction_pdf.dart';
import 'package:secul/core/parsing/correction_report.dart';
import 'package:secul/core/parsing/simplified_data_parser.dart';
import 'package:secul/ui/screens/correction_request_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **경정청구는 사용자가 적는다.**
///
/// 앱은 5년 전 지출을 알 리가 없다. 예전엔 저장된 연말정산 기록 하나를 가져와
/// 채웠는데 그 쿼리에 연도 조건이 없어서, 2023년을 골라도 다른 해 숫자가 들어왔다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('모든 항목이 빈 채로 있다', (t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    // 연말정산 기록이 저장돼 있어도 끌어오지 않는다 — 연도가 안 맞는다.
    await dbService.saveAnnualRecord('직장인', {
      'grossSalary': 50000000,
      'decidedTax': 1200000,
      'medical': 3000000,
    });

    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const CorrectionRequestScreen(userType: '직장인')));
    await t.pumpAndSettle();

    for (final f in t.widgetList<TextField>(find.byType(TextField))) {
      expect(f.controller?.text ?? '', isEmpty,
          reason: '앱이 5년 전 숫자를 아는 척하면 그 값이 그대로 세무서로 간다');
    }
  });

  testWidgets('경정청구 목록은 좁히지 않는다', (t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const CorrectionRequestScreen(userType: '직장인')));
    await t.pumpAndSettle();

    // 「아 이것도 공제받을 수 있었어?」를 깨닫는 화면이라 간소화 자동분도 다 있어야 한다.
    for (final name in ['의료비', '교육비', '기부금', '보장성보험', '연금저축']) {
      expect(findKo(name), findsWidgets, reason: '$name이 목록에서 빠졌다');
    }
  });

  testWidgets('항목만 고르면 서류와 내는 방법이 보인다', (t) async {
    t.view.physicalSize = const Size(390, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const CorrectionRequestScreen(userType: '직장인')));
    await t.pumpAndSettle();

    // 열자마자는 「총급여를 읽지 못했습니다」만 — 여기까진 맞다.
    expect(findKo('어떻게 내실 건가요?'), findsNothing);

    // 항목 하나만 고르면 서류와 방식이 나와야 한다. 예전엔 총급여·결정세액·
    // 금액을 전부 채워야(c.hasMissed) 나타나서, 만들어 놓고도 아무도 못 봤다.
    await t.tap(findKo('월세액').first);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, '6000000');
    await t.pumpAndSettle();

    expect(findKo('같이 낼 서류'), findsWidgets);
    expect(findKo('어떻게 내실 건가요?'), findsWidgets);
    expect(findKo('세무서에 직접 내기'), findsWidgets);
    expect(findKo('홈택스로 내기'), findsWidgets);
  });

  test('고른 항목의 서류만 나온다', () {
    final picked = kDeductionCatalog.where((c) => c.id == 'rent').single;
    expect(picked.documents, isNotEmpty);
    expect(picked.documents.join(), contains('임대차계약서'));
    // 안 고른 항목의 서류가 섞이면 준비물이 뻥튀기된다.
    final glasses = kDeductionCatalog.where((c) => c.id == 'glasses').single;
    expect(glasses.documents.join(), isNot(contains('임대차계약서')));
  });

  test('모든 항목에 서류 안내가 붙어 있다', () {
    for (final c in kDeductionCatalog) {
      expect(c.documents, isNotEmpty, reason: '${c.name}에 필요 서류가 없다');
    }
  });

  test('작성 내역 PDF가 만들어진다', () async {
    final font = await rootBundle.load('assets/fonts/NanumGothicCoding-Regular.ttf');
    final report = buildCorrectionReport(
      const GansoDeductions(medical: 3000000, rent: 6000000),
      forgottenReceipt(accrualYear: 2024, grossSalary: 50000000, decidedTax: 1500000),
    );
    final bytes = await buildCorrectionPdf(
      report: report,
      amounts: const {'medical': 3000000, 'rent': 6000000},
      grossSalary: 50000000,
      decidedTax: 1500000,
      koreanFont: font.buffer.asUint8List(),
    );
    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
