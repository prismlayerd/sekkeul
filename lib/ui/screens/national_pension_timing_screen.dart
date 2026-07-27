import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

class NationalPensionTimingScreen extends StatefulWidget {
  const NationalPensionTimingScreen({super.key});

  @override
  State<NationalPensionTimingScreen> createState() =>
      _NationalPensionTimingScreenState();
}

class _NationalPensionTimingScreenState
    extends State<NationalPensionTimingScreen> {
  final TextEditingController _baseController = TextEditingController();
  final _fmt = NumberFormat('#,###');

  void _reset() => setState(() => _baseController.clear());

  @override
  void dispose() {
    _baseController.dispose();
    super.dispose();
  }

  double get _base =>
      double.tryParse(_baseController.text.replaceAll(',', '')) ?? 0.0;

  double _earlyAmount(int yrs) => _base * (1 - 0.06 * yrs);
  double _deferAmount(int yrs) => _base * (1 + 0.072 * yrs);

  int _breakEvenMonths(int earlyYrs) {
    final early = _earlyAmount(earlyYrs);
    final normal = _base;
    if (early <= 0 || normal <= early) return 0;
    final earlyMonths = earlyYrs * 12;
    return (early * earlyMonths / (normal - early)).ceil();
  }

  String _won(double v) => '${_fmt.format(v.round())}원';
  String _manwon(double v) {
    if (v <= 0) return '0원';
    return '${_fmt.format((v / 10000).round())}만원';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;
    final hasInput = _base > 0;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('국민연금 조기·연기',
            style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
            Text('수령 시기에 따른\n연금액 변화를 비교해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('조기수령 −6%/년(최대 5년), 연기수령 +7.2%/년(최대 5년)'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('기준 월 연금액',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('정상 수령 시 예상 월 연금액을 입력하세요.'.keepWords,
                      style: TextStyle(
                          color: subColor.withValues(alpha: 0.7), fontSize: 11)),
                  const SizedBox(height: 8),
                  AmountField(
                    controller: _baseController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (hasInput) ...[
                    const SizedBox(height: 8),
                    Text('기준 연금: ${_won(_base)}'.keepWords,
                        style: TextStyle(color: subColor, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (hasInput) ...[
              _comparisonTable(context, textColor, subColor, primary,
                  isEarly: true),
              const SizedBox(height: 16),
              _comparisonTable(context, textColor, subColor, primary,
                  isEarly: false),
            ] else
              Container(
                padding: const EdgeInsets.all(20),
                decoration:
                    AppTheme.getAccentCardDecoration(context, borderRadius: 20),
                child: Text('기준 월 연금액을 입력해보세요.'.keepWords,
                    style: TextStyle(color: subColor, fontSize: 13)),
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
                    '• 조기수령: 최대 5년 앞당겨 받으며 1년당 6% 감액됩니다.\n'
                    '• 연기수령: 최대 5년 늦춰 받으며 1년당 7.2% 증액됩니다.\n'
                    '• 손익분기점은 정상수령 개시 시점 이후 기준입니다.\n'
                    '• 실제 수령 조건은 국민연금공단에 문의하세요.',
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

  Widget _comparisonTable(BuildContext context, Color textColor, Color subColor,
      Color primary, {required bool isEarly}) {
    final base = _base;
    return Container(
      decoration: isEarly
          ? AppTheme.getCardDecoration(context, borderRadius: 16)
          : AppTheme.getAccentCardDecoration(context, borderRadius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              Icon(
                isEarly
                    ? Icons.arrow_back_rounded
                    : Icons.arrow_forward_rounded,
                color: isEarly ? Colors.orange : primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(isEarly ? '조기 수령' : '연기 수령',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(
                  flex: 2,
                  child: Text('기간',
                      style: TextStyle(
                          color: subColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 2,
                  child: Text('월 연금액',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: subColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 3,
                  child: Text('손익분기',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: subColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
            ]),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          ...List.generate(5, (i) {
            final yrs = i + 1;
            final amount =
                isEarly ? _earlyAmount(yrs) : _deferAmount(yrs);
            final diff = amount - base;
            final diffPct =
                '${diff >= 0 ? '+' : ''}${(diff / base * 100).toStringAsFixed(0)}%';
            String breakEven;
            if (isEarly) {
              final months = _breakEvenMonths(yrs);
              final y = months ~/ 12;
              final m = months % 12;
              breakEven = y > 0 ? '$y년 $m개월 후' : '$m개월 후';
            } else {
              breakEven = '연기 후 즉시 유리';
            }
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(children: [
                  Expanded(
                      flex: 2,
                      child: Text('$yrs년',
                          style:
                              TextStyle(color: textColor, fontSize: 13))),
                  Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(_manwon(amount),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color:
                                      isEarly ? Colors.orange : primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Text(diffPct,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color:
                                      isEarly ? Colors.orange : primary,
                                  fontSize: 11)),
                        ],
                      )),
                  Expanded(
                      flex: 3,
                      child: Text(
                        isEarly
                            ? '정상수령 개시 후\n$breakEven'
                            : breakEven,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: subColor, fontSize: 11, height: 1.4),
                      )),
                ]),
              ),
              Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor,
                  indent: 16),
            ]);
          }),
        ],
      ),
    );
  }
}
