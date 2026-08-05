import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../security/notification_helper.dart';
import '../data/db_helper.dart';
import '../data/occupation_data.dart';
import '../data/recurring_template.dart';
import '../tax_engine/reserve_estimator.dart';
import 'system_reminder_catalog.dart';
import 'custom_reminder_service.dart';
import 'notification_history.dart';
import 'event_reminder_prefs.dart';

/// 세끌 시스템 알림 예약 — 세무 기한·문턱 등 '앱 기본' 알림.
/// 정의는 [kSystemReminderCatalog](system_reminder_catalog.dart)가 단일 출처,
/// 켜짐/꺼짐은 reminder_settings(없으면 ON)로 판정한다.
/// 기록 넛지는 더 이상 여기서 고정 예약하지 않고 reminders 테이블 시드로 이관됐다.
class ReminderScheduler {
  static const int idThreshold = 1005; // 공제 문턱 도달(즉시) — 카탈로그 sys_threshold와 동일

  /// 알림 켜짐 시 — 시스템 기한 재예약 + 기록 넛지 시드 보장(유형별).
  static Future<void> scheduleAll({required int payDay, required String userType}) async {
    await NotificationHistory.backfill(userType: userType);
    await scheduleTaxSeason(userType);
    await customReminderService.ensureRecordSeed(payDay: payDay, userType: userType);
  }

  static Future<void> cancelAll() => notificationHelper.cancelAll();

  /// 다가오는 [month]/[day] [hour]시의 가장 가까운 미래 날짜.
  static DateTime _nextOccurrence(int month, int day, {int hour = 9}) {
    final now = DateTime.now();
    var when = DateTime(now.year, month, day, hour);
    if (!when.isAfter(now)) when = DateTime(now.year + 1, month, day, hour);
    return when;
  }

  /// 시스템 기한 알림 — 카탈로그 기반. 유형 비해당·꺼짐 항목은 취소해 잘못된 알림을 막는다.
  static Future<void> scheduleTaxSeason(String userType) async {
    final settings = await dbService.getReminderSettings();
    bool isOn(String key) => settings[key] ?? true; // 행 없으면 ON
    final profile = await dbService.getProfile();
    final ownsCar = profile?['owns_car'] ?? true;
    final ownsHouse = profile?['owns_house'] ?? true;
    final occupationCode = profile?['occupation_code'] as String?;
    final isVatExempt = OccupationData.occupations[occupationCode]?.isPersonalService ?? false;

    for (final s in kSystemReminderCatalog) {
      if (s.isEvent) continue; // 이벤트형(문턱)은 발생 시점에 show…로 처리
      final active = s.appliesTo(userType,
              ownsCar: ownsCar, ownsHouse: ownsHouse, isVatExempt: isVatExempt) &&
          isOn(s.key);
      if (active) {
        String body = s.body;
        // 프리랜서·N잡러는 "5월 신고 준비" 알림에 예상 세금 대비 현재 적립 현황을 덧붙인다.
        if (s.key == 'sys_may_prep' && (userType == '프리랜서' || userType == 'N잡러')) {
          body = await _appendReserveStatus(body, userType);
        }
        // 프리랜서·N잡러는 "5월 신고 시작" 알림에 3.3%/8.8% 원천징수 정산 안내를 덧붙인다.
        if (s.key == 'sys_may_start' && (userType == '프리랜서' || userType == 'N잡러')) {
          body = _appendWithholdingNote(body);
        }
        // 직장인은 근로소득만 있으면 연말정산으로 종결돼 5월 신고가 의무가 아니다 —
        // 회사가 놓친 공제가 있을 때만 해당된다는 안내를 덧붙인다.
        if ((s.key == 'sys_may_prep' || s.key == 'sys_may_start' || s.key == 'sys_may_dday') &&
            userType == '직장인') {
          body = _appendEmployeeOptionalNote(body);
        }
        await notificationHelper.scheduleAtDate(
          id: s.notifId,
          title: s.title,
          body: body,
          when: _nextOccurrence(s.month!, s.day!, hour: s.hour),
        );
      } else {
        await notificationHelper.cancel(s.notifId);
      }
    }
  }

  /// "5월 신고 시작" 알림 본문에 3.3%/8.8% 원천징수 정산(환급/추가납부) 안내를 덧붙인다.
  static String _appendWithholdingNote(String baseBody) {
    return '$baseBody 사업소득(3.3%)·기타소득(8.8%)으로 미리 낸 세금은 실제 세액과 정산돼 돌려받거나(환급) 더 낼(추가납부) 수 있어요.';
  }

  /// 직장인의 5월 종소세 알림에 대상 여부 안내를 덧붙인다 — 회사가 놓친 공제뿐 아니라
  /// 회사에 알리고 싶지 않아 연말정산에서 일부러 뺀 공제도 이때 직접 신고할 수 있다.
  static String _appendEmployeeOptionalNote(String baseBody) {
    return '$baseBody 회사가 놓친 공제나, 회사에 알리고 싶지 않아 일부러 뺀 공제가 있다면 이때 직접 신고하세요.';
  }

  /// "5월 신고 준비" 알림 본문에 예상 세금 대비 현재 적립 현황을 덧붙인다.
  /// 이번 달분이 아니라 연간 전체를 보여줘야 신고 시점 감각에 맞아 annualTotalTax 범위를 그대로 쓴다.
  static Future<String> _appendReserveStatus(String baseBody, String userType) async {
    try {
      final estimate = await ReserveEstimator.estimateForCurrentMonth(userType: userType);
      final annualMin = (estimate.minMonthlyTaxReserve * 12).round();
      final annualMax = (estimate.maxMonthlyTaxReserve * 12).round();
      final fmt = NumberFormat('#,###');
      final range = annualMin == annualMax
          ? '${fmt.format(annualMin)}원'
          : '${fmt.format(annualMin)}~${fmt.format(annualMax)}원';
      return '$baseBody 올해 예상 세금은 대략 $range이에요 — 가계부에서 적립 현황을 확인해보세요.';
    } catch (_) {
      return baseBody;
    }
  }

  /// 공제 문턱 도달 — 즉시 1회. 설정에서 꺼져 있으면 보내지 않는다.
  static Future<void> showThresholdReached() => _fireEvent('sys_threshold');

  /// 공제 문턱 임박(80%) — 즉시 1회. 설정에서 꺼져 있으면 보내지 않는다.
  static Future<void> showThresholdNear() => _fireEvent('sys_threshold_near');

  static const int idBudgetNear = 1014;
  static const int idBudgetOver = 1015;

  /// 예산 80%·초과 알림 — 감지 즉시 쏘지 않고 지연 예약한다(이미 화면을 보고 있는
  /// 상태라 즉시 알림이 무의미함). 16시 이전 감지면 당일 저녁(기본 20:00, 리마인더에서
  /// 사용자 편집 가능), 16시 이후면 다음날 아침 9시(고정) 예약.
  static Future<void> scheduleBudgetAlert({required bool over}) async {
    final pref = await resolveEventPref('budget_alert');
    if (!pref.enabled) return;
    final id = over ? idBudgetOver : idBudgetNear;
    final title = over ? '이번 달 지출 목표를 초과했어요' : '이번 달 지출 목표의 80%에 도달했어요';
    final body = over
        ? '지출이 목표액을 넘었어요. 남은 기간 지출을 줄이면 다음 달이 편해져요.'
        : '지출 목표까지 얼마 남지 않았어요. 남은 달을 조금 아껴볼까요?';
    final now = DateTime.now();
    var target = now.hour < 16
        ? DateTime(now.year, now.month, now.day, pref.hour, pref.minute)
        : DateTime(now.year, now.month, now.day + 1, 9, 0);
    if (!target.isAfter(now)) {
      target = DateTime(now.year, now.month, now.day + 1, 9, 0);
    }
    await notificationHelper.scheduleNotification(
      id: id,
      title: title,
      body: body,
      delay: target.difference(now),
    );
  }

  /// 예산 목표 아래로 다시 내려가는 등 조건이 해소되면 예약된 지연 알림을 취소한다.
  static Future<void> cancelBudgetAlert({required bool over}) =>
      notificationHelper.cancel(over ? idBudgetOver : idBudgetNear);

  static Future<void> _fireEvent(String key) async {
    final s = systemReminderByKey(key);
    if (s == null) return;
    final settings = await dbService.getReminderSettings();
    if (settings[key] == false) return; // 명시적으로 꺼졌을 때만 차단
    await notificationHelper.showImmediateNotification(
      id: s.notifId,
      title: s.title,
      body: s.body,
      logCategory: key,
    );
  }

  /// 카드 결제일 알림 — [cards] 목록의 각 카드마다 매월 반복 (ids 2100~2199).
  static Future<void> scheduleCardPayments(List<Map<String, dynamic>> cards) async {
    for (int i = 0; i < 100; i++) {
      await notificationHelper.cancel(2100 + i);
    }
    final now = DateTime.now();
    for (int i = 0; i < cards.length; i++) {
      final name = cards[i]['name'] as String;
      final day  = cards[i]['day'] as int;
      var when = DateTime(now.year, now.month, day, 9);
      if (!when.isAfter(now)) {
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear  = now.month == 12 ? now.year + 1 : now.year;
        when = DateTime(nextYear, nextMonth, day, 9);
      }
      await notificationHelper.scheduleAtDate(
        id: 2100 + i,
        title: '$name 결제일이에요',
        body: '가계부에 남겨두면 편해요',
        when: when,
        matchComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  static const int idInactivityNudge = 2002;

  /// 가계부 미기록 넛지 — 3일 이상 기록이 없으면 다음날 아침(기본 9시, 리마인더에서 편집
  /// 가능) 지연 알림 예약. 그 사이 기록해서 3일 미만으로 돌아오면 예약을 취소한다.
  static Future<void> checkInactivityNudge(DateTime? lastExpenseDate) async {
    final pref = await resolveEventPref('inactivity_nudge');
    if (!pref.enabled || lastExpenseDate == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(lastExpenseDate.year, lastExpenseDate.month, lastExpenseDate.day);
    if (today.difference(last).inDays < 3) {
      await notificationHelper.cancel(idInactivityNudge);
      return;
    }
    final target = DateTime(now.year, now.month, now.day + 1, pref.hour, pref.minute);
    await notificationHelper.scheduleNotification(
      id: idInactivityNudge,
      title: '기록이 비었어요',
      body: '며칠째 지출 기록이 없어요',
      delay: target.difference(now),
    );
  }

  /// 고정지출 알림 — 템플릿마다 dayOfMonth 당일 1건, 매달 반복 (ids 2200~2299).
  /// 전체 템플릿을 묶는 토글 하나(recurring_expense_alert)로 온/오프.
  static Future<void> scheduleRecurringExpenses(List<RecurringTemplate> templates) async {
    for (int i = 0; i < 100; i++) {
      await notificationHelper.cancel(2200 + i);
    }
    final pref = await resolveEventPref('recurring_expense_alert');
    if (!pref.enabled) return;
    final now = DateTime.now();
    for (int i = 0; i < templates.length && i < 100; i++) {
      final t = templates[i];
      var when = DateTime(now.year, now.month, t.dayOfMonth, pref.hour, pref.minute);
      if (!when.isAfter(now)) {
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        when = DateTime(nextYear, nextMonth, t.dayOfMonth, pref.hour, pref.minute);
      }
      await notificationHelper.scheduleAtDate(
        id: 2200 + i,
        title: '오늘 ${t.name} 결제일이에요',
        body: '가계부에 남겨둘까요?',
        when: when,
        matchComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  static const int idIncomeInactivityNudge = 2004;

  /// 수입 미기록 넛지 — 지출 넛지와 별도 토글. 3일 이상 수입 기록이 없으면
  /// 다음날 아침(기본 9시, 리마인더에서 편집 가능) 지연 알림 예약.
  static Future<void> checkIncomeInactivityNudge(DateTime? lastIncomeDate) async {
    final pref = await resolveEventPref('income_inactivity_nudge');
    if (!pref.enabled || lastIncomeDate == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(lastIncomeDate.year, lastIncomeDate.month, lastIncomeDate.day);
    if (today.difference(last).inDays < 3) {
      await notificationHelper.cancel(idIncomeInactivityNudge);
      return;
    }
    final target = DateTime(now.year, now.month, now.day + 1, pref.hour, pref.minute);
    await notificationHelper.scheduleNotification(
      id: idIncomeInactivityNudge,
      title: '수입 기록이 없어요',
      body: '며칠째 수입 기록이 없어요',
      delay: target.difference(now),
    );
  }

  static const int idTaxReserveShortfall = 2005;

  /// 세금 적립 부족 경고 — 이번 달 권장 최소 적립액([recommendedMinReserve]) 대비
  /// 실제로 "보험/금융" 카테고리에 기록된 지출([actualReserved])이 못 미치면 다음날
  /// 아침(기본 9시, 리마인더에서 편집 가능) 지연 알림 예약. 조건 해소 시 자동 취소.
  static Future<void> checkTaxReserveShortfall({
    required double recommendedMinReserve,
    required double actualReserved,
  }) async {
    final pref = await resolveEventPref('tax_reserve_shortfall');
    if (!pref.enabled || recommendedMinReserve <= 0) return;
    if (actualReserved >= recommendedMinReserve) {
      await notificationHelper.cancel(idTaxReserveShortfall);
      return;
    }
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day + 1, pref.hour, pref.minute);
    final shortfallPct =
        (((recommendedMinReserve - actualReserved) / recommendedMinReserve) * 100).round();
    await notificationHelper.scheduleNotification(
      id: idTaxReserveShortfall,
      title: '세금 적립이 부족해요',
      body: '권장보다 $shortfallPct% 모자라요',
      delay: target.difference(now),
    );
  }

  static const int idFreelancerHealthUninsured = 2006;

  /// 건강보험 미가입 경고 — 프리랜서 전용. 내 정보의 건강보험 가입여부([healthEnrolled])가
  /// false면 다음날 아침(기본 9시, 리마인더에서 편집 가능) 지연 알림 예약. 가입으로 바뀌면 자동 취소.
  static Future<void> checkFreelancerHealthUninsured({required bool healthEnrolled}) async {
    final pref = await resolveEventPref('freelancer_health_uninsured');
    if (!pref.enabled || healthEnrolled) {
      await notificationHelper.cancel(idFreelancerHealthUninsured);
      return;
    }
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day + 1, pref.hour, pref.minute);
    await notificationHelper.scheduleNotification(
      id: idFreelancerHealthUninsured,
      title: '건강보험 확인해보세요',
      body: '프리랜서는 직접 가입해야 해요. 등록하셨나요?',
      delay: target.difference(now),
    );
  }

}
