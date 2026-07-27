import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:intl/intl.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/expense_category.dart';
import '../../core/data/expense_item.dart';
import '../../core/data/income_entry.dart';
import '../../core/data/kr_holidays.dart';
import '../../core/data/ledger_profile.dart';
import '../../core/notifications/reminder_scheduler.dart';
import '../../core/tax_engine/bookkeeping_duty.dart';
import '../../core/tax_engine/reserve_estimator.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import 'bookkeeping_guide_screen.dart';
import 'my_info_screen.dart';
import 'recurring_confirm_screen.dart';
import 'recurring_templates_screen.dart';
import 'day_entry_screen.dart';
import 'month_list_screen.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';


// ── 항목 색상 (파스텔 톤) ──
const _incomeColor   = Color(0xFF5CB87A); // 수익      — soft green
const _pmCreditColor = Color(0xFF6B8FD4); // 신용카드  — steel blue
const _pmDebitColor  = Color(0xFFD4A847); // 체크+현금 — soft amber
const _pmOtherColor  = Color(0xFF9E9B96); // 기타      — warm gray

const _catCredit = '신용카드';
const _catDebit  = '체크+현금';
const _catOther  = '기타';

class ExpenseCalendarScreen extends StatefulWidget {
  /// 진입 맥락 — 하단 탭 '소득'/'지출'에서 들어올 때 제목·강조를 구분.
  /// 'income' = 소득 기록, 'expense' = 지출 기록, null = 가계부(통합).
  final String? initialFocus;

  const ExpenseCalendarScreen({super.key, this.initialFocus});

  @override
  State<ExpenseCalendarScreen> createState() => _ExpenseCalendarScreenState();
}

class _ExpenseCalendarScreenState extends State<ExpenseCalendarScreen>
    with TickerProviderStateMixin {
  int _year  = DateTime.now().year;
  int _month = DateTime.now().month;

  Map<String, List<ExpenseItem>> _expensesByDay = {};
  Map<String, List<IncomeEntry>>  _incomesByDay = {};
  Map<String, int> _dayBatchId    = {}; // dateKey → batch 타임스탬프(묶음 선택용)

  final Set<DateTime> _selected = {};
  bool _isDragging = false;
  DateTime? _dragStart;
  DateTime? _dragCurrent;

  final Map<String, GlobalKey> _cellKeys = {};

  final _incomeCtrl = TextEditingController();
  String _incomeType = '급여'; // '급여'(근로소득) | '기타'(기타 수익)
  String _userType = '직장인'; // 직장인 / N잡러 / 프리랜서 — 기타수익 토글 노출 판단
  final _creditCtrl = TextEditingController();
  final _debitCtrl  = TextEditingController();
  final _otherCtrl  = TextEditingController();
  String _creditCategory = '기타';
  String _debitCategory  = '기타';
  String _otherCategory  = '기타';
  // 사업경비 인정 여부(프리랜서·N잡러 대상) — 결제수단별 독립 플래그.
  bool _creditIsBusiness = false;
  bool _debitIsBusiness  = false;
  bool _otherIsBusiness  = false;
  // 3.3% 원천징수 사업소득 여부 — true면 수익 입력값이 실수령액(세후).
  bool _incomeIsWithheld = false;

  LedgerProfile get _profile => LedgerProfile.of(_userType);
  bool get _isBusinessUser => _profile.tracksBusinessExpense;

  int _activeView = 0; // 0=달력, 1=목록, 2=분석, 3=연간
  List<ExpenseItem> _allExpenses = [];
  int _recurringPendingCount = 0;
  int _expenseTarget = 0;
  int _grossIncome = 0; // 예상 연봉 — 신카 공제 문턱(연봉의 25%) 계산용
  Map<int, int> _annualIncome = {}; // month(1~12) → 수입 합계
  ReserveEstimate? _reserveEstimate; // 프리랜서·N잡러 + 이번 달일 때만 채워짐
  bool _reserveCardExpanded = false; // 기본 접힘 — 캘린더 위 크롬 최소화

  // 다른 유형에서 가져올 수 있는 가계부 기록 — _load에서 채운다. 비어 있으면 배너 숨김.
  List<({String from, LedgerMoveSummary summary})> _importOptions = [];

  // 결제/고정지출 관리 — 달력 아래 인라인 노출(월급날·카드결제일·고정지출)
  int _paydayDay = 25;
  List<Map<String, dynamic>> _cardDates = [];

  // 핀치 줌 — 1단계(기본 7열) · 2단계(가로 2배 폭, 세로 동일).
  int _zoomLevel = 1;
  int _activePointers = 0;
  Offset? _downPos;                      // 탭/패닝 구분용
  Size _vp = Size.zero;                  // 격자 뷰포트 크기
  double _panX = 0;                      // 2단계 가로 스크롤 오프셋
  final Map<int, Offset> _pointers = {}; // 핀치용 활성 포인터
  double? _pinchBaseDist;                // 핀치 시작 두 손가락 거리
  double _pinchRatio = 1.0;              // 현재/시작 거리 비

  final _calScrollCtrl = ScrollController();

  // 가로 패닝 관성 슬라이딩
  late final AnimationController _panFlingCtrl;
  double _minPanX = 0.0;
  final _panVTracker = VelocityTracker.withKind(PointerDeviceKind.touch);

  final _fmt = NumberFormat('#,###');

  // ── 줌 레벨 파생 ──────────────────────────────────────────────────
  bool get _showAmounts => _zoomLevel >= 2;

  int get _daysInMonth {
    final next = _month == 12 ? DateTime(_year + 1, 1, 1) : DateTime(_year, _month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  int get _firstOffset => DateTime(_year, _month, 1).weekday - 1;

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _panFlingCtrl = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        final clamped = _panFlingCtrl.value.clamp(_minPanX, 0.0);
        setState(() => _panX = clamped);
        if (clamped == _minPanX || clamped == 0.0) _panFlingCtrl.stop();
      });
    _load();
  }

  @override
  void dispose() {
    _panFlingCtrl.dispose();
    _calScrollCtrl.dispose();
    _incomeCtrl.dispose();
    _creditCtrl.dispose();
    _debitCtrl.dispose();
    _otherCtrl.dispose();
    super.dispose();
  }

  // ── 데이터 로드 ──────────────────────────────────────────────────

  Future<void> _load() async {
    final profile = await dbService.getProfile();
    final loadedType = (profile?['user_type'] as String?) ?? '직장인';
    // gross_income/expense_target은 유형별로 profile_type_values에 저장된다 —
    // user_profile의 같은 이름 컬럼(전체 프로필 저장 위저드 전용)은 여기선 안 쓴다.
    final typeValues = await dbService.getProfileTypeValues(loadedType);
    final target = typeValues['expense_target']!.toInt();
    final grossIncome = typeValues['gross_income']!.toInt();
    final allExpenses = await dbService.getExpenses(userType: loadedType);
    final allIncome   = await dbService.getIncomeEntriesForMonth(_year, _month, userType: loadedType);
    final pendingCount = await dbService.getPendingRecurringCount(_year, _month);
    final paydayDay = (profile?['pay_day'] as int? ?? 25).clamp(1, 31);
    final cardDates = await dbService.getCardPaymentDates();

    // 연간 수입: 12개월 병렬 로드
    final incFutures = List.generate(
        12, (i) => dbService.getIncomeEntriesForMonth(_year, i + 1, userType: loadedType));
    final incResults = await Future.wait(incFutures);
    final annualInc = <int, int>{};
    for (int m = 0; m < 12; m++) {
      annualInc[m + 1] = incResults[m].fold(0, (s, e) => s + e.amount);
    }

    final expMap = <String, List<ExpenseItem>>{};
    for (final e in allExpenses) {
      final end = e.endDate ?? e.date;
      var d = DateTime(e.date.year, e.date.month, e.date.day);
      final endDay = DateTime(end.year, end.month, end.day);
      while (!d.isAfter(endDay)) {
        if (d.year == _year && d.month == _month) {
          (expMap[_key(d)] ??= []).add(e);
        }
        d = d.add(const Duration(days: 1));
      }
    }

    final incMap = <String, List<IncomeEntry>>{};
    for (final e in allIncome) {
      final end = e.endDate ?? e.date;
      var d = DateTime(e.date.year, e.date.month, e.date.day);
      final endDay = DateTime(end.year, end.month, end.day);
      while (!d.isAfter(endDay)) {
        if (d.year == _year && d.month == _month) {
          (incMap[_key(d)] ??= []).add(e);
        }
        d = d.add(const Duration(days: 1));
      }
    }

    final dayBatch = <String, int>{};
    void absorb(String key, String id) {
      final b = _batchOf(id);
      if (b > (dayBatch[key] ?? -1)) dayBatch[key] = b;
    }
    expMap.forEach((k, list) { for (final e in list) { absorb(k, e.id); } });
    incMap.forEach((k, list) { for (final e in list) { absorb(k, e.id); } });

    // 다른 유형에 쌓아둔 기록을 이 유형으로 가져올 수 있는지 미리보기(허용된 출처만).
    final importOpts = <({String from, LedgerMoveSummary summary})>[];
    for (final src in _importSourcesFor(loadedType)) {
      final summary = await dbService.previewLedgerMove(from: src, to: loadedType);
      if (summary.totalMovable > 0) importOpts.add((from: src, summary: summary));
    }

    if (mounted) {
      setState(() {
        _userType = loadedType;
        _importOptions = importOpts;
        _incomeType = LedgerProfile.of(loadedType).defaultIncomeType;
        _expensesByDay = expMap;
        _incomesByDay  = incMap;
        _dayBatchId    = dayBatch;
        _allExpenses   = allExpenses;
        _recurringPendingCount = pendingCount;
        _expenseTarget = target;
        _grossIncome   = grossIncome;
        _annualIncome  = annualInc;
        _paydayDay     = paydayDay;
        _cardDates     = cardDates;
      });
    }
    await _loadReserveEstimate();
    await _maybeShowOtherIncomeThresholdDialog(loadedType);
  }

  bool get _isCurrentMonth =>
      _year == DateTime.now().year && _month == DateTime.now().month;

  Future<void> _loadReserveEstimate() async {
    if (!_isBusinessUser || !_isCurrentMonth) {
      if (mounted && _reserveEstimate != null) setState(() => _reserveEstimate = null);
      return;
    }
    final estimate = await ReserveEstimator.estimateForCurrentMonth(userType: _userType);
    if (!mounted) return;
    setState(() => _reserveEstimate = estimate);
    final introShown = await dbService.getAppState('reserve_card_intro_shown');
    if (introShown == null && mounted) {
      await dbService.setAppState('reserve_card_intro_shown', 'true');
      _showReserveIntroDialog();
    }
  }

  void _showReserveIntroDialog() {
    if (!mounted) return;
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('세금 적립 카드가 생겼어요', style: AppTheme.serif(17, ink, weight: FontWeight.w400, spacing: -0.3)),
        content: Text(
          '이번 달 수입에서 세금·4대보험으로 미리 떼어둬야 할 금액과, 지금 마음 놓고 써도 되는 금액을 매달 계산해서 보여드려요. '
          '업종코드를 설정하면 더 정확해져요 — 내 정보에서 언제든 설정할 수 있어요.',
          style: AppTheme.sans(13, sub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('확인', style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _openProfileForReserve() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyInfoScreen(userType: _userType, onProfileChanged: _load),
      ),
    );
    await _load();
  }

  /// 기장의무 안내 + 가계부 기록으로 간편장부 만들기.
  Future<void> _openBookkeepingGuide() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookkeepingGuideScreen(userType: _userType),
      ),
    );
  }

  int _batchOf(String id) {
    if (id.startsWith('b')) {
      final us = id.indexOf('_');
      if (us > 1) return int.tryParse(id.substring(1, us)) ?? 0;
    }
    return 0;
  }

  // ── 월 합계 ──────────────────────────────────────────────────────

  int get _monthIncomeTotal =>
      _incomesByDay.values.expand((l) => l).toSet().fold(0, (s, e) => s + e.amount);

  // ── 날짜별 합계 ──────────────────────────────────────────────────

  int _incomeOf(String key) =>
      (_incomesByDay[key] ?? const []).fold(0, (s, e) => s + e.amount);

  // 결제수단별 합계 (카테고리 점 표시·prefill용)
  int _paymentOf(String key, String pm) => (_expensesByDay[key] ?? const [])
      .toSet()
      .where((e) => e.paymentMethod == pm)
      .fold(0, (s, e) => s + e.amount);

  bool _hasData(String key) =>
      (_incomesByDay[key]?.isNotEmpty ?? false) ||
      (_expensesByDay[key]?.isNotEmpty ?? false);

  // ── 선택 ─────────────────────────────────────────────────────────

  /// 같은 묶음(배치 = 같은 배경색)으로 입력된 날짜들을 한 번에 선택.
  /// 데이터 없는 날은 그 날 단독.
  Set<DateTime> _groupDatesFor(DateTime date) {
    final batch = _dayBatchId[_key(date)];
    if (batch == null) return {date};
    final out = <DateTime>{};
    _dayBatchId.forEach((k, b) {
      if (b == batch) out.add(DateTime.parse(k));
    });
    return out.isEmpty ? {date} : out;
  }

  void _toggleSingle(DateTime date) {
    final group = _groupDatesFor(date);
    final alreadySelected =
        _selected.length == group.length && group.every(_selected.contains);
    if (alreadySelected) {
      setState(() {
        _selected.clear();
        _clearForm();
      });
      _scrollToTop();
      return;
    }
    setState(() {
      _selected..clear()..addAll(group);
      _prefillFromDate(group.reduce((a, b) => a.isBefore(b) ? a : b));
    });
    _openDayEntry();
  }

  /// 풀스크린 입력 화면을 열고, 돌아오면 새로고침 — 인라인 에디터의 "스크롤이
  /// 에디터를 지나쳐버리는" 문제를 화면 분리로 원천 해결한다.
  Future<void> _openDayEntry() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DayEntryScreen(
          dates: Set.of(_selected),
          userType: _userType,
          hasExisting: _selected.any((d) => _hasData(_key(d))),
          initialIncomeText: _incomeCtrl.text,
          initialIncomeType: _incomeType,
          initialIncomeWithheld: _incomeIsWithheld,
          initialCreditText: _creditCtrl.text,
          initialCreditCategory: _creditCategory,
          initialCreditBusiness: _creditIsBusiness,
          initialDebitText: _debitCtrl.text,
          initialDebitCategory: _debitCategory,
          initialDebitBusiness: _debitIsBusiness,
          initialOtherText: _otherCtrl.text,
          initialOtherCategory: _otherCategory,
          initialOtherBusiness: _otherIsBusiness,
          incomesByDay: _incomesByDay,
          expensesByDay: _expensesByDay,
        ),
      ),
    );
    await _load();
    _deselect();
  }

  /// 그 날 기록된 소득의 유형(첫 항목 기준). 없으면 유형별 기본값(직장인·N잡러=근로소득, 프리랜서=사업소득).
  String _incomeTypeOf(String key) {
    final list = _incomesByDay[key];
    if (list == null || list.isEmpty) return _profile.defaultIncomeType;
    return list.first.incomeType;
  }

  /// 대표 날짜(가장 이른) 기준으로 폼 prefill — 묶음은 같은 금액의 한 건.
  void _prefillFromDate(DateTime date) {
    final key = _key(date);
    final inc = _incomeOf(key);
    final cr = _paymentOf(key, _catCredit);
    final db = _paymentOf(key, _catDebit);
    final ot = _paymentOf(key, _catOther);
    _incomeType = _incomeTypeOf(key);
    _incomeIsWithheld = (_incomesByDay[key] ?? const []).isEmpty
        ? _profile.withholdingDefault
        : (_incomesByDay[key] ?? const []).first.isWithheld;
    // 기존 지출에서 결제수단별 카테고리·사업경비 복원
    for (final e in (_expensesByDay[key] ?? []).toSet()) {
      if (e.paymentMethod == _catCredit) { _creditCategory = e.category; _creditIsBusiness = e.isBusiness; }
      else if (e.paymentMethod == _catDebit) { _debitCategory = e.category; _debitIsBusiness = e.isBusiness; }
      else if (e.paymentMethod == _catOther) { _otherCategory = e.category; _otherIsBusiness = e.isBusiness; }
    }
    _incomeCtrl.text = inc > 0 ? _fmt.format(inc) : '';
    _creditCtrl.text = cr > 0 ? _fmt.format(cr) : '';
    _debitCtrl.text  = db > 0 ? _fmt.format(db) : '';
    _otherCtrl.text  = ot > 0 ? _fmt.format(ot) : '';
  }

  void _prefillForm() {
    if (_selected.length == 1) {
      final key = _key(_selected.first);
      final inc = _incomeOf(key);
      _incomeType = _incomeTypeOf(key);
      _incomeIsWithheld = (_incomesByDay[key] ?? const []).isEmpty
        ? _profile.withholdingDefault
        : (_incomesByDay[key] ?? const []).first.isWithheld;
      _incomeCtrl.text = inc > 0 ? _fmt.format(inc) : '';
      final cr = _paymentOf(key, _catCredit);
      final db = _paymentOf(key, _catDebit);
      final ot = _paymentOf(key, _catOther);
      for (final e in (_expensesByDay[key] ?? []).toSet()) {
        if (e.paymentMethod == _catCredit) { _creditCategory = e.category; _creditIsBusiness = e.isBusiness; }
        else if (e.paymentMethod == _catDebit) { _debitCategory = e.category; _debitIsBusiness = e.isBusiness; }
        else if (e.paymentMethod == _catOther) { _otherCategory = e.category; _otherIsBusiness = e.isBusiness; }
      }
      _creditCtrl.text = cr > 0 ? _fmt.format(cr) : '';
      _debitCtrl.text  = db > 0 ? _fmt.format(db) : '';
      _otherCtrl.text  = ot > 0 ? _fmt.format(ot) : '';
    } else {
      _clearForm();
    }
  }

  void _clearForm() {
    _incomeType = _profile.defaultIncomeType;
    // 프리랜서는 소득이 항상 원천징수 대상이라 기본 체크 — 통장엔 이미 뗀 돈이 들어오므로.
    _incomeIsWithheld = _profile.withholdingDefault;
    _creditCategory = '기타';
    _debitCategory  = '기타';
    _otherCategory  = '기타';
    _creditIsBusiness = false;
    _debitIsBusiness  = false;
    _otherIsBusiness  = false;
    _incomeCtrl.clear();
    _creditCtrl.clear();
    _debitCtrl.clear();
    _otherCtrl.clear();
  }

  void _deselect() {
    setState(() {
      _selected.clear();
      _clearForm();
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_calScrollCtrl.hasClients) return;
      final maxExt = _calScrollCtrl.position.maxScrollExtent;
      if (maxExt <= 0) return;
      _calScrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  // ── 드래그 히트테스트 ────────────────────────────────────────────

  DateTime? _dateAtGlobal(Offset global) {
    for (final entry in _cellKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final topLeft = box.localToGlobal(Offset.zero);
      final rect = topLeft & box.size;
      if (rect.contains(global)) return DateTime.parse(entry.key);
    }
    return null;
  }

  Set<DateTime> _rangeBetween(DateTime a, DateTime b) {
    final start = a.isBefore(b) ? a : b;
    final end   = a.isBefore(b) ? b : a;
    final out = <DateTime>{};
    var d = start;
    while (!d.isAfter(end)) { out.add(d); d = d.add(const Duration(days: 1)); }
    return out;
  }

  // ── 저장 / 삭제 ──────────────────────────────────────────────────

  // ── build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final bg  = AppTheme.backgroundColor(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        title: Text(
          widget.initialFocus == 'income'
              ? '소득 기록'
              : widget.initialFocus == 'expense'
                  ? '지출 기록'
                  : '가계부',
          style: AppTheme.serif(22, ink),
        ),
        actions: [
          if (_selected.isEmpty && _importOptions.isNotEmpty) _buildImportAction(),
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _deselect,
              child: Text('취소', style: AppTheme.sans(14, AppTheme.accentColor(context))),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildMonthNav(ink),
            _buildViewTabs(ink),
            AppTheme.hairline(context),
            Expanded(
              child: IndexedStack(
                index: _activeView,
                children: [
                  // 0: 달력
                  Column(
                    children: [
                      if (_reserveEstimate != null && !_reserveEstimate!.hasOccupationCode)
                        _buildProfileGateBanner(),
                      if (_recurringPendingCount > 0) _buildRecurringBanner(),
                      Expanded(child: _buildCalendar(ink, sub)),
                    ],
                  ),
                  // 1: 분석
                  _buildAnalysisView(ink, sub),
                  // 2: 연간
                  _buildAnnualView(ink, sub),
                ],
              ),
            ),
            // 적립 예상 카드 — 달력 그리드 아래(프리랜서·N잡러 이번 달만). 수입/지출/잔액
            // 요약은 분석탭과 중복이라 제거하고, 달력을 위로 올려 기록 화면을 넓혔다.
            if (_activeView == 0 && _reserveEstimate != null) _buildReserveCard(ink, sub),
            if (_activeView == 0) _buildQuickSettingsRow(ink, sub),
          ],
        ),
      ),
    );
  }

  // ── 가계부 가져오기(유형 이동) ─────────────────────────────────────
  /// 이 유형이 '대상'일 때 기록을 가져올 수 있는 '출처' 유형들.
  /// 4방향만 허용 — 직장인·프리랜서→N잡러(전부 이동), N잡러→직장인·프리랜서(맞는 것만).
  List<String> _importSourcesFor(String target) {
    switch (target) {
      case 'N잡러':
        return const ['직장인', '프리랜서'];
      case '직장인':
      case '프리랜서':
        return const ['N잡러'];
      default:
        return const [];
    }
  }

  Widget _buildImportAction() {
    final accent = AppTheme.accentColor(context);
    final count = _importOptions.length;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: _onImportTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.drive_file_move_outline, size: 14, color: accent),
              const SizedBox(width: 4),
              Text('가져오기', style: AppTheme.sans(12, accent, weight: FontWeight.w700)),
              if (count > 1) ...[
                const SizedBox(width: 4),
                Text('$count', style: AppTheme.sans(12, accent, weight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onImportTap() {
    if (_importOptions.length == 1) {
      final opt = _importOptions.first;
      _confirmImport(opt.from, opt.summary);
      return;
    }
    final ink = AppTheme.ink(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.backgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('가계부 가져오기', style: AppTheme.serif(18, ink)),
            const SizedBox(height: 4),
            for (final opt in _importOptions)
              ListTile(
                leading: Icon(Icons.drive_file_move_outline, color: AppTheme.accentColor(context)),
                title: Text('${opt.from} 때 기록'.keepWords, style: AppTheme.sans(14, ink)),
                subtitle: Text('${opt.summary.totalMovable}건', style: AppTheme.sans(12, AppTheme.inkSecondary(context))),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmImport(opt.from, opt.summary);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 방향별 맞춤 안내/유의 문구. to = 현재 유형(_userType).
  ({String title, String body}) _importDialogText(String from, LedgerMoveSummary s) {
    final to = _userType;
    final moved = s.totalMovable;
    if (to == 'N잡러') {
      // 직장인·프리랜서 → N잡러: 소득이 모두 N잡러 범위 안이라 전부 이동(남는 것 없음).
      // 직장인도 급여·기타소득 둘 다 기록할 수 있어 두 소득 모두 옮겨간다.
      final kinds = from == '직장인' ? '급여·기타소득·지출' : '사업·기타소득·지출';
      return (
        title: '$from 기록을 N잡러로 가져올까요?',
        body: '$from 때 기록한 $kinds $moved건을 N잡러 가계부로 옮겨요. '
            'N잡러는 근로·사업·기타소득을 모두 관리하니 그대로 이어서 볼 수 있어요. '
            '$from 가계부는 비워져요.',
      );
    }
    // N잡러 → 직장인·프리랜서: 대상에 맞는 소득만 이동, 나머지는 N잡러에 남는다.
    // 직장인도 기타소득을 기록할 수 있어 급여·기타소득 둘 다 옮겨가고, 사업소득만 N잡러에 남는다.
    final movedKinds = to == '직장인' ? '급여·기타소득·지출' : '사업·기타소득·지출';
    final orphanKinds = to == '직장인' ? '사업소득' : '급여';
    final orphan = s.orphanIncomeCount;
    final orphanNote = orphan > 0
        ? ' $orphanKinds $orphan건은 $to 가계부에 맞지 않아 N잡러에 그대로 남아요.'
        : '';
    return (
      title: 'N잡러 기록을 $to 가계부로 가져올까요?',
      body: 'N잡러 기록 중 $movedKinds $moved건을 $to 가계부로 옮겨요.$orphanNote',
    );
  }

  Future<void> _confirmImport(String from, LedgerMoveSummary summary) async {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);
    final t = _importDialogText(from, summary);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(t.title, style: AppTheme.serif(17, ink, weight: FontWeight.w400, spacing: -0.3)),
        content: Text(t.body, style: AppTheme.sans(13, sub, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: AppTheme.sans(14, sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('가져오기', style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await dbService.moveLedgerRecords(from: from, to: _userType);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${summary.totalMovable}건을 가져왔어요.'.keepWords)),
    );
  }

  /// 직장인의 올해 기타소득(필요경비 60% 자동 인정 후 소득금액)이 연 300만원을 넘으면
  /// 종합과세 대상임을 알리고 N잡러 전환을 안내한다. 연도별로 한 번만 띄운다.
  Future<void> _maybeShowOtherIncomeThresholdDialog(String loadedType) async {
    if (loadedType != '직장인') return;
    final year = DateTime.now().year;
    final flagKey = 'other_income_threshold_notice_$year';
    if (await dbService.getAppState(flagKey) != null) return;

    final futures = List.generate(
        12, (i) => dbService.getIncomeEntriesForMonth(year, i + 1, userType: loadedType));
    final results = await Future.wait(futures);
    int otherIncomeSum = 0;
    for (final month in results) {
      for (final e in month) {
        if (e.incomeType == '기타소득') otherIncomeSum += e.amount;
      }
    }
    final taxableAmount = otherIncomeSum * 0.4; // 필요경비 60% 자동 인정 후 소득금액
    if (taxableAmount <= 3000000) return;

    await dbService.setAppState(flagKey, 'true');
    if (!mounted) return;
    _showOtherIncomeThresholdDialog();
  }

  void _showOtherIncomeThresholdDialog() {
    if (!mounted) return;
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('기타소득이 300만원을 넘었어요'.keepWords, style: AppTheme.serif(17, ink, weight: FontWeight.w400, spacing: -0.3)),
        content: Text(
          '올해 기록한 기타소득의 소득금액(필요경비 60% 제외 후)이 300만원을 넘었어요. '
          '근로소득과 합산해 5월에 종합소득세를 신고해야 해요. '
          'N잡러로 전환하면 소득 구분과 세금 적립을 더 정확히 안내받을 수 있어요.',
          style: AppTheme.sans(13, sub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('나중에', style: AppTheme.sans(14, sub)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final existing = await dbService.getProfile() ?? <String, dynamic>{};
              await dbService.saveProfile({...existing, 'user_type': 'N잡러'});
              if (!mounted) return;
              await _load();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('N잡러로 전환했어요. 기존 기록은 위 가져오기 배너로 옮길 수 있어요.'.keepWords)),
              );
            },
            child: Text('N잡러로 전환', style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// 결제/고정지출 관리 — 달력 아래 인라인 노출(월급날·카드결제일·고정지출).
  /// 이전엔 별도 "관리" 화면으로 들어가야 봤지만, 자주 안 쓰이는 만큼 오히려
  /// 달력 화면에서 바로 보이고 바로 입력되게 꺼냈다.
  Widget _buildQuickSettingsRow(Color ink, Color sub) {
    final accent = AppTheme.accentColor(context);
    final line = AppTheme.line(context);
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: line, width: 1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildLegend(),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (_profile.showsPaydayChip)
                  _quickChip(
                    icon: Icons.payments_outlined,
                    label: '월급 $_paydayDay일',
                    ink: ink, sub: sub, line: line,
                    onTap: _showPaydayPicker,
                  ),
                for (final card in _cardDates)
                  _quickChip(
                    icon: Icons.credit_card_rounded,
                    label: '${card['name']} ${card['day']}일',
                    ink: ink, sub: sub, line: line,
                    onTap: () => _showCardOptions(card),
                  ),
                _quickChip(
                  icon: Icons.add_rounded,
                  label: '카드결제일',
                  ink: accent, sub: accent, line: accent,
                  onTap: _showAddCardDialog,
                ),
                _quickChip(
                  icon: Icons.add_rounded,
                  label: '고정지출',
                  ink: accent, sub: accent, line: accent,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const RecurringTemplatesScreen(),
                    ));
                    _load();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip({
    required IconData icon,
    required String label,
    required Color ink,
    required Color sub,
    required Color line,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: line, width: 1.0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: sub),
            const SizedBox(width: 4),
            Text(label, style: AppTheme.sans(12, ink, weight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Future<void> _showPaydayPicker() async {
    final ink    = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);
    final bg     = AppTheme.backgroundColor(context);
    final line   = AppTheme.line(context);
    final sub    = AppTheme.inkSecondary(context);

    final confirmed = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int current = _paydayDay;
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: line),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            title: Text('월급날 설정', style: AppTheme.serif(17, ink)),
            content: SizedBox(
              height: 120,
              child: ListWheelScrollView.useDelegate(
                itemExtent: 36,
                onSelectedItemChanged: (i) => setSt(() => current = i + 1),
                controller: FixedExtentScrollController(initialItem: _paydayDay - 1),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: 31,
                  builder: (_, i) => Center(
                    child: Text('${i + 1}일',
                        style: AppTheme.sans(
                            16,
                            i + 1 == current ? ink : AppTheme.inkTertiary(ctx),
                            weight: i + 1 == current
                                ? FontWeight.w700
                                : FontWeight.w400)),
                  ),
                ),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 12),
                  child: Text('취소', style: AppTheme.sans(14, sub)),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(ctx, current),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                  child: Text('저장',
                      style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
                ),
              ),
            ],
          );
        });
      },
    );

    if (confirmed == null || !mounted) return;
    final profile = await dbService.getProfile() ?? {};
    await dbService.saveProfile({...profile, 'pay_day': confirmed});
    if (mounted) setState(() => _paydayDay = confirmed);
  }

  Future<void> _showAddCardDialog() async {
    final nameCtrl = TextEditingController();
    int selectedDay = 1;
    final ink    = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);
    final bg     = AppTheme.backgroundColor(context);
    final line   = AppTheme.line(context);
    final sub    = AppTheme.inkSecondary(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        int currentDay = selectedDay;
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: line),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            title: Text('카드 결제일 추가', style: AppTheme.serif(17, ink)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('카드 이름',
                    style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: AppTheme.sans(15, ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '예: 신한카드',
                    hintStyle: AppTheme.sans(15, AppTheme.inkTertiary(ctx)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: UnderlineInputBorder(
                        borderSide: BorderSide(color: line)),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: line)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: accent, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('결제일',
                    style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 100,
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 32,
                    onSelectedItemChanged: (i) =>
                        setSt(() => currentDay = i + 1),
                    controller:
                        FixedExtentScrollController(initialItem: currentDay - 1),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 31,
                      builder: (_, i) => Center(
                        child: Text('${i + 1}일',
                            style: AppTheme.sans(
                                14,
                                i + 1 == currentDay
                                    ? ink
                                    : AppTheme.inkTertiary(ctx),
                                weight: i + 1 == currentDay
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 12),
                  child: Text('취소', style: AppTheme.sans(14, sub)),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  selectedDay = currentDay;
                  Navigator.pop(ctx, true);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                  child: Text('추가',
                      style:
                          AppTheme.sans(14, accent, weight: FontWeight.w700)),
                ),
              ),
            ],
          );
        });
      },
    );

    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (confirmed != true || name.isEmpty || !mounted) return;

    await dbService.addCardPaymentDate(name, selectedDay);
    final updated = await dbService.getCardPaymentDates();
    if (!kIsWeb) await ReminderScheduler.scheduleCardPayments(updated);
    if (mounted) setState(() => _cardDates = updated);
  }

  Future<void> _showCardOptions(Map<String, dynamic> card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ink  = AppTheme.ink(ctx);
        final bg   = AppTheme.backgroundColor(ctx);
        final line = AppTheme.line(ctx);
        final sub  = AppTheme.inkSecondary(ctx);
        return AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: line),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          title: Text('${card['name']} ${card['day']}일',
              style: AppTheme.serif(17, ink)),
          content: GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('삭제',
                  style: AppTheme.sans(15, AppTheme.colorDanger,
                      weight: FontWeight.w600)),
            ),
          ),
          actions: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                child: Text('취소', style: AppTheme.sans(14, sub)),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    await dbService.deleteCardPaymentDate(card['id'] as int);
    final updated = await dbService.getCardPaymentDates();
    if (!kIsWeb) await ReminderScheduler.scheduleCardPayments(updated);
    if (mounted) setState(() => _cardDates = updated);
  }

  /// 고정 지출 미확인 배너
  /// 프로필 소프트 게이트 — 업종코드 등 미작성 시 상단 배너(하드 블록 아님, 정보 안내).
  Widget _buildProfileGateBanner() {
    final accent = AppTheme.accentColor(context);
    return GestureDetector(
      onTap: _openProfileForReserve,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withAlpha(15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: accent.withAlpha(60), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.badge_outlined, size: 18, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '내 정보를 설정하면 적립 계산이 정확해져요'.keepWords,
                style: AppTheme.sans(13, accent, weight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringBanner() {
    final accent = AppTheme.accentColor(context);
    return GestureDetector(
      onTap: () async {
        final added = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => RecurringConfirmScreen(year: _year, month: _month),
          ),
        );
        if (added == true) _load();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withAlpha(15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: accent.withAlpha(60), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.event_repeat_outlined, size: 18, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '고정 지출 확인 대기',
                    style: AppTheme.sans(11, accent,
                        weight: FontWeight.w600, spacing: 0.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_recurringPendingCount건 미처리'.keepWords,
                    style: AppTheme.sans(14, accent, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withAlpha(26),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('확인하기',
                  style: AppTheme.sans(12, accent, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  /// 색 점 범례 — 수익 + 결제수단 3종 + 고정지출 링크
  Widget _buildLegend() {
    final sub = AppTheme.inkSecondary(context);
    Widget dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: AppTheme.sans(11, sub, weight: FontWeight.w500)),
        ]);
    return Wrap(spacing: 10, runSpacing: 4, children: [
      dot(_incomeColor,   '수익'),
      dot(_pmCreditColor, '신용카드'),
      dot(_pmDebitColor,  '체크/현금'),
      dot(_pmOtherColor,  '기타'),
    ]);
  }

  Widget _buildViewTabs(Color ink) {
    const labels = ['달력', '분석', '연간'];
    final accent = AppTheme.accentColor(context);
    final sub = AppTheme.inkSecondary(context);
    return Row(
      children: List.generate(3, (i) {
        final selected = _activeView == i;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (_activeView != i) setState(() { _activeView = i; _deselect(); });
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                labels[i],
                style: AppTheme.sans(13, selected ? accent : sub,
                    weight: selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMonthNav(Color ink) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: ink, size: 26),
            onPressed: () {
              setState(() {
                if (_month == 1) { _year--; _month = 12; } else { _month--; }
                _selected.clear(); _clearForm();
              });
              _scrollToTop();
              _load();
            },
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MonthListScreen(
                year: _year,
                month: _month,
                expensesByDay: _expensesByDay,
                incomesByDay: _incomesByDay,
              ),
            )),
            behavior: HitTestBehavior.opaque,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$_year. $_month', style: AppTheme.sans(18, ink, weight: FontWeight.w700)),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 18, color: AppTheme.inkSecondary(context)),
            ]),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, color: ink, size: 26),
            onPressed: () {
              setState(() {
                if (_month == 12) { _year++; _month = 1; } else { _month++; }
                _selected.clear(); _clearForm();
              });
              _scrollToTop();
              _load();
            },
          ),
        ],
      ),
    );
  }

  /// 프리랜서·N잡러 전용 — 이번 달 세금·4대보험 적립(예상)과 지금 써도 되는 돈.
  /// 저장 없이 그 자리에서 재계산(가계부 기록 + 프로필 최신값 기준) — 과거 달엔 노출하지 않는다.
  /// 기본 접힘(요약 1줄) — 캘린더 위 크롬을 줄이기 위해 탭해야 상세가 펼쳐진다.
  Widget _buildReserveCard(Color ink, Color sub) {
    final r = _reserveEstimate!;
    String won(double v) => '${_fmt.format(v.round())}원';
    String range(double min, double max) =>
        min.round() == max.round() ? won(min) : '${_fmt.format(min.round())}~${_fmt.format(max.round())}원';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line(context), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _reserveCardExpanded,
            label: r.hasOccupationCode
                ? '이번 달 세금·보험 적립 예상 ${range(r.minMonthlyTaxReserve + r.insuranceReserve, r.maxMonthlyTaxReserve + r.insuranceReserve)}'
                : '이번 달 세금·보험 적립 예상 — 업종 설정 필요',
            child: GestureDetector(
              onTap: () => setState(() => _reserveCardExpanded = !_reserveCardExpanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                child: Row(children: [
                  Icon(Icons.savings_outlined, size: 16, color: sub),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('이번 달 세금·보험 적립(예상)'.keepWords,
                        style: AppTheme.sans(13, sub, weight: FontWeight.w600)),
                  ),
                  if (!_reserveCardExpanded) ...[
                    // 업종 미설정이면 경비율을 몰라 세액이 과대 계상된다 — 요약값도 숨긴다.
                    Text(
                      r.hasOccupationCode
                          ? range(r.minMonthlyTaxReserve + r.insuranceReserve,
                              r.maxMonthlyTaxReserve + r.insuranceReserve)
                          : '업종 설정 필요',
                      style: AppTheme.sans(13, r.hasOccupationCode ? ink : AppTheme.accentColor(context),
                          weight: FontWeight.w800),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(_reserveCardExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 18, color: sub),
                ]),
              ),
            ),
          ),
          if (_reserveCardExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 업종을 모르면 경비율을 모르고, 경비율이 0으로 잡혀 "경비가 하나도 없다"는
                  // 최악 가정의 세액이 나온다(실측 5배 이상 과대). 추정이 아니라 오류라서
                  // 숫자를 내지 않고 업종 설정으로 보낸다.
                  if (!r.hasOccupationCode)
                    GestureDetector(
                      onTap: _openProfileForReserve,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('세금으로 미리 모아둘 돈', style: AppTheme.sans(13, sub)),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('업종 설정 시',
                                style: AppTheme.sans(13, AppTheme.accentColor(context), weight: FontWeight.w700)),
                            Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.accentColor(context)),
                          ]),
                        ],
                      ),
                    )
                  else ...[
                    _reserveRow('세금으로 미리 모아둘 돈', range(r.minMonthlyTaxReserve, r.maxMonthlyTaxReserve), ink, sub),
                    if (r.minMonthlyTaxReserve.round() != r.maxMonthlyTaxReserve.round()) ...[
                      const SizedBox(height: 4),
                      Text('단순경비율(최소)~기준경비율(최대) 두 가정 중 어디에 해당할지 몰라 범위로 보여드려요'.keepWords,
                          style: AppTheme.sans(11, AppTheme.inkTertiary(context), height: 1.4)),
                    ],
                  ],
                  const SizedBox(height: 6),
                  // 프로필(가입 보험) 미설정이라 계산 불가한 0은 '0원'(=낼 것 없음)으로
                  // 오해될 수 있어, 설정을 유도하는 표현 + 프로필 이동으로 바꾼다.
                  if (r.insuranceReserve == 0 && !r.insuranceProfileSet)
                    GestureDetector(
                      onTap: _openProfileForReserve,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('보험료로 대비할 돈', style: AppTheme.sans(13, sub)),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('프로필 설정 시',
                                style: AppTheme.sans(13, AppTheme.accentColor(context), weight: FontWeight.w700)),
                            Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.accentColor(context)),
                          ]),
                        ],
                      ),
                    )
                  else
                    _reserveRow('보험료로 대비할 돈', won(r.insuranceReserve), ink, sub),
                  const SizedBox(height: 10),
                  AppTheme.hairline(context),
                  const SizedBox(height: 10),
                  // 세금 적립을 모르면 거기서 뺀 "써도 되는 돈"도 모른다 — 같이 감춘다.
                  if (r.hasOccupationCode)
                    _reserveRow('지금 써도 되는 돈', range(r.minUsable, r.maxUsable), ink, sub, emphasize: true),
                  // ── 무기장가산세 경고 ──
                  // 적립액에 이미 20%가 포함돼 있다. 왜 늘었는지 말해주지 않으면
                  // 사용자는 숫자가 튄 이유를 알 수 없고, 피할 방법도 모른 채 넘어간다.
                  if (r.includesNoBookkeepingPenalty) ...[
                    const SizedBox(height: 10),
                    AppTheme.hairline(context),
                    const SizedBox(height: 10),
                    _noBookkeepingWarning(r.bookkeepingJudgment, ink, sub),
                  ],
                  // ── 올해 쌓인 예상 환급 (A/B/C) ──
                  // 기록의 이유를 기록하는 자리에 둔다. 지금까진 세무 시뮬레이터에만 있었다.
                  if (r.refundProgress != null) ...[
                    const SizedBox(height: 10),
                    AppTheme.hairline(context),
                    const SizedBox(height: 10),
                    _refundProgressBlock(r.refundProgress!, ink, sub, won),
                  ],
                  if (!r.hasOccupationCode) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _openProfileForReserve,
                      behavior: HitTestBehavior.opaque,
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, size: 13, color: AppTheme.accentColor(context)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('업종코드를 설정하면 더 정확해져요'.keepWords,
                              style: AppTheme.sans(12, AppTheme.accentColor(context), weight: FontWeight.w600)),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.accentColor(context)),
                      ]),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _openProfileForReserve,
                      behavior: HitTestBehavior.opaque,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.tune_rounded, size: 13, color: sub),
                        const SizedBox(width: 6),
                        Text('내 정보 수정', style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
                      ]),
                    ),
                  ],
                  const CalcDisclaimer(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 무기장가산세 경고 — 위 적립액에 산출세액 20%가 이미 포함돼 있음을 밝힌다.
  ///
  /// 소득세법 §81의5. 소규모사업자(신규·직전연도 수입 4,800만 미만)는 면제라
  /// 이 블록은 그 밖의 사업자에게만 뜬다. 복식부기의무자만의 문제가 아니라,
  /// 간편장부대상자도 4,800만을 넘으면 장부 없이 신고할 때 똑같이 맞는다.
  Widget _noBookkeepingWarning(BookkeepingJudgment? j, Color ink, Color sub) {
    final danger = AppTheme.colorDanger;
    final isDouble = j?.isDoubleEntry ?? false;
    return GestureDetector(
      onTap: _openBookkeepingGuide,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.error_outline_rounded, size: 14, color: danger),
            const SizedBox(width: 6),
            Expanded(
              child: Text('위 적립액에 무기장가산세 20%가 들어 있어요'.keepWords,
                  style: AppTheme.sans(13, ink, weight: FontWeight.w700)),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: sub),
          ]),
          const SizedBox(height: 4),
          Text(
            isDouble
                ? '${j!.reason} 장부를 갖추면 이 20%가 빠져요.'
                : '직전연도 수입이 4,800만원을 넘어, 장부 없이 신고하면 산출세액의 20%가 더 붙어요. '
                    '가계부 기록으로 간편장부를 만들면 빠집니다.',
            style: AppTheme.sans(12, sub, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// 적은 경비 → "올해 쌓인 예상 환급" A/B/C 블록.
  ///
  /// 직장인 홈(home_status_section._buildCardRefundBlock)과 같은 말·같은 모양을 쓴다.
  /// 다만 자라는 기전이 다르다 — 직장인은 신용카드 소득공제, 프리랜서는 그 제도
  /// 대상이 아니라서 "필요경비 → 소득금액 감소 → 이미 뗀 3.3% 환급"으로 자란다.
  ///
  /// A: 분기점 아래 — 더 적어도 환급이 안 는다(추계가 유리해 기록이 세금을 안 바꾼다).
  ///    여기서 "더 쓰세요"는 틀린 처방이라(100을 써서 30을 아끼는 짓) "찾아 적으라"고 말한다.
  /// B: 분기점 위 — 적을수록 환급이 는다.
  /// C: 결정세액 0 — 낸 3.3%를 다 돌려받아 더는 안 는다.
  Widget _refundProgressBlock(
      RefundProgress p, Color ink, Color sub, String Function(double) won) {
    final accent = AppTheme.accentColor(context);
    final tert = AppTheme.inkTertiary(context);

    // 소득이 과세 문턱 아래거나(낼 세금 0) 다 찾아봐야 실익이 미미하면
    // 카운터도 유도도 띄우지 않는다 — 돌려받을 게 없는데 재촉하면 거짓 약속이 된다.
    if (p.noTaxEitherWay || (!p.isAhead && !p.worthPursuing)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reserveRow('올해 적은 경비', won(p.recordedExpense), ink, sub),
          const SizedBox(height: 4),
          Text(
            p.noTaxEitherWay
                ? '지금 소득에선 어느 쪽으로 신고해도 낼 세금이 없어요'
                : '공제를 빼면 낼 세금이 거의 없어서, 경비를 더 찾아도 돌려받을 게 적어요',
            style: AppTheme.sans(12, sub, height: 1.4),
          ),
        ],
      );
    }

    // A — 분기점 전. 남은 금액과 함께 "그래봐야 얼마"까지 같이 말한다.
    // 상한(추계 세액)을 숨기면 360만원을 더 찾아 1천원을 버는 요구가 되어버린다.
    if (!p.isAhead) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reserveRow('올해 적은 경비', won(p.recordedExpense), ink, sub),
          const SizedBox(height: 4),
          Text('${won(p.shortfall)}을 더 찾으면 환급이 쌓이기 시작해요 (최대 ${won(p.maxGain)})'.keepWords,
              style: AppTheme.sans(12, sub, height: 1.4)),
        ],
      );
    }

    // B/C — 환급 카운터(히어로). C는 결정세액 0으로 멈춤 안내.
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('올해 쌓인 예상 환급', style: AppTheme.sans(12, tert)),
          const SizedBox(height: 4),
          Text(won(p.refundGain),
              style: AppTheme.serif(26, accent,
                  weight: FontWeight.w700, spacing: -0.8, height: 1.0)),
          const SizedBox(height: 6),
          Text(
            p.isCapped
                // 사업 3.3%+기타 8.8% 원천징수를 합쳐 말해야 정확하다 — "3.3%"로 좁히지 않는다.
                ? '올해 원천징수된 세금을 다 돌려받는 상태예요 · 더 적어도 환급은 안 늘어요'
                : '경비를 더 찾을수록 늘어요 · 예상',
            style: AppTheme.sans(11, p.isCapped ? sub : tert),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _reserveRow(String label, String value, Color ink, Color sub, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.sans(13, sub)),
        Text(value,
            style: AppTheme.sans(emphasize ? 15 : 13, ink, weight: emphasize ? FontWeight.w800 : FontWeight.w700)),
      ],
    );
  }

  Widget _dowLabel(int i) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    final isSun = i == 6;
    final isSat = i == 5;
    return Text(labels[i],
        style: AppTheme.label(context,
            color: isSun
                ? AppTheme.colorDanger
                : isSat
                    ? AppTheme.accentColor(context)
                    : null));
  }

  /// 요일 행 오버레이 — 2단계 가로 폭/스크롤을 반영해 날짜 칸 위에 정렬
  Widget _buildOverlayDow() {
    final vp = _vp;
    if (vp == Size.zero || _zoomLevel == 1) {
      return SizedBox(
        height: 28,
        child: Row(
          children: List.generate(
              7, (i) => Expanded(child: Center(child: _dowLabel(i)))),
        ),
      );
    }
    final cellW = vp.width / 7 * 2; // 2단계: 한 칸 = 날짜칸 2개 폭
    return SizedBox(
      height: 28,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          children: List.generate(7, (i) {
            final leftX = i * cellW + _panX;
            if (leftX + cellW < 0 || leftX > vp.width) return const SizedBox();
            return Positioned(
              left: leftX,
              width: cellW,
              top: 0,
              bottom: 0,
              child: Center(child: _dowLabel(i)),
            );
          }),
        ),
      ),
    );
  }

  // ── 달력 본체 ────────────────────────────────────────────────────

  /// 핀치를 놓을 때 손가락 벌어짐/오므림으로 단계 결정.
  void _resolvePinch() {
    if (_pinchRatio > 1.18 && _zoomLevel == 1) {
      _setZoom(2);
    } else if (_pinchRatio < 0.85 && _zoomLevel == 2) {
      _setZoom(1);
    }
    _pinchBaseDist = null;
    _pinchRatio = 1.0;
  }

  void _setZoom(int level) {
    if (level == _zoomLevel) return;
    setState(() {
      _zoomLevel = level;
      if (level == 1) {
        _panX = 0;
      } else {
        // 핀치 중심 열이 손가락 아래 유지되도록 가로 오프셋 설정.
        final w = _vp.width;
        double ratio = 0.5;
        if (_pointers.isNotEmpty) {
          final mid = _pointers.values.reduce((a, b) => a + b) /
              _pointers.length.toDouble();
          ratio = (mid.dx / w).clamp(0.0, 1.0);
        }
        _panX = (-ratio * w).clamp(-w, 0.0);
      }
    });
  }

  Widget _buildCalendar(Color ink, Color sub) {
    _cellKeys.clear();
    final lineColor = AppTheme.lineStrong(context);
    final weekCount = ((_daysInMonth + _firstOffset) / 7).ceil();

    return LayoutBuilder(builder: (context, constraints) {
      _vp = Size(constraints.maxWidth, constraints.maxHeight);
      final w = constraints.maxWidth;
      final zoomed = _zoomLevel > 1;
      final cw = zoomed ? w / 7 * 2 : w / 7;
      final ch = _zoomLevel == 1
          ? (constraints.maxHeight / weekCount).clamp(0.0, 74.0)
          : constraints.maxHeight / weekCount;
      final totalW = cw * 7;
      final minPanX = (w - totalW).clamp(double.negativeInfinity, 0.0);
      _minPanX = minPanX;

      // 단일 주(週) 행 위젯
      Widget buildRow(int row) => SizedBox(
        height: ch,
        child: Row(
          children: List.generate(7, (col) {
            final idx = row * 7 + col - _firstOffset;
            return SizedBox(
              width: cw,
              height: ch,
              child: (idx < 0 || idx >= _daysInMonth)
                  ? Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right:  BorderSide(color: lineColor, width: 1),
                          bottom: BorderSide(color: lineColor, width: 1),
                        ),
                      ),
                    )
                  : _buildCell(DateTime(_year, _month, idx + 1), ink, sub),
            );
          }),
        ),
      );

      // 행 목록을 핀치줌·패닝이 적용된 섹션 위젯으로 변환
      // (에디터와 독립 — 에디터는 이 변환 밖에 위치)
      Widget buildSection(List<Widget> rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        // 섹션 높이를 행 수로 고정 — 세로 스크롤뷰(무한 높이) 안에서
        // OverflowBox가 세로로 붕괴하지 않도록. OverflowBox는 가로 줌 패닝 전용.
        final sectionHeight = rows.length * ch;
        final g = Container(
          width: totalW,
          height: sectionHeight,
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            border: Border(left: BorderSide(color: lineColor, width: 1)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        );
        return SizedBox(
          width: w,
          height: sectionHeight,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: sectionHeight,
              maxHeight: sectionHeight,
              child: Transform.translate(
                offset: Offset(_panX, 0),
                child: g,
              ),
            ),
          ),
        );
      }

      final allRows = <Widget>[for (int row = 0; row < weekCount; row++) buildRow(row)];

      final touchArea = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          _panFlingCtrl.stop();
          _activePointers++;
          _pointers[e.pointer] = e.position;
          _downPos = e.position;
          if (_pointers.length >= 2) {
            _dragStart = null;
            final pts = _pointers.values.toList();
            _pinchBaseDist = (pts[0] - pts[1]).distance;
            return;
          }
          if (zoomed) return;
          final date = _dateAtGlobal(e.position);
          if (date == null) return;
          setState(() {
            _dragStart = date;
            _dragCurrent = date;
            _isDragging = false;
          });
        },
        onPointerMove: (e) {
          if (_pointers.containsKey(e.pointer)) _pointers[e.pointer] = e.position;
          if (_pointers.length >= 2) {
            final pts = _pointers.values.toList();
            final dist = (pts[0] - pts[1]).distance;
            if (_pinchBaseDist != null && _pinchBaseDist! > 0) {
              _pinchRatio = dist / _pinchBaseDist!;
            }
            return;
          }
          if (zoomed) {
            final moved = _downPos == null ? 999.0 : (e.position - _downPos!).distance;
            if (moved < 20) return;
            _panVTracker.addPosition(e.timeStamp, e.position);
            setState(() {
              _panX = (_panX + e.delta.dx).clamp(minPanX, 0.0);
            });
            return;
          }
          if (_dragStart == null) return;
          final date = _dateAtGlobal(e.position);
          if (date == null || date == _dragCurrent) return;
          _dragCurrent = date;
          setState(() {
            _isDragging = true;
            _selected..clear()..addAll(_rangeBetween(_dragStart!, date));
          });
        },
        onPointerUp: (e) {
          final wasPinch = _pointers.length >= 2 || _pinchBaseDist != null;
          _pointers.remove(e.pointer);
          _activePointers = (_activePointers - 1).clamp(0, 10);
          if (wasPinch) {
            if (_pointers.isEmpty) _resolvePinch();
            _dragStart = null;
            return;
          }
          final moved = _downPos == null ? 999.0 : (e.position - _downPos!).distance;
          if (zoomed) {
            if (moved < 20) {
              final date = _dateAtGlobal(e.position);
              if (date != null) _toggleSingle(date);
            } else {
              final vel = _panVTracker.getVelocity().pixelsPerSecond.dx;
              if (vel.abs() > 80) {
                _panFlingCtrl.value = _panX;
                _panFlingCtrl.animateWith(FrictionSimulation(0.135, _panX, vel));
              }
            }
            _dragStart = null;
            return;
          }
          if (_dragStart != null && !_isDragging) {
            _toggleSingle(_dragStart!);
          } else if (_isDragging) {
            setState(() => _isDragging = false);
            _prefillForm();
            _openDayEntry();
          }
          _dragStart = null;
          _dragCurrent = null;
        },
        onPointerCancel: (e) {
          _pointers.remove(e.pointer);
          _activePointers = (_activePointers - 1).clamp(0, 10);
        },
        // 다중 날짜 드래그 중(_isDragging)에만 스크롤을 막아 그리드가 손 밑에서 밀리지 않게 한다.
        child: SingleChildScrollView(
          controller: _calScrollCtrl,
          physics: _isDragging ? const NeverScrollableScrollPhysics() : null,
          child: buildSection(allRows),
        ),
      );

      return Column(
        children: [
          _buildOverlayDow(),
          Container(height: 1, color: lineColor),
          Expanded(child: touchArea),
        ],
      );
    });
  }

  Widget _buildCell(DateTime date, Color ink, Color sub) {
    final key = _key(date);
    final gkey = _cellKeys[key] = GlobalKey();
    final isSun = date.weekday == DateTime.sunday;
    final isSat = date.weekday == DateTime.saturday;
    final isHoliday = KrHolidays.isHoliday(date);
    final dayColor = (isSun || isHoliday)
        ? AppTheme.colorDanger
        : isSat
            ? AppTheme.accentColor(context)
            : ink;
    final isSelected = _selected.contains(date);
    final isDark = AppTheme.isDark(context);
    final accent = AppTheme.accentColor(context);
    final lineColor = AppTheme.lineStrong(context);

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    final income = _incomeOf(key);
    final dayExps = (_expensesByDay[key] ?? []).toSet().toList();

    // 선택 연결
    final prevDay = date.subtract(const Duration(days: 1));
    final nextDay = date.add(const Duration(days: 1));
    final selConnLeft  = isSelected && _selected.contains(prevDay);
    final selConnRight = isSelected && _selected.contains(nextDay);
    final selBg = accent.withValues(alpha: isDark ? 0.24 : 0.12);

    // 날짜 숫자
    final bool todayPill = isToday && !isSelected;
    final Widget dayNumber = Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: todayPill ? BoxDecoration(color: accent, shape: BoxShape.circle) : null,
      child: Text('${date.day}',
          style: AppTheme.sans(13,
              todayPill ? Colors.white : dayColor,
              weight: (isSelected || isToday) ? FontWeight.w800 : FontWeight.w600)),
    );

    // 범위 지출 (endDate가 있고 시작일과 다른 것)
    final rangeExps = dayExps
        .where((e) => e.endDate != null &&
            !(e.endDate!.year == e.date.year &&
              e.endDate!.month == e.date.month &&
              e.endDate!.day == e.date.day))
        .toList();

    // 범위 지출 deduplicate: 같은 날짜범위+결제수단은 1개만
    final seenBars = <String>{};
    final uniqueRangeExps = <ExpenseItem>[];
    for (final e in rangeExps) {
      final bk = '${e.date.day}_${e.endDate!.day}_${e.paymentMethod}';
      if (seenBars.add(bk)) uniqueRangeExps.add(e);
    }
    final bars = uniqueRangeExps.take(3).toList();

    // 단일 지출 (범위 아님)
    final singleExps = dayExps.where((e) =>
        e.endDate == null ||
        (e.endDate!.year == e.date.year &&
         e.endDate!.month == e.date.month &&
         e.endDate!.day == e.date.day)).toList();
    final hasCr  = singleExps.any((e) => e.paymentMethod == _catCredit);
    final hasDeb = singleExps.any((e) => e.paymentMethod == _catDebit);
    final hasOth = singleExps.any((e) => e.paymentMethod == _catOther);

    // 범위 바 빌더
    Widget rangeBar(ExpenseItem e) {
      final isBarStart = e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day;
      final isBarEnd = e.endDate != null &&
          e.endDate!.year == date.year &&
          e.endDate!.month == date.month &&
          e.endDate!.day == date.day;
      final color = _pmColorOf(e.paymentMethod);
      return Container(
        height: 7,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.only(
            topLeft:     isBarStart ? const Radius.circular(4) : Radius.zero,
            bottomLeft:  isBarStart ? const Radius.circular(4) : Radius.zero,
            topRight:    isBarEnd   ? const Radius.circular(4) : Radius.zero,
            bottomRight: isBarEnd   ? const Radius.circular(4) : Radius.zero,
          ),
        ),
        margin: EdgeInsets.only(
          left:  isBarStart ? 5 : 0,
          right: isBarEnd   ? 5 : 0,
          bottom: 2,
        ),
      );
    }

    // ── 2단계 레인: 점(단일) → 막대(범위)로 같은 줄에서 바로 연결 ──
    Widget laneBar(Color color, bool range, bool start, bool end, int amt, String sign) {
      final roundL = !range || start;
      final roundR = !range || end;
      return Container(
        height: 13,
        margin: EdgeInsets.only(left: roundL ? 4 : 0, right: roundR ? 4 : 0, bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(roundL ? 6 : 0),
            right: Radius.circular(roundR ? 6 : 0),
          ),
        ),
        // 시작 칸에만 금액 표기 — 범위 중간/끝은 막대만 이어짐.
        child: (roundL && amt > 0)
            ? Text('$sign${_fmt.format(amt)}',
                style: AppTheme.sans(8.5, Colors.white, weight: FontWeight.w700),
                softWrap: false, overflow: TextOverflow.clip)
            : null,
      );
    }

    Widget? laneInc() {
      if (income == 0) return null;
      IncomeEntry? r;
      for (final e in (_incomesByDay[key] ?? const <IncomeEntry>[])) {
        if (e.endDate != null &&
            !(e.endDate!.year == e.date.year &&
              e.endDate!.month == e.date.month &&
              e.endDate!.day == e.date.day)) { r = e; break; }
      }
      if (r == null) return laneBar(_incomeColor, false, true, true, income, '+');
      final st = r.date.month == date.month && r.date.day == date.day;
      final en = r.endDate!.month == date.month && r.endDate!.day == date.day;
      return laneBar(_incomeColor, true, st, en, income, '+');
    }

    Widget? laneExp(String pm, Color color) {
      final amt = _paymentOf(key, pm);
      if (amt == 0) return null;
      ExpenseItem? r;
      for (final e in dayExps.where((e) => e.paymentMethod == pm)) {
        if (e.endDate != null &&
            !(e.endDate!.year == e.date.year &&
              e.endDate!.month == e.date.month &&
              e.endDate!.day == e.date.day)) { r = e; break; }
      }
      if (r == null) return laneBar(color, false, true, true, amt, '-');
      final st = r.date.month == date.month && r.date.day == date.day;
      final en = r.endDate!.month == date.month && r.endDate!.day == date.day;
      return laneBar(color, true, st, en, amt, '-');
    }

    final crLane = laneExp(_catCredit, _pmCreditColor);
    final dbLane = laneExp(_catDebit, _pmDebitColor);
    final otLane = laneExp(_catOther, _pmOtherColor);
    final incLane = laneInc();

    final l2Content = Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.topLeft, child: dayNumber),
          const SizedBox(height: 3),
          if (incLane != null) incLane,
          if (crLane != null) crLane,
          if (dbLane != null) dbLane,
          if (otLane != null) otLane,
        ],
      ),
    );

    final l1Content = Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dayNumber,
                const SizedBox(height: 2),
                SizedBox(
                  width: double.infinity,
                  child: bars.isEmpty
                      ? Wrap(
                          spacing: 3, runSpacing: 3,
                          alignment: WrapAlignment.center,
                          runAlignment: WrapAlignment.start,
                          children: [
                            if (income > 0) _catDot(_incomeColor, isDark),
                            if (hasCr) _catDot(_pmCreditColor, isDark),
                            if (hasDeb) _catDot(_pmDebitColor, isDark),
                            if (hasOth) _catDot(_pmOtherColor, isDark),
                          ],
                        )
                      : income > 0
                          ? Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _catDot(_incomeColor, isDark),
                            )
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        if (bars.isNotEmpty)
          Positioned(
            left: 0, right: 0, bottom: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: bars.map(rangeBar).toList(),
            ),
          ),
      ],
    );

    return Container(
        key: gkey,
        decoration: BoxDecoration(
          border: Border(
            right:  BorderSide(color: lineColor, width: 1),
            bottom: BorderSide(color: lineColor, width: 1),
          ),
        ),
        child: Stack(
          children: [
            // ① 선택 배경 (inner margin 유지)
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.only(
                  left:  selConnLeft  ? 0 : 2,
                  right: selConnRight ? 0 : 2,
                  top: 2, bottom: 2,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? selBg : null,
                  borderRadius: BorderRadius.only(
                    topLeft:     selConnLeft  ? Radius.zero : const Radius.circular(6),
                    bottomLeft:  selConnLeft  ? Radius.zero : const Radius.circular(6),
                    topRight:    selConnRight ? Radius.zero : const Radius.circular(6),
                    bottomRight: selConnRight ? Radius.zero : const Radius.circular(6),
                  ),
                ),
              ),
            ),

            // ② 셀 콘텐츠 — 단계 전환 시 페이드
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: KeyedSubtree(
                  key: ValueKey('${date.day}_$_zoomLevel'),
                  child: _showAmounts ? l2Content : l1Content,
                ),
              ),
            ),
          ],
        ),
      );
  }

  Color _pmColorOf(String pm) {
    switch (pm) {
      case _catCredit: return _pmCreditColor;
      case _catDebit:  return _pmDebitColor;
      default:         return _pmOtherColor;
    }
  }

  /// 카테고리 색 점 — 숫자 대신 무슨 항목이 있는지 색으로 표시
  Widget _catDot(Color color, bool isDark) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
    );
  }

  // ── 분석 뷰 ──────────────────────────────────────────────────────

  static const _taxDeductCats = {
    '의료/건강': '의료비 세액공제 (15%)',
    '교육':     '교육비 세액공제 (15%)',
    '보험/금융': '보험료 세액공제 (12%)',
    '기부':     '기부금 세액공제 (15%, 1천만 초과분 30%)',
  };

  /// 지출 목표 설정/수정 — 분석 탭에서 직접 입력. 홈 화면은 표시 전용이라
  /// 목표를 정하는 곳은 여기 하나뿐이다.
  Future<void> _showExpenseTargetDialog() async {
    final ctrl = TextEditingController(
      text: _expenseTarget > 0 ? _fmt.format(_expenseTarget) : '');
    final ink = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);
    final bg = AppTheme.backgroundColor(context);
    final line = AppTheme.line(context);
    final sub = AppTheme.inkSecondary(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: line),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          title: Text('이달 지출 목표', style: AppTheme.serif(17, ink)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: const [ThousandsFormatter()],
            textAlign: TextAlign.right,
            style: AppTheme.sans(15, ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: '예: 1,500,000',
              hintStyle: AppTheme.sans(15, AppTheme.inkTertiary(ctx)),
              suffixText: '원',
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: UnderlineInputBorder(borderSide: BorderSide(color: line)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: line)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent, width: 1.5)),
            ),
            onChanged: (v) {
              final n = v.replaceAll(RegExp(r'[^0-9]'), '');
              final f = n.isEmpty ? '' : _fmt.format(int.parse(n));
              ctrl.value = TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
            },
          ),
          actions: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 8, 12),
                child: Text('취소', style: AppTheme.sans(14, sub)),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                child: Text('저장', style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
              ),
            ),
          ],
        );
      },
    );

    final val = double.tryParse(ctrl.text.replaceAll(',', '')) ?? 0.0;
    ctrl.dispose();
    if (confirmed != true || !mounted) return;
    await dbService.setProfileTypeValues(_userType, expenseTarget: val);
    if (mounted) setState(() => _expenseTarget = val.toInt());
  }

  Widget _buildAnalysisView(Color ink, Color sub) {
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final allExps = _expensesByDay.values.expand((l) => l).toSet().toList();
    final totalExp = allExps.fold(0, (s, e) => s + e.amount);
    final totalInc = _monthIncomeTotal;

    // 전월 데이터
    final prevMonth = _month == 1 ? 12 : _month - 1;
    final prevYear  = _month == 1 ? _year - 1 : _year;
    final prevExps  = _allExpenses
        .where((e) => e.date.year == prevYear && e.date.month == prevMonth)
        .toList();
    final prevCatTotals = <String, int>{};
    for (final e in prevExps) {
      prevCatTotals[e.category] = (prevCatTotals[e.category] ?? 0) + e.amount;
    }
    final prevTotal = prevExps.fold(0, (s, e) => s + e.amount);

    // 카테고리별
    final catTotals = <String, int>{};
    for (final e in allExps) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 결제수단별
    final pmTotals = <String, int>{'신용카드': 0, '체크+현금': 0, '기타': 0};
    for (final e in allExps) {
      if (e.paymentMethod == _catCredit)      pmTotals['신용카드'] = pmTotals['신용카드']! + e.amount;
      else if (e.paymentMethod == _catDebit)  pmTotals['체크+현금'] = pmTotals['체크+현금']! + e.amount;
      else                                    pmTotals['기타'] = pmTotals['기타']! + e.amount;
    }

    // 세금 공제 가능
    final taxCatAmounts = <String, int>{};
    for (final cat in _taxDeductCats.keys) {
      final amt = catTotals[cat] ?? 0;
      if (amt > 0) taxCatAmounts[cat] = amt;
    }
    final totalTaxDeduct = taxCatAmounts.values.fold(0, (s, v) => s + v);

    final hasData = totalExp > 0;
    final totalBusinessExp = allExps.where((e) => e.isBusiness).fold(0, (s, e) => s + e.amount);

    // 신용카드 공제 문턱 — 연 누적(1월~오늘) 기준. 문턱(최저사용금액, 조특법 §126의2)
    // 판정은 신용+체크·현금 "합계"라서 신용만 세면 진행률이 실제보다 낮게 나온다.
    // ('기타' 결제수단은 현금영수증 없는 지출로 보아 제외 — 홈과 같은 규칙.)
    final now = DateTime.now();
    final firstOfYear = DateTime(now.year, 1, 1);
    final cardEligibleYtd = _allExpenses
        .where((e) =>
            (e.paymentMethod == _catCredit || e.paymentMethod == _catDebit) &&
            !e.date.isBefore(firstOfYear) &&
            !e.date.isAfter(now))
        .fold(0, (s, e) => s + e.amount);
    final hasThreshold = _profile.showsCardThreshold && _grossIncome > 0;
    final cardThreshold = _grossIncome * 0.25;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [

        // ── 이달 요약 ──────────────────────────────────────
        Text('이달 요약'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 12),
        Row(children: [
          _summaryCell('수입', totalInc, _incomeColor, ink, sub),
          Container(width: 1, height: 44, color: AppTheme.line(context)),
          _summaryCell('지출', totalExp, AppTheme.colorDanger, ink, sub),
          Container(width: 1, height: 44, color: AppTheme.line(context)),
          _summaryCell(
            '잔액',
            // 적자면 '-950,000원'처럼 마이너스 기호를 그대로 노출(색 + 부호 이중 신호).
            totalInc - totalExp,
            totalInc - totalExp >= 0 ? _incomeColor : AppTheme.colorDanger,
            ink, sub,
          ),
        ]),
        const SizedBox(height: 20),
        AppTheme.hairline(context),

        // ── D. 지출 목표 ──────────────────────────────────
        const SizedBox(height: 20),
        Row(children: [
          Text('지출 목표'.toUpperCase(), style: AppTheme.label(context)),
          const Spacer(),
          GestureDetector(
            onTap: _showExpenseTargetDialog,
            behavior: HitTestBehavior.opaque,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.tune_rounded, size: 13, color: accent),
              const SizedBox(width: 4),
              Text(_expenseTarget > 0 ? '수정' : '설정',
                  style: AppTheme.sans(12, accent, weight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        if (_expenseTarget > 0)
          _analysisSimpleBar(
            label: '목표 ${_fmt.format(_expenseTarget)}원',
            amount: totalExp,
            max: _expenseTarget,
            color: totalExp > _expenseTarget
                ? AppTheme.colorDanger
                : accent,
            trailText: totalExp > _expenseTarget
                ? '목표 ${_fmt.format(totalExp - _expenseTarget)}원 초과'
                : '${_fmt.format(_expenseTarget - totalExp)}원 남음',
            ink: ink, sub: sub,
          )
        else
          Text('이달 지출 목표를 설정하면 달성률을 여기서 확인할 수 있어요.'.keepWords,
              style: AppTheme.sans(13, tert, height: 1.5)),
        const SizedBox(height: 20),
        AppTheme.hairline(context),

        // ── A. 결제수단별 ─────────────────────────────────
        if (hasData) ...[
          const SizedBox(height: 20),
          Text('결제수단별'.toUpperCase(), style: AppTheme.label(context)),
          const SizedBox(height: 10),
          _analysisSimpleBar(
            label: '신용카드',
            amount: pmTotals['신용카드']!,
            max: totalExp,
            color: _pmCreditColor,
            ink: ink, sub: sub,
          ),
          const SizedBox(height: 8),
          _analysisSimpleBar(
            label: '체크+현금',
            amount: pmTotals['체크+현금']!,
            max: totalExp,
            color: _pmDebitColor,
            ink: ink, sub: sub,
          ),
          const SizedBox(height: 8),
          _analysisSimpleBar(
            label: '기타',
            amount: pmTotals['기타']!,
            max: totalExp,
            color: _pmOtherColor,
            ink: ink, sub: sub,
          ),
          const SizedBox(height: 20),
          AppTheme.hairline(context),
        ],

        // ── 인정 경비(사업경비) 합계 — 프리랜서·N잡러만 ──
        if (_isBusinessUser) ...[
          const SizedBox(height: 20),
          Row(children: [
            Text('인정 경비 합계'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(width: 8),
            if (totalBusinessExp > 0)
              AppTheme.blueprintBadge(context, '${_fmt.format(totalBusinessExp)}원'),
          ]),
          const SizedBox(height: 10),
          if (totalBusinessExp == 0)
            Text('지출 입력 시 "사업경비로 인정"을 체크하면 여기에 합산돼요.'.keepWords,
                style: AppTheme.sans(13, tert, height: 1.5))
          else
            _analysisSimpleBar(
              label: '사업경비 처리',
              amount: totalBusinessExp,
              max: totalExp,
              color: accent,
              ink: ink, sub: sub,
            ),
          const SizedBox(height: 20),
          AppTheme.hairline(context),
        ],

        // ── 신용카드 공제 문턱 (연봉 있는 직장인·N잡러) ──
        if (hasThreshold) ...[
          const SizedBox(height: 20),
          Text('카드 공제 문턱'.toUpperCase(), style: AppTheme.label(context)),
          const SizedBox(height: 10),
          _analysisSimpleBar(
            label: '연봉의 25% (${_fmt.format(cardThreshold.toInt())}원)',
            amount: cardEligibleYtd,
            max: cardThreshold.toInt(),
            color: cardEligibleYtd >= cardThreshold ? AppTheme.colorSuccess : accent,
            trailText: cardEligibleYtd >= cardThreshold
                ? '돌파 — 체크·현금이 공제율 2배예요'
                : '${_fmt.format(cardThreshold.toInt() - cardEligibleYtd)}원 남음',
            ink: ink, sub: sub,
          ),
          const SizedBox(height: 20),
          AppTheme.hairline(context),
        ],

        // ── E. 세금 공제 가능 지출 ───────────────────────
        const SizedBox(height: 20),
        Row(children: [
          Text('세금 공제 가능 지출'.toUpperCase(), style: AppTheme.label(context)),
          const SizedBox(width: 8),
          if (totalTaxDeduct > 0)
            AppTheme.blueprintBadge(context, '${_fmt.format(totalTaxDeduct)}원'),
        ]),
        const SizedBox(height: 10),
        if (totalTaxDeduct == 0)
          Text('의료비·교육비·보험료·기부금을 입력하면 공제 예상액을 볼 수 있어요.'.keepWords,
              style: AppTheme.sans(13, tert, height: 1.5))
        else
          for (final entry in taxCatAmounts.entries) ...[
            _taxDeductRow(entry.key, entry.value, ink, sub),
            const SizedBox(height: 6),
          ],
        const SizedBox(height: 20),
        AppTheme.hairline(context),

        // ── 카테고리별 ───────────────────────────────────
        if (hasData) ...[
          const SizedBox(height: 20),
          Text('카테고리별'.toUpperCase(), style: AppTheme.label(context)),
          const SizedBox(height: 14),
          for (final entry in sortedCats) ...[
            _analysisCatBar(entry.key, entry.value, totalExp, ink, sub),
            const SizedBox(height: 14),
          ],
          AppTheme.hairline(context),
        ],

        // ── C. 전월 대비 ──────────────────────────────────
        const SizedBox(height: 20),
        Text('전월 대비'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 10),
        _prevMonthSection(catTotals, prevCatTotals, totalExp, prevTotal, ink, sub, tert),
        const SizedBox(height: 8),

      ],
    );
  }

  Widget _summaryCell(String label, int amount, Color color, Color ink, Color sub) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTheme.sans(11, sub, weight: FontWeight.w500, spacing: 0.3)),
          const SizedBox(height: 2),
          Text('${_fmt.format(amount)}원',
              style: AppTheme.sans(13, color, weight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _analysisSimpleBar({
    required String label,
    required int amount,
    required int max,
    required Color color,
    String? trailText,
    required Color ink,
    required Color sub,
  }) {
    final pct = max > 0 ? (amount / max).clamp(0.0, 1.0) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: AppTheme.sans(13, ink, weight: FontWeight.w600))),
        Text(trailText ?? '${_fmt.format(amount)}원  ${(pct * 100).round()}%',
            style: AppTheme.sans(12, sub)),
      ]),
      const SizedBox(height: 5),
      LayoutBuilder(builder: (ctx, c) => Stack(children: [
        Container(height: 5, width: c.maxWidth,
            decoration: BoxDecoration(color: AppTheme.line(context), borderRadius: BorderRadius.circular(2))),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut,
          height: 5, width: c.maxWidth * pct,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
      ])),
    ]);
  }

  Widget _taxDeductRow(String catId, int amount, Color ink, Color sub) {
    final cat = expenseCategoryById(catId);
    final hint = _taxDeductCats[catId] ?? '';
    return Row(children: [
      Icon(cat.icon, size: 13, color: cat.color),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(cat.label, style: AppTheme.sans(13, ink, weight: FontWeight.w600)),
        Text(hint, style: AppTheme.sans(11, AppTheme.inkTertiary(context))),
      ])),
      Text('${_fmt.format(amount)}원', style: AppTheme.sans(13, sub, weight: FontWeight.w600)),
    ]);
  }

  Widget _prevMonthSection(
    Map<String, int> cur, Map<String, int> prev,
    int curTotal, int prevTotal,
    Color ink, Color sub, Color tert,
  ) {
    final diff = curTotal - prevTotal;
    final noData = prevTotal == 0 && curTotal == 0;

    if (noData) {
      return Text('전월 데이터가 없어요.', style: AppTheme.sans(13, tert));
    }

    // 가장 많이 증가한 카테고리
    String? topIncrCat;
    int topIncrDiff = 0;
    for (final cat in cur.keys) {
      final d = (cur[cat] ?? 0) - (prev[cat] ?? 0);
      if (d > topIncrDiff) { topIncrDiff = d; topIncrCat = cat; }
    }

    final overallColor = diff <= 0 ? _incomeColor : AppTheme.colorDanger;
    final overallSign  = diff <= 0 ? '▼ ' : '▲ ';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('전체 지출 ', style: AppTheme.sans(13, sub)),
        Text('$overallSign${_fmt.format(diff.abs())}원',
            style: AppTheme.sans(13, overallColor, weight: FontWeight.w700)),
        Text(prevTotal > 0
            ? '  (${((diff.abs() / prevTotal) * 100).round()}%)'
            : '',
            style: AppTheme.sans(12, tert)),
      ]),
      if (topIncrCat != null) ...[
        const SizedBox(height: 6),
        Row(children: [
          Icon(expenseCategoryById(topIncrCat).icon, size: 13,
              color: expenseCategoryById(topIncrCat).color),
          const SizedBox(width: 5),
          Text('${expenseCategoryById(topIncrCat).label} 지출이 가장 많이 늘었어요 '
              '(+${_fmt.format(topIncrDiff)}원)',
              style: AppTheme.sans(12, sub, height: 1.4)),
        ]),
      ],
    ]);
  }

  Widget _analysisCatBar(String catId, int amount, int total, Color ink, Color sub) {
    final cat = expenseCategoryById(catId);
    final pct = total > 0 ? amount / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(cat.icon, size: 14, color: cat.color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(cat.label,
                  style: AppTheme.sans(13, ink, weight: FontWeight.w600)),
            ),
            Text('${_fmt.format(amount)}원',
                style: AppTheme.sans(13, sub, weight: FontWeight.w600)),
            const SizedBox(width: 8),
            SizedBox(
              width: 38,
              child: Text('${(pct * 100).round()}%'.keepWords,
                  style: AppTheme.sans(12, AppTheme.inkTertiary(context)),
                  textAlign: TextAlign.right),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, constraints) {
          return Stack(children: [
            Container(
              height: 5,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: AppTheme.line(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              height: 5,
              width: constraints.maxWidth * pct,
              decoration: BoxDecoration(
                color: cat.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ]);
        }),
      ],
    );
  }

  // ── 연간 뷰 ──────────────────────────────────────────────────────

  Widget _buildAnnualView(Color ink, Color sub) {
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final yearExps = _allExpenses.where((e) => e.date.year == _year).toList();

    final monthExp = <int, int>{};
    for (final e in yearExps) {
      monthExp[e.date.month] = (monthExp[e.date.month] ?? 0) + e.amount;
    }

    // 순수익 = 수입 - 지출 (월별)
    final monthNet = <int, int>{};
    for (int m = 1; m <= 12; m++) {
      monthNet[m] = (_annualIncome[m] ?? 0) - (monthExp[m] ?? 0);
    }
    final maxAbs = monthNet.values.fold(0, (mx, v) => v.abs() > mx ? v.abs() : mx);

    // 연간 세금 공제 가능 지출 — 월간 분석의 카테고리 정의를 그대로 1년치로 집계.
    final yearCatTotals = <String, int>{};
    for (final e in yearExps) {
      yearCatTotals[e.category] = (yearCatTotals[e.category] ?? 0) + e.amount;
    }
    final yearTaxCatAmounts = <String, int>{};
    for (final cat in _taxDeductCats.keys) {
      final amt = yearCatTotals[cat] ?? 0;
      if (amt > 0) yearTaxCatAmounts[cat] = amt;
    }
    final yearTotalTaxDeduct = yearTaxCatAmounts.values.fold(0, (s, v) => s + v);

    // 연간 카드 문턱 — 조회 연도가 올해면 1/1~오늘, 지난 연도면 1년 전체.
    // 문턱 판정은 신용+체크·현금 합계 기준(조특법 §126의2) — 분석 뷰·홈과 같은 규칙.
    final now = DateTime.now();
    final isCurrentYear = _year == now.year;
    final yearEnd = isCurrentYear ? now : DateTime(_year, 12, 31);
    final cardEligibleYtd = yearExps
        .where((e) =>
            (e.paymentMethod == _catCredit || e.paymentMethod == _catDebit) &&
            !e.date.isAfter(yearEnd))
        .fold(0, (s, e) => s + e.amount);
    final hasThreshold = _profile.showsCardThreshold && _grossIncome > 0;
    final cardThreshold = _grossIncome * 0.25;

    // 연간 사업경비 총액 — 프리랜서·N잡러만.
    final yearBusinessExp = yearExps.where((e) => e.isBusiness).fold(0, (s, e) => s + e.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // ── 연간 세금 공제 가능 지출 ──────────────────────
        Row(children: [
          Text('$_year년 세금 공제 가능 지출'.toUpperCase(), style: AppTheme.label(context)),
          const SizedBox(width: 8),
          if (yearTotalTaxDeduct > 0)
            AppTheme.blueprintBadge(context, '${_fmt.format(yearTotalTaxDeduct)}원'),
        ]),
        const SizedBox(height: 10),
        if (yearTotalTaxDeduct == 0)
          Text('의료비·교육비·보험료·기부금을 기록하면 1년 합계를 여기서 볼 수 있어요.'.keepWords,
              style: AppTheme.sans(13, tert, height: 1.5))
        else
          for (final entry in yearTaxCatAmounts.entries) ...[
            _taxDeductRow(entry.key, entry.value, ink, sub),
            const SizedBox(height: 6),
          ],
        const SizedBox(height: 8),
        Text('가계부 기록 기준 참고값이에요. 실제 공제액은 홈택스 간소화 자료로 확인하세요.'.keepWords,
            style: AppTheme.sans(11.5, tert, height: 1.4)),
        const SizedBox(height: 20),
        AppTheme.hairline(context),

        // ── 연간 신용카드 공제 문턱 ────────────────────────
        if (hasThreshold) ...[
          const SizedBox(height: 20),
          Text('$_year년 카드 공제 문턱'.toUpperCase(), style: AppTheme.label(context)),
          const SizedBox(height: 10),
          _analysisSimpleBar(
            label: '연봉의 25% (${_fmt.format(cardThreshold.toInt())}원)',
            amount: cardEligibleYtd,
            max: cardThreshold.toInt(),
            color: cardEligibleYtd >= cardThreshold ? AppTheme.colorSuccess : accent,
            trailText: cardEligibleYtd >= cardThreshold
                ? '돌파 — 체크·현금이 공제율 2배예요'
                : '${_fmt.format(cardThreshold.toInt() - cardEligibleYtd)}원 남음',
            ink: ink, sub: sub,
          ),
          const SizedBox(height: 20),
          AppTheme.hairline(context),
        ],

        // ── 연간 인정 경비(사업경비) 합계 ───────────────────
        if (_isBusinessUser) ...[
          const SizedBox(height: 20),
          Row(children: [
            Text('$_year년 인정 경비 합계'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(width: 8),
            if (yearBusinessExp > 0)
              AppTheme.blueprintBadge(context, '${_fmt.format(yearBusinessExp)}원'),
          ]),
          const SizedBox(height: 10),
          if (yearBusinessExp == 0)
            Text('지출 입력 시 "사업경비로 인정"을 체크하면 여기에 합산돼요.'.keepWords,
                style: AppTheme.sans(13, tert, height: 1.5))
          else
            Text('${_fmt.format(yearBusinessExp)}원', style: AppTheme.sans(20, ink, weight: FontWeight.w700)),
          const SizedBox(height: 20),
          AppTheme.hairline(context),
        ],

        // ── 월별 순수익 ─────────────────────────────────
        const SizedBox(height: 20),
        Text('$_year년 순수익'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 4),
        Text('수입 − 지출', style: AppTheme.sans(12, tert)),
        const SizedBox(height: 16),
        for (int m = 1; m <= 12; m++) ...[
          _annualMonthRow(m, monthNet[m] ?? 0, maxAbs, ink, sub),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _annualMonthRow(int month, int net, int maxAbs, Color ink, Color sub) {
    final isCurrent = month == _month;
    final accent = AppTheme.accentColor(context);
    final isPositive = net >= 0;
    final barColor = isCurrent
        ? accent
        : isPositive
            ? _incomeColor.withValues(alpha: 0.7)
            : AppTheme.colorDanger.withValues(alpha: 0.7);
    final labelColor = isCurrent ? accent : sub;
    final netAbs = net.abs();

    return GestureDetector(
      onTap: () {
        setState(() {
          _month = month;
          _activeView = 0;
          _selected.clear();
          _clearForm();
        });
        _load();
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('${month}월',
                style: AppTheme.sans(13, labelColor,
                    weight: isCurrent ? FontWeight.w800 : FontWeight.w500)),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final barW = maxAbs > 0
                  ? (netAbs / maxAbs) * constraints.maxWidth
                  : 0.0;
              return Stack(alignment: Alignment.centerLeft, children: [
                Container(
                  height: 8,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: AppTheme.line(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (barW > 0)
                  Container(
                    height: 8,
                    width: barW,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ]);
            }),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              net == 0 ? '—' : '${isPositive ? '+' : '-'}${_fmt.format(netAbs)}원',
              style: AppTheme.sans(12,
                  net == 0
                      ? AppTheme.inkTertiary(context)
                      : isPositive ? _incomeColor : AppTheme.colorDanger,
                  weight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

}

