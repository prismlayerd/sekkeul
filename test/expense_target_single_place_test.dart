import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **지출 목표 입력칸은 하나다 — 부르는 곳이 둘일 뿐.**
///
/// 처음엔 홈과 가계부가 각자 입력칸을 들고 있었다. 서로를 모르는 채로 같은
/// 값을 고쳐서, 한쪽에서 바꾸고 다른 쪽을 열면 옛 값이 보였다.
///
/// 그래서 한동안 홈에서 누르면 가계부로 **보냈는데**, 실기기에서 써 보니
/// 홈에서 목표를 정하려던 사람이 낯선 화면으로 끌려가는 게 어색했다.
/// 지금은 입력칸 하나(showExpenseTargetDialog)를 두 곳에서 부른다 —
/// 홈에서 누르면 **홈에 머문 채** 열린다.
void main() {
  test('홈 상태 카드에 입력칸이 없다', () {
    final src = File('lib/ui/screens/home/home_status_section.dart').readAsStringSync();
    expect(src.contains('TextField'), isFalse,
        reason: '홈은 얼마나 썼는지 보여주는 자리다 — 설정은 가계부 한 곳에서.');
  });

  test('홈의 목표 유도 문구가 정해진 그대로다', () {
    // 2026-08-15에 이 문구를 바꾸라는 요청을 받고 스크립트로 치환했는데,
    // 그 치환만 assert 없이 돌아 조용히 실패했다. 바뀐 줄 알고 보고까지 했다.
    final src = File('lib/ui/screens/home/home_status_section.dart').readAsStringSync();
    expect(src.contains('이번 달 지출 목표액을 정하고 관리해봐요.'), isTrue);
    expect(src.contains('목표를 정하면 남은 돈을 알려드려요'), isFalse,
        reason: '옛 문구가 남아 있다');
  });

  test('홈이 목표를 정하러 가계부로 보내지 않는다', () {
    final src = File('lib/ui/screens/home_screen.dart').readAsStringSync();
    expect(src.contains('onSetExpenseTarget: _editExpenseTarget'), isTrue,
        reason: '홈에서 누르면 홈에서 열려야 한다');
    expect(src.contains('openExpenseTarget'), isFalse,
        reason: '가계부로 보내던 경로가 남아 있다');
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
