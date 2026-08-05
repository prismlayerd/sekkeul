import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../core/notifications/system_reminder_catalog.dart';
import '../../core/notifications/reminder_scheduler.dart';
import '../../core/security/notification_helper.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/occupation_data.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final String userType;
  const NotificationSettingsScreen({super.key, required this.userType});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  Map<String, bool> _settings = {};
  bool _loading = true;
  bool _ownsCar = true;
  bool _ownsHouse = true;
  bool _isVatExempt = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await dbService.getReminderSettings();
    final profile = await dbService.getProfile();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _ownsCar = profile?['owns_car'] ?? true;
      _ownsHouse = profile?['owns_house'] ?? true;
      _isVatExempt = OccupationData.occupations[profile?['occupation_code'] as String?]
              ?.isPersonalService ??
          false;
      _loading = false;
    });
  }

  bool _on(String key) => _settings[key] ?? true;

  bool _groupOn(List<SystemReminder> items) => items.every((s) => _on(s.key));

  Future<void> _toggleGroup(List<SystemReminder> items, bool v) async {
    if (v && !kIsWeb) await notificationHelper.ensurePermissionIfNeeded();
    for (final s in items) {
      await dbService.setReminderSetting(s.key, v);
    }
    if (!kIsWeb) await ReminderScheduler.scheduleTaxSeason(widget.userType);
    await _load();
  }

  Future<void> _toggleItem(SystemReminder s, bool v) async {
    if (v && !kIsWeb) await notificationHelper.ensurePermissionIfNeeded();
    await dbService.setReminderSetting(s.key, v);
    if (s.category == SysCategory.deadline && !kIsWeb) {
      await ReminderScheduler.scheduleTaxSeason(widget.userType);
    }
    await _load();
  }

  List<MapEntry<String, List<SystemReminder>>> _byTopCategory(
      List<SystemReminder> items) {
    final order = <String>[];
    final map = <String, List<SystemReminder>>{};
    for (final s in items) {
      if (!map.containsKey(s.topCategory)) {
        order.add(s.topCategory);
        map[s.topCategory] = [];
      }
      map[s.topCategory]!.add(s);
    }
    return order.map((c) => MapEntry(c, map[c]!)).toList();
  }

  List<MapEntry<String, List<SystemReminder>>> _grouped(
      List<SystemReminder> items) {
    final order = <String>[];
    final map = <String, List<SystemReminder>>{};
    for (final s in items) {
      final g = s.group ?? s.key;
      if (!map.containsKey(g)) {
        order.add(g);
        map[g] = [];
      }
      map[g]!.add(s);
    }
    return order.map((g) => MapEntry(g, map[g]!)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sys = systemRemindersFor(widget.userType,
        ownsCar: _ownsCar, ownsHouse: _ownsHouse, isVatExempt: _isVatExempt);
    final deadlines =
        sys.where((s) => s.category == SysCategory.deadline).toList();
    final thresholds =
        sys.where((s) => s.category == SysCategory.moment).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppTheme.inkSecondary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text('알림 설정',
            style: AppTheme.sans(17, ink, weight: FontWeight.w700)),
      ),
      body: _loading
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
              children: [
                // ── 1. 기한 알림(세금 일정·교통·에너지·일자리·행정 등, topCategory별 섹션) ──
                for (final entry in _byTopCategory(deadlines).asMap().entries) ...[
                  if (entry.key > 0) _catDivider(),
                  _catHeader(entry.value.key),
                  for (final e in _grouped(entry.value.value)) _groupRow(e.key, e.value),
                ],

                // ── 2. 공제 문턱 ──
                if (thresholds.isNotEmpty) ...[
                  _catDivider(),
                  _catHeader('공제 문턱'),
                  for (final s in thresholds) _sysRow(s),
                ],

              ],
            ),
    );
  }

  Widget _catHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title,
            style: AppTheme.sans(12, AppTheme.inkTertiary(context),
                weight: FontWeight.w600)),
      );

  Widget _catDivider() =>
      Divider(height: 1, thickness: 1, color: AppTheme.line(context));

  Widget _groupRow(String groupId, List<SystemReminder> items) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final on = _groupOn(items);
    final label = kGroupLabels[groupId] ?? groupId;
    final schedule = kGroupSchedules[groupId] ??
        items.map((s) => s.scheduleLabel).join(' · ');
    final count = items.length;

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
                    Row(children: [
                      Text(label,
                          style: AppTheme.sans(15, on ? ink : tert,
                              weight: FontWeight.w700)),
                      if (count > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: on ? accent : tert, width: 1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text('$count건',
                              style: AppTheme.sans(11, on ? accent : tert,
                                  weight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(schedule, style: AppTheme.sans(12, tert)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: on,
                activeColor: accent,
                onChanged: kIsWeb ? null : (v) => _toggleGroup(items, v),
              ),
            ],
          ),
        ),
        AppTheme.hairline(context),
      ],
    );
  }

  Widget _sysRow(SystemReminder s) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final on = _on(s.key);
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
                    Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(15, on ? ink : tert,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(s.scheduleLabel, style: AppTheme.sans(12, tert)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: on,
                activeColor: accent,
                onChanged: kIsWeb ? null : (v) => _toggleItem(s, v),
              ),
            ],
          ),
        ),
        AppTheme.hairline(context),
      ],
    );
  }

}
