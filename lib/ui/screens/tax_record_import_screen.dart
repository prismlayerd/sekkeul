import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../../core/data/db_helper.dart';
import '../../core/parsing/pdf_text_extractor.dart';
import '../../core/parsing/simplified_data_parser.dart';
import '../../core/parsing/withholding_parser.dart';
import '../theme/text_wrap.dart';

/// ① 연말정산 기록 — 간소화 자료 + 원천징수영수증 PDF를 온디바이스로 파싱하거나
/// 총급여·결정세액을 직접 적어 이번 연말정산 결과를 기록한다. 모두 기기 안에서 처리.
/// (빠진 공제 진단은 '빠진 공제 항목 찾기' 단계가 전담 — 여기서는 기록만 한다.)
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

  // 추출값 편집 — 파서가 잘못 읽은 값을 사용자가 보정(잘못된 기록 방지)
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();
    // 기본 직접 입력 모드 — 저장 경로 활성화를 위해 빈 객체 시드
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

  /// 편집된 값으로 재구성한 원천징수 (보정 반영).
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

  // 신고된 연말정산 결과 장부
  List<Map<String, dynamic>> _asFiledItems(WithholdingReceipt w) => [
        {'title': '총급여액 (수입금액)', 'amount': w.grossSalary.toDouble(), 'isHeader': true},
        {'title': '(-) 근로소득공제', 'amount': w.laborDeduction.toDouble()},
        {'title': '(=) 과세표준', 'amount': w.taxableBase.toDouble(), 'isHeader': true, 'highlight': true},
        {'title': '(×) 산출세액', 'amount': w.calculatedTax.toDouble()},
        {'title': '(=) 결정세액', 'amount': w.decidedTax.toDouble(), 'isHeader': true, 'highlight': true},
        {'title': '(-) 기납부세액', 'amount': w.paidTax.toDouble()},
      ];

  Future<void> _save() async {
    final w = _effWh();
    // 진단·자동기입용 원시값 영속화 — PDF 간소화 파싱값은 실제 지출 가능액이라
    // 빠진 공제 진단·합산진단이 그대로 당겨 쓴다. 수기 모드에선 이 키들이 0.
    await dbService.saveAnnualRecord(widget.userType, {
      'grossSalary': _v('salary'),
      'decidedTax': _v('decided'),
      'creditCard': _v('av_card'),
      'debitCash': _v('av_debit'),
      'medical': _v('av_med'),
      'education': _v('av_edu'),
      'donation': _v('av_don'),
      'lifeInsurance': _v('av_life'),
      'pensionSavings': _v('av_pen'),
      'rent': _v('av_rent'),
    });
    await dbService.saveReportDraft(widget.userType,
        reportType: '연말정산', items: _asFiledItems(w), finalAmount: w.finalSettlement.toDouble(), isRefund: w.isRefund);
    if (mounted) Navigator.pop(context, true);
  }

  String _won(int v) => '${_fmt.format(v)}원';

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final w = _wh;
    final g = _ganso;

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
            Text(_manualMode ? '연말정산 결과를\n기록해요' : '홈택스 PDF로\n한 번에 기록',
                style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),
            const SizedBox(height: 10),
            Text(_manualMode
                ? '총급여와 결정세액을 적어 이번 연말정산 결과를 남겨두세요. 빠진 공제는 다음 단계에서 찾아드려요. 모두 기기 안에서만 처리돼요.'
                : '홈택스에서 받은 간소화 자료·원천징수영수증 PDF를 올리면 값을 자동으로 채워요. 모두 기기 안에서만 처리돼요.',
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
                hint: '총급여·결정세액·신고한 공제',
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

            // ── 저장 (수기: 항상 / PDF: 원천징수 파싱 후) ──
            if (w != null) ...[
              const SizedBox(height: 28),
              _saveButton(),
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
          // 직접 입력 모드 진입 — 빈 객체 시드로 저장 경로 활성화
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

  /// 직접 입력 패널 — 총급여·결정세액만 기록(빠진 공제 진단은 다음 단계 전담).
  Widget _manualSection() {
    final sub = AppTheme.inkSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('핵심 항목'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 8),
        Text('총급여와 결정세액은 원천징수영수증에서 확인할 수 있어요.'.keepWords,
            style: AppTheme.sans(13, sub, height: 1.45)),
        const SizedBox(height: 16),
        _manualRow('총급여', 'salary'),
        _manualRow('결정세액', 'decided'),
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

  /// 추출값 확인·보정 — 파서가 읽은 값을 사용자가 검토·수정.
  Widget _confirmSection() {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('추출값 확인·보정'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 8),
        Text('PDF에서 읽은 값이에요. 다르면 고쳐주세요.'.keepWords, style: AppTheme.sans(13, sub, height: 1.45)),
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

  /// 공용 액수 입력칸.
  Widget _amount(String key, {bool expand = false, double width = 150}) {
    return AmountField(
      controller: _ctrl(key),
      expand: expand,
      width: width,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _saveButton() {
    final bg = AppTheme.backgroundColor(context);
    return GestureDetector(
      onTap: _save,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppTheme.ink(context), borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('연말정산 결과 저장',
              style: AppTheme.sans(15, bg, weight: FontWeight.w700)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 16, color: bg),
        ]),
      ),
    );
  }
}
