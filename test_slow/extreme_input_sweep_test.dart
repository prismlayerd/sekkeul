import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../test/support/screen_registry.dart';

/// **극단 입력 스윕 — 모든 계산기 화면에 큰 수를 넣어 본다.**
///
/// 사용자는 자릿수를 틀린다. 금리 칸에 금액을 넣고, 개월 칸에 연도를 넣는다.
/// 그때 화면이 조 단위 숫자를 태연히 그리면 그 화면의 신뢰가 끝난다.
///
/// 실제로 두 건이 그랬다:
/// - ISA 계산기가 `.round()`로 int64 최대값(9,223,372,036,854,775,807)을 뱉고
///   그걸 "절세 효과"라고 보여줬다
/// - 버팀목 대출이 월 이자 6,666,666,666,667원을 보여줬다
///
/// 화면마다 가드를 넣는 대신 **여기서 전수로 막는다.** 새 계산기를 추가해도
/// 자동으로 포함된다.
///
/// ⚠ 64개 화면을 열고 칸마다 입력하므로 **20분 이상 걸린다.** 그래서 `test/`가
/// 아니라 `test_slow/`에 둔다 — `flutter test`는 `test/`만 훑으므로 평소 실행에서
/// 자동으로 빠진다. 계산기 화면을 건드렸으면 직접 돌린다:
///
///     flutter test test_slow/
void main() {
  // 사람이 실제로 다룰 수 있는 금액의 상한. 개인 재무 계산기에서 이걸 넘는
  // 숫자가 나오면 계산이 폭발했다는 뜻이다. (1조원)
  const insaneAmount = 1000000000000.0;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  /// 화면에 그려진 금액 중 가장 큰 값.
  double biggestAmount(WidgetTester t) {
    double max = 0;
    for (final w in t.allWidgets) {
      if (w is! Text) continue;
      final s = w.data ?? w.textSpan?.toPlainText();
      if (s == null) continue;
      for (final m in RegExp(r'(\d{1,3}(?:,\d{3}){2,})\s*원').allMatches(s)) {
        final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (v != null && v > max) max = v;
      }
      // '1,234만원' · '5.6억원' 표기도 원 단위로 환산해 본다.
      for (final m in RegExp(r'([\d,]+(?:\.\d+)?)\s*만원').allMatches(s)) {
        final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (v != null && v * 10000 > max) max = v * 10000;
      }
      for (final m in RegExp(r'([\d,]+(?:\.\d+)?)\s*억원').allMatches(s)) {
        final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (v != null && v * 100000000 > max) max = v * 100000000;
      }
    }
    return max;
  }

  testWidgets('모든 계산기 화면 — 큰 수를 넣어도 1조원 넘는 금액을 그리지 않는다',
      (t) async {
    t.view.physicalSize = const Size(390, 4000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final old = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = old);

    final problems = <String>[];
    var checked = 0, withFields = 0;

    for (var i = 0; i < noArgScreens.length; i++) {
      final (name, build) = noArgScreens[i];
      await seedRealisticUser('직장인');
      try {
        await t.pumpWidget(
            MaterialApp(key: ValueKey('x-$i'), home: build()));
        await t.pump(const Duration(milliseconds: 60));
        final n = find.byType(TextField).evaluate().length;
        checked++;
        if (n == 0) continue;
        withFields++;

        // 모든 칸에 같은 큰 수를 넣는다 — 자릿수를 틀린 사용자를 흉내낸다.
        // 앞 4칸이면 폭발을 드러내기에 충분하다 — 전 칸을 채우면 스윕이 몇 배 느려진다.
        for (var f = 0; f < n && f < 4; f++) {
          await t.enterText(find.byType(TextField).at(f), '99999999');
          await t.pump(const Duration(milliseconds: 40));
        }
        await t.pump(const Duration(milliseconds: 80));
        t.takeException();

        final biggest = biggestAmount(t);
        if (biggest > insaneAmount) {
          problems.add('$name — 화면 최대 금액 ${biggest.toStringAsExponential(2)}원');
        }
      } catch (_) {
        // 화면이 못 뜨는 건 screen_smoke_filled_profile_test의 몫이다.
      }
      t.takeException();
    }
    FlutterError.onError = old;

    for (final p in problems) {
      // ignore: avoid_print
      print('  ✕ $p');
    }
    // ignore: avoid_print
    print('훑은 화면 $checked개 · 입력칸 있는 화면 $withFields개 · 폭발 ${problems.length}건');
    expect(problems, isEmpty,
        reason: '자릿수를 틀린 입력에 화면이 조 단위 숫자로 답한다');
  });
}
