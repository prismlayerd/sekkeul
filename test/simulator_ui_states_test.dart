import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/tax_simulator_screen.dart';
import 'support/ko_finder.dart';

/// 계산기 화면의 상태별 표시 — 값이 아니라 "그 상황에서 무엇이 보이는가"를 고정한다.
void main() {
  Future<void> open(WidgetTester t, {required Map<String, dynamic> profile}) async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({'user_type': '직장인', ...profile});
    t.view.physicalSize = const Size(400, 4000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(home: TaxSimulatorScreen(userType: '직장인')));
    await t.pumpAndSettle();
  }

  testWidgets('연봉을 아직 안 넣었으면 결과 자리에 무엇을 넣어야 하는지 알려준다', (t) async {
    await open(t, profile: {'gross_income': 0.0});
    expect(findKo('세전 총급여를 먼저 넣어주세요'), findsOneWidget);
  });

  testWidgets('연봉만 있고 공제가 없으면 빈 화면 대신 다음 할 일을 보여준다', (t) async {
    await open(t, profile: {'gross_income': 55000000.0});
    expect(findKo('아직 잡힌 공제가 없어요'), findsOneWidget,
        reason: '결과 영역이 통째로 사라지면 고장난 줄 안다');
  });

  testWidgets('낸 세금을 넘는 공제는 잘리고, 왜 잘렸는지 말해 준다', (t) async {
    // 총급여 2,520만 + 월세 50만 → 월세공제 102만이 결정세액(약 32만)을 넘는다.
    await open(t, profile: {'gross_income': 25200000.0, 'monthly_rent': 500000.0});
    expect(findKo('세금은 낸 만큼만 돌려받아요'), findsOneWidget);
    expect(findKo('환급되지 않아요'), findsOneWidget);
    // 잘린 뒤에도 원래 공제 합계를 함께 보여줘야 계산이 이해된다.
    expect(findKo('공제 합계'), findsOneWidget);
  });

  testWidgets('주담대 금액을 넣기 전에는 조건을 묻지 않는다', (t) async {
    await open(t, profile: {'gross_income': 55000000.0});
    expect(findKo('금리가 고정이에요'), findsNothing);
  });

  testWidgets('주담대 금액을 넣으면 한도가 갈리는 두 조건을 묻는다', (t) async {
    await open(t, profile: {'gross_income': 55000000.0});
    await t.tap(findKo('소득공제 추가항목 (선택)').first);
    await t.pumpAndSettle();

    final mortgageField = find.byKey(const Key('mortgageField'));
    expect(mortgageField, findsOneWidget, reason: '주담대 입력칸을 찾지 못했다');

    await t.enterText(mortgageField, '10000000');
    await t.pumpAndSettle();

    expect(findKo('금리가 고정이에요'), findsOneWidget);
    expect(findKo('처음부터 원금도 같이 갚아요'), findsOneWidget);
    // 기본값은 800만원 — 조건을 고르지 않으면 최고 한도를 주지 않는다.
    expect(findKo('지금 한도: 연 800만원'), findsOneWidget);

    await t.tap(findKo('금리가 고정이에요'));
    await t.pumpAndSettle();
    expect(findKo('지금 한도: 연 1800만원'), findsOneWidget);

    await t.tap(findKo('처음부터 원금도 같이 갚아요'));
    await t.pumpAndSettle();
    expect(findKo('지금 한도: 연 2000만원'), findsOneWidget);
  });
}
