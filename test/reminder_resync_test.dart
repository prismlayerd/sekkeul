import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/notifications/custom_reminder_service.dart';
import 'package:secul/core/notifications/reminder.dart';

/// **앱을 켤 때 예약을 다시 건다.**
///
/// 예약은 리마인더를 만들거나 켤 때 한 번만 걸었다. 안드로이드의 알람은 앱을
/// 업데이트하거나 강제 종료하면 날아가는데, 그러면 목록에는 켜짐으로 남은 채
/// 영영 안 울린다 — "리마인더가 전혀 안 울린다"는 제보의 한 갈래다.
void main() {
  setUp(() async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
  });

  test('notifId가 없던 옛 기록에도 번호를 붙여 준다', () async {
    // 번호가 없으면 _schedule이 첫 줄에서 그냥 돌아간다 — 조용히 안 걸린다.
    final id = await dbService.insertReminder(Reminder(
      title: '밥먹어',
      frequency: ReminderFrequency.daily,
      notifyDate: DateTime(2026, 8, 16),
      notifyHour: 17,
      notifyMinute: 20,
    ).toMap());
    expect(id, greaterThan(0));

    var saved = (await customReminderService.list()).single;
    expect(saved.notifId, isNull, reason: '이 테스트의 전제가 깨졌다');

    await customReminderService.resyncAll();

    saved = (await customReminderService.list()).single;
    expect(saved.notifId, isNotNull, reason: '번호를 안 붙였다 — 예약이 안 걸린다');
  });

  test('꺼 둔 리마인더는 다시 걸지 않는다', () async {
    await dbService.insertReminder(Reminder(
      title: '꺼둠',
      frequency: ReminderFrequency.daily,
      notifyDate: DateTime(2026, 8, 16),
      enabled: false,
    ).toMap());

    await customReminderService.resyncAll();

    final saved = (await customReminderService.list()).single;
    expect(saved.enabled, isFalse);
    expect(saved.notifId, isNull, reason: '꺼 둔 것에 번호를 붙였다');
  });
}
