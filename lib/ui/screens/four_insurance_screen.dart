import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../../core/tax_engine/insurance_engine.dart';

/// 4대보험료 계산기 (2026년 기준)
/// 엔진: InsuranceEngine.calculateEmployeeInsurance
class FourInsuranceScreen extends StatefulWidget {
  const FourInsuranceScreen({super.key});

  @override
  State<FourInsuranceScreen> createState() => _FourInsuranceScreenState();
}

class _FourInsuranceScreenState extends State<FourInsuranceScreen> {
  final TextEditingController _salaryController = TextEditingController();
  final _fmt = NumberFormat('#,###');

  void _reset() => setState(() => _salaryController.clear());

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  double get _monthly =>
      double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;

  String _won(double v) => v <= 0 ? '0원' : '${_fmt.format(v.round())}원';

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;

    final monthly = _monthly;
    final r = InsuranceEngine.calculateEmployeeInsurance(monthly);
    final hasInput = monthly > 0;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('4대보험료 계산기',
            style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textColor),
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
            Text('월급에서 빠져나가는\n4대보험료를 확인해요',
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('국민연금·건강보험·장기요양·고용보험 근로자 부담분 (2026년 기준)',
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('월 급여 (세전)',
                      style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 4),
                  AmountField(
                    controller: _salaryController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getAccentCardDecoration(context,
                  borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.shield_outlined, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text('월 공제 보험료 합계',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(hasInput ? _won(r.totalMonthlyPremium) : '0원',
                      style: TextStyle(
                          color: primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (hasInput) ...[
                    _row(
                        '국민연금 (${(InsuranceEngine.empNationalPensionRate * 100).toStringAsFixed(2)}%)',
                        _won(r.nationalPension),
                        subColor,
                        textColor),
                    const SizedBox(height: 8),
                    _row('건강보험 (3.595%)', _won(r.healthInsurance), subColor,
                        textColor),
                    const SizedBox(height: 8),
                    _row('장기요양 (건보 × 13.14%)', _won(r.longTermCare),
                        subColor, textColor),
                    const SizedBox(height: 8),
                    _row('고용보험 (0.9%)', _won(r.employmentInsurance),
                        subColor, textColor),
                    const SizedBox(height: 12),
                    Divider(
                        color: Theme.of(context).dividerColor,
                        height: 1,
                        thickness: 1),
                    const SizedBox(height: 12),
                    _row(
                      '세후 실수령 (소득세 별도)',
                      _won(monthly - r.totalMonthlyPremium),
                      subColor,
                      primary,
                    ),
                  ] else
                    Text('월급을 입력해보세요.',
                        style: TextStyle(color: subColor, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                    Icon(Icons.lightbulb_outline_rounded,
                        color: subColor, size: 16),
                    const SizedBox(width: 6),
                    Text('알아두기',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '• 국민연금 상한 월 ${_fmt.format(InsuranceEngine.pensionUpperBound.round())}원 / '
                    '하한 ${_fmt.format(InsuranceEngine.pensionLowerBound.round())}원 적용됩니다.\n'
                    '• 건강보험료 기준으로 장기요양보험료가 산정됩니다.\n'
                    '• 사업주도 동일 금액을 부담합니다 (산재는 전액 사업주 부담).\n'
                    '• 소득세·지방소득세는 별도 세율표에 따라 추가 공제됩니다.',
                    style: TextStyle(
                        color: subColor, fontSize: 12, height: 1.6),
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

  Widget _row(
          String label, String value, Color labelColor, Color valueColor) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(color: labelColor, fontSize: 13))),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      );
}
