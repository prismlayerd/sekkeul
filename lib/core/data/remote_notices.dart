import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// **앱을 새로 받지 않아도 바뀌는 소식.**
///
/// 세끌은 오프라인 앱이다. 사용자가 적은 것은 기기 밖으로 나가지 않는다.
/// 그런데 제도가 바뀌는 것은 우리가 정하는 일이 아니라서, 그때마다 스토어
/// 업데이트를 눌러 달라고 할 수는 없다 — 실사용 후기가 그랬다.
///
/// 그래서 **소식 카드만** 인터넷에서 받는다. 보내는 것은 없다.
/// GET 한 번이 전부고, 실패하면 마지막으로 받아 둔 것을 쓰고, 그것도 없으면
/// 카드를 안 그린다. 어느 경우에도 앱의 나머지는 그대로 돈다.
///
/// 실을 곳은 이미 있는 GitHub Pages다(개인정보처리방침이 올라가 있는 그 주소).
/// 서버를 새로 두지 않는다 — `docs/notices.json`을 고쳐 push하면 그게 배포다.
class RemoteNotices {
  static const _url =
      'https://prismlayerd.github.io/sekkeul/notices.json';

  /// 이 시간이 지나야 다시 받으러 간다. 하루에 몇 번씩 갈 이유가 없다 —
  /// 제도는 그렇게 자주 안 바뀌고, 사용자의 데이터 요금은 우리 것이 아니다.
  static const _ttl = Duration(hours: 6);

  /// 통째로 못 믿을 만큼 커지면 버린다. 원격 파일이 어쩌다 깨져도
  /// 앱이 메모리를 먹고 죽지는 않게.
  static const _maxBytes = 512 * 1024;

  static File? _cacheFileOverride;
  static HttpClient Function()? _clientOverride;

  /// 테스트에서 캐시 위치와 HTTP 클라이언트를 갈아 끼운다.
  static void debugOverride({File? cacheFile, HttpClient Function()? client}) {
    _cacheFileOverride = cacheFile;
    _clientOverride = client;
  }

  static Future<File> _cacheFile() async {
    if (_cacheFileOverride != null) return _cacheFileOverride!;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/notices.json');
  }

  /// 소식 목록. **절대 예외를 던지지 않는다** — 홈 화면이 이걸 기다리다
  /// 멈추면 안 된다. 못 받으면 빈 목록이다.
  ///
  /// [force]는 사용자가 직접 새로고침한 경우다 — TTL을 무시한다.
  static Future<List<Notice>> load({bool force = false}) async {
    final cached = await _readCache();
    if (!force && cached != null && cached.fresh) return cached.notices;

    final fetched = await _fetch();
    if (fetched == null) return cached?.notices ?? const [];
    return fetched;
  }

  static Future<_Cached?> _readCache() async {
    try {
      final f = await _cacheFile();
      if (!await f.exists()) return null;
      final age = DateTime.now().difference(await f.lastModified());
      return _Cached(_parse(await f.readAsString()), age < _ttl);
    } catch (_) {
      return null;
    }
  }

  static Future<List<Notice>?> _fetch() async {
    HttpClient? client;
    try {
      client = (_clientOverride ?? HttpClient.new)()
        ..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(_url));
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      if (res.contentLength > _maxBytes) return null;

      final body = await res.transform(utf8.decoder).join();
      if (body.length > _maxBytes) return null;

      final notices = _parse(body);
      // 읽히는 걸 확인한 뒤에만 캐시에 쓴다 — 깨진 파일을 저장해 두면
      // 다음에 인터넷이 없을 때 그 깨진 걸 쓰게 된다.
      try {
        await (await _cacheFile()).writeAsString(body);
      } catch (_) {}
      return notices;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// 한 건이 깨져도 나머지는 살린다. 원격 파일은 손으로 쓰는 것이라
  /// 오타 하나로 전부를 잃을 이유가 없다.
  static List<Notice> _parse(String body) {
    final root = jsonDecode(body);
    final items = (root is Map ? root['notices'] : root) as List? ?? const [];
    final now = DateTime.now();
    final out = <Notice>[];
    for (final e in items) {
      final n = Notice.tryFrom(e);
      if (n != null && !n.isExpired(now)) out.add(n);
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }
}

class _Cached {
  final List<Notice> notices;
  final bool fresh;
  const _Cached(this.notices, this.fresh);
}

/// 소식 한 건 — 뉴스 한 꼭지처럼 제목·사진·요약·본문·출처를 갖는다.
class Notice {
  final String id;
  final String label;
  final String title;
  final String summary;
  final String? imageUrl;
  final List<String> body;
  final List<NoticeChange> changes;
  final String? source;
  final String? sourceUrl;
  final DateTime date;
  final DateTime? until;

  const Notice({
    required this.id,
    required this.label,
    required this.title,
    required this.summary,
    required this.body,
    required this.date,
    this.imageUrl,
    this.changes = const [],
    this.source,
    this.sourceUrl,
    this.until,
  });

  bool isExpired(DateTime now) => until != null && now.isAfter(until!);

  /// 필수 칸이 비었거나 형태가 다르면 `null`. 던지지 않는다.
  static Notice? tryFrom(Object? raw) {
    if (raw is! Map) return null;
    String? str(String k) {
      final v = raw[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final id = str('id');
    final title = str('title');
    final date = _date(str('date'));
    if (id == null || title == null || date == null) return null;

    return Notice(
      id: id,
      label: str('label') ?? '소식',
      title: title,
      summary: str('summary') ?? '',
      imageUrl: _safeUrl(str('image')),
      body: [
        for (final p in (raw['body'] as List? ?? const []))
          if (p is String && p.trim().isNotEmpty) p.trim(),
      ],
      changes: [
        for (final c in (raw['changes'] as List? ?? const []))
          if (NoticeChange.tryFrom(c) case final v?) v,
      ],
      source: str('source'),
      sourceUrl: _safeUrl(str('sourceUrl')),
      date: date,
      until: _date(str('until')),
    );
  }

  static DateTime? _date(String? s) => s == null ? null : DateTime.tryParse(s);

  /// http(s)만 연다. 원격 파일이 `javascript:`나 `file:`을 실어 보내도
  /// 그건 링크가 되지 않는다.
  static String? _safeUrl(String? s) {
    if (s == null) return null;
    final u = Uri.tryParse(s);
    return (u != null && (u.scheme == 'https' || u.scheme == 'http')) ? s : null;
  }
}

/// 무엇이 어떻게 바뀌었나 — 전/후 한 줄.
/// 사용자가 원한 건 "바뀌었다"가 아니라 "예전엔 이랬는데 지금은 이래요"다.
class NoticeChange {
  final String what;
  final String before;
  final String after;

  const NoticeChange({
    required this.what,
    required this.before,
    required this.after,
  });

  static NoticeChange? tryFrom(Object? raw) {
    if (raw is! Map) return null;
    final w = raw['what'], b = raw['before'], a = raw['after'];
    if (w is! String || b is! String || a is! String) return null;
    if (w.trim().isEmpty) return null;
    return NoticeChange(what: w.trim(), before: b.trim(), after: a.trim());
  }
}
