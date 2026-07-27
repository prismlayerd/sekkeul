import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

class LoanInterestScreen extends StatefulWidget {
  const LoanInterestScreen({super.key});

  @override
  State<LoanInterestScreen> createState() => _LoanInterestScreenState();
}

class _LoanInterestScreenState extends State<LoanInterestScreen> {
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '4.5');
  final _yearsCtrl = TextEditingController(text: '20');
  int _method = 0; // 0=원리금균등, 1=원금균등, 2=만기일시
  final _fmt = NumberFormat('#,###');

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _principalCtrl.clear();
        _rateCtrl.text = '4.5';
        _yearsCtrl.text = '20';
        _method = 0;
      });

  int get _principal => int.tryParse(_principalCtrl.text.replaceAll(',', '')) ?? 0;
  double get _rate => double.tryParse(_rateCtrl.text.replaceAll(',', '')) ?? 0;
  int get _years => int.tryParse(_yearsCtrl.text.replaceAll(',', '')) ?? 0;

  ({int monthlyPayment, int totalPayment, int totalInterest})? get _result {
    if (_principal <= 0 || _rate <= 0 || _years <= 0) return null;
    final p = _principal.toDouble();
    final r = _rate / 100 / 12;
    final n = _years * 12;
    int monthly = 0;
    int total = 0;
    int interest = 0;
    switch (_method) {
      case 0: // 원리금균등
        final payment = p * r * _pow(1 + r, n) / (_pow(1 + r, n) - 1);
        monthly = payment.round();
        total = monthly * n;
        interest = total - _principal;
      case 1: // 원금균등 (첫달 기준 표시)
        final principalPayment = (p / n).round();
        final firstInterest = (p * r).round();
        monthly = principalPayment + firstInterest;
        double totalInterestD = 0;
        double balance = p;
        for (int i = 0; i < n; i++) {
          totalInterestD += balance * r;
          balance -= p / n;
        }
        interest = totalInterestD.round();
        total = _principal + interest;
      case 2: // 만기일시
        monthly = (p * r).round();
        interest = monthly * n;
        total = interest + _principal;
    }
    return (monthlyPayment: monthly, totalPayment: total, totalInterest: interest);
  }

  double _pow(double base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) result *= base;
    return result;
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
    final methods = ['원리금균등', '원금균등', '만기일시'];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        titleSpacing: 0,
        title: Text('대출이자 계산',
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
            Text('대출금액·금리·기간을 입력하면\n월 상환액과 총이자를 계산해드려요.'.keepWords,
                style: AppTheme.sans(AppTheme.tsLG, ink, height: 1.5)),
            const SizedBox(height: 24),
            Divider(height: 1, thickness: 1, color: line),
            _amountRow('대출금액', _principalCtrl, null),
            Divider(height: 1, thickness: 1, color: line),
            _numRow('연 금리', _rateCtrl, '%', '연이율 기준'),
            Divider(height: 1, thickness: 1, color: line),
            _numRow('대출기간', _yearsCtrl, '년', null),
            Divider(height: 1, thickness: 1, color: line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('상환방식', style: AppTheme.sans(AppTheme.tsBase, ink)),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(methods.length, (i) {
                      final sel = _method == i;
                      return Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _method = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? accent : Colors.transparent,
                              border: Border.all(color: sel ? accent : line),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(methods[i],
                                style: AppTheme.sans(AppTheme.tsMD,
                                    sel ? Colors.white : sub,
                                    weight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: line),
            const SizedBox(height: 24),
            if (r == null)
              _emptyCard(accentSoft, sub, '대출금액·금리·기간을 입력하세요.')
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: accentSoft, borderRadius: BorderRadius.circular(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_method == 2 ? '월 이자' : '월 상환액',
                        style: AppTheme.sans(AppTheme.tsMD, sub)),
                    const SizedBox(height: 6),
                    Text('${_fmt.format(r.monthlyPayment)}원',
                        style: AppTheme.serif(AppTheme.serifLG, accent,
                            weight: FontWeight.w400)),
                    if (_method == 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('첫 달 기준, 이후 감소',
                            style: AppTheme.sans(AppTheme.tsSM, sub)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(4)),
                child: Column(children: [
                  _resultRow('총 상환액',
                      '${_fmt.format(r.totalPayment)}원', ink, sub, line),
                  _resultRow('총 이자',
                      '${_fmt.format(r.totalInterest)}원', ink, sub, line),
                  _resultRow(
                      '이자 비율',
                      '${(r.totalInterest / r.totalPayment * 100).toStringAsFixed(1)}%',
                      ink, sub, line,
                      last: true),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            _notice(sub, ink, const [
              '원리금균등: 매월 동일 금액 납부 (원금+이자).',
              '원금균등: 매월 동일 원금 + 잔금에 따른 이자 (첫달 납입액이 최고).',
              '만기일시: 매월 이자만 납부, 만기에 원금 전액 상환.',
              '월 납입액은 반올림 기준이며 실제 약정과 다를 수 있어요.',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(String label, TextEditingController ctrl, String? hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTheme.sans(
                        AppTheme.tsBase, AppTheme.ink(context))),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(hint,
                      style: AppTheme.sans(
                          AppTheme.tsSM, AppTheme.inkSecondary(context))),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          AmountField(
              controller: ctrl, onChanged: (_) => setState(() {})),
        ],
      ),
    );
  }

  Widget _numRow(String label, TextEditingController ctrl, String suffix,
      String? hint) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.sans(AppTheme.tsBase, ink)),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(hint, style: AppTheme.sans(AppTheme.tsSM, sub)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
        ],
      ),
    );
  }

  Widget _emptyCard(Color bg, Color sub, String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(msg, style: AppTheme.sans(AppTheme.tsMD, sub)),
      );

  Widget _resultRow(String label, String value, Color ink, Color sub,
      Color line, {bool last = false}) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.sans(AppTheme.tsBase, sub)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: AppTheme.sans(AppTheme.tsBase, ink,
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
                      style:
                          AppTheme.sans(AppTheme.tsSM, sub, height: 1.55)),
                )),
          ],
        ),
      );
}
