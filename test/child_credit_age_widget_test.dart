import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/tax_engine/tax_rates.dart';
import 'package:secul/ui/screens/dependent_deduction_screen.dart';

/// 자녀세액공제 대상 연령 문구가 화면까지 실제로 내려오는지 확인한다.
///
/// 엔진 테스트는 값만 본다. "8세 이상"이 하드코딩으로 남아 있어도 계산은 통과하는데,
/// 사용자는 틀린 기준으로 자녀 수를 세게 된다. 그 회귀는 여기서만 잡힌다.
void main() {
  setUp(() => dbService = InMemoryDatabaseHelper());

  testWidgets('부양가족 공제 화면 — 대상 연령을 출생연도로 안내한다', (t) async {
    t.view.physicalSize = const Size(1200, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(const MaterialApp(home: DependentDeductionScreen()));
    await t.pumpAndSettle();

    final label = TaxRates.childTaxCreditEligibilityLabel();
    expect(find.textContaining(label), findsWidgets,
        reason: '기준 귀속연도의 출생연도 안내($label)가 보여야 한다');
    expect(find.textContaining('8세 이상'), findsNothing,
        reason: '연도와 무관한 "8세 이상"은 2026 귀속부터 틀린 안내다');
  });
}
