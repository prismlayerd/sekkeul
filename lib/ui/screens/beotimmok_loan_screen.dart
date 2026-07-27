import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

class BeotimmokLoanScreen extends StatefulWidget {
  const BeotimmokLoanScreen({super.key});

  @override
  State<BeotimmokLoanScreen> createState() => _BeotimmokLoanScreenState();
}

class _BeotimmokLoanScreenState extends State<BeotimmokLoanScreen> {
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '2.10');
  final _yearsCtrl = TextEditingController(text: '2');
  final _fmt = NumberFormat('#,###');

  static const _rates = [
    ('부부 합산 연 소득 5천만원 이하', '1.2% ~ 2.1%'),
    ('부부 합산 연 소득 6천만원 이하', '2.1% ~ 2.9%'),
    ('청년 단독세대주 (만 19~34세)', '1.3% ~ 2.1%'),
  ];

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _principalCtrl.clear();
        _rateCtrl.text = '2.10';
        _yearsCtrl.text = '2';
      });

  int get _principal => int.tryParse(_principalCtrl.text.replaceAll(',', '')) ?? 0;
  double get _rate => double.tryParse(_rateCtrl.text.replaceAll(',', '')) ?? 0;
  int get _years => int.tryParse(_yearsCtrl.text.replaceAll(',', '')) ?? 0;

  ({int monthlyInterest, int totalInterest})? get _result {
    if (_principal <= 0 || _rate <= 0 || _years <= 0 || _years > 10) return null;
    final r = _rate / 100 / 12;
    final n = _years * 12;
    final monthly = (_principal * r).round();
    return (
      monthlyInterest: monthly,
      totalInterest: monthly * n,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    final accentSoft = AppTheme.accentSoft(context);
    final r = _result;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        titleSpacing: 0,
        title: Text('버팀목 대출 계산',
            style: AppTheme.serif(AppTheme.serifMD, ink,
                weight: FontWeight.w400, spacing: -0.5)),
        actions: [
          IconButton(
              icon: Icon(Icons.refresh_rounded, size: 20, color: tert),
              onPressed: _reset),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('전세자금 대출 (버팀목)의\n월 이자와 총 이자를 계산해드려요.'.keepWords,
                style: AppTheme.sans(AppTheme.tsLG, ink, height: 1.5)),
            const SizedBox(height: 4),
            Text('만기일시 방식 (매달 이자만, 만기에 원금 전액 상환).'.keepWords,
                style: AppTheme.sans(AppTheme.tsSM, tert)),
            const SizedBox(height: 16),
            _rateTable(sub, ink, line),
            const SizedBox(height: 16),
            Divider(height: 1, thickness: 1, color: line),
            _amountRow('대출금액', _principalCtrl),
            Divider(height: 1, thickness: 1, color: line),
            _numRow('연 금리', _rateCtrl, '%'),
            Divider(height: 1, thickness: 1, color: line),
            _numRow('대출기간', _yearsCtrl, '년'),
            Divider(height: 1, thickness: 1, color: line),
            const SizedBox(height: 24),
            if (r == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: accentSoft, borderRadius: BorderRadius.circular(4)),
                child: Text('대출금액·금리·기간을 입력하세요.'.keepWords,
                    style: AppTheme.sans(AppTheme.tsMD, sub)),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: accentSoft, borderRadius: BorderRadius.circular(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('월 이자', style: AppTheme.sans(AppTheme.tsMD, sub)),
                    const SizedBox(height: 6),
                    Text('${_fmt.format(r.monthlyInterest)}원',
                        style: AppTheme.serif(AppTheme.serifLG, accent,
                            weight: FontWeight.w400)),
                    const SizedBox(height: 4),
                    Text('만기 시 원금 ${_fmt.format(_principal)}원 전액 상환'.keepWords,
                        style: AppTheme.sans(AppTheme.tsSM, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(4)),
                child: Column(children: [
                  _resultRow('월 이자', '${_fmt.format(r.monthlyInterest)}원',
                      accent, sub, line),
                  _resultRow('총 이자 (기간 합계)', '${_fmt.format(r.totalInterest)}원',
                      ink, sub, line),
                  _resultRow('만기 상환 원금', '${_fmt.format(_principal)}원',
                      ink, sub, line, last: true),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            _notice(sub, ink, const [
              '버팀목 전세자금 대출: 무주택 세대주 대상 전세 자금 (임차보증금 80% 이내).',
              '전세 보증금 수도권 3억원, 지방 2억원 이하 (청년 수도권 3억원, 지방 2억원).',
              '만기 시 원금을 전액 상환해야 하므로 자금 계획을 미리 세우세요.',
              '중간에 대출을 연장하면 이자가 계속 발생합니다.',
              '정확한 조건은 주택도시기금(nhuf.molit.go.kr) 또는 은행에서 확인하세요.',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _rateTable(Color sub, Color ink, Color line) {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: line), borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text('2024년 기준 금리 (소득·유형 구간)'.keepWords,
                style: AppTheme.sans(AppTheme.tsSM, sub, weight: FontWeight.w600)),
          ),
          Divider(height: 1, thickness: 1, color: line),
          ..._rates.asMap().entries.map((e) => Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(e.value.$1,
                            style: AppTheme.sans(AppTheme.tsSM, sub)),
                      ),
                      const SizedBox(width: 8),
                      Text(e.value.$2,
                          style: AppTheme.sans(AppTheme.tsSM, ink,
                              weight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (e.key < _rates.length - 1)
                  Divider(height: 1, thickness: 1, color: line, indent: 12),
              ])),
        ],
      ),
    );
  }

  Widget _amountRow(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: AppTheme.sans(AppTheme.tsBase, AppTheme.ink(context)))),
          const SizedBox(width: 12),
          AmountField(controller: ctrl, onChanged: (_) => setState(() {})),
        ]),
      );

  Widget _numRow(String label, TextEditingController ctrl, String suffix) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Expanded(child: Text(label, style: AppTheme.sans(AppTheme.tsBase, ink))),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            onChanged: (_) => setState(() {}),
            style: AppTheme.sans(AppTheme.tsBase, ink),
            decoration: InputDecoration(
              suffixText: suffix,
              suffixStyle: AppTheme.sans(AppTheme.tsSM, sub),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: accent, width: 1.5)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _resultRow(String label, String value, Color valueColor, Color sub,
      Color line, {bool last = false}) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(label, style: AppTheme.sans(AppTheme.tsBase, sub))),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: AppTheme.sans(AppTheme.tsBase, valueColor,
                      weight: FontWeight.w600)),
            ),
          ],
        ),
      ),
      if (!last) Divider(height: 1, thickness: 1, color: line, indent: 16),
    ]);
  }

  Widget _notice(Color sub, Color ink, List<String> items) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: sub.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: sub),
              const SizedBox(width: 6),
              Text('알아두기',
                  style: AppTheme.sans(AppTheme.tsMD, ink,
                      weight: FontWeight.w600)),
            ]),
            const SizedBox(height: 10),
            ...items.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $s',
                      style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.55)),
                )),
          ],
        ),
      );
}
