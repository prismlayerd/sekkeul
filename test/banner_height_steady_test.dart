import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/home/home_banner_carousel.dart';
import 'package:secul/ui/screens/home/home_status_section.dart';
import 'package:secul/ui/screens/home_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **배너가 돌아도 아래가 움직이면 안 된다.**
///
/// 6초마다 카드가 바뀔 때 그 아래 절취선부터 화면 전체가 위아래로 들썩였다.
/// 읽고 있던 줄이 손 밑에서 도망간다.
///
/// 카드 높이를 눈으로 맞추는 건 이미 두 번 실패했다. 여기서는 **아래 것의
/// 위치를 직접 재서** 붙잡는다 — 원인이 무엇이든 이 값이 흔들리면 실패다.
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  testWidgets('카드가 넘어가도 아래 절취선이 제자리다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    ));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }

    // 배너 아래에 있는 첫 덩어리. 배너가 커지거나 작아지면 이게 따라 움직인다.
    double belowY() => t.getTopLeft(find.byType(HomeStatusSection)).dy;

    final ticks = find.bySemanticsLabel(RegExp(r'^\d+번째 소식$'));
    final count = ticks.evaluate().length;
    expect(count, greaterThan(1), reason: '돌아갈 카드가 없으면 이 테스트는 의미가 없다');

    final seen = <int, double>{0: belowY()};
    for (var i = 1; i < count; i++) {
      await t.tap(ticks.at(i));
      // 카드 전환은 500ms 페이드다. 전환 **도중에도** 움직이면 안 되므로
      // 중간과 끝을 둘 다 본다 — 예전에 AnimatedSize가 여기서 늘었다 줄었다.
      await t.pump(const Duration(milliseconds: 250));
      final mid = belowY();
      await t.pump(const Duration(milliseconds: 400));
      seen[i] = belowY();
      expect(mid, seen[0],
          reason: '$i번째 카드로 넘어가는 **도중**에 아래가 ${mid - seen[0]!}픽셀 움직였다');
    }

    final moved = seen.entries.where((e) => e.value != seen[0]).toList();
    expect(moved, isEmpty,
        reason: '카드마다 아래 위치가 다르다 (0번=${seen[0]}):\n'
            '${moved.map((e) => '  ${e.key}번째 → ${e.value} (${e.value - seen[0]!}픽셀)').join('\n')}');
  });

  testWidgets('두 줄로 쓴 문장의 뒷줄이 안 사라진다', (t) async {
    // 높이를 맞추려고 한 줄로 조였더니 `공제 문턱까지 / 912만원 남았어요`의
    // **금액이 통째로 없어졌다**. 줄임표도 안 붙어서 잘린 줄도 몰랐다.
    // 실기기 스크린샷에서야 발견했다 — 자동으로 잡히게 둔다.
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    Future<void> pumpOne(String headline) => t.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: HomeBannerCarousel(
              cards: [
                BannerCardData(
                  label: '신카 공제',
                  headline: headline,
                  action: '신용카드 공제 확인',
                  glyph: '카',
                  onTap: () {},
                ),
              ],
              activeIndex: 0,
              onTickTap: (_) {},
              onDismiss: (_) {},
            ),
          ),
        ));

    await pumpOne('공제 문턱까지\n912만원 남았어요');
    await t.pumpAndSettle();
    final two = t.getSize(find.byType(HomeBannerCarousel)).height;
    expect(findKo('912만원 남았어요'), findsOneWidget,
        reason: '뒷줄이 사라졌다 — 정작 알려주려던 금액이 이 줄에 있다');

    // 한 줄짜리도 같은 높이여야 한다. 아니면 6초마다 아래가 들썩인다.
    await pumpOne('공제 문턱을 넘었어요');
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(HomeBannerCarousel)).height, two,
        reason: '한 줄 카드와 두 줄 카드의 높이가 다르다');
  });
}
