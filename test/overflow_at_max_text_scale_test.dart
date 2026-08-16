import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/screen_registry.dart';

/// **글자를 키운 사람에게도 화면이 안 넘친다.**
///
/// 앱은 시스템 글자 확대를 1.3배까지 허용한다고 스스로 정해 뒀다
/// (`main.dart`의 clamp). 그런데 넘침 검사는 1.0배에서만 돌아서, 정작
/// 그 1.3배를 아무도 안 봤다. 글자를 키워 쓰는 사람은 눈이 불편한
/// 사람이고, 그 사람 화면에서 글자가 잘리면 앱을 못 쓴다.
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  testWidgets('글자 1.3배에서 360x800이 안 넘친다', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    final problems = <String>[];
    var current = '';
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exception.toString();
      if (!s.contains('overflowed')) return;
      final where = RegExp(r'(\w+\.dart):(\d+)').firstMatch(d.toString());
      final by = RegExp(r'overflowed by ([\d.]+)').firstMatch(s)?.group(1) ?? '?';
      final line = '$current — ${by}px @ ${where?.group(0) ?? '?'}';
      if (!problems.contains(line)) problems.add(line);
    };
    addTearDown(() => FlutterError.onError = old);

    var seq = 0;
    await seedRealisticUser('직장인');
    final screens = <(String, Widget Function())>[
      ...noArgScreens,
      for (final u in ['직장인', 'N잡러', '프리랜서'])
        for (final (n, b) in byTypeScreens) ('$n($u)', () => b(u)),
    ];
    for (final (name, build) in screens) {
      current = name;
      try {
        await t.pumpWidget(MaterialApp(
          key: ValueKey('scale-${seq++}'),
          home: MediaQuery(
            // 앱이 스스로 허용한 상한 그대로.
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: build(),
          ),
        ));
        for (var i = 0; i < 3; i++) {
          await t.pump(const Duration(milliseconds: 250));
        }
      } catch (_) {
        // 못 뜨는 건 다른 테스트가 본다.
      }
      t.takeException();
    }
    FlutterError.onError = old;

    for (final p in problems) {
      // ignore: avoid_print
      print('  ✕ $p');
    }
    // ignore: avoid_print
    print('1.3배에서 넘치는 화면 ${problems.length}개');
    expect(problems, isEmpty, reason: '글자를 키우면 잘리는 화면이 있다');
  });
}
