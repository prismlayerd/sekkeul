import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 세무 신고 파이프라인 스텝 레일.
///
/// 단계 수·라벨은 유형마다 달라(직장인·프리랜서 3단계, N잡러 4단계) 고정하지 않고
/// 메뉴와 같은 단일 출처(`taxRailLabels`)에서 받아 그린다. 각 화면 상단에 "지금 몇
/// 단계인지"를 도면 눈금처럼 상시 표시하고, 현재 단계는 도면 블루 + 헤어라인 위
/// 눈금(밑줄)으로 위치를 표시(you-are-here).
class TaxPipelineRail extends StatelessWidget {
  /// 유형별 단계 라벨(순서대로). `taxRailLabels(userType)`로 얻는다.
  final List<String> labels;

  /// 현재 단계 (1-based). `taxRailIndex(userType, railKey)`로 얻는다.
  final int current;

  const TaxPipelineRail({super.key, required this.labels, required this.current});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 들어가면 지금처럼 양끝에 붙여 고르게 벌리고, 안 들어가면 옆으로 민다.
        //
        // N잡러는 단계가 넷이라 글자를 1.3배로 키우면 한 줄에 안 들어간다.
        // 예전에는 그냥 잘렸다 — 마지막 단계가 화면 밖으로 나가서, 정작
        // "지금 몇 단계인지"를 못 보게 됐다.
        LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: c.maxWidth - 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int i = 0; i < labels.length; i++)
                    Padding(
                      padding: EdgeInsets.only(right: i < labels.length - 1 ? 14 : 0),
                      child: _tick(context, i + 1, labels[i]),
                    ),
                ],
              ),
            ),
          ),
        ),
        AppTheme.hairline(context),
      ],
    );
  }

  Widget _tick(BuildContext context, int n, String label) {
    final active = n == current;
    final done = n < current;
    final accent = AppTheme.accentColor(context);
    final color = active
        ? accent
        : (done ? AppTheme.inkSecondary(context) : AppTheme.inkTertiary(context));

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('0$n', style: AppTheme.serif(AppTheme.tsMD, color, weight: FontWeight.w400, spacing: 0)),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTheme.sans(AppTheme.tsXS, color,
              weight: active ? FontWeight.w700 : FontWeight.w500, spacing: -0.2),
        ),
      ],
    );

    // 현재 단계만 헤어라인 위에 도면 블루 눈금(1.5px 밑줄)으로 위치 표시.
    return Container(
      padding: const EdgeInsets.only(bottom: 7),
      decoration: active
          ? BoxDecoration(border: Border(bottom: BorderSide(color: accent, width: 1.5)))
          : null,
      child: content,
    );
  }
}
