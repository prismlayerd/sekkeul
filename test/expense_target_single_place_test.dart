import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **지출 목표를 정하는 곳은 하나다 — 가계부 분석 탭.**
///
/// 예전엔 홈에도 인라인 입력칸이 있었다. 두 곳이 서로를 모르는 채로 같은 값을
/// 고쳐서, 한쪽에서 바꾸고 다른 쪽을 열면 옛 값이 보였다. 연봉을 「내 정보」
/// 한 곳으로 모은 것과 같은 이유다(2026-07-24).
void main() {
  test('홈 상태 카드에 입력칸이 없다', () {
    final src = File('lib/ui/screens/home/home_status_section.dart').readAsStringSync();
    expect(src.contains('TextField'), isFalse,
        reason: '홈은 얼마나 썼는지 보여주는 자리다 — 설정은 가계부 한 곳에서.');
  });

  testWidgets('가계부를 분석 탭으로 바로 열 수 있다', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await t.pumpWidget(const MaterialApp(
      home: ExpenseCalendarScreen(initialView: 1),
    ));
    await t.pumpAndSettle();

    // 분석 탭에만 있는 것 — 목표를 정하는 자리.
    expect(findKo('지출 목표'), findsWidgets,
        reason: '홈에서 목표를 정하러 왔는데 달력이 열리면 길이 끊긴다');
  });
}
