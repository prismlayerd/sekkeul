import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/backfill_screen.dart';
import 'package:secul/ui/screens/home_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:secul/ui/screens/home/home_banner_carousel.dart';

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **유형마다 묻는 것이 다르다.**
///
/// 카드 공제는 근로소득자만 받는다(조특법 §126의2). 프리랜서에게 카드 사용액을
/// 물으면 아무리 정확히 넣어도 공제가 0원이다 — 헛수고를 시키는 것이고, 앱이
/// 세법을 모른다는 뜻이 된다.
///
/// 반대로 사업소득이 없는 직장인에게 총수입을 물으면 답할 것이 없다.
/// N잡러만 둘 다다 — 근로소득이 있어 카드공제 대상이면서 사업소득도 있다.
void main() {
  final year = DateTime.now().year;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  Future<void> pumpBackfill(WidgetTester t, String type) async {
    // 목록 전체가 만들어지게 화면을 길게 잡는다 — ListView는 보이는 것만 짓는다.
    t.view.physicalSize = const Size(390, 2600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: BackfillScreen(userType: type),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('직장인에게 사업 총수입을 묻지 않는다', (t) async {
    await pumpBackfill(t, '직장인');
    expect(findKo('신용카드'), findsWidgets);
    expect(findKo('전통시장'), findsOneWidget);
    expect(findKo('총수입'), findsNothing,
        reason: '사업소득이 없는 사람에게 답할 수 없는 것을 묻고 있다');
  });

  testWidgets('프리랜서에게 카드 사용액을 묻지 않는다', (t) async {
    await pumpBackfill(t, '프리랜서');
    expect(findKo('총수입'), findsOneWidget);
    expect(findKo('경비'), findsWidgets);
    // 카드공제는 근로소득자 전용이다. 넣어 봐야 공제가 0원이다.
    expect(findKo('신용카드'), findsNothing,
        reason: '프리랜서에게 받을 수 없는 공제의 재료를 묻고 있다');
    expect(findKo('전통시장'), findsNothing);
  });

  testWidgets('N잡러에게는 둘 다 묻는다', (t) async {
    await pumpBackfill(t, 'N잡러');
    expect(findKo('총수입'), findsOneWidget);
    expect(findKo('신용카드'), findsWidgets,
        reason: 'N잡러는 근로소득이 있어 카드공제 대상이다');
  });

  testWidgets('달마다 칸이 있고 앱이 더해 준다', (t) async {
    // 합계 한 칸으로 받으면 사용자가 카드사 앱을 보며 일곱 달치를 손으로
    // 더해야 한다. 더하다 틀리면 그 값이 그대로 세금 계산에 들어간다.
    await pumpBackfill(t, '직장인');
    final last = DateTime.now().month - 1;
    for (var m = 1; m <= last; m++) {
      expect(findKo('$m월'), findsWidgets, reason: '$m월 칸이 없다');
    }
    expect(findKo('합계'), findsOneWidget, reason: '앱이 더해 주지 않는다');
  });

  testWidgets('안 덮인 프리랜서 홈은 예상 환급 대신 채우라고 한다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await seedRealisticUser('프리랜서');
    await dbService.setAppState('backfill_done_$year', '');

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    ));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }

    // 안내는 **배너**가 맡는다 — 02 안에 겹쳐 넣지 않는다.
    final cards = t
        .widget<HomeBannerCarousel>(find.byType(HomeBannerCarousel))
        .cards;
    final fill = cards.where((c) => c.label == '이전 달').toList();
    expect(fill, hasLength(1), reason: '채우라는 배너가 없다');
    expect(fill.single.dismissible, isFalse,
        reason: '닫으면 연간 계산으로 가는 길이 사라진다');
    expect(findKo('카드 공제 문턱'), findsNothing,
        reason: '프리랜서에게 받을 수 없는 공제를 보여주고 있다');
  });
}
