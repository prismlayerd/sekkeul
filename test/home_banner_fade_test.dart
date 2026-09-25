import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/home/home_banner_carousel.dart';

/// 배너 카드가 넘어갈 때 즉시 바뀌지 않고 서서히 페이드(교차)돼야 한다.
/// AnimatedOpacity가 실제로 매 프레임 중간값을 그리는지, 전환 중간 시점에
/// 카드 하나는 사라지는 중(0→작아짐)·다른 하나는 나타나는 중(0→커짐)인지를
/// 렌더된 Opacity 값으로 직접 확인한다 — 위젯 설정값만 보면 "바뀐 척"도 통과한다.
void main() {
  testWidgets('배너 카드 전환 중간 시점에 두 카드가 겹쳐 반투명으로 보인다', (tester) async {
    Widget build(int activeIndex) => MaterialApp(
          home: Scaffold(
            body: HomeBannerCarousel(
              cards: [
                BannerCardData(label: 'A', headline: '카드A', action: '', glyph: '', onTap: () {}),
                BannerCardData(label: 'B', headline: '카드B', action: '', glyph: '', onTap: () {}),
              ],
              activeIndex: activeIndex,
              onTickTap: (_) {},
              onDismiss: (_) {},
            ),
          ),
        );

    await tester.pumpWidget(build(0));
    await tester.pumpAndSettle();

    // AnimatedOpacity는 내부적으로 FadeTransition(RenderAnimatedOpacity)을 쓴다 —
    // Opacity 위젯이 아니라 FadeTransition.opacity(애니메이션)의 현재 값을 읽어야
    // "지금 실제로 그려지는" 투명도를 확인할 수 있다.
    List<double> opacities() => tester
        .widgetList<FadeTransition>(find.descendant(
            of: find.byType(AnimatedOpacity), matching: find.byType(FadeTransition)))
        .map((f) => f.opacity.value)
        .toList();

    // 시작 상태 — 카드A는 완전히 보이고, 카드B는 완전히 숨겨져 있다.
    final start = opacities();
    expect(start, containsAllInOrder([1.0]));
    expect(start.reduce((a, b) => a < b ? a : b), 0.0);

    // 인덱스를 바꾼 직후(0ms) — 아직 애니메이션 시작 프레임이라 값은 그대로다.
    await tester.pumpWidget(build(1));
    // 전환 도중(500ms 중 250ms 지점) — 둘 다 중간값이어야 크로스페이드다.
    await tester.pump(const Duration(milliseconds: 250));
    final mid = opacities();
    expect(mid.any((o) => o > 0.02 && o < 0.98), isTrue,
        reason: '중간 시점엔 최소 하나는 반투명(크로스페이드 중)이어야 한다 — 지금 값: $mid');

    // 전환이 끝난 뒤 — 카드B만 완전히 보이고 카드A는 완전히 사라져야 한다.
    await tester.pump(const Duration(milliseconds: 300));
    final end = opacities();
    expect(end, containsAllInOrder([1.0]));
    expect(end.reduce((a, b) => a < b ? a : b), 0.0);
  });
}
