import '../data/db_helper.dart';
import '../data/remote_notices.dart';
import '../security/notification_helper.dart';

/// 소식 마감 알림 — 신청 기간이 있는 소식(`until`)을 마감 [leadDays]일 전 아침에 알린다.
///
/// 서버 푸시가 없는 오프라인 앱이라 "새 소식이 떴다"는 보낼 수 없다. 대신 앱이 소식을
/// 받을 때마다 **내게 맞는 마감 소식**을 로컬 예약으로 건다. 설정은 1장 「알림 설정」에서.
class NewsAlerts {
  static const settingKey = 'news_deadline';
  static const leadDays = 3;
  static const _hour = 9;
  static const _idBase = 3000; // 3000~3899 — 기존 알림 ID(1001~2200)와 겹치지 않는다

  /// 알림 ID는 소식 id에서 정해진다. 같은 소식은 늘 같은 ID라 다시 걸면 덮어쓴다.
  static int idFor(Notice n) => _idBase + n.id.codeUnits.fold(7, (h, c) => (h * 31 + c) % 900);

  /// 내게 맞고 아직 알릴 시각이 남은 마감 소식 → 알릴 시각.
  static List<(Notice, DateTime)> due(List<Notice> notices, UserFacts facts, DateTime now) => [
        for (final n in notices)
          if (!n.isApp && n.until != null && n.matches(facts) && !n.isExpired(now))
            if (_when(n).isAfter(now)) (n, _when(n)),
      ];

  static DateTime _when(Notice n) {
    final d = n.until!.subtract(const Duration(days: leadDays));
    return DateTime(d.year, d.month, d.day, _hour);
  }

  /// 꺼져 있으면 건 것을 모두 걷는다. 목록에서 아예 사라진 소식의 알람은 남는다 —
  /// ponytail: 소식은 until로 내리지 지우지 않는다. 지우는 일이 잦아지면 ID를 따로 저장.
  static Future<void> sync(List<Notice> notices, UserFacts facts) async {
    final on = (await dbService.getReminderSettings())[settingKey] ?? true;
    final wanted = on ? {for (final (n, w) in due(notices, facts, DateTime.now())) n.id: w} : <String, DateTime>{};
    for (final n in notices) {
      final when = wanted[n.id];
      if (when == null) {
        await notificationHelper.cancel(idFor(n));
      } else {
        await notificationHelper.scheduleAtDate(
          id: idFor(n),
          title: '${n.label} · 마감 $leadDays일 전',
          body: '${n.title.replaceAll('\n', ' ')} — ${n.until!.month}월 ${n.until!.day}일까지예요.',
          when: when,
        );
      }
    }
  }
}
