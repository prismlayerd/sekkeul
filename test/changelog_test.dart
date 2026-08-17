import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/changelog.dart';

/// **올릴 버전에는 변경 내역이 있어야 한다.**
///
/// 앱 안 「업데이트 소식」과 Play의 「새로운 기능」이 `assets/changelog.md`
/// 한 파일을 같이 읽는다. 안 적고 올리면 사용자는 무엇이 바뀌었는지 두 곳
/// 어디서도 못 본다 — 그리고 그건 올린 뒤에야 알게 된다.
void main() {
  final src = File('assets/changelog.md').readAsStringSync();
  final entries = parseChangelog(src);

  /// pubspec의 `version: 1.1.0+9`.
  (String, int) pubspecVersion() {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final m = RegExp(r'version:\s*([\d.]+)\+(\d+)').firstMatch(line)!;
    return (m.group(1)!, int.parse(m.group(2)!));
  }

  test('지금 버전의 변경 내역이 적혀 있다', () {
    final (version, build) = pubspecVersion();
    final hit = entries.where((e) => e.build == build).toList();
    expect(hit, hasLength(1),
        reason: 'pubspec은 $version+$build인데 changelog.md에 ($build) 항목이 없습니다.\n'
            '적힌 버전: ${entries.map((e) => '${e.version}(${e.build})').join(', ')}');
    expect(hit.single.version, version,
        reason: '빌드번호는 맞는데 버전 이름이 다릅니다');
    expect(hit.single.lines, isNotEmpty, reason: '항목만 있고 내용이 없습니다');
  });

  test('최신이 맨 위로 온다', () {
    for (var i = 1; i < entries.length; i++) {
      expect(entries[i - 1].build, greaterThan(entries[i].build));
    }
  });

  test('머리줄 형식을 지킨다', () {
    // 형식이 틀리면 그 항목은 통째로 사라진다 — 조용히.
    final heads = RegExp(r'^##\s+\S.*$', multiLine: true)
        .allMatches(src)
        .map((m) => m.group(0)!)
        .where((h) => !h.contains('세끌 변경 내역'))
        .length;
    expect(entries.length, heads,
        reason: '`## ` 줄은 $heads개인데 읽힌 항목은 ${entries.length}개입니다. '
            '형식은 `## 1.1.0 (9) · 2026-08-17` 입니다');
  });

  test('세법 표시는 tax를 붙인 항목에만 붙는다', () {
    // 안 바뀌었는데 붙이면 업데이트 카드가 "세법이 바뀌었다"고 거짓말한다.
    for (final e in entries) {
      final head = RegExp('^##.*\\(${e.build}\\).*\$', multiLine: true)
          .firstMatch(src)!
          .group(0)!;
      expect(e.taxUpdate, head.contains('· tax'), reason: head);
    }
  });

  test('빈 줄과 설명문은 항목으로 새지 않는다', () {
    for (final e in entries) {
      for (final line in e.lines) {
        expect(line.trim(), isNotEmpty);
      }
    }
    // 파일 맨 위 사용법 설명이 첫 항목에 섞이면 안 된다.
    expect(entries.first.lines.any((l) => l.contains('한 줄씩')), isFalse);
  });
}
