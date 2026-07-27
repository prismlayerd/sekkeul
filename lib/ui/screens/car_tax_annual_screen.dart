import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';

class CarTaxAnnualScreen extends StatefulWidget {
  const CarTaxAnnualScreen({super.key});

  @override
  State<CarTaxAnnualScreen> createState() => _CarTaxAnnualScreenState();
}

class _CarTaxAnnualScreenState extends State<CarTaxAnnualScreen> {
  final _taxCtrl = TextEditingController();
  int _month = 1;
  final _fmt = NumberFormat('#,###');

  static const Map<int, double> _rates = {1: 4.57, 3: 3.76, 6: 2.51, 9: 1.26};

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '')) ?? 0;

  double get _annualTax => _num(_taxCtrl);
  double get _rate => _rates[_month]!;
  double get _discount => _annualTax * _rate / 100;
  double get _payAmount => _annualTax - _discount;

  bool get _hasInput => _annualTax > 0;

  String _won(double v) => '${_fmt.format(v.round())}원';

  @override
  void dispose() {
    _taxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    final bg = AppTheme.surface(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        title: Text('자동차세 연납 할인',
            style: AppTheme.serif(16, ink, weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _amountField('연간 자동차세 (본세+지방교육세)', _taxCtrl, ink, sub, line),
            const SizedBox(height: 20),
            Text('신청 시기', style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: _rates.keys
                  .map((m) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _segButton('$m월', m, _month,
                              (v) => setState(() => _month = v), ink, line, accent),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 32),
            if (_hasInput) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_month월 연납 시', style: AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('절감액', style: AppTheme.sans(14, ink, weight: FontWeight.w700)),
                        Text('-${_won(_discount)}',
                            style: AppTheme.sans(16, accent, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('공제율', '${_rate.toStringAsFixed(2)}%', ink, sub),
                    const SizedBox(height: 8),
                    _row('실제 납부액', _won(_payAmount), ink, sub),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox('2026년 신청 일정', const [
              '1월: 1.16~1.31 (공제율 약 4.57%)',
              '3월: 3.16~3.31 (공제율 약 3.76%)',
              '6월: 6.16~6.30 (공제율 약 2.51%)',
              '9월: 9.16~9.30 (공제율 약 1.26%)',
              '기준 이자율 연 3.65%로 일할 계산합니다.',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('신청 방법', const [
              '위택스(wetax.go.kr) - 신고/납부 → 자동차세 연세액',
              '서울은 이택스(etax.seoul.go.kr) 이용',
              '차량등록지 관할 구청·시청 세무과 방문 신청 가능',
              '2024년 1월부터 10% 일괄 할인은 폐지되고 일할 계산 방식으로 변경되었습니다.',
              '체납액이 있으면 신청이 제한될 수 있습니다.',
            ], line, sub, ink),
            const CalcDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _amountField(
      String label, TextEditingController ctrl, Color ink, Color sub, Color line) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          inputFormatters: const [ThousandsFormatter()],
          style: AppTheme.sans(14, ink),
          decoration: InputDecoration(
            suffixText: '원',
            suffixStyle: AppTheme.sans(14, sub),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: ink)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onChanged: (v) {
            final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
            final formatted = digits.isEmpty ? '' : _fmt.format(int.parse(digits));
            ctrl.value = TextEditingValue(
                text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _segButton(String label, int value, int groupValue,
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
            style: AppTheme.sans(12, selected ? accent : ink, weight: FontWeight.w600)),
      ),
    );
  }

  Widget _row(String label, String value, Color ink, Color sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: AppTheme.sans(13, sub))),
        Text(value, style: AppTheme.sans(13, ink, weight: FontWeight.w600)),
      ],
    );
  }

  Widget _infoBox(String title, List<String> items, Color line, Color sub, Color ink) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: AppTheme.sans(13, sub)),
                Expanded(child: Text(item, style: AppTheme.sans(13, sub, height: 1.5))),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
