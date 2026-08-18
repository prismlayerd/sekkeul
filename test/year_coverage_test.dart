import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/year_coverage.dart';
import 'package:secul/ui/screens/home_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:secul/ui/screens/home/home_banner_carousel.dart';

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **한 해를 안 덮으면 연간 숫자를 내놓지 않는다.**
///
/// 8월에 깐 사람의 가계부에는 8월분밖에 없다. 그런데 카드 공제 문턱은 1월부터의
/// 누적으로 판정된다. 그대로 계산하면 "912만원 남았다"고 말하는데 실제로는 이미
/// 넘겼을 수 있다 — 앱이 자신 있게 틀린다.
void main() {
  final year = DateTime.now().year;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  group('덮였는지 판정', () {
    setUp(() async {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
    });

    test('아무것도 안 했으면 안 덮였다', () async {
      expect(await YearCoverage.isComplete(year), isFalse);
    });

    test('「다 넣었어요」를 누르면 덮였다', () async {
      await YearCoverage.markComplete(year);
      expect(await YearCoverage.isComplete(year), isTrue);
    });

    test('1~7월에 한 푼도 안 쓴 사람도 통과한다', () async {
      // **0원이 정답인 사람이 있다.** 기록이 있는지로 세면 이 사람의 게이트는
      // 영원히 안 열린다. 그래서 판정은 기록이 아니라 사용자의 확인이다.
      await YearCoverage.setBackfill(year, const Backfill());
      await YearCoverage.markComplete(year);
      expect(await YearCoverage.isComplete(year), isTrue);
      expect((await YearCoverage.backfill(year)).total, 0);
    });

    test('1월부터 써 온 사람은 채울 게 없다', () async {
      await dbService.insertExpense(ExpenseItem(
        id: 'j1',
        date: DateTime(year, 1, 10),
        amount: 30000,
        content: '',
        category: '기타',
        paymentMethod: '신용카드',
        userType: '직장인',
      ));
      expect(await YearCoverage.isComplete(year), isTrue,
          reason: '1월 기록이 있는데 채우라고 하면 할 일이 없는 사람을 붙잡는 것이다');
    });

    test('저장했다 불러오면 같은 값이다', () async {
      await YearCoverage.setSpecials(
          year, const CardSpecials(market: 320000, transport: 180000));
      final s = await YearCoverage.specials(year);
      expect(s.market, 320000);
      expect(s.transport, 180000);
      expect(s.culture, 0);
      expect(s.total, 500000);
    });
  });

  testWidgets('안 덮인 홈은 문턱 숫자 대신 채우라고 한다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    // 씨더는 한 해를 덮은 사람을 만든다. 여기서는 **연중 가입자**를 본다.
    await dbService.setAppState('backfill_done_$year', '');

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    ));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }

    // 틀린 숫자는 안 그린다.
    expect(findKo('남음'), findsNothing,
        reason: '틀린 «OO원 남음»이 아직 화면에 있다');
    // 채우라는 말은 **배너**가 한다 — 02에 겹쳐 넣으면 같은 얘기가 두 번이다.
    final cards = t
        .widget<HomeBannerCarousel>(find.byType(HomeBannerCarousel))
        .cards;
    expect(cards.any((c) => c.label == '이전 달'), isTrue,
        reason: '숫자만 가리고 채우라는 말이 어디에도 없다');
  });
}
