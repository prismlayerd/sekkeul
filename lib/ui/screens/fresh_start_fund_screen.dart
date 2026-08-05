import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class FreshStartFundScreen extends StatefulWidget {
  const FreshStartFundScreen({super.key});

  @override
  State<FreshStartFundScreen> createState() => _FreshStartFundScreenState();
}

class _FreshStartFundScreenState extends State<FreshStartFundScreen> {
  final _debtCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController(text: '10');
  int _statusIdx = 1; // 0=부실(저소득), 1=부실(일반), 2=부실우려, 3=정상
  final _fmt = NumberFormat('#,###');

  static const _statuses = [
    // 저소득 부실차주의 무담보 채무 감면율이 80%에서 90%로 올랐다(금융위).
    ('부실 (저소득)', 0.90),
    ('부실 (일반)', 0.70),
    ('부실우려', 0.30),
    ('정상 차주', 0.0),
  ];

  double get _debt => double.tryParse(_debtCtrl.text.replaceAll(',', '')) ?? 0;
  int get _years => int.tryParse(_yearsCtrl.text.replaceAll(',', '')) ?? 0;
  double get _rate => _statuses[_statusIdx].$2;

  double get _reduction => _debt * _rate;
  double get _afterDebt => _debt - _reduction;
  double get _monthlyPayment => _years > 0 ? _afterDebt / (_years * 12) : 0;

  bool get _hasInput => _debt > 0 && _years > 0;

  String _won(double v) => '${_fmt.format(v.round())}원';

  @override
  void dispose() {
    _debtCtrl.dispose();
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
        title: Text('새출발기금 채무조정',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('현재 상황 (차주 분류)',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(4)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _statusIdx,
                  isExpanded: true,
                  style: AppTheme.sans(14, ink),
                  dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                  items: [
                    for (int i = 0; i < _statuses.length; i++)
                      DropdownMenuItem(
                          value: i,
                          child: Text(
                              '${_statuses[i].$1} (${(_statuses[i].$2 * 100).round()}% 감면)'.keepWords)),
                  ],
                  onChanged: (v) => setState(() => _statusIdx = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('총 사업자 채무',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _debtCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: const [ThousandsFormatter()],
              style: AppTheme.sans(14, ink),
              decoration: InputDecoration(
                hintText: '50,000,000',
                hintStyle: AppTheme.sans(14, sub),
                suffixText: '원',
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
              onChanged: (v) {
                final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                final formatted =
                    digits.isEmpty ? '' : _fmt.format(int.parse(digits));
                _debtCtrl.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Text('분할 상환 기간',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _yearsCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTheme.sans(14, ink),
              decoration: InputDecoration(
                suffixText: '년 (최대 20년)',
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
                    Text('예상 월 분할상환액',
                        style:
                            AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(_won(_monthlyPayment),
                        style: AppTheme.sans(20, accent,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('원금 감면액', _won(_reduction), ink, sub),
                    const SizedBox(height: 8),
                    _row('감면 후 원금', _won(_afterDebt), ink, sub),
                    const SizedBox(height: 12),
                    Text('* 무이자 분할 가정 단순 추정치. 약정 후 연 1~3%대 이자가 붙을 수 있습니다.'.keepWords,
                        style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '대상 요건',
              [
                '코로나19 방역조치 등 피해 소상공인·자영업자, 개인사업자 및 일부 법인 대표',
                '부실 차주: 90일 이상 연체 / 부실우려 차주: 90일 미만 연체 + 폐업·매출급감 등',
                '정상 차주는 감면 없이 장기 분할(최대 20년)만 가능',
                '채무 한도: 1인당 최대 15억원(사업자 10억 + 개인 5억)',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '신청 절차',
              [
                '새출발기금 콜센터(1660-1378)·공식 사이트에서 자격 확인',
                '사업자등록증·금융거래확인서·소득증빙 제출',
                '한국자산관리공사(KAMCO) 심사 (약 30~60일)',
                '감면율·이자율·상환기간 확정 후 약정 체결',
                '매월 자동이체로 분할 상환 시작',
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
