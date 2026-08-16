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
/// 옆으로 넘길 수 있다는 걸 모르는 사람이 있으므로 1장 끝에 길을 하나 둔다 —
/// 그게 없으면 04·05는 그냥 사라진 게 된다. **그 길이 이 테스트의 핵심이다.**
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

  testWidgets('길을 누르면 2장으로 간다', (t) async {
    await pumpHome(t);

    final link = findKo('세무 도구 · 자주 묻는 질문');
    expect(link, findsOneWidget, reason: '2장으로 가는 길이 없다 — 04·05가 사라진 셈이다');

    await t.ensureVisible(link);
    await t.pumpAndSettle();
    await t.tap(link);
    await t.pumpAndSettle();

    expect(findKo('자주 묻는 질문').hitTestable(), findsWidgets,
        reason: '길을 눌렀는데 2장이 안 나온다');
  });

  testWidgets('머리(유형 선택)는 두 장에서 계속 보인다', (t) async {
    await pumpHome(t);

    expect(findKo('N잡러'), findsOneWidget);

    await t.tap(findKo('세무 도구 · 자주 묻는 질문'));
    await t.pumpAndSettle();

    expect(findKo('N잡러'), findsOneWidget,
        reason: '장을 넘겼더니 유형 선택이 사라졌다 — 머리는 고정이어야 한다');
  });
}
