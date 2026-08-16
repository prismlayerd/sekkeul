import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/components/splash_tear.dart';
import 'package:secul/ui/theme/app_theme.dart';

/// **종이는 뜯기 전에 한 장으로 있어야 한다.**
///
/// 처음부터 벌어지기 시작하면 뜯는 게 아니라 그냥 갈라지는 것으로 보인다.
/// 앞머리에 다무는 구간이 있어야 "뜯는다"가 읽힌다 — 눈으로는 100ms 차이를
/// 못 세니 여기서 붙잡는다.
void main() {
  /// 애니메이션 진행도(0~1000). 페인터가 들고 있는 값을 그대로 읽는다 —
  /// 픽셀을 세는 것보다 흔들림이 없다.
  int progress(WidgetTester t) {
    final painter = t.widget<CustomPaint>(find.descendant(
      of: find.byType(SplashTear),
      matching: find.byType(CustomPaint),
    ));
    return (((painter.painter! as dynamic).t as double) * 1000).round();
  }

  testWidgets('앞머리에 다무는 구간이 있다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: SplashTear()),
    ));
    await t.pump(); // postFrame에서 forward()

    // 전체 길이의 20% 지점 — 아직 다물고 있어야 한다.
    await t.pump(const Duration(milliseconds: 230));
    expect(progress(t), lessThan(260),
        reason: '20% 지점에서 이미 벌어지고 있다 — 다무는 구간이 없다');

    // 다 벌어진 뒤.
    await t.pump(const Duration(milliseconds: 700));
    expect(progress(t), greaterThan(760),
        reason: '벌어지기가 안 끝났다');

    await t.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('「동작 줄이기」를 켜면 재생하지 않는다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: SplashTear()),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));

    expect(
        find.descendant(
            of: find.byType(SplashTear), matching: find.byType(CustomPaint)),
        findsNothing,
        reason: '동작을 줄이라고 했는데 애니메이션이 돈다');
  });
}
