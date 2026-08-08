import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **지식 노트(wiki)와 앱 코드가 같은 말을 하는지 본다.**
///
/// 옵시디언 볼트의 `sekkeul/지식/세법/*.md`는 앱의 사양서다. 노트마다
/// `## 앱에서 쓰이는 곳`에 코드 위치와 **그 줄의 코드를 그대로** 적게 돼 있다.
/// 이 테스트는 그 인용문이 실제 파일에 아직 그대로 있는지 확인한다.
///
/// 세법이 바뀌면 흐름이 강제된다:
///   노트 갱신 → 이 테스트 실패 → 코드 수정 → 통과
///
/// 반대 방향도 잡힌다 — 노트를 안 고치고 코드값만 바꾸면 인용문이 사라져 실패한다.
///
/// 볼트는 저장소 밖(OneDrive)에 있다. 환경변수 `SEKKEUL_WIKI` → `~/OneDrive/Desktop/wiki`
/// 순으로 찾고, 못 찾으면 **실패시키지 않고 건너뛴다**(다른 PC에서 클론했을 때 빌드가 깨지면 안 된다).
///
// ponytail: 노트 형식·등급·만료 린트는 지웠다. 노트가 10개 넘어 눈으로 못 훑게 되면 되살릴 것.
void main() {
  test('노트가 인용한 코드값이 실제 코드와 일치한다', () {
    final dir = _lawDir();
    if (dir == null || !dir.existsSync()) {
      // ignore: avoid_print
      print('  ⤳ 볼트를 못 찾아 건너뛴다. 환경변수 SEKKEUL_WIKI 에 볼트 경로를 넣으면 대조가 돈다.');
      return;
    }

    final problems = <String>[];
    var noteCount = 0;
    for (final f in dir.listSync()) {
      if (f is! File || !f.path.endsWith('.md')) continue;
      noteCount++;
      final name = f.path.replaceAll(r'\', '/').split('/').last;

      for (final ref in _parseRefs(_section(f.readAsStringSync(), '앱에서 쓰이는 곳'))) {
        final file = File(ref.path);
        if (!file.existsSync()) {
          problems.add('$name → ${ref.path} 파일이 없다 (코드가 옮겨갔으면 노트를 고칠 것)');
          continue;
        }
        final flat = _flatten(file.readAsStringSync());
        for (final snippet in ref.snippets) {
          if (!flat.contains(_flatten(snippet))) {
            problems.add(
              '$name → ${ref.path}\n'
              '      노트가 말하는 값 : $snippet\n'
              '      코드에 그런 줄이 없다. 둘 중 하나다 —\n'
              '        (a) 법이 바뀌어 노트를 고쳤다 → 코드를 고칠 차례다\n'
              '        (b) 코드를 먼저 고쳤다        → 순서가 뒤집혔다. 노트부터 고칠 것',
            );
          }
        }
      }
    }

    for (final p in problems) {
      // ignore: avoid_print
      print('  ✕ $p');
    }
    // ignore: avoid_print
    print('  ✓ 세법 노트 $noteCount개를 대조했다 (${dir.path})');
    expect(problems, isEmpty, reason: '노트가 먼저고 코드가 따라온다');
  });
}

Directory? _lawDir() {
  final env = Platform.environment;
  for (final root in [
    env['SEKKEUL_WIKI'],
    if (env['USERPROFILE'] != null) '${env['USERPROFILE']}/OneDrive/Desktop/wiki',
    if (env['HOME'] != null) '${env['HOME']}/OneDrive/Desktop/wiki',
  ]) {
    if (root == null || root.isEmpty) continue;
    final d = Directory('${root.replaceAll(r'\', '/')}/sekkeul/지식/세법');
    if (d.existsSync()) return d;
  }
  return null;
}

/// `## {제목}` 아래 다음 `##` 전까지.
///
/// 끝을 `$(?![\s\S])`로 잡는 이유: Dart 정규식은 자바스크립트 문법이라 `\Z`가 없다
/// (있는 줄 알고 쓰면 그냥 문자 Z로 읽힌다).
String _section(String body, String heading) {
  final m = RegExp(
    r'^##[ \t]+' +
        RegExp.escape(heading) +
        r'[ \t]*$([\s\S]*?)(?=^##[ \t]|$(?![\s\S]))',
    multiLine: true,
  ).firstMatch(body);
  return m?.group(1) ?? '';
}

/// 노트가 가리킨 코드 한 곳.
class _CodeRef {
  _CodeRef(this.path, this.snippets);

  /// 저장소 루트 기준 경로. 예: `lib/core/tax_engine/tax_rates.dart`
  final String path;

  /// 그 줄에서 백틱으로 인용한 코드. 예: `static const double x = 1500000.0;`
  final List<String> snippets;
}

/// `## 앱에서 쓰이는 곳` 본문에서 `경로[:줄] … \`코드\`` 를 뽑는다.
/// 줄 번호는 코드가 조금만 움직여도 어긋나므로 읽고 버린다.
List<_CodeRef> _parseRefs(String section) {
  final pathRe = RegExp(r'((?:lib|test)[\w./\-가-힣]*\.dart)(?::\d+)?');
  final codeRe = RegExp(r'`([^`\n]+)`');

  final refs = <_CodeRef>[];
  for (final raw in section.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line == '없음') continue;

    final pm = pathRe.firstMatch(line);
    if (pm == null) continue;

    // 경로 자체가 백틱에 싸여 있을 수 있으니 코드 인용에서 걸러낸다.
    final snippets = <String>[
      for (final cm in codeRe.allMatches(line))
        if (!cm.group(1)!.contains('.dart')) cm.group(1)!.trim(),
    ]..removeWhere((s) => s.isEmpty);

    refs.add(_CodeRef(pm.group(1)!, snippets));
  }
  return refs;
}

/// 공백 차이·줄바꿈 때문에 엉뚱하게 실패하지 않도록 납작하게 만든다.
String _flatten(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
