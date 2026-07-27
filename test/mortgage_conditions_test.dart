import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/tax_simulator_screen.dart';
import 'package:secul/ui/screens/year_end_tax_screen.dart';
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

  testWidgets('연말정산 진단 — 같은 질문을 같은 문구로 묻는다', (t) async {
    await seed();
    sizeUp(t);
    await t.pumpWidget(
        const MaterialApp(home: YearEndTaxScreen(userType: '직장인', directWizardMode: true)));
    await t.pumpAndSettle();

    // 주담대 단계까지 '다음'을 눌러 이동한다.
    var reached = false;
    for (var i = 0; i < 10; i++) {
      if (findKo('주담대·고향사랑을 확인할게요').evaluate().isNotEmpty) {
        reached = true;
        break;
      }
      final next = findKo('다음');
      if (next.evaluate().isEmpty) break;
      await t.tap(next.first);
      await t.pumpAndSettle();
    }
    expect(reached, isTrue, reason: '위저드의 주담대 단계에 도달하지 못했다');

    expect(findKo('금리가 고정이에요'), findsNothing, reason: '금액 전에는 묻지 않는다');

    // 이 단계의 첫 금액칸이 주담대다.
    await t.enterText(find.byType(TextField).first, '10000000');
    await t.pumpAndSettle();

    // 계산기와 **글자 그대로 같은** 질문이어야 한다 — 공용 위젯을 쓰므로 어긋날 수 없다.
    expect(findKo('금리가 고정이에요'), findsOneWidget);
    expect(findKo('처음부터 원금도 같이 갚아요'), findsOneWidget);
    expect(findKo('지금 한도: 연 800만원'), findsOneWidget);

    await t.tap(findKo('금리가 고정이에요'));
    await t.tap(findKo('처음부터 원금도 같이 갚아요'));
    await t.pumpAndSettle();
    expect(findKo('지금 한도: 연 2000만원'), findsOneWidget);
  });
}
