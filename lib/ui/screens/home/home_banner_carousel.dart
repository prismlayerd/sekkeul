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

  /// 오른쪽에 깔 사진. 없으면 카드는 지금까지와 똑같이 글자만으로 그려진다.
  final String? imageUrl;

  /// 닫을 수 있는가. 기본은 닫힌다 — 광고·팁은 안 보고 싶을 수 있다.
  ///
  /// **닫으면 길이 사라지는 카드는 false로 둔다.** 1~지난달 채우기가 그렇다.
  /// 그걸 안 채우면 연간 계산이 통째로 안 나오는데, 실수로 ×를 누른 사람은
  /// 다시 찾을 데가 없다.
  final bool dismissible;

  const BannerCardData({
    required this.label,
    required this.headline,
    required this.action,
    required this.glyph,
    required this.onTap,
    this.sub,
    this.imageUrl,
    this.dismissible = true,
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
          child: Stack(
            children: [
              // **사진은 글자 뒤가 아니라 글자 옆이다.**
              //
              // 사진 위에 흰 글씨를 얹는 흔한 방식은 사진이 무엇이냐에 따라
              // 글자가 읽히기도 하고 안 읽히기도 한다. 우리가 고르는 사진이
              // 아니라 그때그때 올리는 사진이라 그 도박을 할 수 없다.
              // 그래서 오른쪽에 두고, 글자 쪽 가장자리를 투명하게 녹여
              // 종이 바탕에 스며들게 한다. 겹치는 구간이 아예 없다.
              if (c.imageUrl != null)
                Positioned(top: 0, bottom: 0, right: 0, child: _FadedPhoto(url: c.imageUrl!)),
              Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                // 사진이 있으면 글자는 왼쪽 절반 남짓만 쓴다 — 사진의 짙은
                // 부분까지 글자가 밀고 들어가지 않게.
                flex: c.imageUrl != null ? 58 : 100,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: AppTheme.sectionHead(context, null, c.label)),
                        if (c.dismissible)
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
              if (c.imageUrl != null) const Spacer(flex: 42),
            ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 오른쪽 사진 — 왼쪽 가장자리를 투명하게 녹인다.
///
/// 못 받아 오면 **아무것도 그리지 않는다.** 자리를 비워 두지도 않는다 —
/// 글자는 이미 왼쪽에 다 있으므로 사진이 없어도 카드가 성립한다.
/// 로딩 중에도 빈 자리다. 6초마다 도는 카드에서 회색 판이 번쩍이면
/// 그게 사진보다 더 눈에 띈다.
class _FadedPhoto extends StatelessWidget {
  final String url;
  const _FadedPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // 부모(Stack)가 준 높이만큼 채우고, 너비는 카드의 46%.
        // 글자가 쓰는 58%와 12%p 겹치는데, 그 구간은 그라데이션이
        // 거의 투명한 쪽이라 글자를 가리지 않는다.
        final w = MediaQuery.of(context).size.width * 0.46;
        return IgnorePointer(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              // 왼쪽 40%를 페이드에 쓴다. 더 짧게 하면 경계가 선처럼 보이고,
              // 더 길게 하면 사진이 뭘 찍은 건지 알아볼 수 없어진다.
              colors: [Color(0x00000000), Color(0xFF000000)],
              stops: [0.0, 0.4],
            ).createShader(r),
            child: SizedBox(
              width: w,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                loadingBuilder: (_, child, p) =>
                    p == null ? child : const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
