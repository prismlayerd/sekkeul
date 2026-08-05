import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _thousands = NumberFormat('#,###');

/// 금액을 천단위로 끊어 쓴다 — `1234567` → `1,234,567`.
///
/// 화면 74개가 각자 `final _fmt = NumberFormat('#,###')`를 들고 있었다.
/// 앱 어디서든 돈은 같은 모양으로 보여야 하니 한 곳에 둔다.
/// 이 파일에 있는 이유는 화면이 전부 이미 app_theme을 import하기 때문이다.
String comma(num v) => _thousands.format(v.round());

/// 금액 + '원'. 음수는 음수로 보여준다(차액·환급이 실제로 음수일 수 있다).
/// 0 이하를 '0원'으로 눌러야 하는 화면은 자기 화면에서 가드를 건다.
String won(num v) => '${comma(v)}원';

/// 세끌 디자인 시스템 v4.0 — Architectural Blueprint
/// ─────────────────────────────────────────────────────────
/// • 제목: DM Serif Display (+ Noto Serif KR 한글 대체) — 차갑고 정밀한 세리프
/// • 본문: DM Sans — 공학 도면 같은 산세리프
/// • 라벨: 극소형 + 자간 극대 (대문자 도면 주석)
/// • 구조: 카드·그림자 제로, 1px 선이 섹션을 가름, 여백이 호흡
/// • 라이트 #F8F7F5 콘크리트 오프화이트 / 다크 #0D0D0D 무광 블랙
class AppTheme {
  // ──────────────────────────────────────────────
  // 글꼴 패밀리 (assets/fonts/ 번들, pubspec fonts: 등록)
  // ──────────────────────────────────────────────
  static const String serifFamily   = 'DM Serif Display';
  static const String serifKrFamily = 'Noto Serif KR';
  static const String sansFamily    = 'DM Sans';

  /// 세리프 제목 (라틴/숫자=DM Serif, 한글=Noto Serif KR 대체)
  static TextStyle serif(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double spacing = -0.5,
    double height = 1.15,
  }) =>
      TextStyle(
        fontFamily: serifFamily,
        fontFamilyFallback: [serifKrFamily],
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: spacing,
        height: height,
      );

  /// 산세리프 본문 (한글은 시스템 CJK 대체)
  static TextStyle sans(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
    double height = 1.5,
  }) =>
      TextStyle(
        fontFamily: sansFamily,
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: spacing,
        height: height,
      );

  /// 도면 주석 라벨 — 극소형 + 자간 극대
  static TextStyle label(BuildContext context, {Color? color}) {
    final c = color ?? inkTertiary(context);
    return TextStyle(
      fontFamily: sansFamily,
      fontSize: 11,
      color: c,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.0,
      height: 1.2,
    );
  }

  // ──────────────────────────────────────────────
  // 팔레트 — Light (콘크리트 오프화이트)
  // ──────────────────────────────────────────────
  static const Color lightBackground   = Color(0xFFF8F7F5); // 콘크리트 오프화이트
  static const Color lightSurface       = Color(0xFFFFFFFF); // 입력/필드 표면
  static const Color lightInk           = Color(0xFF161513); // 잉크 (주 텍스트)
  static const Color lightInkSecondary  = Color(0xFF5E5C57); // 부 텍스트 (가독성↑)
  static const Color lightInkTertiary   = Color(0xFF6B6862); // 라벨/힌트 (대비 ~4.6:1, WCAG AA)
  static const Color lightLine          = Color(0xFFDCD8D0); // 1px 헤어라인
  static const Color lightLineStrong    = Color(0xFFC7C2B8); // 강조 라인
  static const Color lightAccent        = Color(0xFF1F5AE0); // 도면 블루
  static const Color lightAccentSoft    = Color(0xFFE8EEFB); // 블루 틴트

  // ──────────────────────────────────────────────
  // 팔레트 — Dark (무광 블랙)
  // ──────────────────────────────────────────────
  static const Color darkBackground     = Color(0xFF0D0D0D); // 무광 블랙
  static const Color darkSurface         = Color(0xFF1A1916); // 입력/필드 표면
  static const Color darkInk             = Color(0xFFF2F0EC); // 잉크 (주 텍스트)
  static const Color darkInkSecondary    = Color(0xFF9D9A93); // 부 텍스트 (가독성↑)
  static const Color darkInkTertiary     = Color(0xFF6B6862); // 라벨/힌트
  static const Color darkLine            = Color(0xFF242220); // 1px 헤어라인
  static const Color darkLineStrong      = Color(0xFF34312D); // 강조 라인
  static const Color darkAccent          = Color(0xFF6A93F0); // 도면 블루
  static const Color darkAccentSoft      = Color(0xFF16213B); // 블루 틴트

  // ──────────────────────────────────────────────
  // 타입 스케일 상수 — 이 값 외 사용 금지
  // ──────────────────────────────────────────────
  static const double tsXS   = 11;   // 마이크로 라벨 / legend / eyebrow
  static const double tsSM   = 12;   // caption / meta / 부차 정보
  static const double tsMD   = 13;   // compact UI / 탭 / 날짜 숫자
  static const double tsBase = 14;   // 기본 본문 / 목록 항목
  static const double tsLG   = 15;   // 섹션 제목 / CTA
  static const double tsXL   = 17;   // sans UI 헤더 (제목용 sans)
  static const double serifSM = 17;  // 인라인 serif / 다이얼로그 헤더
  static const double serifMD = 22;  // AppBar 제목
  static const double serifLG = 28;  // 섹션 헤딩 / 빈 상태 제목
  static const double serifXL = 34;  // 표시 숫자

  // 시맨틱 (무광 톤에 맞춘 절제된 채도)
  static const Color colorSuccess = Color(0xFF2FA37A);
  static const Color colorWarning = Color(0xFFD69A3A);
  static const Color colorDanger  = Color(0xFFD9503F);
  static const Color colorInfo    = Color(0xFF1F5AE0);

  // ──────────────────────────────────────────────
  // 컨텍스트 헬퍼
  // ──────────────────────────────────────────────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color ink(BuildContext c)          => isDark(c) ? darkInk : lightInk;
  static Color inkSecondary(BuildContext c) => isDark(c) ? darkInkSecondary : lightInkSecondary;
  static Color inkTertiary(BuildContext c)  => isDark(c) ? darkInkTertiary : lightInkTertiary;
  static Color line(BuildContext c)         => isDark(c) ? darkLine : lightLine;
  static Color lineStrong(BuildContext c)   => isDark(c) ? darkLineStrong : lightLineStrong;
  static Color surface(BuildContext c)      => isDark(c) ? darkSurface : lightSurface;
  static Color accentColor(BuildContext c)  => isDark(c) ? darkAccent : lightAccent;
  static Color accentSoft(BuildContext c)   => isDark(c) ? darkAccentSoft : lightAccentSoft;
  static Color backgroundColor(BuildContext c) => isDark(c) ? darkBackground : lightBackground;

  /// 1px 수평 헤어라인 — 페이지를 가르는 구조선
  static Widget hairline(BuildContext context, {double height = 1, Color? color}) =>
      Container(height: height, color: color ?? line(context));

  // ──────────────────────────────────────────────
  // TextTheme 빌더
  // ──────────────────────────────────────────────
  static TextTheme _buildTextTheme(Color ink, Color secondary, Color tertiary) {
    return TextTheme(
      displayLarge:  serif(52, ink, weight: FontWeight.w400, spacing: -1.5, height: 1.0),
      displayMedium: serif(40, ink, weight: FontWeight.w400, spacing: -1.0, height: 1.05),
      headlineLarge: serif(28, ink, weight: FontWeight.w400, spacing: -0.5, height: 1.15),
      headlineMedium: serif(22, ink, weight: FontWeight.w400, spacing: -0.3, height: 1.2),
      headlineSmall: serif(19, ink, weight: FontWeight.w400, spacing: -0.2, height: 1.25),
      titleLarge:  sans(17, ink, weight: FontWeight.w700, spacing: -0.2),
      titleMedium: sans(15, ink, weight: FontWeight.w600),
      titleSmall:  sans(13, secondary, weight: FontWeight.w600),
      bodyLarge:  sans(15, ink, weight: FontWeight.w400, height: 1.6),
      bodyMedium: sans(14, secondary, weight: FontWeight.w400, height: 1.55),
      bodySmall:  sans(12.5, tertiary, weight: FontWeight.w400, height: 1.45),
      labelLarge:  sans(14, ink, weight: FontWeight.w600),
      labelMedium: sans(13, secondary, weight: FontWeight.w500),
      labelSmall:  sans(11, tertiary, weight: FontWeight.w600, spacing: 2.0, height: 1.2),
    );
  }

  // ──────────────────────────────────────────────
  // Light Theme
  // ──────────────────────────────────────────────
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    primaryColor: lightAccent,
    cardColor: lightSurface,
    canvasColor: lightBackground,

    colorScheme: const ColorScheme.light(
      primary: lightAccent,
      primaryContainer: lightAccentSoft,
      secondary: lightAccent,
      surface: lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightInk,
      outline: lightLine,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: lightBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      iconTheme: const IconThemeData(color: lightInk),
      titleTextStyle: serif(22, lightInk, weight: FontWeight.w400, spacing: -0.3),
    ),

    textTheme: _buildTextTheme(lightInk, lightInkSecondary, lightInkTertiary),

    dividerTheme: const DividerThemeData(color: lightLine, thickness: 1, space: 1),
    dividerColor: lightLine,
    iconTheme: const IconThemeData(color: lightInkSecondary, size: 20),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      hintStyle: sans(15, lightInkTertiary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: lightLine)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: lightLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: lightAccent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: lightBackground,
      selectedItemColor: lightInk,
      unselectedItemColor: lightInkTertiary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: sans(10, lightInk, weight: FontWeight.w600, spacing: 0.5),
      unselectedLabelStyle: sans(10, lightInkTertiary, weight: FontWeight.w500, spacing: 0.5),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightInk,
        foregroundColor: lightBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: sans(16, lightBackground, weight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(vertical: 18),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: lightAccent,
        textStyle: sans(14, lightAccent, weight: FontWeight.w600),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: lightAccent,
      linearTrackColor: lightLine,
    ),
  );

  // ──────────────────────────────────────────────
  // Dark Theme
  // ──────────────────────────────────────────────
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    primaryColor: darkAccent,
    cardColor: darkSurface,
    canvasColor: darkBackground,

    colorScheme: const ColorScheme.dark(
      primary: darkAccent,
      primaryContainer: darkAccentSoft,
      secondary: darkAccent,
      surface: darkSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkInk,
      outline: darkLine,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      iconTheme: const IconThemeData(color: darkInk),
      titleTextStyle: serif(22, darkInk, weight: FontWeight.w400, spacing: -0.3),
    ),

    textTheme: _buildTextTheme(darkInk, darkInkSecondary, darkInkTertiary),

    dividerTheme: const DividerThemeData(color: darkLine, thickness: 1, space: 1),
    dividerColor: darkLine,
    iconTheme: const IconThemeData(color: darkInkSecondary, size: 20),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      hintStyle: sans(15, darkInkTertiary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: darkLine)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: darkLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: darkAccent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkBackground,
      selectedItemColor: darkInk,
      unselectedItemColor: darkInkTertiary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: sans(10, darkInk, weight: FontWeight.w600, spacing: 0.5),
      unselectedLabelStyle: sans(10, darkInkTertiary, weight: FontWeight.w500, spacing: 0.5),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkInk,
        foregroundColor: darkBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: sans(16, darkBackground, weight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(vertical: 18),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: darkAccent,
        textStyle: sans(14, darkAccent, weight: FontWeight.w600),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: darkAccent,
      linearTrackColor: darkLine,
    ),
  );

  // ──────────────────────────────────────────────
  // 공통 유틸 (하위호환 — 기존 화면이 참조)
  // ──────────────────────────────────────────────

  /// 기본 표면 — 에디토리얼: 그림자 0, 1px 헤어라인, 거의 직각
  static BoxDecoration getCardDecoration(
    BuildContext context, {
    double borderRadius = 4.0,
    bool elevated = false,
  }) {
    return BoxDecoration(
      color: surface(context),
      borderRadius: BorderRadius.circular(borderRadius.clamp(0.0, 6.0)),
      border: Border.all(color: line(context), width: 1),
    );
  }

  /// 도면 주석 박스 — 파란 테두리, 채움 최소
  static BoxDecoration getAccentCardDecoration(
    BuildContext context, {
    double borderRadius = 4.0,
  }) {
    return BoxDecoration(
      color: accentSoft(context),
      borderRadius: BorderRadius.circular(borderRadius.clamp(0.0, 6.0)),
      border: Border.all(color: accentColor(context), width: 1),
    );
  }

  /// 기능 패널 — 표면색 채움 + 1px 테두리 + 모서리 4 + 패딩. 그림자 0(블루프린트).
  /// 홈의 나열식 섹션을 하나의 카드로 묶어 "어디부터 어디까지가 한 기능인지" 보이게 한다.
  static Widget panel(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    bool accent = false,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: accent ? accentSoft(context) : surface(context),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accent ? accentColor(context) : line(context), width: 1),
      ),
      child: child,
    );
  }

  /// 파란 테두리 도면 배지 (예: "5월 신고")
  static Widget blueprintBadge(BuildContext context, String text) {
    final accent = accentColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: accent, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: sansFamily,
          fontSize: 10.5,
          color: accent,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
