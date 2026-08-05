import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../../core/notifications/reminder.dart';
import '../../core/notifications/custom_reminder_service.dart';
import '../theme/text_wrap.dart';

/// '내가 만든' 알림 추가·수정 — 풀스크린(바텀시트 금지).
/// 제목 · 반복(한번/매일/매주/매월) · 조건부(날짜/요일/일) · 인라인 시각.
class ReminderFormScreen extends StatefulWidget {
  final Reminder? existing; // null이면 신규
  final String? initialTitle; // 프리셋 칩에서 넘어온 미리채움 제목(신규 생성시만 사용)
  const ReminderFormScreen({super.key, this.existing, this.initialTitle});

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _titleCtrl = TextEditingController();
  ReminderFrequency _freq = ReminderFrequency.monthly;
  DateTime _onceDate = DateTime.now();
  Set<int> _weekdays = {DateTime.now().weekday}; // 1=월…7=일, 복수 선택
  int _monthDay = DateTime.now().day.clamp(1, 28);
  int _hour = 9;
  int _minute = 0;
  bool _saving = false;

  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minCtrl;

  bool get _isEdit => widget.existing != null;

  /// 기본 제공 리마인더(kind != 'custom') 수정 중이면 시각 외 필드는 잠근다.
  bool get _isFixedKind => _isEdit && widget.existing!.kind != 'custom';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _freq = e.frequency;
      _onceDate = e.notifyDate;
      _weekdays = e.effectiveWeekdays.toSet();
      _monthDay = e.notifyDate.day.clamp(1, 28);
      _hour = e.notifyHour;
      _minute = e.notifyMinute;
    } else if (widget.initialTitle != null) {
      _titleCtrl.text = widget.initialTitle!;
    }
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _titleCtrl.text.trim().isNotEmpty && !_saving;

  /// 폼 입력 → notifyDate 구성.
  DateTime _composedNotifyDate() {
    final now = DateTime.now();
    switch (_freq) {
      case ReminderFrequency.once:
        return _onceDate;
      case ReminderFrequency.daily:
        return DateTime(now.year, now.month, now.day);
      case ReminderFrequency.weekly:
        return DateTime(now.year, now.month, now.day);
      case ReminderFrequency.monthly:
        return DateTime(now.year, now.month, _monthDay);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final base = (widget.existing ??
            Reminder(title: '', notifyDate: _placeholderDate))
        .copyWith(
      title: _titleCtrl.text.trim(),
      kind: widget.existing?.kind ?? 'custom', // 기록 시드 등 기존 종류 보존
      frequency: _freq,
      notifyDate: _composedNotifyDate(),
      weekday: _freq == ReminderFrequency.weekly ? (_weekdays.toList()..sort()).first : null,
      weekdays: _freq == ReminderFrequency.weekly ? (_weekdays.toList()..sort()) : const [],
      notifyHour: _hour,
      notifyMinute: _minute,
      enabled: true,
    );
    if (_isEdit) {
      await customReminderService.update(base);
    } else {
      await customReminderService.add(base);
    }
    if (mounted) Navigator.pop(context, true);
  }

  static final DateTime _placeholderDate = DateTime(2000);

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('알림을 삭제할까요?', style: AppTheme.sans(15, AppTheme.ink(ctx), weight: FontWeight.w700)),
        content: Text('이 알림과 예약된 알림이 함께 사라져요.'.keepWords, style: AppTheme.sans(14, AppTheme.inkSecondary(ctx), height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소', style: AppTheme.sans(14, AppTheme.inkSecondary(ctx)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('삭제', style: AppTheme.sans(14, AppTheme.colorDanger, weight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true && widget.existing != null) {
      await customReminderService.remove(widget.existing!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 삭제는 사용자가 직접 만든 알림(custom)만. 기록 넛지 등 시드 알림은 끄기만 가능.
          if (_isEdit && widget.existing?.kind == 'custom')
            TextButton(
              onPressed: _confirmDelete,
              child: Text('삭제', style: AppTheme.sans(14, AppTheme.colorDanger, weight: FontWeight.w700)),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
          children: [
            Text((_isEdit ? '알림 수정' : '새 알림').toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 12),
            Text(_isEdit ? '알림을\n다듬어요' : '챙길 일을\n알림으로',
                style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),

            if (_isFixedKind) ...[
              // ── 기본 제공 리마인더 — 제목·주기 고정, 안내만 ──
              const SizedBox(height: 26),
              Text('무엇을 알릴까요?'.toUpperCase(), style: AppTheme.label(context)),
              const SizedBox(height: 12),
              Text(_titleCtrl.text, style: AppTheme.sans(15, ink, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('기본 제공 알림은 시각만 바꿀 수 있어요.'.keepWords,
                  style: AppTheme.sans(12, AppTheme.inkTertiary(context), height: 1.45)),
            ] else ...[
              // ── 제목 ──
              const SizedBox(height: 26),
              Text('무엇을 알릴까요?'.toUpperCase(), style: AppTheme.label(context)),
              const SizedBox(height: 12),
              _titleField(ink, sub),

              // ── 반복 ──
              const SizedBox(height: 26),
              Text('언제 알릴까요?'.toUpperCase(), style: AppTheme.label(context)),
              const SizedBox(height: 12),
              _freqChips(),
              const SizedBox(height: 16),
              _conditionalPicker(ink, sub),
            ],

            // ── 시각 ──
            const SizedBox(height: 26),
            Text('몇 시에 알릴까요?'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 12),
            _timePicker(ink, sub),
          ],
        ),
      ),
      bottomNavigationBar: _saveBar(),
    );
  }

  Widget _titleField(Color ink, Color sub) {
    final accent = AppTheme.accentColor(context);
    return TextField(
      controller: _titleCtrl,
      onChanged: (_) => setState(() {}),
      style: AppTheme.sans(15, ink, weight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: '예: 가계부 기록, 월세 이체, 건강검진 예약',
        hintStyle: AppTheme.sans(14, AppTheme.inkTertiary(context)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: AppTheme.surface(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppTheme.line(context))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppTheme.line(context))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: accent, width: 1.5)),
      ),
    );
  }

  Widget _freqChips() {
    return Row(
      children: [
        for (final f in ReminderFrequency.values) ...[
          Expanded(child: _segment(f.label, _freq == f, () => setState(() => _freq = f))),
          if (f != ReminderFrequency.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.10) : Colors.transparent,
          border: Border.all(color: selected ? accent : AppTheme.line(context), width: selected ? 1.4 : 1.0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AppTheme.sans(14, selected ? ink : sub, weight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  /// 반복 주기별 조건부 입력 — 한번=날짜, 매주=요일, 매월=일. 매일=없음.
  Widget _conditionalPicker(Color ink, Color sub) {
    switch (_freq) {
      case ReminderFrequency.daily:
        return _hint('매일 같은 시각에 알려드려요.');
      case ReminderFrequency.once:
        return _dateRow(ink, sub);
      case ReminderFrequency.weekly:
        return _weekdayRow();
      case ReminderFrequency.monthly:
        return _monthDayGrid();
    }
  }

  Widget _hint(String t) =>
      Text(t, style: AppTheme.sans(12, AppTheme.inkTertiary(context), height: 1.45));

  Widget _dateRow(Color ink, Color sub) {
    final accent = AppTheme.accentColor(context);
    return GestureDetector(
      onTap: _pickDate,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          border: Border.all(color: AppTheme.line(context)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Icon(Icons.event_rounded, size: 16, color: accent),
          const SizedBox(width: 10),
          Text('${DateFormat('yyyy년 M월 d일').format(_onceDate)} (${kWeekdayLabels[(_onceDate.weekday - 1) % 7]})',
              style: AppTheme.sans(14, ink, weight: FontWeight.w600)),
          const Spacer(),
          Text('변경', style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _onceDate.isBefore(now) ? now : _onceDate,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _onceDate = picked);
  }

  /// 복수 요일 선택 — 최소 1개는 항상 남긴다(전부 해제 방지).
  Widget _weekdayRow() {
    return Row(
      children: [
        for (int wd = 1; wd <= 7; wd++) ...[
          Expanded(
            child: _miniCell(kWeekdayLabels[wd - 1], _weekdays.contains(wd), () {
              setState(() {
                if (_weekdays.contains(wd)) {
                  if (_weekdays.length > 1) _weekdays.remove(wd);
                } else {
                  _weekdays.add(wd);
                }
              });
            }, danger: wd == 7, warn: wd == 6),
          ),
          if (wd != 7) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _monthDayGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (int d = 1; d <= 28; d++)
              SizedBox(
                width: 38,
                child: _miniCell('$d', _monthDay == d, () => setState(() => _monthDay = d)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _hint('말일 변동을 피하려고 28일까지만 골라요.'),
      ],
    );
  }

  Widget _miniCell(String label, bool selected, VoidCallback onTap,
      {bool danger = false, bool warn = false}) {
    final ink = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);
    final base = danger ? AppTheme.colorDanger : warn ? accent : AppTheme.inkSecondary(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? ink : null,
          border: Border.all(color: selected ? ink : AppTheme.line(context), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AppTheme.sans(14, selected ? AppTheme.backgroundColor(context) : base,
                weight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  /// 인라인 시·분 선택 — 계기판 한 창에 두 드럼을 묶는다(시 0~23 · 분 0~59).
  Widget _timePicker(Color ink, Color sub) {
    final accent = AppTheme.accentColor(context);
    final tert = AppTheme.inkTertiary(context);
    const itemExtent = 44.0;
    const drumHeight = 154.0;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border.all(color: AppTheme.line(context)),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // 실시간 값 — 도면 주석처럼 작게.
          Text('${_hour < 12 ? "오전" : "오후"}  ${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
              style: AppTheme.sans(12, tert, weight: FontWeight.w600, spacing: 0.5)),
          const SizedBox(height: 2),
          // 계기판: 두 드럼 + 가운데 단일 선택 띠(위아래 헤어라인).
          SizedBox(
            height: drumHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 선택 창(두 드럼 공통)
                IgnorePointer(
                  child: Container(
                    height: itemExtent,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.07),
                      border: Border.symmetric(
                        horizontal: BorderSide(color: accent.withValues(alpha: 0.40)),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: _drum(_hourCtrl, 24, itemExtent, (v) => _hour = v)),
                    Text(':', style: AppTheme.serif(22, tert, height: 1.0)),
                    Expanded(child: _drum(_minCtrl, 60, itemExtent, (v) => _minute = v)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 시 / 분 라벨
          Row(
            children: [
              Expanded(child: Center(child: Text('시', style: AppTheme.label(context)))),
              const SizedBox(width: 14),
              Expanded(child: Center(child: Text('분', style: AppTheme.label(context)))),
            ],
          ),
        ],
      ),
    );
  }

  /// 세로 회전 드럼 한 개 — 선택 창은 바깥 계기판이 그리므로 오버레이는 투명.
  Widget _drum(FixedExtentScrollController controller, int count, double itemExtent, ValueChanged<int> onChange) {
    final ink = AppTheme.ink(context);
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: itemExtent,
      magnification: 1.15,
      squeeze: 1.05,
      diameterRatio: 1.3,
      backgroundColor: Colors.transparent,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: (i) => setState(() => onChange(i)),
      children: [
        for (int i = 0; i < count; i++)
          Center(child: Text(i.toString().padLeft(2, '0'), style: AppTheme.serif(27, ink, height: 1.0))),
      ],
    );
  }

  Widget _saveBar() {
    final bg = AppTheme.backgroundColor(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: GestureDetector(
          onTap: _canSave ? () { HapticFeedback.lightImpact(); _save(); } : null,
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: _canSave ? 1.0 : 0.4,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppTheme.ink(context), borderRadius: BorderRadius.circular(4)),
              child: Text(_isEdit ? '저장' : '알림 만들기',
                  style: AppTheme.sans(15, bg, weight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}
