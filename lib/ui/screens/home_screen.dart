import 'dart:async';
import '../../core/tax_engine/tax_rates.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../theme/app_theme.dart';
import '../../core/update_service.dart';

import '../components/reminder_card.dart';
import '../components/slip_ticks.dart';
import '../components/section_accordion.dart';
import '../../core/data/year_coverage.dart';
import '../../core/data/year_snapshot.dart';
import 'home/missable_deduction_section.dart';
import 'backfill_screen.dart';
import '../components/just_updated_card.dart';
import '../components/update_card.dart';
import 'onboarding_screen.dart';
import 'my_info_screen.dart';
import 'tax_simulator_screen.dart';
import 'expense_calendar_screen.dart';
import 'missed_deduction_diagnosis_screen.dart';
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
  /// 홈의 몇 번째 장을 보고 있나 (0 = 이번 달, 1 = 도구와 문답).
  int _homePage = 0;
  final _homePageCtrl = PageController();

  double _debitCashTotal = 0.0;
  /// 결제수단이 '기타'이거나 비어 있는 이번 달 지출.
  double _otherPayTotal = 0.0;
  // 신용카드 연간(1월~오늘) 누계 — 공제 문턱(연봉의 25%)은 연 누적 기준이라 당월 합계와 분리.
  double _creditCardYtdTotal = 0.0;
  // 체크+현금 연간 누계 — 카드공제 환급 추정에 신용(15%)/체크·현금(30%) 분리 필요.
  double _debitCashYtdTotal = 0.0;
  double _excludedYtdTotal = 0.0; // 결제수단 '기타'·미설정 — 문턱에서 빠진 금액
  /// 공제율이 다른 세 갈래의 올해 누계 — 가계부 표식 + 채워 넣은 1~지난달.
  CardSpecials _specialsYtd = const CardSpecials();
  /// 가계부가 올 한 해를 덮는가. 안 덮으면 연간 누적 숫자를 안 보여준다.
  bool _yearCovered = true;
  /// 채워 넣은 1월~지난달 누계 — 가계부 기록이 아니라 요약이라 따로 더한다.
  Backfill _backfill = const Backfill();
  /// 공제율이 다른 세 갈래(전통시장·대중교통·도서공연)의 올해 누계.
  CardSpecials _cardSpecials = const CardSpecials();
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
  bool _isTypeIdentified = false;   // 유형 파악 완료 여부 (온보딩 1단계)
  bool _isProfileCompleted = false; // 프로필 완성 여부 (온보딩 2단계)
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

  // FAQ 셔플 — 유형별 풀을 한 번 섞어두고 5개씩 창(window)으로 보여준다.
  // 버튼을 누르면 offset을 5씩 밀어 새 5개를 노출(끝에서 앞으로 순환)하므로, 계속 누르면 모든 질문을 볼 수 있다.
  List<Map<String, String>> _faqShuffled = [];
  int _faqOffset = 0;
  String _faqPoolType = ''; // 풀을 만든 기준 유형 — 유형이 바뀌면 다시 섞는다.

  bool get _isEmployee => _userType == '직장인' || _userType == 'N잡러';


  // 홈 상단 회전 배너 (광고·알림 카드) — 6초마다 페이드 전환, 유형별 카드 세트
  int _bannerIndex = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    // Play에 새 버전이 있는지 조용히 확인한다. 없거나 확인이 안 되는 환경이면
    // 카드가 아예 안 그려지므로 결과를 기다릴 필요가 없다.
    updateService.check();
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
          
          // SQLite의 REAL 칸은 정수로 넣으면 int로 돌아온다 — double로 바로
          // 캐스팅하면 던진다. 예전에는 그 실패를 삼켜서 급여가 0으로 보였다.
          final monthlyIncome =
              (profile['monthly_income'] as num?)?.toDouble() ?? 0.0;

          if (monthlyIncome > 0) {
            _salaryController.text = comma(monthlyIncome.toInt());
          }
          
          _dependentCount = profile['dependents'] as int? ?? 0;
          _childrenCount = profile['children_count_total'] as int? ?? 0;
          
          final monthlyRent = profile['monthly_rent'] as double? ?? 0.0;
          if (monthlyRent > 0) {
            _monthlyRentController.text = comma(monthlyRent.toInt());
          }

          final yellowUmbrella = profile['yellow_umbrella'] as double? ?? 0.0;
          if (yellowUmbrella > 0) {
            _yellowUmbrellaController.text = comma(yellowUmbrella.toInt());
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
    _loadHiddenBanners();
  }

  Future<void> _refreshUnreadCount() async {
    final count = await dbService.unreadNotificationCount();
    if (mounted) setState(() => _unreadNotifCount = count);
  }

  /// 알림 켜짐 상태면 시즌·월간 리마인더를 (재)예약. 웹은 미지원.
  ///
  /// 홈 진입 때 await 없이 부르는 자리라 여기서 새어 나간 예외는 아무도 못 잡는다.
  /// 예약은 부가 기능이고 기기·권한 상태에 따라 실패할 수 있으니, 실패해도 홈은
  /// 그대로 떠야 한다.
  Future<void> _refreshReminders() async {
    if (kIsWeb) return;
    try {
      if (_notificationsEnabled) {
        await ReminderScheduler.scheduleAll(payDay: _payDay, userType: _userType);
      } else {
        await ReminderScheduler.cancelAll();
      }
    } catch (e, st) {
      // logcat으로만 흘리면 기기에서는 아무 데도 안 보인다 —
      // 「설정 → 알림 점검」이 읽을 수 있게 오류 기록으로 남긴다.
      await dbService.insertErrorLog('리마인더 예약 실패: $e', st.toString());
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text('정확한 시간에 알림 받기'.keepWords,
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
          _activeIncomeController.text = comma(total.toInt());
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

  /// 1월~지난달 채우기 — 홈 배너와 02 블록 둘 다 여기로 온다.
  Future<void> _openBackfill() async {
    final done = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => BackfillScreen(userType: _userType)));
    if (done == true) {
      await _loadMonthlyExpenses();
      if (mounted) _calculateTax();
    }
  }

  Future<void> _loadMonthlyExpenses() async {
    final now = DateTime.now();
    // 연간 누적을 셈하기 전에 먼저 안다 — 이 값들이 누계에 더해지고 빠진다.
    _yearCovered = await YearCoverage.isComplete(now.year);
    _backfill = await YearCoverage.backfill(now.year);
    _cardSpecials = await YearCoverage.specials(now.year);
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final nextMonth = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final lastOfMonth = nextMonth.subtract(const Duration(days: 1));

    final all = await dbService.getExpenses(userType: _userType);
    final firstOfYear = DateTime(now.year, 1, 1);
    double credit = 0.0;
    double debit = 0.0;
    double otherPay = 0.0;
    double creditYtd = 0.0;
    double debitYtd = 0.0;
    double excludedYtd = 0.0;
    // 가계부에서 「공제 구분」이 붙은 지출 — 신용/체크에 넣지 않고 여기로 뺀다.
    final ledgerSpecial = <String, double>{'전통시장': 0, '대중교통': 0, '도서공연': 0};
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
        // 연 누적처럼 **셋으로** 가른다. 예전에는 신용카드가 아니면 전부
        // 체크·현금으로 보냈다 — 기타로 적은 지출이 체크·현금 숫자에 섞여
        // 들어가, 가계부에는 있는 항목이 홈에서는 어디에도 안 보였다.
        if (e.paymentMethod == '신용카드') {
          credit += e.amount;
        } else if (e.paymentMethod == '체크+현금') {
          debit += e.amount;
        } else {
          otherPay += e.amount;
        }
      }
      // 카드공제는 연 누적 기준 — 올해 1월~오늘. 신용/체크·현금은 공제율이 달라 분리 집계.
      // ('기타' 결제수단은 현금영수증 없는 지출로 보아 공제 대상에서 제외.)
      if (!eStart.isBefore(firstOfYear) && !eStart.isAfter(now)) {
        // 갈래를 나누는 규칙은 [cardBucket] 하나뿐이다. 예전엔 이 규칙이
        // 화면마다 따로 적혀 있어서, 연말정산 진단과 홈택스 가이드가 「기타」를
        // 체크·현금에 섞고 특례 셋을 아예 못 봤다 — 같은 앱의 두 화면이 다른
        // 카드공제액을 말했다.
        switch (cardBucket(e)) {
          case '신용카드':
            creditYtd += e.amount;
          case '체크+현금':
            debitYtd += e.amount;
          case final String dt when ledgerSpecial.containsKey(dt):
            ledgerSpecial[dt] = ledgerSpecial[dt]! + e.amount;
          default:
            // '기타'·미설정 — 문턱에 안 들어간다. 왜 안 줄어드는지 말해주려고 센다.
            excludedYtd += e.amount;
        }
      }
    }
    if (mounted) {
      setState(() {
        _creditCardTotal = credit;
        _debitCashTotal = debit;
        _otherPayTotal = otherPay;
        // 채워 넣은 1~지난달을 더한다. 그리고 전통시장·대중교통·도서공연은
        // 신용카드 누계에서 **뺀다** — 카드로 긁은 돈이라 가계부에 이미
        // 신용카드로 들어와 있고, 안 빼면 15%와 40%로 두 번 센다.
        _creditCardYtdTotal =
            (creditYtd + _backfill.credit - _cardSpecials.total)
                .clamp(0.0, double.infinity);
        _debitCashYtdTotal = debitYtd + _backfill.debit;
        _specialsYtd = CardSpecials(
          market: _cardSpecials.market + ledgerSpecial['전통시장']!,
          transport: _cardSpecials.transport + ledgerSpecial['대중교통']!,
          culture: _cardSpecials.culture + ledgerSpecial['도서공연']!,
        );
        _excludedYtdTotal = excludedYtd;
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
    final total = _creditCardTotal + _debitCashTotal + _otherPayTotal;
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

    // 기존 프로필을 읽어 위저드에서 설정한 공제 항목(혼인·자녀·경로우대 등)을 보존(merge)
    final existing = await dbService.getProfile() ?? <String, dynamic>{};
    final profile = {
      ...existing,
      'user_type': _userType,
      // gross_income·expense_target은 여기서 안 쓴다 — 유형별 값(profile_type_values)이
      // 원본이고, 그 저장 함수가 user_profile까지 같이 갱신한다. 홈이 자기 메모리 값으로
      // 덮으면 아직 안 읽힌 0이 방금 저장한 연봉을 지운다(2026-08-14).
      // 부양가족·거주형태·급여일도 홈은 읽기만 한다. 여기서 다시 적으면 미입력이
      // 0·false·25로 굳어 내 정보가 "고른 적 없는 값"을 고른 것처럼 보여준다.
      'monthly_rent': monthlyRent,
      'decided_tax': _decidedTax,
      'yellow_umbrella': yellowUmbrella,
      'monthly_income': monthlyIncome,
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
    _homePageCtrl.dispose();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                  _otherPayTotal = 0.0;
                  _creditCardYtdTotal = 0.0;
                  _debitCashYtdTotal = 0.0;
                  _excludedYtdTotal = 0.0;
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
                      backgroundColor: const Color(0xFFFF4D4D),
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
          _expenseTarget > 0 ? comma(_expenseTarget.toInt()) : '';
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        // 발행처 표시는 이제 물결 마크다 — 앱 아이콘과 같은 곡선.
        // 가로로 길고 낮게 써서 머리글 높이를 '세 끌' 때와 같게 유지한다.
        // 폭만 줄인다 — 파장이 고정이라 물결이 눌리지 않고 양 끝이 잘린다.
        title: AppTheme.waveMark(context, height: 23, width: 84),
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
    return '${comma(man)}만원';
  }

  /// 한계세율 — 구간표는 엔진 하나만 본다(소법 §55①).
  /// 여기에 표를 복사해 두었더니 2023년 개정을 놓쳐 4,600만~5,000만 구간의
  /// N잡러에게 15%를 24%라고 말하고 있었다.
  int _marginalRate(double annualIncome) =>
      TaxRates.marginalRatePercent(annualIncome);


  /// 직장인/N잡러/프리랜서별 세무 도구 카드
  void _go(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  /// 가계부로 이동 후 복귀 — 분석탭에서 바뀌었을 수 있는 유형별 지출 목표를 다시 읽어온다.
  Future<void> _goToLedger({int view = 0}) async {
    // 복귀 시 리로드는 didPopNext(RouteObserver)가 처리.
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ExpenseCalendarScreen(initialView: view)));
  }

  /// 지출 목표를 **홈에 머문 채, 그 자리에서** 정한다.
  ///
  /// 한동안 가계부 분석 탭으로 보냈다가, 다음엔 팝업으로 띄웠다. 둘 다 틀렸다 —
  /// 화면을 옮기면 낯선 데로 끌려가고, 팝업을 띄우면 지금 보고 있던 지출 합계가
  /// 가려져 목표를 얼마로 잡을지 판단할 근거가 덮인다. 게다가 이 앱은 종이
  /// 명세서라 위에 뜨는 창이 없다.
  ///
  /// 이제 02 블록이 그 줄을 입력칸으로 펼친다(`ExpenseTargetField`). 가계부
  /// 분석 탭도 **같은 입력칸**을 쓰므로 두 곳이 어긋날 자리가 없다.
  Future<void> _editExpenseTarget(double val) async {
    if (!mounted) return;
    await dbService.setProfileTypeValues(_userType, expenseTarget: val);
    if (!mounted) return;
    setState(() {
      _expenseTarget = val;
      _savingGoalController.text = comma(val.toInt());
    });
    _checkBudget();
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

  /// 홈은 **두 장의 명세서**다.
  ///
  /// 한 장에 절이 다섯(01~05) 쌓여 있어 "너무 많이 보인다"는 의견이 모였다.
  /// 매달 보는 것(돈·알림)과 필요할 때 찾는 것(도구·문답)은 성격이 다르니
  /// 장을 가른다.
  ///
  /// 머리(발행 정보·유형 선택)는 **페이지 밖에 고정**한다. 머리는 가만히
  /// 있는데 내용만 옆으로 미끄러져야 "두 장"이라는 게 읽히고, 덤으로 유형
  /// 선택이 어느 장에서든 손에 닿는다.
  Widget _buildHomeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 선은 아래 한 줄만. 위아래로 두 번 그으면 머리줄이 상자가 된다.
              // 발행 정보는 그 선에 바짝 붙어야 '선 위에 찍힌 것'으로 읽힌다.
              _slipMeta(),
              AppTheme.hairline(context, color: AppTheme.ink(context)),
              const SizedBox(height: 14),
              _buildTypeSelector(),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _homePageCtrl,
            onPageChanged: (i) => setState(() => _homePage = i),
            children: [
              _homePageOne(),
              _homePageTwo(),
            ],
          ),
        ),
        // 장 표시는 **맨 아래**에 둔다.
        //
        // 배너 회전 틱과 같은 모양이라, 위쪽 머리에 두면 둘이 100픽셀 거리에
        // 나란히 놓여 무엇이 무엇인지 모호했다. 아래로 내리면 "지금 몇 번째
        // 장"이라는 뜻이 자리로 읽힌다.
        //
        // 장을 넘기는 길은 **손가락과 이 표시 둘뿐**이다. 1장 끝에 "다음 장으로"
        // 링크를 뒀었는데, 가는 길만 있고 돌아오는 길이 없어 한쪽으로만 흐르는
        // 문이 됐다. 좌우로 미는 건 양방향이고, 이 표시는 어느 장에서든 눌러서
        // 건너뛸 수 있다.
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Center(
            child: SlipTicks(
              count: 2,
              active: _homePage,
              onTap: _goToHomePage,
              labelFor: (i) => i == 0 ? '이번 달' : '도구와 문답',
            ),
          ),
        ),
      ],
    );
  }

  /// 1장 — 이번 달 얼마 벌고 썼나. 홈이 답해야 할 질문이 이것이다.
  Widget _homePageOne() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 업데이트가 있을 때만 그려진다. 없으면 자리를 차지하지 않는다.
          const UpdateCard(),
          // 방금 업데이트하고 처음 열었을 때만. 누르면 사라진다.
          const JustUpdatedCard(),
          HomeBannerCarousel(
            cards: _bannerCards(),
            activeIndex: _bannerIndex,
            onTickTap: (i) {
              setState(() => _bannerIndex = i);
              _startBannerRotation();
            },
            onDismiss: _dismissBanner,
          ),
          _slipRule(),
          HomeStatusSection(
            specialsYtd: _specialsYtd,
            yearCovered: _yearCovered,
            onFillPreviousMonths: _openBackfill,
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
            otherPayTotal: _otherPayTotal,
            creditCardYtdTotal: _creditCardYtdTotal,
            debitCashYtdTotal: _debitCashYtdTotal,
            excludedFromThresholdYtd: _excludedYtdTotal,
            refundProgress: _refundProgress,
            cardSavingCombined: _cardSavingCombined,
            onOpenLedger: _goToLedger,
            onOpenMyInfo: _openProfile,
            onExpenseTargetChanged: _editExpenseTarget,
          ),
          _slipRule(),
          ReminderCard(userType: _userType),
          _slipRule(),
          // 04는 유형에 따라 갈린다 — 직장인·N잡러는 놓치기 쉬운 공제,
          // 프리랜서는 장부 만들기. 2장의 세무 도구·FAQ가 05·06으로 밀린다.
          MissableDeductionSection(userType: _userType),
          _slipFooter(),
        ],
      ),
    );
  }

  /// 2장 — 필요할 때 찾는 것.
  Widget _homePageTwo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TaxToolsAccordion(userType: _userType),
          _slipRule(),
          _buildFaqCard(),
          _slipFooter(),
        ],
      ),
    );
  }

  void _goToHomePage(int i) {
    if (!_homePageCtrl.hasClients) return;
    _homePageCtrl.animateToPage(i,
        duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  /// 명세서 머리줄 — 발행 시각과 귀속연도. 종이 영수증이 맨 위에 찍는 것.
  Widget _slipMeta() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 5),
      // 자간 2.0인 label 스타일을 그대로 쓰면 360px에서 두 칸이 부딪힌다.
      // 머리줄은 좁은 화면에서도 한 줄이어야 하므로 자간을 줄여 쓴다.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 좁은 화면에서는 발행 시각이 먼저 줄어든다 — 오른쪽 두 항목이 잘리면 안 된다.
          Flexible(
            child: Text('${now.year}-${two(now.month)}-${two(now.day)}',
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(AppTheme.tsXS, AppTheme.inkSecondary(context),
                    weight: FontWeight.w600, spacing: 1.0)),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Semantics(
              button: true,
              label: _isProfileCompleted ? '내 정보 수정' : '내 정보 설정',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openProfile,
                child: Text(_isProfileCompleted ? '내 정보' : '내 정보 설정',
                    style: AppTheme.sans(AppTheme.tsXS, AppTheme.ink(context),
                        weight: FontWeight.w700, spacing: 1.0,
                        decoration: TextDecoration.underline)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  /// 절을 가르는 선. 기본은 점선, 소계 위에서만 실선.
  Widget _slipRule({bool solid = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: solid
            ? Container(height: 1, color: AppTheme.ink(context))
            : AppTheme.dashRule(context),
      );

  /// 명세서 끝 — 바코드와 한 줄. 이 앱이 무엇인지 마지막으로 말하는 자리.
  Widget _slipFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        children: [
          Container(height: 1, color: AppTheme.ink(context)),
          const SizedBox(height: 12),
          Text('이 명세서는 기기 안에만 있습니다'.keepWords,
              style: AppTheme.label(context, color: AppTheme.inkSecondary(context))),
          const SizedBox(height: 10),
          AppTheme.barcode(context, height: 26),
          const SizedBox(height: 6),
          Text('＊ S E K K E U L ＊',
              style: AppTheme.label(context, color: AppTheme.inkTertiary(context))),
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

  /// 유형 파악 온보딩 진입 — 결과로 user_type + type_identified 저장.
  Future<void> _openOnboarding() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => OnboardingScreen(
              returnResult: true,
              // 유형을 이미 아는 사람은 자기 유형이 체크된 채로 시작한다.
              currentType: _isTypeIdentified ? _userType : null)),
    );
    if (result is String && mounted) {
      setState(() => _isTypeIdentified = true);
      // 유형 탭을 눌렀을 때와 같은 경로로 넘긴다 — 가계부·수입·알림까지 다시 읽어야
      // 유형이 바뀐 뒤 화면이 옛 유형의 숫자를 들고 있지 않는다.
      _setUserType(result);
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
                action: '가계부에 기록하기',
                glyph: '카',
                onTap: _goToLedger,
              )
            : BannerCardData(
                label: '신카 공제',
                headline: '공제 문턱 돌파!\n체크카드로 2배 공제예요',
                action: '가계부에 기록하기',
                glyph: '↑',
                onTap: _goToLedger,
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
                action: '가계부에 기록하기',
                glyph: '카',
                onTap: _goToLedger,
              )
            : BannerCardData(
                label: '신카 공제',
                headline: '공제 문턱 돌파!\n체크카드로 2배 공제예요',
                action: '가계부에 기록하기',
                glyph: '↑',
                onTap: _goToLedger,
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

    // **1월~지난달이 비어 있으면 그 얘기를 맨 앞에 둔다.**
    //
    // 연중에 깐 사람에게는 이게 제일 급하다. 이걸 안 채우면 카드 공제도 예상
    // 환급도 계산이 안 나오는데, 그 사실을 02 블록 안에서만 말하면 스크롤을
    // 내려야 보인다. 배너는 앱을 켜자마자 눈에 닿는 유일한 자리다.
    if (!_yearCovered && DateTime.now().month > 1) {
      final last = DateTime.now().month - 1;
      cards.insert(
        0,
        BannerCardData(
          label: '이전 달',
          headline: '1~$last월을 채우면\n올해 환급이 보여요',
          action: '2분이면 끝나요',
          glyph: '채',
          onTap: _openBackfill,
          // 닫으면 연간 계산으로 가는 길이 사라진다.
          dismissible: false,
        ),
      );
    }

    // 유형별 도구 카드
    if (_userType == '직장인') {
      cards.addAll([
        // 경정청구가 아니라 **5월 종합소득세**다. 연말정산에서 빠뜨린 공제는
        // 그 해 5월 확정신고에 얹으면 되고, 경정청구는 그 시기를 놓쳤을 때
        // 5년 안에 아무 때나 하는 별개의 길이다. 둘을 붙여 「5월 경정청구」로
        // 쓰면 5월이 지나면 못 받는 것처럼 읽힌다.
        BannerCardData(label: '환급', headline: '회사가 놓친 공제,\n5월 종합소득세로 돌려받아요', action: '환급액 계산하기', glyph: '환', onTap: () => _go(TaxSimulatorScreen(userType: _userType))),
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
      label: s.label, headline: s.headline, action: s.action, glyph: s.glyph, onTap: _openOnboarding,
    ));

    // 이달의 절세 팁을 상단 회전 배너에 합친다(별도 카드 제거).
    cards.addAll(_tipBannerCards());
    return cards;
  }

  /// 유형 선택 — 전표의 체크칸. 가계부 뷰 전환과 같은 위젯을 쓴다.
  Widget _buildTypeSelector() {
    const types = ['직장인', 'N잡러', '프리랜서'];
    return AppTheme.segmented(
      context,
      labels: types,
      selected: types.indexOf(_userType).clamp(0, types.length - 1),
      onTap: (i) => _switchUserType(types[i]),
      semanticSuffix: '유형',
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

    // 03·04와 같은 몸을 쓴다. 예전엔 여기만 Material ExpansionTile이었는데
    // 그 타일은 최소 높이가 48dp라, 접힌 상태에서 05만 한 뼘 더 두꺼웠다.
    return SectionAccordion(
      no: '06',
      title: '자주 묻는 질문',
      expanded: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...shown.map((faq) => _buildFaqItem(faq['q']!, faq['a']!)),
          if (pool.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Semantics(
                button: true,
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
                        Icon(Icons.refresh_rounded,
                            size: 15, color: AppTheme.inkSecondary(context)),
                        const SizedBox(width: 6),
                        Text('다른 질문 보기',
                            style: AppTheme.sans(AppTheme.tsXS, AppTheme.inkSecondary(context),
                                weight: FontWeight.w600)),
                      ],
                    ),
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
        {'q': '연말정산에서 놓친 공제, 5월에 다시 받을 수 있나요?', 'a': '네, 가능합니다. 그 해 5월 종합소득세 신고 때 누락된 공제를 함께 신청하면 됩니다. 5월도 지났다면 경정청구가 있습니다. 경정청구는 5월에만 하는 것이 아니라 신고기한으로부터 5년 안이면 아무 때나 할 수 있어서, 지난 5년치까지 거슬러 돌려받을 수 있습니다.'},
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
        title: Text('Q. $question', style: AppTheme.sans(AppTheme.tsXS, AppTheme.ink(context), weight: FontWeight.w600, height: 1.4)),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: AppTheme.accentColor(context), width: 2)),
            ),
            child: Text(answer, style: AppTheme.sans(AppTheme.tsXS, AppTheme.inkSecondary(context), height: 1.55)),
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
        // 배경은 테마가 투명으로 준다 — 하단바 밑으로도 같은 종이가 이어져야 한다.
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        selectedItemColor: AppTheme.ink(context),
        unselectedItemColor: AppTheme.inkTertiary(context),
        selectedFontSize: AppTheme.tsNav,
        unselectedFontSize: AppTheme.tsNav,
        // 전표에는 아이콘이 없다. 현재 칸은 잉크로 채운 사각형, 나머지는 빈 테두리.
        items: [
          for (final label in const ['홈', '혜택', '계산기', '전체'])
            BottomNavigationBarItem(
              icon: _navMark(false),
              activeIcon: _navMark(true),
              label: label,
            ),
        ],
      ),
    );
  }

  Widget _navMark(bool active) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? AppTheme.ink(context) : null,
            border: active ? null : Border.all(color: AppTheme.inkTertiary(context), width: 1),
          ),
        ),
      );
}

