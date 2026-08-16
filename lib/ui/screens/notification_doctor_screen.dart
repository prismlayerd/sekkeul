import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/security/notification_helper.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

/// 알림이 안 울릴 때 **어디서 막혔는지** 보는 화면.
///
/// 홈의 알림함은 증거가 못 된다 — 거기는 앱을 열 때마다 "이 시각에 울렸어야
/// 한다"를 역산해 채우는 곳이라, OS가 실제로 띄웠는지와 무관하게 쌓인다
/// (`notification_history.dart`).
///
/// 막히는 자리는 넷이다: 플러그인 · 알림 권한 · 정확 알람 권한 · 예약.
/// **모르는 것은 모른다고 적는다** — 예전에는 못 읽으면 "허용"으로 적어서,
/// 권한이 정상인데 안 오는 것처럼 보였다.
class NotificationDoctorScreen extends StatefulWidget {
  const NotificationDoctorScreen({super.key});

  @override
  State<NotificationDoctorScreen> createState() => _NotificationDoctorScreenState();
}

class _NotificationDoctorScreenState extends State<NotificationDoctorScreen> {
  bool _loading = true;
  bool _alive = false;
  bool? _notifOk;
  bool? _exactOk;
  List<PendingNotificationRequest> _pending = const [];
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final alive = await notificationHelper.pluginAlive();
    final notif = await notificationHelper.notificationsAllowed();
    final exact = await notificationHelper.exactAlarmsAllowed();
    final pending = await notificationHelper.pending();
    if (!mounted) return;
    setState(() {
      _alive = alive;
      _notifOk = notif;
      _exactOk = exact;
      _pending = pending;
      _loading = false;
    });
  }

  /// 테스트 두 발을 보내고, **예약이 실제로 잡혔는지까지** 확인한다.
  ///
  /// 보내는 것만으로는 모른다 — 플러그인이 죽어 있으면 조용히 아무 일도
  /// 안 일어나고, 예전 코드는 그걸 삼켰다. 10초 예약이 대기 목록에 들어갔는지
  /// 되짚어야 "예약까지는 됐다"를 말할 수 있다.
  Future<void> _sendTest() async {
    final before = notificationHelper.failures.length;
    await notificationHelper.sendTestNotifications();
    final pending = await notificationHelper.pending();
    final queued = pending.any((p) => p.id == 9002);
    final newFailures = notificationHelper.failures.length - before;

    if (!mounted) return;
    setState(() {
      _testResult = newFailures > 0
          ? '보내는 중에 실패가 $newFailures건 났어요. 아래 「최근 실패」를 봐주세요.'
          : queued
              ? '보냈고 10초 예약도 잡혔어요. 이제 화면에 뜨는지만 보면 됩니다.'
              : '보냈는데 **예약이 안 잡혔어요.** 알림 자체가 막혀 있습니다.';
    });
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

                  AppTheme.sectionHead(context, '01', '기본'),
                  const SizedBox(height: 10),
                  _row('알림 기능 자체', _alive,
                      note: _alive ? null : '앱 알림 모듈이 응답하지 않아요 — 이게 꺼져 있으면 아래는 다 의미 없어요'),
                  AppTheme.hairline(context),
                  _row('알림 표시 권한', _notifOk,
                      onFix: _notifOk == true ? null : notificationHelper.requestPermissions),
                  AppTheme.hairline(context),
                  // **안 켜도 된다.** 켜야 하는 것처럼 보이면 안 되는 자리다.
                  _row('정확한 시각 알람 (선택)', _exactOk,
                      onFix: _exactOk == true ? null : notificationHelper.requestExactAlarms,
                      note: _exactOk == true
                          ? '정한 시각에 분 단위로 울려요'
                          : '꺼져 있어도 울려요 — 켜면 몇 분 오차가 없어집니다'),
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
                    // **전부** 보여준다. 예전에는 20건에서 잘라서, 28건 중 8건이
                    // 사라진 것처럼 보였다. 그리고 제목만 찍으니 자동차세
                    // 연납(1·3·6·9월)처럼 제목이 같은 것들이 중복으로 보였다 —
                    // 본문까지 보여줘야 서로 다른 항목인 게 드러난다.
                    for (final p in (_pending.toList()
                      ..sort((a, b) => a.id.compareTo(b.id))))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 46,
                              child: Text('${p.id}',
                                  style: AppTheme.sans(AppTheme.tsXS, sub)),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.title ?? '(제목 없음)',
                                      style: AppTheme.sans(AppTheme.tsSM, ink)),
                                  if ((p.body ?? '').trim().isNotEmpty)
                                    Text(p.body!,
                                        style: AppTheme.sans(AppTheme.tsXS, sub)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],

                  const SizedBox(height: 22),
                  AppTheme.sectionHead(context, '03', '테스트'),
                  const SizedBox(height: 10),
                  Text(
                    '두 발을 보냅니다 — 지금 하나, 10초 뒤 하나.\n'
                    '· 둘 다 안 오면 → 권한이나 방해금지(상단바 ⊘)\n'
                    '· 즉시만 오면 → 예약이 막힌 것, 기기 절전 설정을 보세요\n'
                    '· 소리 없이 상단 줄에만 뜨면 → 채널 중요도가 낮아진 것\n'
                    '\n'
                    '「정확한 시각 알람」은 안 켜도 됩니다 — 몇 분 오차가 생길 뿐이에요.'
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
                  if (_testResult != null) ...[
                    const SizedBox(height: 10),
                    Text(_testResult!.keepWords,
                        style: AppTheme.sans(AppTheme.tsSM, ink, height: 1.5)),
                  ],

                  if (notificationHelper.failures.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    AppTheme.sectionHead(context, '04', '최근 실패'),
                    const SizedBox(height: 10),
                    // 예전에는 이 실패들이 전부 logcat으로만 갔다 — 기기에서는
                    // 아무 데도 안 보여서, 무엇이 막혔는지 알 길이 없었다.
                    for (final f in notificationHelper.failures.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(f,
                            style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.4)),
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  /// 한 줄. [ok]가 null이면 **모른다**고 적는다.
  Widget _row(String label, bool? ok, {VoidCallback? onFix, String? note}) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final (text, color) = switch (ok) {
      true => ('허용', AppTheme.colorSuccess),
      false => ('차단', AppTheme.colorDanger),
      null => ('모름', AppTheme.colorWarning),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 색을 못 쓰는 체계라 상태는 글자로도 말한다.
          SizedBox(
            width: 34,
            child: Text(text,
                style: AppTheme.sans(AppTheme.tsSM, color, weight: FontWeight.w700)),
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
