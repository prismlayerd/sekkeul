import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 세무 신고 파이프라인 스텝 레일 — ①진단 · ②가상신고서 · ③홈택스.
///
/// 세 단계는 실제 순서가 있는 시퀀스(진단 → 신고서 미리보기 → 홈택스 제출)라
/// 각 화면 상단에 "지금 몇 단계인지"를 도면 눈금처럼 상시 표시한다. 현재 단계는
/// 도면 블루 + 헤어라인 위 눈금(밑줄)으로 위치를 표시(you-are-here).
class TaxPipelineRail extends StatelessWidget {
  /// 1 = 진단, 2 = 가상신고서, 3 = 홈택스
  final int current;

  const TaxPipelineRail({super.key, required this.current});

  static const List<String> _labels = ['진단', '가상신고서', '홈택스'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < _labels.length; i++) _tick(context, i + 1, _labels[i]),
            ],
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
        Text('0$n', style: AppTheme.serif(14, color, weight: FontWeight.w400, spacing: 0)),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTheme.sans(12, color,
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
