import 'package:flutter/material.dart';
import '../../core/tax_engine/tax_rates.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

class _TaxResult {
  final double gain;
  final double ltd;
  final double income;
  final double base;
  final double tax;
  final double local;
  final double total;
  const _TaxResult({
    required this.gain,
    required this.ltd,
    required this.income,
    required this.base,
    required this.tax,
    required this.local,
    required this.total,
  });
}

class CapitalGainsTaxScreen extends StatefulWidget {
  const CapitalGainsTaxScreen({super.key});

  @override
  State<CapitalGainsTaxScreen> createState() => _CapitalGainsTaxScreenState();
}

class _CapitalGainsTaxScreenState extends State<CapitalGainsTaxScreen> {
  final TextEditingController _acquireController = TextEditingController();
  final TextEditingController _transferController = TextEditingController();
  final TextEditingController _yearsController =
      TextEditingController(text: '5');
  bool _oneHousehold = false;
  final _fmt = NumberFormat('#,###');

  // 양도소득세 세율은 소득세법 §104①1이 **§55①의 종합소득세율을 그대로 준용**한다.
  // 여기에 표를 따로 두었더니 2023년 개정(1,200만→1,400만, 4,600만→5,000만과
  // 누진공제 전부 상향)을 놓쳐 2022년 이전 값으로 굳어 있었다.
  // 과세표준 4,600만~5,000만 구간에서 세금이 과대 계산됐다.
  // 표를 없애고 엔진 하나만 본다.

  void _reset() => setState(() {
        _acquireController.clear();
        _transferController.clear();
        _yearsController.text = '5';
        _oneHousehold = false;
      });

  @override
  void dispose() {
    _acquireController.dispose();
    _transferController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  double get _acquire =>
      double.tryParse(_acquireController.text.replaceAll(',', '')) ?? 0.0;
  double get _transfer =>
      double.tryParse(_transferController.text.replaceAll(',', '')) ?? 0.0;
  int get _years => int.tryParse(_yearsController.text.replaceAll(',', '')) ?? 0;

  double get _ltdRate {
    final y = _years;
    if (_oneHousehold) {
      if (y < 3) return 0.0;
      return (0.24 + (y - 3) * 0.08).clamp(0.0, 0.80);
    } else {
      if (y < 3) return 0.0;
      return (0.06 + (y - 3) * 0.02).clamp(0.0, 0.30);
    }
  }

  double _incomeTax(double taxBase) => TaxRates.calculateTax(taxBase);

  _TaxResult? _compute() {
    final gain = _transfer - _acquire;
    if (gain <= 0) return null;
    final ltd = gain * _ltdRate;
    final income = gain - ltd;
    final base = (income - 2500000).clamp(0.0, double.infinity);
    final tax = _incomeTax(base);
    final local = tax * 0.10;
    final total = tax + local;
    return _TaxResult(
      gain: gain,
      ltd: ltd,
      income: income,
      base: base,
      tax: tax,
      local: local,
      total: total,
    );
  }

  String _won(double v) {
    if (v <= 0) return '0원';
    final eok = v / 100000000;
    if (eok >= 1) return '${eok.toStringAsFixed(2)}억원';
    final man = v / 10000;
    if (man >= 1) return '${man.toStringAsFixed(0)}만원';
    return '${_fmt.format(v.round())}원';
  }

  String _pct(double r) => '${(r * 100).toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;
    final result = _compute();

    return Scaffold(
      appBar: AppBar(
        title: Text('양도소득세',
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
            Text('부동산 양도 시\n납부할 세금을 계산해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('장기보유특별공제 · 기본공제 250만원 · 지방소득세 10% 포함'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('취득가액',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AmountField(
                    controller: _acquireController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Text('양도가액',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AmountField(
                    controller: _transferController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('보유기간 (년)',
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('3년 이상부터 장기보유특별공제 적용'.keepWords,
                              style: TextStyle(
                                  color: subColor.withValues(alpha: 0.8),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 80,
                      child: _numField(_yearsController, '년'),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('1세대 1주택',
                                style:
                                    TextStyle(color: textColor, fontSize: 14)),
                            Text('보유+거주 3년↑, 공제율 연 8% (최대 80%)'.keepWords,
                                style: TextStyle(
                                    color: subColor.withValues(alpha: 0.8),
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _oneHousehold,
                        activeColor: primary,
                        onChanged: (v) => setState(() => _oneHousehold = v),
                      ),
                    ],
                  ),
                  if (_years >= 3) ...[
                    const SizedBox(height: 8),
                    Text('장기보유특별공제율: ${_pct(_ltdRate)}'.keepWords,
                        style: TextStyle(
                            color: primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
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
                    Text('납부 세금 합계',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(result != null ? _won(result.total) : '0원',
                      style: TextStyle(
                          color: primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (result != null) ...[
                    _row('양도차익', _won(result.gain), subColor, textColor),
                    const SizedBox(height: 8),
                    _row(
                      '장기보유특별공제 (${_pct(_ltdRate)})',
                      result.ltd > 0 ? '- ${_won(result.ltd)}' : '해당없음',
                      subColor,
                      textColor,
                    ),
                    const SizedBox(height: 8),
                    _row('양도소득금액', _won(result.income), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('기본공제', '- 250만원', subColor, textColor),
                    const SizedBox(height: 8),
                    _row('과세표준', _won(result.base), subColor, textColor),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    const SizedBox(height: 12),
                    _row('양도소득세', _won(result.tax), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('지방소득세 (10%)', _won(result.local), subColor,
                        textColor),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    const SizedBox(height: 12),
                    _row('총 납부세액', _won(result.total), subColor, primary),
                  ] else
                    Text(
                      _transfer > 0 && _acquire > 0 && _transfer <= _acquire
                          ? '양도가액이 취득가액 이하이면 세금이 없습니다.'
                          : '취득가액·양도가액을 입력해보세요.',
                      style: TextStyle(color: subColor, fontSize: 13),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('누진세율 구간',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _rateRow('1,400만원 이하', '6%', subColor, textColor),
                  _rateRow('5,000만원 이하', '15%', subColor, textColor),
                  _rateRow('8,800만원 이하', '24%', subColor, textColor),
                  _rateRow('1.5억원 이하', '35%', subColor, textColor),
                  _rateRow('3억원 이하', '38%', subColor, textColor),
                  _rateRow('5억원 이하', '40%', subColor, textColor),
                  _rateRow('10억원 이하', '42%', subColor, textColor),
                  _rateRow('10억원 초과', '45%', subColor, textColor),
                ],
              ),
            ),
            const SizedBox(height: 12),

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
                    '• 취득세·중개수수료·필요경비는 취득가액에 포함해 입력하세요.\n'
                    '• 1세대 1주택 비과세(9억원 이하)·고가주택 특례는 별도 확인.\n'
                    '• 다주택·단기보유(1년 미만 40%, 2년 미만 30%) 중과는 미반영.\n'
                    '• 지방소득세 10%는 양도소득세액 기준으로 추가됩니다.',
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

  Widget _numField(TextEditingController ctrl, String suffix) {
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final primary = Theme.of(context).primaryColor;
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        suffixText: suffix,
        suffixStyle: TextStyle(color: subColor, fontSize: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: TextStyle(color: textColor, fontSize: 15),
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

  Widget _rateRow(
          String label, String rate, Color labelColor, Color valueColor) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: labelColor, fontSize: 12)),
            Text(rate,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
