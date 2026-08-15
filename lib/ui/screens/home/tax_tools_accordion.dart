import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../tax_tools_screen.dart';

/// 홈 세무 도구 아코디언 — 리마인더 카드와 동일한 헤더(라벨 + 요약 + 회전 화살표).
/// 접힘 기본, 탭하면 세무 탭과 동일한 `TaxToolsMenu`를 펼친다.
/// 펼침 상태는 홈 화면 다른 상태와 무관해 이 위젯 안에서만 관리한다.
class TaxToolsAccordion extends StatefulWidget {
  final String userType;
  const TaxToolsAccordion({super.key, required this.userType});

  @override
  State<TaxToolsAccordion> createState() => _TaxToolsAccordionState();
}

class _TaxToolsAccordionState extends State<TaxToolsAccordion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tert = AppTheme.inkTertiary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: '세무 도구 — 기록·신고 준비·경정청구·양식',
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              // 절 머리 하나로 충분하다. 오른쪽에 붙어 있던 '기록 · 신고 준비 · 경정청구 · 양식'
              // 요약은 펼치면 바로 보이는 것을 접힌 상태에서 한 번 더 말하는 줄이라 뺐다.
              Expanded(child: AppTheme.sectionHead(context, '04', '세무 도구')),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(Icons.expand_more_rounded, size: 20, color: tert),
              ),
            ],
          ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: TaxToolsMenu(userType: widget.userType),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }
}
