import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../core/notifications/system_reminder_catalog.dart';
import '../../core/notifications/reminder_scheduler.dart';
import '../../core/notifications/news_alerts.dart';
import '../../core/data/remote_notices.dart';
import '../../core/security/notification_helper.dart';
import '../../core/data/db_helper.dart';
import 'reminder_list_screen.dart';

/// 어느 장의 알림을 다루나 — 홈 1장(소식·정보)과 2장(가계부)이 각자 설정을 갖는다.
/// [all]은 전체 탭 설정에서 오는 길이라 둘 다 보인다.
enum NotifScope { all, news, ledger }

/// 알림 설정 — **큰 버튼 몇 개.** 항목별로 켜고 끄지 않는다.
///
/// 누구에게 무엇이 가는지는 앱이 내 정보로 거른다([UserFacts]). 사용자는
/// 종류만 고른다 — 알림이 서른 개 넘게 늘어나니 항목별 토글은 아무도 못 다뤘다.
class NotificationSettingsScreen extends StatefulWidget {
  final String userType;
  final NotifScope scope;
  const NotificationSettingsScreen(
      {super.key, required this.userType, this.scope = NotifScope.all});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

/// 버튼 하나가 묶는 알림. 카탈로그 전체에서 고른다 — 내 정보가 바뀌어
/// 새로 해당되는 알림도 같은 버튼 설정을 따르게.
typedef _Bucket = ({String title, String desc, NotifScope scope, bool Function(SystemReminder) has});

final List<_Bucket> _buckets = [
  (
    title: '혜택·생활 정보',
    desc: '자동차세·에너지바우처·청년 제도처럼 놓치기 쉬운 정부 일정',
    scope: NotifScope.news,
    has: (s) => s.category == SysCategory.deadline && s.topCategory != '세금 일정',
  ),
  (
    title: '세금 일정',
    desc: '신고·납부 기한과 연말정산',
    scope: NotifScope.ledger,
    has: (s) => s.category == SysCategory.deadline && s.topCategory == '세금 일정',
  ),
  (
    title: '내 기록 알림',
    desc: '가계부 기록이 공제 문턱을 넘었을 때',
    scope: NotifScope.ledger,
    has: (s) => s.category == SysCategory.moment,
  ),
];

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  Map<String, bool> _settings = {};
  UserFacts _facts = const UserFacts();
  List<Notice> _news = const [];
  bool _loading = true;

  bool _shows(NotifScope s) => widget.scope == NotifScope.all || widget.scope == s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await dbService.getReminderSettings();
    final facts = await UserFacts.load();
    final news = await RemoteNotices.load();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _facts = facts;
      _news = news;
      _loading = false;
    });
  }

  Future<void> _toggle(_Bucket b, bool v) async {
    if (v && !kIsWeb) await notificationHelper.ensurePermissionIfNeeded();
    for (final s in kSystemReminderCatalog.where(b.has)) {
      await dbService.setReminderSetting(s.key, v);
    }
    if (!kIsWeb) await ReminderScheduler.scheduleTaxSeason(widget.userType);
    await _load();
  }

  Future<void> _toggleNews(bool v) async {
    if (v && !kIsWeb) await notificationHelper.ensurePermissionIfNeeded();
    await dbService.setReminderSetting(NewsAlerts.settingKey, v);
    if (!kIsWeb) await NewsAlerts.sync(_news, _facts);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final nudge = missingFactsLine(kSystemReminderCatalog
        .where((s) => _buckets.any((b) => _shows(b.scope) && b.has(s)))
        .expand((s) => s.target.missing(_facts)));
    final (title, intro) = switch (widget.scope) {
      NotifScope.news => ('소식·정보 알림', '홈 첫 장(혜택·알림)에 뜨는 소식과 정부 일정이에요. 내 정보에 맞는 것만 보내요.'),
      NotifScope.ledger => ('가계부 알림', '홈 둘째 장(가계부)과 관련된 알림이에요. 내 정보에 맞는 것만 보내요.'),
      NotifScope.all => ('알림 설정', '내 정보에 맞는 알림만 골라 보내요.'),
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '뒤로',
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppTheme.inkSecondary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(title,
            style: AppTheme.sans(AppTheme.tsLG, ink, weight: FontWeight.w700)),
      ),
      body: SafeArea(child: _loading
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(intro,
                      style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.5)),
                ),
                if (_shows(NotifScope.news)) _newsRow(),
                for (final b in _buckets)
                  if (_shows(b.scope)) _bucketRow(b),
                if (_shows(NotifScope.ledger)) _linkRow(),
                if (nudge != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(nudge,
                        style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.5)),
                  ),
              ],
            )),
    );
  }

  /// 소식 마감 알림 — 신청 기간이 있는 소식을 마감 3일 전 아침에 알린다.
  Widget _newsRow() {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final on = _settings[NewsAlerts.settingKey] ?? true;
    final mine = NewsAlerts.due(_news, _facts, DateTime.now());
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('소식 마감 알림',
                  style: AppTheme.sans(AppTheme.tsBase, on ? ink : tert, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('신청 기간이 있는 소식은 마감 ${NewsAlerts.leadDays}일 전 아침에 알려요',
                  style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.4)),
              const SizedBox(height: 2),
              Text(mine.isEmpty ? '지금 나에게 해당하는 마감 소식 없음' : '지금 ${mine.length}건 · ${mine.map((e) => e.$1.label).toSet().join(' · ')}',
                  style: AppTheme.sans(AppTheme.tsXS, on ? accent : tert, weight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 8),
          Switch(
            value: on,
            activeThumbColor: accent,
            onChanged: kIsWeb ? null : _toggleNews,
          ),
        ]),
      ),
      AppTheme.hairline(context),
    ]);
  }

  Widget _bucketRow(_Bucket b) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final mine = {
      for (final s in kSystemReminderCatalog)
        if (b.has(s) && s.appliesTo(_facts)) kGroupLabels[s.group] ?? s.title,
    };
    final all = kSystemReminderCatalog.where(b.has);
    final on = all.every((s) => _settings[s.key] ?? true);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title,
                        style: AppTheme.sans(AppTheme.tsBase, on ? ink : tert,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(b.desc, style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.4)),
                    const SizedBox(height: 2),
                    Text(mine.isEmpty ? '지금 나에게 해당하는 알림 없음' : mine.join(' · '),
                        style: AppTheme.sans(AppTheme.tsXS, on ? accent : tert,
                            weight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: on,
                activeThumbColor: accent,
                onChanged: kIsWeb ? null : (v) => _toggle(b, v),
              ),
            ],
          ),
        ),
        AppTheme.hairline(context),
      ],
    );
  }

  Widget _linkRow() {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ReminderListScreen(userType: widget.userType))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('내 리마인더 관리',
                      style: AppTheme.sans(AppTheme.tsBase, ink, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('직접 만든 알림과 가계부 기록 알림',
                      style: AppTheme.sans(AppTheme.tsXS, tert)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: tert),
            ]),
          ),
          AppTheme.hairline(context),
        ],
      ),
    );
  }
}
