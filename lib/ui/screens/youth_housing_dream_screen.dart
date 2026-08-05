import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class YouthHousingDreamScreen extends StatefulWidget {
  const YouthHousingDreamScreen({super.key});

  @override
  State<YouthHousingDreamScreen> createState() =>
      _YouthHousingDreamScreenState();
}

class _YouthHousingDreamScreenState extends State<YouthHousingDreamScreen> {
  final _monthlyCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController();
  final _fmt = NumberFormat('#,###');

  double get _monthly => saneInput(
      double.tryParse(_monthlyCtrl.text.replaceAll(',', '')) ?? 0, InputMax.money);
  double get _months => saneInput(
      double.tryParse(_monthsCtrl.text.replaceAll(',', '')) ?? 0, InputMax.months);

  // 드림 통장: 연 4.5% 단리
  double get _dreamInterest => _monthly * _months * 0.045 / 2 / 12 * _months;
  double get _dreamTotal => _monthly * _months + _dreamInterest;

  // 일반 통장: 연 2.8% 단리
  double get _normalInterest => _monthly * _months * 0.028 / 2 / 12 * _months;
  double get _normalTotal => _monthly * _months + _normalInterest;

  double get _diff => _dreamTotal - _normalTotal;

  // 소득공제 환급: 연납입액 최대 240만원 × 40% × 16.5%
  double get _annualDeposit => _monthly * 12;
  double get _deductionBase => _annualDeposit.clamp(0, 2400000) * 0.40;
  double get _taxRefund => _deductionBase * 0.165;

  bool get _hasInput => _monthly > 0 && _months > 0;

  String _manwon(double v) {
    if (v <= 0) return '-';
    return '약 ${_fmt.format((v / 10000).round())}만원';
  }

  String _won(double v) {
    if (v <= 0) return '-';
    return '약 ${_fmt.format(v.round())}원';
  }

  @override
  void dispose() {
    _monthlyCtrl.dispose();
    _monthsCtrl.dispose();
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
        title: Text('청년 주택드림 청약통장',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _inputField('월 납입액', _monthlyCtrl, '500,000', '원', ink, sub, line),
            const SizedBox(height: 16),
            _inputField('납입 기간', _monthsCtrl, '24', '개월', ink, sub, line),
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
                    Text('이자 비교 (단리 추정)',
                        style:
                            AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _row('드림 통장 (연 4.5%)', _manwon(_dreamTotal), ink, sub),
                    const SizedBox(height: 8),
                    _row('일반 통장 (연 2.8%)', _manwon(_normalTotal), ink, sub),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('드림 통장 추가 이익',
                            style: AppTheme.sans(14, ink,
                                weight: FontWeight.w700)),
                        Text(_manwon(_diff),
                            style: AppTheme.sans(16, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('연간 납입액', _manwon(_annualDeposit), ink, sub),
                    const SizedBox(height: 8),
                    _row('소득공제 금액 (40%)', _manwon(_deductionBase), ink, sub),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('연 세금 환급 추정 (16.5%)'.keepWords,
                            style: AppTheme.sans(13, ink,
                                weight: FontWeight.w700)),
                        Text(_won(_taxRefund),
                            style: AppTheme.sans(13, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        '* 소득공제 한도 연 240만원. 세율 16.5%(소득세 15%+지방세 1.5%) 기준.'.keepWords,
                        style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '자격 및 혜택',
              [
                '만 19~34세 무주택자',
                '연소득 5,000만원 이하',
                '금리: 연 최대 4.5%',
                '월 2만~100만원 자유납입',
                '24개월 납입 시 청약 1순위 자격',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '소득공제 & 대출 연계',
              [
                '연 납입액 최대 240만원 한도, 40% 소득공제',
                '납입 240만원 기준 연 최대 약 396,000원 환급',
                '당첨 후 분양가 80%까지 연 2%대 저금리 대출 연계',
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
