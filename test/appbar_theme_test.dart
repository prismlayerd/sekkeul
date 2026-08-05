import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/screen_registry.dart';

/// **앱바가 테마 값 그대로 그려지는지 본다.**
///
/// 화면 88개가 backgroundColor·elevation·scrolledUnderElevation·iconTheme을
/// AppBar에 직접 적고 있었고 그게 전부 appBarTheme과 같은 값이라 지웠다.
/// "값이 같으니 화면이 안 바뀐다"는 건 코드를 읽어 확인했지 그려진 결과로
/// 확인한 게 아니었다 — 이 파일이 그 구멍을 닫는다.
///
/// 스크린샷 한 장은 화면 하나만 말한다. 여기서는 등록된 화면을 전부 세워
/// 앱바가 실제로 칠한 색을 읽는다. 앱 테마를 걸고 띄우는 게 핵심이다
/// (다른 테스트들은 맨 MaterialApp으로 띄워서 이걸 못 본다).
void main() {
  /// 앱바가 실제로 칠한 배경색 — AppBar가 안쪽에 세우는 Material이 들고 있다.
  Color paintedBarColor(WidgetTester t) {
    final m = t.widget<Material>(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Material)).first,
    );
    return m.color!;
  }

  for (final (modeName, isDark) in [('라이트', false), ('다크', true)]) {
    testWidgets('$modeName — 앱바가 테마의 배경색으로 그려진다', (t) async {
      t.view.physicalSize = const Size(390, 1600);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);

      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();

      final expectedBg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
      final expectedInk = isDark ? AppTheme.darkInk : AppTheme.lightInk;

      final screens = <(String, Widget Function())>[
        ...noArgScreens,
        for (final (n, b) in byTypeScreens) (n, () => b('직장인')),
      ];

      final offenders = <String>[];
      var checked = 0;
      for (final (label, build) in screens) {
        await t.pumpWidget(MaterialApp(
          key: ValueKey('bar-$label-$isDark'),
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: build(),
        ));
        await t.pump(const Duration(milliseconds: 200));
        t.takeException();

        final bar = find.byType(AppBar);
        if (bar.evaluate().isEmpty) continue;

        final painted = paintedBarColor(t);
        if (painted != expectedBg) offenders.add('$label 배경 $painted');

        final ctx = t.element(bar.first);
        final iconColor = Theme.of(ctx).appBarTheme.iconTheme?.color;
        if (iconColor != expectedInk) offenders.add('$label 아이콘 $iconColor');

        checked++;
      }

      // ignore: avoid_print
      print('$modeName 모드 — 앱바 있는 화면 $checked개 검사, 어긋남 ${offenders.length}건');
      expect(offenders, isEmpty, reason: '앱바가 테마와 다른 값으로 그려진다');
      expect(checked, greaterThan(30), reason: '검사한 화면이 너무 적다 — 레지스트리를 보라');
    });
  }
}
