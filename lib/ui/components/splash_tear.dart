import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 켜지는 순간 — 종이가 물결을 따라 뜯긴다.
///
/// 처음엔 **아무 무늬도 없는 한 장**이다. 그 한 장이 물결선을 따라 갈라지고,
/// 아래쪽만 살짝 내려앉으면서 **벌어진 틈이 물결 마크가 된다**. 물결을 그리는
/// 게 아니라 종이를 열어서 만드는 것이라, 다 열린 모양이 곧 앱 아이콘이다.
///
/// 다 벌어진 모양이 **앱 아이콘 그대로**다 — 비율을
/// `design/make_icon_barcode.py`의 FINAL에서 가져왔다. 아이콘 물결을 고치면
/// 여기도 같이 고쳐야 한다.
///
/// **앱을 붙잡지 않는다.** [IgnorePointer]라 재생 중에도 홈을 바로 누를 수
/// 있고, 「동작 줄이기」를 켠 기기에서는 아예 재생하지 않는다.
class SplashTear extends StatefulWidget {
  const SplashTear({super.key});

  @override
  State<SplashTear> createState() => _SplashTearState();
}

class _SplashTearState extends State<SplashTear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    // 벌어지고(0~58%) · 잠깐 머물고 · 걷힌다(80~100%).
    // 아이콘 두께만큼 벌어져야 해서 갈 길이 멀어졌다. 손을 붙잡지 않으니
    // (IgnorePointer) 길어져도 기다리게 하지는 않는다.
    duration: const Duration(milliseconds: 900),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _done = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        setState(() => _done = true);
      } else {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _TearPainter(
              color: AppTheme.ink(context),
              background: AppTheme.isDark(context)
                  ? AppTheme.darkBackground
                  : AppTheme.lightSurface,
              t: _c.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _TearPainter extends CustomPainter {
  const _TearPainter({
    required this.color,
    required this.background,
    required this.t,
  });

  /// 벌어진 틈으로 드러나는 색 — 이게 물결이 된다.
  final Color color;

  /// 뜯기는 종이 자체의 색.
  final Color background;

  /// 0 = 안 벌어짐(민 종이 한 장), 1 = 다 벌어짐(물결 완성).
  final double t;

  // ── 앱 아이콘과 **같은 비율**. design/make_icon_barcode.py의 FINAL 값이다. ──
  //
  // 다 벌어진 모양이 곧 아이콘이어야 하므로, 아이콘이 정사각 타일에서 쓰는
  // 비율을 화면 **폭** 기준으로 그대로 옮긴다. 예전에는 스플래시가 따로 얇은
  // 띠를 쓰고 있어서(폭 대비 0.069) 다 열려도 아이콘의 1/3 두께였다.
  static const _lobes = 2.5;
  static const _ampR = 0.06; // 화면 폭 대비 진폭
  static const _thR = 0.22;  // 화면 폭 대비 두께 = 다 벌어졌을 때의 틈
  static const _hitch = 1;
  /// 어긋난 봉우리 배율. 아이콘 쪽 계산(head/amp - 1)이 상한 1.6에 걸린 값이다.
  static const _hitchK = 1.6;
  static const _steps = 200;

  /// 뜯긴 자리를 그리는 물결선. [dy]만큼 통째로 내려 그린다.
  List<Offset> _seam(Size size, double dy) {
    final amp = size.width * _ampR;
    final centerY = size.height / 2 + dy;
    const c = (_hitch + 0.5) / _lobes;
    return [
      for (var i = 0; i <= _steps; i++)
        () {
          final u = i / _steps;
          final d = (u - c) / (0.55 / _lobes);
          final a = amp * (1 + _hitchK * math.exp(-(d * d)));
          return Offset(size.width * u, centerY - a * math.sin(2 * math.pi * _lobes * u));
        }(),
    ];
  }

  /// 물결선 위(또는 아래) 화면 전체를 덮는 종이 조각.
  Path _piece(Size size, double dy, {required bool upper}) {
    final seam = _seam(size, dy);
    final p = Path()..moveTo(seam.first.dx, seam.first.dy);
    for (final o in seam.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    final edgeY = upper ? -size.height : size.height * 2;
    p
      ..lineTo(size.width, edgeY)
      ..lineTo(0, edgeY)
      ..close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 다 벌어졌을 때의 틈 = 아이콘 물결의 두께.
    final gap = size.width * _thR;

    // 벌어짐은 먼저 빠르고 끝에서 멎는다 — 뜯긴 종이가 툭 내려앉는 느낌.
    final open = Curves.easeOutCubic.transform((t / 0.58).clamp(0.0, 1.0));
    // 다 벌어진 뒤 잠깐 머물다 종이째 걷힌다.
    final fade = (1 - ((t - 0.80) / 0.20)).clamp(0.0, 1.0);

    canvas.saveLayer(
        Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: fade));

    // 틈으로 드러날 색을 먼저 깔고, 그 위에 종이 두 조각을 덮는다.
    // 조각이 벌어진 만큼만 이 색이 보이고, 그 모양이 곧 물결이다.
    canvas.drawRect(Offset.zero & size, Paint()..color = color);

    final paper = Paint()
      ..color = background
      ..isAntiAlias = true;
    canvas.drawPath(_piece(size, 0, upper: true), paper);
    canvas.drawPath(_piece(size, gap * open, upper: false), paper);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TearPainter old) =>
      old.t != t || old.color != color || old.background != background;
}
