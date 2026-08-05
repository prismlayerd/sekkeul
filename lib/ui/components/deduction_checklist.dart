import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../core/data/deduction_catalog.dart';
import 'amount_field.dart';

/// 놓친 공제 다중선택 체크리스트 — 항목 카드를 탭해 고르고, 고른 항목만
/// 금액을 입력한다. 선택/금액이 바뀔 때마다 id→금액 맵을 콜백으로 올린다.
/// [initialAmounts] 가 있으면(PDF 간소화 파싱 등) 자동 선택+프리필한다.
class DeductionChecklist extends StatefulWidget {
  final Map<String, int> initialAmounts;
  final ValueChanged<Map<String, int>> onChanged;

  const DeductionChecklist({
    super.key,
    this.initialAmounts = const {},
    required this.onChanged,
  });

  @override
  State<DeductionChecklist> createState() => _DeductionChecklistState();
}

class _DeductionChecklistState extends State<DeductionChecklist> {
  final Set<String> _selected = {};
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();
    for (final c in kDeductionCatalog) {
      _ctrls[c.id] = TextEditingController();
    }
    widget.initialAmounts.forEach((id, amt) {
      if (_ctrls.containsKey(id) && amt > 0) {
        _selected.add(id);
        _ctrls[id]!.text = comma(amt);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _amount(String id) =>
      int.tryParse((_ctrls[id]?.text ?? '').replaceAll(',', '')) ?? 0;

  void _emit() {
    final out = <String, int>{};
    for (final id in _selected) {
      out[id] = _amount(id);
    }
    widget.onChanged(out);
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final c in kDeductionCatalog) ...[
          _categoryCard(c),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _categoryCard(DeductionCategory c) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final selected = _selected.contains(c.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.06) : Colors.transparent,
        border: Border.all(
          color: selected ? accent : AppTheme.line(context),
          width: selected ? 1.4 : 1.0,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 — 탭하면 선택 토글.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggle(c.id),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 22,
                  color: selected ? accent : tert,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: AppTheme.sans(15, ink, weight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(c.summary, style: AppTheme.sans(12.5, sub, height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 선택 시 — 금액 입력 + 어디서 찾나 힌트.
          if (selected) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Text('지출액', style: AppTheme.sans(13, sub, weight: FontWeight.w600)),
                ),
                Expanded(
                  child: AmountField(
                    controller: _ctrls[c.id]!,
                    expand: true,
                    onChanged: (_) => _emit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.search_rounded, size: 13, color: tert),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(c.findHint, style: AppTheme.sans(11.5, tert, height: 1.45)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
