import '../data/db_helper.dart';
import '../data/occupation_data.dart';
import 'custom_reminder_service.dart';
import 'reminder.dart';
import 'system_reminder_catalog.dart';

/// zonedSchedule로 예약된 알림(개인 리마인더 · 시스템 세무일정)은 OS가 백그라운드에서
/// 직접 발화시켜 Dart 콜백이 없다 — 그래서 알림함(notification_log)에 전혀 기록되지 않았다.
/// 앱을 열 때마다 마지막 체크포인트 이후 실제로 지났어야 할 발화를 역산해 알림함에 채운다.
class NotificationHistory {
  static const _checkpointKey = 'notif_history_checkpoint';
  static const int _maxBackfillDays = 30; // 오래 안 켠 경우 무한정 훑지 않도록 상한.

  static Future<void> backfill({required String userType}) async {
    final raw = await dbService.getAppState(_checkpointKey);
    final now = DateTime.now();

    if (raw == null) {
      // 첫 실행 — 과거를 지어내지 않고 지금부터 추적을 시작한다.
      await dbService.setAppState(_checkpointKey, now.toIso8601String());
      return;
    }

    var from = DateTime.tryParse(raw) ?? now;
    if (from.isAfter(now)) from = now; // 기기 시계 역행 방어
    if (now.difference(from).inDays > _maxBackfillDays) {
      from = now.subtract(const Duration(days: _maxBackfillDays));
    }

    if (now.isAfter(from)) {
      await _backfillCustomReminders(from, now);
      await _backfillSystemCatalog(from, now, userType);
    }

    await dbService.setAppState(_checkpointKey, now.toIso8601String());
  }

  static Future<void> _backfillCustomReminders(DateTime from, DateTime to) async {
    final reminders = await customReminderService.list();
    for (final r in reminders.where((r) => r.enabled)) {
      for (final when in _occurrences(r, from, to)) {
        await dbService.insertNotificationLog(
          title: r.title,
          body: '',
          category: 'reminder',
          firedAt: when,
        );
      }
    }
  }

  static Future<void> _backfillSystemCatalog(DateTime from, DateTime to, String userType) async {
    final settings = await dbService.getReminderSettings();
    bool isOn(String key) => settings[key] ?? true;
    final profile = await dbService.getProfile();
    final ownsCar = profile?['owns_car'] ?? true;
    final ownsHouse = profile?['owns_house'] ?? true;
    final occupationCode = profile?['occupation_code'] as String?;
    final isVatExempt = OccupationData.occupations[occupationCode]?.isPersonalService ?? false;

    for (final s in kSystemReminderCatalog) {
      if (s.isEvent) continue; // 이벤트형(문턱 등)은 즉시 알림이라 이미 기록됨.
      if (!s.appliesTo(userType,
              ownsCar: ownsCar, ownsHouse: ownsHouse, isVatExempt: isVatExempt) ||
          !isOn(s.key)) continue;
      for (final when in _systemOccurrences(s, from, to)) {
        await dbService.insertNotificationLog(
          title: s.title,
          body: s.body,
          category: s.key,
          firedAt: when,
        );
      }
    }
  }

  /// (from, to] 구간에 실제로 울렸을 사용자 리마인더 발화 시각들.
  static List<DateTime> _occurrences(Reminder r, DateTime from, DateTime to) {
    final result = <DateTime>[];
    switch (r.frequency) {
      case ReminderFrequency.once:
        final when = r.scheduledDateTime;
        if (when.isAfter(from) && !when.isAfter(to)) result.add(when);
        break;

      case ReminderFrequency.daily:
        var day = DateTime(from.year, from.month, from.day);
        final lastDay = DateTime(to.year, to.month, to.day);
        while (!day.isAfter(lastDay)) {
          final when = DateTime(day.year, day.month, day.day, r.notifyHour, r.notifyMinute);
          if (when.isAfter(from) && !when.isAfter(to)) result.add(when);
          day = day.add(const Duration(days: 1));
        }
        break;

      case ReminderFrequency.weekly:
        final targets = r.effectiveWeekdays;
        var day = DateTime(from.year, from.month, from.day);
        final lastDay = DateTime(to.year, to.month, to.day);
        while (!day.isAfter(lastDay)) {
          if (targets.contains(day.weekday)) {
            final when = DateTime(day.year, day.month, day.day, r.notifyHour, r.notifyMinute);
            if (when.isAfter(from) && !when.isAfter(to)) result.add(when);
          }
          day = day.add(const Duration(days: 1));
        }
        break;

      case ReminderFrequency.monthly:
        final targetDay = r.notifyDate.day.clamp(1, 28);
        var cursor = DateTime(from.year, from.month, 1);
        final lastMonth = DateTime(to.year, to.month, 1);
        while (!cursor.isAfter(lastMonth)) {
          final when = DateTime(cursor.year, cursor.month, targetDay, r.notifyHour, r.notifyMinute);
          if (when.isAfter(from) && !when.isAfter(to)) result.add(when);
          cursor = cursor.month == 12
              ? DateTime(cursor.year + 1, 1, 1)
              : DateTime(cursor.year, cursor.month + 1, 1);
        }
        break;
    }
    return result;
  }

  /// (from, to] 구간에 실제로 울렸을 시스템 알림(연중 고정 월/일) 발화 시각들.
  static List<DateTime> _systemOccurrences(SystemReminder s, DateTime from, DateTime to) {
    final result = <DateTime>[];
    final month = s.month, day = s.day;
    if (month == null || day == null) return result;
    for (final year in {from.year, to.year}) {
      final when = DateTime(year, month, day, s.hour);
      if (when.isAfter(from) && !when.isAfter(to)) result.add(when);
    }
    return result;
  }
}
