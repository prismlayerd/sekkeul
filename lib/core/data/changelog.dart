import 'package:flutter/services.dart' show rootBundle;

/// **이 앱이 자기 변경 내역을 들고 다닌다.**
///
/// 서버가 없어서 "새 버전에 뭐가 들었나"를 설치 **전에** 보여줄 방법이 없다.
/// Play의 업데이트 API도 출시 노트를 안 준다(우선순위와 버전코드가 전부다).
/// 그래서 방향을 뒤집었다 — 새 버전이 **자기 얘기**를 품고 온다. 설치가 끝난
/// 뒤에 "이번에 뭐가 바뀌었는지"를 보여주면 정확하고, 서버도 필요 없다.
///
/// 원문은 `assets/changelog.md` 한 곳이고, 같은 파일을 `tool/play_publish.py`가
/// 읽어 Play의 「새로운 기능」으로 올린다. 두 곳에 따로 쓰면 반드시 어긋난다.
class ChangeEntry {
  final String version; // '1.1.0'
  final int build; // 9
  final String date; // '2026-08-17'
  final bool taxUpdate; // 세법·복지 기준이 바뀐 릴리스인가
  final List<String> lines;

  const ChangeEntry({
    required this.version,
    required this.build,
    required this.date,
    required this.taxUpdate,
    required this.lines,
  });

  String get label => 'v$version';
}

/// `## 1.1.0 (9) · 2026-08-17 · tax` 머리줄.
final RegExp _head = RegExp(
    r'^##\s+([\d.]+)\s*\((\d+)\)\s*·\s*(\d{4}-\d{2}-\d{2})\s*(·\s*tax)?\s*$');

/// 변경 내역 원문 → 최신순 목록.
///
/// 파일이 깨져 있어도 앱은 계속 돌아야 한다. 못 읽은 줄은 조용히 버린다 —
/// 변경 내역을 못 보여주는 것과 앱이 안 켜지는 것은 무게가 다르다.
List<ChangeEntry> parseChangelog(String src) {
  final out = <ChangeEntry>[];
  String? version, date;
  int? build;
  var tax = false;
  var lines = <String>[];

  void flush() {
    if (version != null && build != null && lines.isNotEmpty) {
      out.add(ChangeEntry(
          version: version!,
          build: build!,
          date: date ?? '',
          taxUpdate: tax,
          lines: List.unmodifiable(lines)));
    }
    version = null;
    build = null;
    date = null;
    tax = false;
    lines = <String>[];
  }

  for (final raw in src.split('\n')) {
    final line = raw.trimRight();
    final m = _head.firstMatch(line);
    if (m != null) {
      flush();
      version = m.group(1);
      build = int.tryParse(m.group(2)!);
      date = m.group(3);
      tax = m.group(4) != null;
      continue;
    }
    if (version == null) continue; // 머리줄 전의 설명문은 버린다.
    if (line.startsWith('- ')) lines.add(line.substring(2).trim());
  }
  flush();
  out.sort((a, b) => b.build.compareTo(a.build));
  return out;
}

List<ChangeEntry>? _cache;

/// 번들에서 읽어 캐시한다. 앱이 도는 동안 바뀌지 않는 값이다.
Future<List<ChangeEntry>> loadChangelog() async {
  if (_cache != null) return _cache!;
  try {
    _cache = parseChangelog(await rootBundle.loadString('assets/changelog.md'));
  } catch (_) {
    _cache = const [];
  }
  return _cache!;
}
