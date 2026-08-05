import 'package:flutter/material.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

/// 프리랜서 3.3% 원천징수 계산기 — 계약금액(세전) → 원천징수세액·실수령액(세후).
class WithholdingCalcScreen extends StatefulWidget {
  const WithholdingCalcScreen({super.key});

  @override
  State<WithholdingCalcScreen> createState() => _WithholdingCalcScreenState();
}

class _WithholdingCalcScreenState extends State<WithholdingCalcScreen> {
  final TextEditingController _amountCtrl = TextEditingController();

  void _reset() => setState(() => _amountCtrl.clear());

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _gross =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;

  double get _incomeTax => _gross * 0.03;
  double get _localIncomeTax => _gross * 0.003;
  double get _withheldTotal => _incomeTax + _localIncomeTax;
  double get _netReceived => _gross - _withheldTotal;

  String won(double v) {
    if (v <= 0) return '0원';
    final eok = v / 100000000;
    if (eok >= 1) return '${eok.toStringAsFixed(2)}억원';
    final man = v / 10000;
    if (man >= 1) return '${man.toStringAsFixed(0)}만원';
    return '${comma(v.round())}원';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;
    final hasResult = _gross > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('3.3% 원천징수 계산기',
            style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
            Text('프리랜서 용역대가\n원천징수세액을 계산해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('사업소득세 3% + 지방소득세 0.3% 원천징수 기준'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('계약금액 (세전)',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AmountField(
                    controller: _amountCtrl,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  AppTheme.getAccentCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.receipt_long_outlined, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text('실수령액',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(hasResult ? won(_netReceived) : '0원',
                      style: TextStyle(
                          color: primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (hasResult) ...[
                    _row('계약금액', won(_gross), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('사업소득세 (3%)', won(_incomeTax), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('지방소득세 (0.3%)', won(_localIncomeTax), subColor, textColor),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    const SizedBox(height: 12),
                    _row('원천징수세액 합계', won(_withheldTotal), subColor, primary),
                  ] else
                    Text('계약금액을 입력해보세요.',
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
                    '• 원천징수는 지급자가 미리 떼고 주는 세금으로, 최종 세액이 아니에요.\n'
                    '• 5월 종합소득세 신고 때 실제 소득·경비 기준으로 정산돼요.\n'
                    '• 가계부에 수익을 기록할 때 "3.3% 원천징수"를 켜면 실수령액 입력만으로 '
                    '세전 금액을 자동으로 보여줘요.',
                    style:
                        TextStyle(color: subColor, fontSize: 12, height: 1.6),
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

  Widget _row(String label, String value, Color labelColor, Color valueColor) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
              child:
                  Text(label, style: TextStyle(color: labelColor, fontSize: 13))),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      );
}
