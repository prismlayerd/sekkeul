import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/home_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **홈은 세 장이다.**
///
/// 돈 얘기(가계부)가 1장부터 나오면 가계부 앱처럼 읽힌다는 의견이 있었다.
/// 그래서 혜택·알림(1장) / 가계부(2장) / 세무 도구(3장)로 성격별로 갈랐다.
///
/// 장을 넘기는 길은 **손가락과 맨 아래 장 표시** 둘이다. 양방향으로 오간다는
/// 것이 이 테스트의 핵심이다(예전엔 한쪽으로만 흐르는 문이었다).
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  Future<void> pumpHome(WidgetTester t) async {
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
  }

  Future<void> swipe(WidgetTester t, {required bool toNext}) async {
    final dx = toNext ? -300.0 : 300.0;
    await t.drag(find.byType(PageView), Offset(dx, 0));
    await t.pumpAndSettle();
  }

  testWidgets('1장엔 가계부가 없다', (t) async {
    await pumpHome(t);

    // 02(이번 달 현황)는 2장으로 갔다. PageView는 안 보이는 장도 만들어 둘 수
    // 있으므로 **화면에 보이는지**로 본다.
    expect(findKo('이번 달 지출').hitTestable(), findsNothing,
        reason: '가계부(02)가 아직 1장에 보인다');
    expect(findKo('세무 도구').hitTestable(), findsNothing,
        reason: '세무 도구가 아직 1장에 보인다');
  });

  testWidgets('좌우로 밀어 세 장을 오간다', (t) async {
    await pumpHome(t);

    await swipe(t, toNext: true);
    expect(findKo('이번 달 지출').hitTestable(), findsWidgets,
        reason: '옆으로 밀었는데 2장(가계부)이 안 나온다');

    await swipe(t, toNext: true);
    expect(findKo('세무 도구').hitTestable(), findsWidgets,
        reason: '한 번 더 밀었는데 3장(세무 도구)이 안 나온다');

    // **돌아오는 길이 있어야 한다.** 예전 링크는 가는 길만 있었다.
    await swipe(t, toNext: false);
    expect(findKo('이번 달 지출').hitTestable(), findsWidgets,
        reason: '2장으로 못 돌아왔다');

    await swipe(t, toNext: false);
    expect(findKo('이번 달 지출').hitTestable(), findsNothing,
        reason: '1장으로 못 돌아왔다');
  });

  testWidgets('머리(지금 유형·지역)는 세 장에서 계속 보인다', (t) async {
    // 유형 선택 버튼은 내 정보로 옮겼다(2026-09-24). 머리에는 지금 무엇으로
    // 보고 있는지만 남는다 — 그게 장을 넘겨도 보여야 한다.
    await pumpHome(t);
    expect(findKo('직장인 · 지역 미설정'), findsOneWidget);

    await swipe(t, toNext: true);
    expect(findKo('직장인 · 지역 미설정'), findsOneWidget,
        reason: '2장으로 넘겼더니 머리가 사라졌다 — 머리는 고정이어야 한다');

    await swipe(t, toNext: true);
    expect(findKo('직장인 · 지역 미설정'), findsOneWidget,
        reason: '3장으로 넘겼더니 머리가 사라졌다 — 머리는 고정이어야 한다');
  });

  testWidgets('3장의 세무 도구는 펼쳐진 채로 온다', (t) async {
    await pumpHome(t);
    await swipe(t, toNext: true);
    await swipe(t, toNext: true);

    // 도구를 찾으러 온 장이다. 도착해서 한 번 더 눌러야 목록이 나오면
    // 문을 두 번 여는 셈이다.
    expect(findKo('경정청구').hitTestable(), findsWidgets,
        reason: '세무 도구가 접힌 채로 있다');
  });
}
