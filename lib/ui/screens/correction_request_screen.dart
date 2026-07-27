import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../components/deduction_checklist.dart';

import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/deduction_catalog.dart';
import '../../core/parsing/correction_report.dart';
import '../../core/tax_engine/tax_year_rules.dart';
import '../theme/text_wrap.dart';

/// 경정청구 준비 — 입력 대신 '잊은 공제 선택 + 홈택스 신고 가이드' 중심.
/// 빠뜨린 공제를 골라 실제 지출액만 적으면(이미 신고액은 0으로 간주) 추가 환급을
/// 계산하고, 홈택스에서 어떻게 경정청구하는지 단계별로 안내한다.
class CorrectionRequestScreen extends StatefulWidget {
  final String userType;
  const CorrectionRequestScreen({super.key, required this.userType});

  @override
  State<CorrectionRequestScreen> createState() => _CorrectionRequestScreenState();
}

class _CorrectionRequestScreenState extends State<CorrectionRequestScreen> {
  final _fmt = NumberFormat('#,###');
  final _grossCtrl = TextEditingController();
  final _decidedCtrl = TextEditingController();

  Map<String, int> _amounts = {};       // 체크리스트에서 고른 항목별 지출액
  Map<String, int> _initialAmounts = {}; // PDF 간소화 프리필(보조)

  late int _selectedYear = _claimableYears.first;

  /// 아직 청구 기한이 남았고(국세기본법 §45의2 ⑤ — 귀속연도 다음 해 3.10.+5년),
  /// 앱이 그 해 공제율을 원문으로 확인해 둔 연도만 고르게 한다.
  List<int> get _claimableYears {
    final now = DateTime.now();
    return [
      for (var y = now.year - 1; y >= kOldestCorrectionYear; y--)
        if (rulesForYear(y) != null && isCorrectionOpen(y, now)) y,
    ];
  }

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

  /// 저장된 연말정산 기록이 있으면 총급여·결정세액·가능액을 미리 채운다(보조 경로).
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
        forgottenReceipt(
            accrualYear: _selectedYear, grossSalary: _gross, decidedTax: _decided),
      );

  List<Map<String, dynamic>> _draftItems(CorrectionReport c) => [
        for (final l in c.lines)
          {'title': '${l.category} 세액공제', 'amount': l.missedCredit.toDouble()},
        {'title': '환급받을 세액', 'amount': c.additionalRefund.toDouble(), 'isHeader': true, 'highlight': true},
      ];

  Future<void> _save(CorrectionReport c) async {
    await dbService.saveReportDraft(widget.userType,
        reportType: '경정청구',
        items: _draftItems(c),
        finalAmount: c.additionalRefund.toDouble(),
        isRefund: true);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          children: [
            Text('경정청구 준비'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 12),
            Text('놓친 공제\n되돌려받기', style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),
            const SizedBox(height: 10),
            Text('연말정산 때 깜빡한 공제를 고르기만 하면, 5년 내 경정청구로 얼마를 돌려받을 수 있는지 계산하고 홈택스 신고 방법까지 알려드려요.'.keepWords,
                style: AppTheme.sans(14, sub, height: 1.55)),

            // ── 대상 연도 ──
            const SizedBox(height: 22),
            Text('어느 해 연말정산을 바로잡을까요?'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 10),
            _yearSelector(),

            // ── 총급여·결정세액 (환급액·한도 계산에 필요) ──
            const SizedBox(height: 24),
            Text('그 해 기준 금액'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 6),
            Text('원천징수영수증에서 확인할 수 있어요.'.keepWords, style: AppTheme.sans(12, AppTheme.inkTertiary(context))),
            const SizedBox(height: 14),
            _kvRow('총급여', _grossCtrl),
            const SizedBox(height: 12),
            _kvRow('결정세액', _decidedCtrl),

            // ── 잊은 공제 선택 ──
            const SizedBox(height: 26),
            Text('어떤 공제를 빠뜨렸나요?'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 6),
            Text('해당하는 항목을 고르고 실제 지출액을 적어주세요.'.keepWords, style: AppTheme.sans(12, sub)),
            const SizedBox(height: 14),
            DeductionChecklist(
              initialAmounts: _initialAmounts,
              onChanged: (a) => setState(() => _amounts = a),
            ),

            // ── 예상 추가 환급액 ──
            const SizedBox(height: 16),
            if (c.isBlocked)
              _blockedNotice(c.blockedReason!)
            else if (c.hasMissed) ...[
              _refundHeadline(c.additionalRefund),
              const SizedBox(height: 8),
              ...c.lines.map(_correctionRow),
            ] else
              _emptyMissed(),

            // ── 홈택스 신고 가이드 ──
            const SizedBox(height: 30),
            _guideSection(c),

            if (c.hasMissed) ...[
              const SizedBox(height: 28),
              _saveButton(c),
            ],
          ],
        ),
      ),
    );
  }

  /// 최근 5년 대상 연도 선택 — 경정청구는 법정신고기한 5년 내만 가능.
  Widget _yearSelector() {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);
    return Row(
      children: [
        for (final y in _claimableYears)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedYear = y),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedYear == y ? accent.withValues(alpha: 0.12) : Colors.transparent,
                  border: Border.all(
                    color: _selectedYear == y ? accent : AppTheme.line(context),
                    width: _selectedYear == y ? 1.4 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$y',
                    style: AppTheme.sans(14, _selectedYear == y ? ink : sub,
                        weight: _selectedYear == y ? FontWeight.w700 : FontWeight.w500)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _kvRow(String label, TextEditingController ctrl) {
    return Row(children: [
      Expanded(child: Text(label, style: AppTheme.sans(14, AppTheme.ink(context), weight: FontWeight.w700))),
      AmountField(controller: ctrl, width: 150, onChanged: (_) => setState(() {})),
    ]);
  }

  /// 계산 근거가 없을 때 — 금액 대신 이유를 보여준다.
  /// 경정청구는 이 숫자를 그대로 세무서에 내는 기능이라, 틀린 금액이 빈 결과보다 나쁘다.
  Widget _blockedNotice(String reason) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppTheme.line(context), width: 1), borderRadius: BorderRadius.circular(3)),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.inkTertiary(context)),
        const SizedBox(width: 12),
        Expanded(child: Text(reason.keepWords,
            style: AppTheme.sans(13.5, AppTheme.ink(context), height: 1.5))),
      ]),
    );
  }

  Widget _emptyMissed() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppTheme.line(context), width: 1), borderRadius: BorderRadius.circular(3)),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(children: [
        Icon(Icons.checklist_rounded, size: 20, color: AppTheme.inkTertiary(context)),
        const SizedBox(width: 12),
        Expanded(child: Text('위에서 빠뜨린 공제를 골라보세요. 돌려받을 금액을 계산해드려요.'.keepWords,
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
          Text('예상 추가 환급액', style: AppTheme.label(context)),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(_fmt.format(refund), style: AppTheme.serif(34, accent, spacing: -1.2, height: 1.0)),
            const SizedBox(width: 5),
            Text('원', style: AppTheme.sans(15, sub, weight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          Text('$_selectedYear년 귀속 — 5년 내 경정청구로 돌려받을 수 있어요.'.keepWords, style: AppTheme.sans(12, sub, height: 1.45)),
        ],
      ),
    );
  }

  Widget _correctionRow(CorrectionLine l) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.line(context)))),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                Text('지출 ${_fmt.format(l.available)}원 기준'.keepWords, style: AppTheme.sans(12, sub, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 홈택스 경정청구 단계별 가이드 + 고른 항목별 입력 위치.
  Widget _guideSection(CorrectionReport c) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final selectedCats = kDeductionCatalog.where((cat) => _amounts.containsKey(cat.id)).toList();

    const steps = [
      ['홈택스 로그인', 'hometax.go.kr 접속 후 공동·간편인증으로 로그인해요.'],
      ['경정청구 메뉴', '세금신고 → 종합소득세 → 경정청구(정기신고분)로 들어가요.'],
      ['귀속연도 선택', '바로잡을 연도를 고르면 기존 신고 내용이 불러와져요.'],
      ['빠진 공제 입력', '아래 항목을 해당 칸에 추가로 입력해요.'],
      ['제출 · 환급계좌', '내용을 확인하고 제출하면, 환급은 보통 한두 달 안에 들어와요.'],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('홈택스 신고 방법'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 14),
        for (int i = 0; i < steps.length; i++) ...[
          _guideStep(i + 1, steps[i][0], steps[i][1]),
          if (i < steps.length - 1) const SizedBox(height: 14),
        ],
        if (selectedCats.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppTheme.line(context)), borderRadius: BorderRadius.circular(3)),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('고른 항목, 어디에 입력하나요?'.keepWords, style: AppTheme.sans(14, ink, weight: FontWeight.w700)),
                const SizedBox(height: 10),
                for (final cat in selectedCats) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 72, child: Text(cat.name, style: AppTheme.sans(13, ink, weight: FontWeight.w600))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(cat.fileHint, style: AppTheme.sans(12, sub, height: 1.45))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _guideStep(int n, String title, String body) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.lineStrong(context), width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text('$n', style: AppTheme.sans(14, ink, weight: FontWeight.w700, height: 1.0)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.sans(14, ink, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(body, style: AppTheme.sans(12, sub, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _saveButton(CorrectionReport c) {
    final bg = AppTheme.backgroundColor(context);
    return GestureDetector(
      onTap: () => _save(c),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppTheme.ink(context), borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('경정청구서로 저장', style: AppTheme.sans(15, bg, weight: FontWeight.w700)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 16, color: bg),
        ]),
      ),
    );
  }
}
