import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../theme/app_theme.dart';
import '../components/reminder_card.dart';
import 'onboarding_screen.dart';
import 'my_info_screen.dart';
import 'year_end_tax_screen.dart';
import 'tax_simulator_screen.dart';
import 'tax_persona_question_screen.dart';
import 'expense_calendar_screen.dart';
import 'missed_deduction_diagnosis_screen.dart';
import 'annual_backfill_screen.dart';
import 'tax_tools_screen.dart' show taxRecordEntryFor;
import 'settings_screen.dart';
import 'benefit_screen.dart';
import 'calculator_screen.dart';
import 'all_screen.dart';
import 'notification_inbox_screen.dart';
import 'home/tax_tools_accordion.dart';
import 'home/home_banner_carousel.dart';
import 'home/home_status_section.dart';
import '../../core/data/tax_tips.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/occupation_data.dart';
import '../../core/tax_engine/bookkeeping_duty.dart';
import '../../core/tax_engine/reserve_estimator.dart';
import '../../core/security/notification_helper.dart';
import '../../core/notifications/reminder_scheduler.dart';
import '../../core/navigation/app_route_observer.dart';
import '../theme/text_wrap.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  String _userType = '직장인'; 
  int _currentIndex = 0;

  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _savingGoalController = TextEditingController();
  final TextEditingController _monthlyRentController = TextEditingController();

  // 신용카드/체크+현금 당월 누계 (표시용)
  double _creditCardTotal = 0.0;
  double _debitCashTotal = 0.0;
  // 신용카드 연간(1월~오늘) 누계 — 공제 문턱(연봉의 25%)은 연 누적 기준이라 당월 합계와 분리.
  double _creditCardYtdTotal = 0.0;
  // 체크+현금 연간 누계 — 카드공제 환급 추정에 신용(15%)/체크·현금(30%) 분리 필요.
  double _debitCashYtdTotal = 0.0;
  // 프리랜서 '올해 쌓인 예상 환급'. null이면 계산 근거가 없다(업종·직전연도 수입 미입력 등).
  RefundProgress? _refundProgress;
  // N잡러 카드공제 절세액(종합 과세표준 기준). null이면 근로소득 기준 추정을 그대로 쓴다.
  double? _cardSavingCombined;

  // 신용카드/체크+현금 입력용 (더하기 버튼 전 임시값)
  final TextEditingController _creditCardInputController = TextEditingController();
  final TextEditingController _debitCashInputController = TextEditingController();
  

  final TextEditingController _freelancerIncomeController = TextEditingController();
  final TextEditingController _monthsController = TextEditingController(text: '12');
  final TextEditingController _yellowUmbrellaController = TextEditingController();

  // 절세 프로필 상태 변수
  // 부양가족 기본값은 0(본인만) — my_info·프로필 마법사와 같은 규칙. 1로 두면
  // 프로필 미설정 직장인의 간이세액(세후·환급)이 2인 가족 가정으로 계산된다.
  int _dependentCount = 0;
  // 자녀등 수 — 카드공제 기본한도 상향(조특법 §126의2⑩)에 쓰인다.
  int _childrenCount = 0;
  bool _isMonthlyRent = false;
  bool _isTypeIdentified = false;   // 유형 파악 완료 여부 (온보딩 1단계)
  bool _isProfileCompleted = false; // 프로필 완성 여부 (온보딩 2단계)
  bool _showBackfillPrompt = false; // 연중 가입 — 지난 달 소급 입력 유도 배너
  Set<String> _hiddenBannerIds = {}; // X로 닫은 배너 카드(30일간 숨김)
  double _decidedTax = 0.0; // 결정세액 (연말정산 진단 데이터)
  double _grossIncome = 0.0; // 연소득(연봉) (연말정산 진단 데이터)
  double _laborIncome = 0.0; // 이번 달 근로소득(급여) — N잡러 수입 분리
  double _otherIncome = 0.0; // 이번 달 기타 수익(프리랜서·부수입 등) — N잡러 수입 분리
  double _otherIncomeGrossEstimate = 0.0; // 기타 수익(사업/기타소득) 원천징수 역산 세전 추정 — 근로소득은 간이세액표 기반이라 역산 불가, 제외
  double _expenseTarget = 0.0; // 이번 달 지출 목표
  int _payDay = 25; // 직장인·N잡 월급여일 (1~31, 알림 넛지 기준)
  // 경비율 개인화 배너용 — 프로필(①진단)에 저장된 값이 있을 때만 카드 판단에 쓴다.
  String? _occupationCode;
  int _priorYearIncome = 0;
  bool _isNewBusiness = false;
  bool _notificationsEnabled = true; // 세금·가계부 알림 마스터 on/off (reminder_settings 'master'에 영속)
  bool _thresholdNotified = false; // 공제 문턱 도달 알림 중복 방지(세션 내)
  bool _thresholdNearNotified = false; // 공제 문턱 80% 임박 알림 중복 방지(세션 내)
  bool _budgetNearNotified = false; // 지출 목표 80% 알림 중복 방지(세션 내)
  bool _budgetOverNotified = false; // 지출 목표 초과 알림 중복 방지(세션 내)
  int _unreadNotifCount = 0; // 알림함 안읽음 배지

  // 홈 인라인 지출 목표 입력
  bool _showExpenseInput = false;
  final TextEditingController _expenseTargetInlineCtrl = TextEditingController();

  // FAQ 셔플 — 유형별 풀을 한 번 섞어두고 5개씩 창(window)으로 보여준다.
  // 버튼을 누르면 offset을 5씩 밀어 새 5개를 노출(끝에서 앞으로 순환)하므로, 계속 누르면 모든 질문을 볼 수 있다.
  List<Map<String, String>> _faqShuffled = [];
  int _faqOffset = 0;
  String _faqPoolType = ''; // 풀을 만든 기준 유형 — 유형이 바뀌면 다시 섞는다.

  bool get _isEmployee => _userType == '직장인' || _userType == 'N잡러';

  final _numberFormat = NumberFormat('#,###');

  // 홈 상단 회전 배너 (광고·알림 카드) — 6초마다 페이드 전환, 유형별 카드 세트
  int _bannerIndex = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    // 알림 권한 요청은 여기서 하지 않는다(U-1) — 리마인더 화면 진입/설정 알림 토글 시 요청.
    _salaryController.addListener(_calculateTax);
    _monthlyRentController.addListener(_calculateTax);
    _freelancerIncomeController.addListener(_calculateTax);
    _monthsController.addListener(_calculateTax);
    _yellowUmbrellaController.addListener(_calculateTax);
    _savingGoalController.addListener(_onExpenseTargetChanged);
    _loadDataFromDB();
    _startBannerRotation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  /// 홈에서 push했던 화면(가계부·프로필 등)이 pop되어 홈으로 돌아왔을 때 —
  /// 산재해있던 "push 후 수동 리로드" 호출들을 대체하는 단일 진입점.
  @override
  void didPopNext() {
    _loadTypeValues(_userType);
    _loadCurrentMonthIncome();
    _loadMonthlyExpenses();
  }

  /// 상단 배너 + 이달의 절세 카드 6초 자동 회전(페이드). 각자 2장 이상일 때만 전환.
  void _startBannerRotation() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      final bn = _bannerCards().length;
      if (bn <= 1) return;
      setState(() => _bannerIndex = (_bannerIndex + 1) % bn);
    });
  }

  /// 이번 달·유형에 맞는 절세 팁(회전용 최대 2장 — N잡러는 전체 7개 팁에 다 해당돼 과다 노출 방지).
  List<TaxTip> _currentTips() => taxTipsFor(_userType, DateTime.now().month, limit: 2);

  Future<void> _loadDataFromDB() async {
    try {
      final profile = await dbService.getProfile();
      if (profile != null && mounted) {
        setState(() {
          _userType = profile['user_type'] ?? '직장인';
          
          double monthlyIncome = 0.0;
          try {
            monthlyIncome = profile['monthly_income'] as double? ?? 0.0;
          } catch (_) {}

          if (monthlyIncome > 0) {
            _salaryController.text = _numberFormat.format(monthlyIncome.toInt());
          }
          
          _dependentCount = profile['dependents'] as int? ?? 0;
          _childrenCount = profile['children_count_total'] as int? ?? 0;
          _isMonthlyRent = profile['is_monthly_rent'] == true;
          
          final monthlyRent = profile['monthly_rent'] as double? ?? 0.0;
          if (monthlyRent > 0) {
            _monthlyRentController.text = _numberFormat.format(monthlyRent.toInt());
          }

          final yellowUmbrella = profile['yellow_umbrella'] as double? ?? 0.0;
          if (yellowUmbrella > 0) {
            _yellowUmbrellaController.text = _numberFormat.format(yellowUmbrella.toInt());
          }

          _decidedTax = profile['decided_tax'] as double? ?? 0.0;
          _payDay = (profile['pay_day'] as int? ?? 25).clamp(1, 31);
          _occupationCode = profile['occupation_code'] as String?;
          _priorYearIncome = (profile['prior_year_income'] as num?)?.toInt() ?? 0;
          _isNewBusiness = profile['is_new_business'] == true;
          _isTypeIdentified = profile['type_identified'] == true;
          _isProfileCompleted = true;
          // 기존 사용자 호환: 프로필이 있으면 유형 파악 완료로 처리
          if (!_isTypeIdentified) _isTypeIdentified = true;
        });
        await _loadTypeValues(_userType);
      }
    } catch (e) {
      // 핫 리로드 과도기 중 DB 필드 불일치 방어 — 운영 중 지속 실패면 로그로 드러나게.
      debugPrint('홈 프로필 로드 실패(기본값으로 진행): $e');
    }

    // 마스터 알림 토글 — reminder_settings 'master'(없으면 ON)에서 복원.
    try {
      final rs = await dbService.getReminderSettings();
      if (mounted) setState(() => _notificationsEnabled = rs['master'] ?? true);
    } catch (e) {
      debugPrint('마스터 알림 설정 로드 실패: $e');
    }

    await _loadMonthlyExpenses();
    await _loadCurrentMonthIncome();
    _calculateTax();
    _refreshReminders();
    _refreshUnreadCount();
    _checkBackfillPrompt();
    _loadHiddenBanners();
  }

  Future<void> _refreshUnreadCount() async {
    final count = await dbService.unreadNotificationCount();
    if (mounted) setState(() => _unreadNotifCount = count);
  }

  /// 알림 켜짐 상태면 시즌·월간 리마인더를 (재)예약. 웹은 미지원.
  Future<void> _refreshReminders() async {
    if (kIsWeb) return;
    if (_notificationsEnabled) {
      await ReminderScheduler.scheduleAll(payDay: _payDay, userType: _userType);
    } else {
      await ReminderScheduler.cancelAll();
    }
  }

  /// 설정 알림 토글 — 영속화(reminder_settings 'master') + 즉시 예약/해제.
  Future<void> _setNotificationsEnabled(bool enabled) async {
    setState(() => _notificationsEnabled = enabled);
    await dbService.setReminderSetting('master', enabled);
    if (kIsWeb) return;
    if (enabled) {
      await notificationHelper.requestPermissions();
      await _requestExactAlarmPermission();
      await ReminderScheduler.scheduleAll(payDay: _payDay, userType: _userType);
    } else {
      await ReminderScheduler.cancelAll();
    }
  }

  /// 정확한 알람 권한 안내 — 시스템 설정으로 이동하기 전에 이유를 먼저 보여준다.
  /// (API 31 미만은 무조건 자동 허용이라 시스템 화면 전환 없이 바로 통과된다.)
  Future<void> _requestExactAlarmPermission() async {
    final android = notificationHelper.flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('정확한 시간에 알림 받기',
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontWeight: FontWeight.bold)),
        content: Text(
          '신고·납부 기한 알림이 정확한 시각에 오도록, 다음 화면에서 "정확한 알람" 권한을 허용해 주세요.'.keepWords,
          style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!)),
          ),
        ],
      ),
    );
    await android.requestExactAlarmsPermission();
  }

  /// 홈 소득 카드가 사용하는 컨트롤러 (직장인/N잡러 → 급여, 프리랜서 → 수입)
  TextEditingController get _activeIncomeController =>
      _isEmployee ? _salaryController : _freelancerIncomeController;

  /// 소득 달력의 이번 달 기록을 홈 카드에 반영 (기록이 source of truth)
  Future<void> _loadCurrentMonthIncome() async {
    final now = DateTime.now();
    // 근로소득(급여) / 기타 수익 분리 — N잡러 수입 카드용 (income_entries = SSOT).
    // 헤드라인 표시값도 유형별로 필터링된 이 합산에서 직접 계산한다(과거엔 유형 구분 없이
    // 전체 합산하는 monthly_income_records 캐시를 썼는데, 다른 유형으로 기록한 값까지
    // 섞여 보이는 문제가 있었다).
    final entries = await dbService.getIncomeEntriesForMonth(now.year, now.month, userType: _userType);
    double labor = 0, other = 0, otherGross = 0;
    for (final e in entries) {
      if (e.incomeType == '급여') {
        labor += e.amount;
      } else {
        other += e.amount;
        // 원천징수 역산 — 사업소득 3.3%(÷0.967), 기타소득 8.8%(÷0.912). 원천징수 안 했으면 그대로.
        final divisor = e.isWithheld ? (e.incomeType == '기타소득' ? 0.912 : 0.967) : 1.0;
        otherGross += e.amount / divisor;
      }
    }
    final total = labor + other;
    if (mounted) {
      setState(() {
        if (total > 0) {
          _activeIncomeController.text = _numberFormat.format(total.toInt());
        }
        _laborIncome = labor;
        _otherIncome = other;
        _otherIncomeGrossEstimate = otherGross;
      });
    }
    if (!kIsWeb && _notificationsEnabled) {
      final prevMonth = now.month == 1 ? DateTime(now.year - 1, 12) : DateTime(now.year, now.month - 1);
      final prevEntries = await dbService.getIncomeEntriesForMonth(prevMonth.year, prevMonth.month, userType: _userType);
      DateTime? lastIncomeDate;
      for (final e in [...entries, ...prevEntries]) {
        final eEnd = e.endDate ?? e.date;
        final d = DateTime(eEnd.year, eEnd.month, eEnd.day);
        if (lastIncomeDate == null || d.isAfter(lastIncomeDate)) lastIncomeDate = d;
      }
      ReminderScheduler.checkIncomeInactivityNudge(lastIncomeDate);
    }
    if (!kIsWeb && _notificationsEnabled && (_userType == '프리랜서' || _userType == 'N잡러')) {
      final estimate = await ReserveEstimator.estimateForCurrentMonth(userType: _userType);
      final allExpenses = await dbService.getExpenses(userType: _userType);
      final reservedThisMonth = allExpenses
          .where((x) => x.category == '보험/금융' && x.date.year == now.year && x.date.month == now.month)
          .fold<double>(0, (s, x) => s + x.amount);
      await ReminderScheduler.checkTaxReserveShortfall(
        recommendedMinReserve: estimate.minMonthlyTaxReserve + estimate.insuranceReserve,
        actualReserved: reservedThisMonth,
      );
    }
    if (!kIsWeb && _notificationsEnabled && _userType == '프리랜서') {
      final profile = await dbService.getProfile();
      final healthEnrolled = profile?['health_enrolled'] == true;
      await ReminderScheduler.checkFreelancerHealthUninsured(healthEnrolled: healthEnrolled);
    }
  }

  /// X로 닫은 배너 카드 목록 로드(만료된 건 자동 제외).
  Future<void> _loadHiddenBanners() async {
    final all = await dbService.getAllBannerHideTimes();
    final now = DateTime.now().millisecondsSinceEpoch;
    final ids = all.entries.where((e) => e.value > now).map((e) => e.key).toSet();
    if (mounted) setState(() => _hiddenBannerIds = ids);
  }

  /// 배너 카드 닫기 — 30일간 다시 안 보임.
  Future<void> _dismissBanner(BannerCardData card) async {
    final until = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
    await dbService.saveBannerHideTime(card.id, until);
    setState(() {
      _hiddenBannerIds = {..._hiddenBannerIds, card.id};
      _bannerIndex = 0;
    });
  }

  /// 연중 가입 사용자 — 1월~지난달 기록이 비어있으면 소급 입력 배너를 보여준다.
  Future<void> _checkBackfillPrompt() async {
    final now = DateTime.now();
    if (now.month <= 1) return;
    final done = await dbService.getAppState('annual_backfill_done_${now.year}');
    final dismissed = await dbService.getAppState('annual_backfill_dismissed_${now.year}');
    if (done == 'true' || dismissed == 'true') return;
    if (mounted) setState(() => _showBackfillPrompt = true);
  }

  Widget _buildBackfillPrompt() {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final changed = await Navigator.push<bool>(
                  context, MaterialPageRoute(builder: (_) => AnnualBackfillScreen(userType: _userType)));
              if (changed == true) {
                await _loadMonthlyExpenses();
                await _loadCurrentMonthIncome();
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('지난 달 기록이 비어있어요', style: AppTheme.sans(14, ink, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('간단히 채우면 올해 판정이 더 정확해져요 →'.keepWords, style: AppTheme.sans(12, accent)),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: () async {
            await dbService.setAppState(
                'annual_backfill_dismissed_${DateTime.now().year}', 'true');
            if (mounted) setState(() => _showBackfillPrompt = false);
          },
          child: Icon(Icons.close_rounded, size: 18, color: sub),
        ),
      ],
    );
  }

  Future<void> _loadMonthlyExpenses() async {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final nextMonth = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final lastOfMonth = nextMonth.subtract(const Duration(days: 1));

    final all = await dbService.getExpenses(userType: _userType);
    final firstOfYear = DateTime(now.year, 1, 1);
    double credit = 0.0;
    double debit = 0.0;
    double creditYtd = 0.0;
    double debitYtd = 0.0;
    DateTime? lastExpenseDate;
    for (final e in all) {
      final eStart = DateTime(e.date.year, e.date.month, e.date.day);
      final eEnd = e.endDate != null
          ? DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day)
          : eStart;
      if (lastExpenseDate == null || eEnd.isAfter(lastExpenseDate)) {
        lastExpenseDate = eEnd;
      }
      // 이번 달과 겹치는 항목 포함
      if (!eEnd.isBefore(firstOfMonth) && !eStart.isAfter(lastOfMonth)) {
        if (e.paymentMethod == '신용카드') {
          credit += e.amount;
        } else {
          debit += e.amount;
        }
      }
      // 카드공제는 연 누적 기준 — 올해 1월~오늘. 신용/체크·현금은 공제율이 달라 분리 집계.
      // ('기타' 결제수단은 현금영수증 없는 지출로 보아 공제 대상에서 제외.)
      if (!eStart.isBefore(firstOfYear) && !eStart.isAfter(now)) {
        if (e.paymentMethod == '신용카드') {
          creditYtd += e.amount;
        } else if (e.paymentMethod == '체크+현금') {
          debitYtd += e.amount;
        }
      }
    }
    if (mounted) {
      setState(() {
        _creditCardTotal = credit;
        _debitCashTotal = debit;
        _creditCardYtdTotal = creditYtd;
        _debitCashYtdTotal = debitYtd;
      });
      _checkCardThreshold();
      _checkBudget();
      if (!kIsWeb && _notificationsEnabled) {
        ReminderScheduler.checkInactivityNudge(lastExpenseDate);
      }
    }
    await _loadRefundProgress();
  }

  /// 홈 수익지출카드의 환급 관련 값 — 유형마다 자라는 기전이 다르다.
  /// - 프리랜서: 필요경비 → 이미 뗀 원천징수 환급 (refundProgress, A/B/C)
  /// - N잡러: 카드공제. 절세액은 종합 과세표준에서 결정되므로 근로소득만 보는
  ///   estimateCreditCardRefund 대신 합산 엔진이 낸 값을 쓴다.
  /// - 직장인: 사업소득이 없어 두 방식의 결과가 같아 estimator를 부르지 않는다.
  Future<void> _loadRefundProgress() async {
    if (_userType != '프리랜서' && _userType != 'N잡러') {
      if (mounted && (_refundProgress != null || _cardSavingCombined != null)) {
        setState(() {
          _refundProgress = null;
          _cardSavingCombined = null;
        });
      }
      return;
    }
    final estimate = await ReserveEstimator.estimateForCurrentMonth(userType: _userType);
    if (!mounted) return;
    setState(() {
      _refundProgress = estimate.refundProgress;
      _cardSavingCombined = estimate.cardDeductionTaxSaving;
    });
  }

  /// 이번 달 지출 합계가 목표액의 80%·100%에 처음 닿으면 각각 1회 지연 알림 예약,
  /// 다시 그 아래로 내려가면 예약된 알림을 취소한다.
  void _checkBudget() {
    if (kIsWeb || !_notificationsEnabled || _expenseTarget <= 0) return;
    final total = _creditCardTotal + _debitCashTotal;
    if (total >= _expenseTarget) {
      if (!_budgetOverNotified) {
        _budgetOverNotified = true;
        ReminderScheduler.scheduleBudgetAlert(over: true);
      }
    } else {
      if (_budgetOverNotified) {
        _budgetOverNotified = false;
        ReminderScheduler.cancelBudgetAlert(over: true);
      }
      if (total >= _expenseTarget * 0.8) {
        if (!_budgetNearNotified) {
          _budgetNearNotified = true;
          ReminderScheduler.scheduleBudgetAlert(over: false);
        }
      } else {
        if (_budgetNearNotified) {
          _budgetNearNotified = false;
          ReminderScheduler.cancelBudgetAlert(over: false);
        }
      }
    }
  }

  /// 카드 사용 누계가 공제 문턱(연봉 25%)의 80%·100%에 처음 닿으면 각각 1회 알림.
  /// 문턱 판정은 신용+체크·현금 합계 기준(조특법 §126의2 최저사용금액) — 신용만 세면
  /// 홈 카운터(엔진 합계 기준)와 다른 진행률을 알리게 된다.
  void _checkCardThreshold() {
    if (kIsWeb || !_notificationsEnabled || !_isEmployee) return;
    // N잡러의 _salaryController는 근로+사업 합계라, 총급여 기준 문턱에 그대로 쓰면
    // 사업소득만큼 문턱이 부풀려진다. 홈 카드와 같은 규칙으로 근로소득만 쓴다.
    final monthlyIncome = _userType == 'N잡러'
        ? _laborIncome
        : (double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0);
    final annualSalary = _grossIncome > 0 ? _grossIncome : monthlyIncome * 12;
    if (annualSalary <= 0) return;
    final threshold = annualSalary * 0.25;
    final totalEligibleYtd = _creditCardYtdTotal + _debitCashYtdTotal;
    if (totalEligibleYtd >= threshold) {
      if (!_thresholdNotified) {
        _thresholdNotified = true;
        ReminderScheduler.showThresholdReached();
      }
    } else {
      _thresholdNotified = false; // 문턱 아래로 내려가면 리셋
      // 80% 임박 — 문턱 넘기 전에 한 번만.
      if (totalEligibleYtd >= threshold * 0.8) {
        if (!_thresholdNearNotified) {
          _thresholdNearNotified = true;
          ReminderScheduler.showThresholdNear();
        }
      } else {
        _thresholdNearNotified = false;
      }
    }
  }

  Future<void> _saveProfileToDB() async {
    final monthlyIncome = double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;
    final monthlyRent = double.tryParse(_monthlyRentController.text.replaceAll(',', '')) ?? 0.0;
    final yellowUmbrella = double.tryParse(_yellowUmbrellaController.text.replaceAll(',', '')) ?? 0.0;
    final expenseTarget = double.tryParse(_savingGoalController.text.replaceAll(',', '')) ?? 0.0;

    // 기존 프로필을 읽어 위저드에서 설정한 공제 항목(혼인·자녀·경로우대 등)을 보존(merge)
    final existing = await dbService.getProfile() ?? <String, dynamic>{};
    final profile = {
      ...existing,
      'user_type': _userType,
      'gross_income': _grossIncome,
      'dependents': _dependentCount,
      'is_monthly_rent': _isMonthlyRent,
      'monthly_rent': monthlyRent,
      'decided_tax': _decidedTax,
      'yellow_umbrella': yellowUmbrella,
      'monthly_income': monthlyIncome,
      'expense_target': expenseTarget,
      'pay_day': _payDay,
      'type_identified': _isTypeIdentified,
    };
    await dbService.saveProfile(profile);
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _savingGoalController.dispose();
    _monthlyRentController.dispose();
    _creditCardInputController.dispose();
    _debitCashInputController.dispose();
    _freelancerIncomeController.dispose();
    _monthsController.dispose();
    _yellowUmbrellaController.dispose();
    _expenseTargetInlineCtrl.dispose();
    _bannerTimer?.cancel();
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _showDestroyConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('데이터 파기 확인', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontWeight: FontWeight.bold)),
          content: Text(
            '모든 프로필 및 지출 데이터가 기기에서 영구적으로 파기됩니다.\n이 작업은 되돌릴 수 없어요. 정말 파기하시겠습니까?'.keepWords,
            style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await dbService.destroyAllData();
                setState(() {
                  _salaryController.clear();
                  _savingGoalController.clear();
                  _creditCardInputController.clear();
                  _debitCashInputController.clear();
                  _creditCardTotal = 0.0;
                  _debitCashTotal = 0.0;
                  _creditCardYtdTotal = 0.0;
                  _debitCashYtdTotal = 0.0;
                  _monthlyRentController.clear();
                  _freelancerIncomeController.clear();
                  _monthsController.text = '12';
                  _yellowUmbrellaController.clear();
                  _isProfileCompleted = false;
                  _isTypeIdentified = false;
                  _userType = '직장인';
                  _decidedTax = 0.0;
                  _grossIncome = 0.0;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('특허 기술을 통해 로컬 세무 정보가 복구 불가능하게 완전 파기되었습니다.'.keepWords),
                      backgroundColor: Color(0xFFFF4D4D),
                    ),
                  );
                }
              },
              child: const Text('파기', style: TextStyle(color: Color(0xFFFF4D4D), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// 유형별(직장인/N잡러/프리랜서) 독립 저장된 예상연봉·지출목표를 불러와 반영.
  Future<void> _loadTypeValues(String userType) async {
    final values = await dbService.getProfileTypeValues(userType);
    if (!mounted) return;
    setState(() {
      _grossIncome = values['gross_income'] ?? 0.0;
      _expenseTarget = values['expense_target'] ?? 0.0;
      _savingGoalController.text =
          _expenseTarget > 0 ? _numberFormat.format(_expenseTarget.toInt()) : '';
    });
  }

  void _setUserType(String type) {
    setState(() {
      _userType = type;
      _bannerIndex = 0;
      _calculateTax();
    });
    _loadTypeValues(type);
    _startBannerRotation();
    _saveProfileToDB();
    _refreshReminders(); // 유형별 시즌 알림 재예약
    _loadCurrentMonthIncome();
    _loadMonthlyExpenses();
  }

  /// 유형 탭 전환 — 가계부는 유형별로 분리되지만 어느 쪽 데이터도 사라지지 않으므로
  /// 즉시 전환한다. 기록 이전이 필요하면 가계부의 '가져오기' 배너로 처리한다(전환 확인 팝업 제거).
  void _switchUserType(String newType) {
    if (newType == _userType) return;
    _setUserType(newType);
  }

  void _calculateTax() {
    // 세전 급여 또는 지출 목표 변경 시 세액 계산 필요 시 추후 확장 가능
  }

  void _onExpenseTargetChanged() {
    setState(() {
      _expenseTarget = double.tryParse(_savingGoalController.text.replaceAll(',', '')) ?? 0.0;
    });
    _saveProfileToDB();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          BenefitScreen(userType: _userType),
          // 상품 탭은 V1에서 숨김(L-5) — 화면 코드는 보존, IndexedStack에서만 제외.
          const CalculatorScreen(),
          AllScreen(
            userType: _userType,
            onProfileChanged: _loadDataFromDB,
            onOpenSettings: _openSettings,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Future<void> _openInbox() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationInboxScreen(onRead: _refreshUnreadCount),
      ),
    );
    _refreshUnreadCount();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          userType: _userType,
          notificationsEnabled: _notificationsEnabled,
          onNotificationsChanged: _setNotificationsEnabled,
          onDestroyData: _showDestroyConfirmDialog,
        ),
      ),
    );
  }

  /// 홈 탭 — 세끌 워드마크 + 알림함 + 대시보드 본문. (설정은 전체 탭으로 일원화)
  Widget _buildHomeTab() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.ink(context), width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text('세끌',
              style: AppTheme.serif(17, AppTheme.ink(context), weight: FontWeight.w400, spacing: -0.5)),
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded, color: AppTheme.inkSecondary(context), size: 22),
                onPressed: _openInbox,
                tooltip: '알림함',
              ),
              if (_unreadNotifCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _buildHomeContent(),
      ),
    );
  }

  /// 만원 단위 표기 ("3,800만원")
  String _toWanWon(double won) {
    final man = (won / 10000).round();
    return '${_numberFormat.format(man)}만원';
  }

  /// 한국 소득세 한계세율 (2024년 기준)
  int _marginalRate(double annualIncome) {
    if (annualIncome <= 12000000) return 6;
    if (annualIncome <= 46000000) return 15;
    if (annualIncome <= 88000000) return 24;
    if (annualIncome <= 150000000) return 35;
    if (annualIncome <= 300000000) return 38;
    if (annualIncome <= 500000000) return 40;
    if (annualIncome <= 1000000000) return 42;
    return 45;
  }


  /// 직장인/N잡러/프리랜서별 세무 도구 카드
  void _go(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  /// 가계부로 이동 후 복귀 — 분석탭에서 바뀌었을 수 있는 유형별 지출 목표를 다시 읽어온다.
  Future<void> _goToLedger() async {
    // 복귀 시 리로드는 didPopNext(RouteObserver)가 처리.
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseCalendarScreen()));
  }

  /// 절세 팁 액션 키 → 화면 이동.
  void _tipNavigate(String key) {
    switch (key) {
      case 'record':
        final record = taxRecordEntryFor(_userType);
        _go(record != null ? record.build(_userType) : TaxSimulatorScreen(userType: _userType));
        break;
      case 'book':
        _goToLedger();
        break;
      case 'simulator':
      default:
        _go(TaxSimulatorScreen(userType: _userType));
    }
  }

  /// 팁 분류 라벨 → 글리프 박스 1글자.
  String _tipGlyph(String label) {
    switch (label) {
      case '2026 혜택':
        return '혜';
      case '꿀팁':
        return '팁';
      case '5월 신고':
        return '5';
      case '장려금':
        return '장';
      case '연말정산':
        return '정';
      case '소득파악':
        return '파';
      case '지급명세서':
        return '명';
      case '부가세':
        return '부';
      case '중간예납':
        return '예';
      default:
        return '세';
    }
  }

  Widget _buildHomeContent() {
    // 각 기능을 표면색 패널로 묶어 경계를 분명히 한다(헤어라인 나열 → 카드 구획).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTypeSelector(),
          const SizedBox(height: 16),
          // 상단 회전 배너(광고/배너/알림 카드).
          AppTheme.panel(context, child: HomeBannerCarousel(
            cards: _bannerCards(),
            activeIndex: _bannerIndex,
            onTickTap: (i) {
              setState(() => _bannerIndex = i);
              _startBannerRotation();
            },
            onDismiss: _dismissBanner,
          )),
          const SizedBox(height: 14),
          // 이달 현황(수입·지출·공제 문턱).
          AppTheme.panel(context, child: HomeStatusSection(
            userType: _userType,
            isEmployee: _isEmployee,
            monthlyIncome: double.tryParse(
                  _activeIncomeController.text.replaceAll(',', ''),
                ) ??
                0.0,
            grossIncome: _grossIncome,
            dependentCount: _dependentCount,
            childrenCount: _childrenCount,
            laborIncome: _laborIncome,
            otherIncome: _otherIncome,
            otherIncomeGrossEstimate: _otherIncomeGrossEstimate,
            expenseTarget: _expenseTarget,
            creditCardTotal: _creditCardTotal,
            debitCashTotal: _debitCashTotal,
            creditCardYtdTotal: _creditCardYtdTotal,
            debitCashYtdTotal: _debitCashYtdTotal,
            refundProgress: _refundProgress,
            cardSavingCombined: _cardSavingCombined,
            onOpenLedger: _goToLedger,
            onOpenMyInfo: _openProfile,
            showExpenseInput: _showExpenseInput,
            expenseTargetInlineCtrl: _expenseTargetInlineCtrl,
            onRequestExpenseInput: () => setState(() => _showExpenseInput = true),
            onApplyExpenseInput: (val) async {
              setState(() {
                _expenseTarget = val;
                _savingGoalController.text = _numberFormat.format(val.toInt());
                _showExpenseInput = false;
              });
              await dbService.setProfileTypeValues(_userType, expenseTarget: val);
              _checkBudget();
            },
            onCancelExpenseInput: () => setState(() => _showExpenseInput = false),
          )),
          const SizedBox(height: 14),
          // 상태 카드에 아직 유도가 떠 있으면 백필 유도는 뒤로 미룬다 —
          // 요청은 한 번에 하나여야 눈에 들어온다(2026-07-25).
          if (_showBackfillPrompt &&
              !((_isEmployee && _grossIncome <= 0) || _expenseTarget <= 0)) ...[
            AppTheme.panel(context, child: _buildBackfillPrompt()),
            const SizedBox(height: 14),
          ],
          // 리마인더(핵심 기능) — 접이식.
          AppTheme.panel(context, child: ReminderCard(userType: _userType)),
          const SizedBox(height: 14),
          // 세무 도구 — 접이식 아코디언(세무 탭과 동일 메뉴 공유).
          AppTheme.panel(context, child: TaxToolsAccordion(userType: _userType)),
          const SizedBox(height: 14),
          // 자주 묻는 질문.
          AppTheme.panel(context, child: _buildFaqCard()),
        ],
      ),
    );
  }

  /// 월 기준 계절 배너 콘텐츠 — 라벨/헤드라인/액션/글리프를 시즌별로 분기.
  ({String label, String headline, String action, String glyph}) _seasonalBanner() {
    final m = DateTime.now().month;
    if (m >= 1 && m <= 3) {
      // 연초: 연말정산 결과·경정청구
      return (
        label: '연말정산 시즌',
        headline: '올해 연말정산,\n돌려받을 게 더 있을까?',
        action: '내 절세 유형 찾기',
        glyph: '결',
      );
    } else if (m == 4 || m == 5) {
      // 종합소득세 신고철
      return (
        label: '종합소득세 신고',
        headline: '5월 종합소득세,\n나도 환급 대상일까?',
        action: '내 절세 유형 찾기',
        glyph: '신',
      );
    } else {
      // 평시: 절세 준비
      return (
        label: '절세 준비',
        headline: '미리 챙기는 공제,\n내년 환급을 바꿔요',
        action: '내 절세 유형 찾기',
        glyph: 'S',
      );
    }
  }

  /// 절세 유형 찾기(페르소나 질문) 진입 — 결과로 유형 변경 시 반영.
  Future<void> _openPersona() async {
    final newUserType = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaxPersonaQuestionScreen(initialUserType: _userType)),
    );
    if (newUserType != null && newUserType is String && newUserType != _userType) {
      _setUserType(newUserType);
    }
  }

  /// 유형 파악 온보딩 진입 — 결과로 user_type + type_identified 저장.
  Future<void> _openOnboarding() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen(returnResult: true)),
    );
    if (result is String && mounted) {
      setState(() {
        _userType = result;
        _isTypeIdentified = true;
        _bannerIndex = 0;
      });
      await _loadTypeValues(result);
      await _saveProfileToDB();
      _startBannerRotation();
    }
  }

  /// 내 정보 진입 — 프로필 발견성 문제로 온보딩·배너·홈 카드 전부 여기로 모은다(2026-07-24).
  /// 변경 시 콜백으로 홈 데이터(연봉 포함) 재동기화.
  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyInfoScreen(
          userType: _userType,
          onProfileChanged: () {
            if (!mounted) return;
            setState(() {
              _isProfileCompleted = true;
              _bannerIndex = 0;
            });
            _loadDataFromDB();
          },
        ),
      ),
    );
  }

  /// 유형별 회전 배너 카드 세트 — 온보딩 단계에 따라 4가지 상태 분기.
  ///
  /// A: 유형 미파악 → [유형 파악 카드] 단 1장
  /// B: 유형 OK + 프로필 미완성 → [프로필 작성] + [유형 소개]
  /// C: 완료 + 소득 미설정 → [연봉 설정 촉구] + 유형별 도구 + 시즌
  /// D: 완료 + 소득 설정됨 → [개인화 데이터 카드] + 유형별 도구 + 시즌
  /// 이달의 절세 팁 → 회전 배너 카드(맨 위 광고/배너 카드에 합침).
  List<BannerCardData> _tipBannerCards() => _currentTips()
      .map((t) => BannerCardData(
            label: t.label,
            headline: t.title,
            action: '',
            glyph: _tipGlyph(t.label),
            sub: t.body,
            onTap: t.action != null ? () => _tipNavigate(t.action!) : () {},
          ))
      .toList();

  List<BannerCardData> _bannerCards() =>
      _rawBannerCards().where((c) => !_hiddenBannerIds.contains(c.id)).toList();

  List<BannerCardData> _rawBannerCards() {
    final s = _seasonalBanner();

    // ── 상태 A: 유형 미파악 (완전 신규) ──
    if (!_isTypeIdentified) {
      return [
        BannerCardData(
          label: '시작',
          headline: '내가 어떤 납세자인지\n먼저 확인해봐요',
          action: '유형 파악하기',
          glyph: '유',
          onTap: _openOnboarding,
        ),
        ..._tipBannerCards(),
      ];
    }

    // ── 상태 B: 유형 파악 완료, 프로필 미완성 ──
    if (!_isProfileCompleted) {
      final typeIntro = _userType == '직장인'
          ? '연말정산에서\n놓친 공제가 있을 수 있어요'
          : _userType == 'N잡러'
              ? '합산 소득세율이\n예상보다 높을 수 있어요'
              : '3.3% 원천징수 후에도\n5월 신고가 따로 필요해요';
      final typeGlyph = _userType == '직장인' ? '결' : _userType == 'N잡러' ? '합' : '신';
      return [
        BannerCardData(
          label: '내 정보',
          headline: '$_userType 절세 기준을\n잡으려면 내 정보가 필요해요',
          action: '내 정보 설정',
          glyph: '1',
          onTap: _openProfile,
        ),
        BannerCardData(
          label: _userType,
          headline: typeIntro,
          action: '자세히 보기',
          glyph: typeGlyph,
          onTap: () => _go(TaxSimulatorScreen(userType: _userType)),
        ),
        ..._tipBannerCards(),
      ];
    }

    final cards = <BannerCardData>[];

    // ── 상태 C: 완료 + 소득 미설정 — 직장인·N잡러만(프리랜서는 고정급여 개념이 없음) ──
    if (_isEmployee && _grossIncome == 0) {
      cards.add(BannerCardData(
        label: '다음 단계',
        headline: '예상 연봉을 입력하면\n공제 기준이 잡혀요',
        action: '연봉 설정하기',
        glyph: '₩',
        onTap: _openProfile,
      ));
    } else if (_grossIncome > 0) {
      // ── 상태 D: 완료 + 소득 설정됨 — 개인화 카드 ──
      if (_userType == '직장인') {
        final remaining = _grossIncome * 0.25 - _creditCardYtdTotal;
        cards.add(remaining > 0
            ? BannerCardData(
                label: '신카 공제',
                headline: '공제 문턱까지\n${_toWanWon(remaining)} 남았어요',
                action: '신용카드 공제 확인',
                glyph: '카',
                onTap: () => _go(YearEndTaxScreen(userType: _userType)),
              )
            : BannerCardData(
                label: '신카 공제',
                headline: '공제 문턱 돌파!\n체크카드로 2배 공제예요',
                action: '연말정산 진단',
                glyph: '↑',
                onTap: () => _go(YearEndTaxScreen(userType: _userType)),
              ));
      } else if (_userType == 'N잡러') {
        final rate = _marginalRate(_grossIncome);
        cards.add(BannerCardData(
          label: 'N잡 세율',
          headline: '직장 소득 기준\n한계세율 $rate% 구간이에요',
          action: '합산소득세 확인',
          glyph: '율',
          onTap: () => _go(TaxSimulatorScreen(userType: _userType)),
        ));
        final remaining = _grossIncome * 0.25 - _creditCardYtdTotal;
        cards.add(remaining > 0
            ? BannerCardData(
                label: '신카 공제',
                headline: '공제 문턱까지\n${_toWanWon(remaining)} 남았어요',
                action: '신용카드 공제 확인',
                glyph: '카',
                onTap: () => _go(YearEndTaxScreen(userType: _userType)),
              )
            : BannerCardData(
                label: '신카 공제',
                headline: '공제 문턱 돌파!\n체크카드로 2배 공제예요',
                action: '연말정산 진단',
                glyph: '↑',
                onTap: () => _go(YearEndTaxScreen(userType: _userType)),
              ));
      } else {
        cards.add(BannerCardData(
          label: '5월 신고',
          headline: '연 ${_toWanWon(_grossIncome)} 기준\n종합소득세 신고 대상이에요',
          action: '종합소득세 계산',
          glyph: '신',
          onTap: () => _go(TaxSimulatorScreen(userType: _userType)),
        ));
      }
    }

    // 유형별 도구 카드
    if (_userType == '직장인') {
      cards.addAll([
        BannerCardData(label: '환급', headline: '회사가 놓친 공제,\n5월 경정청구로 돌려받아요', action: '환급액 계산하기', glyph: '환', onTap: () => _go(TaxSimulatorScreen(userType: _userType))),
      ]);
    } else if (_userType == 'N잡러') {
      cards.addAll([
        BannerCardData(label: '건강보험', headline: '부업 소득금액 2,000만 넘으면\n건보료가 따라와요', action: '가계부에서 확인', glyph: '보', onTap: _goToLedger),
      ]);
    } else {
      cards.addAll([
        BannerCardData(label: '경비율', headline: '장부를 쓰면 경비\n인정 폭이 넓어져요', action: '가계부 열기', glyph: '장', onTap: _goToLedger),
      ]);
      // ①진단에 저장된 직전연도 수입·신규 여부로 판정 가능할 때만 — 단순경비율
      // 대상에서 벗어났으면(기준경비율 강제) 장부 작성 동기를 구체적으로 짚어준다.
      final occ = OccupationData.occupations[_occupationCode];
      if (occ != null && (_isNewBusiness || _priorYearIncome > 0)) {
        final eligible = isSimpleExpenseRateEligible(
          occupation: occ,
          priorYearIncome: _priorYearIncome,
          isNewBusiness: _isNewBusiness,
        );
        if (!eligible) {
          cards.add(BannerCardData(
            label: '경비율 변경',
            headline: '올해부터 기준경비율\n대상이 됐어요',
            action: '가계부로 경비 인정받기',
            glyph: '기',
            onTap: _goToLedger,
          ));
        }
      }
    }

    // 연말정산 시즌(1~2월, 회사 처리 전)에만 — 회사에 알리고 싶지 않은 공제를
    // 미리 골라 5월 종소세로 직접 신고할 수 있다는 안내.
    if (_isEmployee && DateTime.now().month <= 2) {
      cards.add(BannerCardData(
        label: '연말정산',
        headline: '연말정산에서\n뺄 항목이 있나요?',
        action: '빠진 공제 찾기',
        glyph: '뺌',
        onTap: () => _go(MissedDeductionDiagnosisScreen(userType: _userType)),
      ));
    }

    cards.add(BannerCardData(
      label: s.label, headline: s.headline, action: s.action, glyph: s.glyph, onTap: _openPersona,
    ));

    // 이달의 절세 팁을 상단 회전 배너에 합친다(별도 카드 제거).
    cards.addAll(_tipBannerCards());
    return cards;
  }

  /// 유형 선택 — 텍스트 탭(선택 시 굵게 + 하단 라인) + 프로필 링크
  Widget _buildTypeSelector() {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ...['직장인', 'N잡러', '프리랜서'].map((type) {
          final selected = _userType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Semantics(
              button: true,
              selected: selected,
              label: '$type 유형',
              child: GestureDetector(
                onTap: () => _switchUserType(type),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(type, style: AppTheme.sans(15, selected ? ink : tert, weight: selected ? FontWeight.w700 : FontWeight.w500, spacing: -0.2)),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 2,
                      width: selected ? 20 : 0,
                      color: ink,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const Spacer(),
        Semantics(
          button: true,
          label: _isProfileCompleted ? '내 정보 수정' : '내 정보 설정',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openProfile,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isProfileCompleted ? Icons.check_circle_outline : Icons.add, size: 15, color: accent),
              const SizedBox(width: 5),
              Text(_isProfileCompleted ? '내 정보 수정' : '내 정보 설정', style: AppTheme.sans(13, accent, weight: FontWeight.w600)),
            ]),
          ),
        ),
      ],
    );
  }

  /// FAQ 카드 (최하단) — 유형별 풀에서 5개씩 보여주고, '다른 질문 보기'로 다음 5개를 뽑는다.
  Widget _buildFaqCard() {
    _ensureFaqPool();
    final pool = _faqShuffled;
    final shown = <Map<String, String>>[
      for (int i = 0; i < 5 && i < pool.length; i++)
        pool[(_faqOffset + i) % pool.length],
    ];

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        iconColor: AppTheme.inkTertiary(context),
        collapsedIconColor: AppTheme.inkTertiary(context),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 16),
        title: Text('자주 묻는 질문', style: AppTheme.sans(13, AppTheme.ink(context), weight: FontWeight.w700, spacing: -0.2)),
        children: [
          ...shown.map((faq) => _buildFaqItem(faq['q']!, faq['a']!)),
          if (pool.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => setState(() => _faqOffset = (_faqOffset + 5) % pool.length),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 15, color: AppTheme.inkSecondary(context)),
                      const SizedBox(width: 6),
                      Text('다른 질문 보기', style: AppTheme.sans(12, AppTheme.inkSecondary(context), weight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 현재 유형의 FAQ 풀을 (없거나 유형이 바뀐 경우) 한 번 섞어둔다.
  /// build 중 호출되는 지연 초기화 — 유형이 실제로 바뀔 때만 재섞기해서 매 프레임 셔플을 막는다.
  void _ensureFaqPool() {
    if (_faqPoolType == _userType && _faqShuffled.isNotEmpty) return;
    _faqShuffled = List<Map<String, String>>.from(_faqPoolFor(_userType))..shuffle();
    _faqOffset = 0;
    _faqPoolType = _userType;
  }

  /// 유형별 FAQ 전체 풀. 기초 질문 + 실전에서 자주 묻는 질문을 함께 담는다.
  List<Map<String, String>> _faqPoolFor(String userType) {
    if (userType == '직장인') {
      return [
        {'q': '연말정산에서 놓친 공제, 5월에 다시 받을 수 있나요?', 'a': '네, 가능합니다. 5월 종합소득세 신고(경정청구)를 통해 연말정산에서 누락된 공제를 추가로 신청할 수 있습니다. 최대 5년 이내의 공제까지 소급 신청 가능합니다.'},
        {'q': '회사에 알리기 싫은 의료비, 따로 공제받는 방법은?', 'a': '연말정산 때 해당 항목을 빼고, 5월에 개인적으로 종합소득세 신고를 하면 됩니다. 홈택스에서 직접 신고하면 회사에는 해당 내역이 전달되지 않습니다.'},
        {'q': '언제부터 체크카드를 써야 유리한가요?', 'a': '총급여의 25%를 신용카드로 채운 뒤, 그 이후부터는 체크카드·현금을 사용하는 것이 유리합니다. 체크카드는 공제율이 30%로 신용카드(15%)의 두 배입니다.'},
        {'q': '중도 퇴사자 연말정산은 어떻게 하나요?', 'a': '퇴사 시 회사에서 기본 연말정산을 해줍니다. 이후 다른 회사에 입사하면 전 직장 원천징수영수증을 제출하고, 미취업 상태라면 다음 해 5월에 직접 종합소득세를 신고합니다.'},
        {'q': '부양가족 공제, 형제자매도 가능한가요?', 'a': '가능합니다. 만 20세 이하 또는 만 60세 이상의 형제자매가 연 소득 100만원 이하이고 다른 가족이 공제받지 않는 경우, 기본공제 대상에 포함됩니다.'},
        {'q': '월세도 세액공제 받을 수 있나요?', 'a': '무주택 세대주(총급여 8,000만원 이하)라면 연 1,000만원 한도로 월세액의 15~17%를 세액공제받습니다. 총급여 5,500만원 이하는 17%, 초과는 15%이며, 2026년부터 무주택 주말부부 배우자·다자녀 세대의 주택까지 대상이 넓어졌습니다.'},
        {'q': '연금저축·IRP로 세금을 얼마나 아낄 수 있나요?', 'a': '연금저축 연 600만원, IRP 합산 최대 900만원까지 납입액의 12~15%를 세액공제받습니다. 총급여 5,500만원 이하는 15%라, 900만원을 채우면 최대 135만원을 돌려받습니다.'},
        {'q': '맞벌이 부부, 부양가족은 누구 앞으로 올려야 하나요?', 'a': '보통 소득이 높은 배우자 앞으로 공제하는 것이 유리합니다. 세율이 높을수록 같은 공제로 더 많은 세금을 줄이기 때문입니다. 다만 의료비는 총급여가 적은 쪽이 3% 문턱을 넘기 쉬워 그쪽이 유리할 수 있습니다.'},
        {'q': '산후조리원비·난임시술비도 공제되나요?', 'a': '산후조리원비는 출산 1회당 200만원 한도로 의료비 공제 대상입니다. 난임시술비는 공제율이 30%로 일반 의료비(15%)보다 높게 적용됩니다.'},
        {'q': '안경·콘택트렌즈 구입비도 의료비 공제가 되나요?', 'a': '시력교정용 안경·콘택트렌즈는 부양가족 1인당 연 50만원 한도로 의료비 공제 대상입니다. 미용·도수 없는 제품은 제외됩니다.'},
        {'q': "'13월의 월급'이라는데 왜 저는 오히려 세금을 토해내나요?", 'a': '매달 급여에서는 간이세액표로 세금을 어림잡아 떼고, 연말정산 때 실제 세금과 정산합니다. 부양가족이 적거나 공제가 적으면 그동안 덜 떼인 만큼 추가로 내게 됩니다. 회사에 매달 떼는 비율(80·100·120%)을 조정 신청할 수도 있습니다.'},
        {'q': '성과급·상여금을 받으면 세금 폭탄인가요?', 'a': '상여금도 근로소득이라 연봉에 합산돼 누진세율이 적용됩니다. 받는 달엔 원천징수가 크게 잡혀 보이지만, 최종적으로 연말정산에서 정산됩니다. 소득이 늘어 세율 구간이 올라간 것이지 별도의 벌금성 세금은 아닙니다.'},
        {'q': '따로 사시는 부모님도 부양가족 공제가 되나요?', 'a': '만 60세 이상 부모의 연 소득금액이 100만원(근로소득만 있으면 총급여 500만원) 이하이고 실제로 부양(생활비 지원 등)한다면, 함께 살지 않아도 기본공제가 가능합니다. 형제자매 중 한 명만 공제받을 수 있습니다.'},
        {'q': '주택청약저축도 공제받을 수 있나요?', 'a': '무주택 세대주이고 총급여 7,000만원 이하이면, 주택청약종합저축 납입액(연 300만원 한도)의 40%를 근로소득금액에서 소득공제받습니다. 가입 은행에 무주택확인서를 제출해야 적용됩니다.'},
        {'q': '전세자금대출·주택담보대출 이자도 공제되나요?', 'a': '무주택 세대주의 전세(주택임차)자금 대출은 원리금 상환액의 40%를 주택마련저축과 합산해 연 400만원 한도로 소득공제합니다. 장기주택저당차입금(주택담보대출) 이자는 요건 충족 시 별도로 소득공제 대상입니다.'},
        {'q': '실손보험으로 돌려받은 의료비도 공제되나요?', 'a': '아니요. 보험사에서 보전받은 금액은 본인이 실제 부담한 의료비가 아니므로 의료비 공제에서 빼야 합니다. 이를 빼지 않고 공제받으면 나중에 추징될 수 있습니다.'},
        {'q': '연봉이 오르면 실수령액은 얼마나 늘어나요?', 'a': '오른 금액 전부가 통장에 들어오지는 않습니다. 인상분에 대해 소득세·건강보험·국민연금이 함께 늘어, 대략 인상분의 70~85%가 실수령 증가분이 됩니다. 계산기 탭에서 세후 실수령액을 확인할 수 있습니다.'},
      ];
    } else if (userType == '프리랜서') {
      return [
        {'q': '3.3% 떼고 받았는데 5월에 세금을 또 내야 하나요?', 'a': '3.3%는 원천징수(미리 떼는 세금)일 뿐, 실제 세금과 다를 수 있습니다. 5월 종소세 신고 시 실제 세액을 계산하여, 더 냈으면 환급받고 덜 냈으면 추가 납부합니다.'},
        {'q': '단순경비율과 기준경비율, 어떤 게 유리한가요?', 'a': '일반적으로 수입이 적으면 단순경비율이, 수입이 많으면 간편장부가 유리합니다. 기준경비율은 주요경비를 증빙해야 하므로, 증빙 서류가 부족하면 불리할 수 있습니다.'},
        {'q': '식대, 교통비도 경비로 인정받을 수 있나요?', 'a': '업무와 직접 관련된 식대·교통비는 경비로 인정됩니다. 다만 간편장부나 복식부기로 신고하는 경우에만 개별 경비로 반영 가능하며, 추계신고(경비율) 시에는 이미 경비율에 포함되어 있습니다.'},
        {'q': '종소세 신고를 안 하면 가산세가 얼마나 붙나요?', 'a': '무신고 가산세 20%, 납부지연 가산세 연 8.03%가 부과됩니다. 부정 무신고의 경우 40%까지 올라갑니다. 환급 대상인데도 신고하지 않으면 환급을 받지 못합니다.'},
        {'q': '프리랜서도 부가세 신고를 해야 하나요?', 'a': '인적용역(프리랜서)은 부가가치세 면세 대상입니다. 별도의 부가세 신고가 필요 없습니다. 단, 사업자등록을 내고 물건을 판매하는 경우에는 부가세 신고가 필요합니다.'},
        {'q': '장부는 꼭 써야 하나요?', 'a': '직전 연도 수입금액이 업종 기준(인적용역·자유직업은 7,500만원) 이상이면 복식부기 의무자입니다. 미만이면 간편장부 대상이며 장부 없이 경비율로 추계신고도 가능합니다. 다만 복식부기 의무자가 장부 없이 신고하면 무기장 가산세 20%가 붙습니다.'},
        {'q': '노란우산공제로 절세가 되나요?', 'a': '소기업·소상공인 공제부금(노란우산)은 2026년부터 연 최대 1,800만원까지 소득공제됩니다. 폐업·노후 대비 목돈을 모으면서 종합소득세도 줄일 수 있어 프리랜서에게 유리합니다.'},
        {'q': '11월에 온 중간예납 고지서는 뭔가요?', 'a': '전년도 종합소득세의 절반을 11월에 미리 내는 제도입니다. 5월 신고 때 기납부세액으로 차감되므로 이중과세가 아닙니다. 올해 소득이 크게 줄었다면 중간예납 추계액 신고로 금액을 줄일 수 있습니다.'},
        {'q': '경비로 인정받으려면 어떤 증빙이 필요한가요?', 'a': '세금계산서·계산서·현금영수증·사업용 신용카드 매출전표가 적격 증빙입니다. 건당 3만원을 넘는 지출은 적격 증빙이 없으면 경비 인정이 어렵거나 증빙불비 가산세(2%)가 부과될 수 있습니다.'},
        {'q': '건강보험료는 어떻게 정해지나요?', 'a': '직장에 다니지 않는 프리랜서는 지역가입자로, 종합소득세 신고 소득과 재산을 기준으로 보험료가 산정돼 매월 개인이 전액 부담합니다. 올해 신고 소득이 내년 보험료에 반영되므로, 경비를 잘 챙겨 소득금액을 정확히 신고하는 것이 중요합니다.'},
        {'q': '소득이 불규칙한데 세금은 얼마나 미리 모아둬야 하나요?', 'a': '수입의 대략 10~20%를 세금·건강보험용으로 따로 떼어두길 권합니다(소득 구간·경비율에 따라 다릅니다). 세끌 가계부의 "세금으로 모아둘 돈·보험료로 대비할 돈"이 이 추정을 자동으로 계산해 줍니다.'},
        {'q': '집에서 일하는데 월세·전기·인터넷도 경비가 되나요?', 'a': '업무에 쓰는 비율만큼 안분해 경비로 처리할 수 있습니다(예: 집 면적 중 작업공간 비율). 사적으로 쓰는 부분은 빼야 하고, 면적·사용비율 같은 근거를 남겨두는 것이 안전합니다.'},
        {'q': '노트북·카메라 같은 장비를 산 것도 경비인가요?', 'a': '업무용 장비는 경비로 인정됩니다. 다만 고가 자산(보통 100만원 초과)은 한 번에 비용 처리하지 않고 감가상각으로 여러 해에 나눠 반영하는 것이 원칙입니다(간편장부·복식부기 신고 시).'},
        {'q': '세무사에게 맡겨야 하나요, 직접 해도 되나요?', 'a': '수입이 적고 경비가 단순하면 홈택스에서 직접(모두채움·경비율) 신고해도 충분합니다. 복식부기 의무자이거나 경비·자산이 복잡하면 기장·신고 대행이 절세와 가산세 예방에 유리합니다.'},
        {'q': '외주비·인건비를 준 것도 경비가 되나요?', 'a': '네, 업무를 위해 지급한 외주비·인건비는 경비입니다. 다만 지급할 때 소득세를 원천징수(사업소득 3.3%, 기타소득 8.8% 등)하고 신고할 의무가 생기므로, 증빙과 원천세 신고를 함께 챙겨야 합니다.'},
        {'q': '소득이 없거나 적자인 달도 신고해야 하나요?', 'a': '종합소득세는 "달"이 아니라 "연 단위"로 5월에 한 번 신고합니다. 소득이 적어 낼 세금이 없더라도 3.3%를 뗀 것이 있으면 신고해야 환급받을 수 있습니다.'},
      ];
    } else {
      return [
        {'q': '부업 수입이 생기면 회사에 자동으로 통보되나요?', 'a': '소득 자체가 통보되지는 않지만, 부업 소득으로 건강보험료가 오르면 회사에 간접적으로 알려질 수 있습니다. 종소세 신고 시 건보료 납부 방법을 "개인별 고지"로 선택하면 이를 방지할 수 있습니다.'},
        {'q': '직장 연말정산 끝냈는데 5월 종소세도 해야 하나요?', 'a': '네, 반드시 해야 합니다. 직장 외 소득(부업 등)이 있으면 모든 소득을 합산하여 5월에 종합소득세를 신고해야 합니다. 이때 연말정산에서 이미 낸 세금은 기납부세액으로 차감됩니다.'},
        {'q': '신용카드 공제와 부업 경비를 중복 처리할 수 있나요?', 'a': '불가능합니다. 하나의 지출은 근로소득 카드공제 또는 사업소득 필요경비 중 하나로만 적용해야 합니다. 업무용 지출은 경비로, 개인 소비는 카드공제로 분리하는 것이 유리합니다.'},
        {'q': '부업 수입 얼마부터 건보료가 오르나요?', 'a': '직장가입자의 경우, 근로 외 소득(이자·배당·사업·기타소득 합산)이 연 2,000만원을 초과하면 초과분에 대해 건강보험료가 추가 부과됩니다.'},
        {'q': '사업자등록 없이 프리랜서 소득 신고가 되나요?', 'a': '가능합니다. 사업자등록 없이도 종합소득세 신고 시 사업소득(프리랜서 소득)으로 신고할 수 있습니다. 다만 연 매출이 일정 규모 이상이면 사업자등록 의무가 생길 수 있습니다.'},
        {'q': '내 부업은 사업소득인가요, 기타소득인가요?', 'a': '계속·반복적으로 하는 일(배달·대리·프리랜서 용역)은 사업소득, 일시적·우발적 수입(일회성 원고료·강연료 등)은 기타소득입니다. 사업소득은 금액과 무관하게 신고 대상이고, 기타소득은 필요경비를 뺀 소득금액이 연 300만원을 넘을 때 합산 대상이 됩니다.'},
        {'q': '블로그·유튜브 수익은 얼마부터 신고하나요?', 'a': '기타소득으로 보면 필요경비(보통 60%)를 뺀 소득금액이 연 300만원을 넘을 때 종합과세로 합산 신고합니다. 300만원 이하이면 분리과세를 선택할 수 있고, 계속·반복적 활동이면 사업소득으로 금액과 무관하게 신고해야 합니다.'},
        {'q': '부업에서 뗀 3.3%는 5월에 어떻게 되나요?', 'a': '이미 낸 기납부세액으로 인정되어 5월 합산 신고 때 계산된 세금에서 차감됩니다. 근로소득과 합쳐 세율 구간이 올라가면 추가 납부가, 공제·경비가 많으면 환급이 생길 수 있습니다.'},
        {'q': '회사를 두 곳 다녀요. 연말정산은 어떻게 하나요?', 'a': '주된 근무지 한 곳에 다른 회사 근로소득 원천징수영수증을 제출해 합산 연말정산하는 것이 원칙입니다. 합치지 못했다면 5월에 두 근로소득을 합산해 종합소득세로 직접 신고하면 됩니다.'},
        {'q': '부업 건보료가 회사에 알려지는 걸 막으려면?', 'a': '종합소득세 신고 때 근로 외 소득분 건강보험료를 "개인별 납부(직접고지)"로 선택하면, 회사 급여에서 공제되지 않고 개인에게 따로 고지돼 부업 사실이 회사에 드러나지 않습니다.'},
        {'q': '회사 몰래 부업해도 괜찮나요?', 'a': '세법상 부업·겸업 자체는 문제가 없습니다. 다만 회사 취업규칙이나 근로계약에 겸업금지 조항이 있으면 회사와의 관계에서 불이익이 생길 수 있으니, 세금 신고와 별개로 회사 규정을 확인해야 합니다.'},
        {'q': '부업 소득은 얼마까지 신고 안 해도 되나요?', 'a': '사업소득은 금액과 무관하게 신고 대상입니다. 기타소득은 필요경비를 뺀 소득금액이 연 300만원 이하이면 분리과세로 끝낼 수 있습니다. 다만 원천징수된 세금을 돌려받으려면 신고하는 편이 유리할 수 있습니다.'},
        {'q': '본업에 부업까지 합치면 세율이 얼마나 오르나요?', 'a': '종합소득은 모든 소득을 합산해 누진세율(6~45%)을 적용합니다. 부업 소득이 더해져 과세표준 구간이 올라가면 그 초과분에 높은 세율이 붙습니다. 전체가 아니라 "구간을 넘어간 부분"에만 높은 세율이 적용됩니다.'},
        {'q': '배달·쿠팡·대리운전 같은 플랫폼 소득도 신고해야 하나요?', 'a': '네. 플랫폼 노동 소득도 사업소득으로 신고 대상입니다. 대부분 3.3%가 원천징수되며 5월에 합산 신고로 정산합니다. 유류비·통신비·수수료 같은 업무 경비를 챙기면 세금을 줄일 수 있습니다.'},
        {'q': '부업에서 적자가 나면 본업 세금을 줄일 수 있나요?', 'a': '사업소득에서 결손(적자)이 나면 같은 해 다른 종합소득(근로소득 등)과 통산해 과세표준을 낮출 수 있습니다. 다만 장부(간편장부·복식부기)로 실제 결손을 입증해야 하며, 경비율 추계신고로는 결손이 인정되지 않습니다.'},
        {'q': '부업용 지출은 카드공제와 경비 중 뭐가 유리한가요?', 'a': '세율이 높을수록 "필요경비"가 유리한 경우가 많습니다. 경비는 소득금액을 직접 줄이고, 신용카드 소득공제는 문턱·한도가 있어 효과가 제한적입니다. 업무 지출은 경비로 분리하는 것이 대체로 유리합니다.'},
      ];
    }
  }

  Widget _buildFaqItem(String question, String answer) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 14),
        iconColor: AppTheme.inkTertiary(context),
        collapsedIconColor: AppTheme.inkTertiary(context),
        title: Text('Q. $question', style: AppTheme.sans(12, AppTheme.ink(context), weight: FontWeight.w600, height: 1.4)),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: AppTheme.accentColor(context), width: 2)),
            ),
            child: Text(answer, style: AppTheme.sans(12, AppTheme.inkSecondary(context), height: 1.55)),
          ),
        ],
      ),
    );
  }

  /// 하단 탭 전환 — IndexedStack 인덱스만 바꾼다.
  /// 홈으로 돌아올 땐 다른 탭(내정보·가계부)에서 바뀐 값을 다시 읽는다.
  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) _loadDataFromDB();
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.line(context), width: 1)),
      ),
      child: BottomNavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        selectedItemColor: AppTheme.ink(context),
        unselectedItemColor: AppTheme.inkTertiary(context),
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.square_outlined, size: 20), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined, size: 20), label: '혜택'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate_outlined, size: 20), label: '계산기'),
          BottomNavigationBarItem(icon: Icon(Icons.apps_rounded, size: 20), label: '전체'),
        ],
      ),
    );
  }
}
