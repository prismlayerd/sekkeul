import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/remote_notices.dart';
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
    await dbService.saveProfile({'user_type': '프리랜서', 'type_identified': true});

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

  testWidgets('유형은 내 정보에서 바꾸고 프로필에 저장된다', (t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({'user_type': '직장인', 'type_identified': true});
    var changed = 0;

    await t.pumpWidget(MaterialApp(
      home: MyInfoScreen(userType: '직장인', onProfileChanged: () => changed++),
    ));
    await t.pumpAndSettle();
    expect(find.text('예상 연봉'), findsOneWidget);

    // 버튼이 아니라 소득 항목 자가 진단으로 유형을 바꾼다.
    await t.tap(find.text('직장인'));
    await t.pumpAndSettle();
    await t.tap(find.text('회사에서 받는 월급')); // 근로소득 체크 해제
    await t.tap(find.text('3.3% 떼는 프리랜서 일')); // 사업소득 체크
    await t.pumpAndSettle();
    await t.tap(find.text('유형 확정하기'));
    await t.pumpAndSettle();

    expect((await dbService.getProfile())!['user_type'], '프리랜서');
    expect(changed, 1, reason: '홈이 다시 읽어야 가계부·알림이 새 유형으로 돈다');
    // 프리랜서에겐 안 쓰이는 항목이 바로 빠진다.
    expect(find.text('예상 연봉'), findsNothing);
  });

  testWidgets('혜택 탭 맨 위 맞춤 혜택 — 내 유형·시/도 소식만', (t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    Notice n(String id, String title, {List<String> a = const [], List<String> r = const []}) =>
        Notice(id: id, label: '청년', title: title, summary: '', body: const [],
            date: DateTime(2026, 9, 20), audience: a, regions: r);
    final notices = [
      n('a', '전국 공통 소식'),
      n('b', '서울 청년 월세', r: ['서울']),
      n('c', '부산 청년 교통비', r: ['부산']),
      n('d', '근로자 전용', a: ['직장인', 'N잡러']),
    ];
    await t.pumpWidget(MaterialApp(
      home: BenefitScreen(userType: '프리랜서', sido: '서울', notices: notices),
    ));
    await t.pumpAndSettle();

    expect(find.text('서울 · 프리랜서'), findsOneWidget);
    expect(find.text('전국 공통 소식'), findsOneWidget);
    expect(find.text('서울 청년 월세'), findsOneWidget);
    expect(find.text('부산 청년 교통비'), findsNothing);
    expect(find.text('근로자 전용'), findsNothing);
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
