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

  /// 최근 실패들 — 화면에서 그대로 보여준다.
  ///
  /// 예전에는 알림이 실패하면 전부 `debugPrint`로 흘렸다. 기기에서는 logcat을
  /// 못 보니 **아무 데도 안 보인다.** "알림이 안 온다"는 제보를 세 번 받고도
  /// 무엇이 막혔는지 몰랐던 이유가 이것이다. 실패는 남겨야 고칠 수 있다.
  static const int _maxFailures = 20;
  final List<String> failures = [];

  void _fail(String what, Object e) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    failures.insert(0, '[$stamp] $what — $e');
    if (failures.length > _maxFailures) failures.removeLast();
    debugPrint('알림 실패 · $what — $e');
    // DB에도 남긴다 — 앱을 껐다 켜도 남아야 원인을 쫓을 수 있다.
    dbService.insertErrorLog('알림 실패 · $what', e.toString());
  }

  /// 안드로이드 구현체 — **가져오는 것 자체가 던질 수 있다.**
  ///
  /// 플러그인이 아직 안 붙었으면 resolvePlatformSpecificImplementation이
  /// LateInitializationError를 낸다. 예전에는 이 호출이 try 밖에 있어서, 정작
  /// 감싸 둔 try는 아무것도 못 막았다.
  AndroidFlutterLocalNotificationsPlugin? get _androidImpl {
    try {
      return flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    } catch (_) {
      return null;
    }
  }

  /// 플러그인 자체가 응답하는가.
  ///
  /// 네이티브 채널이 안 붙어 있으면 모든 호출이 MissingPluginException으로
  /// 죽는데, 예전 코드는 그걸 전부 삼켜서 "권한도 정상, 예약 0건"처럼 보였다.
  /// 멀쩡한 것과 죽은 것이 화면에서 똑같아 보이면 진단이 아니다.
  Future<bool> pluginAlive() async {
    try {
      await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      return true;
    } catch (e) {
      _fail('플러그인 응답 없음', e);
      return false;
    }
  }

  /// 예약 방식 판정도 절대 밖으로 던지지 않는다 — 홈 진입 경로에서 부른다.
  Future<AndroidScheduleMode> _safeMode() async {
    try {
      return await _scheduleMode();
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    // 알림 작은 아이콘은 **전용 드로어블**을 쓴다.
    //
    // `@mipmap/ic_launcher`는 API 26+에서 적응형 아이콘 XML로 풀리는데, 그건
    // 알림 작은 아이콘으로 쓸 수 없다 — 빈칸으로 뜨거나 기기에 따라 알림이
    // 아예 안 올라간다. 안드로이드는 작은 아이콘의 **알파 채널만** 보고 색은
    // 자기가 칠하므로, 흰 실루엣 + 투명 배경이어야 한다.
    // (design/make_icon_barcode.py의 notification()이 만든다.)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');

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
    final android = _androidImpl;
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
      _fail('채널 만들기', e);
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
        icon: '@drawable/ic_notification',
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
    final androidImplementation = _androidImpl;
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
      _fail('즉시 알림 표시(id $id)', e);
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

    // 정확 알람은 **있으면 쓰고 없으면 안 쓴다.**
    //
    // 예전에는 늘 정확(exactAllowWhileIdle)으로 먼저 걸고 거부당하면 비정확으로
    // 다시 걸었다. 그런데 SCHEDULE_EXACT_ALARM은 사용자가 설정에서 직접 켜야
    // 하는 권한이라 대개 꺼져 있다 — 예약할 때마다 exact_alarms_not_permitted가
    // 던져지고 그게 전부 "실패"로 쌓였다. 실제로는 비정확으로 잘 걸리고
    // 있었는데 기록만 새빨갰다.
    //
    // 리마인더에 분 단위 정확도는 필요 없다. 비정확 알람도 Doze를 뚫고 울리고
    // (inexactAllowWhileIdle), 기기를 쓰는 중이면 거의 정시에 온다. 정확 알람은
    // 사용자가 굳이 켜 줬을 때만 얹는 **덤**이다.
    final mode = await _safeMode();
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzWhen,
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: mode,
        matchDateTimeComponents: matchComponents,
      );
    } catch (e) {
      // 정확으로 걸려다 막혔으면 권한이 방금 바뀐 것 — 비정확으로 한 번 더.
      if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
        _exactAllowed = false;
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
          return;
        } catch (e2) {
          _fail('알람 예약(id $id)', e2);
          return;
        }
      }
      _fail('알람 예약(id $id)', e);
    }
  }

  /// 정확 알람을 쓸 수 있는지 — 한 번 물어보고 기억한다.
  /// 예약마다 물으면 앱을 켤 때 스물몇 번 왕복한다.
  bool? _exactAllowed;

  Future<AndroidScheduleMode> _scheduleMode() async {
    _exactAllowed ??= await exactAlarmsAllowed() ?? false;
    return _exactAllowed!
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// 사용자가 설정에서 정확 알람을 켜고 온 뒤 다시 물어보게 한다.
  void forgetExactAlarmAnswer() => _exactAllowed = null;

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

  /// 알림 표시 권한(POST_NOTIFICATIONS). **모르면 null**이다.
  ///
  /// 예전에는 못 읽으면 `true`를 돌려줬다. 그러면 진단 화면이 "허용"이라고
  /// 적어 놓고 알림은 안 오는, 가장 나쁜 상태가 된다.
  Future<bool?> notificationsAllowed() async {
    final android = _androidImpl;
    if (android == null) return null;
    try {
      return await android.areNotificationsEnabled();
    } catch (e) {
      _fail('알림 권한 확인', e);
      return null;
    }
  }

  /// 알림 토글을 켤 때 호출 — OS 권한이 꺼져 있으면 시스템 허용 요청을 띄운다.
  Future<void> ensurePermissionIfNeeded() async {
    // 모를 때(null)도 물어본다 — 안 물어보는 것보다 한 번 더 묻는 게 낫다.
    if (await notificationsAllowed() != true) {
      await requestPermissions();
    }
  }

  /// 정확한 시각에 알람을 걸 수 있는가(API 31+). 꺼져 있으면 예약은 되지만
  /// 몇 분~몇십 분 늦게 울린다 — "안 울린다"로 체감되는 자리다.
  Future<bool?> exactAlarmsAllowed() async {
    final android = _androidImpl;
    if (android == null) return null;
    try {
      return await android.canScheduleExactNotifications();
    } catch (e) {
      _fail('정확 알람 가능 여부 확인', e);
      return null;
    }
  }

  /// 정확 알람 허용 화면을 띄운다(사용자가 직접 켜야 하는 시스템 설정).
  Future<void> requestExactAlarms() async {
    final android = _androidImpl;
    if (android == null) return;
    try {
      await android.requestExactAlarmsPermission();
      forgetExactAlarmAnswer();
    } catch (e) {
      _fail('정확 알람 권한 요청', e);
    }
  }

  /// 지금 잡혀 있는 예약들. 진단 화면이 "몇 건이 언제 울리기로 되어 있는지"를
  /// 그대로 보여준다 — 알림함은 **울렸을 것**을 역산해 적는 곳이라 증거가 못 된다.
  Future<List<PendingNotificationRequest>> pending() async {
    try {
      return await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      _fail('예약 목록 읽기', e);
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
      _fail('알림 취소(id $id)', e);
    }
  }

  Future<void> cancelAll() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      _fail('알림 전체 취소', e);
    }
  }
}

final notificationHelper = NotificationHelper();
