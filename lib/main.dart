import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'core/data/db_helper.dart';
import 'core/data/theme_pref.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/app_lock_screen.dart';

import 'core/security/notification_helper.dart';
import 'core/security/app_lock_service.dart';
import 'core/navigation/app_route_observer.dart';

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
      // 알림 권한은 여기서 즉시 요청하지 않는다(U-1) — 첫 리마인더 화면 진입 또는
      // 설정에서 알림을 켤 때(맥락과 함께) 요청한다.
      await notificationHelper.init();
    }
    await dbService.initDatabase();

    // 저장된 화면 테마(시스템/라이트/다크) 복원 — 미설정 시 시스템(OS 따라감)
    themeModeNotifier.value =
        themeModeFromDb(await dbService.getAppState('theme_mode'));

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
    // 화면 테마는 설정에서 고른 값(시스템/라이트/다크)을 따른다 — themeModeNotifier로 즉시 반영.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) => MaterialApp(
        title: '세끌',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        navigatorObservers: [appRouteObserver],
        // U-3 — 시스템 글자 확대를 1.3배까지만 허용(그 이상은 촘촘한 도면형 레이아웃이
        // 깨질 수 있어 캡). 1.0~1.3 구간은 검증 완료.
        builder: (context, child) {
          final scaler = MediaQuery.textScalerOf(context).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: child!,
          );
        },
        home: const _AppLockGate(child: HomeScreen()),
      ),
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
