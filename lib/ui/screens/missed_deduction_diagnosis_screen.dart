import 'package:flutter/material.dart';
import '../components/amount_field.dart';
import '../components/deduction_checklist.dart';

import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/deduction_catalog.dart';
import '../../core/data/residence.dart';
import '../../core/data/year_snapshot.dart';
import '../components/missing_input_notice.dart';
import '../../core/parsing/correction_report.dart';
import 'tax_report_form_screen.dart';
import 'tax_simulator_screen.dart';
import 'tax_tools_screen.dart';
import '../components/tax_pipeline_rail.dart';
import '../theme/text_wrap.dart';

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
  final _grossCtrl = TextEditingController();
  final _decidedCtrl = TextEditingController();

  Map<String, int> _amounts = {};
  YearSnapshot? _snapshot;
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
    // **일 년 내내 쓴 것이 여기로 올라와야 한다.**
    //
    // 예전엔 이 화면이 `annual_records`(PDF로 가져왔거나 손으로 적은 연말정산
    // 결과)만 봤다. 그래서 01·02를 아무리 꾸준히 써도 직장인 파이프라인의
    // 첫 단계에 아무것도 안 넘어왔다 — 사용자는 여기서 다시 처음부터 적었다.
    final snap = await YearSnapshot.load(widget.userType);
    final r = await dbService.getAnnualRecord(widget.userType);
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      // 총급여는 내 정보가 정본이고, 원천징수영수증을 넣은 사람은 그쪽이 이긴다.
      if (snap.laborIncome > 0) _grossCtrl.text = comma(snap.laborIncome.round());
      // **「올해 받을 공제」는 안 끌어온다.** 이 화면은 5월 신고 대상인 **작년**을
      // 다루는데 그 저장소는 올해 것이다 — 연도가 어긋난다. 경정청구가 저장된
      // 기록 하나를 연도 상관없이 채우던 것과 같은 종류의 실수다.
      _initialAmounts = const {};
      if (r != null) {
        final gross = (r['grossSalary'] as num?)?.toInt() ?? 0;
        final decided = (r['decidedTax'] as num?)?.toInt() ?? 0;
        if (gross > 0) _grossCtrl.text = comma(gross);
        if (decided > 0) _decidedCtrl.text = comma(decided);
        _initialAmounts = {..._initialAmounts, ...amountsFromAnnualRecord(r)};
      }
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

  /// **철이 지나면 길이 바뀐다.**
  ///
  /// 5월 확정신고와 경정청구는 다른 절차다. 작년 귀속분은 5월 31일까지는
  /// 확정신고로, 그 뒤엔 경정청구로 낸다(국세기본법 §45의2 — 법정신고기한이
  /// **지난 후** 5년). 8월에 「5월 종합소득세 신고로」라고 하면 이미 닫힌 문을
  /// 가리키는 것이고, 사용자는 내년 5월까지 기다려야 하는 줄 안다.
  String _routeLine() {
    final now = DateTime.now();
    return now.month <= 5
        ? '${now.year - 1}년 귀속은 5월 31일까지 종합소득세 확정신고로 내면 돼요.'
        : '${now.year - 1}년 귀속은 5월이 지나서 경정청구로 내요 — 5년 안이면 아무 때나 돼요.';
  }

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
      appBar: AppBar(
        leading: IconButton(
          tooltip: '뒤로',
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
            // 전표의 표제 — 가운데로 모으고 위아래를 선으로 닫는다(목업 1e).
            AppTheme.ruleLabel(context, 'ESTIMATED REFUND'),
            const SizedBox(height: 12),
            Text('빠진 공제 진단',
                textAlign: TextAlign.center,
                style: AppTheme.display(AppTheme.serifLG, ink, spacing: 4)),
            const SizedBox(height: 10),
            Text('깜빡해서 빠뜨렸거나, 회사에 알리고 싶지 않아 일부러 뺀 공제를 고르면 '
                    '얼마를 더 돌려받을 수 있는지 계산해드려요. ${_routeLine()}'
                .keepWords,
                style: AppTheme.sans(AppTheme.tsBase, sub, height: 1.55)),

            // ── 기준 금액 ──
            const SizedBox(height: 22),
            AppTheme.dashRule(context),
            const SizedBox(height: 16),
            AppTheme.sectionHead(context, '01', '기준 금액'),
            const SizedBox(height: 6),
            Text('원천징수영수증에서 확인할 수 있어요.'.keepWords,
                style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkTertiary(context))),
            const SizedBox(height: 14),
            _kvRow('총급여', _grossCtrl),
            const SizedBox(height: 12),
            _kvRow('결정세액', _decidedCtrl),

            // ── 빠진 공제 선택 ──
            const SizedBox(height: 22),
            AppTheme.dashRule(context),
            const SizedBox(height: 16),
            AppTheme.sectionHead(context, '02', '확인 목록'),
            const SizedBox(height: 6),
            Text('해당하는 항목을 고르고 실제 지출액을 적어주세요.'.keepWords,
                style: AppTheme.sans(AppTheme.tsSM, sub)),
            const SizedBox(height: 10),
            DeductionChecklist(
              key: ValueKey(_snapshot?.profile['residence_type']),
              categories: deductionsFor(
                residence: residenceOf(_snapshot?.profile),
                isHouseholdHead: isHouseholdHead(_snapshot?.profile),
                grossIncome: _gross.toDouble(),
              ),
              initialAmounts: _initialAmounts,
              onChanged: (a) => setState(() => _amounts = a),
            ),
            if (_snapshot != null && _snapshot!.missing.isNotEmpty) ...[
              const SizedBox(height: 16),
              MissingInputNotice(_snapshot!.missing),
            ],

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
                Text('정밀 계산기로 직접 계산하기'.keepWords,
                    style: AppTheme.sans(AppTheme.tsSM, accent, weight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 22),
            AppTheme.barcode(context),
            const SizedBox(height: 6),
            Center(
              child: Text('＊ S E K K E U L ＊',
                  style: AppTheme.label(context, color: AppTheme.inkTertiary(context))),
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
      Expanded(child: Text(label, style: AppTheme.sans(AppTheme.tsMD, AppTheme.ink(context), weight: FontWeight.w700))),
      AmountField(controller: ctrl, width: 150, onChanged: (_) => setState(() {})),
    ]);
  }

  /// 계산 근거가 없을 때 — 금액 대신 이유를 보여준다.
  /// 이 화면의 숫자는 그대로 신고서로 넘어가므로, 틀린 금액이 빈 결과보다 나쁘다.
  Widget _blockedNotice(String reason) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppTheme.line(context), width: 1)),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.inkTertiary(context)),
        const SizedBox(width: 12),
        Expanded(child: Text(reason.keepWords,
            style: AppTheme.sans(AppTheme.tsSM, AppTheme.ink(context), height: 1.5))),
      ]),
    );
  }

  Widget _emptyState() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppTheme.line(context), width: 1)),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(children: [
        Icon(Icons.checklist_rounded, size: 20, color: AppTheme.inkTertiary(context)),
        const SizedBox(width: 12),
        Expanded(child: Text('빠뜨린 공제를 골라보세요. 더 돌려받을 금액을 계산해드려요.'.keepWords,
            style: AppTheme.sans(AppTheme.tsMD, AppTheme.ink(context), weight: FontWeight.w600, height: 1.4))),
      ]),
    );
  }

  Widget _refundHeadline(int refund) {
    final accent = AppTheme.accentColor(context);
    final sub = AppTheme.inkSecondary(context);
    // 결과는 종이 위에 잉크가 앉은 칸으로 찍는다 — 테두리 1.5px + 옅은 채움.
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.accentSoft(context),
        border: Border.all(color: AppTheme.lineStrong(context), width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('지금까지 찾은 환급', style: AppTheme.label(context)),
          const SizedBox(height: 10),
          AppTheme.amount(context, comma(refund), color: accent),
          const SizedBox(height: 6),
          Text(_routeLine(),
              style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.45)),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: AppTheme.tick(context, true)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(l.category,
                    style: AppTheme.sans(AppTheme.tsBase, ink, weight: FontWeight.w700))),
                const SizedBox(width: 8),
                Text('+${comma(l.missedCredit)}원',
                    style: AppTheme.sans(AppTheme.tsBase, accent, weight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Text('지출 ${comma(l.available)}원 기준',
                  style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.4)),
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
          Text(label, style: AppTheme.sans(AppTheme.tsBase, bg, weight: FontWeight.w700)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 16, color: bg),
        ]),
      ),
    );
  }
}
