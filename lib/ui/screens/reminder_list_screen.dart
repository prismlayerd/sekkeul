import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';
import '../../core/notifications/reminder.dart';
import '../../core/notifications/custom_reminder_service.dart';
import '../../core/notifications/event_reminder_prefs.dart';
import '../../core/notifications/reminder_scheduler.dart';
import '../../core/security/notification_helper.dart';
import '../../core/data/db_helper.dart';
import 'reminder_form_screen.dart';
import '../theme/text_wrap.dart';

/// 만료 알림 프리셋 — 계산기 연동 없이 제목만 미리 채우고 날짜는 직접 입력.
const List<(String, String)> kExpiryReminderPresets = [
  ('면허 갱신', '운전면허 갱신'),
  ('여권 만료', '여권 만료'),
  ('전세 만기', '전세 계약 만기'),
];

/// 리마인더 — 사용자 직접 생성 알림만.
/// 세금 일정·공제 문턱·예산 알림은 전체탭 > 알림 설정에서 관리.
class ReminderListScreen extends StatefulWidget {
  final String userType;

  /// 하단 탭에 끼워질 때(true)는 leading 숨김.
  final bool embedded;
  const ReminderListScreen(
      {super.key, this.userType = '직장인', this.embedded = false});

  @override
  State<ReminderListScreen> createState() => _ReminderListScreenState();
}

class _ReminderListScreenState extends State<ReminderListScreen> {
  List<Reminder> _userItems = [];
  ResolvedEventPref _budgetPref = const ResolvedEventPref(enabled: true, hour: 20, minute: 0);
  ResolvedEventPref _inactivityPref = const ResolvedEventPref(enabled: true, hour: 9, minute: 0);
  ResolvedEventPref _incomeInactivityPref = const ResolvedEventPref(enabled: true, hour: 9, minute: 0);
  ResolvedEventPref _recurringExpensePref = const ResolvedEventPref(enabled: true, hour: 9, minute: 0);
  ResolvedEventPref _healthUninsuredPref = const ResolvedEventPref(enabled: true, hour: 9, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    if (!kIsWeb) notificationHelper.requestPermissions();
  }

  Future<void> _load() async {
    final items = await customReminderService.list();
    final budget = await resolveEventPref('budget_alert');
    final inactivity = await resolveEventPref('inactivity_nudge');
    final incomeInactivity = await resolveEventPref('income_inactivity_nudge');
    final recurringExpense = await resolveEventPref('recurring_expense_alert');
    final healthUninsured = await resolveEventPref('freelancer_health_uninsured');
    if (!mounted) return;
    setState(() {
      _userItems = items;
      _budgetPref = budget;
      _inactivityPref = inactivity;
      _incomeInactivityPref = incomeInactivity;
      _recurringExpensePref = recurringExpense;
      _healthUninsuredPref = healthUninsured;
      _loading = false;
    });
  }

  Future<void> _openForm({Reminder? existing, String? initialTitle}) async {
    final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => ReminderFormScreen(existing: existing, initialTitle: initialTitle)));
    if (changed == true) await _load();
  }

  /// 다음 발화 시각순 정렬(꺼진 알림은 뒤로) — 생성 순서보다 실제로 챙겨야 할 순서를 보여준다.
  List<Reminder> _sortedByNext(Iterable<Reminder> items) {
    final list = items.toList();
    list.sort((a, b) {
      if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
      if (!a.enabled) return 0;
      return CustomReminderService.nextInstance(a)
          .compareTo(CustomReminderService.nextInstance(b));
    });
    return list;
  }

  List<Reminder> get _records =>
      _sortedByNext(_userItems.where((r) => r.kind == 'record'));
  List<Reminder> get _customs =>
      _sortedByNext(_userItems.where((r) => r.kind != 'record'));

  String _userSubtitle(Reminder r) {
    final t =
        '${r.notifyHour.toString().padLeft(2, '0')}:${r.notifyMinute.toString().padLeft(2, '0')}';
    switch (r.frequency) {
      case ReminderFrequency.once:
        return '${r.notifyDate.year}년 ${r.notifyDate.month}월 ${r.notifyDate.day}일 · $t';
      case ReminderFrequency.daily:
        return '매일 · $t';
      case ReminderFrequency.weekly:
        final labels =
            r.effectiveWeekdays.map((wd) => kWeekdayLabels[(wd - 1) % 7]).join('·');
        return '매주 $labels요일 · $t';
      case ReminderFrequency.monthly:
        return '매월 ${r.notifyDate.day}일 · $t';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: sub),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
                children: [
                  Text('리마인더'.toUpperCase(), style: AppTheme.label(context)),
                  const SizedBox(height: 12),
                  Text('챙길 알림',
                      style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),
                  const SizedBox(height: 10),
                  Text('직접 만든 알림과 가계부 기록 넛지를 관리해요.'.keepWords,
                      style: AppTheme.sans(14, sub, height: 1.55)),
                  const SizedBox(height: 18),

                  // ── 내가 만든 (CRUD) ──
                  _section(
                      '내가 만든',
                      _customs.isEmpty
                          ? [_muted('월세 이체·건강검진처럼 잊지 않을 일을 직접 만들어요.')]
                          : _customs.map(_userRow).toList()),
                  _presetChips(),
                  const SizedBox(height: 14),
                  _addButton(),
                  const SizedBox(height: 18),

                  // ── 기본 제공 (앱이 자동으로 챙겨주는 알림) ──
                  _section('기본 제공', [
                    ..._records.map(_userRow),
                    _eventRow('budget_alert', '예산 목표 80%·초과 알림', _budgetPref),
                    _eventRow('inactivity_nudge', '지출 미기록 넛지', _inactivityPref),
                    _eventRow('income_inactivity_nudge', '수입 미기록 넛지', _incomeInactivityPref),
                    _eventRow('recurring_expense_alert', '고정지출 알림', _recurringExpensePref),
                    if (widget.userType == '프리랜서')
                      _eventRow('freelancer_health_uninsured', '건강보험 미가입 경고', _healthUninsuredPref),
                  ]),
                ],
              ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 8),
        AppTheme.hairline(context),
        for (final r in rows) ...[
          r,
          AppTheme.hairline(context),
        ],
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _muted(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(t,
            style: AppTheme.sans(12, AppTheme.inkTertiary(context),
                height: 1.45)),
      );

  Widget _userRow(Reminder r) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    return GestureDetector(
      onTap: () => _openForm(existing: r),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(15, r.enabled ? ink : tert,
                          weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(_userSubtitle(r), style: AppTheme.sans(12, tert)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _editReminderTime(r),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.schedule_rounded, size: 18, color: tert),
              ),
            ),
            const SizedBox(width: 4),
            Switch(
              value: r.enabled,
              activeColor: accent,
              onChanged: (v) async {
                if (v && !kIsWeb) await notificationHelper.ensurePermissionIfNeeded();
                await customReminderService.toggle(r, v);
                await _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 리마인더 목록에서 시간만 바로 수정 — 전체 폼(제목·주기 등) 안 열고 시각만.
  Future<void> _editReminderTime(Reminder r) async {
    int hour = r.notifyHour, minute = r.notifyMinute;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('알릴 시각', style: AppTheme.sans(15, AppTheme.ink(ctx), weight: FontWeight.w700)),
        content: SizedBox(
          height: 140,
          width: 200,
          child: Row(
            children: [
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(initialItem: hour),
                  onSelectedItemChanged: (i) => hour = i,
                  children: [
                    for (int i = 0; i < 24; i++)
                      Center(child: Text(i.toString().padLeft(2, '0'), style: AppTheme.sans(16, AppTheme.ink(ctx))))
                  ],
                ),
              ),
              Text(':', style: AppTheme.sans(16, AppTheme.ink(ctx))),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(initialItem: minute),
                  onSelectedItemChanged: (i) => minute = i,
                  children: [
                    for (int i = 0; i < 60; i++)
                      Center(child: Text(i.toString().padLeft(2, '0'), style: AppTheme.sans(16, AppTheme.ink(ctx))))
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('취소', style: AppTheme.sans(14, AppTheme.inkSecondary(ctx)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('저장', style: AppTheme.sans(14, AppTheme.accentColor(ctx), weight: FontWeight.w700))),
        ],
      ),
    );
    if (saved == true) {
      await customReminderService.update(r.copyWith(notifyHour: hour, notifyMinute: minute));
      await _load();
    }
  }

  /// 이벤트 트리거형 기본 제공 알림 행(예산 알림·미기록 넛지) — 토글 + 시각 편집만 가능.
  Widget _eventRow(String key, String title, ResolvedEventPref pref) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final t = '${pref.hour.toString().padLeft(2, '0')}:${pref.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: () => _editEventTime(key, pref),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(15, pref.enabled ? ink : tert,
                          weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(t, style: AppTheme.sans(12, tert)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: pref.enabled,
              activeColor: accent,
              onChanged: (v) async {
                if (v && !kIsWeb) await notificationHelper.ensurePermissionIfNeeded();
                await dbService.setEventReminderPref(key,
                    enabled: v, hour: pref.hour, minute: pref.minute);
                if (key == 'recurring_expense_alert' && !kIsWeb) {
                  await ReminderScheduler.scheduleRecurringExpenses(
                      await dbService.getRecurringTemplates());
                }
                await _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editEventTime(String key, ResolvedEventPref pref) async {
    int hour = pref.hour, minute = pref.minute;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('알릴 시각', style: AppTheme.sans(15, AppTheme.ink(ctx), weight: FontWeight.w700)),
        content: SizedBox(
          height: 140,
          width: 200,
          child: Row(
            children: [
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(initialItem: hour),
                  onSelectedItemChanged: (i) => hour = i,
                  children: [
                    for (int i = 0; i < 24; i++)
                      Center(child: Text(i.toString().padLeft(2, '0'), style: AppTheme.sans(16, AppTheme.ink(ctx))))
                  ],
                ),
              ),
              Text(':', style: AppTheme.sans(16, AppTheme.ink(ctx))),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(initialItem: minute),
                  onSelectedItemChanged: (i) => minute = i,
                  children: [
                    for (int i = 0; i < 60; i++)
                      Center(child: Text(i.toString().padLeft(2, '0'), style: AppTheme.sans(16, AppTheme.ink(ctx))))
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('취소', style: AppTheme.sans(14, AppTheme.inkSecondary(ctx)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('저장', style: AppTheme.sans(14, AppTheme.accentColor(ctx), weight: FontWeight.w700))),
        ],
      ),
    );
    if (saved == true) {
      await dbService.setEventReminderPref(key, enabled: pref.enabled, hour: hour, minute: minute);
      if (key == 'recurring_expense_alert' && !kIsWeb) {
        await ReminderScheduler.scheduleRecurringExpenses(
            await dbService.getRecurringTemplates());
      }
      await _load();
    }
  }

  /// 만료 알림 빠른 추가 — 제목만 미리 채우고 날짜는 직접 입력(계산기 연동 없음).
  Widget _presetChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in kExpiryReminderPresets)
            GestureDetector(
              onTap: () => _openForm(initialTitle: p.$2),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.line(context)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(p.$1,
                    style: AppTheme.sans(12, AppTheme.inkSecondary(context), weight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addButton() {
    final bg = AppTheme.backgroundColor(context);
    return GestureDetector(
      onTap: () => _openForm(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: AppTheme.ink(context),
            borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, size: 18, color: bg),
          const SizedBox(width: 6),
          Text('알림 추가', style: AppTheme.sans(15, bg, weight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
