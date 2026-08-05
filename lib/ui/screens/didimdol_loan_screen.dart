import 'package:flutter/material.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

class DidimdolLoanScreen extends StatefulWidget {
  const DidimdolLoanScreen({super.key});

  @override
  State<DidimdolLoanScreen> createState() => _DidimdolLoanScreenState();
}

class _DidimdolLoanScreenState extends State<DidimdolLoanScreen> {
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '2.55');
  final _yearsCtrl = TextEditingController(text: '30');

  /// 주택도시기금이 공시하는 금리 **범위**만 적는다.
  ///
  /// 소득·만기별 세부 표는 기금 공지로 수시(때로는 월 단위) 바뀐다. 앱에 박아
  /// 두면 반드시 낡는데(종전 표는 2024년 값이라 1%p 가까이 낮았다), 정작 이
  /// 화면의 계산은 사용자가 넣은 금리로 한다. 그래서 범위 + 출처만 남긴다.
  ///
  /// 출처: 주택도시기금 「내집마련 디딤돌대출」 상품 안내 — 확인일 2026-07-28.
  static const _rateRange = '연 2.85% ~ 연 4.15%';
  static const _rateSource = '주택도시기금 공시 (2026-07-28 확인)';

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _principalCtrl.clear();
        _rateCtrl.text = '2.55';
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
        titleSpacing: 0,
        title: Text('디딤돌 대출 계산',
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
            Text('내 집 마련 구입자금 대출 (디딤돌)의\n월 상환액과 총이자를 계산해드려요.'.keepWords,
                style: AppTheme.sans(AppTheme.tsLG, ink, height: 1.5)),
            const SizedBox(height: 4),
            Text('원리금균등 방식. 연 소득에 따라 금리를 직접 입력하세요.'.keepWords,
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
                    Text('${comma(r.monthly)}원',
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
                  _resultRow('총 이자', '${comma(r.totalInterest)}원',
                      accent, sub, line),
                  _resultRow('총 상환액', '${comma(r.totalPayment)}원',
                      ink, sub, line, last: true),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            _notice(sub, ink, const [
              '디딤돌 대출: 무주택 세대주 대상 주택 구입 자금 (LTV 70%, 생애최초 80%).',
              '부부 합산 연 소득 8,500만원 이하 (생애최초·2자녀 이상 완화 가능).',
              '주택 기준시가 5억원 이하 (단, 수도권·지방 차이 있음).',
              '실제 금리는 우대 조건(신혼·첫째출산 등)에 따라 달라질 수 있어요.',
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
            child: Text('금리 범위'.keepWords,
                style: AppTheme.sans(AppTheme.tsSM, sub, weight: FontWeight.w600)),
          ),
          Divider(height: 1, thickness: 1, color: line),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_rateRange,
                  style: AppTheme.sans(AppTheme.tsBase, ink, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('소득·만기·우대 조건에 따라 이 안에서 정해져요. 내 금리는 기금e든든에서 확인하고 위에 넣어주세요.'.keepWords,
                  style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.45)),
              const SizedBox(height: 6),
              Text(_rateSource, style: AppTheme.sans(AppTheme.tsXS, sub)),
            ]),
          ),
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
