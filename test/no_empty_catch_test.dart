import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **삼킨 예외 금지.**
///
/// `catch (e) {}`는 실패를 없던 일로 만든다. 앱은 계속 돌아가지만 무엇이
/// 어긋났는지 아무 데도 남지 않아서, 나중에 "가끔 값이 안 보인다" 같은
/// 재현 안 되는 제보만 받게 된다. 2026-08-15에 `db_helper`의 54곳을
/// `_step`으로 바꿔 `error_log`로 흘렸다 — 다시 늘어나지 않게 여기서 막는다.
///
/// 정말 무시해도 되는 자리는 `catch (_) {}`로 적는다. 밑줄은
/// "이 실패는 알고도 버린다"는 표시다.
void main() {
  test('lib에 이름 붙은 빈 catch가 없다', () {
    // `catch (e) {}` — 줄바꿈이 끼어 있어도 잡는다.
    final empty = RegExp(r'catch\s*\(\s*(?!_)\w+[^)]*\)\s*\{\s*\}');

    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      final rel = f.path.replaceAll(r'\', '/');
      for (final m in empty.allMatches(src)) {
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        offenders.add('$rel:$line');
      }
    }

    expect(offenders, isEmpty,
        reason: '실패를 삼키지 마세요 — 기록으로 흘리거나, 정말 버릴 거면 catch (_) {}.\n'
            '${offenders.join('\n')}');
  });
}
