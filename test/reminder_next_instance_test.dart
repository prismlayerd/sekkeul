import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/notifications/custom_reminder_service.dart';
import 'package:secul/core/notifications/reminder.dart';

/// **다음 알림이 언제 울리는지.**
///
/// 이 계산이 틀리면 알림이 안 오거나 방금 지나간 시각으로 잡혀 즉시 울린다.
/// 둘 다 조용한 실패다 — 안 울린 건 아무도 모르고, 즉시 울린 건 앱 탓인 줄
/// 모른다. 경계(오늘 지나간 시각 · 같은 요일 · 말일 · 12월)를 붙잡아 둔다.
void main() {
  Reminder r(
    ReminderFrequency f, {
    DateTime? date,
    int hour = 9,
    int minute = 0,
    List<int> weekdays = const [],
  }) =>
      Reminder(
        title: '테스트',
        notifyDate: date ?? DateTime(2026, 8, 15),
        notifyHour: hour,
        notifyMinute: minute,
        frequency: f,
        weekdays: weekdays,
      );

  group('매일', () {
    test('오늘 시각이 아직 안 지났으면 오늘', () {
      final at = DateTime(2026, 8, 15, 7, 30);
      expect(CustomReminderService.nextInstance(r(ReminderFrequency.daily), from: at),
          DateTime(2026, 8, 15, 9, 0));
    });

    test('오늘 시각이 지났으면 내일', () {
      final at = DateTime(2026, 8, 15, 9, 0, 1);
      expect(CustomReminderService.nextInstance(r(ReminderFrequency.daily), from: at),
          DateTime(2026, 8, 16, 9, 0));
    });

    test('정각에 딱 걸리면 내일 — 지금 울리게 두면 예약하자마자 울린다', () {
      final at = DateTime(2026, 8, 15, 9, 0);
      expect(CustomReminderService.nextInstance(r(ReminderFrequency.daily), from: at),
          DateTime(2026, 8, 16, 9, 0));
    });
  });

  group('매주', () {
    // 2026-08-15는 토요일.
    test('오늘이 그 요일이고 시각이 남았으면 오늘', () {
      final at = DateTime(2026, 8, 15, 7, 0);
      final next = CustomReminderService.nextInstance(
          r(ReminderFrequency.weekly, weekdays: [DateTime.saturday]),
          from: at);
      expect(next, DateTime(2026, 8, 15, 9, 0));
    });

    test('오늘이 그 요일인데 시각이 지났으면 다음 주 같은 요일', () {
      final at = DateTime(2026, 8, 15, 10, 0);
      final next = CustomReminderService.nextInstance(
          r(ReminderFrequency.weekly, weekdays: [DateTime.saturday]),
          from: at);
      expect(next, DateTime(2026, 8, 22, 9, 0));
    });

    test('여러 요일을 골랐으면 그중 가장 가까운 것', () {
      final at = DateTime(2026, 8, 15, 10, 0); // 토요일 늦은 아침
      final next = CustomReminderService.nextInstance(
          r(ReminderFrequency.weekly,
              weekdays: [DateTime.monday, DateTime.saturday, DateTime.wednesday]),
          from: at);
      expect(next, DateTime(2026, 8, 17, 9, 0), reason: '다음은 월요일이다');
    });

    test('요일을 안 골랐으면 기준 날짜의 요일을 쓴다', () {
      final at = DateTime(2026, 8, 16, 0, 0); // 일요일
      final next = CustomReminderService.nextInstance(
          r(ReminderFrequency.weekly, date: DateTime(2026, 8, 15)), // 토요일
          from: at);
      expect(next, DateTime(2026, 8, 22, 9, 0));
    });
  });

  group('매월', () {
    test('이번 달 날짜가 남았으면 이번 달', () {
      final at = DateTime(2026, 8, 3);
      final next = CustomReminderService.nextInstance(
          r(ReminderFrequency.monthly, date: DateTime(2026, 1, 25)),
          from: at);
      expect(next, DateTime(2026, 8, 25, 9, 0));
    });

    test('이번 달 날짜가 지났으면 다음 달', () {
      final at = DateTime(2026, 8, 26);
      final next = CustomReminderService.nextInstance(
          r(ReminderFrequency.monthly, date: DateTime(2026, 1, 25)),
          from: at);
      expect(next, DateTime(2026, 9, 25, 9, 0));
    });

    test('12월이면 해를 넘긴다', () {
      final at = DateTime(2026, 12, 26);
      final next = CustomReminderService.nextInstance(
          r(ReminderFrequency.monthly, date: DateTime(2026, 1, 25)),
          from: at);
      expect(next, DateTime(2027, 1, 25, 9, 0));
    });

    test('29~31일로 잡아도 없는 날짜를 만들지 않는다', () {
      // 2월에 31일은 없다. 28일로 눌러 모든 달에 존재하게 한다.
      for (final day in [29, 30, 31]) {
        final next = CustomReminderService.nextInstance(
            r(ReminderFrequency.monthly, date: DateTime(2026, 1, day)),
            from: DateTime(2026, 2, 1));
        expect(next, DateTime(2026, 2, 28, 9, 0),
            reason: '$day일 설정이 2월에 없는 날짜로 넘어갔다');
      }
    });
  });

  test('한 번짜리는 지정한 그 시각 그대로', () {
    final one = r(ReminderFrequency.once, date: DateTime(2026, 3, 2), hour: 14, minute: 30);
    expect(CustomReminderService.nextInstance(one, from: DateTime(2026, 8, 15)),
        DateTime(2026, 3, 2, 14, 30));
  });

  test('어떤 주기든 지나간 시각을 주지 않는다', () {
    final at = DateTime(2026, 8, 15, 9, 0);
    for (final f in [
      ReminderFrequency.daily,
      ReminderFrequency.weekly,
      ReminderFrequency.monthly,
    ]) {
      final next = CustomReminderService.nextInstance(r(f), from: at);
      expect(next.isAfter(at), isTrue, reason: '$f가 지나간 시각을 돌려줬다');
    }
  });
}
