import 'package:flutter/material.dart';

import '../../../core/data/db_helper.dart';
import '../../../core/data/remote_notices.dart';
import '../../../core/notifications/system_reminder_catalog.dart';
import 'home_banner_carousel.dart' show BannerCardData;
import '../../theme/app_theme.dart';
import '../notice_detail_screen.dart';
import '../notification_settings_screen.dart';

/// 홈 1장의 `01 · 소식 · 알림` — 새 소식과 세금이 아닌 정부 일정(교통·에너지, 일자리·행정).
///
/// 세금 일정과 직접 만든 리마인더는 2장(가계부)이 맡는다. 소식은 내게 맞는 것을 최신순
/// 넷, 일정은 켜 둔 것 중 다가오는 순으로 셋. 켜고 끄는 건 이 장 전용 알림 설정에서 한다.
class InfoAlertsSection extends StatefulWidget {
  final String userType;
  final UserFacts facts;
  final VoidCallback? onFillProfile; // 권유 줄을 누르면 내 정보로
  final List<Notice> notices; // 내 유형·지역·조건에 걸려 뜬 소식(홈이 이미 거른 것)
  final List<BannerCardData> guides; // 내 유형에 맞는 안내
  final int allCount; // 혜택 탭 「맞춤 혜택」에 쌓인 전체 건수(공통 소식 포함)
  final VoidCallback? onOpenBenefits;
  const InfoAlertsSection(
      {super.key,
      required this.userType,
      this.facts = const UserFacts(),
      this.onFillProfile,
      this.notices = const [],
      this.guides = const [],
      this.allCount = 0,
      this.onOpenBenefits});

  /// 홈에는 최신 둘만 — 나머지는 혜택 탭 「맞춤 혜택」.
  static const homeLimit = 2;

  /// 정부 일정은 이 안으로 다가온 것만 홈에 올린다. 내년 날짜까지 D-300으로 띄우지 않는다.
  static const alertWindowDays = 30;

  @override
  State<InfoAlertsSection> createState() => _InfoAlertsSectionState();
}

class _InfoAlertsSectionState extends State<InfoAlertsSection> {
  List<(SystemReminder, DateTime)> _upcoming = [];
  String? _nudge;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(InfoAlertsSection old) {
    super.didUpdateWidget(old);
    if (old.userType != widget.userType || old.facts != widget.facts) _load();
  }

  Future<void> _load() async {
    final settings = await dbService.getReminderSettings();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final info = kSystemReminderCatalog.where((s) =>
        s.topCategory != '세금 일정' && !s.isEvent && (settings[s.key] ?? true));
    final list = [
      for (final s in info)
        if (s.appliesTo(widget.facts)) (s, _next(s, today)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    // 모르는 칸 때문에 숨은 것 — 무엇을 채우면 보이는지 한 줄로.
    final nudge = missingFactsLine(info.expand((s) => s.target.missing(widget.facts)));
    if (mounted) {
      setState(() {
        _upcoming = list.take(3).toList();
        _nudge = nudge;
      });
    }
  }

  static DateTime _next(SystemReminder s, DateTime today) {
    final d = DateTime(today.year, s.month!, s.day!);
    return d.isBefore(today) ? DateTime(today.year + 1, s.month!, s.day!) : d;
  }

  Future<void> _openSettings() async {
    await Navigator.push(context,
        MaterialPageRoute(
            builder: (_) =>
                NotificationSettingsScreen(userType: widget.userType, scope: NotifScope.news)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final tert = AppTheme.inkTertiary(context);
    final now = DateTime.now();
    final t0 = DateTime(now.year, now.month, now.day);
    // **최신 것 둘만.** 소식(올라온 지 일주일 안, 안 끝난 것) → 곧 다가오는 일정 → 유형 안내 순으로
    // 채운다. 오래됐거나 끝난 소식은 홈에 안 남기고 「맞춤 혜택」에서 본다.
    final rows = <Widget>[
      for (final n in widget.notices)
        if (n.isFresh(now) && !n.isEnded(now)) _newsRow(n),
      for (final (s, on) in _upcoming)
        if (on.difference(t0).inDays <= InfoAlertsSection.alertWindowDays) _alertRow(s, on, t0),
      for (final g in widget.guides) _guideRow(g),
    ].take(InfoAlertsSection.homeLimit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: AppTheme.sectionHead(context, '01', '소식 · 알림')),
          GestureDetector(
            onTap: _openSettings,
            child: Text('알림 설정',
                style: AppTheme.sans(AppTheme.tsSM, AppTheme.accentColor(context),
                    weight: FontWeight.w700, decoration: TextDecoration.underline)),
          ),
        ]),
        const SizedBox(height: 4),
        if (rows.isEmpty && _nudge == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('새 소식이 없어요.',
                style: AppTheme.sans(AppTheme.tsSM, tert, height: 1.5)),
          ),
        ...rows,
        if (widget.allCount > 0 && widget.onOpenBenefits != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onOpenBenefits,
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text('지난 소식까지 맞춤 혜택 ${widget.allCount}건 보기  ›',
                  style: AppTheme.sans(AppTheme.tsSM, AppTheme.accentColor(context),
                      weight: FontWeight.w700)),
            ),
          ),
        if (_nudge != null)
          GestureDetector(
            onTap: widget.onFillProfile,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('$_nudge  ›',
                  style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.5)),
            ),
          ),
      ],
    );
  }

  /// 다가오는 정부 일정 한 줄 — D-n, 제목, 날짜와 한 줄 설명.
  Widget _alertRow(SystemReminder s, DateTime on, DateTime t0) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        SizedBox(
          width: 54,
          child: Text(on == t0 ? 'D-DAY' : 'D-${on.difference(t0).inDays}',
              style: AppTheme.serif(AppTheme.tsBase, ink,
                  weight: FontWeight.w700, spacing: -0.5, height: 1.0)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(AppTheme.tsSM, ink, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${on.month}월 ${on.day}일 · ${s.body}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(AppTheme.tsXS, tert)),
          ]),
        ),
      ]),
    );
  }

  /// 소식 한 줄 — 라벨·마감, 제목, 요약 두 줄. 눌러야 기사가 열린다.
  Widget _newsRow(Notice n) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final when = n.dueLabel(DateTime.now());
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: n))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${n.label} · $when', style: AppTheme.sans(AppTheme.tsXS, tert)),
          const SizedBox(height: 3),
          Text(n.title.replaceAll('\n', ' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(AppTheme.tsBase, ink, weight: FontWeight.w700, height: 1.35)),
          if (n.summary.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(n.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.45)),
          ],
        ]),
      ),
    );
  }

  /// 유형 안내 한 줄 — 라벨, 제목, 이어서 할 일. 카드 전체가 눌린다.
  Widget _guideRow(BannerCardData g) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: g.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(g.label, style: AppTheme.sans(AppTheme.tsXS, tert)),
          const SizedBox(height: 3),
          Text(g.headline.replaceAll('\n', ' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(AppTheme.tsBase, ink, weight: FontWeight.w700, height: 1.35)),
          if (g.action.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text('${g.action}  ›',
                style: AppTheme.sans(AppTheme.tsSM, AppTheme.accentColor(context),
                    weight: FontWeight.w600)),
          ],
        ]),
      ),
    );
  }
}
