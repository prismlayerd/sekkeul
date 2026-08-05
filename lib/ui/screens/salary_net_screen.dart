import 'package:flutter/material.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../../core/tax_engine/insurance_engine.dart';
import '../../core/tax_engine/employee_tax.dart';
import '../theme/text_wrap.dart';

/// 연봉 실수령액 계산기
/// 세전연봉 → 4대보험 + 소득세 + 지방소득세 공제 후 월/연 실수령액
class SalaryNetScreen extends StatefulWidget {
  const SalaryNetScreen({super.key});

  @override
  State<SalaryNetScreen> createState() => _SalaryNetScreenState();
}

class _SalaryNetScreenState extends State<SalaryNetScreen> {
  final TextEditingController _annualController = TextEditingController();
  int _dependents = 1;

  void _reset() {
    setState(() {
      _annualController.clear();
      _dependents = 1;
    });
  }

  @override
  void dispose() {
    _annualController.dispose();
    super.dispose();
  }

  double get _annual =>
      double.tryParse(_annualController.text.replaceAll(',', '')) ?? 0.0;

  String _won(double v) => v <= 0 ? '0원' : '${comma(v.round())}원';
  String _manwon(double v) {
    if (v <= 0) return '0원';
    final man = (v / 10000).round();
    return '${comma(man)}만원';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;

    final annual = _annual;
    final hasInput = annual > 0;
    final monthly = annual / 12;

    final ins = hasInput ? InsuranceEngine.calculateEmployeeInsurance(monthly) : null;
    final incomeTax = hasInput
        ? EmployeeTaxCalculator.estimateMonthlyIncomeTax(
            grossAnnual: annual,
            dependentsIncludingSelf: _dependents,
          )
        : 0.0;
    final localTax = (incomeTax * 0.1).floorToDouble();
    final totalDeduction = (ins?.totalMonthlyPremium ?? 0) + incomeTax + localTax;
    final monthlyNet = hasInput ? monthly - totalDeduction : 0.0;
    final annualNet = monthlyNet * 12;

    return Scaffold(
      appBar: AppBar(
        title: Text('연봉 실수령액',
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
            Text('세전 연봉으로\n실제 수령액을 계산해요'.keepWords,
                style: TextStyle(
                    color: textColor, fontSize: 22, fontWeight: FontWeight.bold, height: 1.4)),
            const SizedBox(height: 8),
            Text('4대보험 + 근로소득세 + 지방소득세를 제외한 금액입니다.'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            // 연봉 입력
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('세전 연봉', style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 4),
                  AmountField(
                    controller: _annualController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (hasInput) ...[
                    const SizedBox(height: 8),
                    Text('월 환산: ${_won(monthly)}'.keepWords,
                        style: TextStyle(color: subColor, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 부양가족 수
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('부양가족 수 (본인 포함)',
                      style: TextStyle(
                          color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('세액공제 적용 인원 수입니다.'.keepWords,
                      style: TextStyle(
                          color: subColor.withValues(alpha: 0.7), fontSize: 11)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final n = i + 1;
                      final sel = _dependents == n;
                      return GestureDetector(
                        onTap: () => setState(() => _dependents = n),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: sel ? primary : primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text('$n명',
                              style: TextStyle(
                                  color: sel ? Colors.white : subColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 결과
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getAccentCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.account_balance_wallet_outlined, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text('월 실수령액',
                        style: TextStyle(
                            color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(hasInput ? _manwon(monthlyNet) : '0원',
                      style: TextStyle(
                          color: primary, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (hasInput && ins != null) ...[
                    _row('세전 월급', _won(monthly), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('국민연금', '- ${_won(ins.nationalPension)}', subColor, textColor),
                    const SizedBox(height: 8),
                    _row('건강보험 + 장기요양',
                        '- ${_won(ins.healthInsurance + ins.longTermCare)}', subColor, textColor),
                    const SizedBox(height: 8),
                    _row('고용보험', '- ${_won(ins.employmentInsurance)}', subColor, textColor),
                    const SizedBox(height: 8),
                    _row('근로소득세', '- ${_won(incomeTax)}', subColor, textColor),
                    const SizedBox(height: 8),
                    _row('지방소득세', '- ${_won(localTax)}', subColor, textColor),
                    const SizedBox(height: 12),
                    Divider(color: Theme.of(context).dividerColor, height: 1, thickness: 1),
                    const SizedBox(height: 12),
                    _row('연 실수령액', _manwon(annualNet), subColor, primary),
                    const SizedBox(height: 4),
                    _row('공제율',
                        '${(totalDeduction / monthly * 100).toStringAsFixed(1)}%',
                        subColor, textColor),
                  ] else
                    Text('세전 연봉을 입력해보세요.',
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
                    Icon(Icons.lightbulb_outline_rounded, color: subColor, size: 16),
                    const SizedBox(width: 6),
                    Text('알아두기',
                        style: TextStyle(
                            color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '• 근로소득세는 간이세액표 근사값으로 연말정산 결과와 다를 수 있습니다.\n'
                    '• 지방소득세는 근로소득세의 10%입니다.\n'
                    '• 식대 비과세(월 20만원) 등은 반영되지 않았습니다.\n'
                    '• 비과세 수당 적용 시 실수령액이 늘어날 수 있습니다.',
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

  Widget _row(String label, String value, Color labelColor, Color valueColor) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label, style: TextStyle(color: labelColor, fontSize: 13))),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      );
}
