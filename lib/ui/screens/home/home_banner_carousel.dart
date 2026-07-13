import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 홈 상단 회전 배너의 단일 카드 모델 (광고·알림·안내).
class BannerCardData {
  final String label;
  final String headline;
  final String action;
  final String glyph;
  final VoidCallback onTap;

  /// 보조 문구 — 헤드라인 아래 한 줄(팁=본문, 그 외=액션 안내). 없으면 action 사용.
  final String? sub;

  const BannerCardData({
    required this.label,
    required this.headline,
    required this.action,
    required this.glyph,
    required this.onTap,
    this.sub,
  });

  /// 닫기 영구 저장용 안정 키 — 라벨+헤드라인 기반.
  String get id => '$label::$headline';
}

/// 홈 상단 회전 배너 — 6초마다 페이드 전환, 하단에 위치 틱.
/// 카드 목록·현재 인덱스·회전 타이머는 홈 화면(부모)이 소유하고 관리한다 —
/// 유형 전환·온보딩 복귀 등에서 인덱스를 0으로 리셋해야 하는 시점들이
/// 이미 부모의 여러 상태 변경 지점에 흩어져 있어(그 시점들과 결합), 그대로 두고
/// 이 위젯은 순수하게 "주어진 카드/인덱스를 어떻게 그리는지"만 담당한다.
class HomeBannerCarousel extends StatelessWidget {
  final List<BannerCardData> cards;
  final int activeIndex;
  final void Function(int index) onTickTap;
  final void Function(BannerCardData card) onDismiss;

  const HomeBannerCarousel({
    super.key,
    required this.cards,
    required this.activeIndex,
    required this.onTickTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final idx = activeIndex % cards.length;
    final reduce = MediaQuery.of(context).disableAnimations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 104,
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: reduce ? 0 : 500),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(
              key: ValueKey(idx),
              child: _bannerCardView(context, cards[idx]),
            ),
          ),
        ),
        if (cards.length > 1) ...[
          const SizedBox(height: 12),
          _bannerTicks(cards.length, idx),
        ],
      ],
    );
  }

  /// 단일 배너 카드 — 라벨 + 세리프 헤드라인 + 보조 문구 + 우측 글리프 박스.
  /// 카드 전체가 탭 영역. 색상은 유형 무관 기본 ink/sub.
  Widget _bannerCardView(BuildContext context, BannerCardData c) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    // 보조 문구: 명시 sub(팁 본문) 우선, 없으면 액션 안내.
    final subText = (c.sub != null && c.sub!.trim().isNotEmpty)
        ? c.sub!
        : (c.action.isNotEmpty ? c.action : null);
    return Semantics(
      button: true,
      label: '${c.label} ${c.headline}',
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: c.onTap,
      child: SizedBox(
        width: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(c.label.toUpperCase(), style: AppTheme.label(context))),
                      Semantics(
                        button: true,
                        label: '이 카드 닫기',
                        child: GestureDetector(
                          onTap: () => onDismiss(c),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(Icons.close_rounded, size: 16, color: sub),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  // 헤드라인이 1줄이든 2줄이든 카드 높이를 동일하게 유지 — 아래 보조 문구 위치 고정.
                  // 높이는 시스템 글자 확대(U-3, 최대 1.3배)에 맞춰 함께 커지도록 textScaler 반영.
                  SizedBox(
                    height: MediaQuery.textScalerOf(context).scale(22) * 1.2 * 2,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(c.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.serif(22, ink, spacing: -0.5, height: 1.2)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (subText != null)
                    Row(children: [
                      Flexible(
                        child: Text(subText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(12, sub, height: 1.4)),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.arrow_forward, size: 13, color: sub),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// 배너 위치 틱 — 현재 카드는 ink 긴 막대, 나머지는 헤어라인. 탭하면 이동.
  Widget _bannerTicks(int count, int active) {
    return Builder(builder: (context) {
      final ink = AppTheme.ink(context);
      return Row(
        children: List.generate(count, (i) {
          final on = i == active;
          return GestureDetector(
            onTap: () => onTickTap(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: on ? 18 : 10,
                height: 2,
                color: on ? ink : AppTheme.line(context),
              ),
            ),
          );
        }),
      );
    });
  }
}
