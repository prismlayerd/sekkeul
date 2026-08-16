import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'wave.dart';

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

/// 세끌 디자인 시스템 v5.2 — Receipt (monospace, neutral gray, textured)
/// ─────────────────────────────────────────────────────────
/// 앱이 다루는 것이 수입과 지출이라 **명세서**의 문법을 그대로 쓴다.
/// • 글꼴: IBM Plex Mono (+ Nanum Gothic Coding 한글 대체) — 전부 고정폭
/// • 라벨: 소형 + 자간 극대 (인쇄된 전표 주석)
/// • 구조: 카드·그림자 제로. 점선이 절을 가르고, 실선은 소계에만
/// • 라이트 #EFEFEF 종이 / 다크 #141414 먹지 — 색조 없는 중성 회색
/// • 바탕: 구겨진 종이 사진 한 장을 앱 **맨 밑**에 깐다(paperBackdrop).
///   Scaffold·AppBar·하단바는 배경이 투명이라 이 한 장이 그대로 비친다 —
///   버튼·입력창·아이콘 위로는 결이 지나가지 않는다.
///
/// **색을 쓰지 않는다.** 영수증은 흑백이고, 그것이 이 테마의 규율이다.
/// 강조는 색이 아니라 잉크 농도·굵기·테두리·반전으로 만든다.
///
/// 예외는 셋뿐이다: 성공·경고·위험. 이건 장식이 아니라 **뜻**이라 남긴다.
/// 다만 종이 위에서 튀지 않게 채도를 낮췄다.
///
/// v5.1에서 세리프(DM Serif + Noto Serif KR)를 버리고 전부 고정폭으로 갔다.
/// 영수증은 타자기로 찍힌 문서지 조판된 책이 아니다. 덤으로 23MB짜리
/// NotoSerifKR이 빠져 APK가 ~20MB 줄었다.
class AppTheme {
  // ──────────────────────────────────────────────
  // 글꼴 패밀리 (assets/fonts/ 번들, pubspec fonts: 등록)
  // ──────────────────────────────────────────────
  static const String monoFamily   = 'IBM Plex Mono';
  static const String monoKrFamily = 'Nanum Gothic Coding';

  /// 화면 89개가 `serif(...)`로 부른다. 이름만 남기고 알맹이는 고정폭이다 —
  /// 이름을 바꾸면 진짜 변경이 diff에 묻힌다.
  static const String serifFamily = monoFamily;

  /// **본문은 고정폭이 아니다.**
  ///
  /// null이면 Flutter가 기기의 한글 UI 글꼴을 쓴다(안드로이드 Noto Sans KR,
  /// iOS Apple SD Gothic Neo). 왜 비워 두는지는 [sans] 주석에 적었다.
  /// 번들 글꼴로 가려면 여기 한 줄만 채우면 된다 — 호출부는 안 건드린다.
  static const String? sansFamily = null;

  /// 고정폭에 음수 자간을 주면 글자가 서로 올라탄다. 세리프 시절 호출부
  /// 90여 곳이 `spacing: -1.5` 같은 값을 넘기고 있어, 부르는 쪽을 전부
  /// 고치는 대신 여기서 한 번 막는다.
  static double _track(double v) => v < 0 ? 0 : v;

  /// 표시용 — 금액·제목. (구 `serif`)
  static TextStyle display(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w700,
    double spacing = 0,
    double height = 1.15,
  }) =>
      TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: const [monoKrFamily],
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: _track(spacing),
        height: height,
        fontFeatures: _tabular,
      );

  /// 세리프 시절 이름. 알맹이는 [display]와 같다.
  static TextStyle serif(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w700,
    double spacing = 0,
    double height = 1.15,
  }) =>
      display(size, color, weight: weight, spacing: spacing, height: height);

  /// 숫자를 고정폭으로 — 자릿수가 세로로 맞아야 명세서가 된다.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// 본문 — **여기만 고정폭이 아니다.**
  ///
  /// 테스터 의견이 "홈에서 텍스트가 잘 안 보인다"로 모였다. 재 보니 명암은
  /// 문제가 아니었다 — 종이 사진의 깊은 주름 위에서도 본문 8.5:1로 AA를
  /// 통과한다. 원인은 **고정폭 한글**이었다. 고정폭은 라틴 글자 폭에 한글을
  /// 밀어 넣어서, 받침이 많은 글자일수록 획이 뭉치고 자간이 균일해 낱말
  /// 경계가 안 잡힌다. 홈 텍스트의 75%가 12~13px 고정폭 한글이었다.
  ///
  /// 크기를 키우는 건 답이 아니다 — 화면만 길어지고(테스터 불만 2번) 획이
  /// 뭉치는 건 그대로다. 글꼴을 바꾼다.
  ///
  /// **영수증 느낌은 [display]와 [label]이 지킨다.** 금액·표시 숫자는 고정폭
  /// 그대로고, 절 머리(`01 · 이번 달 수입`)의 자간 넓은 전표 주석도 그대로다.
  /// 흉내내는 건 타자기지 본문 조판이 아니다.
  ///
  /// 기본 굵기 **w500**은 유지한다. 종이 결 위에서 w400은 바탕에 눌린다.
  ///
  /// [fontFeatures]의 tabular도 유지한다 — `sans()`로 찍는 금액(리더 행의 값
  /// 같은 것)이 아직 있어서 자릿수가 세로로 맞아야 한다.
  static TextStyle sans(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w500,
    double spacing = 0,
    double height = 1.5,
    TextDecoration? decoration,
  }) =>
      TextStyle(
        fontFamily: sansFamily,
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: _track(spacing),
        height: height,
        fontFeatures: _tabular,
        // 파란색이 없으니 링크는 밑줄로 산다.
        decoration: decoration,
        decorationColor: color,
      );

  /// 전표 주석 라벨 — 소형 + 자간 극대.
  /// 11 → 12. 한글은 같은 픽셀에서 라틴보다 빽빽해 11에서 획이 뭉갠다.
  /// 작게 보이고 싶으면 크기가 아니라 잉크를 옅게, 자간을 넓게 쓴다.
  ///
  /// **여기는 고정폭으로 남는다.** 본문은 산세리프로 갔지만(→ [sans]) 절
  /// 머리는 다르다 — 자간을 넓힌 고정폭 소형 대문자가 곧 전표의 문법이고,
  /// 짧아서 읽기 부담도 없다. 컨셉을 지키는 자리다.
  static TextStyle label(BuildContext context, {Color? color}) {
    final c = color ?? inkTertiary(context);
    return TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: const [monoKrFamily],
      fontSize: tsXS,
      color: c,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.0,
      height: 1.2,
      fontFeatures: _tabular,
    );
  }

  // ──────────────────────────────────────────────
  // 팔레트 — Light (종이)
  // ──────────────────────────────────────────────
  // 바탕은 **책상**, 표면은 그 위에 놓인 **전표**다. 전표가 더 밝다.
  //
  // v5.2에서 따뜻한 미색을 걷고 **중성 회색**으로 갔다. 색조가 남아 있으면
  // "베이지 테마"로 읽히는데, 이 앱이 흉내내는 건 특정 색의 종이가 아니라
  // 잉크와 종이라는 두 재료뿐이다. 회색은 색이 아니라 농도라 그 규율에 맞는다.
  static const Color lightBackground   = Color(0xFFE2E2E2); // 책상 (바탕)
  static const Color lightSurface       = Color(0xFFEFEFEF); // 전표 — 순백을 쓰지 않는다
  static const Color lightInk           = Color(0xFF1F1F1F); // 잉크 (주 텍스트) 종이 14.3:1
  static const Color lightInkSecondary  = Color(0xFF4A4A4A); // 부 텍스트 7.7:1
  // 라벨은 전표(#EFEFEF)와 바탕(#E2E2E2) 양쪽에 얹힌다. **어두운 쪽 기준**으로
  // 잡아야 둘 다 AA다 — 바탕 위 5.6:1, 전표 위 6.4:1.
  static const Color lightInkTertiary   = Color(0xFF565656); // 라벨/힌트
  // 바탕 사진의 깊은 주름이 luma 174(#AEAEAE)까지 내려간다. 선을 그보다 옅게
  // 두면 주름과 같은 농도가 돼 구간구간 사라진다 — 주름보다 진하게 잡는다.
  static const Color lightLine          = Color(0xFFB6B6B6); // 1px 헤어라인 · 컨트롤 테두리
  static const Color lightLineStrong    = Color(0xFF8C8C8C); // 강조 라인 · 절취선
  static const Color lightAccent        = Color(0xFF1F1F1F); // 강조 = 잉크. 색이 아니라 농도로 만든다
  // 바탕 위에서도 채워진 게 보여야 한다 — 바탕보다 확실히 어둡게 잡는다.
  static const Color lightAccentSoft    = Color(0xFFDADADA); // 잉크가 앉은 자리(반전 배경)
  // **이 앱의 유일한 색.**
  //
  // 종이 달력의 빨간날은 400년 된 관습이라 설명이 필요 없다. 농도로 갈라 봤지만
  // 회색 다섯 단계 안에서 한 단계 더 옅은 것은 "쉬는 날"로 읽히지 않았다.
  // 어두운 벽돌빛으로 낮춰 잡았다 — 종이 사진의 가장 짙은 주름(#BABABA)
  // 위에서도 4.8:1로 AA를 넘고, 순수한 빨강처럼 튀지 않는다.
  // **달력 뷰의 날짜에만 쓴다.** 다른 데로 번지면 흑백이라는 규율이 무너진다.
  static const Color lightHoliday       = Color(0xFF822618);

  // ──────────────────────────────────────────────
  // 팔레트 — Dark (먹지 carbon copy)
  // ──────────────────────────────────────────────
  static const Color darkBackground     = Color(0xFF1E1E1E); // 먹지
  /// 다크에서 바탕 사진에 곱하는 색. #141414로 곱하면 종이가 13~20 구간에
  /// 눌려 결이 사라진다 — 33~48로 올려 주름이 보이게 둔다.
  static const Color darkPaper          = Color(0xFF303030);
  static const Color darkSurface         = Color(0xFF1C1C1C); // 입력/필드 표면
  static const Color darkInk             = Color(0xFFE8E8E8); // 잉크 (주 텍스트)
  static const Color darkInkSecondary    = Color(0xFF9A9A9A); // 부 텍스트
  static const Color darkInkTertiary     = Color(0xFF8C8C8C); // 라벨/힌트 (대비 ~4.9:1)
  static const Color darkLine            = Color(0xFF2C2C2C); // 1px 헤어라인
  static const Color darkLineStrong      = Color(0xFF444444); // 강조 라인 · 절취선
  static const Color darkAccent          = Color(0xFFE8E8E8); // 강조 = 잉크
  static const Color darkAccentSoft      = Color(0xFF292929); // 잉크가 앉은 자리
  static const Color darkHoliday         = Color(0xFFE08A7D); // 먹지 위 5.2:1

  // ──────────────────────────────────────────────
  // 타입 스케일 상수 — 이 값 외 사용 금지
  //
  // v5에서 본문 15를 기준점으로 다시 잡았다. **바닥을 올리고 천장을 내린다.**
  // 12 밑은 스케일에 두지 않는다 — 읽히지 않는 크기는 있을 이유가 없다.
  // 본문이 올라온 만큼 표시 숫자를 34→30으로 내려 위계 간격을 좁혔다.
  // ──────────────────────────────────────────────
  static const double tsXS   = 12;   // 마이크로 라벨 / legend / eyebrow
  static const double tsSM   = 13;   // caption / meta / 부차 정보
  static const double tsMD   = 14;   // compact UI / 탭 / 날짜 숫자
  static const double tsBase = 15;   // 기본 본문 / 목록 항목 — 기준점
  static const double tsLG   = 17;   // 섹션 제목 / CTA
  static const double tsXL   = 19;   // sans UI 헤더 (제목용 sans)
  static const double serifSM = 19;  // 인라인 serif / 다이얼로그 헤더
  static const double serifMD = 21;  // AppBar 제목
  static const double serifLG = 25;  // 섹션 헤딩 / 빈 상태 제목
  static const double serifXL = 30;  // 표시 숫자

  /// 달력 날짜칸의 금액 줄. 종전 8.5는 "있다고 표시만 하는 크기"였다.
  static const double tsLane = 10;

  /// 하단 네비 라벨. 항상 떠 있는데 제일 작았다.
  static const double tsNav = 12;

  /// 홈 수입 히어로. 44는 본문 15 옆에서 과했다.
  static const double tsHero = 36;

  // 시맨틱 — 종이 위에서 튀지 않게 채도를 낮췄다. 장식이 아니라 뜻이라 남긴다.
  static const Color colorSuccess = Color(0xFF3F7358);
  static const Color colorWarning = Color(0xFF7F5E1E); // 종이 위 4.6:1 — 9A7328은 3.7:1로 AA 미달
  static const Color colorDanger  = Color(0xFFA34434);
  static const Color colorInfo    = Color(0xFF1F1F1F); // 안내는 색이 아니라 잉크다

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
  /// 빨간날 — 일요일과 공휴일. **달력 뷰 전용**([lightHoliday] 주석 참조).
  static Color holiday(BuildContext c)      => isDark(c) ? darkHoliday : lightHoliday;
  static Color backgroundColor(BuildContext c) => isDark(c) ? darkBackground : lightBackground;


  // ──────────────────────────────────────────────
  // 전표 부품 — 영수증의 조판 문법을 위젯으로
  // ──────────────────────────────────────────────

  /// 전표 표면. 바탕(책상)보다 밝은 종이 한 장에 도트 결을 깔고 그 위에 인쇄한다.
  static Widget slip(BuildContext context, {required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      color: surface(context),
      child: CustomPaint(
        painter: _SlipTexturePainter(line(context)),
        child: Padding(
          padding: padding ?? const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: child,
        ),
      ),
    );
  }

  /// 양쪽에 선이 뻗는 머리줄 — `──── TAX & LEDGER · NO. XIV ────`
  static Widget ruleLabel(BuildContext context, String text) {
    final c = inkTertiary(context);
    return Row(children: [
      Expanded(child: Container(height: 1, color: lineStrong(context))),
      // 라벨은 제 폭을 그대로 쓰고 선이 남는 자리를 나눠 갖는다. Flexible로 감싸면
      // 양옆 Expanded와 셋이서 남는 폭을 1:1:1로 갈라 멀쩡한 글자가 잘린다.
      // 길이 가드는 위젯이 아니라 small_screen_overflow_test가 맡는다 —
      // 자간 2.0짜리 라벨은 360px에서 20자 남짓이 한계다.
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(text, maxLines: 1, style: label(context, color: c)),
      ),
      Expanded(child: Container(height: 1, color: lineStrong(context))),
    ]);
  }

  /// 절 머리 — `01 · 이번 달 수입`. 명세서는 순서가 있는 문서라 번호가 뜻을 가진다.
  ///
  /// [no]가 null이면 번호를 빼고 찍는다. 데이터가 있어야만 나오는 절(예: 예상 환급)에
  /// 번호를 주면, 그 절이 빠진 화면에서 번호가 `01 02 04`로 건너뛰어 고장으로 보인다.
  ///
  /// Row가 아니라 **한 덩이 Text**다 — 아코디언 헤더처럼 이미 Row인 자리에
  /// 그대로 끼울 수 있어야 하고, 좁으면 한국어 꼬리부터 잘려야 한다.
  static Widget sectionHead(BuildContext context, String? no, String kr) {
    // 번호와 이름 사이는 붙여 둔다. 라벨 자간이 2.0이라 여기서 공백까지 넉넉히
    // 주면 `0 1   ·   이번 달 수입`처럼 벌어져 한 덩이로 안 읽힌다.
    final labelStyle = label(context).copyWith(letterSpacing: 1.0);
    return Text.rich(
      TextSpan(children: [
        // 번호가 없으면 앞 공백도 없어야 한다 — 한 칸이 들어가면 그 줄만
        // 들여쓰기된 것처럼 보인다(배너 라벨이 본문보다 밀려 보이던 원인).
        if (no != null)
          TextSpan(text: '$no · ', style: labelStyle.copyWith(color: inkTertiary(context))),
        TextSpan(text: kr, style: sans(tsSM, inkSecondary(context))),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 큰 금액 — 왼쪽 정렬, `원`은 작게 붙는다. 명세서의 숫자는 왼쪽에서 읽힌다.
  static Widget amount(BuildContext context, String digits,
      {double size = serifXL, Color? color, String unit = '원'}) {
    final c = color ?? ink(context);
    // 제 폭만 차지한다 — 그래야 Align(right)으로 오른쪽 끝에 붙일 수 있다.
    // (max로 두면 Row가 줄을 다 먹어 정렬이 안 먹는다.)
    return Row(crossAxisAlignment: CrossAxisAlignment.baseline,
      mainAxisSize: MainAxisSize.min,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(child: Text(digits, overflow: TextOverflow.ellipsis,
            style: display(size, c, spacing: 0.5, height: 1.05))),
        Text(unit, style: sans(size * 0.45, c, weight: FontWeight.w500)),
      ]);
  }

  /// 도장 — 회전한 테두리 상자. 종이에 찍힌 것처럼 살짝 기운다.
  static Widget stamp(BuildContext context, String line1, String line2) {
    final c = inkSecondary(context);
    return Transform.rotate(
      angle: -0.045,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: c, width: 1)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(line1, style: label(context, color: c)),
          Text(line2, style: label(context, color: c)),
        ]),
      ),
    );
  }

  /// 1px 수평 헤어라인 — 페이지를 가르는 구조선
  static Widget hairline(BuildContext context, {double height = 1, Color? color}) =>
      Container(height: height, color: color ?? line(context));

  /// 바탕에 쓸 종이 사진들. 앱을 켤 때마다 이 중 한 장이 뽑힌다.
  /// 파일을 `assets/textures/`에 넣고 이름만 여기 더하면 된다
  /// (디렉터리째 pubspec에 등록돼 있어 따로 선언할 게 없다).
  static const List<String> papers = [
    'assets/textures/paper_1.jpg',
    'assets/textures/paper_2.jpg',
    'assets/textures/paper_3.jpg',
  ];

  /// 이번 실행에 뽑힌 종이. **한 번만** 정한다 — 빌드마다 다시 뽑으면
  /// 화면을 그릴 때마다 종이가 바뀐다.
  static final String paper = papers[Random().nextInt(papers.length)];

  /// 종이 바탕 — 앱 **맨 밑**에 한 장만 깔린다(main.dart의 MaterialApp.builder).
  ///
  /// 결은 종이의 성질이지 UI의 성질이 아니다. 위에 덮으면 버튼·입력창·아이콘까지
  /// 결이 지나가 표면이 지저분해진다. 그래서 화면 **뒤**에 깔고, Scaffold·AppBar·
  /// 하단바의 배경을 투명으로 비워 이 한 장이 비쳐 보이게 한다.
  ///
  /// 사진을 늘리지 않고 `cover`로 채운다 — 구겨진 결은 규칙이 없어서 타일로
  /// 반복하면 같은 주름이 되풀이되는 게 바로 보인다.
  /// 라이트에서는 종이를 흰 쪽으로 살짝 눌러 깐다(opacity 0.82). 원본 그대로면
  /// 깊은 주름이 헤어라인만큼 진해져 글자와 선이 결에 묻힌다.
  /// 다크에서는 같은 사진을 [darkPaper]로 곱한다 — 주름은 남고 종이만 검어진다.
  /// 사진은 **자기 레이어**에 따로 둔다.
  ///
  /// 예전에는 `DecoratedBox(child: 앱 전체)`였다. 그러면 사진과 앱이 한 레이어라
  /// 위에서 뭐가 조금만 움직여도(스크롤·펼침·달력 확대) 전체화면 사진이 매번
  /// 다시 그려졌다. [RepaintBoundary]로 갈라 두면 한 번 그린 걸 그대로 재사용한다.
  ///
  /// [FilterQuality.high]도 내렸다 — 구겨진 결에 쓰는 쌍삼차 보간은 눈에 보이는
  /// 차이 없이 값만 비싸다.
  static Widget paperBackdrop(BuildContext context, {required Widget child}) {
    final dark = isDark(context);
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark ? darkBackground : lightSurface,
                image: DecorationImage(
                  image: AssetImage(paper),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  opacity: dark ? 1.0 : 0.82,
                  colorFilter: dark
                      ? const ColorFilter.mode(darkPaper, BlendMode.multiply)
                      : null,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }

  /// 절취선 — 절을 가르는 점선. 실선은 소계 위에만 쓴다.
  static Widget dashRule(BuildContext context, {Color? color}) => CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashRulePainter(color ?? lineStrong(context)),
      );

  /// 인쇄된 막대 — 채워진 만큼 잉크 블록을 찍는다. 둥근 진행바가 아니다.
  /// [ratio]는 0..1로 잘라 쓴다(예산 초과가 막대를 넘어 그리지 않게).
  static Widget printedBar(BuildContext context, double ratio,
          {double height = 9, Color? color}) =>
      CustomPaint(
        size: Size(double.infinity, height),
        painter: _PrintedBarPainter(color ?? ink(context), line(context), ratio.clamp(0.0, 1.0)),
      );

  /// 명세서 끝의 바코드. 읽히는 코드가 아니라 **여기서 끝난다는 표시**다.
  static Widget barcode(BuildContext context, {double height = 24, Color? color}) =>
      CustomPaint(
        size: Size(double.infinity, height),
        painter: _BarcodePainter(color ?? ink(context)),
      );

  /// 물결 마크 — 뜯긴 절취선. 앱 아이콘과 **같은 곡선**이다.
  ///
  /// 아이콘(정사각)과 달리 앱 안에서는 **가로로 길고 낮게** 쓴다. 정사각 그대로
  /// 얹으면 머리글이 아이콘만큼 높아져 홈이 그만큼 아래로 밀린다.
  ///
  /// PNG로 두지 않는 이유: 라이트·다크에서 잉크색이 바뀌고 폭이 화면을 따라간다.
  /// 곡선식은 design/make_icon_barcode.py와 같다 — 한쪽을 고치면 다른 쪽도 고친다.
  /// 홈 머리글에 이름 대신 이 마크만 서 있다 — 라벨이 없으면 스크린리더에는
  /// 앱 이름이 어디에도 안 읽힌다.
  static Widget waveMark(BuildContext context,
          {double height = 26, double width = 132, Color? color}) =>
      Semantics(
        label: '세끌',
        image: true,
        child: CustomPaint(
          size: Size(width, height),
          painter: _WaveMarkPainter(color ?? ink(context)),
        ),
      );

  /// 워드마크 — `세 끌` + `TAX & LEDGER · NO. XIV`. 명세서의 발행처 표시다.
  static Widget wordmark(BuildContext context, {String caption = 'TAX & LEDGER · NO. XIV'}) {
    return Column(children: [
      Text('세 끌',
          textAlign: TextAlign.center,
          style: display(26, ink(context), spacing: 8, height: 1.2)),
      const SizedBox(height: 8),
      ruleLabel(context, caption),
    ]);
  }

  /// 분절 선택 — 나란한 칸 중 하나가 잉크로 반전된다.
  ///
  /// 홈의 유형 선택과 가계부의 뷰 전환이 각자 그리다 크기·간격·테두리가
  /// 다 어긋났다. 한 곳에서 그려야 다시 안 벌어진다.
  static Widget segmented(
    BuildContext context, {
    required List<String> labels,
    required int selected,
    required ValueChanged<int> onTap,
    String semanticSuffix = '',
  }) {
    final inkC = ink(context);
    final tert = inkTertiary(context);
    return Row(children: [
      for (var i = 0; i < labels.length; i++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < labels.length - 1 ? 5 : 0),
            child: Semantics(
              button: true,
              selected: i == selected,
              label: semanticSuffix.isEmpty ? labels[i] : '${labels[i]} $semanticSuffix',
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? accentSoft(context) : null,
                    border: Border.all(
                      color: i == selected ? inkC : line(context),
                      width: i == selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 고른 칸에만 잉크 점 — 색맹인 사람에게도 굵기 말고 표식이 하나 더 있어야 한다.
                      if (i == selected) ...[
                        Container(width: 5, height: 5, color: inkC),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(labels[i],
                            overflow: TextOverflow.ellipsis,
                            style: sans(tsMD, i == selected ? inkC : tert,
                                weight: i == selected ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  /// 점선 테두리 상자 — 아직 채우지 않은 칸.
  static Widget dashedBox(BuildContext context, {required Widget child}) => CustomPaint(
        painter: _DashedBoxPainter(lineStrong(context)),
        child: child,
      );

  /// 전표의 체크칸 — 표시는 잉크로 채운 사각형, 미표시는 빈 테두리.
  static Widget tick(BuildContext context, bool checked, {double size = 16}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: checked ? ink(context) : null,
          border: Border.all(color: checked ? ink(context) : lineStrong(context), width: 1.5),
        ),
        child: checked
            ? Icon(Icons.check, size: size - 5, color: surface(context))
            : null,
      );

  // ──────────────────────────────────────────────
  // TextTheme 빌더
  // ──────────────────────────────────────────────
  static TextTheme _buildTextTheme(Color ink, Color secondary, Color tertiary) {
    return TextTheme(
      displayLarge:  display(46, ink, spacing: 0.5, height: 1.0),
      displayMedium: display(36, ink, spacing: 0.5, height: 1.05),
      headlineLarge: display(serifLG, ink, height: 1.15),
      headlineMedium: display(serifMD, ink, height: 1.2),
      headlineSmall: display(serifSM, ink, height: 1.25),
      titleLarge:  sans(tsXL, ink, weight: FontWeight.w700, spacing: -0.2),
      titleMedium: sans(tsLG, ink, weight: FontWeight.w600),
      titleSmall:  sans(tsMD, secondary, weight: FontWeight.w600),
      // 굵기는 sans의 기본(w500)을 따른다 — 여기서 w400으로 되돌리면
      // 스타일을 안 준 Text 전부가 다시 바탕에 눌린다.
      bodyLarge:   sans(tsLG, ink, height: 1.6),
      bodyMedium:  sans(tsBase, secondary, height: 1.55),
      bodySmall:   sans(tsSM, tertiary, height: 1.45),
      labelLarge:  sans(tsBase, ink, weight: FontWeight.w600),
      labelMedium: sans(tsMD, secondary, weight: FontWeight.w500),
      labelSmall:  sans(tsXS, tertiary, weight: FontWeight.w600, spacing: 2.0, height: 1.2),
    );
  }

  /// 화면 전환 중 배경이 하얗게 번쩍이던 자리.
  ///
  /// 안드로이드 기본 전환(ZoomPageTransitionsBuilder)은 전환 내내 화면 전체를
  /// `colorScheme.surface`로 덮는다. 그 값이 바탕 사진의 톤과 어긋나면 밝거나
  /// 어두운 판이 한 번 지나가고, 그게 '흰 깜빡임'으로 보인다.
  /// 바탕 사진의 평균 톤(#EFEFEF = lightSurface)에 맞춰 지운다.
  ///
  /// 투명으로 두지 않는 이유: Scaffold가 전부 투명이라(종이 결을 비추려고)
  /// 전환 중 두 화면의 글자가 서로 비쳐 겹친다. 300ms 동안 결이 잠깐 사라지는
  /// 편이 유령 글자보다 낫다.
  static PageTransitionsTheme _pageTransitions(Color bg) => PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(backgroundColor: bg),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(backgroundColor: bg),
          TargetPlatform.linux:   ZoomPageTransitionsBuilder(backgroundColor: bg),
          // iOS·macOS는 손대지 않는다 — Cupertino 전환은 화면을 덮지 않아 깜빡임이 없다.
        },
      );

  // ──────────────────────────────────────────────
  // Light Theme
  // ──────────────────────────────────────────────
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    pageTransitionsTheme: _pageTransitions(lightSurface),
    // 바탕은 paperBackdrop 한 장이 그린다 — 화면이 자기 배경을 칠하면 그 결이 가려진다.
    scaffoldBackgroundColor: Colors.transparent,
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      iconTheme: const IconThemeData(color: lightInk),
      // 영수증의 머리글은 크게 조판되지 않는다 — 작게 찍히고 자간으로 넓어진다.
      centerTitle: true,
      titleTextStyle: sans(tsMD, lightInk, weight: FontWeight.w700, spacing: 2.0),
    ),

    textTheme: _buildTextTheme(lightInk, lightInkSecondary, lightInkTertiary),

    dividerTheme: const DividerThemeData(color: lightLine, thickness: 1, space: 1),
    dividerColor: lightLine,
    iconTheme: const IconThemeData(color: lightInkSecondary, size: 20),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      hintStyle: sans(tsBase, lightInkTertiary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: lightLine)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: lightLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: lightAccent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: lightInk,
      unselectedItemColor: lightInkTertiary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: sans(tsNav, lightInk, weight: FontWeight.w600, spacing: 0.5),
      unselectedLabelStyle: sans(tsNav, lightInkTertiary, weight: FontWeight.w500, spacing: 0.5),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightInk,
        foregroundColor: lightBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        textStyle: sans(tsLG, lightBackground, weight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(vertical: 18),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: lightAccent,
        textStyle: sans(tsBase, lightAccent, weight: FontWeight.w600),
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
    pageTransitionsTheme: _pageTransitions(darkBackground),
    scaffoldBackgroundColor: Colors.transparent,
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      iconTheme: const IconThemeData(color: darkInk),
      centerTitle: true,
      titleTextStyle: sans(tsMD, darkInk, weight: FontWeight.w700, spacing: 2.0),
    ),

    textTheme: _buildTextTheme(darkInk, darkInkSecondary, darkInkTertiary),

    dividerTheme: const DividerThemeData(color: darkLine, thickness: 1, space: 1),
    dividerColor: darkLine,
    iconTheme: const IconThemeData(color: darkInkSecondary, size: 20),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      hintStyle: sans(tsBase, darkInkTertiary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: darkLine)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: darkLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: darkAccent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: darkInk,
      unselectedItemColor: darkInkTertiary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: sans(tsNav, darkInk, weight: FontWeight.w600, spacing: 0.5),
      unselectedLabelStyle: sans(tsNav, darkInkTertiary, weight: FontWeight.w500, spacing: 0.5),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkInk,
        foregroundColor: darkBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        textStyle: sans(tsLG, darkBackground, weight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(vertical: 18),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: darkAccent,
        textStyle: sans(tsBase, darkAccent, weight: FontWeight.w600),
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

  /// 기입란 — 1px 헤어라인으로 두르기만 한다. **채우지 않는다.**
  ///
  /// 예전에는 [surface]로 채웠다. 그 색이 종이 사진 위에 회색 판을 덮어서,
  /// 홈·가계부에는 종이 결이 비치는데 계산기 30여 화면만 판때기가 깔렸다.
  /// 영수증에 상자는 없지만 선으로 두른 **기입란**은 있다 — 경계는 선이
  /// 만들고 바탕은 종이 그대로 둔다.
  ///
  /// 입력창·버튼은 여전히 채운다(inputDecorationTheme). 글자를 적거나 누르는
  /// 자리 위로는 결이 지나가면 안 된다.
  static BoxDecoration getCardDecoration(
    BuildContext context, {
    double borderRadius = 2.0,
    bool elevated = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius.clamp(0.0, 4.0)),
      border: Border.all(color: line(context), width: 1),
    );
  }

  /// 도면 주석 박스 — 파란 테두리, 채움 최소
  static BoxDecoration getAccentCardDecoration(
    BuildContext context, {
    double borderRadius = 2.0,
  }) {
    return BoxDecoration(
      color: accentSoft(context),
      borderRadius: BorderRadius.circular(borderRadius.clamp(0.0, 4.0)),
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
        borderRadius: BorderRadius.circular(2),
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
        // 10.5는 스케일 바닥(12) 밑이라 고정폭에서 획이 뭉갠다.
        style: sans(tsXS, accent, weight: FontWeight.w600, spacing: 0.5),
      ),
    );
  }
}


/// 전표 종이의 결 — 아주 옅은 도트 그리드. 종이가 균질한 판이 아니라는 표시다.
class _SlipTexturePainter extends CustomPainter {
  const _SlipTexturePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.55);
    const gap = 5.0;
    for (double y = 2; y < size.height; y += gap) {
      for (double x = 2; x < size.width; x += gap) {
        canvas.drawRect(Rect.fromLTWH(x, y, 0.7, 0.7), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SlipTexturePainter old) => old.color != color;
}


/// 절취선 — 4px 찍고 4px 쉰다.
class _DashRulePainter extends CustomPainter {
  const _DashRulePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset((x + 4).clamp(0, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashRulePainter old) => old.color != color;
}

/// 인쇄된 막대 — 9px 블록을 5px 간격으로 찍는다. 채워진 구간만 잉크.
class _PrintedBarPainter extends CustomPainter {
  const _PrintedBarPainter(this.inkColor, this.emptyColor, this.ratio);
  final Color inkColor;
  final Color emptyColor;
  final double ratio;

  @override
  void paint(Canvas canvas, Size size) {
    const block = 9.0, gap = 5.0;
    final filled = size.width * ratio;
    for (double x = 0; x < size.width; x += block + gap) {
      final w = (block).clamp(0.0, size.width - x);
      canvas.drawRect(
        Rect.fromLTWH(x, 0, w, size.height),
        Paint()..color = x + w <= filled ? inkColor : emptyColor,
      );
    }
  }

  @override
  bool shouldRepaint(_PrintedBarPainter old) =>
      old.ratio != ratio || old.inkColor != inkColor || old.emptyColor != emptyColor;
}

/// 명세서 끝의 바코드.
class _BarcodePainter extends CustomPainter {
  const _BarcodePainter(this.color);
  final Color color;

  // 굵기 패턴을 고정 배열로 둔다 — 매 프레임 난수를 쓰면 바코드가 떨린다.
  static const _widths = <double>[1, 3, 1, 2, 1, 1, 3, 1, 1, 2, 3, 1, 2, 1, 1, 3, 2, 1, 1, 2,
                                  1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 2, 3, 1, 1, 2, 1, 1, 3, 1, 2];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    double x = 0;
    var i = 0;
    while (x < size.width) {
      final w = _widths[i % _widths.length];
      if (i.isEven) canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w + 1;
      i++;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.color != color;
}


/// 물결 마크 — 사인 곡선 두 줄 사이를 채운 띠. 봉우리 하나만 완만하게 더 솟는다.
/// 값은 design/make_icon_barcode.py의 FINAL과 짝이다(잔잔한 진폭 + 어긋난 봉우리).
class _WaveMarkPainter extends CustomPainter {
  const _WaveMarkPainter(this.color);
  final Color color;

  /// **파장 고정** — 높이 1에 대해 봉우리 하나가 차지하는 가로 길이.
  /// 봉우리 수를 상수로 박아 두면 폭을 줄일 때 물결이 가로로 눌려 촘촘해진다.
  /// 이 값을 고정하고 봉우리 수를 폭에서 뽑으면, 폭을 줄여도 물결 모양은
  /// 그대로고 **양 끝만 잘린다**.
  static const _lobeSpan = 1.45;
  static const _ampR = 0.17;   // 높이 대비 진폭 — 잔잔하게
  static const _thR = 0.40;    // 높이 대비 띠 두께
  static const _hitch = 1;     // 이 봉우리만 더 솟는다
  static const _steps = 96;

  /// 이 폭에 들어가는 봉우리 수.
  static double _lobesFor(Size size) =>
      (size.width / size.height) / _lobeSpan;

  List<Offset> _edge(Size size, double offset, double hitchK) => waveEdge(
        size: size,
        lobes: _lobesFor(size),
        amp: size.height * _ampR,
        dy: offset,
        hitchK: hitchK,
        hitch: _hitch,
        steps: _steps,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final th = size.height * _thR;
    // 봉우리가 위아래로 넘치지 않을 만큼만 키운다 — 아이콘 쪽과 같은 규칙.
    final k = waveHitchK(
        half: size.height * 0.5, th: th, amp: size.height * _ampR);
    final top = _edge(size, -th / 2, k);
    final bottom = _edge(size, th / 2, k).reversed;
    final path = Path()..moveTo(top.first.dx, top.first.dy);
    for (final p in top.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in bottom) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_WaveMarkPainter old) => old.color != color;
}


/// 점선 테두리 상자 — 아직 채우지 않은 칸.
class _DashedBoxPainter extends CustomPainter {
  const _DashedBoxPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 4.0, gap = 4.0;
    void run(double len, Offset Function(double) at) {
      for (double d = 0; d < len; d += dash + gap) {
        canvas.drawLine(at(d), at((d + dash).clamp(0, len)), paint);
      }
    }
    run(size.width, (d) => Offset(d, 0));
    run(size.width, (d) => Offset(d, size.height));
    run(size.height, (d) => Offset(0, d));
    run(size.height, (d) => Offset(size.width, d));
  }

  @override
  bool shouldRepaint(_DashedBoxPainter old) => old.color != color;
}
