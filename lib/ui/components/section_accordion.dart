import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 접혔다 펴지는 절 — 홈의 03 리마인더 · 04 세무 도구 · 05 자주 묻는 질문.
///
/// 셋이 각자 같은 머리를 들고 있었고, 그중 05만 Material `ExpansionTile`을
/// 썼다. 그 타일은 최소 높이가 48dp라 접힌 상태에서 혼자 한 뼘 더 높았다 —
/// 나란히 놓인 절 중 하나만 칸이 두꺼우면 그 줄이 문서 밖으로 보인다.
///
/// 머리는 **줄 전체가 토글**이다. 화살표만 누르게 하면 손가락으로는 못 맞힌다.
class SectionAccordion extends StatefulWidget {
  const SectionAccordion({
    super.key,
    required this.no,
    required this.title,
    required this.expanded,
    this.collapsed,
    this.semanticLabel,
  });

  /// 절 번호 — `'03'`.
  final String no;
  final String title;

  /// 펼쳤을 때의 내용. 접혀 있으면 만들지 않는다.
  final WidgetBuilder expanded;

  /// 접혔을 때 머리 밑에 남길 한 줄. 없으면 머리만 남는다.
  final Widget? collapsed;

  /// 스크린리더가 읽을 이름. 없으면 [title].
  final String? semanticLabel;

  @override
  State<SectionAccordion> createState() => _SectionAccordionState();
}

class _SectionAccordionState extends State<SectionAccordion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tert = AppTheme.inkTertiary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          label: widget.semanticLabel ?? widget.title,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Expanded(child: AppTheme.sectionHead(context, widget.no, widget.title)),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(Icons.expand_more_rounded, size: 20, color: tert),
                  ),
                ],
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: widget.expanded(context),
                  )
                // 접혀도 폭은 지켜야 한다 — 안 그러면 절 머리 폭이 글자만큼 줄어든다.
                : (widget.collapsed ?? const SizedBox(width: double.infinity)),
          ),
        ),
      ],
    );
  }
}
