import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 계산 결과 화면 하단 면책 문구 — 세액·환급·수급액 추정치가 있는 화면에서 공통 사용.
class CalcDisclaimer extends StatelessWidget {
  const CalcDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTheme.hairline(context),
          const SizedBox(height: 12),
          Text(
            '이 결과는 참고용 추정치예요. 실제 세액·환급액·수급액은 개인 상황에 따라 달라질 수 있으니, '
            '정확한 금액은 홈택스나 관할 기관, 세무사를 통해 확인하세요.',
            style: AppTheme.sans(11, AppTheme.inkTertiary(context), height: 1.5),
          ),
        ],
      ),
    );
  }
}
