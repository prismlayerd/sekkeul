import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class EvVsGasScreen extends StatefulWidget {
  const EvVsGasScreen({super.key});

  @override
  State<EvVsGasScreen> createState() => _EvVsGasScreenState();
}

class _EvVsGasScreenState extends State<EvVsGasScreen> {
  final _dailyKmCtrl = TextEditingController(text: '40');
  final _gasPriceCtrl = TextEditingController(text: '1700');
  final _elecPriceCtrl = TextEditingController(text: '300');
  final _gasEfficiencyCtrl = TextEditingController(text: '12');
  final _evEfficiencyCtrl = TextEditingController(text: '5');
  final _gasPriceCarCtrl = TextEditingController();
  final _evPriceCarCtrl = TextEditingController();
  final _evSubsidyCtrl = TextEditingController();
  int _years = 5;
  final _fmt = NumberFormat('#,###');

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '')) ?? 0;

  double get _gasAnnualFuel =>
      (_num(_dailyKmCtrl) * 365 / (_num(_gasEfficiencyCtrl) == 0 ? 1 : _num(_gasEfficiencyCtrl))) *
      _num(_gasPriceCtrl);
  double get _evAnnualFuel =>
      (_num(_dailyKmCtrl) * 365 / (_num(_evEfficiencyCtrl) == 0 ? 1 : _num(_evEfficiencyCtrl))) *
      _num(_elecPriceCtrl);

  double get _gasTco => _num(_gasPriceCarCtrl) * 10000 + _gasAnnualFuel * _years;
  double get _evTco =>
      (_num(_evPriceCarCtrl) - _num(_evSubsidyCtrl)) * 10000 + _evAnnualFuel * _years;

  double get _yearlyGap => _gasAnnualFuel - _evAnnualFuel;
  int? get _breakEvenYears {
    final initialGap = (_num(_evPriceCarCtrl) - _num(_evSubsidyCtrl) - _num(_gasPriceCarCtrl)) * 10000;
    if (_yearlyGap <= 0 || initialGap <= 0) return null;
    return (initialGap / _yearlyGap).ceil();
  }

  bool get _hasInput => _num(_gasPriceCarCtrl) > 0 && _num(_evPriceCarCtrl) > 0;

  String _won(double v) => '${_fmt.format(v.round())}원';

  @override
  void dispose() {
    for (final c in [
      _dailyKmCtrl,
      _gasPriceCtrl,
      _elecPriceCtrl,
      _gasEfficiencyCtrl,
      _evEfficiencyCtrl,
      _gasPriceCarCtrl,
      _evPriceCarCtrl,
      _evSubsidyCtrl
    ]) {
      c.dispose();
    }
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
        title: Text('전기차 vs 휘발유차',
            style: AppTheme.serif(16, ink, weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _numField('일일 주행거리', _dailyKmCtrl, 'km', ink, sub, line),
            const SizedBox(height: 12),
            _numField('휘발유 가격', _gasPriceCtrl, '원/L', ink, sub, line),
            const SizedBox(height: 12),
            _numField('전기요금', _elecPriceCtrl, '원/kWh', ink, sub, line),
            const SizedBox(height: 12),
            _numField('휘발유차 연비', _gasEfficiencyCtrl, 'km/L', ink, sub, line),
            const SizedBox(height: 12),
            _numField('전기차 효율', _evEfficiencyCtrl, 'km/kWh', ink, sub, line),
            const SizedBox(height: 20),
            Text('구매·비교 조건', style: AppTheme.sans(13, ink, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            _numField('휘발유차 구매가격', _gasPriceCarCtrl, '만원', ink, sub, line),
            const SizedBox(height: 12),
            _numField('전기차 구매가격', _evPriceCarCtrl, '만원', ink, sub, line),
            const SizedBox(height: 12),
            _numField('전기차 보조금', _evSubsidyCtrl, '만원', ink, sub, line),
            const SizedBox(height: 16),
            Text('비교 기간', style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [3, 5, 7, 10]
                  .map((y) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _segButton('$y년', y, _years,
                              (v) => setState(() => _years = v), ink, line, accent),
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
                    Text('$_years년 총소유비용(TCO) 비교'.keepWords,
                        style: AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _row('휘발유차 TCO', _won(_gasTco), ink, sub),
                    const SizedBox(height: 8),
                    _row('전기차 TCO', _won(_evTco), ink, sub),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('손익분기점',
                            style: AppTheme.sans(14, ink, weight: FontWeight.w700)),
                        Text(_breakEvenYears != null ? '$_breakEvenYears년 후' : '해당 없음',
                            style: AppTheme.sans(16, accent, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _row('연간 연료비 절감액', _won(_yearlyGap), ink, sub),
                    const SizedBox(height: 8),
                    _row('연간 CO2 절감량 (참고)', '약 2.3톤', ink, sub),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox('참고', const [
              '전기차 연료비는 휘발유차 대비 약 1/3 수준으로 추정됩니다.',
              '실제 비용은 주행 습관·충전 방식(완속/급속)·지역별 보조금에 따라 달라집니다.',
              '전기차 보조금은 차량가격·지자체에 따라 크게 차이 납니다.',
            ], line, sub, ink),
          ],
        ),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl, String suffix,
      Color ink, Color sub, Color line) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
inputFormatters: [
            if (suffix == '원' || suffix == '만원')
              const ThousandsFormatter()
            else
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: AppTheme.sans(14, ink),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: AppTheme.sans(14, sub),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: ink)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
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
