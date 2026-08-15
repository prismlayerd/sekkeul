import 'package:flutter/material.dart';

/// 사용자가 고른 화면 테마(시스템/라이트/다크). 시작 시 DB(app_state 'theme_mode')에서
/// 로드되고, 설정에서 바꾸면 갱신된다.
///
/// **미설정 기본값은 라이트다.** 이 앱의 정체성은 종이 명세서라, 처음 여는 사람은
/// 종이를 봐야 한다. OS가 다크라고 먹지부터 보여주면 앱이 무엇인지 설명이 안 된다.
/// 시스템을 따르고 싶은 사람은 설정에서 '시스템'을 고르면 되고, 그 선택은 남는다.
/// (전역 ValueNotifier 패턴 — 앱 전체가 구독한다)
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

/// DB 문자열 → ThemeMode 복원. 저장된 값이 없으면(첫 실행) 라이트.
ThemeMode themeModeFromDb(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      return ThemeMode.light;
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
