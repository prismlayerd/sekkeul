import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/theme/wave.dart';

/// 물결은 세 곳에 나타난다 — 앱 아이콘 · 스플래시가 뜯긴 자국 · 홈 마크.
/// 셋이 조금이라도 다르면 스플래시가 끝나는 순간 물결이 튄다.
///
/// 다트 쪽 둘은 [waveEdge] 하나를 부르게 묶었다. 파이썬(아이콘 생성기)은
/// 언어가 달라 묶을 수 없으니, 여기서 **값이 같은지**만 붙잡아 둔다.
void main() {
  test('스플래시 비율이 아이콘 생성기의 FINAL과 같다', () {
    final py = File('design/make_icon_barcode.py').readAsStringSync();
    final dart = File('lib/ui/components/splash_tear.dart').readAsStringSync();

    final finalLine =
        RegExp(r'^FINAL = dict\((.*)\)$', multiLine: true).firstMatch(py);
    expect(finalLine, isNotNull,
        reason: 'make_icon_barcode.py의 FINAL 줄을 못 찾았다');

    double pyVal(String key) => double.parse(
        RegExp('$key=([0-9.]+)').firstMatch(finalLine!.group(1)!)!.group(1)!);
    double dartVal(String name) => double.parse(
        RegExp('static const $name = ([0-9.]+)').firstMatch(dart)!.group(1)!);

    expect(dartVal('_lobes'), pyVal('lobes'), reason: '봉우리 수');
    expect(dartVal('_ampR'), pyVal('amp_r'), reason: '진폭 비율');
    expect(dartVal('_thR'), pyVal('th_r'), reason: '띠 두께 비율');
    expect(dartVal('_hitch'), pyVal('hitch'), reason: '어긋나는 봉우리 번호');
  });

  test('물결 식이 lib에 한 벌만 있다', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      if (rel.endsWith('lib/ui/theme/wave.dart')) continue;
      if (f.readAsStringSync().contains('math.sin(2 * math.pi')) {
        offenders.add(rel);
      }
    }
    expect(offenders, isEmpty,
        reason: '물결은 waveEdge 하나만 그린다 — 복제하면 세 곳이 어긋난다.\n'
            '${offenders.join('\n')}');
  });

  test('어긋난 봉우리 하나만 더 솟는다', () {
    const size = Size(300, 100);
    final pts = waveEdge(
        size: size, lobes: 2.5, amp: 10, hitchK: 1.6, hitch: 1, steps: 240);

    // 위로 솟은 정도 = 중심선에서 위로 벗어난 거리.
    double riseNear(double t) {
      final want = size.width * t;
      final p = pts.reduce((a, b) =>
          (a.dx - want).abs() < (b.dx - want).abs() ? a : b);
      return size.height / 2 - p.dy;
    }

    // 봉우리는 lobes=2.5에서 t = 0.1, 0.5, 0.9. 어긋나는 건 hitch=1 → t=0.5.
    expect(riseNear(0.5), greaterThan(riseNear(0.1) * 2),
        reason: '두 번째 봉우리가 다른 봉우리보다 확실히 높아야 뜯긴 자국으로 읽힌다');
    expect(riseNear(0.5), lessThan(size.height / 2),
        reason: '봉우리가 화면 밖으로 나가면 띠가 끊어져 보인다');
  });
}
