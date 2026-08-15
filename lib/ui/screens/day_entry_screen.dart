import 'package:flutter/material.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/expense_category.dart';
import '../../core/data/expense_item.dart';
import '../../core/data/income_entry.dart';
import '../../core/data/ledger_profile.dart';
import '../../core/data/quick_entry_preset.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

const _catCredit = '신용카드';
const _catDebit = '체크+현금';
const _catOther = '기타';
const _payments = [_catCredit, _catDebit, _catOther];

/// 하루(또는 여러 날 묶음)의 수입·지출 **목록** 화면.
///
/// 예전에는 입력칸이 고정 4개(수익 1 + 결제수단 3)였다. 같은 날 신용카드로
/// 식비와 교통을 따로 쓰면 하나밖에 못 적었고, 더 나쁜 건 저장이
/// **그날 기록을 전부 지우고 4칸을 다시 넣는** 방식이라 고정지출 등 다른
/// 경로로 들어온 기록이 조용히 사라졌다.
///
/// 그래서 화면을 목록으로 바꾸고 **항목 단위로 즉시 쓴다**. 일괄 저장 버튼이
/// 없으니 "전부 지우고 다시 넣기"가 코드에 존재할 자리가 없다.
///
/// 입력은 **목록 안에서 펼친다**(inline expand). 앱 하드 제약이 바텀시트 금지라
/// 그렇기도 하고, 하루치를 연달아 적을 때 화면이 안 바뀌는 쪽이 훨씬 빠르다 —
/// 적은 것이 바로 위에 쌓이는 게 보이니 뭘 넣었는지 확인하러 나갈 일이 없다.
///
/// 여러 날을 고르면 **각 날짜에 항목을 하나씩** 만든다. 예전의 기간 항목
/// (`endDate`)은 금액 전부를 첫날에 몰아 넣고 달력에만 걸쳐 보이게 해서,
/// 12/28~1/3 여행이면 1월 몫까지 12월 지출로 집계됐다. 새로 만들지 않는다.
/// 이미 있는 기간 기록은 그대로 보이고 수정·삭제된다.
class DayEntryScreen extends StatefulWidget {
  final Set<DateTime> dates;
  final String userType;
  final Map<String, List<IncomeEntry>> incomesByDay;
  final Map<String, List<ExpenseItem>> expensesByDay;

  const DayEntryScreen({
    super.key,
    required this.dates,
    required this.userType,
    required this.incomesByDay,
    required this.expensesByDay,
  });

  @override
  State<DayEntryScreen> createState() => _DayEntryScreenState();
}

class _DayEntryScreenState extends State<DayEntryScreen> {
  late final LedgerProfile _profile = LedgerProfile.of(widget.userType);

  /// 지금 펼쳐 둔 편집기. `'inc'`/`'exp'`는 새로 추가, 그 외에는 그 항목의 id.
  /// 한 번에 하나만 연다 — 둘이 열려 있으면 어느 쪽을 저장하는지 알 수 없다.
  String? _open;
  QuickEntryPreset? _pendingPreset;
  final _openKey = GlobalKey();

  final List<IncomeEntry> _incomes = [];
  final List<ExpenseItem> _expenses = [];
  List<QuickEntryPreset> _presets = [];

  List<DateTime> get _dates => widget.dates.toList()..sort();
  bool get _isMulti => widget.dates.length > 1;

  @override
  void initState() {
    super.initState();
    _collect();
    _loadPresets();
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 고른 날짜들의 기록을 모은다. 기간 항목은 여러 날에 걸쳐 같은 id로 잡히므로
  /// id로 걸러 한 번만 담는다.
  void _collect() {
    final seenInc = <String>{}, seenExp = <String>{};
    _incomes.clear();
    _expenses.clear();
    for (final d in _dates) {
      for (final e in (widget.incomesByDay[_key(d)] ?? const <IncomeEntry>[])) {
        if (seenInc.add(e.id)) _incomes.add(e);
      }
      for (final e in (widget.expensesByDay[_key(d)] ?? const <ExpenseItem>[])) {
        if (seenExp.add(e.id)) _expenses.add(e);
      }
    }
    _incomes.sort((a, b) => a.date.compareTo(b.date));
    _expenses.sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> _loadPresets() async {
    final list = await dbService.getQuickEntryPresets();
    if (mounted) setState(() => _presets = list);
  }

  String _newId(DateTime d) =>
      '${DateTime.now().microsecondsSinceEpoch}_${_key(d)}_${_expenses.length + _incomes.length}';

  // ── 쓰기 — 전부 항목 하나씩. 통째로 지우는 경로는 없다. ────────────────

  Future<void> _addExpense(_ExpenseDraft dr) async {
    for (final d in _dates) {
      final item = ExpenseItem(
        id: _newId(d),
        date: d,
        amount: dr.amount,
        content: dr.content,
        category: dr.category,
        paymentMethod: dr.paymentMethod,
        isBusiness: dr.isBusiness,
        userType: widget.userType,
      );
      await dbService.insertExpense(item);
      _expenses.add(item);
    }
    if (mounted) setState(() {});
  }

  Future<void> _updateExpense(ExpenseItem old, _ExpenseDraft dr) async {
    // endDate는 건드리지 않는다 — 옛 기간 기록을 수정해도 성격이 바뀌면 안 된다.
    final item = old.copyWith(
      amount: dr.amount,
      content: dr.content,
      category: dr.category,
      paymentMethod: dr.paymentMethod,
      isBusiness: dr.isBusiness,
    );
    await dbService.updateExpense(item);
    if (!mounted) return;
    setState(() => _expenses[_expenses.indexWhere((e) => e.id == old.id)] = item);
  }

  Future<void> _deleteExpense(ExpenseItem e) async {
    await dbService.deleteExpense(e.id);
    if (!mounted) return;
    setState(() => _expenses.removeWhere((x) => x.id == e.id));
  }

  Future<void> _addIncome(_IncomeDraft dr) async {
    for (final d in _dates) {
      final item = IncomeEntry(
        id: _newId(d),
        date: d,
        amount: dr.amount,
        memo: dr.memo,
        incomeType: dr.incomeType,
        isWithheld: dr.isWithheld,
        userType: widget.userType,
      );
      await dbService.insertIncomeEntry(item);
      _incomes.add(item);
    }
    if (mounted) setState(() {});
  }

  Future<void> _updateIncome(IncomeEntry old, _IncomeDraft dr) async {
    final item = old.copyWith(
      amount: dr.amount,
      memo: dr.memo,
      incomeType: dr.incomeType,
      isWithheld: dr.isWithheld,
    );
    await dbService.updateIncomeEntry(item);
    if (!mounted) return;
    setState(() => _incomes[_incomes.indexWhere((e) => e.id == old.id)] = item);
  }

  Future<void> _deleteIncome(IncomeEntry e) async {
    await dbService.deleteIncomeEntry(e.id, e.date.year, e.date.month);
    if (!mounted) return;
    setState(() => _incomes.removeWhere((x) => x.id == e.id));
  }

  // ── 편집기 열고 닫기 ────────────────────────────────────────────────

  void _openEditor(String key, {QuickEntryPreset? preset}) {
    setState(() {
      _open = key;
      _pendingPreset = preset;
    });
    // 펼친 자리가 키보드에 가리지 않게 스크롤을 붙여 준다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _openKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 220), alignment: 0.1);
      }
    });
  }

  void _closeEditor() => setState(() {
        _open = null;
        _pendingPreset = null;
      });

  // ── 화면 ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    final first = _dates.first, last = _dates.last;
    final title = _isMulti
        ? '${first.month}월 ${first.day}일 – ${last.month}월 ${last.day}일'
        : '${first.month}월 ${first.day}일 (${wd[first.weekday - 1]})';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (_isMulti) ...[
              Text('고른 ${widget.dates.length}일에 각각 기록됩니다.'.keepWords,
                  style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkSecondary(context))),
              const SizedBox(height: 14),
            ],
            AppTheme.sectionHead(context, '01', '수익'),
            const SizedBox(height: 10),
            for (final e in _incomes)
              if (_open == e.id)
                _incomeForm(edit: e)
              else
                _row(
                  title: e.memo.isNotEmpty ? e.memo : e.incomeType,
                  sub: [
                    if (e.memo.isNotEmpty) e.incomeType,
                    if (e.isWithheld) '원천징수',
                    if (e.endDate != null) '기간',
                    if (_isMulti) '${e.date.month}/${e.date.day}',
                  ].join(' · '),
                  amount: e.amount,
                  onTap: () => _openEditor(e.id),
                ),
            if (_open == 'inc') _incomeForm() else _addRow('수익 추가하기', () => _openEditor('inc')),
            const SizedBox(height: 18),
            AppTheme.dashRule(context),
            const SizedBox(height: 18),
            AppTheme.sectionHead(context, '02', '지출'),
            const SizedBox(height: 10),
            for (final e in _expenses)
              if (_open == e.id)
                _expenseForm(edit: e)
              else
                _row(
                  title: e.content.isNotEmpty ? e.content : expenseCategoryById(e.category).label,
                  sub: [
                    if (e.content.isNotEmpty) expenseCategoryById(e.category).label,
                    e.paymentMethod,
                    if (e.isBusiness) '사업경비',
                    if (e.endDate != null) '기간',
                    if (_isMulti) '${e.date.month}/${e.date.day}',
                  ].join(' · '),
                  amount: e.amount,
                  onTap: () => _openEditor(e.id),
                ),
            if (_open == 'exp') _expenseForm() else _addRow('지출 추가하기', () => _openEditor('exp')),
            if (_presets.isNotEmpty) ...[
              const SizedBox(height: 18),
              AppTheme.dashRule(context),
              const SizedBox(height: 18),
              AppTheme.sectionHead(context, null, '즐겨찾기'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in _presets)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openEditor('exp', preset: p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.line(context), width: 1),
                        ),
                        child: Text('${p.name} ${comma(p.amount)}',
                            style: AppTheme.sans(AppTheme.tsSM, AppTheme.ink(context))),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 목록 안에서 펼쳐지는 지출 편집기.
  Widget _expenseForm({ExpenseItem? edit}) {
    final preset = _pendingPreset;
    return _ExpenseForm(
      key: _openKey,
      profile: _profile,
      initial: edit == null
          ? _ExpenseDraft(
              amount: preset?.amount ?? 0,
              content: preset?.name ?? '',
              category: preset?.category ?? '기타',
              paymentMethod: preset?.paymentMethod ?? _catCredit,
              isBusiness: false)
          : _ExpenseDraft(
              amount: edit.amount,
              content: edit.content,
              category: edit.category,
              paymentMethod: edit.paymentMethod,
              isBusiness: edit.isBusiness),
      dayCount: edit == null ? widget.dates.length : 1,
      onCancel: _closeEditor,
      onDelete: edit == null
          ? null
          : () async {
              await _deleteExpense(edit);
              _closeEditor();
            },
      onSave: (d) async {
        if (d.amount <= 0) return;
        if (edit == null) {
          await _addExpense(d);
        } else {
          await _updateExpense(edit, d);
        }
        _closeEditor();
      },
    );
  }

  /// 목록 안에서 펼쳐지는 수익 편집기.
  Widget _incomeForm({IncomeEntry? edit}) {
    return _IncomeForm(
      key: _openKey,
      profile: _profile,
      initial: edit == null
          ? _IncomeDraft(
              amount: 0,
              memo: '',
              incomeType: _profile.defaultIncomeType,
              isWithheld: _profile.withholdingDefault)
          : _IncomeDraft(
              amount: edit.amount,
              memo: edit.memo,
              incomeType: edit.incomeType,
              isWithheld: edit.isWithheld),
      dayCount: edit == null ? widget.dates.length : 1,
      onCancel: _closeEditor,
      onDelete: edit == null
          ? null
          : () async {
              await _deleteIncome(edit);
              _closeEditor();
            },
      onSave: (d) async {
        if (d.amount <= 0) return;
        if (edit == null) {
          await _addIncome(d);
        } else {
          await _updateIncome(edit, d);
        }
        _closeEditor();
      },
    );
  }

  /// 기록 한 줄 — 이름, 그 밑에 부속 정보, 오른쪽 끝에 금액. 누르면 고친다.
  Widget _row({
    required String title,
    required String sub,
    required int amount,
    required VoidCallback onTap,
  }) {
    // 한 줄이 한 기록이다 — 이름·부속·금액이 따로 읽히면 목록이 아니라
    // 낱말 더미가 된다. 하나로 묶어 "김밥 5,000, 신용카드, 버튼"으로 읽힌다.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.line(context), width: 1)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.keepWords,
                          style: AppTheme.sans(AppTheme.tsBase, AppTheme.ink(context))),
                      if (sub.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(sub,
                            style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkTertiary(context))),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(comma(amount),
                    style: AppTheme.sans(AppTheme.tsBase, AppTheme.ink(context),
                        weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 아직 안 채운 칸 — 점선. 홈의 지출 목표 빈 칸과 같은 문법.
  Widget _addRow(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(top: 10),
        // '＋'는 전각 기호라 스크린리더가 "더하기"로 읽지 않는다. 라벨을 직접 준다.
        child: Semantics(
          button: true,
          label: label,
          onTap: onTap,
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: AppTheme.dashedBox(
                context,
                child: SizedBox(
                  height: 46,
                  child: Row(children: [
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(label,
                          style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkSecondary(context))),
                    ),
                    Text('＋',
                        style: AppTheme.sans(AppTheme.tsLG, AppTheme.ink(context),
                            weight: FontWeight.w600)),
                    const SizedBox(width: 14),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

// ── 편집 대상 값 ────────────────────────────────────────────────────────

class _ExpenseDraft {
  _ExpenseDraft({
    required this.amount,
    required this.content,
    required this.category,
    required this.paymentMethod,
    required this.isBusiness,
  });
  int amount;
  String content;
  String category;
  String paymentMethod;
  bool isBusiness;
}

class _IncomeDraft {
  _IncomeDraft({
    required this.amount,
    required this.memo,
    required this.incomeType,
    required this.isWithheld,
  });
  int amount;
  String memo;
  String incomeType;
  bool isWithheld;
}

// ── 시트 ───────────────────────────────────────────────────────────────

/// 목록 안에서 펼쳐지는 편집 칸.
///
/// 바텀시트가 아니다 — 앱 하드 제약(바텀시트 금지)이기도 하고, 목록 자리에서
/// 그대로 열려야 방금 적은 항목이 위에 쌓이는 게 보인다. 아직 안 채운 칸이라
/// 테두리는 점선으로 둔다(홈의 빈 칸과 같은 문법).
class _FormBlock extends StatelessWidget {
  const _FormBlock({
    required this.title,
    required this.children,
    required this.onSave,
    required this.onCancel,
    this.onDelete,
    this.note,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final Future<void> Function()? onDelete;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: AppTheme.dashedBox(
        context,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTheme.sectionHead(context, null, title),
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(note!, style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkSecondary(context))),
              ],
              const SizedBox(height: 14),
              ...children,
              Row(children: [
                if (onDelete != null)
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onDelete!(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                        child: Text('삭제',
                            style: AppTheme.sans(AppTheme.tsSM, AppTheme.colorDanger,
                                weight: FontWeight.w600)),
                      ),
                    ),
                  ),
                const Spacer(),
                Semantics(
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onCancel,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Text('취소',
                          style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkSecondary(context))),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Semantics(
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSave,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      alignment: Alignment.center,
                      color: AppTheme.ink(context),
                      child: Text('저장',
                          style: AppTheme.sans(AppTheme.tsSM, AppTheme.backgroundColor(context),
                              weight: FontWeight.w700)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// 편집 칸 안의 한 줄 — 왼쪽 라벨 고정, 오른쪽 내용.
class _Field extends StatelessWidget {
  const _Field(this.label, this.child);
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 74,
            child: Text(label, style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkSecondary(context))),
          ),
          Expanded(child: child),
        ]),
      );

  /// 고르는 칸들 — 분류·결제수단·소득유형이 같은 모양을 쓴다.
  static Widget chips(
      BuildContext context, List<String> labels, String selected, ValueChanged<String> onTap,
      {List<String>? values}) {
    final vals = values ?? labels;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (var i = 0; i < labels.length; i++)
        // 고른 칸인지가 테두리 굵기와 잉크 농도로만 갈린다 — 눈으로 못 보면
        // 무엇을 골랐는지 알 수 없다. selected를 넘겨 "선택됨"으로 읽히게 한다.
        Semantics(
          button: true,
          selected: vals[i] == selected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(vals[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: vals[i] == selected ? AppTheme.accentSoft(context) : null,
                border: Border.all(
                  color: vals[i] == selected ? AppTheme.ink(context) : AppTheme.line(context),
                  width: vals[i] == selected ? 1.5 : 1,
                ),
              ),
              child: Text(labels[i],
                  style: AppTheme.sans(AppTheme.tsSM,
                      vals[i] == selected ? AppTheme.ink(context) : AppTheme.inkTertiary(context),
                      weight: vals[i] == selected ? FontWeight.w700 : FontWeight.w400)),
            ),
          ),
        ),
    ]);
  }
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({
    super.key,
    required this.profile,
    required this.initial,
    required this.dayCount,
    required this.onCancel,
    required this.onSave,
    this.onDelete,
  });
  final LedgerProfile profile;
  final _ExpenseDraft initial;
  final int dayCount;
  final Future<void> Function()? onDelete;
  final VoidCallback onCancel;
  final ValueChanged<_ExpenseDraft> onSave;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  late final _amountCtrl =
      TextEditingController(text: widget.initial.amount > 0 ? comma(widget.initial.amount) : '');
  late final _contentCtrl = TextEditingController(text: widget.initial.content);
  late String _category = widget.initial.category;
  late String _payment = widget.initial.paymentMethod;
  late bool _isBusiness = widget.initial.isBusiness;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cats = kExpenseCategories;
    return _FormBlock(
      title: widget.onDelete == null ? '지출 추가' : '지출 수정',
      note: widget.dayCount > 1 ? '고른 ${widget.dayCount}일에 각각 기록됩니다.' : null,
      onDelete: widget.onDelete,
      onCancel: widget.onCancel,
      onSave: () => widget.onSave(_ExpenseDraft(
        amount: int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
        content: _contentCtrl.text.trim(),
        category: _category,
        paymentMethod: _payment,
        isBusiness: _isBusiness,
      )),
      children: [
        _Field('금액', AmountField(controller: _amountCtrl, expand: true, autofocus: true)),
        _Field(
          '내용',
          TextField(
            controller: _contentCtrl,
            style: AppTheme.sans(AppTheme.tsBase, AppTheme.ink(context)),
            decoration: InputDecoration(
              isDense: true,
              // 비워도 된다 — 목록에서는 분류 이름으로 대신 보인다.
              hintText: '선택 · 예: 한남상회',
              hintStyle: AppTheme.sans(AppTheme.tsBase, AppTheme.inkTertiary(context)),
            ),
          ),
        ),
        _Field(
          '분류',
          _Field.chips(context, [for (final c in cats) c.label], _category,
              (v) => setState(() => _category = v),
              values: [for (final c in cats) c.id]),
        ),
        _Field('결제수단',
            _Field.chips(context, _payments, _payment, (v) => setState(() => _payment = v))),
        if (widget.profile.tracksBusinessExpense)
          _Field(
            '사업경비',
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _isBusiness = !_isBusiness),
              child: Row(children: [
                AppTheme.tick(context, _isBusiness),
                const SizedBox(width: 10),
                Text('경비로 인정', style: AppTheme.sans(AppTheme.tsBase, AppTheme.ink(context))),
              ]),
            ),
          ),
      ],
    );
  }
}

class _IncomeForm extends StatefulWidget {
  const _IncomeForm({
    super.key,
    required this.profile,
    required this.initial,
    required this.dayCount,
    required this.onCancel,
    required this.onSave,
    this.onDelete,
  });
  final LedgerProfile profile;
  final _IncomeDraft initial;
  final int dayCount;
  final Future<void> Function()? onDelete;
  final VoidCallback onCancel;
  final ValueChanged<_IncomeDraft> onSave;

  @override
  State<_IncomeForm> createState() => _IncomeFormState();
}

class _IncomeFormState extends State<_IncomeForm> {
  late final _amountCtrl =
      TextEditingController(text: widget.initial.amount > 0 ? comma(widget.initial.amount) : '');
  late final _memoCtrl = TextEditingController(text: widget.initial.memo);
  late String _type = widget.initial.incomeType;
  late bool _isWithheld = widget.initial.isWithheld;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormBlock(
      title: widget.onDelete == null ? '수익 추가' : '수익 수정',
      note: widget.dayCount > 1 ? '고른 ${widget.dayCount}일에 각각 기록됩니다.' : null,
      onDelete: widget.onDelete,
      onCancel: widget.onCancel,
      onSave: () => widget.onSave(_IncomeDraft(
        amount: int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
        memo: _memoCtrl.text.trim(),
        incomeType: _type,
        isWithheld: _isWithheld,
      )),
      children: [
        _Field('금액', AmountField(controller: _amountCtrl, expand: true, autofocus: true)),
        _Field(
          '내용',
          TextField(
            controller: _memoCtrl,
            style: AppTheme.sans(AppTheme.tsBase, AppTheme.ink(context)),
            decoration: InputDecoration(
              isDense: true,
              hintText: '선택 · 예: 9월 급여',
              hintStyle: AppTheme.sans(AppTheme.tsBase, AppTheme.inkTertiary(context)),
            ),
          ),
        ),
        _Field(
          '소득 유형',
          _Field.chips(
              context, widget.profile.incomeTypes, _type, (v) => setState(() => _type = v)),
        ),
        // 원천징수는 사업·기타소득에만 있다. 급여는 간이세액표라 역산이 안 된다.
        if (widget.profile.tracksBusinessExpense && _type != '급여')
          _Field(
            '원천징수',
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _isWithheld = !_isWithheld),
              child: Row(children: [
                AppTheme.tick(context, _isWithheld),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('세금 떼고 받은 금액'.keepWords,
                      style: AppTheme.sans(AppTheme.tsBase, AppTheme.ink(context))),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
