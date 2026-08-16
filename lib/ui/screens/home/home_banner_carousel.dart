import 'package:flutter/material.dart';

import '../../components/slip_ticks.dart';
import '../../theme/app_theme.dart';
import '../../theme/text_wrap.dart';

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

    // 카드 높이는 **재지 않되, 카드끼리는 같다.**
    //
    // 예전에는 글자 크기와 행간을 손으로 더해 높이를 냈다. 그 손셈이 타입
    // 스케일을 옮길 때마다 뒤처져 두 번 넘쳤다(9.2px → 3.9px). 셈을 없앤 뒤엔
    // 카드마다 높이가 달라져서, 6초마다 돌 때 아래 절취선부터 화면이 들썩였다.
    //
    // 지금은 셈도 안 하고 들썩이지도 않는다 — 모든 줄이 한 줄로 고정이고
    // 보조 문구가 없는 카드도 그 자리를 비워 두기 때문이다(아래 참조).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: Duration(milliseconds: reduce ? 0 : 500),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, if (current != null) current],
          ),
          child: KeyedSubtree(
            key: ValueKey(idx),
            child: _bannerCardView(context, cards[idx]),
          ),
        ),
        if (cards.length > 1) ...[
          const SizedBox(height: 12),
          SlipTicks(
            count: cards.length,
            active: idx,
            onTap: onTickTap,
            labelFor: (i) => '${i + 1}번째 소식',
          ),
        ],
      ],
    );
  }

  /// 헤드라인을 **정확히 두 줄**로 만든다 — 짧으면 빈 줄을 붙인다.
  static String _twoLines(String s) => s.contains('\n') ? s : '$s\n';

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
                        Expanded(child: AppTheme.sectionHead(context, null, c.label)),
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
                    // **늘 두 줄이다.** 한 줄도, 세 줄도 아니다.
                    //
                    // 빽빽하다는 의견에 한 줄로 조였더니 "공제 문턱까지 /
                    // 912만원 남았어요"처럼 원래 두 줄로 쓴 문장이 앞줄만 남고
                    // **금액이 통째로 사라졌다**. 줄임표도 안 붙어서 잘린 줄도
                    // 몰랐다. 짧아진 화면보다 사라진 숫자가 훨씬 비싸다.
                    //
                    // 한 줄짜리 문장에는 빈 줄을 붙여 자리를 채운다 — 카드마다
                    // 줄 수가 갈리면 6초마다 아래가 들썩인다.
                    Text(_twoLines(c.headline).keepWords,
                        maxLines: 2,
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        // 홈의 표제는 절 머리(01 INCOME…)다. 배너가 그보다 크면
                        // 광고가 문서를 이긴다 — 한 급 낮춰 본문 위계에 넣는다.
                        style: AppTheme.display(AppTheme.serifSM, ink, height: 1.3)),
                    const SizedBox(height: 6),
                    // **보조 문구가 없어도 자리는 비운다.**
                    //
                    // 카드마다 이 줄이 있고 없고가 갈리면 카드 높이가 달라지고,
                    // 6초마다 돌 때마다 아래 절취선부터 화면 전체가 들썩인다.
                    // 빈 줄 하나를 두는 편이 낫다 — 흔들리는 화면은 읽히지 않는다.
                    Row(children: [
                      Flexible(
                        // 한 줄로 줄였으니 문장 경계 줄바꿈도 뺀다 —
                        // 어차피 첫 줄만 보인다.
                        child: Text(subText ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.45)),
                      ),
                      if (subText != null) ...[
                        const SizedBox(width: 5),
                        Icon(Icons.arrow_forward, size: 13, color: sub),
                      ],
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

}
