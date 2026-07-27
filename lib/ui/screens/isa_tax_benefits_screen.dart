import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

class IsaTaxBenefitsScreen extends StatefulWidget {
  const IsaTaxBenefitsScreen({super.key});

  @override
  State<IsaTaxBenefitsScreen> createState() => _IsaTaxBenefitsScreenState();
}

class _IsaTaxBenefitsScreenState extends State<IsaTaxBenefitsScreen> {
  final _depositCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '5.0');
  final _yearsCtrl = TextEditingController(text: '5');
  int _type = 0; // 0=일반, 1=서민·농어민
  final _fmt = NumberFormat('#,###');

  @override
  void dispose() {
    _depositCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _depositCtrl.clear();
        _rateCtrl.text = '5.0';
        _yearsCtrl.text = '5';
        _type = 0;
      });

  int get _deposit => int.tryParse(_depositCtrl.text.replaceAll(',', '')) ?? 0;
  double get _rate => double.tryParse(_rateCtrl.text.replaceAll(',', '')) ?? 0;
  int get _years => int.tryParse(_yearsCtrl.text.replaceAll(',', '')) ?? 0;

  ({
    int totalDeposit,
    int totalInterest,
    int taxFreeLimit,
    int isaAfterTax,
    int normalAfterTax,
    int taxSaving,
  })? get _result {
    if (_deposit <= 0 || _rate <= 0 || _years <= 0 || _years > 20) return null;
    final r = _rate / 100;
    final n = _years;
    final d = _deposit.toDouble();

    // 연간 납입 복리 (매년 초 납입 기준 연금형)
    final totalValue = d * ((1 - _pow(1 + r, n)) / (-r)) * (1 + r);
    final totalDeposit = _deposit * n;
    final totalInterest = totalValue - totalDeposit;

    final taxFreeLimit = _type == 0 ? 2000000.0 : 4000000.0;
    final taxableInterest =
        totalInterest > taxFreeLimit ? totalInterest - taxFreeLimit : 0.0;

    final isaAfterTax = totalInterest - taxableInterest * 0.099;
    final normalAfterTax = totalInterest * (1 - 0.154);
    final taxSaving = isaAfterTax - normalAfterTax;

    return (
      totalDeposit: totalDeposit,
      totalInterest: totalInterest.round(),
      taxFreeLimit: taxFreeLimit.round(),
      isaAfterTax: isaAfterTax.round(),
      normalAfterTax: normalAfterTax.round(),
      taxSaving: taxSaving.round(),
    );
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
    final types = ['일반형', '서민·농어민형'];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        titleSpacing: 0,
        title: Text('ISA 절세 계산',
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
            Text('ISA 납입액·기간·수익률을 입력하면\n일반계좌 대비 절세 효과를 계산해드려요.'.keepWords,
                style: AppTheme.sans(AppTheme.tsLG, ink, height: 1.5)),
            const SizedBox(height: 24),
            Divider(height: 1, thickness: 1, color: line),
            _amountRow('연간 납입액', _depositCtrl),
            Divider(height: 1, thickness: 1, color: line),
            _numRow('기대 연수익률', _rateCtrl, '%'),
            Divider(height: 1, thickness: 1, color: line),
            _numRow('납입 기간', _yearsCtrl, '년'),
            Divider(height: 1, thickness: 1, color: line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('가입 유형', style: AppTheme.sans(AppTheme.tsBase, ink)),
                  const SizedBox(height: 4),
                  Text('서민·농어민형은 비과세 한도 400만원 (일반형: 200만원)'.keepWords,
                      style: AppTheme.sans(AppTheme.tsSM, sub)),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(types.length, (i) {
                      final sel = _type == i;
                      return Padding(
                        padding: EdgeInsets.only(right: i == 0 ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _type = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? accent : Colors.transparent,
                              border: Border.all(color: sel ? accent : line),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(types[i],
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: accentSoft, borderRadius: BorderRadius.circular(4)),
                child: Text('납입액·수익률·기간을 입력하세요.'.keepWords,
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
                    Text('절세 효과', style: AppTheme.sans(AppTheme.tsMD, sub)),
                    const SizedBox(height: 6),
                    Text('+${_fmt.format(r.taxSaving)}원',
                        style: AppTheme.serif(AppTheme.serifLG, accent,
                            weight: FontWeight.w400)),
                    const SizedBox(height: 4),
                    Text('일반계좌 대비 세금 절약',
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
                  _resultRow('총 납입액', '${_fmt.format(r.totalDeposit)}원',
                      ink, sub, line),
                  _resultRow('총 이자 수익', '${_fmt.format(r.totalInterest)}원',
                      ink, sub, line),
                  _resultRow(
                      '비과세 한도',
                      '${_fmt.format(r.taxFreeLimit)}원 (${_type == 0 ? '일반형' : '서민·농어민형'})',
                      ink, sub, line),
                  _resultRow('ISA 세후 이자', '${_fmt.format(r.isaAfterTax)}원',
                      ink, sub, line),
                  _resultRow('일반계좌 세후 이자',
                      '${_fmt.format(r.normalAfterTax)}원', ink, sub, line),
                  _resultRow('절세액', '+${_fmt.format(r.taxSaving)}원',
                      accent, sub, line, last: true),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            _notice(sub, ink, const [
              'ISA는 1인 1계좌, 연간 납입 한도 2,000만원 (총 한도 1억원).',
              '비과세 한도 초과분은 분리과세 9.9% (지방세 포함) 적용.',
              '일반계좌 이자소득세 15.4% (지방세 포함)와 비교한 수치예요.',
              '서민·농어민형: 직전 과세기간 근로·사업소득 3,800만원 이하.',
              '수익률과 실제 투자 결과는 다를 수 있으며, 참고용으로만 활용하세요.',
            ]),
            const CalcDisclaimer(),
          ],
        ),
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
            Text(label, style: AppTheme.sans(AppTheme.tsBase, sub)),
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
