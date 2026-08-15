import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// 세끌 물결 한 줄 — 뜯긴 영수증의 가장자리.
///
/// 앱 아이콘(`design/make_icon_barcode.py`) · 홈 마크([AppTheme.waveMark]) ·
/// 스플래시([SplashTear])가 **같은 곡선**을 쓴다. 예전엔 셋이 각자 같은 식을
/// 들고 있어서, 한 곳만 손보면 스플래시가 끝나는 순간 물결이 튀었다.
/// 파이썬 쪽은 언어가 달라 복제가 남지만, 값이 어긋나면
/// `test/wave_shape_test.dart`가 잡는다.
///
/// [hitch]번째 봉우리만 [hitchK]배 더 솟는다 — 종이를 손으로 뜯으면 한 군데가
/// 유독 크게 찢긴다. 그 한 번의 어긋남이 이 마크를 물결이 아니라 **뜯긴 자국**
/// 으로 읽히게 한다.
List<Offset> waveEdge({
  required Size size,
  required double lobes,
  required double amp,
  required double hitchK,
  double dy = 0,
  int hitch = 1,
  int steps = 96,
}) {
  final y = size.height / 2 + dy;
  final c = (hitch + 0.5) / lobes;
  return [
    for (var i = 0; i <= steps; i++)
      () {
        final t = i / steps;
        final d = (t - c) / (0.55 / lobes);
        final a = amp * (1 + hitchK * math.exp(-(d * d)));
        return Offset(size.width * t, y - a * math.sin(2 * math.pi * lobes * t));
      }(),
  ];
}

/// 띠 두께 [th]에서 봉우리를 얼마나 더 솟게 할지.
///
/// 봉우리가 위아래로 넘치면 띠가 끊어져 보인다 — 남은 높이만큼만 키운다.
/// 파이썬 쪽 `_wave_band`의 같은 식이다.
double waveHitchK({required double half, required double th, required double amp}) =>
    math.min(1.6, math.max(0.25, (half - th / 2) / amp - 1));
