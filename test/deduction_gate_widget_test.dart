import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/deduction_gate_screen.dart';

/// 게이트는 "고르면 얼마"가 보여야 고를 이유가 생긴다.
/// 금액이 사라지거나 0으로 표시되는 회귀를 여기서 잡는다.
void main() {
  setUp(() => dbService = InMemoryDatabaseHelper());

  Future<void> pump(WidgetTester t, String userType) async {
    t.view.physicalSize = const Size(1200, 4000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: DeductionGateScreen(userType: userType)));
    await t.pumpAndSettle();
  }

  testWidgets('항목마다 총급여 기준 금액이 붙는다', (t) async {
    await dbService.saveProfile({'user_type': '직장인', 'gross_income': 45000000.0});
    await pump(t, '직장인');

    expect(find.textContaining('월세로 살아요'), findsOneWidget);
    // 총급여 4,500만 → 5,500만 이하라 월세 17%, 한도 1,000만 → 170만
    expect(find.textContaining('1,700,000원'), findsWidgets);
    // 아직 아무것도 안 고른 상태
    expect(find.textContaining('아직 고른 항목이 없어요'), findsOneWidget);
  });

  testWidgets('고르면 합계가 오르고 버튼 문구가 바뀐다', (t) async {
    await dbService.saveProfile({'user_type': '직장인', 'gross_income': 45000000.0});
    await pump(t, '직장인');

    await t.tap(find.textContaining('월세로 살아요'));
    await t.pumpAndSettle();

    expect(find.textContaining('고른 1개를 한도까지 채우면'), findsOneWidget);
    expect(find.textContaining('1개 입력하러 가기'), findsOneWidget);
  });

  testWidgets('프리랜서는 근로자 전용 항목이 빠진다', (t) async {
    await dbService.saveProfile({'user_type': '프리랜서', 'gross_income': 45000000.0});
    await pump(t, '프리랜서');

    expect(find.textContaining('중소기업에 다녀요'), findsNothing);
    expect(find.textContaining('주택담보대출'), findsNothing);
    // 월세는 성실사업자만 대상이라는 조건을 문구에 밝힌다
    expect(find.textContaining('성실사업자만'), findsOneWidget);
  });
}
