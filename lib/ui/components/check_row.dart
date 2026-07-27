import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

/// 고르면 체크가 켜지는 한 줄. 그림자 없이 테두리와 체크만으로 상태를 보인다.
///
/// "해당하면 켜세요"가 필요한 자리에 쓴다 — 켜고 끄는 것이 즉시 계산을 바꾸는
/// 조건들(예: 주택담보대출 한도를 800만→2,000만으로 가르는 고정금리·비거치식).
class CheckRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CheckRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(
              color: selected ? accent : AppTheme.line(context),
              width: selected ? 1.4 : 1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                size: 18, color: selected ? accent : AppTheme.inkTertiary(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label.keepWords,
                  style: AppTheme.sans(13, AppTheme.ink(context),
                      weight: selected ? FontWeight.w700 : FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 주택담보대출 한도를 가르는 두 조건 (소득세법 §52⑥).
/// 둘 다면 2,000만원 · 하나면 1,800만원 · 없으면 800만원.
class MortgageConditionRows extends StatelessWidget {
  final bool fixedRate;
  final bool nonDeferred;
  final ValueChanged<bool> onFixedRate;
  final ValueChanged<bool> onNonDeferred;

  /// 지금 적용되는 한도 (원). 아래에 한 줄로 보여준다.
  final double limit;

  const MortgageConditionRows({
    super.key,
    required this.fixedRate,
    required this.nonDeferred,
    required this.onFixedRate,
    required this.onNonDeferred,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('대출 조건에 따라 한도가 달라져요 — 해당하는 것을 골라주세요.'.keepWords,
            style: AppTheme.sans(12, AppTheme.inkSecondary(context), height: 1.45)),
        const SizedBox(height: 8),
        CheckRow(
          label: '금리가 고정이에요',
          selected: fixedRate,
          onTap: () => onFixedRate(!fixedRate),
        ),
        const SizedBox(height: 6),
        CheckRow(
          label: '처음부터 원금도 같이 갚아요 (비거치식)',
          selected: nonDeferred,
          onTap: () => onNonDeferred(!nonDeferred),
        ),
        const SizedBox(height: 6),
        Text('지금 한도: 연 ${(limit / 10000).round()}만원'.keepWords,
            style: AppTheme.sans(12, AppTheme.accentColor(context),
                weight: FontWeight.w700)),
      ],
    );
  }
}
