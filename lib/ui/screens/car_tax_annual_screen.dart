import 'package:flutter/material.dart';
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

  /// 신청 시기 → (신청 기간, 연세액 대비 공제율 %).
  ///
  /// 지방세법 §128③ 계산식에 시행령 §125⑥ 이자율 5%를 넣은 값이다.
  /// 나눗셈을 그대로 남겨 둔다 — 6·9월은 계산식의 기준이 제2기분(연세액의
  /// 절반)이라, 1·3월처럼 365로 나누면 각각 2.52%·1.26%가 나와서 틀린다.
  /// 일수는 납부기한 다음 날부터 12월 31일까지. 2026년은 평년이라 365일.
  static const _rates = <int, (String, double)>{
    1: ('1.16~1.31', 334 / 365 * 5),      // 2.1~12.31
    3: ('3.16~3.31', 275 / 365 * 5),      // 4.1~12.31
    6: ('6.16~6.30', 5 / 2),              // 제2기분 × 이자율
    9: ('9.16~9.30', 92 / 184 * 5 / 2),   // 제2기분 × 92/184 × 이자율
  };

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '')) ?? 0;

  double get _annualTax => _num(_taxCtrl);
  double get _rate => _rates[_month]!.$2;
  double get _discount => _annualTax * _rate / 100;
  double get _payAmount => _annualTax - _discount;

  bool get _hasInput => _annualTax > 0;


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
      appBar: AppBar(
        title: Text('자동차세 연납 할인',
            style: AppTheme.serif(AppTheme.tsBase, ink, weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _amountField('연간 자동차세 (본세+지방교육세)', _taxCtrl, ink, sub, line),
            const SizedBox(height: 20),
            Text('신청 시기', style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
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
                    Text('$_month월 연납 시', style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('절감액', style: AppTheme.sans(AppTheme.tsMD, ink, weight: FontWeight.w700)),
                        Text('-${won(_discount)}',
                            style: AppTheme.sans(AppTheme.tsBase, accent, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('공제율', '${_rate.toStringAsFixed(2)}%', ink, sub),
                    const SizedBox(height: 8),
                    _row('실제 납부액', won(_payAmount), ink, sub),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox('2026년 신청 일정', [
              for (final e in _rates.entries)
                '${e.key}월: ${e.value.$1} (공제율 ${e.value.$2.toStringAsFixed(2)}%)',
              '이자율 연 5%로 남은 기간을 일할 계산합니다(지방세법 시행령 §125⑥).',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('신청 방법', const [
              '위택스(wetax.go.kr) - 신고/납부 → 자동차세 연세액',
              '서울은 이택스(etax.seoul.go.kr) 이용',
              '차량등록지 관할 구청·시청 세무과 방문 신청 가능',
              '옛 10% 일괄 할인은 없어졌고, 지방세법 §128③ 계산식으로 공제액을 냅니다.',
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
        Text(label, style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          inputFormatters: const [ThousandsFormatter()],
          style: AppTheme.sans(AppTheme.tsMD, ink),
          decoration: InputDecoration(
            suffixText: '원',
            suffixStyle: AppTheme.sans(AppTheme.tsMD, sub),
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
            final formatted = digits.isEmpty ? '' : comma(int.parse(digits));
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
            style: AppTheme.sans(AppTheme.tsXS, selected ? accent : ink, weight: FontWeight.w600)),
      ),
    );
  }

  Widget _row(String label, String value, Color ink, Color sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: AppTheme.sans(AppTheme.tsSM, sub))),
        Text(value, style: AppTheme.sans(AppTheme.tsSM, ink, weight: FontWeight.w600)),
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
          Text(title, style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: AppTheme.sans(AppTheme.tsSM, sub)),
                Expanded(child: Text(item, style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5))),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
