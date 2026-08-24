import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **영수증 테마의 규율 두 가지.**
///
/// 문서에만 적힌 규칙은 지켜지지 않는다. 화면이 88개라 눈으로는 못 훑는다.
void main() {
  Iterable<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('모서리는 4를 넘지 않는다', () {
    // 영수증은 종이를 자른 것이라 모서리가 둥글지 않다. 테마 자신은 2를 쓰고,
    // AppTheme의 두 헬퍼는 이미 clamp(0, 4)로 자른다. 8·12·16·24는 카드
    // 시절 잔재였고 115곳이 남아 있었다(2026-08-15에 정리).
    final tooRound = RegExp(r'Radius\.circular\((\d+(?:\.\d+)?)\)');
    final offenders = <String>[];
    for (final f in dartFiles('lib/ui')) {
      final src = f.readAsStringSync();
      final rel = f.path.replaceAll(r'\', '/');
      for (final m in tooRound.allMatches(src)) {
        if (double.parse(m.group(1)!) <= 4) continue;
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        offenders.add('$rel:$line — ${m.group(0)}');
      }
    }
    expect(offenders, isEmpty,
        reason: '모서리 상한은 4입니다.\n${offenders.join('\n')}');
  });

  test('머티리얼 기본색을 쓰지 않는다', () {
    // 영수증 팔레트는 종이 위 대비를 재서 고른 것이다(colorWarning은 4.6:1 —
    // 9A7328은 3.7:1로 AA 미달이라 7F5E1E로 내렸다). Colors.orange·green·red를
    // 그대로 쓰면 그 계산 밖으로 나가고, 화면마다 다른 앱처럼 보인다.
    //
    // 계산기 8개 화면에 42곳이 남아 있었다(2026-08-24 정리). transparent·white·
    // black은 팔레트가 아니라 합성용이라 뺀다.
    final bad = RegExp(r'Colors\.(?!transparent|white|black)[a-z]');
    final offenders = <String>[];
    for (final f in dartFiles('lib/ui')) {
      final src = f.readAsStringSync();
      final rel = f.path.replaceAll(r'\', '/');
      if (rel.endsWith('theme/app_theme.dart')) continue;
      for (final m in bad.allMatches(src)) {
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        offenders.add('$rel:$line');
      }
    }
    expect(offenders, isEmpty,
        reason: 'AppTheme.colorDanger·colorWarning·colorSuccess를 쓰세요.\n'
            '${offenders.join('\n')}');
  });

  test('잉크 위의 글자를 흰색으로 박지 않는다', () {
    // 다크에서 잉크는 밝은 회색(#E8E8E8)이다. 그 위에 흰 글자를 얹으면
    // 라이트에서만 보이고 다크에서는 사라진다. 잉크의 반대는 흰색이 아니라
    // **바탕**이다 — AppTheme.backgroundColor(context).
    final offenders = <String>[];
    for (final f in dartFiles('lib/ui/screens')) {
      final src = f.readAsStringSync();
      final rel = f.path.replaceAll(r'\', '/');
      for (final m in RegExp(r'(?<!\.)\bColors\.(white|black)\b(?!\w)').allMatches(src)) {
        // 투명도를 실은 건 덮개(오버레이)라 테마와 무관하다.
        if (src.substring(m.end, (m.end + 12).clamp(0, src.length)).startsWith('.with')) {
          continue;
        }
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        offenders.add('$rel:$line — ${m.group(0)}');
      }
    }
    expect(offenders, isEmpty,
        reason: '흑백을 직접 박지 말고 AppTheme의 잉크·바탕을 쓰세요.\n'
            '${offenders.join('\n')}');
  });
}
