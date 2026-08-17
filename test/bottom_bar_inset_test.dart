import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/day_entry_screen.dart';

import 'support/screen_registry.dart';

/// **화면 맨 아래 버튼이 시스템 내비게이션 바에 안 깔린다.**
///
/// 안드로이드 15(targetSdk 35+)부터 edge-to-edge가 강제다. 시스템 바가 투명해지고
/// 앱이 그 아래까지 그린다. Material의 `BottomNavigationBar`는 스스로 그만큼
/// 자리를 비우지만, 직접 만든 바는 아무도 안 비워 준다.
///
/// 그래서 가계부 하루 입력에서 **「저장」이 내비게이션 바 밑에 깔려 안 눌렸다.**
/// 저장이 안 되는 건 적은 걸 잃는 일이라, 눈으로 찾을 때까지 기다릴 수 없다.
void main() {
  testWidgets('저장 버튼이 내비게이션 바 위에 있다', (t) async {
    // 3버튼 내비게이션을 쓰는 기기 — 아래 48px이 시스템 것이다.
    const navBar = 48.0;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    t.view.padding = const FakeViewPadding(bottom: navBar);
    t.view.viewPadding = const FakeViewPadding(bottom: navBar);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPadding);
    addTearDown(t.view.resetViewPadding);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();

    await t.pumpWidget(MaterialApp(
      home: DayEntryScreen(
        dates: {DateTime.now()},
        userType: '직장인',
        incomesByDay: const {},
        expensesByDay: const {},
      ),
    ));
    await t.pumpAndSettle();

    final done = find.text('완료');
    expect(done, findsOneWidget, reason: '아래 바를 못 찾았다');

    final bottom = t.getBottomLeft(done).dy;
    final safeLine = 844.0 - navBar;
    expect(bottom, lessThanOrEqualTo(safeLine),
        reason: '버튼 아래끝이 $bottom인데 시스템 바가 $safeLine부터 덮는다 — 손가락이 안 닿는다');
  });

  test('직접 만든 아래 바는 전부 SafeArea를 두른다', () {
    // 새 화면에서 같은 실수가 반복되지 않게 한다. Material의 BottomNavigationBar와
    // BottomAppBar는 스스로 인셋을 넣으므로 통과시킨다.
    const safe = {'SafeArea', 'BottomNavigationBar', 'BottomAppBar', 'NavigationBar'};
    final offenders = <String>[];
    for (final f in Directory('lib/ui/screens')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      final rel = f.path.replaceAll(r'\', '/');
      for (final m
          in RegExp(r'bottomNavigationBar:\s*([A-Za-z_][\w.]*)').allMatches(src)) {
        final w = m.group(1)!;
        if (safe.contains(w)) continue;
        // 조건식으로 갈리는 경우(`_loaded ? ... : null`)는 뒤쪽에 SafeArea가 온다.
        final tail = src.substring(m.end, (m.end + 90).clamp(0, src.length));
        if (tail.contains('SafeArea')) continue;
        // 함수로 뺀 바는 그 함수 안을 본다.
        //
        // **Material의 BottomNavigationBar는 감싸면 오히려 틀린다.** 그쪽은
        // `viewPadding`을 보는데 SafeArea는 `padding`만 지우기 때문에, 감싸면
        // 인셋이 두 번 들어가 바가 붕 뜬다. 스스로 처리하는 위젯은 통과시킨다.
        final body = RegExp('Widget ${RegExp.escape(w)}\\(').firstMatch(src);
        if (body != null) {
          final head =
              src.substring(body.end, (body.end + 400).clamp(0, src.length));
          if (safe.any(head.contains)) continue;
        }
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        offenders.add('$rel:$line — bottomNavigationBar: $w');
      }
    }
    expect(offenders, isEmpty,
        reason: '아래 바를 SafeArea(top: false)로 감싸세요. '
            '안 그러면 시스템 내비게이션 바가 버튼을 덮습니다.\n${offenders.join('\n')}');
  });
}
