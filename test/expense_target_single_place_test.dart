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
/// 다음엔 팝업으로 띄웠는데 그것도 틀렸다 — 이 앱은 종이 명세서라 위에 뜨는
/// 창이 없고, 팝업이 지금 보고 있던 지출 합계를 덮어 목표를 얼마로 잡을지
/// 판단할 근거를 가린다.
///
/// 지금은 입력칸 하나([ExpenseTargetField])를 두 곳에서 부르고, 부른 자리에서
/// **그대로 펼친다**.
void main() {
  test('입력칸을 두 벌 만들지 않는다', () {
    // 홈도 가계부도 제 TextField를 들면 서로를 모른 채 같은 값을 고친다.
    // 둘 다 공용 위젯을 부르기만 해야 한다.
    for (final f in [
      'lib/ui/screens/home/home_status_section.dart',
      'lib/ui/screens/expense_calendar_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src.contains('ExpenseTargetField'), isTrue, reason: '$f가 공용 입력칸을 안 쓴다');
    }
  });

  test('목표를 팝업으로 열지 않는다', () {
    // 종이 명세서 위에 뜨는 창은 없다. 목표는 보고 있던 그 줄에서 정해진다.
    //
    // 다른 화면의 확인 대화상자(삭제할까요?)까지 싸잡아 막지는 않는다 —
    // 그건 **입력**이 아니라 되돌릴 수 없는 일을 한 번 더 묻는 자리다.
    // 여기서 막는 것은 «값을 받는 창»이다.
    final field = File('lib/ui/components/expense_target_field.dart').readAsStringSync();
    expect(field.contains('showDialog'), isFalse, reason: '입력칸이 스스로 창을 띄운다');
    expect(field.contains('showModalBottomSheet'), isFalse);
    for (final f in [
      'lib/ui/screens/home/home_status_section.dart',
      'lib/ui/screens/expense_calendar_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src.contains('showExpenseTargetDialog'), isFalse,
          reason: '$f가 아직 옛 팝업 경로를 부른다');
    }
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
    expect(src.contains('onExpenseTargetChanged: _editExpenseTarget'), isTrue,
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
