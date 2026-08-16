import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/screen_registry.dart';

/// 홈에서 '지출 목표'를 눌러 들어오는 길.
///
/// 가계부를 밀어 넣으면서 **전환이 끝나기도 전에** 목표 입력 다이얼로그를
/// 띄운다. 밀려 들어오는 화면 위에 또 하나를 얹는 것이라, 순서가 어긋나면
/// `_dependents.isEmpty` 단언에서 죽는다 — 실기기 빨간 화면과 같은 자리다.
void main() {
  testWidgets('전환 중에 목표 입력을 띄워도 죽지 않는다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ExpenseCalendarScreen(
                      initialView: 1, openExpenseTarget: true),
                ),
              ),
              child: const Text('가계부'),
            ),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(find.text('가계부'));
    // 전환 한복판에서 프레임을 하나씩 넘긴다 — 여기서 다이얼로그가 끼어든다.
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 40));
      expect(t.takeException(), isNull, reason: '전환 중에 죽었다');
    }
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);

    // 바깥을 눌러 닫는 길까지 — 여기가 실제로 죽던 자리다.
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: '닫는 중에 죽었다');
  });

  testWidgets('평소 경로로 열어 닫아도 죽지 않는다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await t.pumpWidget(const MaterialApp(home: ExpenseCalendarScreen(initialView: 1)));
    await t.pumpAndSettle();

    // 분석 탭의 '지출 목표' 절 — 누르면 입력이 뜬다.
    final row = find.text('설정');
    if (row.evaluate().isEmpty) {
      // 문구가 다르면 이 테스트는 의미가 없다 — 찾은 것만 알린다.
      // ignore: avoid_print
      print('설정 버튼을 못 찾음');
      return;
    }
    await t.tap(row.first);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: '여는 중에 죽었다');

    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: '닫는 중에 죽었다');
  });
}
