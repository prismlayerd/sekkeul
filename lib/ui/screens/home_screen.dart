import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../components/reminder_card.dart';
import 'onboarding_screen.dart';
import 'profile_input_screen.dart';
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

  // 신용카드/체크+현금 입력용 (더하기 버튼 전 임시값)
  final TextEditingController _creditCardInputController = TextEditingController();
  final TextEditingController _debitCashInputController = TextEditingController();
  

  final TextEditingController _freelancerIncomeController = TextEditingController();
  final TextEditingController _monthsController = TextEditingController(text: '12');
  final TextEditingController _yellowUmbrellaController = TextEditingController();

  // 절세 프로필 상태 변수
  int _dependentCount = 1;
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

  // 홈 인라인 연봉 입력
  bool _showSalaryInput = false;
  final TextEditingController _grossIncomeInlineCtrl = TextEditingController();

  // 홈 인라인 지출 목표 입력
  bool _showExpenseInput = false;
  final TextEditingController _expenseTargetInlineCtrl = TextEditingController();

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
          
          _dependentCount = profile['dependents'] as int? ?? 1;
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
      await ReminderScheduler.scheduleAll(payDay: _payDay, userType: _userType);
    } else {
      await ReminderScheduler.cancelAll();
    }
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
                Text('간단히 채우면 올해 판정이 더 정확해져요 →', style: AppTheme.sans(12, accent)),
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
      // 신카 공제 문턱은 연 누적 기준 — 올해 1월~오늘까지 신용카드 사용액만 합산.
      if (e.paymentMethod == '신용카드' && !eStart.isBefore(firstOfYear) && !eStart.isAfter(now)) {
        creditYtd += e.amount;
      }
    }
    if (mounted) {
      setState(() {
        _creditCardTotal = credit;
        _debitCashTotal = debit;
        _creditCardYtdTotal = creditYtd;
      });
      _checkCardThreshold();
      _checkBudget();
      if (!kIsWeb && _notificationsEnabled) {
        ReminderScheduler.checkInactivityNudge(lastExpenseDate);
      }
    }
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

  /// 신용카드 누계가 공제 문턱(연봉 25%)의 80%·100%에 처음 닿으면 각각 1회 알림.
  void _checkCardThreshold() {
    if (kIsWeb || !_notificationsEnabled || !_isEmployee) return;
    final monthlyIncome = double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;
    final annualSalary = _grossIncome > 0 ? _grossIncome : monthlyIncome * 12;
    if (annualSalary <= 0) return;
    final threshold = annualSalary * 0.25;
    if (_creditCardYtdTotal >= threshold) {
      if (!_thresholdNotified) {
        _thresholdNotified = true;
        ReminderScheduler.showThresholdReached();
      }
    } else {
      _thresholdNotified = false; // 문턱 아래로 내려가면 리셋
      // 80% 임박 — 문턱 넘기 전에 한 번만.
      if (_creditCardYtdTotal >= threshold * 0.8) {
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
    _grossIncomeInlineCtrl.dispose();
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
            '모든 프로필 및 지출 데이터가 기기에서 영구적으로 파기됩니다.\n이 작업은 되돌릴 수 없어요. 정말 파기하시겠습니까?',
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
                    const SnackBar(
                      content: Text('특허 기술을 통해 로컬 세무 정보가 복구 불가능하게 완전 파기되었습니다.'),
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
      _grossIncomeInlineCtrl.text =
          _grossIncome > 0 ? _numberFormat.format(_grossIncome.toInt()) : '';
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

  /// 유형 탭 전환 확인 — 가계부는 유형별로 분리되므로(과거 공통 기록은 계속 보임),
  /// 전환 전에 "지금부터 기록이 어떻게 나뉘는지" 인지시키고 확인받는다.
  Future<void> _confirmAndSwitchUserType(String newType) async {
    if (newType == _userType) return;
    final hasOwnHistory = await dbService.hasOwnLedgerHistory(newType);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('$_userType에서 $newType(으)로 전환할까요?',
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontWeight: FontWeight.bold)),
          content: Text(
            hasOwnHistory
                ? '이전에 $newType(으)로 기록했던 가계부가 있어요. 이어서 보여드릴게요.'
                : '지금부터 가계부에 적는 내용은 $newType 전용으로 따로 쌓여요. 지금까지 기록한 내용은 공통으로 계속 보여요.',
            style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('취소', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('전환', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) _setUserType(newType);
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

  /// 홈 탭 — 세끌 워드마크 + 설정 톱니 + 대시보드 본문.
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
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppTheme.inkSecondary(context), size: 22),
            onPressed: _openSettings,
            tooltip: '설정',
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
            laborIncome: _laborIncome,
            otherIncome: _otherIncome,
            otherIncomeGrossEstimate: _otherIncomeGrossEstimate,
            expenseTarget: _expenseTarget,
            creditCardTotal: _creditCardTotal,
            debitCashTotal: _debitCashTotal,
            creditCardYtdTotal: _creditCardYtdTotal,
            onOpenLedger: _goToLedger,
            showSalaryInput: _showSalaryInput,
            grossIncomeInlineCtrl: _grossIncomeInlineCtrl,
            onRequestSalaryInput: () => setState(() => _showSalaryInput = true),
            onApplySalaryInput: (val) async {
              setState(() {
                _grossIncome = val;
                _showSalaryInput = false;
              });
              await dbService.setProfileTypeValues(_userType, grossIncome: val);
              _calculateTax();
            },
            onCancelSalaryInput: () => setState(() => _showSalaryInput = false),
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
          if (_showBackfillPrompt) ...[
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

  /// 프로필 작성 진입 — 완료 시 홈 데이터 재동기화.
  Future<void> _openProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileInputScreen(userType: _userType)),
    );
    if (result == true && mounted) {
      setState(() {
        _isProfileCompleted = true;
        _bannerIndex = 0;
      });
      _loadDataFromDB();
    }
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
          label: '프로필',
          headline: '$_userType 절세 기준을\n잡으려면 프로필이 필요해요',
          action: '기초 프로필 작성',
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
        onTap: () => setState(() => _showSalaryInput = true),
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
        BannerCardData(label: '환급', headline: '회사가 놓친 공제,\n5월 신고나 경정청구로 돌려받아요', action: '환급액 계산하기', glyph: '환', onTap: () => _go(TaxSimulatorScreen(userType: _userType))),
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
                onTap: () => _confirmAndSwitchUserType(type),
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
          label: _isProfileCompleted ? '프로필 수정' : '프로필 작성',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileInputScreen(userType: _userType)));
              if (result == true) {
                setState(() => _isProfileCompleted = true);
                _loadDataFromDB();
              }
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isProfileCompleted ? Icons.check_circle_outline : Icons.add, size: 15, color: accent),
              const SizedBox(width: 5),
              Text(_isProfileCompleted ? '프로필 수정' : '프로필 작성', style: AppTheme.sans(13, accent, weight: FontWeight.w600)),
            ]),
          ),
        ),
      ],
    );
  }

  /// FAQ 카드 (최하단)
  Widget _buildFaqCard() {
    final List<Map<String, String>> faqs;

    if (_userType == '직장인') {
      faqs = [
        {'q': '연말정산에서 놓친 공제, 5월에 다시 받을 수 있나요?', 'a': '네, 가능합니다. 5월 종합소득세 신고(경정청구)를 통해 연말정산에서 누락된 공제를 추가로 신청할 수 있습니다. 최대 5년 이내의 공제까지 소급 신청 가능합니다.'},
        {'q': '회사에 알리기 싫은 의료비, 따로 공제받는 방법은?', 'a': '연말정산 때 해당 항목을 빼고, 5월에 개인적으로 종합소득세 신고를 하면 됩니다. 홈택스에서 직접 신고하면 회사에는 해당 내역이 전달되지 않습니다.'},
        {'q': '언제부터 체크카드를 써야 유리한가요?', 'a': '총급여의 25%를 신용카드로 채운 뒤, 그 이후부터는 체크카드·현금을 사용하는 것이 유리합니다. 체크카드는 공제율이 30%로 신용카드(15%)의 두 배입니다.'},
        {'q': '중도 퇴사자 연말정산은 어떻게 하나요?', 'a': '퇴사 시 회사에서 기본 연말정산을 해줍니다. 이후 다른 회사에 입사하면 전 직장 원천징수영수증을 제출하고, 미취업 상태라면 다음 해 5월에 직접 종합소득세를 신고합니다.'},
        {'q': '부양가족 공제, 형제자매도 가능한가요?', 'a': '가능합니다. 만 20세 이하 또는 만 60세 이상의 형제자매가 연 소득 100만원 이하이고 다른 가족이 공제받지 않는 경우, 기본공제 대상에 포함됩니다.'},
      ];
    } else if (_userType == '프리랜서') {
      faqs = [
        {'q': '3.3% 떼고 받았는데 5월에 세금을 또 내야 하나요?', 'a': '3.3%는 원천징수(미리 떼는 세금)일 뿐, 실제 세금과 다를 수 있습니다. 5월 종소세 신고 시 실제 세액을 계산하여, 더 냈으면 환급받고 덜 냈으면 추가 납부합니다.'},
        {'q': '단순경비율과 기준경비율, 어떤 게 유리한가요?', 'a': '일반적으로 수입이 적으면 단순경비율이, 수입이 많으면 간편장부가 유리합니다. 기준경비율은 주요경비를 증빙해야 하므로, 증빙 서류가 부족하면 불리할 수 있습니다.'},
        {'q': '식대, 교통비도 경비로 인정받을 수 있나요?', 'a': '업무와 직접 관련된 식대·교통비는 경비로 인정됩니다. 다만 간편장부나 복식부기로 신고하는 경우에만 개별 경비로 반영 가능하며, 추계신고(경비율) 시에는 이미 경비율에 포함되어 있습니다.'},
        {'q': '종소세 신고를 안 하면 가산세가 얼마나 붙나요?', 'a': '무신고 가산세 20%, 납부지연 가산세 연 8.03%가 부과됩니다. 부정 무신고의 경우 40%까지 올라갑니다. 환급 대상인데도 신고하지 않으면 환급을 받지 못합니다.'},
        {'q': '프리랜서도 부가세 신고를 해야 하나요?', 'a': '인적용역(프리랜서)은 부가가치세 면세 대상입니다. 별도의 부가세 신고가 필요 없습니다. 단, 사업자등록을 내고 물건을 판매하는 경우에는 부가세 신고가 필요합니다.'},
      ];
    } else {
      faqs = [
        {'q': '부업 수입이 생기면 회사에 자동으로 통보되나요?', 'a': '소득 자체가 통보되지는 않지만, 부업 소득으로 건강보험료가 오르면 회사에 간접적으로 알려질 수 있습니다. 종소세 신고 시 건보료 납부 방법을 "개인별 고지"로 선택하면 이를 방지할 수 있습니다.'},
        {'q': '직장 연말정산 끝냈는데 5월 종소세도 해야 하나요?', 'a': '네, 반드시 해야 합니다. 직장 외 소득(부업 등)이 있으면 모든 소득을 합산하여 5월에 종합소득세를 신고해야 합니다. 이때 연말정산에서 이미 낸 세금은 기납부세액으로 차감됩니다.'},
        {'q': '신용카드 공제와 부업 경비를 중복 처리할 수 있나요?', 'a': '불가능합니다. 하나의 지출은 근로소득 카드공제 또는 사업소득 필요경비 중 하나로만 적용해야 합니다. 업무용 지출은 경비로, 개인 소비는 카드공제로 분리하는 것이 유리합니다.'},
        {'q': '부업 수입 얼마부터 건보료가 오르나요?', 'a': '직장가입자의 경우, 근로 외 소득(이자·배당·사업·기타소득 합산)이 연 2,000만원을 초과하면 초과분에 대해 건강보험료가 추가 부과됩니다.'},
        {'q': '사업자등록 없이 프리랜서 소득 신고가 되나요?', 'a': '가능합니다. 사업자등록 없이도 종합소득세 신고 시 사업소득(프리랜서 소득)으로 신고할 수 있습니다. 다만 연 매출이 일정 규모 이상이면 사업자등록 의무가 생길 수 있습니다.'},
      ];
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        iconColor: AppTheme.inkTertiary(context),
        collapsedIconColor: AppTheme.inkTertiary(context),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 16),
        title: Text('자주 묻는 질문', style: AppTheme.sans(13, AppTheme.ink(context), weight: FontWeight.w700, spacing: -0.2)),
        children: faqs.map((faq) => _buildFaqItem(faq['q']!, faq['a']!)).toList(),
      ),
    );
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
