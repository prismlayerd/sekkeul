import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class NewbornSpecialLoanScreen extends StatefulWidget {
  const NewbornSpecialLoanScreen({super.key});

  @override
  State<NewbornSpecialLoanScreen> createState() =>
      _NewbornSpecialLoanScreenState();
}

class _NewbornSpecialLoanScreenState extends State<NewbornSpecialLoanScreen> {
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _fmt = NumberFormat('#,###');

  double get _amount =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
  double get _rate => double.tryParse(_rateCtrl.text.replaceAll(',', '')) ?? 0;
  double get _years =>
      double.tryParse(_yearsCtrl.text.replaceAll(',', '')) ?? 0;

  int get _months => (_years * 12).round();

  // 원리금균등 월상환액
  double get _monthlyPayment {
    if (_amount <= 0 || _months <= 0) return 0;
    final r = _rate / 100 / 12;
    if (r == 0) return _amount / _months;
    final factor = math.pow(1 + r, _months);
    return _amount * r * factor / (factor - 1);
  }

  double get _totalPayment => _monthlyPayment * _months;
  double get _totalInterest => _totalPayment - _amount;

  bool get _hasInput => _amount > 0 && _rate > 0 && _years > 0;

  String _won(double v) {
    if (v <= 0) return '-';
    return '${_fmt.format(v.round())}원';
  }

  String _manwon(double v) {
    if (v <= 0) return '-';
    return '약 ${_fmt.format((v / 10000).round())}만원';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
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
        title: Text('신생아 특례대출',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _inputField('대출금액', _amountCtrl, '300,000,000', '원', ink, sub, line),
            const SizedBox(height: 16),
            _inputField('연금리', _rateCtrl, '2.5', '%', ink, sub, line),
            const SizedBox(height: 16),
            _inputField('상환기간', _yearsCtrl, '30', '년', ink, sub, line),
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
                    Text('원리금균등 상환 예상',
                        style:
                            AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('월 상환액',
                            style: AppTheme.sans(14, ink,
                                weight: FontWeight.w700)),
                        Text(_won(_monthlyPayment),
                            style: AppTheme.sans(16, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('총 상환액', _manwon(_totalPayment), ink, sub),
                    const SizedBox(height: 8),
                    _row('총 이자', _manwon(_totalInterest), ink, sub),
                    const SizedBox(height: 8),
                    Text('* 원리금균등 기준. 특례금리는 소득·자녀 수에 따라 차등 적용됩니다.'.keepWords,
                        style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '지원 대상',
              [
                '대출 신청일 기준 2년 내 출산·입양 무주택 가구 (2023.1.1 이후 출생아)',
                '부부 합산 연소득 요건 충족 (구입 2.5억, 전세 1.3억 이하 등 연도별 상이)',
                '주택 요건: 구입 9억·전용 85㎡ 이하 / 전세 보증금 기준 충족',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '특례 혜택',
              [
                '구입자금(디딤돌): 최저 연 1%대~3%대, 최대 5억원',
                '전세자금(버팀목): 최저 연 1%대~3%대, 수도권 최대 3억원',
                '특례금리 5년 적용, 추가 출산 시 자녀 1인당 우대금리 + 기간 연장',
              ],
              line,
              sub,
              ink,
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, String hint,
      String suffix, Color ink, Color sub, Color line) {
    final isRate = suffix == '%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.numberWithOptions(decimal: isRate),
          textAlign: TextAlign.right,
inputFormatters: [
            if (suffix == '원' || suffix == '만원')
              const ThousandsFormatter()
            else
              isRate
                  ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  : FilteringTextInputFormatter.digitsOnly,
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
