import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

class LoanScheduleScreen extends StatefulWidget {
  const LoanScheduleScreen({super.key});

  @override
  State<LoanScheduleScreen> createState() => _LoanScheduleScreenState();
}

class _LoanScheduleScreenState extends State<LoanScheduleScreen> {
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '4.5');
  final _monthsCtrl = TextEditingController(text: '240');
  int _method = 0; // 0=원리금균등, 1=원금균등
  bool _showAll = false;
  final _fmt = NumberFormat('#,###');

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _monthsCtrl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _principalCtrl.clear();
        _rateCtrl.text = '4.5';
        _monthsCtrl.text = '240';
        _method = 0;
        _showAll = false;
      });

  int get _principal => int.tryParse(_principalCtrl.text.replaceAll(',', '')) ?? 0;
  double get _rate => double.tryParse(_rateCtrl.text.replaceAll(',', '')) ?? 0;
  int get _months => int.tryParse(_monthsCtrl.text.replaceAll(',', '')) ?? 0;

  List<({int month, int principal, int interest, int payment, int balance})>
      _buildSchedule() {
    if (_principal <= 0 || _rate <= 0 || _months <= 0 || _months > 480) {
      return [];
    }
    final p = _principal.toDouble();
    final r = _rate / 100 / 12;
    final n = _months;
    final rows = <({int month, int principal, int interest, int payment, int balance})>[];

    if (_method == 0) {
      double pow1 = 1.0;
      for (int i = 0; i < n; i++) pow1 *= (1 + r);
      final pmt = p * r * pow1 / (pow1 - 1);
      double balance = p;
      for (int m = 1; m <= n && balance > 0.5; m++) {
        final interest = balance * r;
        final principal = pmt - interest;
        balance -= principal;
        rows.add((
          month: m,
          principal: principal.round(),
          interest: interest.round(),
          payment: pmt.round(),
          balance: balance < 0 ? 0 : balance.round(),
        ));
      }
    } else {
      final principalPmt = p / n;
      double balance = p;
      for (int m = 1; m <= n && balance > 0.5; m++) {
        final interest = balance * r;
        balance -= principalPmt;
        rows.add((
          month: m,
          principal: principalPmt.round(),
          interest: interest.round(),
          payment: (principalPmt + interest).round(),
          balance: balance < 0 ? 0 : balance.round(),
        ));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    final accentSoft = AppTheme.accentSoft(context);
    final methods = ['원리금균등', '원금균등'];

    final schedule = _buildSchedule();
    final displayRows = _showAll ? schedule : schedule.take(12).toList();
    final totalInterest = schedule.fold<int>(0, (s, r) => s + r.interest);
    final totalPayment = schedule.fold<int>(0, (s, r) => s + r.payment);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: Text('대출 상환 스케줄',
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
            Text('대출 조건을 입력하면\n월별 상환 스케줄을 보여드려요.'.keepWords,
                style: AppTheme.sans(AppTheme.tsLG, ink, height: 1.5)),
            const SizedBox(height: 24),
            Divider(height: 1, thickness: 1, color: line),
            _amountRow('대출금액', _principalCtrl),
            Divider(height: 1, thickness: 1, color: line),
            _numRow('연 금리', _rateCtrl, '%'),
            Divider(height: 1, thickness: 1, color: line),
            _numRow('대출기간', _monthsCtrl, '개월'),
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
                        padding: EdgeInsets.only(right: i == 0 ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _method = i;
                            _showAll = false;
                          }),
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
            if (schedule.isEmpty)
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
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('총 이자', style: AppTheme.sans(AppTheme.tsSM, sub)),
                        const SizedBox(height: 4),
                        Text('${_fmt.format(totalInterest)}원',
                            style: AppTheme.sans(AppTheme.tsLG, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('총 상환액', style: AppTheme.sans(AppTheme.tsSM, sub)),
                        const SizedBox(height: 4),
                        Text('${_fmt.format(totalPayment)}원',
                            style: AppTheme.sans(AppTheme.tsLG, ink,
                                weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(4)),
                child: Column(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: sub.withValues(alpha: 0.06),
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(3),
                            topRight: Radius.circular(3))),
                    child: Row(children: [
                      SizedBox(
                          width: 36,
                          child: Text('회차',
                              style: AppTheme.sans(AppTheme.tsXS, sub,
                                  weight: FontWeight.w600))),
                      Expanded(
                          child: Text('원금',
                              textAlign: TextAlign.right,
                              style: AppTheme.sans(AppTheme.tsXS, sub,
                                  weight: FontWeight.w600))),
                      Expanded(
                          child: Text('이자',
                              textAlign: TextAlign.right,
                              style: AppTheme.sans(AppTheme.tsXS, sub,
                                  weight: FontWeight.w600))),
                      Expanded(
                          child: Text('납입액',
                              textAlign: TextAlign.right,
                              style: AppTheme.sans(AppTheme.tsXS, sub,
                                  weight: FontWeight.w600))),
                      Expanded(
                          child: Text('잔금',
                              textAlign: TextAlign.right,
                              style: AppTheme.sans(AppTheme.tsXS, sub,
                                  weight: FontWeight.w600))),
                    ]),
                  ),
                  Divider(height: 1, thickness: 1, color: line),
                  ...displayRows.map((row) => Column(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(children: [
                            SizedBox(
                                width: 36,
                                child: Text('${row.month}',
                                    style: AppTheme.sans(AppTheme.tsSM, sub))),
                            Expanded(
                                child: Text(_fmt.format(row.principal),
                                    textAlign: TextAlign.right,
                                    style: AppTheme.sans(AppTheme.tsSM, ink))),
                            Expanded(
                                child: Text(_fmt.format(row.interest),
                                    textAlign: TextAlign.right,
                                    style: AppTheme.sans(AppTheme.tsSM,
                                        accent.withValues(alpha: 0.7)))),
                            Expanded(
                                child: Text(_fmt.format(row.payment),
                                    textAlign: TextAlign.right,
                                    style: AppTheme.sans(AppTheme.tsSM, ink,
                                        weight: FontWeight.w600))),
                            Expanded(
                                child: Text(_fmt.format(row.balance),
                                    textAlign: TextAlign.right,
                                    style: AppTheme.sans(AppTheme.tsSM, sub))),
                          ]),
                        ),
                        if (row.month < displayRows.last.month ||
                            (!_showAll && schedule.length > 12))
                          Divider(
                              height: 1,
                              thickness: 1,
                              color: line,
                              indent: 12),
                      ])),
                  if (!_showAll && schedule.length > 12)
                    GestureDetector(
                      onTap: () => setState(() => _showAll = true),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text('전체 ${schedule.length}개월 보기'.keepWords,
                              style: AppTheme.sans(AppTheme.tsMD, accent,
                                  weight: FontWeight.w600)),
                        ),
                      ),
                    ),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            _notice(sub, ink, const [
              '원리금균등: 매달 동일한 금액 납부 (초반에 이자 비중이 높아요).',
              '원금균등: 매달 동일한 원금 + 잔금에 따른 이자 (총이자가 적어요).',
              '실제 약정 조건(중도상환·연장 등)은 반영되지 않았습니다.',
            ]),
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
          AmountField(
              controller: ctrl,
              onChanged: (_) => setState(() => _showAll = false)),
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
            onChanged: (_) => setState(() => _showAll = false),
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
