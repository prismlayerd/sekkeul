import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/deduction_catalog.dart';
import 'package:secul/core/parsing/correction_report.dart';
import 'package:secul/core/parsing/simplified_data_parser.dart';
import 'package:secul/core/tax_engine/tax_year_rules.dart';
import 'package:secul/ui/screens/correction_request_screen.dart';
import 'package:secul/ui/screens/missed_deduction_diagnosis_screen.dart';
import 'support/ko_finder.dart';

/// 화면이 "왜 계산 못 했는지"를 실제로 그리는지 확인한다.
/// 엔진 테스트는 값만 보므로, 차단 사유가 화면에 안 뜨고 0원으로만 보이는 회귀는
/// 여기서만 잡힌다.
void main() {
  setUp(() => dbService = InMemoryDatabaseHelper());

  Future<void> pump(WidgetTester t, Widget screen) async {
    // 결과 영역은 리스트 아래쪽이라, 기본 800x600 화면에서는 아예 build되지 않는다.
    t.view.physicalSize = const Size(1200, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: screen));
    await t.pumpAndSettle();
  }

  testWidgets('경정청구 — 총급여를 아직 안 넣으면 사유를 보여준다', (t) async {
    await pump(t, const CorrectionRequestScreen(userType: '직장인'));
    expect(findKo('총급여를 읽지 못했습니다'), findsOneWidget);
  });

  testWidgets('경정청구 — 청구 가능한 귀속연도만 고를 수 있다', (t) async {
    await pump(t, const CorrectionRequestScreen(userType: '직장인'));
    final now = DateTime.now();
    for (var y = now.year - 1; y >= kOldestCorrectionYear; y--) {
      final shown = find.text('$y');
      if (rulesForYear(y) != null && isCorrectionOpen(y, now)) {
        expect(shown, findsWidgets, reason: '$y년은 아직 청구 가능한데 목록에 없다');
      } else {
        expect(shown, findsNothing, reason: '$y년은 계산할 수 없는데 목록에 있다');
      }
    }
  });

  // 이 화면은 연도를 물어보고, 되받아 보여주면서, 정작 계산에는 안 쓰고 있었다.
  // (v1에서 _selectedYear가 buildCorrectionReport로 전달되지 않았음)
  //
  // 화면으로 확인하던 것을 순수 함수로 내렸다 — 프리필을 걷어서(앱은 5년 전
  // 지출을 알 리가 없다) 위젯 테스트가 값을 넣을 길이 없어졌고, 애초에 연도별
  // 공제율은 엔진의 일이라 여기서 재는 게 맞다.
  test('고른 귀속연도의 공제율로 계산된다', () {
    int refund(int year) => buildCorrectionReport(
          const GansoDeductions(donation: 1000000),
          forgottenReceipt(
              accrualYear: year, grossSalary: 40000000, decidedTax: 5000000),
        ).additionalRefund;

    expect(refund(2023), 150000, reason: '기부금 100만 × 15%');
    expect(refund(2022), 200000, reason: '2022 귀속은 코로나 한시 상향으로 20%');
  });

  testWidgets('빠진 공제 찾기 — 총급여를 아직 안 넣으면 사유를 보여준다', (t) async {
    await pump(t, const MissedDeductionDiagnosisScreen(userType: '직장인'));
    expect(findKo('총급여를 읽지 못했습니다'), findsOneWidget);
  });
}
