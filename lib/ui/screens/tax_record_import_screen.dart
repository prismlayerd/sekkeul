import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../../core/data/db_helper.dart';
import '../../core/parsing/pdf_text_extractor.dart';
import '../../core/parsing/simplified_data_parser.dart';
import '../../core/parsing/withholding_parser.dart';
import '../../core/parsing/correction_report.dart';

/// ① 연말정산 자료 입력 — 간소화 자료 + 원천징수영수증 PDF를 온디바이스로 파싱해
/// 신고 결과를 읽고, 두 자료를 대조해 '빠진 공제'를 찾는다. 모두 기기 안에서 처리.
class TaxRecordImportScreen extends StatefulWidget {
  final String userType;
  const TaxRecordImportScreen({super.key, required this.userType});

  @override
  State<TaxRecordImportScreen> createState() => _TaxRecordImportScreenState();
}

class _TaxRecordImportScreenState extends State<TaxRecordImportScreen> {
  final _fmt = NumberFormat('#,###');
  GansoDeductions? _ganso;
  WithholdingReceipt? _wh;
  bool _busy = false;
  bool _manualMode = true; // 기본 직접 입력 (PDF 없이도 기록 가능)
  String? _error;

  // 추출값 편집 — 파서가 잘못 읽은 값을 사용자가 보정(잘못된 신고 방지)
  final Map<String, TextEditingController> _ctrls = {};

  // 사용자가 '회사에 안 냄'으로 직접 고른 공제 항목 키(av_*). 기본 비어 있음 —
  // 민감한 판단을 앱이 대신 결정하지 않고, 체크한 항목만 미신고분으로 계산한다.
  final Set<String> _notReported = {};

  @override
  void initState() {
    super.initState();
    // 기본 직접 입력 모드 — 계산·저장 경로 활성화를 위해 빈 객체 시드
    if (_manualMode) {
      _ganso = const GansoDeductions();
      _wh = const WithholdingReceipt();
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String key) =>
      _ctrls.putIfAbsent(key, () => TextEditingController());
  int _v(String key) =>
      int.tryParse((_ctrls[key]?.text ?? '').replaceAll(',', '')) ?? 0;
  void _seed(String key, int value) {
    _ctrl(key).text = value == 0 ? '' : _fmt.format(value);
  }

  /// 수기 모드에서는 '회사에 안 냄'으로 체크한 항목만 미신고분으로 반영한다
  /// (앱이 입력값 전부를 '안 냈다'고 결정하지 않음). PDF 모드는 원천 신고액으로 대조하므로 그대로.
  int _avFor(String key) =>
      (_manualMode && !_notReported.contains(key)) ? 0 : _v(key);

  /// 편집된 값으로 재구성한 간소화/원천 (보정 반영).
  GansoDeductions _effGanso() => GansoDeductions(
        creditCard: _avFor('av_card'),
        debitCard: _avFor('av_debit'),
        medical: _avFor('av_med'),
        medicalReimbursed: 0,
        // 난임은 총액 편집과 별개로 파싱값 보존(편집 표에 별도 필드 없음)
        medicalInfertility: _ganso?.medicalInfertility ?? 0,
        education: _avFor('av_edu'),
        donation: _avFor('av_don'),
        lifeInsurance: _avFor('av_life'),
        pensionSavings: _avFor('av_pen'),
        rent: _avFor('av_rent'),
      );
  WithholdingReceipt _effWh() {
    final b = _wh!;
    return WithholdingReceipt(
      grossSalary: _v('salary'),
      decidedTax: _v('decided'),
      laborDeduction: b.laborDeduction,
      taxableBase: b.taxableBase,
      calculatedTax: b.calculatedTax,
      paidTax: b.paidTax,
      finalSettlement: b.finalSettlement,
      claimedMedical: _v('cl_med'),
      claimedEducation: _v('cl_edu'),
      claimedDonation: _v('cl_don'),
      claimedLifeInsurance: _v('cl_life'),
      claimedPensionSavings: _v('cl_pen'),
      claimedRent: _v('cl_rent'),
    );
  }

  Future<void> _pick({required bool isGanso}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (res == null) {
        setState(() => _busy = false);
        return;
      }
      final bytes = res.files.single.bytes;
      if (bytes == null) {
        setState(() {
          _busy = false;
          _error = '파일을 읽지 못했어요. 다시 선택해 주세요.';
        });
        return;
      }
      final text = extractPdfText(bytes);
      setState(() {
        if (isGanso) {
          final g = parseSimplifiedText(text);
          _ganso = g;
          _seed('av_card', g.creditCard);
          _seed('av_debit', g.debitCash);
          _seed('av_med', g.medicalNet);
          _seed('av_edu', g.education);
          _seed('av_don', g.donation);
          _seed('av_life', g.lifeInsurance);
          _seed('av_pen', g.pensionSavings);
          _seed('av_rent', g.rent);
        } else {
          final w = parseWithholdingText(text);
          _wh = w;
          _seed('salary', w.grossSalary);
          _seed('decided', w.decidedTax);
          _seed('cl_med', w.claimedMedical);
          _seed('cl_edu', w.claimedEducation);
          _seed('cl_don', w.claimedDonation);
          _seed('cl_life', w.claimedLifeInsurance);
          _seed('cl_pen', w.claimedPensionSavings);
          _seed('cl_rent', w.claimedRent);
        }
        _busy = false;
      });
    } catch (e) {
      debugPrint('연말정산 PDF 파싱 실패: $e');
      setState(() {
        _busy = false;
        _error = 'PDF를 분석하지 못했어요. 홈택스에서 받은 PDF가 맞는지 확인해 주세요.';
      });
    }
  }

  // 누락 없음(또는 간소화 미입력) → 신고된 연말정산 결과 그대로
  List<Map<String, dynamic>> _asFiledItems(WithholdingReceipt w) => [
        {'title': '총급여액 (수입금액)', 'amount': w.grossSalary.toDouble(), 'isHeader': true},
        {'title': '(-) 근로소득공제', 'amount': w.laborDeduction.toDouble()},
        {'title': '(=) 과세표준', 'amount': w.taxableBase.toDouble(), 'isHeader': true, 'highlight': true},
        {'title': '(×) 산출세액', 'amount': w.calculatedTax.toDouble()},
        {'title': '(=) 결정세액', 'amount': w.decidedTax.toDouble(), 'isHeader': true, 'highlight': true},
        {'title': '(-) 기납부세액', 'amount': w.paidTax.toDouble()},
      ];

  // 빠진 공제 → 경정청구(추가환급) 신고서
  List<Map<String, dynamic>> _correctionItems(CorrectionReport c) => [
        for (final l in c.lines)
          {'title': '${l.category} 추가 세액공제', 'amount': l.missedCredit.toDouble()},
        {'title': '(=) 예상 추가 환급액 합계', 'amount': c.additionalRefund.toDouble(), 'isHeader': true, 'highlight': true},
      ];

  Future<void> _save() async {
    final w = _effWh();
    final g = _ganso != null ? _effGanso() : null;
    final c = g != null ? buildCorrectionReport(g, w) : null;
    // 진단 자동기입용 원시값 영속화 (PDF·수기 공통)
    await dbService.saveAnnualRecord(widget.userType, {
      'grossSalary': _v('salary'),
      'decidedTax': _v('decided'),
      'creditCard': _avFor('av_card'),
      'debitCash': _avFor('av_debit'),
      'medical': _avFor('av_med'),
      'education': _avFor('av_edu'),
      'donation': _avFor('av_don'),
      'lifeInsurance': _avFor('av_life'),
      'pensionSavings': _avFor('av_pen'),
      'rent': _avFor('av_rent'),
    });
    if (c != null && c.hasMissed) {
      await dbService.saveReportDraft(widget.userType,
          reportType: '경정청구', items: _correctionItems(c), finalAmount: c.additionalRefund.toDouble(), isRefund: true);
    } else {
      await dbService.saveReportDraft(widget.userType,
          reportType: '연말정산', items: _asFiledItems(w), finalAmount: w.finalSettlement.toDouble(), isRefund: w.isRefund);
    }
    if (mounted) Navigator.pop(context, true);
  }

  String _won(int v) => '${_fmt.format(v)}원';

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final w = _wh;
    final g = _ganso;
    final correction = (g != null && w != null) ? buildCorrectionReport(_effGanso(), _effWh()) : null;

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
            Text('연말정산 기록'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 12),
            Text(_manualMode ? '공제 항목을\n직접 적어주세요' : '홈택스 PDF로\n한 번에 채우기',
                style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),
            const SizedBox(height: 10),
            Text(_manualMode
                ? '회사에 안 낸 공제만 직접 골라 적으면 빠진 공제를 찾아 5월 종합소득세 신고에 써드려요. 모두 기기 안에서만 분석돼요.'
                : '홈택스에서 받은 간소화 자료·원천징수영수증 PDF를 올리면 값을 자동으로 채워요. 모두 기기 안에서만 분석돼요.',
                style: AppTheme.sans(14, sub, height: 1.55)),
            const SizedBox(height: 20),

            _modeToggle(),
            const SizedBox(height: 8),

            // ── A) PDF 가져오기 모드 ──
            if (!_manualMode) ...[
              _slot(
                label: '간소화 자료',
                hint: '신용카드·의료비·보험료 등 공제 가능액',
                done: g != null,
                summary: g == null ? null : '카드 ${_won(g.creditCard)} · 의료비 ${_won(g.medical)} · 보장성 ${_won(g.lifeInsurance)}',
                onTap: _busy ? null : () => _pick(isGanso: true),
              ),
              AppTheme.hairline(context),
              _slot(
                label: '원천징수영수증',
                hint: '총급여·이미 신고한 공제',
                done: w != null,
                summary: w == null ? null : '총급여 ${_won(w.grossSalary)} · ${w.isRefund ? '환급' : '추가납부'} ${_won(w.settlementAbs)}',
                onTap: _busy ? null : () => _pick(isGanso: false),
              ),
              AppTheme.hairline(context),
              if (_busy) ...[
                const SizedBox(height: 20),
                Center(child: Text('PDF 분석 중…', style: AppTheme.sans(13, sub))),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: AppTheme.sans(13, AppTheme.colorDanger, height: 1.45)),
              ],
              if (w != null && g == null) ...[
                const SizedBox(height: 28),
                Text('빠진 공제 · 추가 환급'.toUpperCase(), style: AppTheme.label(context)),
                const SizedBox(height: 12),
                Text('간소화 자료도 넣으면 빠뜨린 공제와 추가 환급액을 찾아드려요.',
                    style: AppTheme.sans(13, sub, height: 1.45)),
              ],
              if (w != null && g != null) ...[
                const SizedBox(height: 28),
                _confirmSection(),
              ],
            ]
            // ── B) 직접 입력 모드 ──
            else ...[
              const SizedBox(height: 12),
              _manualSection(),
            ],

            // ── 빠진 공제 → 추가 환급 + 저장 (양쪽 공통) ──
            if (w != null && g != null) ...[
              const SizedBox(height: 24),
              Text('빠진 공제 · 추가 환급'.toUpperCase(), style: AppTheme.label(context)),
              const SizedBox(height: 12),
              if (correction == null || !correction.hasMissed)
                _emptyMissed()
              else ...[
                _refundHeadline(correction.additionalRefund),
                const SizedBox(height: 8),
                ...correction.lines.map(_correctionRow),
              ],
              const SizedBox(height: 28),
              _saveButton(hasMissed: correction?.hasMissed ?? false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _slot({
    required String label,
    required String hint,
    required bool done,
    String? summary,
    VoidCallback? onTap,
  }) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(done ? Icons.check_circle_outline_rounded : Icons.upload_file_outlined,
                size: 22, color: done ? accent : sub),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
                  const SizedBox(height: 3),
                  Text(summary ?? hint,
                      style: AppTheme.sans(12, done ? accent : sub, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(done ? '다시' : 'PDF 선택', style: AppTheme.sans(12, tert, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// PDF / 직접입력 모드 토글.
  Widget _modeToggle() {
    return Row(children: [
      _modeChip('직접 입력', true),
      const SizedBox(width: 8),
      _modeChip('PDF로 가져오기', false),
    ]);
  }

  Widget _modeChip(String label, bool manual) {
    final selected = _manualMode == manual;
    final accent = AppTheme.accentColor(context);
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return GestureDetector(
      onTap: () => setState(() {
        _manualMode = manual;
        _error = null;
        if (manual) {
          // 직접 입력 모드 진입 — 빈 객체 시드로 계산·저장 경로 활성화
          _ganso = const GansoDeductions();
          _wh = const WithholdingReceipt();
        } else {
          // PDF 모드로 복귀 — 시드 비우고 다시 선택하게
          _ganso = null;
          _wh = null;
        }
      }),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? accent : AppTheme.line(context),
            width: selected ? 1.4 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AppTheme.sans(13, selected ? ink : sub,
                weight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  /// 직접 입력 패널 — 핵심 항목만 단일 열로. 입력값은 _effGanso/_effWh가 읽어
  /// 기존 빠진 공제·저장 경로를 그대로 탄다. (신고액 cl_*는 0 = 회사에 안 냄)
  Widget _manualSection() {
    final sub = AppTheme.inkSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('핵심 항목'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 8),
        Text('PDF 없이도 핵심 항목만 입력하면 빠진 공제·환급을 계산해드려요.',
            style: AppTheme.sans(13, sub, height: 1.45)),
        const SizedBox(height: 16),
        _manualRow('총급여', 'salary'),
        _manualRow('결정세액', 'decided'),
        const SizedBox(height: 14),
        Text('공제 항목 — 회사에 안 낸 것만 골라주세요', style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('체크한 항목만 5월에 직접 신고할 미신고분으로 계산해요. 앱이 대신 정하지 않아요.',
            style: AppTheme.sans(11.5, AppTheme.inkTertiary(context), height: 1.4)),
        const SizedBox(height: 8),
        AppTheme.hairline(context),
        _manualDeductionRow('신용카드', 'av_card'),
        _manualDeductionRow('체크·현금', 'av_debit'),
        _manualDeductionRow('의료비', 'av_med'),
        _manualDeductionRow('월세 (연 납입액)', 'av_rent'),
        _manualDeductionRow('보장성보험', 'av_life'),
        _manualDeductionRow('연금저축·IRP', 'av_pen'),
        _manualDeductionRow('교육비', 'av_edu'),
        _manualDeductionRow('기부금', 'av_don'),
      ],
    );
  }

  Widget _manualRow(String label, String key) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.line(context)))),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Text(label, style: AppTheme.sans(14, AppTheme.ink(context)))),
        _amount(key, width: 150),
      ]),
    );
  }

  /// 공제 항목 행 — '회사에 안 냄' 체크 + 금액. 체크한 항목만 미신고분 계산에 포함한다.
  /// 기본은 체크 해제라, 사용자가 직접 고르기 전까지 앱은 어떤 것도 '안 냈다'고 정하지 않는다.
  Widget _manualDeductionRow(String label, String key) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final checked = _notReported.contains(key);
    return GestureDetector(
      onTap: () => setState(() {
        if (checked) {
          _notReported.remove(key);
        } else {
          _notReported.add(key);
        }
      }),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.line(context)))),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          // 사각 체크박스 — 선택 시 잉크로 채움(회사에 안 낸 항목 표시)
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: checked ? ink : null,
              border: Border.all(color: checked ? ink : AppTheme.lineStrong(context), width: 1.4),
              borderRadius: BorderRadius.circular(3),
            ),
            child: checked
                ? Icon(Icons.check, size: 15, color: AppTheme.backgroundColor(context))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: AppTheme.sans(14, checked ? ink : tert,
                    weight: checked ? FontWeight.w600 : FontWeight.w400)),
          ),
          _amount(key, width: 130),
        ]),
      ),
    );
  }

  Widget _emptyMissed() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppTheme.line(context), width: 1), borderRadius: BorderRadius.circular(3)),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(children: [
        Icon(Icons.verified_outlined, size: 20, color: AppTheme.colorSuccess),
        const SizedBox(width: 12),
        Expanded(child: Text('빠뜨린 공제가 없어요. 이미 잘 챙기셨네요.',
            style: AppTheme.sans(14, AppTheme.ink(context), weight: FontWeight.w600, height: 1.4))),
      ]),
    );
  }

  /// 추출값 확인·보정 — 파서가 읽은 값을 사용자가 검토·수정.
  Widget _confirmSection() {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('추출값 확인·보정'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 8),
        Text('PDF에서 읽은 값이에요. 다르면 고쳐주세요.', style: AppTheme.sans(13, sub, height: 1.45)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('총급여', style: AppTheme.sans(14, ink, weight: FontWeight.w700))),
          _amount('salary', width: 150),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          const Expanded(flex: 3, child: SizedBox()),
          Expanded(flex: 4, child: Text('가능액'.toUpperCase(), textAlign: TextAlign.center, style: AppTheme.label(context))),
          const SizedBox(width: 10),
          Expanded(flex: 4, child: Text('신고액'.toUpperCase(), textAlign: TextAlign.center, style: AppTheme.label(context))),
        ]),
        const SizedBox(height: 4),
        AppTheme.hairline(context),
        _editRow2('의료비', 'av_med', 'cl_med'),
        _editRow2('교육비', 'av_edu', 'cl_edu'),
        _editRow2('기부금', 'av_don', 'cl_don'),
        _editRow2('보장성보험', 'av_life', 'cl_life'),
        _editRow2('연금저축', 'av_pen', 'cl_pen'),
        _editRow2('월세액', 'av_rent', 'cl_rent'),
      ],
    );
  }

  Widget _editRow2(String label, String avKey, String clKey) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.line(context)))),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(flex: 3, child: Text(label, style: AppTheme.sans(14, AppTheme.ink(context)))),
        Expanded(flex: 4, child: _amount(avKey, expand: true)),
        const SizedBox(width: 10),
        Expanded(flex: 4, child: _amount(clKey, expand: true)),
      ]),
    );
  }

  /// 공용 액수 입력칸 — 입력 시 라이브 재계산.
  Widget _amount(String key, {bool expand = false, double width = 150}) {
    return AmountField(
      controller: _ctrl(key),
      expand: expand,
      width: width,
      onChanged: (_) => setState(() {}),
    );
  }

  /// 추가 환급 합계 — 표제란.
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
          Text('연말정산에 안 넣은 공제예요. 경정청구로 돌려받을 수 있어요.', style: AppTheme.sans(12, sub, height: 1.45)),
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
                  Text('+${_won(l.missedCredit)}', style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Text('가능 ${_won(l.available)} · 신고 ${_won(l.claimed)}',
                    style: AppTheme.sans(12, sub, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton({required bool hasMissed}) {
    final bg = AppTheme.backgroundColor(context);
    return GestureDetector(
      onTap: _save,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppTheme.ink(context), borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(hasMissed ? '경정청구 신고서로 저장' : '연말정산 결과 저장',
              style: AppTheme.sans(15, bg, weight: FontWeight.w700)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 16, color: bg),
        ]),
      ),
    );
  }
}
