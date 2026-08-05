import 'package:flutter/material.dart';
import '../../core/tax_engine/tax_rates.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';

class HourlyRateConverterScreen extends StatefulWidget {
  const HourlyRateConverterScreen({super.key});

  @override
  State<HourlyRateConverterScreen> createState() =>
      _HourlyRateConverterScreenState();
}

class _HourlyRateConverterScreenState
    extends State<HourlyRateConverterScreen> {
  final _rateCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _marginCtrl = TextEditingController(text: '0');
  final _fmt = NumberFormat('#,###');

  static int get _minWage2026 => TaxRates.minimumHourlyWage2026.toInt();

  double _num(TextEditingController c) => saneInput(
      double.tryParse(c.text.replaceAll(',', '')) ?? 0, InputMax.unitPrice);

  double get _rate => saneInput(_num(_rateCtrl), InputMax.unitPrice);
  double get _hours => saneInput(_num(_hoursCtrl), 1000);
  double get _base => _rate * _hours;
  double get _quote =>
      _base * (1 + saneInput(_num(_marginCtrl), InputMax.percent) / 100);
  double get _afterTax => _quote * (1 - 0.033);

  bool get _hasInput => _rate > 0 && _hours > 0;

  String _won(double v) => '${_fmt.format(v.round())}원';

  @override
  void dispose() {
    _rateCtrl.dispose();
    _hoursCtrl.dispose();
    _marginCtrl.dispose();
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
        title: Text('시급 환산기',
            style: AppTheme.serif(16, ink, weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _numField('시급', _rateCtrl, '원', ink, sub, line),
            const SizedBox(height: 16),
            _numField('예상 작업 시간', _hoursCtrl, '시간', ink, sub, line),
            const SizedBox(height: 16),
            _numField('마진 추가 (선택)', _marginCtrl, '%', ink, sub, line),
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
                    Text('프로젝트 견적',
                        style: AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('최종 제안 금액',
                            style: AppTheme.sans(14, ink, weight: FontWeight.w700)),
                        Text(_won(_quote),
                            style: AppTheme.sans(16, accent, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('기본 금액 (마진 전)', _won(_base), ink, sub),
                    const SizedBox(height: 8),
                    _row('3.3% 원천징수 후 실수령', _won(_afterTax), ink, sub),
                    const SizedBox(height: 8),
                    _row('일급 환산 (8시간)', _won(_rate * 8), ink, sub),
                    const SizedBox(height: 8),
                    _row('월급 환산 (월 160시간)', _won(_rate * 160), ink, sub),
                    const SizedBox(height: 12),
                    Text(
                        _rate >= _minWage2026
                            ? '* 2026년 최저시급(10,320원) 이상입니다.'
                            : '* 2026년 최저시급(10,320원)보다 낮습니다.',
                        style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox('참고', const [
              '프리랜서 실제 청구 가능 시간은 전체 근무시간의 60~70% 수준인 경우가 많습니다.',
              '3.3% 원천징수는 프리랜서·사업소득자 기준이며, 5월 종합소득세 신고로 정산됩니다.',
              '월급 환산은 하루 8시간 × 20일(월 160시간) 기준 참고치입니다.',
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
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          inputFormatters: [
            if (suffix == '원' || suffix == '만원')
              const ThousandsFormatter()
            else
              FilteringTextInputFormatter.digitsOnly,
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
