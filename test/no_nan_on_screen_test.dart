import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/screen_registry.dart';

/// **화면에 NaN·Infinity가 찍히지 않는다.**
///
/// 세무 계산은 나눗셈이 많다 — 진행률, 경비율, 세율 구간, 월할. 분모가 0이면
/// Dart는 던지지 않고 `NaN`이나 `Infinity`를 내놓고, 그게 그대로 글자가 되어
/// 사용자에게 간다. "NaN원"은 크래시보다 나쁘다 — 앱이 멀쩡한 척하면서 틀린
/// 답을 주기 때문이다.
///
/// 아무것도 안 넣은 사람(전부 0)이 가장 잘 걸린다. 갓 설치한 사람이 그 상태다.
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  /// 화면에 그려진 글자를 전부 모은다.
  List<String> renderedText(WidgetTester t) => t
      .widgetList<Text>(find.byType(Text))
      .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
      .toList();

  testWidgets('빈 프로필에서 전 화면에 NaN이 없다', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    final old = FlutterError.onError;
    FlutterError.onError = (_) {}; // 레이아웃 잡음은 여기 관심사가 아니다
    addTearDown(() => FlutterError.onError = old);

    final bad = <String>[];
    var seq = 0;

    for (final userType in ['직장인', 'N잡러', '프리랜서']) {
      for (final (name, build) in byTypeScreens) {
        // 갓 설치 — 아무것도 안 넣은 상태.
        dbService = InMemoryDatabaseHelper();
        await dbService.initDatabase();

        try {
          await t.pumpWidget(MaterialApp(
            key: ValueKey('nan-${seq++}'),
            home: build(userType),
          ));
          for (var i = 0; i < 4; i++) {
            await t.pump(const Duration(milliseconds: 250));
          }
        } catch (_) {
          continue; // 못 뜨는 건 다른 테스트의 관심사다
        }
        t.takeException();

        for (final s in renderedText(t)) {
          if (s.contains('NaN') || s.contains('Infinity') || s.contains('∞')) {
            final line = '$name($userType) — "$s"';
            if (!bad.contains(line)) bad.add(line);
          }
        }
      }
    }
    FlutterError.onError = old;

    for (final b in bad) {
      // ignore: avoid_print
      print('  ✕ $b');
    }
    expect(bad, isEmpty, reason: '0으로 나눈 결과가 그대로 글자가 됐다');
  });
}
