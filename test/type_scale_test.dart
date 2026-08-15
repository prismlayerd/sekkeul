import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **글자 크기는 스케일 안에서만 고른다.**
///
/// 실기기에서 배너가 9.2픽셀 넘쳤다. 원인은 높이를 손으로 셈해 둔 자리였는데,
/// 그 셈이 옛 크기(11·12)로 되어 있고 안에 든 글자는 새 크기(12·13)였다.
/// 크기가 스무 종이면 이런 어긋남을 눈으로 못 찾는다 — 열한 종으로 묶어 두고
/// 여기서 붙잡는다.
void main() {
  // app_theme.dart의 타입 스케일. 이 목록을 늘리려면 거기부터 늘린다.
  const allowed = {'10', '12', '13', '14', '15', '17', '19', '21', '25', '30', '36'};

  test('lib에 스케일 밖 글자 크기가 없다', () {
    final offenders = <String>[];
    final patterns = [
      RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)'),
      RegExp(r'AppTheme\.(?:sans|serif|display)\(\s*(\d+(?:\.\d+)?)\s*,'),
    ];

    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      // 스케일을 정의하는 파일 자신은 예외.
      if (rel.endsWith('lib/ui/theme/app_theme.dart')) continue;

      final src = f.readAsStringSync();
      for (final p in patterns) {
        for (final m in p.allMatches(src)) {
          if (allowed.contains(m.group(1))) continue;
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          offenders.add('$rel:$line — ${m.group(0)}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'AppTheme의 ts* / serif* 상수 중에서 고르세요.\n'
            '${offenders.join('\n')}');
  });
}
