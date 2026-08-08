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
/// 노트가 코드보다 위에 서고, wiki가 앱의 사양서가 된다.
///
/// ---
/// **볼트를 어디서 찾는가**
///
/// 볼트는 저장소 밖(OneDrive)에 있다. 순서대로 찾는다:
///   1. 환경변수 `SEKKEUL_WIKI`
///   2. `%USERPROFILE%\OneDrive\Desktop\wiki`
///   3. `$HOME/OneDrive/Desktop/wiki`
///
/// 볼트를 못 찾거나 `지식/세법/`이 비어 있으면 **실패시키지 않고 건너뛴다.**
/// CI나 다른 PC에서 클론했을 때 볼트가 없다고 빌드가 깨지면 안 되기 때문이다.
/// 대신 이유를 출력한다.
void main() {
  final vault = _findVault();
  final lawDir = vault == null
      ? null
      : Directory('${vault.path}/sekkeul/지식/세법');

  group('wiki ↔ 코드 동기화', () {
    late List<_Note> notes;

    setUpAll(() {
      notes = <_Note>[];
      if (lawDir == null || !lawDir.existsSync()) return;
      for (final f in lawDir.listSync()) {
        if (f is File && f.path.endsWith('.md')) {
          notes.add(_Note.parse(f));
        }
      }
    });

    test('볼트를 찾았고 세법 노트가 하나 이상 있다', () {
      if (vault == null) {
        _skipNote(
          '옵시디언 볼트를 못 찾았다. 환경변수 SEKKEUL_WIKI 에 볼트 경로를 넣으면 대조가 돈다.\n'
          r'  예) PowerShell:  $env:SEKKEUL_WIKI = "C:\Users\vedja\OneDrive\Desktop\wiki"',
        );
        return;
      }
      if (lawDir == null || !lawDir.existsSync() || notes.isEmpty) {
        _skipNote(
          '${lawDir?.path} 에 세법 노트가 없다.\n'
          '  work\\수신함\\ 의 초안을 검토해서 이 폴더로 승격하면 그때부터 대조가 시작된다.',
        );
        return;
      }
      // ignore: avoid_print
      print('  ✓ 세법 노트 ${notes.length}개를 대조 대상으로 읽었다 (${lawDir?.path})');
    });

    /// 형식이 깨진 노트는 대조 자체가 안 된다. 머리말부터 본다.
    test('노트가 _규칙.md 의 머리말 형식을 지킨다', () {
      if (notes.isEmpty) return;

      final problems = <String>[];
      for (final n in notes) {
        if (n.grade == null) {
          problems.add('${n.name} — **등급:** 없음 (A 또는 B)');
        } else if (n.grade != 'A' && n.grade != 'B') {
          problems.add('${n.name} — 등급이 "${n.grade}" (A 또는 B만 허용)');
        }
        if (n.checkedOn == null) {
          problems.add('${n.name} — **확인일:** 없음 (YYYY-MM-DD)');
        }
        if (n.validUntil == null || n.validUntil!.isEmpty) {
          problems.add('${n.name} — **유효기간:** 없음');
        }
        if (n.section('근거').trim().isEmpty) {
          problems.add('${n.name} — `## 근거`가 비어 있다 (근거 없으면 노트가 아니다)');
        }
        if (n.section('앱에서 쓰이는 곳').trim().isEmpty) {
          problems.add('${n.name} — `## 앱에서 쓰이는 곳`이 비어 있다 (없으면 "없음"이라고 적을 것)');
        }
      }
      _report(problems);
      expect(problems, isEmpty, reason: 'wiki/_규칙.md 3번 형식을 따를 것');
    });

    /// A등급은 1차 출처를 직접 열어 확인한 것이다. 원문 인용이 없으면 A가 아니다.
    test('A등급 노트는 근거에 원문 인용이 들어 있다', () {
      if (notes.isEmpty) return;

      final problems = <String>[];
      for (final n in notes.where((n) => n.grade == 'A')) {
        final basis = n.section('근거');
        final hasQuote = RegExp(r'[""].{10,}[""]').hasMatch(basis) ||
            RegExp(r'".{10,}"').hasMatch(basis);
        if (!hasQuote) {
          problems.add('${n.name} — A등급인데 `## 근거`에 원문 인용문이 없다 (B로 내리거나 원문을 인용할 것)');
        }
      }
      _report(problems);
      expect(problems, isEmpty, reason: 'wiki/_규칙.md 1번 — A등급은 인용문을 반드시 포함한다');
    });

    /// 흐린 표현이 있으면 검증이 안 된 것이다.
    ///
    /// `## 근거`는 원문을 그대로 옮긴 곳이라 검사하지 않는다 — 법령 문장에 "일반적으로"가
    /// 들어 있다고 노트를 나무랄 수는 없다. 내가 쓴 문장만 본다.
    test('노트에 흐린 표현이 없다', () {
      if (notes.isEmpty) return;

      const vague = ['아마', '일반적으로', '대체로', '것으로 보인다', '인 듯', '추정된다'];
      final problems = <String>[];
      for (final n in notes) {
        final basis = n.section('근거');
        final mine = basis.isEmpty ? n.body : n.body.replaceAll(basis, '');
        for (final w in vague) {
          if (mine.contains(w)) {
            problems.add('${n.name} — "$w" 가 들어 있다 (확실한 것만 단정하거나 질문 노트로 돌릴 것)');
          }
        }
      }
      _report(problems);
      expect(problems, isEmpty, reason: 'wiki/_규칙.md 2번 — 흐리게 쓰지 않는다');
    });

    /// 노트가 가리킨 파일이 실제로 있는가. 리팩터링으로 파일이 옮겨가면 여기서 잡힌다.
    test('노트가 가리키는 코드 파일이 실제로 있다', () {
      if (notes.isEmpty) return;

      final problems = <String>[];
      for (final n in notes) {
        for (final ref in n.refs) {
          if (!File(ref.path).existsSync()) {
            problems.add('${n.name} → ${ref.path} 파일이 없다 (코드가 옮겨갔으면 노트를 고칠 것)');
          }
        }
      }
      _report(problems);
      expect(problems, isEmpty);
    });

    /// ★ 핵심. 노트에 백틱으로 인용한 코드 한 줄이 그 파일에 아직 그대로 있는가.
    test('노트가 인용한 코드값이 실제 코드와 일치한다', () {
      if (notes.isEmpty) return;

      final problems = <String>[];
      for (final n in notes) {
        for (final ref in n.refs) {
          final file = File(ref.path);
          if (!file.existsSync()) continue; // 위 테스트가 따로 잡는다
          final source = file.readAsStringSync();
          final flat = _flatten(source);

          for (final snippet in ref.snippets) {
            if (!flat.contains(_flatten(snippet))) {
              problems.add(
                '${n.name} → ${ref.path}\n'
                '      노트가 말하는 값 : $snippet\n'
                '      코드에 그런 줄이 없다. 둘 중 하나다 —\n'
                '        (a) 법이 바뀌어 노트를 고쳤다 → 코드를 고칠 차례다\n'
                '        (b) 코드를 먼저 고쳤다        → 순서가 뒤집혔다. 노트부터 고칠 것',
              );
            }
          }
        }
      }
      _report(problems);
      expect(problems, isEmpty, reason: '노트가 먼저고 코드가 따라온다');
    });

    /// 줄 번호는 코드가 조금만 움직여도 어긋난다. 실패시키지 않고 알려만 준다.
    test('노트에 적힌 줄 번호가 아직 맞다 (어긋나면 알림만)', () {
      if (notes.isEmpty) return;

      for (final n in notes) {
        for (final ref in n.refs) {
          if (ref.line == null || ref.snippets.isEmpty) continue;
          final file = File(ref.path);
          if (!file.existsSync()) continue;
          final lines = file.readAsLinesSync();
          final target = _flatten(ref.snippets.first);
          final actual = lines.indexWhere((l) => _flatten(l).contains(target));
          if (actual >= 0 && actual + 1 != ref.line) {
            // ignore: avoid_print
            print('  · ${n.name} → ${ref.path}:${ref.line} 이 실제로는 ${actual + 1}줄에 있다 '
                '(노트 줄 번호를 갱신하면 좋다)');
          }
        }
      }
      expect(true, isTrue); // 알림 전용
    });

    /// 세법은 썩는다. 확인일이 1년을 넘으면 제목에 ⚠️ 를 달아 재확인 대상으로 표시한다.
    test('확인일이 1년 넘은 노트는 제목에 ⚠️ 가 붙어 있다', () {
      if (notes.isEmpty) return;

      final now = DateTime.now();
      final problems = <String>[];
      for (final n in notes) {
        final checked = n.checkedOn;
        if (checked == null) continue;
        final age = now.difference(checked).inDays;
        final marked = n.title.contains('⚠️') || n.title.contains('⚠');
        if (age > 365 && !marked) {
          problems.add('${n.name} — 확인일이 ${age}일 전이다. 제목에 ⚠️ 를 붙이고 원문을 다시 열 것');
        }
      }
      _report(problems);
      expect(problems, isEmpty, reason: 'wiki/_규칙.md 6번 — 유효기간');
    });
  });
}

// ─────────────────────────────────────────────────────────────
// 파싱
// ─────────────────────────────────────────────────────────────

/// 노트 하나.
class _Note {
  _Note({
    required this.name,
    required this.title,
    required this.body,
    required this.grade,
    required this.checkedOn,
    required this.validUntil,
    required this.refs,
  });

  final String name;
  final String title;
  final String body;
  final String? grade;
  final DateTime? checkedOn;
  final String? validUntil;
  final List<_CodeRef> refs;

  static _Note parse(File f) {
    final body = f.readAsStringSync();
    final name = f.path.replaceAll(r'\', '/').split('/').last;

    String? field(String label) => RegExp(
          r'^\*\*' + RegExp.escape(label) + r':?\*\*[ \t]*(.+)$',
          multiLine: true,
        ).firstMatch(body)?.group(1)?.trim();

    final titleLine =
        RegExp(r'^#[ \t]+(.+)$', multiLine: true).firstMatch(body)?.group(1) ??
            name;

    DateTime? checked;
    final rawChecked = field('확인일');
    if (rawChecked != null) {
      final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(rawChecked);
      if (m != null) checked = DateTime.parse(m.group(0)!);
    }

    // "등급: A | B" 처럼 템플릿이 그대로 남은 경우까지 잡으려고 첫 글자만 본다.
    String? grade;
    final rawGrade = field('등급');
    if (rawGrade != null) {
      final m = RegExp(r'\b([A-Z])\b').firstMatch(rawGrade);
      grade = m?.group(1) ?? rawGrade;
    }

    return _Note(
      name: name,
      title: titleLine.trim(),
      body: body,
      grade: grade,
      checkedOn: checked,
      validUntil: field('유효기간'),
      refs: _parseRefs(_section(body, '앱에서 쓰이는 곳')),
    );
  }

  String section(String heading) => _section(body, heading);
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
  _CodeRef({required this.path, required this.line, required this.snippets});

  /// 저장소 루트 기준 경로. 예: `lib/core/tax_engine/tax_rates.dart`
  final String path;

  /// 노트에 `:18` 처럼 적힌 줄 번호. 없으면 null.
  final int? line;

  /// 그 줄에서 백틱으로 인용한 코드. 예: `static const double x = 1500000.0;`
  final List<String> snippets;
}

/// `## 앱에서 쓰이는 곳` 본문에서 `경로[:줄] … \`코드\`` 를 뽑는다.
///
/// 한 줄에 여러 인용문이 있으면 전부 대조 대상이다.
/// "없음" 한 줄만 있으면 대조할 것이 없다.
List<_CodeRef> _parseRefs(String section) {
  final refs = <_CodeRef>[];
  final pathRe = RegExp(r'((?:lib|test)[\w./\-가-힣]*\.dart)(?::(\d+))?');
  final codeRe = RegExp(r'`([^`\n]+)`');

  for (final raw in section.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line == '없음') continue;

    final pm = pathRe.firstMatch(line);
    if (pm == null) continue;

    final path = pm.group(1)!;
    final lineNo = pm.group(2) == null ? null : int.tryParse(pm.group(2)!);

    // 경로 자체가 백틱에 싸여 있을 수 있으니 코드 인용에서 걸러낸다.
    final snippets = <String>[
      for (final cm in codeRe.allMatches(line))
        if (!cm.group(1)!.contains('.dart')) cm.group(1)!.trim(),
    ]..removeWhere((s) => s.isEmpty);

    refs.add(_CodeRef(path: path, line: lineNo, snippets: snippets));
  }
  return refs;
}

// ─────────────────────────────────────────────────────────────
// 볼트 찾기 · 출력
// ─────────────────────────────────────────────────────────────

Directory? _findVault() {
  final env = Platform.environment;
  final candidates = <String?>[
    env['SEKKEUL_WIKI'],
    if (env['USERPROFILE'] != null) '${env['USERPROFILE']}/OneDrive/Desktop/wiki',
    if (env['HOME'] != null) '${env['HOME']}/OneDrive/Desktop/wiki',
  ];
  for (final c in candidates) {
    if (c == null || c.isEmpty) continue;
    final d = Directory(c.replaceAll(r'\', '/'));
    if (d.existsSync()) return d;
  }
  return null;
}

/// 공백 차이·줄바꿈 때문에 엉뚱하게 실패하지 않도록 납작하게 만든다.
String _flatten(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

void _report(List<String> problems) {
  for (final p in problems) {
    // ignore: avoid_print
    print('  ✕ $p');
  }
}

void _skipNote(String message) {
  // ignore: avoid_print
  print('  ⤳ 대조를 건너뛴다 — $message');
}
