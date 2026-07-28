import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/db_helper.dart';
import '../security/notification_helper.dart';
import 'reminder.dart';

/// 사용자 맞춤 리마인더 서비스 — DB(reminders 테이블) CRUD + 시스템 알림 예약.
/// 알림 ID는 2000번대(리마인더 id + base)로 고정 세무 일정(1001~1009)과 분리.
class CustomReminderService {
  static const int _notifBase = 2000;

  Future<List<Reminder>> list() async {
    final rows = await dbService.getReminders();
    return rows.map((r) => Reminder.fromMap(r)).toList();
  }

  /// 생성 — DB 저장 후 notifId를 부여하고 활성 시 알림 예약.
  Future<Reminder> add(Reminder r) async {
    final id = await dbService.insertReminder(r.toMap());
    final saved = r.copyWith(id: id, notifId: _notifBase + (id <= 0 ? 1 : id));
    await dbService.updateReminder(saved.toMap());
    if (saved.enabled) await _schedule(saved);
    return saved;
  }

  /// 수정 — 기존 알림 취소 후 활성 시 재예약.
  Future<void> update(Reminder r) async {
    await dbService.updateReminder(r.toMap());
    if (r.notifId != null) await _cancelAllVariants(r.notifId!);
    if (r.enabled) await _schedule(r);
  }

  Future<void> remove(Reminder r) async {
    if (r.notifId != null) await _cancelAllVariants(r.notifId!);
    if (r.id != null) await dbService.deleteReminder(r.id!);
  }

  /// 기본 id + 매주 요일별 하위 id(7개) 전부 취소 — 주기 변경 시 잔여 예약 방지.
  Future<void> _cancelAllVariants(int notifId) async {
    await _safeCancel(notifId);
    for (int wd = 1; wd <= 7; wd++) {
      await _safeCancel(_weeklySubId(notifId, wd));
    }
  }

  Future<Reminder> toggle(Reminder r, bool on) async {
    final updated = r.copyWith(enabled: on);
    await update(updated);
    return updated;
  }

  static const String _payDayRecordTitle = '월급날이에요! 기록해볼까요?';
  static const String _freelancerRecordTitle = '가계부에 오늘 기록해볼까요?';

  /// 기록 넛지 시드 — 최초 1회만 reminders에 'record' 항목을 만든다(매월·급여일·18시).
  /// 월급날 알림과 가계부 기록 넛지를 하나로 합친 기본 제공 리마인더. 한 번 만들면 사용자가 시각만 편집 가능.
  /// 프리랜서는 고정 월급날 개념이 없어 문구를 분기한다(userType). 이미 시드된 프리랜서 유저는
  /// 옛 "월급날" 문구가 남아있으면 시각·주기는 그대로 두고 제목만 1회 갱신한다.
  Future<void> ensureRecordSeed({required int payDay, required String userType}) async {
    final all = await list();
    final title = userType == '프리랜서' ? _freelancerRecordTitle : _payDayRecordTitle;
    final existing = all.where((r) => r.kind == 'record').toList();
    if (existing.isNotEmpty) {
      final current = existing.first;
      if (userType == '프리랜서' && current.title == _payDayRecordTitle) {
        await update(current.copyWith(title: _freelancerRecordTitle));
      }
      return;
    }
    final now = DateTime.now();
    final day = payDay.clamp(1, 28);
    await add(Reminder(
      title: title,
      kind: 'record',
      frequency: ReminderFrequency.monthly,
      notifyDate: DateTime(now.year, now.month, day),
      notifyHour: 18,
      notifyMinute: 0,
      enabled: true,
    ));
  }

  /// 다음으로 울릴 활성 리마인더(요약 표시용).
  Future<Reminder?> nextUpcoming() async {
    final all = await list();
    final upcoming = all.where((r) => r.enabled).toList()
      ..sort((a, b) => nextInstance(a).compareTo(nextInstance(b)));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// 반복 주기에 맞춘 '다음 발화 시각'(미래). 표시·예약 공통.
  static DateTime nextInstance(Reminder r, {DateTime? from}) {
    final now = from ?? DateTime.now();
    final h = r.notifyHour, m = r.notifyMinute;
    switch (r.frequency) {
      case ReminderFrequency.once:
        return r.scheduledDateTime;
      case ReminderFrequency.daily:
        var when = DateTime(now.year, now.month, now.day, h, m);
        if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
        return when;
      case ReminderFrequency.weekly:
        // 선택된 요일 중 가장 가까운 다음 발화.
        return r.effectiveWeekdays
            .map((wd) => _nextWeekdayInstance(wd, h, m, from: now))
            .reduce((a, b) => a.isBefore(b) ? a : b);
      case ReminderFrequency.monthly:
        final day = r.notifyDate.day.clamp(1, 28); // 모든 달 존재 보장
        var when = DateTime(now.year, now.month, day, h, m);
        if (!when.isAfter(now)) {
          when = now.month == 12
              ? DateTime(now.year + 1, 1, day, h, m)
              : DateTime(now.year, now.month + 1, day, h, m);
        }
        return when;
    }
  }

  /// 반복 주기 → 네이티브 매치 컴포넌트. weekly는 요일별 개별 예약(_schedule)이라 여기선 안 쓰임.
  static DateTimeComponents? _matchFor(ReminderFrequency f) {
    switch (f) {
      case ReminderFrequency.once:
        return null;
      case ReminderFrequency.daily:
        return DateTimeComponents.time;
      case ReminderFrequency.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case ReminderFrequency.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
    }
  }

  /// 매주 반복은 요일마다 별도 네이티브 알람이 필요해 기본 id에서 파생된 하위 id를 쓴다.
  static int _weeklySubId(int notifId, int weekday) => notifId * 10 + (weekday - 1);

  static DateTime _nextWeekdayInstance(int weekday, int hour, int minute, {DateTime? from}) {
    final now = from ?? DateTime.now();
    var when = DateTime(now.year, now.month, now.day, hour, minute);
    var add = (weekday - when.weekday) % 7;
    if (add < 0) add += 7;
    when = when.add(Duration(days: add));
    if (!when.isAfter(now)) when = when.add(const Duration(days: 7));
    return when;
  }

  Future<void> _schedule(Reminder r) async {
    final notifId = r.notifId;
    if (notifId == null) return;

    if (r.frequency == ReminderFrequency.weekly) {
      for (final wd in r.effectiveWeekdays) {
        final when = _nextWeekdayInstance(wd, r.notifyHour, r.notifyMinute);
        try {
          await notificationHelper.scheduleAtDate(
            id: _weeklySubId(notifId, wd),
            title: r.title,
            body: '',
            when: when,
            matchComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (_) {
          // 웹 등 미지원 환경에서는 예약을 건너뛴다(UI는 유지).
        }
      }
      return;
    }

    final when = nextInstance(r);
    // 단발인데 이미 지난 시각이면 예약하지 않는다.
    if (r.frequency == ReminderFrequency.once && !when.isAfter(DateTime.now())) {
      return;
    }
    try {
      await notificationHelper.scheduleAtDate(
        id: notifId,
        title: r.title,
        body: '',
        when: when,
        matchComponents: _matchFor(r.frequency),
      );
    } catch (_) {
      // 웹 등 미지원 환경에서는 예약을 건너뛴다(UI는 유지).
    }
  }

  Future<void> _safeCancel(int id) async {
    try {
      await notificationHelper.cancel(id);
    } catch (_) {}
  }
}

final customReminderService = CustomReminderService();
