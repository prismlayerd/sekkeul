import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/home_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **홈은 두 장이다.**
///
/// 한 장에 절이 다섯(01~05) 쌓여 "너무 많이 보인다"는 의견이 모였다. 매달
/// 보는 것(돈·알림)과 필요할 때 찾는 것(도구·문답)을 갈랐다.
///
/// 장을 넘기는 길은 **손가락과 맨 아래 장 표시** 둘이다. 1장 끝에 "다음
/// 장으로" 링크를 뒀었는데 돌아오는 길이 없어 한쪽으로만 흐르는 문이었다.
/// **양방향으로 오간다는 것이 이 테스트의 핵심이다.**
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

  testWidgets('1장에 돈이 있고 2장 것은 없다', (t) async {
    await pumpHome(t);

    expect(findKo('이번 달 지출'), findsWidgets, reason: '1장에 02가 없다');
    // 04·05는 2장으로 갔다. PageView는 안 보이는 장도 만들어 둘 수 있으므로
    // **화면에 보이는지**로 본다.
    expect(findKo('자주 묻는 질문').hitTestable(), findsNothing,
        reason: '05가 아직 1장에 보인다');
  });

  /// 손가락으로 옆으로 민다.
  Future<void> swipe(WidgetTester t, {required bool toNext}) async {
    final dx = toNext ? -300.0 : 300.0;
    await t.drag(find.byType(PageView), Offset(dx, 0));
    await t.pumpAndSettle();
  }

  testWidgets('좌우로 밀어 두 장을 오간다', (t) async {
    await pumpHome(t);

    await swipe(t, toNext: true);
    expect(findKo('세무 도구').hitTestable(), findsWidgets,
        reason: '옆으로 밀었는데 2장이 안 나온다');

    // **돌아오는 길이 있어야 한다.** 예전 링크는 가는 길만 있었다.
    await swipe(t, toNext: false);
    expect(findKo('이번 달 지출').hitTestable(), findsWidgets,
        reason: '되돌아오지 못한다 — 한쪽으로만 흐르는 문이다');
  });

  testWidgets('머리(유형 선택)는 두 장에서 계속 보인다', (t) async {
    await pumpHome(t);
    expect(findKo('N잡러'), findsOneWidget);

    await swipe(t, toNext: true);
    expect(findKo('N잡러'), findsOneWidget,
        reason: '장을 넘겼더니 유형 선택이 사라졌다 — 머리는 고정이어야 한다');
  });

  testWidgets('2장의 세무 도구는 펼쳐진 채로 온다', (t) async {
    await pumpHome(t);
    await swipe(t, toNext: true);

    // 도구를 찾으러 온 장이다. 도착해서 한 번 더 눌러야 목록이 나오면
    // 문을 두 번 여는 셈이다.
    expect(findKo('경정청구').hitTestable(), findsWidgets,
        reason: '세무 도구가 접힌 채로 있다');
  });
}
