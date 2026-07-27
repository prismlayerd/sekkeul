import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import '../theme/text_wrap.dart';

/// 알림함 — 홈 우상단 벨 아이콘에서 진입.
/// 발화된 즉시형 알림(문턱·예산·시즌 등) 기록을 최신순으로 표시.
class NotificationInboxScreen extends StatefulWidget {
  final VoidCallback? onRead; // 읽음 처리 후 배지 갱신 콜백

  const NotificationInboxScreen({super.key, this.onRead});

  @override
  State<NotificationInboxScreen> createState() => _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await dbService.getNotificationLogs();
    await dbService.markAllNotificationsRead();
    widget.onRead?.call();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('알림 기록을 모두 지울까요?',
            style: AppTheme.sans(15, AppTheme.ink(ctx), weight: FontWeight.w700)),
        content: Text('지워진 기록은 복구할 수 없어요.'.keepWords,
            style: AppTheme.sans(13, AppTheme.inkSecondary(ctx), height: 1.45)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('취소', style: AppTheme.sans(14, AppTheme.inkSecondary(ctx)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('지우기',
                  style: AppTheme.sans(14, AppTheme.colorDanger, weight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    await dbService.clearNotificationLogs();
    widget.onRead?.call();
    if (!mounted) return;
    setState(() => _logs = []);
  }

  String _relativeTime(String isoString) {
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}월 ${dt.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('알림함', style: AppTheme.serif(22, ink, weight: FontWeight.w400, spacing: -0.3)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_logs.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: Text('모두 지우기',
                  style: AppTheme.sans(13, AppTheme.colorDanger, weight: FontWeight.w600)),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : _logs.isEmpty
                ? _emptyState(tert)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
                    itemCount: _logs.length,
                    separatorBuilder: (_, __) => AppTheme.hairline(context),
                    itemBuilder: (_, i) => _logRow(_logs[i], ink, sub, tert),
                  ),
      ),
    );
  }

  Widget _emptyState(Color tert) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none_rounded, size: 48, color: tert),
          const SizedBox(height: 16),
          Text('받은 알림이 없어요',
              style: AppTheme.sans(15, tert, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('공제 문턱·예산 초과·세무 일정 알림이\n여기에 기록돼요.'.keepWords,
              style: AppTheme.sans(13, tert, height: 1.5),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _logRow(Map<String, dynamic> log, Color ink, Color sub, Color tert) {
    final title = log['title'] as String? ?? '';
    final body = log['body'] as String? ?? '';
    final firedAt = _relativeTime(log['fired_at'] as String? ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.accentColor(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(title,
                        style: AppTheme.sans(14, ink, weight: FontWeight.w700, spacing: -0.1)),
                  ),
                  const SizedBox(width: 8),
                  Text(firedAt, style: AppTheme.sans(12, tert)),
                ]),
                const SizedBox(height: 4),
                Text(body, style: AppTheme.sans(13, sub, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
