import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 계산기 화면 공통 위젯 — 값 한 줄, 안내 박스, 세그먼트 버튼.
/// 여러 계산기 화면이 각자 private로 복제해 두던 동일 구현을 하나로 모았다.

Widget calcRow(String label, String value, Color ink, Color sub) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(child: Text(label, style: AppTheme.sans(AppTheme.tsSM, sub))),
      Text(value, style: AppTheme.sans(AppTheme.tsSM, ink, weight: FontWeight.w600)),
    ],
  );
}

Widget calcInfoBox(String title, List<String> items, Color line, Color sub, Color ink) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(4)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('· ', style: AppTheme.sans(AppTheme.tsSM, sub)),
              Expanded(child: Text(item, style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5))),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ],
    ),
  );
}

Widget calcSegButton(String label, int value, int groupValue,
    ValueChanged<int> onChanged, Color ink, Color line, Color accent) {
  final selected = value == groupValue;
  return GestureDetector(
    onTap: () => onChanged(value),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          border: Border.all(color: selected ? accent : line),
          borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: AppTheme.sans(AppTheme.tsXS, selected ? accent : ink, weight: FontWeight.w600)),
    ),
  );
}
