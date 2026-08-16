import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 지금 몇 번째 장을 보고 있는지 — 잉크 막대와 헤어라인.
///
/// 점(dot)을 쓰지 않는다. 이 앱에 둥근 것이 없고, 인쇄된 짧은 막대가 전표의
/// 문법에 맞는다. 고른 것만 길고 진하다.
///
/// 배너 회전과 홈의 두 페이지가 **같은 표시**를 쓴다 — 같은 뜻(여러 장 중
/// 지금 이것)이면 같은 모양이어야 사용자가 두 번 배우지 않는다.
class SlipTicks extends StatelessWidget {
  const SlipTicks({
    super.key,
    required this.count,
    required this.active,
    required this.onTap,
    required this.labelFor,
  });

  final int count;
  final int active;
  final ValueChanged<int> onTap;

  /// 스크린리더가 읽을 이름 — 막대만 보고는 무엇인지 알 수 없다.
  final String Function(int index) labelFor;

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    return Row(
      // 감싸는 쪽이 Center로 가운데에 둘 수 있어야 한다.
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final on = i == active;
        return Semantics(
          button: true,
          selected: on,
          label: labelFor(i),
          child: GestureDetector(
            onTap: () => onTap(i),
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
          ),
        );
      }),
    );
  }
}
