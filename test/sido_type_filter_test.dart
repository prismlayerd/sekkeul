import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/benefit_screen.dart';
import 'package:secul/ui/screens/my_info_screen.dart';

/// 사는 시/도는 내 정보에서 고르고 그대로 저장돼야 지역 소식이 걸러진다.
/// 근로자 전용 제도는 프리랜서 혜택 목록에 나오지 않아야 한다.
void main() {
  testWidgets('내 정보에서 시/도를 고르면 프로필에 저장된다', (t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({'user_type': '프리랜서'});

    await t.pumpWidget(MaterialApp(
      home: MyInfoScreen(userType: '프리랜서', onProfileChanged: () {}),
    ));
    await t.pumpAndSettle();

    expect(find.textContaining('우리 시·도 소식만'), findsOneWidget);
    await t.tap(find.text('사는 지역'));
    await t.pumpAndSettle();
    await t.tap(find.text('부산'));
    await t.pumpAndSettle();
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();

    expect((await dbService.getProfile())!['sido'], '부산');
    expect(find.text('부산'), findsOneWidget);
  });

  Future<bool> finds(WidgetTester t, String userType, String q) async {
    await t.pumpWidget(MaterialApp(home: BenefitScreen(userType: userType, key: UniqueKey())));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.search_rounded));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), q);
    await t.pumpAndSettle();
    return find.text('배우자 출산전후휴가').evaluate().isNotEmpty;
  }

  testWidgets('근로자 전용 혜택은 프리랜서에게 안 보인다', (t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    expect(await finds(t, '직장인', '배우자 출산'), isTrue);
    expect(await finds(t, 'N잡러', '배우자 출산'), isTrue);
    expect(await finds(t, '프리랜서', '배우자 출산'), isFalse);
  });
}
