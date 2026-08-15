import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **바텀시트 금지 — 앱의 하드 제약.**
///
/// `요약.md`: "바텀시트 금지 — fullscreen push / inline expand / AlertDialog만."
///
/// 규칙이 문서에만 있으면 지켜지지 않는다. 실제로 2026-08-15에 가계부 입력
/// 화면을 새로 쓰면서 바텀시트를 넣었고, 아무도 못 막았다. 여기서 막는다.
void main() {
  // 아직 안 고친 곳. **늘리지 말 것** — 고칠 때마다 지운다.
  const known = <String>{
    'lib/ui/screens/profile_input_screen.dart',   // 생년월일 휠
    'lib/ui/screens/year_end_tax_screen.dart',    // 원천징수영수증 파일 고르기
  };

  test('lib에 새 바텀시트가 없다', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      if (!f.readAsStringSync().contains('showModalBottomSheet')) continue;
      if (known.any(rel.endsWith)) continue;
      offenders.add(rel);
    }
    expect(offenders, isEmpty,
        reason: '바텀시트 금지 — 풀스크린 push / 인라인 펼침 / AlertDialog 중에서 고르세요.\n'
            '${offenders.join('\n')}');
  });
}
