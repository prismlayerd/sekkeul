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
  }

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
    } catch (_) {}
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'tax_nudge_channel',
      '세금·절세 알림',
      channelDescription: '공제 문턱 도달 등 절세 가이드 알림',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
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
    // 알람처럼 화면 배너+소리로 뜨도록 max 중요도. 채널 중요도는 생성 후 고정이라
    // 새 채널 ID(_v2)로 바꿔 기존 조용한 채널을 대체한다.
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'sekkeul_reminder_v2',
      '리마인더',
      channelDescription: '신고 기한·가계부 기록 등 예약 알림',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(
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
