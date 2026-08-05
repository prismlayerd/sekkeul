import 'package:flutter/material.dart';
import '../components/amount_field.dart';

import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../../core/tax_engine/employee_tax.dart';
import '../theme/text_wrap.dart';

/// 보험료 세액공제 계산기
/// 엔진: EmployeeTaxCalculator.calculateInsurancePremiumTaxCredit (소법 §59의4)
/// - 보장성보험: 연 100만원 한도 × 12% = 최대 12만원
/// - 장애인전용보장성보험: 연 100만원 한도 × 15% = 최대 15만원
/// 합산 최대 절세액: 27만원
class InsurancePremiumScreen extends StatefulWidget {
  const InsurancePremiumScreen({super.key});

  @override
  State<InsurancePremiumScreen> createState() => _InsurancePremiumScreenState();
}

class _InsurancePremiumScreenState extends State<InsurancePremiumScreen> {
  final TextEditingController _generalController = TextEditingController();
  final TextEditingController _disabledController = TextEditingController();

  void _reset() {
    setState(() {
      _generalController.clear();
      _disabledController.clear();
    });
  }

  @override
  void dispose() {
    _generalController.dispose();
    _disabledController.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

  String _toManwon(double won) {
    if (won <= 0) return '0원';
    final man = (won / 10000).round();
    return '${comma(man)}만원';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;

    final general = _parse(_generalController);
    final disabled = _parse(_disabledController);

    final credit = EmployeeTaxCalculator.calculateInsurancePremiumTaxCredit(
      generalInsurancePremium: general,
      disabledInsurancePremium: disabled,
    );

    final generalCredit = (general > 1000000.0 ? 1000000.0 : general) * 0.12;
    final disabledCredit = (disabled > 1000000.0 ? 1000000.0 : disabled) * 0.15;
    final hasInput = general > 0 || disabled > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('보험료 세액공제 계산기',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 20, color: subColor),
            tooltip: '초기화',
            onPressed: _reset,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('낸 보험료만큼\n세금을 돌려받아요'.keepWords,
                style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold, height: 1.4)),
            const SizedBox(height: 8),
            Text('실손·암·종신보험 등 보장성보험 납입액으로 받을 수 있는 세액공제를 계산합니다.'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            // 입력 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                children: [
                  _buildInputField('보장성보험 연간 납입액', _generalController,
                      hint: '실손·암·종신보험 등, 연 100만원까지 공제'),
                  const SizedBox(height: 20),
                  _buildInputField('장애인전용보장성보험 연간 납입액', _disabledController,
                      hint: '장애인 전용 상품, 연 100만원까지 공제'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 결과 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getAccentCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.health_and_safety_rounded, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text('예상 절세액 (세액공제)',
                        style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(hasInput ? _toManwon(credit) : '0원',
                      style: TextStyle(color: primary, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (hasInput) ...[
                    if (general > 0)
                      _resultRow(
                        '보장성보험 (12%) ${general > 1000000 ? "— 한도 100만 초과" : ""}',
                        _toManwon(generalCredit),
                        subColor,
                        general > 1000000 ? Colors.orange : textColor,
                      ),
                    if (disabled > 0) ...[
                      const SizedBox(height: 8),
                      _resultRow(
                        '장애인전용보험 (15%) ${disabled > 1000000 ? "— 한도 100만 초과" : ""}',
                        _toManwon(disabledCredit),
                        subColor,
                        disabled > 1000000 ? Colors.orange : textColor,
                      ),
                    ],
                    if (credit >= 270000) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.colorSuccess.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle_rounded, color: AppTheme.colorSuccess, size: 14),
                          const SizedBox(width: 6),
                          Text('최대 공제 달성 (27만원)', style: TextStyle(color: AppTheme.colorSuccess, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ] else
                    Text('보험 납입액을 입력해보세요.',
                        style: TextStyle(color: subColor, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 안내 박스
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: subColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.lightbulb_outline_rounded, color: subColor, size: 16),
                    const SizedBox(width: 6),
                    Text('알아두기', style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '• 보장성보험(실손·암·종신)은 연 100만원 한도로 12% 공제됩니다.\n'
                    '• 장애인전용보장성보험은 별도 연 100만원 한도로 15% 공제됩니다.\n'
                    '• 저축성 보험(연금보험, 저축보험 등)은 이 공제 대상이 아닙니다.\n'
                    '• 연말정산 시 보험료 납입증명서를 회사에 제출하세요.',
                    style: TextStyle(color: subColor, fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
            const CalcDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: TextStyle(color: labelColor, fontSize: 13))),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {String? hint}) {
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: subColor, fontSize: 14)),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint, style: TextStyle(color: subColor.withValues(alpha: 0.7), fontSize: 11)),
        ],
        const SizedBox(height: 4),
        AmountField(controller: controller, expand: true, onChanged: (_) => setState(() {})),
      ],
    );
  }
}
