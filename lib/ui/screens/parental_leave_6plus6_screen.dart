import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class ParentalLeave6Plus6Screen extends StatefulWidget {
  const ParentalLeave6Plus6Screen({super.key});

  @override
  State<ParentalLeave6Plus6Screen> createState() =>
      _ParentalLeave6Plus6ScreenState();
}

class _ParentalLeave6Plus6ScreenState extends State<ParentalLeave6Plus6Screen> {
  final _p1Ctrl = TextEditingController();
  final _p2Ctrl = TextEditingController();

  // 6+6 부모육아휴직제: 첫 6개월 통상임금 100%, 월별 상한 단계 상향
  static const _caps = [2000000, 2500000, 3000000, 3500000, 4000000, 4500000];

  double get _p1 => double.tryParse(_p1Ctrl.text.replaceAll(',', '')) ?? 0;
  double get _p2 => double.tryParse(_p2Ctrl.text.replaceAll(',', '')) ?? 0;

  double _sixMonth(double wage) {
    double sum = 0;
    for (final cap in _caps) {
      sum += wage < cap ? wage : cap;
    }
    return sum;
  }

  double get _p1Total => _sixMonth(_p1);
  double get _p2Total => _sixMonth(_p2);
  double get _combined => _p1Total + _p2Total;

  bool get _hasInput => _p1 > 0 && _p2 > 0;

  String _manwon(double v) {
    if (v <= 0) return '-';
    return '약 ${comma((v / 10000).round())}만원';
  }

  @override
  void dispose() {
    _p1Ctrl.dispose();
    _p2Ctrl.dispose();
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
        title: Text('6+6 부모육아휴직급여',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _inputField('부모 A 월 통상임금', _p1Ctrl, '4,500,000', '원', ink, sub, line),
            const SizedBox(height: 16),
            _inputField('부모 B 월 통상임금', _p2Ctrl, '3,000,000', '원', ink, sub, line),
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
                    Text('첫 6개월 급여 합계 (부모 각각)'.keepWords,
                        style:
                            AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _row('부모 A 6개월 합계', _manwon(_p1Total), ink, sub),
                    const SizedBox(height: 8),
                    _row('부모 B 6개월 합계', _manwon(_p2Total), ink, sub),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('부부 합산 (첫 6개월)',
                            style: AppTheme.sans(14, ink,
                                weight: FontWeight.w700)),
                        Text(_manwon(_combined),
                            style: AppTheme.sans(16, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('* 통상임금 100%, 월 상한 1→6개월차 200만~450만원 단계 적용. 7개월차부터는 일반 육아휴직급여로 전환.'.keepWords,
                        style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '제도 요건',
              [
                '생후 18개월 이내 자녀에 대해 부모가 모두 육아휴직 사용',
                '동시 또는 순차 사용 모두 가능',
                '첫 6개월 통상임금 100% 지급 (상한 단계 상향)',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '월별 상한액',
              [
                '1개월차: 월 200만원',
                '2개월차: 월 250만원',
                '3개월차: 월 300만원',
                '4개월차: 월 350만원',
                '5개월차: 월 400만원',
                '6개월차: 월 450만원',
              ],
              line,
              sub,
              ink,
            ),
            const CalcDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, String hint,
      String suffix, Color ink, Color sub, Color line) {
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
            hintText: hint,
            hintStyle: AppTheme.sans(14, sub),
            suffixText: suffix,
            suffixStyle: AppTheme.sans(14, sub),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: ink)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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

  Widget _infoBox(
      String title, List<String> items, Color line, Color sub, Color ink) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(4)),
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
                Expanded(
                    child: Text(item,
                        style: AppTheme.sans(13, sub, height: 1.5))),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
