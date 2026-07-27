import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
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
  testWidgets('경정청구 — 고른 귀속연도가 실제 계산에 반영된다', (t) async {
    await dbService.saveAnnualRecord('직장인', {
      'grossSalary': 40000000,
      'decidedTax': 5000000,
      'donation': 1000000,
    });
    await pump(t, const CorrectionRequestScreen(userType: '직장인'));

    // 기본 선택은 가장 최근 연도(2023 귀속 이후) → 기부금 100만 × 15% = 15만
    expect(find.textContaining('150,000'), findsWidgets);

    // 2022 귀속은 코로나 한시 상향이 살아 있어 20% → 20만
    await t.tap(find.text('2022'));
    await t.pumpAndSettle();
    expect(find.textContaining('200,000'), findsWidgets,
        reason: '2022 귀속 기부금은 20%(조특 한시 상향)로 계산돼야 한다');
    expect(find.textContaining('150,000'), findsNothing);
  });

  testWidgets('빠진 공제 찾기 — 총급여를 아직 안 넣으면 사유를 보여준다', (t) async {
    await pump(t, const MissedDeductionDiagnosisScreen(userType: '직장인'));
    expect(findKo('총급여를 읽지 못했습니다'), findsOneWidget);
  });
}
