import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/deduction_gate_screen.dart';
import 'package:secul/ui/screens/tax_simulator_screen.dart';

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

  // 숨긴 대가로 손해가 나면 안 된다 — 안 고른 항목은 결과 아래에서 다시 묻는다.
  testWidgets('계산기 — 안 고른 항목을 금액과 함께 되묻는다', (t) async {
    await dbService.saveProfile({'user_type': '직장인', 'gross_income': 45000000.0});
    t.view.physicalSize = const Size(1200, 8000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(const MaterialApp(
        home: TaxSimulatorScreen(userType: '직장인', preOpened: {'medical'})));
    await t.pumpAndSettle();

    expect(find.textContaining('혹시 이건'), findsWidgets);
    // 고른 것(병원비)은 되묻지 않는다
    expect(find.textContaining('병원비를 많이 썼어요'), findsNothing);
  });

  testWidgets('게이트를 안 거치면 되묻지 않는다', (t) async {
    await dbService.saveProfile({'user_type': '직장인', 'gross_income': 45000000.0});
    t.view.physicalSize = const Size(1200, 8000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(const MaterialApp(home: TaxSimulatorScreen(userType: '직장인')));
    await t.pumpAndSettle();

    expect(find.textContaining('혹시 이건'), findsNothing);
  });

  // 선택을 저장하면 게이트를 매번 통과시키지 않아도 된다.
  testWidgets('저장된 선택을 게이트가 미리 체크한다', (t) async {
    await dbService.saveProfile(
        {'user_type': '직장인', 'gross_income': 45000000.0, 'deduction_picks': 'rent,medical'});
    await pump(t, '직장인');
    expect(find.textContaining('고른 2개를 한도까지 채우면'), findsOneWidget);
  });

  testWidgets('게이트를 안 거쳐도 저장된 선택이 적용된다', (t) async {
    await dbService.saveProfile(
        {'user_type': '직장인', 'gross_income': 45000000.0, 'deduction_picks': 'rent'});
    t.view.physicalSize = const Size(1200, 8000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(const MaterialApp(home: TaxSimulatorScreen(userType: '직장인')));
    await t.pumpAndSettle();

    expect(find.textContaining('혹시 이건'), findsWidgets);
    // 고른 월세는 되묻지 않는다
    expect(find.textContaining('월세로 살아요'), findsNothing);
  });

  // 측정 결과: 총액이 한도 아래면 어떻게 쪼개든 결과가 0원 달라진다.
  // 그래서 한도를 넘을 때만 세부 입력을 연다.
  group('한도를 넘을 때만 되묻는다', () {
    Future<void> openCalc(WidgetTester t, Set<String> picks) async {
      await dbService.saveProfile({'user_type': '직장인', 'gross_income': 45000000.0});
      t.view.physicalSize = const Size(1200, 9000);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
          MaterialApp(home: TaxSimulatorScreen(userType: '직장인', preOpened: picks)));
      await t.pumpAndSettle();
    }

    testWidgets('의료비 700만 이하면 본인·65세↑ 칸을 묻지 않는다', (t) async {
      await openCalc(t, {'medical'});
      await t.enterText(find.byKey(const Key('medicalOtherField')), '5000000');
      await t.pumpAndSettle();
      expect(find.textContaining('한도가 없으니'), findsNothing);
    });

    testWidgets('의료비 700만을 넘으면 본인·65세↑ 칸을 연다', (t) async {
      await openCalc(t, {'medical'});
      await t.enterText(find.byKey(const Key('medicalOtherField')), '9000000');
      await t.pumpAndSettle();
      expect(find.textContaining('700만원이 넘었어요'), findsOneWidget);
      expect(find.textContaining('그중 본인·65세 이상·장애인 의료비'), findsOneWidget);
    });

    testWidgets('연금저축 600만 이하면 IRP를 묻지 않는다', (t) async {
      await openCalc(t, {'pension'});
      await t.enterText(find.byKey(const Key('pensionSavingsField')), '4000000');
      await t.pumpAndSettle();
      expect(find.textContaining('IRP·퇴직연금으로 넣으면'), findsNothing);
    });

    testWidgets('연금저축 600만을 넘으면 IRP를 연다', (t) async {
      await openCalc(t, {'pension'});
      await t.enterText(find.byKey(const Key('pensionSavingsField')), '8000000');
      await t.pumpAndSettle();
      expect(find.textContaining('600만원이 한도예요'), findsOneWidget);
      expect(find.textContaining('IRP·퇴직연금(DC) 납입액'), findsOneWidget);
    });
  });
}
