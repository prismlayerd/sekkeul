import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/tax_simulator_screen.dart';
import 'support/ko_finder.dart';

/// 주택담보대출 한도를 가르는 두 조건(소법 §52⑥)을 **두 화면이 똑같이** 묻는지 본다.
///
/// 한 화면만 물으면 같은 사람이 같은 대출을 넣고도 화면마다 다른 답을 받는다.
void main() {
  Future<void> seed() async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({
      'user_type': '직장인',
      'gross_income': 55000000.0,
    });
  }

  void sizeUp(WidgetTester t) {
    t.view.physicalSize = const Size(400, 4000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('계산기 — 금액을 넣어야 조건을 묻고, 기본 한도는 800만원', (t) async {
    await seed();
    sizeUp(t);
    await t.pumpWidget(const MaterialApp(home: TaxSimulatorScreen(userType: '직장인')));
    await t.pumpAndSettle();

    await t.tap(findKo('소득공제 추가항목 (선택)').first);
    await t.pumpAndSettle();
    expect(findKo('금리가 고정이에요'), findsNothing, reason: '금액 전에는 묻지 않는다');

    await t.enterText(find.byKey(const Key('mortgageField')), '10000000');
    await t.pumpAndSettle();
    expect(findKo('지금 한도: 연 800만원'), findsOneWidget);

    await t.tap(findKo('금리가 고정이에요'));
    await t.pumpAndSettle();
    expect(findKo('지금 한도: 연 1800만원'), findsOneWidget);

    await t.tap(findKo('처음부터 원금도 같이 갚아요'));
    await t.pumpAndSettle();
    expect(findKo('지금 한도: 연 2000만원'), findsOneWidget);
  });

  // 「연말정산 진단」 화면이 같은 질문을 하는지 보던 케이스가 있었다. 그 화면을
  // 지우면서(2026-08-24) 같이 걷었다 — MortgageConditionRows는 이제 종소세
  // 진단 한 곳에서만 쓰이고, 위 케이스가 그걸 지킨다.
}
