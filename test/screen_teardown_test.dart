import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/screen_registry.dart';

/// **화면을 닫을 때 죽지 않는다.**
///
/// 지금까지의 전수 검사는 화면을 *열기만* 했다. 그런데 실기기에서 나온 빨간
/// 화면은 **닫는 순간**이었다 — 글자칸이 포커스를 쥔 채 트리가 해체되면서
/// `_dependents.isEmpty` 단언에 걸렸다. 여는 검사만으로는 영영 못 잡는다.
///
/// 여기서는 화면마다 밀어 넣었다가 **도로 빼면서** 예외를 본다.
bool _layoutOnly(Object e) {
  final s = e.toString();
  return s.contains('overflowed') ||
      s.contains('RenderFlex') ||
      s.contains('ink splashes may be invisible');
}

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  testWidgets('전 화면이 닫힐 때 예외가 없다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    final problems = <String>[];
    var current = '';
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      if (_layoutOnly(d.exception)) return;
      final line = '$current — ${d.exception.toString().split('\n').first}';
      if (!problems.contains(line)) problems.add(line);
    };
    addTearDown(() => FlutterError.onError = old);

    for (final userType in ['직장인', '프리랜서']) {
      await seedRealisticUser(userType);

      final screens = <(String, Widget Function())>[
        ...noArgScreens,
        for (final (n, b) in byTypeScreens) (n, () => b(userType)),
      ];
      for (final (name, build) in screens) {
        current = '$name($userType)';
        final navKey = GlobalKey<NavigatorState>();
        await t.pumpWidget(MaterialApp(
          key: ValueKey('host-$current'),
          navigatorKey: navKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ));
        await t.pump();

        try {
          navKey.currentState!
              .push(MaterialPageRoute<void>(builder: (_) => build()));
          for (var i = 0; i < 4; i++) {
            await t.pump(const Duration(milliseconds: 200));
          }
          // 글자칸이 있으면 **포커스를 준 채로** 닫는다. 실기기에서 죽은
          // 조건이 그것이었다 — 포커스를 쥔 칸이 트리 해체에 딸려 간다.
          final field = find.byType(TextField);
          if (field.evaluate().isNotEmpty) {
            await t.tap(field.first, warnIfMissed: false);
            for (var i = 0; i < 2; i++) {
              await t.pump(const Duration(milliseconds: 200));
            }
          }
          navKey.currentState!.pop();
          for (var i = 0; i < 4; i++) {
            await t.pump(const Duration(milliseconds: 200));
          }
        } catch (e) {
          if (!_layoutOnly(e)) problems.add('$current — $e');
        }
        final taken = t.takeException();
        if (taken != null && !_layoutOnly(taken)) {
          problems.add('$current — $taken');
        }
      }
    }
    FlutterError.onError = old;

    for (final p in problems) {
      // ignore: avoid_print
      print('  ✕ $p');
    }
    expect(problems, isEmpty, reason: '닫는 순간에 죽는 화면이 있다');
  });
}
