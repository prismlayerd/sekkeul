import 'package:flutter/material.dart';

import '../../components/section_accordion.dart';
import '../tax_tools_screen.dart';

/// 홈 세무 도구 아코디언 — 탭하면 세무 탭과 같은 `TaxToolsMenu`를 펼친다.
///
/// 머리와 여닫는 몸은 [SectionAccordion]에 있다. 03·05와 같은 몸을 쓴다.
class TaxToolsAccordion extends StatelessWidget {
  final String userType;
  const TaxToolsAccordion({super.key, required this.userType});

  @override
  Widget build(BuildContext context) {
    return SectionAccordion(
      no: '04',
      title: '세무 도구',
      semanticLabel: '세무 도구 — 기록·신고 준비·경정청구·양식',
      // 절 머리 하나로 충분하다. 오른쪽에 붙어 있던 '기록 · 신고 준비 · 경정청구 ·
      // 양식' 요약은 펼치면 바로 보이는 것을 접힌 상태에서 한 번 더 말하는 줄이라 뺐다.
      expanded: (_) => TaxToolsMenu(userType: userType),
    );
  }
}
