import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import '../../core/data/theme_pref.dart';
import '../../core/data/backup_service.dart';
import '../../core/data/db_helper.dart';
import '../../core/security/app_lock_service.dart';
import 'notification_settings_screen.dart';
import '../theme/text_wrap.dart';

/// 설정 — 홈 우상단 톱니에서 진입.
/// 알림(마스터+세부) · 화면 테마 · 데이터 수집방식 · 백업/복원 · 개인정보처리방침 · 면책 · 파기 · 버전.
/// 화면 테마는 설정에서 시스템/라이트/다크 중 선택(기본 시스템, main.dart 참고).
class SettingsScreen extends StatefulWidget {
  final String userType;
  final bool notificationsEnabled;
  final Future<void> Function(bool) onNotificationsChanged;
  final VoidCallback onDestroyData;

  const SettingsScreen({
    super.key,
    required this.userType,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    required this.onDestroyData,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _notificationsEnabled = widget.notificationsEnabled;
  PackageInfo? _packageInfo;
  bool _appLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadAppLock();
  }

  Future<void> _loadAppLock() async {
    final enabled = await appLockService.isEnabled();
    if (!mounted) return;
    setState(() => _appLockEnabled = enabled);
  }

  Future<void> _toggleAppLock(bool want) async {
    if (want) {
      final pin = await _showSetPinDialog();
      if (pin == null) return;
      await appLockService.setPin(pin);
      await appLockService.setEnabled(true);
    } else {
      await appLockService.setEnabled(false);
    }
    if (!mounted) return;
    setState(() => _appLockEnabled = want);
  }

  Future<String?> _showSetPinDialog() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(ctx).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('PIN 설정 (4~6자리 숫자)'.keepWords,
              style: AppTheme.sans(15, AppTheme.ink(ctx), weight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(counterText: '', labelText: 'PIN'),
              ),
              TextField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(counterText: '', labelText: 'PIN 확인'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: AppTheme.sans(12, AppTheme.colorDanger)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('취소', style: AppTheme.sans(14, AppTheme.inkSecondary(ctx)))),
            TextButton(
              onPressed: () {
                final pin = pinController.text;
                final confirm = confirmController.text;
                if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
                  setDialogState(() => error = 'PIN은 4~6자리 숫자여야 해요');
                  return;
                }
                if (pin != confirm) {
                  setDialogState(() => error = 'PIN이 서로 달라요');
                  return;
                }
                Navigator.pop(ctx, pin);
              },
              child: Text('설정',
                  style: AppTheme.sans(14, AppTheme.accentColor(ctx), weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _packageInfo = info);
  }

  @override
  void didUpdateWidget(SettingsScreen old) {
    super.didUpdateWidget(old);
    if (old.notificationsEnabled != widget.notificationsEnabled) {
      setState(() => _notificationsEnabled = widget.notificationsEnabled);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _exportBackup() async {
    final r = await backupService.exportToFile();
    switch (r) {
      case BackupResult.success:
        _snack('백업 파일을 저장했어요. 안전한 곳에 보관하세요.');
      case BackupResult.cancelled:
        break;
      default:
        _snack('백업에 실패했어요. 다시 시도해주세요.');
    }
  }

  String _stamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportErrorLogs() async {
    final logs = await dbService.getErrorLogs();
    if (logs.isEmpty) {
      _snack('기록된 오류가 없어요.');
      return;
    }
    final buffer = StringBuffer();
    for (final log in logs) {
      buffer.writeln('[${log['occurred_at']}] ${log['message']}');
      buffer.writeln(log['stack_trace']);
      buffer.writeln('---');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sekkeul_error_log_${_stamp()}.txt');
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(file.path)], text: '세끌 오류 기록');
  }

  Future<void> _importBackup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('백업에서 복원할까요?',
            style: AppTheme.sans(15, AppTheme.ink(ctx), weight: FontWeight.w700)),
        content: Text('지금 기기에 있는 데이터는 백업 내용으로 덮어써져요.'.keepWords,
            style: AppTheme.sans(14, AppTheme.inkSecondary(ctx), height: 1.45)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('취소', style: AppTheme.sans(14, AppTheme.inkSecondary(ctx)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('복원',
                  style: AppTheme.sans(14, AppTheme.accentColor(ctx), weight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    final r = await backupService.importFromFile();
    switch (r) {
      case BackupResult.success:
        _snack('복원했어요. 앱을 완전히 종료한 뒤 다시 열면 모두 반영돼요.');
      case BackupResult.cancelled:
        break;
      case BackupResult.invalidFile:
        _snack('세끌 백업 파일이 아니에요. 파일을 확인해주세요.');
      default:
        _snack('복원에 실패했어요. 파일이 손상됐을 수 있어요.');
    }
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('개인정보처리방침',
            style: AppTheme.sans(15, AppTheme.ink(ctx), weight: FontWeight.w700)),
        content: Text(
          '세끌은 제1모드(완전 오프라인)로 운영됩니다.\n\n'
          '모든 납세자 정보·가계부·리마인더 데이터는 이 기기의 저장소에만 보관되며, '
          '외부 서버 전송·제3자 제공·광고 추적이 전혀 없습니다.\n\n'
          '데이터는 "개인 세무 데이터 영구 파기"로 언제든 완전히 삭제할 수 있습니다.',
          style: AppTheme.sans(13, AppTheme.inkSecondary(ctx), height: 1.55),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('닫기',
                  style: AppTheme.sans(14, AppTheme.accentColor(ctx), weight: FontWeight.w700))),
        ],
      ),
    );
  }

  void _showLegalDisclaimer() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('이용 안내 및 면책',
            style: AppTheme.sans(15, AppTheme.ink(ctx), weight: FontWeight.w700)),
        content: Text(
          '세끌이 제공하는 세액·환급액·수급액 계산은 법령·고시 정보를 바탕으로 한 참고용 추정치입니다.\n\n'
          '실제 세액·환급액·수급 여부는 개인 상황에 따라 달라질 수 있으며, 법적 효력이 없습니다. '
          '정확한 금액과 자격 요건은 홈택스·국세청·관할 기관 또는 세무사를 통해 반드시 확인하세요.\n\n'
          '세끌 이용에 따른 판단과 책임은 이용자 본인에게 있습니다.',
          style: AppTheme.sans(13, AppTheme.inkSecondary(ctx), height: 1.55),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('닫기',
                  style: AppTheme.sans(14, AppTheme.accentColor(ctx), weight: FontWeight.w700))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('설정', style: AppTheme.serif(22, ink, weight: FontWeight.w400, spacing: -0.3)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            const SizedBox(height: 8),
            _statusPlate(context),
            const SizedBox(height: 28),

            Text('일반'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 6),
            AppTheme.hairline(context),
            _notifRow(),
            AppTheme.hairline(context),
            _glyphRow(
              title: '세부 알림 설정',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          NotificationSettingsScreen(userType: widget.userType))),
            ),
            AppTheme.hairline(context),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeNotifier,
              builder: (context, mode, _) => _glyphRow(
                title: '화면 테마',
                trailingTag: _tag(context, themeModeLabel(mode)),
                onTap: _showThemePicker,
              ),
            ),
            AppTheme.hairline(context),

            if (!kIsWeb) ...[
              const SizedBox(height: 24),
              Text('보안'.toUpperCase(), style: AppTheme.label(context)),
              const SizedBox(height: 6),
              AppTheme.hairline(context),
              _glyphRow(
                title: '앱 잠금',
                trailing: Switch(
                  value: _appLockEnabled,
                  activeColor: AppTheme.accentColor(context),
                  onChanged: _toggleAppLock,
                ),
                onTap: () => _toggleAppLock(!_appLockEnabled),
              ),
              AppTheme.hairline(context),
            ],

            if (!kIsWeb) ...[
              const SizedBox(height: 24),
              Text('데이터'.toUpperCase(), style: AppTheme.label(context)),
              const SizedBox(height: 6),
              AppTheme.hairline(context),
              _glyphRow(
                title: '데이터 백업 (내보내기)',
                onTap: _exportBackup,
              ),
              AppTheme.hairline(context),
              _glyphRow(
                title: '데이터 복원 (가져오기)',
                onTap: _importBackup,
              ),
              AppTheme.hairline(context),
              _glyphRow(
                title: '오류 기록 내보내기',
                onTap: _exportErrorLogs,
              ),
              AppTheme.hairline(context),
            ],

            const SizedBox(height: 24),
            Text('법적 고지'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 6),
            AppTheme.hairline(context),
            _glyphRow(
              title: '개인정보처리방침',
              onTap: _showPrivacyPolicy,
            ),
            AppTheme.hairline(context),
            _glyphRow(
              title: '이용 안내 및 면책',
              onTap: _showLegalDisclaimer,
            ),
            AppTheme.hairline(context),
            const SizedBox(height: 14),

            // 되돌릴 수 없는 조작 — 상단 탐색 항목과 같은 무게로 읽히지 않도록 테두리로 분리.
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.colorDanger.withValues(alpha: 0.4), width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _glyphRow(
                title: '개인 세무 데이터 영구 파기',
                danger: true,
                noChevron: false,
                onTap: widget.onDestroyData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 앱 정보 요약판 — 이름·버전과 지금 상태(알림/데이터 수집)를 한 번에 보여주는
  /// 도면 제목란(title block) 모티프. 예전엔 맨 아래 "앱 정보" 행으로 묻혀 있던 정보를
  /// 화면 진입 즉시 확인하도록 끌어올렸다.
  Widget _statusPlate(BuildContext context) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final line = AppTheme.line(context);
    final versionText = _packageInfo != null
        ? 'v${_packageInfo!.version} (${_packageInfo!.buildNumber})'
        : '';

    return Container(
      decoration: BoxDecoration(border: Border.all(color: line, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Text('세끌', style: AppTheme.serif(19, ink, weight: FontWeight.w400, spacing: -0.3)),
                const Spacer(),
                Text(versionText, style: AppTheme.sans(AppTheme.tsSM, tert)),
              ],
            ),
          ),
          AppTheme.hairline(context),
          Row(
            children: [
              Expanded(
                child: _statusCell(context, label: '알림', value: _notificationsEnabled ? '켜짐' : '꺼짐'),
              ),
              Container(width: 1, height: 44, color: line),
              Expanded(
                child: _statusCell(context, label: '데이터 수집', value: '수동 입력'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusCell(BuildContext context, {required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTheme.label(context)),
          const SizedBox(height: 4),
          Text(value,
              style: AppTheme.sans(AppTheme.tsBase, AppTheme.ink(context), weight: FontWeight.w700)),
        ],
      ),
    );
  }

  /// 준비 중·잠금 등 부가 상태를 알리는 절제된 태그 — blueprintBadge의 무채색 톤.
  Widget _tag(BuildContext context, String text) {
    final tert = AppTheme.inkTertiary(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: tert, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(text, style: AppTheme.sans(10.5, tert, weight: FontWeight.w600)),
    );
  }

  Widget _notifRow() {
    return _glyphRow(
      title: '세금·가계부 알림',
      trailing: Switch(
        value: _notificationsEnabled,
        activeColor: AppTheme.accentColor(context),
        onChanged: (v) async {
          setState(() => _notificationsEnabled = v);
          await widget.onNotificationsChanged(v);
        },
      ),
      onTap: () async {
        final v = !_notificationsEnabled;
        setState(() => _notificationsEnabled = v);
        await widget.onNotificationsChanged(v);
      },
    );
  }

  /// 화면 테마 선택(시스템/라이트/다크) — 고르면 즉시 반영 + DB 영속화.
  Future<void> _showThemePicker() async {
    final current = themeModeNotifier.value;
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('화면 테마',
            style: AppTheme.sans(15, AppTheme.ink(ctx), weight: FontWeight.w700)),
        children: [
          for (final mode in ThemeMode.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, mode),
              child: Row(children: [
                Icon(
                  mode == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: mode == current
                      ? AppTheme.accentColor(ctx)
                      : AppTheme.inkTertiary(ctx),
                ),
                const SizedBox(width: 12),
                Text(themeModeLabel(mode), style: AppTheme.sans(14, AppTheme.ink(ctx))),
              ]),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    themeModeNotifier.value = selected;
    await dbService.setAppState('theme_mode', themeModeToDb(selected));
  }

  /// 설정 행 — 제목 한 줄 + 우측 컨트롤(스위치·태그·화살표)만 남긴 단순 리스트 행.
  Widget _glyphRow({
    required String title,
    required VoidCallback onTap,
    bool danger = false,
    bool noChevron = false,
    Widget? trailing,
    Widget? trailingTag,
  }) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final titleColor = danger ? AppTheme.colorDanger : ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: AppTheme.sans(15, titleColor, weight: FontWeight.w700, spacing: -0.2)),
          ),
          if (trailingTag != null) trailingTag,
          if (trailing != null)
            trailing
          else if (!danger && !noChevron)
            Icon(Icons.chevron_right_rounded, size: 20, color: tert),
        ]),
      ),
    );
  }
}
