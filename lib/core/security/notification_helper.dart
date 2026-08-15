import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import '../data/db_helper.dart';

class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS — 초기화 시점에 알림 권한 요청 (버전 안전)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    await _createChannels();
  }

  // ── 알림 채널 ──────────────────────────────────────────────────────
  //
  // 안드로이드 8부터 **채널이 알림의 성격을 정한다.** 소리를 낼지, 화면 위로
  // 배너를 띄울지(헤드업), 잠금화면에 보일지 전부 채널에 달렸다. 코드의
  // importance는 채널을 **만들 때 한 번만** 반영되고, 그 뒤로는 사용자
  // 설정에만 따른다 — 값을 고쳐도 이미 만들어진 채널에는 안 먹는다.
  //
  // 그래서 두 가지를 한다.
  // 1) 첫 알림을 기다리지 않고 **켤 때 미리** 만든다. 예전에는 플러그인이
  //    첫 발화 때 알아서 만들게 뒀는데, 그러면 어떤 성격으로 만들어졌는지
  //    확인할 방법이 없었다.
  // 2) 성격을 바꿀 때는 **id를 올린다**(v2 → v3). 안 올리면 옛 채널이 그대로
  //    남아 조용한 알림이 계속 나간다.
  static const String reminderChannelId = 'sekkeul_reminder_v3';
  static const String nudgeChannelId = 'sekkeul_nudge_v3';

  Future<void> _createChannels() async {
    final android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      for (final c in const [
        AndroidNotificationChannel(
          reminderChannelId,
          '리마인더',
          description: '신고 기한·가계부 기록 등 내가 정한 알림',
          importance: Importance.max, // 화면 위 배너 + 소리
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          nudgeChannelId,
          '절세 안내',
          description: '공제 문턱 도달·지출 목표 초과 등 상황 알림',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      ]) {
        await android.createNotificationChannel(c);
      }
    } catch (e) {
      debugPrint('알림 채널을 못 만들었다: $e');
    }
  }

  /// 채널 밖에서 매번 같이 넘기는 표시 설정.
  ///
  /// 채널이 성격을 정하지만, 잠금화면 공개 범위와 분류는 알림마다 준다.
  static AndroidNotificationDetails _android(String channelId, String channelName,
          {required String body}) =>
      AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        // 잠금화면에도 내용을 보여준다 — 가릴 만한 개인정보를 담지 않는다.
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
        // 긴 문구가 배너에서 잘리지 않게 펼침 형태를 같이 준다.
        // 본문이 없는 알림(리마인더는 제목만 있다)에 붙이면 빈 줄이 생긴다.
        styleInformation:
            body.trim().isEmpty ? null : BigTextStyleInformation(body),
      );

  Future<void> requestPermissions() async {
    // Android 13+ 알림 표시 권한만 요청(정확 알람은 사용하지 않음).
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
    // iOS 권한은 init의 DarwinInitializationSettings에서 요청됨
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? logCategory,
  }) async {
    try {
      await dbService.insertNotificationLog(title: title, body: body, category: logCategory);
    } catch (_) {
      // 기록에 실패해도 알림은 띄운다 — 알림이 본체고 기록은 부산물이다.
    }
    final platformChannelSpecifics = NotificationDetails(
      android: _android(nudgeChannelId, '절세 안내', body: body),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBanner: true,
      ),
    );

    // 즉시 알림도 홈에서 await 없이 던져진다(문턱 돌파·예산 초과 안내).
    // 여기서 안 막으면 처리되지 않은 비동기 예외가 된다.
    try {
      await flutterLocalNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('즉시 알림 표시 실패($id): $e');
    }
  }

  Future<void> scheduleNotification({required int id, required String title, required String body, required Duration delay}) async {
    await scheduleAtDate(
      id: id,
      title: title,
      body: body,
      when: tz.TZDateTime.now(tz.local).add(delay),
    );
  }

  /// 절대 시각 예약. [matchComponents]를 주면 매월·매일 반복.
  Future<void> scheduleAtDate({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    DateTimeComponents? matchComponents,
  }) async {
    final platformChannelSpecifics = NotificationDetails(
      android: _android(reminderChannelId, '리마인더', body: body),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBanner: true,
      ),
    );

    final tzWhen = when is tz.TZDateTime
        ? when
        : tz.TZDateTime.from(when, tz.local);

    // 정확 알람(exactAllowWhileIdle) — 정한 시각에 정확히 발화(Doze 무시).
    // USE_EXACT_ALARM이 자동 부여되므로 사용자가 설정을 바꿀 필요가 없다.
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzWhen,
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
      );
    } catch (e) {
      // 단말이 정확 알람을 거부하는 드문 경우 — 비정확으로라도 예약(크래시 방지). 원인은 로깅.
      debugPrint('정확 알람 예약 실패 → 비정확 폴백: $e');
      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzWhen,
          notificationDetails: platformChannelSpecifics,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchComponents,
        );
      } catch (e2) {
        // 폴백까지 실패해도 화면은 그대로 떠야 한다. 홈은 이 예약들을 await 없이
        // 던져 두므로(fire-and-forget), 여기서 안 막으면 처리되지 않은 비동기 예외가 된다.
        debugPrint('비정확 알람 예약도 실패: $e2');
      }
    }
  }

  /// 현재 예약 대기 중인 알림 개수(진단용).
  Future<int> pendingCount() async {
    final p = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    return p.length;
  }

  /// 진단용 알림 두 발. 어디서 막혔는지 이 둘로 갈린다.
  ///
  /// * 즉시 알림도 안 뜬다 → 알림 **권한**이나 방해금지 문제다.
  /// * 즉시는 뜨는데 10초 뒤 것이 안 뜬다 → **예약(알람)** 쪽 문제다.
  ///   기기 절전이 알람을 죽이는 경우가 대부분이다.
  ///
  /// 예약 id는 리마인더(2000번대)·세무일정(1001~)과 겹치지 않게 9000번대를 쓴다.
  static const int _testNowId = 9001;
  static const int _testLaterId = 9002;

  Future<void> sendTestNotifications() async {
    await showImmediateNotification(
      id: _testNowId,
      title: '테스트 · 즉시 알림',
      body: '이게 보이면 알림 권한은 켜져 있어요.',
      logCategory: 'test',
    );
    await scheduleAtDate(
      id: _testLaterId,
      title: '테스트 · 10초 예약',
      body: '이게 보이면 예약 알림도 살아 있어요.',
      when: DateTime.now().add(const Duration(seconds: 10)),
    );
  }

  /// 알림 표시 권한(POST_NOTIFICATIONS) 허용 여부.
  Future<bool> notificationsAllowed() async {
    final android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final ok = await android.areNotificationsEnabled();
    return ok ?? true;
  }

  /// 알림 토글을 켤 때 호출 — OS 권한이 꺼져 있으면 시스템 허용 요청을 띄운다.
  Future<void> ensurePermissionIfNeeded() async {
    if (!await notificationsAllowed()) {
      await requestPermissions();
    }
  }

  /// 정확한 시각에 알람을 걸 수 있는가(API 31+). 꺼져 있으면 예약은 되지만
  /// 몇 분~몇십 분 늦게 울린다 — "안 울린다"로 체감되는 자리다.
  Future<bool> exactAlarmsAllowed() async {
    final android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    try {
      return await android.canScheduleExactNotifications() ?? true;
    } catch (e) {
      debugPrint('정확 알람 가능 여부를 못 읽었다: $e');
      return true;
    }
  }

  /// 정확 알람 허용 화면을 띄운다(사용자가 직접 켜야 하는 시스템 설정).
  Future<void> requestExactAlarms() async {
    final android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      await android.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('정확 알람 요청 실패: $e');
    }
  }

  /// 지금 잡혀 있는 예약들. 진단 화면이 "몇 건이 언제 울리기로 되어 있는지"를
  /// 그대로 보여준다 — 알림함은 **울렸을 것**을 역산해 적는 곳이라 증거가 못 된다.
  Future<List<PendingNotificationRequest>> pending() async {
    try {
      return await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('예약 목록을 못 읽었다: $e');
      return const [];
    }
  }

  // 취소도 실패할 수 있다(플러그인 미초기화 등). 홈이 넛지 취소를 await 없이
  // 부르므로 여기서 막지 않으면 처리되지 않은 비동기 예외가 된다 — 값은 이미
  // setState로 그려진 뒤라 화면은 멀쩡한데 예외만 남는다.
  Future<void> cancel(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('알림 취소 실패($id): $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('알림 전체 취소 실패: $e');
    }
  }
}

final notificationHelper = NotificationHelper();
