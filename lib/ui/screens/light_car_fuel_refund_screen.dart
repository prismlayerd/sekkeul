import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class LightCarFuelRefundScreen extends StatefulWidget {
  const LightCarFuelRefundScreen({super.key});

  @override
  State<LightCarFuelRefundScreen> createState() => _LightCarFuelRefundScreenState();
}

class _LightCarFuelRefundScreenState extends State<LightCarFuelRefundScreen> {
  final _monthlyLiterCtrl = TextEditingController();
  int _fuelType = 0;
  final _fmt = NumberFormat('#,###');

  static const List<String> _fuelLabels = ['휘발유', '경유', 'LPG(부탄)'];
  /// 유종별 리터당 환급액 — 조특법 §111의2③ · 시행령 §112의2③.
  ///
  /// **휘발유·경유는 리터당 250원**(법제처 생활법령 「경형자동차 유류세 환급」,
  /// 확인일 2026-08-01). 종전에는 경유를 160원으로 두어 조문의 64%만 환급되는
  /// 것으로 안내했다 — 월 100L 주유 기준 연 10만 8천원을 덜 받는 것으로 계산된다.
  ///
  /// 부탄은 조문이 리터당 금액을 정하지 않고 "부과된 개별소비세 전액"이라고만
  /// 한다. 여기 197원은 실무 환산값이라 원문으로 확정되지 않았다 —
  /// 추적: test/notice_expiry_test.dart (1차 미확인)
  static const List<double> _fuelRates = [250, 250, 197];
  static const double _annualCap = 300000;

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '')) ?? 0;

  double get _monthlyLiter => _num(_monthlyLiterCtrl);
  double get _rate => _fuelRates[_fuelType];
  double get _monthlyRefund => _monthlyLiter * _rate;
  double get _annualRefundRaw => _monthlyRefund * 12;
  double get _annualRefund => _annualRefundRaw > _annualCap ? _annualCap : _annualRefundRaw;
  bool get _capped => _annualRefundRaw > _annualCap;

  bool get _hasInput => _monthlyLiter > 0;

  String _won(double v) => '${_fmt.format(v.round())}원';

  @override
  void dispose() {
    _monthlyLiterCtrl.dispose();
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
        title: Text('경차 유류세 환급',
            style: AppTheme.serif(16, ink, weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('유종', style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(_fuelLabels.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == _fuelLabels.length - 1 ? 0 : 6),
                    child: _segButton(_fuelLabels[i], i, _fuelType,
                        (v) => setState(() => _fuelType = v), ink, line, accent),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            _numField('월 평균 주유량', _monthlyLiterCtrl, 'L', ink, sub, line),
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
                    Text('예상 환급액', style: AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('연간 환급액',
                            style: AppTheme.sans(14, ink, weight: FontWeight.w700)),
                        Text(_won(_annualRefund),
                            style: AppTheme.sans(16, accent, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('월 환급액(리터당 ${_rate.toStringAsFixed(0)}원)', _won(_monthlyRefund), ink, sub),
                    if (_capped) ...[
                      const SizedBox(height: 8),
                      Text('* 연간 상한 30만원 초과분은 지급되지 않습니다.'.keepWords,
                          style: AppTheme.sans(11, sub)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox('적격 차량', const [
              '배기량 1,000cc 미만 경형자동차(승용·승합·화물·특수)',
              '1인 1대 원칙이 적용됩니다.',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('환급 단가 · 상한', const [
              '휘발유·경유 리터당 250원, LPG(부탄)는 부과된 개별소비세 전액(환산 197원)',
              '연간 상한 30만원(1대 기준)',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('신청 방법', const [
              '국세청 등록 카드사(신한·현대·우리·KB국민·삼성·비씨·롯데·NH농협·하나·씨티)에 경차 유류구매전용카드 발급 신청',
              '차량등록증 사본 제출',
              '발급받은 카드로 주유 시 결제 → 카드사가 매월 청구 후 소유자 계좌로 자동 환급',
              '반드시 유류구매전용카드로 결제해야 환급되며, 일반 신용카드 결제분은 소급 환급되지 않습니다.',
              '2026.12.31까지 적용됩니다.',
            ], line, sub, ink),
            const CalcDisclaimer(),
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
