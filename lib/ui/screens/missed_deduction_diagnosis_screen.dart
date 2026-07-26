import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../components/deduction_checklist.dart';

import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/deduction_catalog.dart';
import '../../core/parsing/correction_report.dart';
import 'tax_report_form_screen.dart';
import 'tax_simulator_screen.dart';
import 'tax_tools_screen.dart';
import '../components/tax_pipeline_rail.dart';

/// ① 진단 — "연말정산에 안 넣은 공제"를 체크리스트로 고르고 그 항목만 입력한다.
/// 놓친 환급을 추정해 보여주고, 신고서 단계로 이어가도록 초안을 저장한다.
/// (정밀 세액 계산이 필요하면 기존 시뮬레이터로 연결.)
class MissedDeductionDiagnosisScreen extends StatefulWidget {
  final String userType;
  const MissedDeductionDiagnosisScreen({super.key, required this.userType});

  @override
  State<MissedDeductionDiagnosisScreen> createState() => _MissedDeductionDiagnosisScreenState();
}

class _MissedDeductionDiagnosisScreenState extends State<MissedDeductionDiagnosisScreen> {
  final _fmt = NumberFormat('#,###');
  final _grossCtrl = TextEditingController();
  final _decidedCtrl = TextEditingController();

  Map<String, int> _amounts = {};
  Map<String, int> _initialAmounts = {};

  @override
  void initState() {
    super.initState();
    _prefillFromRecord();
  }

  @override
  void dispose() {
    _grossCtrl.dispose();
    _decidedCtrl.dispose();
    super.dispose();
  }

  int get _gross => int.tryParse(_grossCtrl.text.replaceAll(',', '')) ?? 0;
  int get _decided => int.tryParse(_decidedCtrl.text.replaceAll(',', '')) ?? 0;

  Future<void> _prefillFromRecord() async {
    final r = await dbService.getAnnualRecord(widget.userType);
    if (r == null || !mounted) return;
    setState(() {
      final gross = (r['grossSalary'] as num?)?.toInt() ?? 0;
      final decided = (r['decidedTax'] as num?)?.toInt() ?? 0;
      if (gross > 0) _grossCtrl.text = _fmt.format(gross);
      if (decided > 0) _decidedCtrl.text = _fmt.format(decided);
      _initialAmounts = amountsFromAnnualRecord(r);
      _amounts = Map.of(_initialAmounts);
    });
  }

  CorrectionReport _report() => buildCorrectionReport(
        gansoFromAmounts(_amounts),
        // 이 화면은 "5월 종합소득세 신고로 더 돌려받기"로 이어진다. 5월 확정신고는
        // 언제나 전년도 귀속분이므로 그 해 공제율로 계산한다.
        forgottenReceipt(
            accrualYear: DateTime.now().year - 1,
            grossSalary: _gross,
            decidedTax: _decided),
      );

  Future<void> _continueToForm(CorrectionReport c) async {
    await dbService.saveReportDraft(widget.userType,
        reportType: '종합소득세',
        items: [
          for (final l in c.lines)
            {'title': '${l.category} 세액공제', 'amount': l.missedCredit.toDouble()},
          {'title': '예상 환급세액', 'amount': c.additionalRefund.toDouble(), 'isHeader': true, 'highlight': true},
        ],
        finalAmount: c.additionalRefund.toDouble(),
        isRefund: true);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportFormLoader(userType: widget.userType)));
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);
    final c = _report();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TaxPipelineRail(
                labels: taxRailLabels(widget.userType),
                current: taxRailIndex(widget.userType, 'missed'),
              ),
            ),
            Expanded(
              child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          children: [
            Text('빠진 공제 찾기'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 12),
            Text('연말정산에 안 넣은\n공제를 골라보세요', style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),
            const SizedBox(height: 10),
            Text('깜빡해서 빠뜨렸거나, 회사에 알리고 싶지 않아 일부러 뺀 공제를 고르면, 5월 종합소득세 신고로 얼마를 더 돌려받을 수 있는지 계산해드려요.',
                style: AppTheme.sans(14, sub, height: 1.55)),

            // ── 기준 금액 ──
            const SizedBox(height: 24),
            Text('기준 금액'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 6),
            Text('원천징수영수증에서 확인할 수 있어요.', style: AppTheme.sans(12, AppTheme.inkTertiary(context))),
            const SizedBox(height: 14),
            _kvRow('총급여', _grossCtrl),
            const SizedBox(height: 12),
            _kvRow('결정세액', _decidedCtrl),

            // ── 빠진 공제 선택 ──
            const SizedBox(height: 26),
            Text('빠뜨린 공제'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 6),
            Text('해당하는 항목을 고르고 실제 지출액을 적어주세요.', style: AppTheme.sans(12, sub)),
            const SizedBox(height: 14),
            DeductionChecklist(
              initialAmounts: _initialAmounts,
              onChanged: (a) => setState(() => _amounts = a),
            ),

            // ── 결과 ──
            const SizedBox(height: 16),
            if (c.isBlocked)
              _blockedNotice(c.blockedReason!)
            else if (c.hasMissed) ...[
              _refundHeadline(c.additionalRefund),
              const SizedBox(height: 8),
              ...c.lines.map(_resultRow),
              const SizedBox(height: 28),
              _primaryButton('신고서로 이어가기', () => _continueToForm(c)),
            ] else
              _emptyState(),

            // ── 정밀 계산기 ──
            const SizedBox(height: 18),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => TaxSimulatorScreen(userType: widget.userType))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.calculate_outlined, size: 16, color: accent),
                const SizedBox(width: 6),
                Text('정밀 계산기로 직접 계산하기', style: AppTheme.sans(13, accent, weight: FontWeight.w600)),
              ]),
            ),
          ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvRow(String label, TextEditingController ctrl) {
    return Row(children: [
      Expanded(child: Text(label, style: AppTheme.sans(14, AppTheme.ink(context), weight: FontWeight.w700))),
      AmountField(controller: ctrl, width: 150, onChanged: (_) => setState(() {})),
    ]);
  }

  /// 계산 근거가 없을 때 — 금액 대신 이유를 보여준다.
  /// 이 화면의 숫자는 그대로 신고서로 넘어가므로, 틀린 금액이 빈 결과보다 나쁘다.
  Widget _blockedNotice(String reason) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppTheme.line(context), width: 1), borderRadius: BorderRadius.circular(3)),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.inkTertiary(context)),
        const SizedBox(width: 12),
        Expanded(child: Text(reason,
            style: AppTheme.sans(13.5, AppTheme.ink(context), height: 1.5))),
      ]),
    );
  }

  Widget _emptyState() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppTheme.line(context), width: 1), borderRadius: BorderRadius.circular(3)),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(children: [
        Icon(Icons.checklist_rounded, size: 20, color: AppTheme.inkTertiary(context)),
        const SizedBox(width: 12),
        Expanded(child: Text('빠뜨린 공제를 골라보세요. 더 돌려받을 금액을 계산해드려요.',
            style: AppTheme.sans(14, AppTheme.ink(context), weight: FontWeight.w600, height: 1.4))),
      ]),
    );
  }

  Widget _refundHeadline(int refund) {
    final accent = AppTheme.accentColor(context);
    final sub = AppTheme.inkSecondary(context);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppTheme.lineStrong(context), width: 1.4), borderRadius: BorderRadius.circular(3)),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('더 받을 수 있는 환급', style: AppTheme.label(context)),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(_fmt.format(refund), style: AppTheme.serif(34, accent, spacing: -1.2, height: 1.0)),
            const SizedBox(width: 5),
            Text('원', style: AppTheme.sans(15, sub, weight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          Text('5월 종합소득세 신고로 돌려받을 수 있어요.', style: AppTheme.sans(12, sub, height: 1.45)),
        ],
      ),
    );
  }

  Widget _resultRow(CorrectionLine l) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.line(context)))),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Container(width: 3, height: 34, color: accent),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(l.category, style: AppTheme.sans(15, ink, weight: FontWeight.w700)),
                const Spacer(),
                Text('+${_fmt.format(l.missedCredit)}원', style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Text('지출 ${_fmt.format(l.available)}원 기준', style: AppTheme.sans(12, sub, height: 1.4)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    final bg = AppTheme.backgroundColor(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppTheme.ink(context), borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: AppTheme.sans(15, bg, weight: FontWeight.w700)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 16, color: bg),
        ]),
      ),
    );
  }
}
