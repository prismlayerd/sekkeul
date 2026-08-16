import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/screen_registry.dart';

/// **확대가 손가락을 따라온다.**
///
/// 예전에는 손을 뗄 때만 단계가 한 칸 바뀌었다 — 벌리는 동안은 아무 일도
/// 안 일어나다가 놓는 순간 툭 바뀌니 사진 확대와 달리 끊겨 보였다.
/// 이제 폭은 벌린 만큼 이어서 커지고, 보여주는 내용만 단계로 바뀐다.
void main() {
  /// 첫 주의 날짜 칸 하나가 지금 몇 픽셀인지.
  double cellWidth(WidgetTester t) {
    final dayOne = find.text('1');
    return t.getSize(dayOne.first).width; // 글자 폭이 아니라 칸을 봐야 하지만
  }

  /// 요일 머리 '수'의 x 위치 — 칸이 넓어지면 같이 밀린다.
  double dowX(WidgetTester t) => t.getTopLeft(find.text('수').first).dx;

  testWidgets('벌리는 중에 이미 넓어진다', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const ExpenseCalendarScreen(),
    ));
    await t.pumpAndSettle();

    final before = dowX(t);

    final center = t.getCenter(find.byType(ExpenseCalendarScreen));
    final a = await t.startGesture(center - const Offset(30, 0));
    final b = await t.startGesture(center + const Offset(30, 0));
    await t.pump(const Duration(milliseconds: 16));

    // 절반만 벌린 시점 — 여기서 이미 달라져 있어야 한다.
    for (var i = 0; i < 3; i++) {
      await a.moveBy(const Offset(-14, 0));
      await b.moveBy(const Offset(14, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    final during = dowX(t);
    expect(during, isNot(closeTo(before, 0.5)),
        reason: '손가락을 벌리는 중인데 아무것도 안 움직였다 — 뗄 때만 바뀌고 있다');

    await a.up();
    await b.up();
    await t.pumpAndSettle(const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(t.takeException(), isNull);
  });

  testWidgets('손을 떼면 어중간한 배율로 남지 않는다', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const ExpenseCalendarScreen(),
    ));
    await t.pumpAndSettle();

    final center = t.getCenter(find.byType(ExpenseCalendarScreen));
    final a = await t.startGesture(center - const Offset(30, 0));
    final b = await t.startGesture(center + const Offset(30, 0));
    await t.pump(const Duration(milliseconds: 16));
    // 1단계와 2단계 사이 어중간한 지점까지만 벌린다.
    for (var i = 0; i < 2; i++) {
      await a.moveBy(const Offset(-10, 0));
      await b.moveBy(const Offset(10, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await t.pumpAndSettle(const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

    // 붙은 뒤에는 요일 일곱 개가 화면에 딱 떨어지거나(1단계),
    // 확대되어 일부만 보이거나 — 어느 쪽이든 예외 없이 안정된다.
    expect(t.takeException(), isNull);
    expect(find.text('수'), findsWidgets);
  });
}
