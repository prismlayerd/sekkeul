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

  /// 입력 가능한 최대 자릿수. 개인 재무 앱에서 12자리(9,999억)를 넘는 금액은
  /// 자릿수를 틀린 것이다. 상한이 없으면 계산이 폭발해 화면이 조 단위나
  /// int64 최대값을 태연히 그린다 — 실제로 여러 계산기가 그랬다.
  static const int maxDigits = 12;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue now) {
    final digits = now.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return now.copyWith(text: '');
    // 자릿수를 넘기면 입력을 받지 않는다(이전 값 유지).
    if (digits.length > maxDigits) return old;
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

/// 입력값 상한 — 자릿수를 틀린 입력이 계산을 폭발시키는 것을 막는다.
///
/// 사용자는 금리 칸에 금액을 넣고 개월 칸에 연도를 넣는다. 상한이 없으면
/// 화면이 조 단위나 int64 최대값을 태연히 그리고, 그 순간 그 계산기의
/// 신뢰가 끝난다. 각 화면이 자기 칸의 의미에 맞는 상한을 준다.
double saneInput(double v, double max) =>
    v.isFinite && v > 0 ? (v > max ? max : v) : 0.0;

/// 흔한 상한값 — 개인 재무 앱 기준.
class InputMax {
  static const double money = 1000000000000; // 1조원
  static const double unitPrice = 1000000;   // 시급·단가 100만원
  static const double percent = 100;         // 비율
  static const double years = 60;            // 근속·기간
  static const double months = 600;          // 50년
  static const double count = 10000;         // 횟수·건수
  static const double distance = 2000;       // 일일 주행거리 km
  static const double efficiency = 100;      // 연비 km/L · km/kWh
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
