import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

class BogeumjariLoanScreen extends StatefulWidget {
  const BogeumjariLoanScreen({super.key});

  @override
  State<BogeumjariLoanScreen> createState() => _BogeumjariLoanScreenState();
}

class _BogeumjariLoanScreenState extends State<BogeumjariLoanScreen> {
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '4.25');
  final _yearsCtrl = TextEditingController(text: '30');
  final _fmt = NumberFormat('#,###');

  static const _rates = [
    ('기본 금리', '4.00~4.50%'),
    ('전자약정·MyHome 앱', '-0.10%p'),
    ('신혼부부 (혼인 7년 이내)', '-0.20%p'),
    ('다자녀 (2자녀 이상)', '-0.40%p (3자녀 -0.50%p)'),
    ('저소득 청년 (만 39세 이하)', '-0.10%p'),
    ('장애인·다문화·한부모', '-0.40%p'),
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
        _rateCtrl.text = '4.25';
        _yearsCtrl.text = '30';
      });

  int get _principal => int.tryParse(_principalCtrl.text.replaceAll(',', '')) ?? 0;
  double get _rate => double.tryParse(_rateCtrl.text.replaceAll(',', '')) ?? 0;
  int get _years => int.tryParse(_yearsCtrl.text.replaceAll(',', '')) ?? 0;

  ({int monthly, int totalInterest, int totalPayment})? get _result {
    if (_principal <= 0 || _rate <= 0 || _years <= 0 || _years > 50) return null;
    final p = _principal.toDouble();
    final r = _rate / 100 / 12;
    final n = _years * 12;
    double pow1 = 1.0;
    for (int i = 0; i < n; i++) pow1 *= (1 + r);
    final monthly = p * r * pow1 / (pow1 - 1);
    final totalPayment = monthly * n;
    return (
      monthly: monthly.round(),
      totalInterest: (totalPayment - _principal).round(),
      totalPayment: totalPayment.round(),
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
        title: Text('보금자리론 계산',
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
            Text('보금자리론(HF)의\n월 상환액과 총이자를 계산해드려요.'.keepWords,
                style: AppTheme.sans(AppTheme.tsLG, ink, height: 1.5)),
            const SizedBox(height: 4),
            Text('원리금균등 방식. 우대금리 적용 후 금리를 직접 입력하세요.'.keepWords,
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
                    Text('월 상환액', style: AppTheme.sans(AppTheme.tsMD, sub)),
                    const SizedBox(height: 6),
                    Text('${_fmt.format(r.monthly)}원',
                        style: AppTheme.serif(AppTheme.serifLG, accent,
                            weight: FontWeight.w400)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(4)),
                child: Column(children: [
                  _resultRow('총 이자', '${_fmt.format(r.totalInterest)}원',
                      accent, sub, line),
                  _resultRow('총 상환액', '${_fmt.format(r.totalPayment)}원',
                      ink, sub, line, last: true),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            _notice(sub, ink, const [
              '보금자리론: 부부합산 연 소득 7,000만원 이하(신혼 8,500만·다자녀 1억) 대상.',
              '주택가격 6억원 이하(우대형 9억원 이하), 대출한도 최대 3.6억원.',
              'LTV 일반 70% · 생애최초 80%, 만기 10/15/20/30년 선택.',
              '3년 경과 후 중도상환수수료 면제, 3년 내에도 원금 10% 이내 무료 상환.',
              '디딤돌 대출보다 소득·주택가격 기준이 넓지만 금리는 더 높습니다.',
              '정확한 조건은 한국주택금융공사(hf.go.kr) 또는 취급 은행에서 확인하세요.',
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
            child: Text('2026년 기준 금리·우대금리'.keepWords,
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
                              style: AppTheme.sans(AppTheme.tsSM, sub))),
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
