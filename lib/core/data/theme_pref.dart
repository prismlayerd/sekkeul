import 'package:flutter/material.dart';

/// 사용자가 고른 화면 테마(시스템/라이트/다크). 시작 시 DB(app_state 'theme_mode')에서
/// 로드되고, 설정에서 바꾸면 갱신된다. 미설정 기본값은 시스템(OS 설정을 따라감).
/// (app_mode.dart의 appModeNotifier와 동일한 전역 ValueNotifier 패턴)
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

/// DB 문자열 → ThemeMode 복원 (미설정·미지값 시 시스템)
ThemeMode themeModeFromDb(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

/// ThemeMode → DB 저장용 문자열
String themeModeToDb(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

/// 설정 화면 표시 라벨
String themeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return '라이트';
    case ThemeMode.dark:
      return '다크';
    case ThemeMode.system:
      return '시스템';
  }
}
