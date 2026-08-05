import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/expense_category.dart';
import '../../core/data/expense_item.dart';
import '../../core/data/income_entry.dart';
import '../../core/data/ledger_profile.dart';
import '../../core/data/quick_entry_preset.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

const _incomeColor = Color(0xFF5CB87A); // 수익 — soft green
const _catCredit = '신용카드';
const _catDebit  = '체크+현금';
const _catOther  = '기타';

/// 하루(또는 여러 날 묶음)의 수입·지출을 입력/수정하는 풀스크린 화면.
/// 캘린더 화면과 분리된 자체 스크롤·자체 상태를 가져 "입력창이 화면 밖으로 스크롤되는" 문제를 원천적으로 없앤다.
class DayEntryScreen extends StatefulWidget {
  final Set<DateTime> dates;
  final String userType;
  final bool hasExisting;
  final String initialIncomeText;
  final String initialIncomeType;
  final bool initialIncomeWithheld;
  final String initialCreditText;
  final String initialCreditCategory;
  final bool initialCreditBusiness;
  final String initialDebitText;
  final String initialDebitCategory;
  final bool initialDebitBusiness;
  final String initialOtherText;
  final String initialOtherCategory;
  final bool initialOtherBusiness;
  final Map<String, List<IncomeEntry>> incomesByDay;
  final Map<String, List<ExpenseItem>> expensesByDay;

  const DayEntryScreen({
    super.key,
    required this.dates,
    required this.userType,
    required this.hasExisting,
    required this.initialIncomeText,
    required this.initialIncomeType,
    required this.initialIncomeWithheld,
    required this.initialCreditText,
    required this.initialCreditCategory,
    required this.initialCreditBusiness,
    required this.initialDebitText,
    required this.initialDebitCategory,
    required this.initialDebitBusiness,
    required this.initialOtherText,
    required this.initialOtherCategory,
    required this.initialOtherBusiness,
    required this.incomesByDay,
    required this.expensesByDay,
  });

  @override
  State<DayEntryScreen> createState() => _DayEntryScreenState();
}

class _DayEntryScreenState extends State<DayEntryScreen> {
  late final _incomeCtrl = TextEditingController(text: widget.initialIncomeText);
  late final _creditCtrl = TextEditingController(text: widget.initialCreditText);
  late final _debitCtrl  = TextEditingController(text: widget.initialDebitText);
  late final _otherCtrl  = TextEditingController(text: widget.initialOtherText);

  late final LedgerProfile _profile = LedgerProfile.of(widget.userType);

  late String _incomeType = widget.initialIncomeType;
  late bool _incomeIsWithheld = widget.initialIncomeWithheld;
  late String _creditCategory = widget.initialCreditCategory;
  late String _debitCategory  = widget.initialDebitCategory;
  late String _otherCategory  = widget.initialOtherCategory;
  late bool _creditIsBusiness = widget.initialCreditBusiness;
  late bool _debitIsBusiness  = widget.initialDebitBusiness;
  late bool _otherIsBusiness  = widget.initialOtherBusiness;

  final _fmt = NumberFormat('#,###');

  List<QuickEntryPreset> _presets = [];

  @override
  void initState() {
    super.initState();
    _incomeCtrl.addListener(_onIncomeChanged);
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final list = await dbService.getQuickEntryPresets();
    if (mounted) setState(() => _presets = list);
  }

  /// 즐겨찾기 프리셋을 결제수단에 맞는 행에 채운다.
  void _applyPreset(QuickEntryPreset p) {
    setState(() {
      final amountText = _fmt.format(p.amount);
      switch (p.paymentMethod) {
        case _catCredit:
          _creditCtrl.text = amountText;
          _creditCategory = p.category;
          if (_profile.tracksBusinessExpense) _creditIsBusiness = p.isBusiness;
          break;
        case _catDebit:
          _debitCtrl.text = amountText;
          _debitCategory = p.category;
          if (_profile.tracksBusinessExpense) _debitIsBusiness = p.isBusiness;
          break;
        default:
          _otherCtrl.text = amountText;
          _otherCategory = p.category;
          if (_profile.tracksBusinessExpense) _otherIsBusiness = p.isBusiness;
      }
    });
  }

  Future<void> _showAddPresetDialog() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String paymentMethod = _catCredit;
    String category = '기타';
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final bg = AppTheme.backgroundColor(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: line),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          title: Text('즐겨찾기 추가', style: AppTheme.serif(17, ink)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: AppTheme.sans(15, ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '이름 (예: 아메리카노)',
                    hintStyle: AppTheme.sans(15, AppTheme.inkTertiary(ctx)),
                    border: UnderlineInputBorder(borderSide: BorderSide(color: line)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: line)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: AppTheme.sans(15, ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '금액',
                    hintStyle: AppTheme.sans(15, AppTheme.inkTertiary(ctx)),
                    suffixText: '원',
                    border: UnderlineInputBorder(borderSide: BorderSide(color: line)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: line)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent, width: 1.5)),
                  ),
                  onChanged: (v) {
                    final n = v.replaceAll(RegExp(r'[^0-9]'), '');
                    final f = n.isEmpty ? '' : _fmt.format(int.parse(n));
                    amountCtrl.value = TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
                  },
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [_catCredit, _catDebit, _catOther].map((pm) {
                    final sel = paymentMethod == pm;
                    return GestureDetector(
                      onTap: () => setDialogState(() => paymentMethod = pm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? accent.withValues(alpha: 0.15) : Colors.transparent,
                          border: Border.all(color: sel ? accent : line, width: sel ? 1.4 : 1.0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(pm,
                            style: AppTheme.sans(12, sel ? ink : sub,
                                weight: sel ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kExpenseCategories.map((cat) {
                    final sel = category == cat.id;
                    return GestureDetector(
                      onTap: () => setDialogState(() => category = cat.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? cat.color.withValues(alpha: 0.15) : Colors.transparent,
                          border: Border.all(color: sel ? cat.color : line, width: sel ? 1.4 : 1.0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(cat.icon, size: 13, color: sel ? cat.color : sub),
                          const SizedBox(width: 4),
                          Text(cat.label,
                              style: AppTheme.sans(12, sel ? ink : sub,
                                  weight: sel ? FontWeight.w700 : FontWeight.w500)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx, false),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 8, 12),
                child: Text('취소', style: AppTheme.sans(14, sub)),
              ),
            ),
            GestureDetector(
              onTap: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                child: Text('저장', style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final amount = int.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0;
      await dbService.insertQuickEntryPreset(QuickEntryPreset(
        id: 0,
        name: nameCtrl.text.trim(),
        amount: amount,
        category: category,
        paymentMethod: paymentMethod,
        sortOrder: _presets.length,
      ));
      await _loadPresets();
    }
    nameCtrl.dispose();
    amountCtrl.dispose();
  }

  Future<void> _confirmDeletePreset(QuickEntryPreset p) async {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('즐겨찾기 삭제', style: AppTheme.sans(16, ink, weight: FontWeight.w700)),
        content: Text('"${p.name}"을(를) 삭제할까요?'.keepWords, style: AppTheme.sans(14, sub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: AppTheme.sans(14, sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('삭제', style: AppTheme.sans(14, AppTheme.colorDanger, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await dbService.deleteQuickEntryPreset(p.id);
      await _loadPresets();
    }
  }

  void _onIncomeChanged() {
    if (_profile.tracksBusinessExpense && _incomeIsWithheld) setState(() {});
  }

  @override
  void dispose() {
    _incomeCtrl.removeListener(_onIncomeChanged);
    _incomeCtrl.dispose();
    _creditCtrl.dispose();
    _debitCtrl.dispose();
    _otherCtrl.dispose();
    super.dispose();
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── 저장 / 삭제 ──────────────────────────────────────────────────

  Future<void> _save() async {
    final inc = int.tryParse(_incomeCtrl.text.replaceAll(',', '')) ?? 0;
    final cr  = int.tryParse(_creditCtrl.text.replaceAll(',', '')) ?? 0;
    final db  = int.tryParse(_debitCtrl.text.replaceAll(',', '')) ?? 0;
    final ot  = int.tryParse(_otherCtrl.text.replaceAll(',', '')) ?? 0;

    final sorted = widget.dates.toList()..sort();
    final first = sorted.first;
    final last  = sorted.last;
    final isRange = sorted.length > 1;
    final endDate = isRange ? last : null;

    final removedInc = <String>{};
    final removedExp = <String>{};
    for (final date in widget.dates) {
      final key = _key(date);
      for (final e in (widget.incomesByDay[key] ?? const [])) {
        if (removedInc.add(e.id)) {
          await dbService.deleteIncomeEntry(e.id, e.date.year, e.date.month);
        }
      }
      for (final e in (widget.expensesByDay[key] ?? const [])) {
        if (removedExp.add(e.id)) {
          await dbService.deleteExpense(e.id);
        }
      }
    }

    final batch = DateTime.now().microsecondsSinceEpoch;
    final prefix = 'b${batch}_${_key(first)}';
    if (inc > 0) {
      await dbService.insertIncomeEntry(IncomeEntry(
        id: '${prefix}_inc', date: first, endDate: endDate, amount: inc, memo: '',
        incomeType: _incomeType,
        isWithheld: _profile.tracksBusinessExpense && _incomeType != '급여' && _incomeIsWithheld,
        userType: widget.userType));
    }
    if (cr > 0) {
      await dbService.insertExpense(ExpenseItem(
        id: '${prefix}_cr', date: first, endDate: endDate, amount: cr,
        content: '', category: _creditCategory, paymentMethod: _catCredit,
        isBusiness: _profile.tracksBusinessExpense && _creditIsBusiness,
        userType: widget.userType));
    }
    if (db > 0) {
      await dbService.insertExpense(ExpenseItem(
        id: '${prefix}_db', date: first, endDate: endDate, amount: db,
        content: '', category: _debitCategory, paymentMethod: _catDebit,
        isBusiness: _profile.tracksBusinessExpense && _debitIsBusiness,
        userType: widget.userType));
    }
    if (ot > 0) {
      await dbService.insertExpense(ExpenseItem(
        id: '${prefix}_ot', date: first, endDate: endDate, amount: ot,
        content: '', category: _otherCategory, paymentMethod: _catOther,
        isBusiness: _profile.tracksBusinessExpense && _otherIsBusiness,
        userType: widget.userType));
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    for (final date in widget.dates) {
      final key = _key(date);
      for (final e in (widget.incomesByDay[key] ?? const [])) {
        await dbService.deleteIncomeEntry(e.id, date.year, date.month);
      }
      for (final e in (widget.expensesByDay[key] ?? const []).toSet()) {
        await dbService.deleteExpense(e.id);
      }
    }
    if (mounted) Navigator.pop(context);
  }

  // ── 즐겨찾기 프리셋 ────────────────────────────────────────────────

  Widget _buildPresetRow(Color ink, Color sub, Color accent, Color line) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final p in _presets)
          GestureDetector(
            onTap: () => _applyPreset(p),
            onLongPress: () => _confirmDeletePreset(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: line, width: 1.0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(expenseCategoryById(p.category).icon, size: 13, color: sub),
                const SizedBox(width: 4),
                Text(p.name, style: AppTheme.sans(12, ink, weight: FontWeight.w600)),
                const SizedBox(width: 4),
                Text('${_fmt.format(p.amount)}원', style: AppTheme.sans(11, sub)),
              ]),
            ),
          ),
        GestureDetector(
          onTap: _showAddPresetDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: accent, width: 1.0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 13, color: accent),
              const SizedBox(width: 4),
              Text('즐겨찾기', style: AppTheme.sans(12, accent, weight: FontWeight.w600)),
            ]),
          ),
        ),
      ],
    );
  }

  // ── build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final bg  = AppTheme.backgroundColor(context);
    final accent = AppTheme.accentColor(context);
    final line = AppTheme.line(context);

    final sorted = widget.dates.toList()..sort();
    final isRange = sorted.length > 1;
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    final title = isRange
        ? '${sorted.first.month}월 ${sorted.first.day}일 – ${sorted.last.month}월 ${sorted.last.day}일'
        : '${sorted.first.month}월 ${sorted.first.day}일 (${wd[sorted.first.weekday - 1]})';

    Widget sectionEyebrow(IconData icon, String label, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: AppTheme.sans(11, color, weight: FontWeight.w700, spacing: 0.6)),
      ],
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(title, style: AppTheme.serif(20, ink, weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 수익 ───────────────────────────
              sectionEyebrow(Icons.arrow_upward_rounded, '수익', _incomeColor),
              const SizedBox(height: 8),
              _BlueprintAmountField(label: '', ctrl: _incomeCtrl, color: _incomeColor, fmt: _fmt),
              const SizedBox(height: 8),
              _incomeTypeToggle(sub),
              if (_profile.tracksBusinessExpense && _incomeType != '급여') _withheldToggle(ink, sub),
              const SizedBox(height: 18),

              // ── 지출 ───────────────────────────
              sectionEyebrow(Icons.arrow_downward_rounded, '지출', accent),
              const SizedBox(height: 8),
              _buildPresetRow(ink, sub, accent, line),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: line, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: _PaymentCategoryRow(
                      label: '신용카드', ctrl: _creditCtrl, fmt: _fmt,
                      category: _creditCategory,
                      onCategoryChanged: (v) => setState(() => _creditCategory = v),
                      showBottomBorder: false,
                      isBusiness: _profile.tracksBusinessExpense ? _creditIsBusiness : null,
                      onBusinessChanged: (v) => setState(() => _creditIsBusiness = v),
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: _PaymentCategoryRow(
                      label: '체크/현금', ctrl: _debitCtrl, fmt: _fmt,
                      category: _debitCategory,
                      onCategoryChanged: (v) => setState(() => _debitCategory = v),
                      showBottomBorder: false,
                      isBusiness: _profile.tracksBusinessExpense ? _debitIsBusiness : null,
                      onBusinessChanged: (v) => setState(() => _debitIsBusiness = v),
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: _PaymentCategoryRow(
                      label: '기타', ctrl: _otherCtrl, fmt: _fmt,
                      category: _otherCategory,
                      onCategoryChanged: (v) => setState(() => _otherCategory = v),
                      showBottomBorder: false,
                      isBusiness: _profile.tracksBusinessExpense ? _otherIsBusiness : null,
                      onBusinessChanged: (v) => setState(() => _otherIsBusiness = v),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          // Row+Expanded를 bottomNavigationBar에 높이 제약 없이 직접 두면 flutter web에서
          // body/appBar까지 통째로 렌더링되지 않는 문제가 있어 SizedBox로 높이를 고정한다.
          child: SizedBox(
            height: 48,
            child: Row(children: [
              if (widget.hasExisting) ...[
                GestureDetector(
                  onTap: _delete,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.colorDanger, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('삭제',
                        style: AppTheme.sans(13, AppTheme.colorDanger, weight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: _save,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(widget.hasExisting ? '수정' : '저장',
                        style: AppTheme.sans(14, bg, weight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _incomeTypeToggle(Color sub) {
    final String hint;
    switch (_incomeType) {
      case '급여':
        hint = '근로소득 — 회사 월급·상여. 연말정산으로 정산돼요.';
        break;
      case '사업소득':
        hint = '사업소득 — 계속·반복적인 용역. 3.3% 원천징수(소득세 3%+지방소득세 0.3%).';
        break;
      case '기타소득':
        hint = '기타소득 — 강연료·원고료 등 일시적인 용역. 8.8% 원천징수(필요경비 60% 자동 인정).';
        break;
      default:
        hint = '기타 수익 — 5월 종합소득세에 합산돼요.'; // 과거 기록 호환(레거시 '기타')
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 58,
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text('구분', style: AppTheme.sans(13, sub, weight: FontWeight.w600)),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _profile.incomeTypes)
                    _incomeTypeChip(t == '급여' ? '근로소득' : t, t),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 58),
          child: Text(hint, textAlign: TextAlign.left, style: AppTheme.sans(12, sub, height: 1.4)),
        ),
      ],
    );
  }

  /// 원천징수 토글 — 프리랜서(사업소득 3.3%·기타소득 8.8%)·N잡러의 '기타 수익'(3.3%)에서 노출.
  Widget _withheldToggle(Color ink, Color sub) {
    final isOtherIncome = _incomeType == '기타소득';
    final rateLabel = isOtherIncome ? '8.8%' : '3.3%';
    final divisor = isOtherIncome ? 0.912 : 0.967;
    final raw = int.tryParse(_incomeCtrl.text.replaceAll(',', '')) ?? 0;
    final gross = raw > 0 ? (raw / divisor).round() : 0;
    return Padding(
      padding: const EdgeInsets.only(left: 58, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _incomeIsWithheld = !_incomeIsWithheld),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _incomeIsWithheld ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 16,
                  color: _incomeIsWithheld ? _incomeColor : sub,
                ),
                const SizedBox(width: 6),
                Text('$rateLabel 원천징수 (세후 실수령액으로 입력)'.keepWords,
                    style: AppTheme.sans(12, _incomeIsWithheld ? ink : sub, weight: FontWeight.w600)),
              ],
            ),
          ),
          if (_incomeIsWithheld && raw > 0) ...[
            const SizedBox(height: 4),
            Text('세전 금액(추정) ${_fmt.format(gross)}원'.keepWords,
                style: AppTheme.sans(12, sub, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _incomeTypeChip(String label, String type) {
    final selected = _incomeType == type;
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return GestureDetector(
      onTap: () => setState(() {
        _incomeType = type;
        // 사업/기타소득 선택 시 원천징수(세후 입력)를 기본으로 켠다 — 통장엔 이미 뗀 돈이 들어오므로.
        if (type != '급여') _incomeIsWithheld = true;
      }),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _incomeColor.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? _incomeColor : AppTheme.line(context),
            width: selected ? 1.4 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AppTheme.sans(12, selected ? ink : sub,
                weight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

// ── 금액 입력 필드 — 레이블 고정 너비 58px, 항목 색으로 포커스 표시 ──
class _BlueprintAmountField extends StatefulWidget {
  final String label;
  final TextEditingController ctrl;
  final Color color;
  final NumberFormat fmt;

  const _BlueprintAmountField({
    required this.label,
    required this.ctrl,
    required this.color,
    required this.fmt,
  });

  @override
  State<_BlueprintAmountField> createState() => _BlueprintAmountFieldState();
}

class _BlueprintAmountFieldState extends State<_BlueprintAmountField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final focused = _focus.hasFocus;
    final lineColor  = focused ? widget.color : AppTheme.line(context);
    final labelColor = focused ? widget.color : sub;

    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lineColor, width: focused ? 1.6 : 1.0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.label.isNotEmpty)
            SizedBox(
              width: 58,
              child: Text(widget.label,
                  style: AppTheme.sans(13, labelColor, weight: FontWeight.w600)),
            ),
          if (widget.label.isNotEmpty)
            Expanded(
              flex: 2,
              child: _amountField(context, ink),
            )
          else
            Expanded(child: _amountField(context, ink)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text('원', style: AppTheme.sans(widget.label.isEmpty ? 13 : 12, sub)),
          ),
          if (widget.label.isNotEmpty) const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _amountField(BuildContext context, Color ink) {
    final fs = widget.label.isEmpty ? 22.0 : 18.0;
    return TextField(
      controller: widget.ctrl,
      focusNode: _focus,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.right,
      cursorColor: widget.color,
      style: AppTheme.sans(fs, ink, weight: FontWeight.w700),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        hintText: '0',
        hintStyle: AppTheme.sans(fs, AppTheme.inkTertiary(context), weight: FontWeight.w300),
      ),
      onChanged: (v) {
        final n = v.replaceAll(RegExp(r'[^0-9]'), '');
        final f = n.isEmpty ? '' : widget.fmt.format(int.parse(n));
        if (f != widget.ctrl.text) {
          widget.ctrl.value = TextEditingValue(
            text: f, selection: TextSelection.collapsed(offset: f.length));
        }
      },
    );
  }
}

// ── 결제수단별 금액 + 카테고리 compact 행 ────────────────────────────
class _PaymentCategoryRow extends StatefulWidget {
  final String label;
  final TextEditingController ctrl;
  final NumberFormat fmt;
  final String category;
  final ValueChanged<String> onCategoryChanged;
  final bool showBottomBorder;
  /// null이면 사업경비 토글 숨김(직장인 등) — 프리랜서·N잡러만 값을 전달.
  final bool? isBusiness;
  final ValueChanged<bool>? onBusinessChanged;

  const _PaymentCategoryRow({
    required this.label,
    required this.ctrl,
    required this.fmt,
    required this.category,
    required this.onCategoryChanged,
    this.showBottomBorder = true,
    this.isBusiness,
    this.onBusinessChanged,
  });

  @override
  State<_PaymentCategoryRow> createState() => _PaymentCategoryRowState();
}

class _PaymentCategoryRowState extends State<_PaymentCategoryRow> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ink = AppTheme.ink(ctx);
        final sub = AppTheme.inkSecondary(ctx);
        final bg  = AppTheme.backgroundColor(ctx);
        final line = AppTheme.line(ctx);
        return AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: line),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          title: Text('${widget.label} 카테고리'.keepWords, style: AppTheme.serif(17, ink)),
          content: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kExpenseCategories.map((cat) {
              final sel = widget.category == cat.id;
              return GestureDetector(
                onTap: () => Navigator.of(ctx).pop(cat.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? cat.color.withValues(alpha: 0.15) : Colors.transparent,
                    border: Border.all(
                      color: sel ? cat.color : line,
                      width: sel ? 1.4 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(cat.icon, size: 13, color: sel ? cat.color : sub),
                    const SizedBox(width: 4),
                    Text(cat.label,
                        style: AppTheme.sans(12, sel ? ink : sub,
                            weight: sel ? FontWeight.w700 : FontWeight.w500)),
                  ]),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
    if (picked != null) widget.onCategoryChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final cat = expenseCategoryById(widget.category);
    final focused = _focus.hasFocus;
    final isEmpty = widget.ctrl.text.isEmpty || widget.ctrl.text == '0';
    final lineColor = focused ? cat.color : AppTheme.line(context);
    final labelColor = focused ? cat.color : sub;

    final amountBox = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: lineColor, width: focused ? 1.4 : 1.0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.ctrl,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              cursorColor: cat.color,
              style: AppTheme.sans(16, ink, weight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '0',
                hintStyle: AppTheme.sans(16, AppTheme.inkTertiary(context), weight: FontWeight.w300),
              ),
              onChanged: (v) {
                final n = v.replaceAll(RegExp(r'[^0-9]'), '');
                final f = n.isEmpty ? '' : widget.fmt.format(int.parse(n));
                if (f != widget.ctrl.text) {
                  widget.ctrl.value = TextEditingValue(
                    text: f, selection: TextSelection.collapsed(offset: f.length));
                }
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(width: 4),
          Text('원', style: AppTheme.sans(12, sub)),
        ],
      ),
    );

    final categoryBox = GestureDetector(
      onTap: _pickCategory,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isEmpty ? 0.35 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isEmpty ? Colors.transparent : cat.color.withValues(alpha: 0.12),
            border: Border.all(
              color: isEmpty ? AppTheme.line(context) : cat.color.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(cat.icon, size: 13, color: isEmpty ? sub : cat.color),
            const SizedBox(width: 4),
            Text(cat.label,
                style: AppTheme.sans(12, isEmpty ? sub : cat.color,
                    weight: FontWeight.w600)),
          ]),
        ),
      ),
    );

    final innerRow = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 58,
            child: Text(widget.label,
                style: AppTheme.sans(13, labelColor, weight: FontWeight.w600)),
          ),
          Expanded(flex: 3, child: amountBox),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: categoryBox),
        ],
    );

    Widget content = innerRow;
    if (widget.isBusiness != null) {
      final biz = widget.isBusiness!;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          innerRow,
          const SizedBox(height: 6),
          Opacity(
            opacity: isEmpty ? 0.35 : 1.0,
            child: Padding(
              padding: const EdgeInsets.only(left: 58),
              child: GestureDetector(
                onTap: () => widget.onBusinessChanged?.call(!biz),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      biz ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 15,
                      color: biz ? cat.color : sub,
                    ),
                    const SizedBox(width: 5),
                    Text('사업경비로 인정',
                        style: AppTheme.sans(11.5, biz ? ink : sub, weight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!widget.showBottomBorder) return content;

    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lineColor, width: focused ? 1.6 : 1.0)),
      ),
      child: content,
    );
  }
}
