import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

class MonthlyRentTaxCreditScreen extends StatefulWidget {
  const MonthlyRentTaxCreditScreen({super.key});

  @override
  State<MonthlyRentTaxCreditScreen> createState() =>
      _MonthlyRentTaxCreditScreenState();
}

class _MonthlyRentTaxCreditScreenState
    extends State<MonthlyRentTaxCreditScreen> {
  final _salaryCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();
  final _fmt = NumberFormat('#,###');

  @override
  void dispose() {
    _salaryCtrl.dispose();
    _rentCtrl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _salaryCtrl.clear();
        _rentCtrl.clear();
      });

  int get _salary => int.tryParse(_salaryCtrl.text.replaceAll(',', '')) ?? 0;
  int get _rent => int.tryParse(_rentCtrl.text.replaceAll(',', '')) ?? 0;

  ({bool eligible, int annualRent, int cappedRent, double rate, int credit})?
      get _result {
    if (_salary <= 0 || _rent <= 0) return null;
    if (_salary > 80000000) return (eligible: false, annualRent: 0, cappedRent: 0, rate: 0, credit: 0);
    final annualRent = _rent * 12;
    final cappedRent = annualRent.clamp(0, 10000000);
    final rate = _salary <= 55000000 ? 0.17 : 0.12;
    final credit = (cappedRent * rate).round();
    return (eligible: true, annualRent: annualRent, cappedRent: cappedRent, rate: rate, credit: credit);
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
        title: Text('월세 세액공제',
            style: AppTheme.serif(AppTheme.serifMD, ink,
                weight: FontWeight.w400, spacing: -0.5)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 20, color: tert),
            onPressed: _reset,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('연 급여와 월세를 입력하면\n공제 가능 금액을 알려드려요.'.keepWords,
                style: AppTheme.sans(AppTheme.tsLG, ink, height: 1.5)),
            const SizedBox(height: 4),
            Text('2024 귀속 기준. 무주택 세대주·세대원 대상.'.keepWords,
                style: AppTheme.sans(AppTheme.tsSM, tert)),
            const SizedBox(height: 24),
            Divider(height: 1, thickness: 1, color: line),
            _inputRow('연 총급여', _salaryCtrl, '실근로소득 (비과세 제외)'),
            Divider(height: 1, thickness: 1, color: line),
            _inputRow('월 월세액', _rentCtrl, '실제 납부 중인 월 임차료'),
            Divider(height: 1, thickness: 1, color: line),
            const SizedBox(height: 24),
            if (r == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('연 급여와 월세를 입력하면 결과가 나와요.'.keepWords,
                    style: AppTheme.sans(AppTheme.tsMD, sub)),
              )
            else if (!r.eligible)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.colorDanger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: AppTheme.colorDanger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('총급여 8,000만원 초과 시 월세 세액공제 대상이 아니에요.'.keepWords,
                        style: AppTheme.sans(AppTheme.tsMD, AppTheme.colorDanger)),
                  ),
                ]),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('세액공제 예상액',
                        style: AppTheme.sans(AppTheme.tsMD, sub)),
                    const SizedBox(height: 6),
                    Text('${_fmt.format(r.credit)}원',
                        style: AppTheme.serif(AppTheme.serifLG, accent,
                            weight: FontWeight.w400)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    _resultRow('연간 월세 납부액', '${_fmt.format(r.annualRent)}원',
                        ink, sub, line),
                    _resultRow(
                        '공제 적용 월세',
                        '${_fmt.format(r.cappedRent)}원 (한도 1,000만원)',
                        ink, sub, line),
                    _resultRow(
                        '공제율',
                        '${(r.rate * 100).toStringAsFixed(0)}%'
                            '${_salary <= 55000000 ? ' (5,500만원 이하)' : ' (5,500만원 초과)'}',
                        ink, sub, line),
                    _resultRow('세액공제액', '${_fmt.format(r.credit)}원',
                        ink, sub, line, last: true),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _notice(sub, ink, const [
              '무주택 세대주·세대원(배우자 포함)에 한해 적용됩니다.',
              '국민주택규모(85㎡) 이하 또는 기준시가 4억원 이하 주택에만 해당돼요.',
              '임대차계약서상 주소지와 주민등록 주소지가 동일해야 합니다.',
              '총급여 5,500만원 이하 → 17%, 초과(~8,000만원) → 12% 공제.',
              '이 계산기는 참고용이며 정확한 공제액은 세무사에게 확인하세요.',
            ]),
            const CalcDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _inputRow(String label, TextEditingController ctrl, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.sans(AppTheme.tsBase, AppTheme.ink(context))),
                const SizedBox(height: 2),
                Text(hint, style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkSecondary(context))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AmountField(controller: ctrl, onChanged: (_) => setState(() {})),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, Color ink, Color sub,
      Color line, {bool last = false}) {
    return Column(
      children: [
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
      ],
    );
  }

  Widget _notice(Color sub, Color ink, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sub.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: sub),
            const SizedBox(width: 6),
            Text('알아두기',
                style: AppTheme.sans(AppTheme.tsMD, ink, weight: FontWeight.w600)),
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
}
