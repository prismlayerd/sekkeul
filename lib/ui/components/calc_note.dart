import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'calc_disclaimer.dart';

/// 계산기 하단 「알아두기」 — 이 계산이 무엇을 빼고 셈했는지 미리 말하는 자리.
///
/// 화면 19개가 같은 모양을 각자 손으로 그리고 있었다(전구 아이콘 + 옅은 회색
/// 채움 + 굵은 제목). 채움은 종이 사진 위에 판때기를 덮었고, 제목은 앱의 다른
/// 절 머리와 모양이 달랐다.
///
/// 여기서는 [CalcDisclaimer]와 같은 문법을 쓴다 — 실선 하나 긋고 그 아래에
/// 적는다. 상자도 아이콘도 없다. 결과 아래에 붙는 주석이라는 건 **자리**가
/// 말하지 전구가 말하는 게 아니다.
class CalcNote extends StatelessWidget {
  const CalcNote(this.body, {super.key, this.title = '알아두기'});

  /// 줄머리 `•`가 붙은 여러 줄.
  final String body;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTheme.hairline(context),
          const SizedBox(height: 12),
          AppTheme.sectionHead(context, null, title),
          const SizedBox(height: 8),
          Text(body,
              style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkSecondary(context),
                  height: 1.6)),
        ],
      ),
    );
  }
}
