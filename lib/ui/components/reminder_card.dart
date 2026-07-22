import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../core/notifications/reminder.dart';
import '../../core/notifications/custom_reminder_service.dart';
import '../../core/navigation/app_route_observer.dart';
import '../screens/reminder_list_screen.dart';

/// 홈 — 사용자 맞춤 리마인더 아코디언 카드 (지출 카드와 절세 카드 사이).
/// 접힌 상태: 다음 알림 요약. 펼친 상태(부드러운 애니메이션): 목록.
/// 알림 '추가' 기능은 다음 패스에서 제공 — 지금은 읽기 전용.
class ReminderCard extends StatefulWidget {
  final String userType;
  const ReminderCard({super.key, this.userType = '직장인'});

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard> with RouteAware {
  List<Reminder> _reminders = [];
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// 리마인더 관리 화면(추가·수정·삭제)에서 돌아왔을 때 목록 리로드.
  @override
  void didPopNext() {
    _load();
  }

  Future<void> _load() async {
    final list = await customReminderService.list();
    if (!mounted) return;
    setState(() {
      _reminders = list;
    });
  }

  String _ddayFor(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(when.year, when.month, when.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'D-DAY';
    if (diff > 0) return 'D-$diff';
    return '지남';
  }

  String _timeLabel(Reminder r) {
    final h = r.notifyHour.toString().padLeft(2, '0');
    final m = r.notifyMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 일정 한 줄 설명 — 주기별 분기.
  String _subtitle(Reminder r) {
    final t = _timeLabel(r);
    switch (r.frequency) {
      case ReminderFrequency.once:
        return '${DateFormat('M월 d일').format(r.notifyDate)} $t';
      case ReminderFrequency.daily:
        return '매일 $t';
      case ReminderFrequency.weekly:
        final labels = r.effectiveWeekdays.map((wd) => kWeekdayLabels[(wd - 1) % 7]).join('·');
        return '매주 $labels요일 $t';
      case ReminderFrequency.monthly:
        return '매월 ${r.notifyDate.day}일 $t';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 헤더: 라벨+화살표(접힘) / 추가·관리 링크(우상단) ──
        Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('리마인더', style: AppTheme.label(context)),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Icon(Icons.expand_more_rounded, size: 20, color: tert),
                ),
              ]),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openManager,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 16, color: accent),
                const SizedBox(width: 4),
                Text(_reminders.isEmpty ? '알림 추가' : '리마인더 관리',
                    style: AppTheme.sans(13, accent, weight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
        // ── 펼침 영역 — AnimatedSize로 높이 전환 ──
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _expandedContent(ink, sub, tert, accent)
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }

  Widget _expandedContent(Color ink, Color sub, Color tert, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_reminders.isEmpty)
            Text('가계부 기록·월세·건강검진, 알림으로 챙겨보세요.',
                style: AppTheme.sans(12.5, tert, height: 1.5))
          else
            ..._reminders.take(3).map((r) => _reminderRow(r, ink, sub, tert, accent)),
        ],
      ),
    );
  }

  Future<void> _openManager() async {
    // 복귀 시 리로드는 didPopNext(RouteObserver)가 처리.
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ReminderListScreen(userType: widget.userType)));
  }

  Widget _reminderRow(Reminder r, Color ink, Color sub, Color tert, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // D-day(단발) 또는 주기 배지
          SizedBox(
            width: 54,
            child: Text(
                r.frequency == ReminderFrequency.once
                    ? _ddayFor(CustomReminderService.nextInstance(r))
                    : r.frequency.label,
                style: AppTheme.serif(15, r.enabled ? ink : tert,
                    weight: FontWeight.w700, spacing: -0.5, height: 1.0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(13.5, r.enabled ? ink : tert,
                        weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_subtitle(r), style: AppTheme.sans(11.5, tert)),
              ],
            ),
          ),
          // on/off 스위치 (기존 알림 끄고 켜기는 가능)
          Switch(
            value: r.enabled,
            activeColor: accent,
            onChanged: (v) async {
              await customReminderService.toggle(r, v);
              await _load();
            },
          ),
        ],
      ),
    );
  }
}
