import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'core/data/db_helper.dart';
import 'core/data/app_mode.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/app_lock_screen.dart';

import 'core/security/notification_helper.dart';
import 'core/security/app_lock_service.dart';

import 'ui/theme/app_theme.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      dbService.insertErrorLog(
        details.exceptionAsString(),
        details.stack?.toString() ?? '',
      );
    };
    if (!kIsWeb) {
      await notificationHelper.init();
      await notificationHelper.requestPermissions();
    }
    await dbService.initDatabase();

    // 저장된 데이터 수집 모드(제1/제2) 복원
    final profile = await dbService.getProfile();
    appModeNotifier.value = appModeFromDb(profile?['data_mode'] as String?);

    runApp(const SeculApp());
  }, (error, stack) {
    dbService.insertErrorLog(error.toString(), stack.toString());
  });
}

/// 세끌 어플리케이션 메인 진입점
class SeculApp extends StatelessWidget {
  const SeculApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '세끌',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const _AppLockGate(child: HomeScreen()),
    );
  }
}

/// S-3 앱 잠금 — 백그라운드에서 돌아올 때(resumed)만 잠금을 요구한다.
/// 최초 실행(cold start)은 "resumed" 이전에 "paused"를 거치지 않으므로 잠금 없이 진입한다.
class _AppLockGate extends StatefulWidget {
  final Widget child;
  const _AppLockGate({required this.child});

  @override
  State<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<_AppLockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    if (!kIsWeb) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      _maybeLock();
    }
  }

  Future<void> _maybeLock() async {
    final enabled = await appLockService.isEnabled();
    if (enabled && mounted) setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return AppLockScreen(onUnlocked: () => setState(() => _locked = false));
    }
    return widget.child;
  }
}
