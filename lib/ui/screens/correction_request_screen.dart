import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../components/amount_field.dart';
import '../components/deduction_checklist.dart';

import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/deduction_catalog.dart';
import '../../core/parsing/correction_pdf.dart';
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
  final _grossCtrl = TextEditingController();
  final _decidedCtrl = TextEditingController();

  /// 체크리스트에서 고른 항목별 지출액.
  ///
  /// **미리 채우지 않는다.** 예전엔 저장된 연말정산 기록 하나를 가져와 채웠는데,
  /// 그 쿼리에 연도 조건이 없어서 2023년을 골라도 다른 해 숫자가 들어왔다.
  /// 애초에 앱이 5년 전 지출을 알 리가 없다 — 이 화면은 「아 이것도 공제받을
  /// 수 있었어?」를 깨달았을 때 여는 곳이고, 값은 사용자가 직접 적는 것이다.
  Map<String, int> _amounts = {};

  late int _selectedYear = _claimableYears.first;

  /// 어떻게 낼지 — 사용자가 **먼저** 고른다.
  _Method _method = _Method.paper;

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
  void dispose() {
    _grossCtrl.dispose();
    _decidedCtrl.dispose();
    super.dispose();
  }

  int get _gross => int.tryParse(_grossCtrl.text.replaceAll(',', '')) ?? 0;
  int get _decided => int.tryParse(_decidedCtrl.text.replaceAll(',', '')) ?? 0;

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
      appBar: AppBar(
        leading: IconButton(
          tooltip: '뒤로',
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
            Text('놓친 공제\n되돌려받기'.keepWords, style: AppTheme.serif(AppTheme.serifXL, ink, spacing: -0.5, height: 1.2)),
            const SizedBox(height: 10),
            Text('연말정산 때 깜빡한 공제를 고르고 금액을 적으면, 5년 내 경정청구로 '
                    '얼마를 돌려받을 수 있는지 계산하고 필요한 서류와 내는 방법까지 안내해드려요.'
                .keepWords,
                style: AppTheme.sans(AppTheme.tsMD, sub, height: 1.55)),

            // ── 대상 연도 ──
            const SizedBox(height: 22),
            Text('어느 해 연말정산을 바로잡을까요?'.keepWords.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 10),
            _yearSelector(),

            // ── 총급여·결정세액 (환급액·한도 계산에 필요) ──
            const SizedBox(height: 24),
            Text('그 해 기준 금액'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 6),
            Text('원천징수영수증에서 확인할 수 있어요.'.keepWords, style: AppTheme.sans(AppTheme.tsXS, AppTheme.inkTertiary(context))),
            const SizedBox(height: 14),
            _kvRow('총급여', _grossCtrl),
            const SizedBox(height: 12),
            _kvRow('결정세액', _decidedCtrl),

            // ── 잊은 공제 선택 ──
            const SizedBox(height: 26),
            Text('어떤 공제를 빠뜨렸나요?'.keepWords.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 6),
            Text('해당하는 항목을 고르고 실제 지출액을 적어주세요.'.keepWords, style: AppTheme.sans(AppTheme.tsXS, sub)),
            const SizedBox(height: 14),
            DeductionChecklist(
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

            if (c.hasMissed) ...[
              // ── 같이 낼 서류 ──
              const SizedBox(height: 30),
              _documentSection(),

              // ── 어떻게 낼까 ──
              const SizedBox(height: 30),
              _methodSection(c),

              const SizedBox(height: 22),
              if (_method == _Method.hometax) _guideSection(c),
              if (_method == _Method.paper) _paperSection(c),

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
                    style: AppTheme.sans(AppTheme.tsMD, _selectedYear == y ? ink : sub,
                        weight: _selectedYear == y ? FontWeight.w700 : FontWeight.w500)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _kvRow(String label, TextEditingController ctrl) {
    return Row(children: [
      Expanded(child: Text(label, style: AppTheme.sans(AppTheme.tsMD, AppTheme.ink(context), weight: FontWeight.w700))),
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
            style: AppTheme.sans(AppTheme.tsSM, AppTheme.ink(context), height: 1.5))),
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
            style: AppTheme.sans(AppTheme.tsMD, AppTheme.ink(context), weight: FontWeight.w600, height: 1.4))),
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
            Text(comma(refund), style: AppTheme.serif(AppTheme.serifXL, accent, spacing: -1.2, height: 1.0)),
            const SizedBox(width: 5),
            Text('원', style: AppTheme.sans(AppTheme.tsBase, sub, weight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          Text('$_selectedYear년 귀속 — 5년 내 경정청구로 돌려받을 수 있어요.', style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.45)),
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
                  Text(l.category, style: AppTheme.sans(AppTheme.tsBase, ink, weight: FontWeight.w700)),
                  const Spacer(),
                  Text('+${comma(l.missedCredit)}원', style: AppTheme.sans(AppTheme.tsMD, accent, weight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Text('지출 ${comma(l.available)}원 기준', style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 고른 항목마다 **같이 낼 서류.**
  ///
  /// 서류가 빠지면 보정 요구가 오고 환급이 몇 달 늦는다. 숫자를 다 맞춰 놓고
  /// 서류에서 막히는 게 제일 아깝다 — 방식을 고르기 전에 먼저 보여준다.
  Widget _documentSection() {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final picked = kDeductionCatalog.where((c) => (_amounts[c.id] ?? 0) > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('같이 낼 서류'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 6),
        Text('고르신 항목에 필요한 것만 모았어요.'.keepWords,
            style: AppTheme.sans(AppTheme.tsXS, AppTheme.inkTertiary(context))),
        const SizedBox(height: 14),
        for (final c in picked) ...[
          Text(c.name, style: AppTheme.sans(AppTheme.tsSM, ink, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final d in c.documents)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('· ', style: AppTheme.sans(AppTheme.tsSM, sub)),
                Expanded(
                  child: Text(d.keepWords,
                      style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.45)),
                ),
              ]),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// **어떻게 낼지 먼저 고르게 한다.**
  ///
  /// 두 길은 준비물이 다르다. 우편·방문은 종이 서류와 프린터가 필요하고,
  /// 홈택스는 공동인증서와 스캔 파일이 필요하다. 안내를 둘 다 늘어놓으면
  /// 자기와 상관없는 절반을 읽게 된다.
  Widget _methodSection(CorrectionReport c) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);

    Widget pick(_Method m, String title, String desc) {
      final on = _method == m;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => setState(() => _method = m),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: on ? accent.withValues(alpha: 0.10) : null,
              border: Border.all(
                  color: on ? accent : AppTheme.line(context), width: on ? 1.4 : 1.0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: AppTheme.sans(AppTheme.tsMD, ink,
                      weight: on ? FontWeight.w700 : FontWeight.w600)),
              const SizedBox(height: 4),
              Text(desc.keepWords,
                  style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.45)),
            ]),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('어떻게 내실 건가요?'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 12),
        pick(_Method.paper, '세무서에 직접 내기',
            '앱이 만든 작성 내역과 공식 양식을 받아서 프린트하세요. 메일로 보내 두면 PC에서 뽑기 편해요.'),
        pick(_Method.hometax, '홈택스로 내기',
            '고르신 항목만 짚어서, 어느 화면 어느 칸에 넣고 무엇을 첨부할지 안내해드려요.'),
      ],
    );
  }

  /// 우편·방문 — 작성 내역 PDF와 공식 양식을 OS 공유 시트로 넘긴다.
  ///
  /// 앱이 메일을 보내지 않는다. 공유 시트에서 사용자가 직접 메일 앱이나
  /// 인쇄를 고른다 — 릴리스에 INTERNET 권한이 없어도 되고, 앱이 사용자의
  /// 세금 자료를 어디로도 내보내지 않는다.
  Widget _paperSection(CorrectionReport c) {
    final sub = AppTheme.inkSecondary(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('$_selectedYear년 귀속 경정청구서를 주소지 관할 세무서에 내시면 돼요. '
              '우편도 되고 직접 가셔도 돼요.'
          .keepWords,
          style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5)),
      const SizedBox(height: 16),
      _wideButton('작성 내역 받기 (프린트·메일)', () => _sharePdf(c)),
      const SizedBox(height: 8),
      _wideButton('공식 경정청구서 양식 받기',
          () => _shareAsset('assets/forms/gyeongjeong_national.pdf', '경정청구서'),
          outlined: true),
      const SizedBox(height: 8),
      _wideButton('지방세 경정청구서 양식 받기',
          () => _shareAsset('assets/forms/gyeongjeong_local.pdf', '지방세 경정청구서'),
          outlined: true),
      const SizedBox(height: 10),
      Text('작성 내역의 숫자를 공식 양식에 그대로 옮겨 적으시면 돼요.'.keepWords,
          style: AppTheme.sans(AppTheme.tsXS, AppTheme.inkTertiary(context), height: 1.45)),
    ]);
  }

  Future<void> _sharePdf(CorrectionReport c) async {
    final font = await rootBundle.load('assets/fonts/NanumGothicCoding-Regular.ttf');
    final bytes = await buildCorrectionPdf(
      report: c,
      amounts: _amounts,
      grossSalary: _gross,
      decidedTax: _decided,
      koreanFont: font.buffer.asUint8List(),
    );
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/경정청구_작성내역_$_selectedYear.pdf');
    await f.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(f.path)], text: '$_selectedYear년 귀속 경정청구 작성 내역');
  }

  Future<void> _shareAsset(String assetPath, String name) async {
    final bytes = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name.pdf');
    await f.writeAsBytes(bytes.buffer.asUint8List());
    await Share.shareXFiles([XFile(f.path)], text: name);
  }

  Widget _wideButton(String label, VoidCallback onTap, {bool outlined = false}) {
    final ink = AppTheme.ink(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: outlined ? null : ink,
            border: outlined ? Border.all(color: AppTheme.line(context)) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: AppTheme.sans(AppTheme.tsSM,
                  outlined ? ink : Theme.of(context).cardColor,
                  weight: FontWeight.w700)),
        ),
      ),
    );
  }

  /// 홈택스 경정청구 단계별 가이드 + 고른 항목별 입력 위치.
  Widget _guideSection(CorrectionReport c) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final selectedCats = kDeductionCatalog.where((cat) => _amounts.containsKey(cat.id)).toList();

    // **고른 항목 이름을 그대로 넣는다.** 모두에게 같은 다섯 줄이면 그건
    // 가이드가 아니라 매뉴얼이다. 사용자가 자기 화면에서 무엇을 할지 알아야 한다.
    final names = selectedCats.map((c) => c.name).join(' · ');
    final steps = [
      ['홈택스 로그인', 'hometax.go.kr 접속 후 공동·간편인증으로 로그인해요.'],
      ['경정청구 메뉴', '세금신고 → 종합소득세 → 경정청구(정기신고분)로 들어가요.'],
      ['$_selectedYear년 선택', '$_selectedYear년을 고르면 그때 신고한 내용이 그대로 불러와져요.'],
      ['$names 넣기', '불러온 화면에서 아래 칸을 찾아 금액을 더해요.'],
      ['서류 첨부', '위 「같이 낼 서류」를 스캔하거나 사진으로 찍어 올려요.'],
      ['제출 · 환급계좌', '환급받을 계좌를 넣고 제출하면, 보통 한두 달 안에 들어와요.'],
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
                Text('고른 항목, 어디에 입력하나요?'.keepWords, style: AppTheme.sans(AppTheme.tsMD, ink, weight: FontWeight.w700)),
                const SizedBox(height: 10),
                for (final cat in selectedCats) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 72, child: Text(cat.name, style: AppTheme.sans(AppTheme.tsSM, ink, weight: FontWeight.w600))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(cat.fileHint, style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.45)),
                            const SizedBox(height: 2),
                            // 얼마를 넣을지까지 말해 준다 — 화면을 오가며 기억할 일이 없어야 한다.
                            Text('넣을 금액 ${comma(_amounts[cat.id] ?? 0)}원',
                                style: AppTheme.sans(AppTheme.tsXS, AppTheme.accentColor(context),
                                    weight: FontWeight.w600)),
                          ]),
                        ),
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
          child: Text('$n', style: AppTheme.sans(AppTheme.tsMD, ink, weight: FontWeight.w700, height: 1.0)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.sans(AppTheme.tsMD, ink, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(body, style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.5)),
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
          Text('경정청구서로 저장', style: AppTheme.sans(AppTheme.tsBase, bg, weight: FontWeight.w700)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 16, color: bg),
        ]),
      ),
    );
  }
}


/// 경정청구를 내는 두 길. 준비물이 달라서 먼저 고르게 한다.
enum _Method { paper, hometax }
