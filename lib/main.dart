import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'core/data/db_helper.dart';
import 'core/data/text_scale_pref.dart';
import 'core/data/theme_pref.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/app_lock_screen.dart';

import 'core/security/notification_helper.dart';
import 'core/security/app_lock_service.dart';
import 'core/navigation/app_route_observer.dart';

import 'ui/components/splash_tear.dart';
import 'ui/theme/app_theme.dart';

/// 앱 시작 준비가 실패한 사유. DB가 안 열린 기기에서는 오류 기록 테이블에
/// 못 적으므로 여기 들고 있다가 설정 화면에서 내보낼 때 함께 넘긴다.
String? startupError;

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
    // 준비가 실패해도 화면은 띄운다. 예전엔 이 셋 중 하나만 던져도 runApp에
    // 닿지 못해 앱이 통째로 안 떴다 — 기기마다 흰 화면이 되던 자리다.
    try {
      if (!kIsWeb) {
        // 알림 권한은 여기서 즉시 요청하지 않는다(U-1) — 첫 리마인더 화면 진입 또는
        // 설정에서 알림을 켤 때(맥락과 함께) 요청한다.
        await notificationHelper.init();
      }
      await dbService.initDatabase();

      // 저장된 화면 테마(시스템/라이트/다크) 복원 — 미설정 시 시스템(OS 따라감)
      themeModeNotifier.value =
          themeModeFromDb(await dbService.getAppState('theme_mode'));
      // 저장된 글자 크기 복원 — 미설정 시 기존 크기(제일 작은 단계).
      textScaleNotifier.value =
          textScaleFromDb(await dbService.getAppState('text_scale'));
    } catch (e, stack) {
      // DB가 안 열린 기기에서는 이 기록도 실패한다 — 그때는 남길 자리가 없다.
      dbService.insertErrorLog('[시작 실패] $e', stack.toString());
    }

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
        // 글자 크기 = **기기 설정 x 앱 설정**, 상한은 maxTextScale.
        //
        // 기기 설정만 따르던 때는 "글자가 작다"는 의견에 답할 방법이 없었다.
        // 안드로이드 글꼴 크기를 건드릴 줄 모르거나, 다른 앱까지 커지는 게 싫어
        // 안 건드리는 사람이 많다. 앱 안에서 이 앱만 키울 수 있어야 한다.
        //
        // 상한은 text_scale_pref의 상수 하나를 넘침 테스트와 같이 본다 —
        // 양쪽에 따로 박아 두면 한쪽만 올라가 검사를 빠져나간다.
        builder: (context, child) {
          final system = MediaQuery.textScalerOf(context).scale(1.0);
          return ValueListenableBuilder<double>(
            valueListenable: textScaleNotifier,
            builder: (context, step, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler:
                    TextScaler.linear(effectiveTextScale(system, step))),
            // 종이 바탕은 앱 **맨 밑**에 한 장만 깐다. 위에 덮으면 버튼·입력창·
            // 아이콘 위로 결이 지나가 표면이 지저분해진다. 화면들의 Scaffold는
            // 배경이 투명이라(app_theme) 이 한 장이 그대로 비친다.
            //
            // 물결 뜯김은 그 위에 한 번만 얹힌다. 여기(빌더)에 두면 콜드 스타트
            // 한 번만 만들어지고, 화면을 옮겨 다니거나 백그라운드에서 돌아와도
            // 다시 재생되지 않는다.
            child: Stack(children: [
              AppTheme.paperBackdrop(context, child: child!),
              const SplashTear(),
            ]),
          ),
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
