import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/components/expense_target_dialog.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/screen_registry.dart';

/// **지출 목표 입력 — 홈과 가계부가 같은 것을 쓴다.**
///
/// 바깥을 눌러 닫는 길이 실기기에서 빨간 화면(`_dependents.isEmpty`)을 만든
/// 자리다. autofocus를 주면 포커스 노드를 프레임워크가 들고, 글자칸이 포커스를
/// 쥔 채 트리가 해체되면서 상속 위젯이 딸린 것들을 둔 채 걷힌다. 디버그에서만
/// 도는 단언이라 스토어 빌드에서는 조용히 넘어갔을 뿐, 트리가 어긋나는 건
/// 릴리스에서도 같다.
///
/// 입력칸이 하나라 여기서 한 번 붙잡으면 두 화면을 다 덮는다.
void main() {
  Widget host(void Function(double?) onDone) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async =>
                    onDone(await showExpenseTargetDialog(context, 0)),
                child: const Text('목표'),
              ),
            ),
          ),
        ),
      );

  setUp(() async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
  });

  testWidgets('바깥을 눌러 닫아도 죽지 않는다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    double? result;
    var called = false;
    await t.pumpWidget(host((v) {
      result = v;
      called = true;
    }));
    await t.pumpAndSettle();

    await t.tap(find.text('목표'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: '여는 중에 죽었다');

    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: '닫는 중에 죽었다');
    expect(called, isTrue);
    expect(result, isNull, reason: '취소했는데 값이 돌아왔다');
  });

  testWidgets('저장하면 정한 값이 돌아온다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    double? result;
    await t.pumpWidget(host((v) => result = v));
    await t.pumpAndSettle();

    await t.tap(find.text('목표'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '1500000');
    await t.pumpAndSettle();
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();

    expect(result, 1500000);
  });

  testWidgets('가계부 분석 탭에서도 같은 입력이 뜬다', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await t.pumpWidget(const MaterialApp(home: ExpenseCalendarScreen(initialView: 1)));
    await t.pumpAndSettle();

    final row = find.text('설정');
    if (row.evaluate().isEmpty) return; // 이미 목표가 있으면 '수정'이다
    await t.tap(row.first);
    await t.pumpAndSettle();

    expect(find.text('이달 지출 목표'), findsOneWidget);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
