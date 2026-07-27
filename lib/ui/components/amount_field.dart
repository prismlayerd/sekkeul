import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

final NumberFormat _amountFormat = NumberFormat('#,###');

/// 금액 입력칸의 천 단위 콤마 — 타이핑하는 동안 바로 붙는다.
///
/// `onChanged`에서 컨트롤러를 덮어쓰면 커서가 맨 뒤로 튄다(중간을 고치면 커서를 잃음).
/// 포매터로 처리하면 Flutter가 커서 위치를 함께 계산해 준다.
class ThousandsFormatter extends TextInputFormatter {
  const ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue now) {
    final digits = now.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return now.copyWith(text: '');
    final text = _amountFormat.format(int.parse(digits));
    // 커서 앞의 숫자 개수를 유지한 위치로 되돌린다.
    final typedBefore =
        now.text.substring(0, now.selection.end.clamp(0, now.text.length))
            .replaceAll(RegExp(r'[^0-9]'), '')
            .length;
    int offset = 0, seen = 0;
    while (offset < text.length && seen < typedBefore) {
      if (RegExp(r'[0-9]').hasMatch(text[offset])) seen++;
      offset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// 앱 공통 액수 입력칸 — 모든 금액 기입란의 단일 디자인 소스.
///
/// 설계 원칙:
/// • 박스 안엔 숫자만 — 힌트는 항상 '0' (예시 문구 금지).
/// • 단위 '원'은 박스 밖 오른쪽에 별도 라벨로.
/// • 천 단위 콤마 자동 삽입.
/// • 폭이 상황마다 달라도(고정폭 vs 꽉 채움) 박스·텍스트·단위 스타일은 동일.
///
/// 레이아웃:
/// • [expand] = true  → 가로 공간을 꽉 채움 (라벨이 위에 오는 세로 폼).
/// • [expand] = false → [width] 고정폭 (라벨이 왼쪽에 오는 한 줄 행). 기본값.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool expand;
  final double width;
  final bool autofocus;
  final bool enabled;

  const AmountField({
    super.key,
    required this.controller,
    this.onChanged,
    this.expand = false,
    this.width = 150,
    this.autofocus = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final field = TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.right,
      inputFormatters: const [ThousandsFormatter()],
      style: AppTheme.sans(16, ink, weight: FontWeight.w700),
      decoration: InputDecoration(
        isDense: true,
        hintText: '0',
        hintStyle: AppTheme.sans(16, AppTheme.inkTertiary(context)),
        filled: true,
        fillColor: AppTheme.surface(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppTheme.line(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppTheme.line(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppTheme.accentColor(context), width: 1.5),
        ),
      ),
      onChanged: onChanged,
    );

    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        expand ? Expanded(child: field) : SizedBox(width: width, child: field),
        const SizedBox(width: 8),
        Text('원', style: AppTheme.sans(15, AppTheme.inkSecondary(context), weight: FontWeight.w600)),
      ],
    );
  }
}
