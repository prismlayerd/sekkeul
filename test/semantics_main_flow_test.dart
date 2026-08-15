import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/day_entry_screen.dart';
import 'package:secul/ui/screens/deduction_gate_screen.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';
import 'package:secul/ui/screens/home_screen.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/screen_registry.dart';

/// **돈을 적는 길은 눈을 감고도 지나갈 수 있어야 한다.**
///
/// 화면 88개 전부에 라벨을 붙이는 건 다음 일이고, 홈 → 달력 → 하루 입력까지는
/// 지금 붙잡아 둔다. 여기가 막히면 앱을 아예 못 쓴다.
///
/// 잡는 것: **누를 수 있는데 이름이 없는 것.** 도형만 그려 둔 버튼, 아이콘 하나
/// 짜리 닫기, CustomPaint로 그린 마크가 여기 걸린다.
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  /// 이름 없는 누름 노드를 모은다.
  List<String> unlabeled(SemanticsNode root) {
    final out = <String>[];
    void walk(SemanticsNode n) {
      final d = n.getSemanticsData();
      final tappable = d.hasAction(SemanticsAction.tap);
      final named = d.label.trim().isNotEmpty ||
          d.tooltip.trim().isNotEmpty ||
          d.hint.trim().isNotEmpty ||
          d.value.trim().isNotEmpty;
      // 글자 입력칸은 라벨 대신 옆의 항목 이름이 설명한다 — 여기서 안 본다.
      final isField = d.hasFlag(SemanticsFlag.isTextField);
      if (tappable && !named && !isField) out.add('rect=${n.rect}');
      n.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    walk(root);
    return out;
  }

  Future<void> check(WidgetTester t, String name, Widget screen) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(key: ValueKey(name), home: screen));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    final root = t.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
    final bad = unlabeled(root);
    handle.dispose();
    expect(bad, isEmpty,
        reason: '$name — 이름 없이 누를 수 있는 것이 ${bad.length}개다.\n'
            '${bad.join('\n')}');
  }

  testWidgets('홈에서 누를 수 있는 것마다 이름이 있다', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await seedRealisticUser('직장인');
    await check(t, 'HomeScreen', const HomeScreen());
  });

  testWidgets('달력에서 날짜 칸마다 무엇이 적혔는지 읽힌다', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await seedRealisticUser('직장인');
    await check(t, 'ExpenseCalendarScreen', const ExpenseCalendarScreen());
  });

  testWidgets('공제 고르기에서 누를 수 있는 것마다 이름이 있다', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await seedRealisticUser('직장인');
    await check(t, 'DeductionGateScreen', const DeductionGateScreen(userType: '직장인'));
  });

  testWidgets('하루 입력에서 누를 수 있는 것마다 이름이 있다', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await seedRealisticUser('직장인');
    await check(
      t,
      'DayEntryScreen',
      DayEntryScreen(
        dates: {DateTime(2026, 8, 15)},
        userType: '직장인',
        incomesByDay: const {},
        expensesByDay: const {},
      ),
    );
  });
}
