import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../components/calc_widgets.dart';
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

  String won(double v) {
    if (v <= 0) return '-';
    return '${comma(v.round())}원';
  }

  String _manwon(double v) {
    if (v <= 0) return '-';
    return '약 ${comma((v / 10000).round())}만원';
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
      appBar: AppBar(
        title: Text('신생아 특례대출',
            style: AppTheme.serif(AppTheme.tsBase, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                            AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('월 상환액',
                            style: AppTheme.sans(AppTheme.tsMD, ink,
                                weight: FontWeight.w700)),
                        Text(won(_monthlyPayment),
                            style: AppTheme.sans(AppTheme.tsBase, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    calcRow('총 상환액', _manwon(_totalPayment), ink, sub),
                    const SizedBox(height: 8),
                    calcRow('총 이자', _manwon(_totalInterest), ink, sub),
                    const SizedBox(height: 8),
                    Text('* 원리금균등 기준. 특례금리는 소득·자녀 수에 따라 차등 적용됩니다.'.keepWords,
                        style: AppTheme.sans(AppTheme.tsXS, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            // 출처: 주택도시기금 포털(myhome.go.kr) 신생아 특례 디딤돌·버팀목 대출 공식 안내.
            // 소득·순자산 기준, 금리, 한도 전부 2026-09-15 조회 기준 확인 완료(일치).
            // 순자산 기준액은 매년 갱신되는 수치(통계청 가계금융복지조사 3분위 평균 기반)로,
            // "2026년도 기준"이라는 페이지 표기 그대로임 — 연도가 바뀌면 재확인 필요.
            calcInfoBox(
              '지원 대상',
              [
                // myhome.go.kr: "'23.1.1. 이후 출생아부터 적용", "대출신청일 기준 2년 내 출산(입양)"
                '대출접수일 기준 2년 내 출산·입양한 무주택 세대주 (2023.1.1 이후 출생아)',
                // myhome.go.kr 디딤돌·버팀목 공통: 부부합산 1.3억 이하(맞벌이 2억 이하)
                '부부합산 연소득 1.3억원 이하, 맞벌이는 2억원 이하',
                // myhome.go.kr: 순자산 "2026년도 기준" 디딤돌 5.11억원 / 버팀목 3.45억원
                '순자산: 구입 5.11억원 · 전세 3.45억원 이하',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            calcInfoBox(
              '특례 혜택',
              [
                // myhome.go.kr 디딤돌: 금리 1.8~4.5%, 한도 4억원, 주택 9억·전용 85㎡ 이하
                '구입자금(디딤돌): 연 1.8~4.5%, 최대 4억원 (주택 9억·전용 85㎡ 이하)',
                // myhome.go.kr 버팀목: 금리 1.30~4.30%, 한도 2.4억원, 보증금 수도권 5억·그 외 4억
                '전세자금(버팀목): 연 1.3~4.3%, 최대 2.4억원 (보증금 수도권 5억·그 밖 4억)',
                // myhome.go.kr: 디딤돌 기본 5년(자녀 1명당 5년 연장, 최장 15년),
                // 버팀목 기본 4년(자녀 1명당 4년 연장, 최장 12년)
                '특례금리 구입 5년(최장 15년)·전세 4년, 추가 출산 1명당 연장',
              ],
              line,
              sub,
              ink,
            ),
          ],
        ),
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
        Text(label, style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
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
          style: AppTheme.sans(AppTheme.tsMD, ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTheme.sans(AppTheme.tsMD, sub),
            suffixText: suffix,
            suffixStyle: AppTheme.sans(AppTheme.tsMD, sub),
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

}
