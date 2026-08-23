import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../tax_tools_screen.dart';

/// 홈 2장의 `05 · 세무 도구` — **늘 펼쳐져 있다.**
///
/// 예전에는 접히는 절이었다. 홈이 한 장이던 시절, 다섯 절이 다 펼쳐져 있으면
/// 손댈 수 없이 길어져서였다.
///
/// 장을 둘로 가르면서 이유가 사라졌다. 2장은 **도구를 찾으러 오는 장**이다.
/// 도착해서 한 번 더 눌러야 목록이 나오는 건 문을 두 번 여는 일이다.
class TaxToolsAccordion extends StatelessWidget {
  final String userType;
  const TaxToolsAccordion({super.key, required this.userType});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 절 머리 하나로 충분하다. 오른쪽에 붙어 있던 '기록 · 신고 준비 ·
        // 경정청구 · 양식' 요약은 바로 아래 보이는 것을 한 번 더 말하는 줄이라 뺐다.
        AppTheme.sectionHead(context, '05', '세무 도구'),
        const SizedBox(height: 14),
        TaxToolsMenu(userType: userType),
      ],
    );
  }
}
