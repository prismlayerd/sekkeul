import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/security/notification_helper.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

/// 알림이 안 울릴 때 **어디서 막혔는지** 보는 화면.
///
/// 홈의 알림함은 증거가 못 된다 — 거기는 앱을 열 때마다 "이 시각에 울렸어야
/// 한다"를 역산해 채우는 곳이라, OS가 실제로 띄웠는지와 무관하게 쌓인다
/// (`notification_history.dart`). 그래서 진짜 상태를 보는 자리를 따로 둔다.
///
/// 막히는 자리는 셋뿐이다: 알림 권한 · 정확 알람 권한 · 예약 자체.
/// 아래 세 줄이 그 셋을 그대로 보여주고, 테스트 두 발로 어디인지 가른다.
class NotificationDoctorScreen extends StatefulWidget {
  const NotificationDoctorScreen({super.key});

  @override
  State<NotificationDoctorScreen> createState() => _NotificationDoctorScreenState();
}

class _NotificationDoctorScreenState extends State<NotificationDoctorScreen> {
  bool _loading = true;
  bool _notifOk = false;
  bool _exactOk = false;
  List<PendingNotificationRequest> _pending = const [];
  String? _testedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notif = await notificationHelper.notificationsAllowed();
    final exact = await notificationHelper.exactAlarmsAllowed();
    final pending = await notificationHelper.pending();
    if (!mounted) return;
    setState(() {
      _notifOk = notif;
      _exactOk = exact;
      _pending = pending;
      _loading = false;
    });
  }

  Future<void> _sendTest() async {
    await notificationHelper.sendTestNotifications();
    if (!mounted) return;
    final now = TimeOfDay.now();
    setState(() => _testedAt =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);

    return Scaffold(
      appBar: AppBar(title: const Text('알림 점검')),
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text('알림이 안 오면 여기서 어디가 막혔는지 봅니다.'.keepWords,
                      style: AppTheme.sans(AppTheme.tsSM, sub)),
                  const SizedBox(height: 18),

                  AppTheme.sectionHead(context, '01', '권한'),
                  const SizedBox(height: 10),
                  _check('알림 표시', _notifOk,
                      onFix: _notifOk ? null : notificationHelper.requestPermissions),
                  AppTheme.hairline(context),
                  _check('정확한 시각 알람', _exactOk,
                      onFix: _exactOk ? null : notificationHelper.requestExactAlarms,
                      note: '꺼져 있으면 예약은 되지만 늦게 울려요'),
                  AppTheme.hairline(context),

                  const SizedBox(height: 22),
                  AppTheme.sectionHead(context, '02', '예약된 알림'),
                  const SizedBox(height: 10),
                  if (_pending.isEmpty)
                    Text('없음 — 리마인더를 켰는데도 0건이면 예약 자체가 실패한 거예요.'.keepWords,
                        style: AppTheme.sans(AppTheme.tsSM, sub))
                  else ...[
                    Text('${_pending.length}건',
                        style: AppTheme.display(AppTheme.serifLG, ink)),
                    const SizedBox(height: 8),
                    for (final p in _pending.take(20))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          SizedBox(
                            width: 56,
                            child: Text('${p.id}',
                                style: AppTheme.sans(AppTheme.tsSM, sub)),
                          ),
                          Expanded(
                            child: Text(p.title ?? '(제목 없음)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(AppTheme.tsSM, ink)),
                          ),
                        ]),
                      ),
                  ],

                  const SizedBox(height: 22),
                  AppTheme.sectionHead(context, '03', '테스트'),
                  const SizedBox(height: 10),
                  Text(
                    '두 발을 보냅니다 — 지금 하나, 10초 뒤 하나.\n'
                    '· 둘 다 안 오면 → 권한이나 방해금지 문제\n'
                    '· 즉시만 오면 → 예약(알람)이 막힌 것, 기기 절전 설정을 보세요\n'
                    '· 둘 다 오면 → 알림은 살아 있고 리마인더 설정 쪽 문제'
                        .keepWords,
                    style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.6),
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _sendTest,
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        color: ink,
                        child: Text('테스트 알림 보내기',
                            style: AppTheme.sans(AppTheme.tsBase,
                                AppTheme.backgroundColor(context),
                                weight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  if (_testedAt != null) ...[
                    const SizedBox(height: 8),
                    Text('$_testedAt에 보냈어요.',
                        style: AppTheme.sans(AppTheme.tsSM, sub)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _check(String label, bool ok, {VoidCallback? onFix, String? note}) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 색을 못 쓰니 상태는 글자로 말한다.
          SizedBox(
            width: 30,
            child: Text(ok ? '허용' : '차단',
                style: AppTheme.sans(AppTheme.tsSM,
                    ok ? AppTheme.colorSuccess : AppTheme.colorDanger,
                    weight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.sans(AppTheme.tsBase, ink)),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note.keepWords, style: AppTheme.sans(AppTheme.tsSM, sub)),
                ],
              ],
            ),
          ),
          if (onFix != null)
            Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  onFix();
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                  await _load();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('켜기',
                      style: AppTheme.sans(AppTheme.tsSM, ink,
                          weight: FontWeight.w700,
                          decoration: TextDecoration.underline)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
