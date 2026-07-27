import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/recurring_template.dart';
import '../../core/data/expense_item.dart';
import '../../core/data/expense_category.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

const _pmCreditColor = Color(0xFF6B8FD4);
const _pmDebitColor  = Color(0xFFD4A847);
const _pmOtherColor  = Color(0xFF9E9B96);

class RecurringConfirmScreen extends StatefulWidget {
  final int year;
  final int month;

  const RecurringConfirmScreen({
    super.key,
    required this.year,
    required this.month,
  });

  @override
  State<RecurringConfirmScreen> createState() => _RecurringConfirmScreenState();
}

class _RecurringConfirmScreenState extends State<RecurringConfirmScreen> {
  List<Map<String, dynamic>> _allItems = [];
  final Map<int, TextEditingController> _amountCtrls = {};
  // 0=미확인(기본), 1=확인, 2=건너뜀 — pending(DB status==0) 항목에만 적용
  final Map<int, int> _localStatus = {};
  final Map<int, bool> _localIsBusiness = {}; // 템플릿 기본값에서 개별 수정 시에만 존재
  bool _saving = false;
  bool _loaded = false;
  String _userType = '직장인';

  bool get _isBusinessUser => _userType == '프리랜서' || _userType == 'N잡러';

  final _fmt = NumberFormat('#,###');

  final ScrollController _scrollCtrl = ScrollController();
  bool _moreBelow = false; // 목록 아래에 가려진(안 보이는) 항목이 더 있는지

  // 확인 완료 건수: DB confirmed + 로컬 확인 선택
  int get _confirmedCount => _allItems.where((item) {
    final t = item['template'] as RecurringTemplate;
    final dbStatus = item['status'] as int;
    return dbStatus == 1 || (dbStatus == 0 && _localStatus[t.id] == 1);
  }).length;

  int get _totalCount => _allItems.length;

  // 확인된 합계 금액
  int get _confirmedTotal {
    int total = 0;
    for (final item in _allItems) {
      final t = item['template'] as RecurringTemplate;
      final dbStatus = item['status'] as int;
      if (dbStatus == 1) {
        total += (item['actual_amount'] as int? ?? 0);
      } else if (dbStatus == 0 && _localStatus[t.id] == 1) {
        total += int.tryParse(_amountCtrls[t.id]?.text ?? '') ?? t.amountHint;
      }
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_updateMoreBelow);
    // 비동기 로드로 목록이 채워진 뒤 overflow 여부를 판정(작은 화면이면 화살표 노출)
    _load().then((_) {
      if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _updateMoreBelow());
    });
  }

  void _updateMoreBelow() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final more = pos.maxScrollExtent > 0 && pos.pixels < pos.maxScrollExtent - 4;
    if (more != _moreBelow && mounted) setState(() => _moreBelow = more);
  }

  @override
  void dispose() {
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    _scrollCtrl.removeListener(_updateMoreBelow);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await dbService.getProfile();
    // 전체 상태(0/1/2) 로드 — 3가지 상태 시각화를 위해
    final confs = await dbService.getRecurringConfirmations(widget.year, widget.month);
    for (final item in confs) {
      if ((item['status'] as int) == 0) {
        final t = item['template'] as RecurringTemplate;
        _amountCtrls[t.id] ??= TextEditingController(
          text: t.amountHint > 0 ? '${t.amountHint}' : '',
        );
        _localStatus[t.id] ??= 0;
      }
    }
    if (mounted) {
      setState(() {
        _userType = (profile?['user_type'] as String?) ?? '직장인';
        _allItems = confs;
        _loaded = true;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    for (final item in _allItems) {
      final t = item['template'] as RecurringTemplate;
      if ((item['status'] as int) != 0) continue; // 이미 처리된 항목 건너뜀
      final localSt = _localStatus[t.id] ?? 0;

      if (localSt == 2) {
        await dbService.skipRecurring(t.id, widget.year, widget.month);
        continue;
      }
      if (localSt == 1) {
        final amount = int.tryParse(_amountCtrls[t.id]?.text ?? '') ?? t.amountHint;
        if (amount <= 0) {
          await dbService.skipRecurring(t.id, widget.year, widget.month);
          continue;
        }
        final expenseDate = DateTime(
          widget.year,
          widget.month,
          t.dayOfMonth.clamp(1, _daysInMonth(widget.year, widget.month)),
        );
        final expenseId = 'rec_${t.id}_${widget.year}_${widget.month}';
        await dbService.insertExpense(ExpenseItem(
          id: expenseId,
          date: expenseDate,
          amount: amount,
          content: t.name,
          category: t.category,
          paymentMethod: t.paymentMethod,
          isBusiness: _localIsBusiness[t.id] ?? t.isBusiness,
          userType: _userType,
        ));
        await dbService.confirmRecurring(t.id, widget.year, widget.month,
            amount: amount, expenseId: expenseId);
      }
      // localSt==0: 사용자가 선택하지 않은 항목 → 아무것도 안 함
    }
    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    }
  }

  // 탭 → 0(미확인) → 1(확인) → 2(건너뜀) → 0 순환
  // DB 기처리 항목(status≠0)은 탭 불가
  void _toggleStatus(int templateId) {
    final item = _allItems.firstWhere(
      (i) => (i['template'] as RecurringTemplate).id == templateId,
      orElse: () => <String, dynamic>{},
    );
    if (item.isEmpty || (item['status'] as int) != 0) return;
    setState(() {
      final cur = _localStatus[templateId] ?? 0;
      _localStatus[templateId] = (cur + 1) % 3;
    });
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  Color _pmColor(String pm) {
    switch (pm) {
      case '신용카드': return _pmCreditColor;
      case '체크+현금': return _pmDebitColor;
      default:       return _pmOtherColor;
    }
  }

  // ── build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final bg  = AppTheme.backgroundColor(context);

    const monthNames = ['1월', '2월', '3월', '4월', '5월', '6월',
        '7월', '8월', '9월', '10월', '11월', '12월'];
    final monthLabel = monthNames[widget.month - 1];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        title: Text('$monthLabel 고정 지출'.keepWords, style: AppTheme.serif(22, ink)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: AppTheme.hairline(context),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _allItems.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildProgressHeader(),
                    AppTheme.hairline(context),
                    Expanded(
                      child: Stack(
                        children: [
                          ListView.separated(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            itemCount: _allItems.length,
                            separatorBuilder: (_, __) => AppTheme.hairline(context),
                            itemBuilder: (_, i) => _buildLedgerRow(_allItems[i]),
                          ),
                          // 아래에 가려진 항목이 더 있을 때만 페이드 + 화살표로 스크롤 단서를 준다.
                          if (_moreBelow)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                child: Container(
                                  height: 44,
                                  alignment: Alignment.bottomCenter,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
                                        Theme.of(context).scaffoldBackgroundColor,
                                      ],
                                    ),
                                  ),
                                  child: Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 22, color: AppTheme.inkSecondary(context)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _loaded && _allItems.isNotEmpty
          ? _buildBottomBar()
          : null,
    );
  }

  // ── 빈 상태 ──────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final sub  = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_repeat_outlined, size: 36, color: tert),
          const SizedBox(height: 12),
          Text('확인할 항목이 없어요',
              style: AppTheme.sans(15, tert, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('고정 지출 항목을 먼저 등록해두세요.'.keepWords,
              style: AppTheme.sans(13, sub)),
        ],
      ),
    );
  }

  // ── 진행 헤더 — 도면 타이틀 블록 ───────────────────────────────────

  Widget _buildProgressHeader() {
    final tert   = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final count  = _confirmedCount;
    final total  = _totalCount;
    final progress = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('확인 완료', style: AppTheme.label(context)),
              const Spacer(),
              Text('$count', style: AppTheme.serif(22, accent)),
              Text(' / $total', style: AppTheme.serif(22, tert)),
              Text('  건', style: AppTheme.sans(12, tert)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: AppTheme.line(context),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            count == total
                ? '모두 확인했어요. 아래 완료를 눌러 저장하세요.'
                : '항목을 탭해 확인 · 건너뜀을 정하세요.',
            style: AppTheme.sans(12, tert),
          ),
        ],
      ),
    );
  }

  // ── 날짜 스탬프 — 매월 빠져나가는 날 (세리프 숫자) ──────────────────

  Widget _dateStamp(int day, {required bool active}) {
    final ink    = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);
    return Container(
      width: 46,
      padding: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppTheme.line(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('$day', style: AppTheme.serif(22, active ? accent : ink, height: 1.0)),
          const SizedBox(height: 1),
          Text('일', style: AppTheme.sans(11, AppTheme.inkTertiary(context),
              weight: FontWeight.w600, spacing: 1)),
        ],
      ),
    );
  }

  // ── 원장 행 — 한 줄 = 매월 한 건의 고정 지출 ────────────────────────

  Widget _buildLedgerRow(Map<String, dynamic> item) {
    final t        = item['template'] as RecurringTemplate;
    final dbStatus = item['status'] as int;
    final isPending = dbStatus == 0;
    final effectiveStatus = isPending ? (_localStatus[t.id] ?? 0) : dbStatus;
    final cat     = expenseCategoryById(t.category);
    final pmColor = _pmColor(t.paymentMethod);
    final ink     = AppTheme.ink(context);
    final tert    = AppTheme.inkTertiary(context);
    final accent  = AppTheme.accentColor(context);
    final isConfirmed = effectiveStatus == 1;
    final isSkipped   = effectiveStatus == 2;

    // 금액 영역
    Widget amountWidget;
    if (dbStatus == 1) {
      // 이미 등록된 확정 금액 (읽기 전용)
      amountWidget = Text(
        '${_fmt.format(item['actual_amount'] as int? ?? 0)}원',
        style: AppTheme.serif(17, accent, height: 1.0),
        textAlign: TextAlign.right,
      );
    } else if (isSkipped) {
      amountWidget = Text('건너뜀',
          style: AppTheme.sans(12, tert, weight: FontWeight.w500));
    } else {
      // 미확인 / 확인 — 금액 입력 (밑줄형, 가벼운 도면 입력)
      amountWidget = SizedBox(
        width: 96,
        child: TextField(
          controller: _amountCtrls[t.id],
          keyboardType: TextInputType.number,
          inputFormatters: const [ThousandsFormatter()],
          textAlign: TextAlign.right,
          cursorColor: accent,
          style: AppTheme.serif(17, isConfirmed ? accent : ink, height: 1.0),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.only(bottom: 5),
            suffixText: '원',
            suffixStyle: AppTheme.sans(11, tert),
            hintText: '금액',
            hintStyle: AppTheme.sans(13, tert),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.line(context))),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: accent, width: 1.5)),
          ),
        ),
      );
    }

    // 상태 아이콘
    Widget stateIcon;
    if (isConfirmed) {
      stateIcon = Icon(Icons.check_circle, size: 21, color: accent);
    } else if (isSkipped) {
      stateIcon = Icon(Icons.remove_circle_outline, size: 21, color: tert);
    } else {
      stateIcon = Icon(Icons.radio_button_unchecked, size: 21,
          color: AppTheme.lineStrong(context));
    }

    return GestureDetector(
      onTap: isPending ? () => _toggleStatus(t.id) : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isSkipped ? 0.5 : 1.0,
        child: Container(
          // 확인된 행: 좌측 여백에 2px accent 마진 표시 (도면 체크 마크)
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isConfirmed ? accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(isConfirmed ? 12 : 14, 14, 0, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _dateStamp(t.dayOfMonth, active: isConfirmed),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name,
                        style: AppTheme.sans(14, ink, weight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                              color: cat.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(cat.label, style: AppTheme.sans(12, tert)),
                        Text('  ·  ', style: AppTheme.sans(12, tert)),
                        Text(t.paymentMethod,
                            style: AppTheme.sans(12, pmColor,
                                weight: FontWeight.w600)),
                      ],
                    ),
                    if (_isBusinessUser && isPending) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => setState(() {
                          _localIsBusiness[t.id] =
                              !(_localIsBusiness[t.id] ?? t.isBusiness);
                        }),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (_localIsBusiness[t.id] ?? t.isBusiness)
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 14,
                              color: (_localIsBusiness[t.id] ?? t.isBusiness) ? accent : tert,
                            ),
                            const SizedBox(width: 4),
                            Text('사업경비로 인정',
                                style: AppTheme.sans(11, tert, weight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              amountWidget,
              const SizedBox(width: 12),
              stateIcon,
            ],
          ),
        ),
      ),
    );
  }

  // ── 하단 바 — 합계 + 완료 ──────────────────────────────────────────

  Widget _buildBottomBar() {
    final ink  = AppTheme.ink(context);
    final bg   = AppTheme.backgroundColor(context);
    final sub  = AppTheme.inkSecondary(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.line(context))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('이번 달 확인 합계', style: AppTheme.sans(13, sub)),
                  const Spacer(),
                  Text(_fmt.format(_confirmedTotal),
                      style: AppTheme.serif(22, ink, height: 1.0)),
                  Text(' 원', style: AppTheme.sans(13, sub)),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _saving ? null : _save,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _saving ? AppTheme.inkTertiary(context) : ink,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: bg),
                        )
                      : Text('완료',
                          style: AppTheme.sans(15, bg, weight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
