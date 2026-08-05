import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class RetirementPensionScreen extends StatefulWidget {
  const RetirementPensionScreen({super.key});

  @override
  State<RetirementPensionScreen> createState() =>
      _RetirementPensionScreenState();
}

class _RetirementPensionScreenState extends State<RetirementPensionScreen> {
  final _wageCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _fmt = NumberFormat('#,###');

  double get _wage => saneInput(
      double.tryParse(_wageCtrl.text.replaceAll(',', '')) ?? 0, InputMax.money);
  double get _years => saneInput(
      double.tryParse(_yearsCtrl.text.replaceAll(',', '')) ?? 0, InputMax.years);

  // DB형(확정급여): 퇴직 시점 월평균임금 × 근속연수
  double get _db => _wage * _years;

  // DC형(확정기여): 매년 임금총액의 1/12(≈월평균임금) 적립 + 연 3% 운용 추정
  // 적립 원금은 DB와 동일, 운용수익은 평균 잔존기간(근속/2) 기준 단리 추정
  double get _dcPrincipal => _wage * _years;
  double get _dcReturn => _dcPrincipal * 0.03 * (_years / 2);
  double get _dc => _dcPrincipal + _dcReturn;

  bool get _hasInput => _wage > 0 && _years > 0;

  String _manwon(double v) {
    if (v <= 0) return '-';
    return '약 ${_fmt.format((v / 10000).round())}만원';
  }

  @override
  void dispose() {
    _wageCtrl.dispose();
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
        title: Text('퇴직연금',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _inputField('퇴직 전 월평균임금', _wageCtrl, '3,500,000', '원', ink, sub, line),
            const SizedBox(height: 16),
            _inputField('근속연수', _yearsCtrl, '10', '년', ink, sub, line),
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
                    Text('예상 퇴직급여',
                        style:
                            AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _row('DB형 (확정급여)', _manwon(_db), ink, sub),
                    const SizedBox(height: 8),
                    _row('DC형 원금', _manwon(_dcPrincipal), ink, sub),
                    const SizedBox(height: 8),
                    _row('DC형 운용수익 (연 3% 추정)', _manwon(_dcReturn), ink, sub),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DC형 예상 합계',
                            style: AppTheme.sans(14, ink,
                                weight: FontWeight.w700)),
                        Text(_manwon(_dc),
                            style: AppTheme.sans(16, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('* DB형은 퇴직 시점 임금 기준 확정. DC형은 운용 실적에 따라 달라집니다.'.keepWords,
                        style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '유형별 특징',
              [
                'DB형 — 회사가 운용, 퇴직 시 확정급여 지급 (임금상승률↑ 유리)',
                'DC형 — 근로자가 직접 운용, 매년 임금총액 1/12 이상 적립',
                'IRP — 퇴직급여 수령 계좌, 추가납입 시 연 900만 세액공제',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '세금',
              [
                '퇴직소득세: 근속연수공제 후 연분연승법으로 저율 과세',
                'IRP로 이전해 연금 수령 시 퇴직소득세 30~40% 감면',
                '연금 외 일시금 수령 시 퇴직소득세 전액 과세',
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
