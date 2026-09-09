import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/remote_notices.dart';

/// 원격 소식은 **우리가 손으로 쓰는 파일**이고, 앱은 그걸 그대로 믿고 그린다.
/// 오타 하나로 홈 화면이 죽으면 안 된다 — 그래서 파서는 절대 던지지 않고,
/// 못 읽은 건만 빼고 나머지를 살려야 한다.
void main() {
  Notice? one(Object? raw) => Notice.tryFrom(raw);

  group('한 건 읽기', () {
    test('필수 칸(id·title·date)이 다 있으면 읽힌다', () {
      final n = one({
        'id': 'a',
        'title': '제목',
        'date': '2026-09-09',
        'label': '교통',
        'summary': '한 줄',
      })!;
      expect(n.id, 'a');
      expect(n.label, '교통');
      expect(n.summary, '한 줄');
    });

    test('필수 칸이 하나라도 없으면 null', () {
      expect(one({'title': '제목', 'date': '2026-09-09'}), isNull);
      expect(one({'id': 'a', 'date': '2026-09-09'}), isNull);
      expect(one({'id': 'a', 'title': '제목'}), isNull);
      expect(one({'id': 'a', 'title': '제목', 'date': '어제'}), isNull);
    });

    test('label이 없으면 「소식」으로 둔다 — 빈 자리를 그리지 않는다', () {
      expect(one({'id': 'a', 'title': 't', 'date': '2026-09-09'})!.label, '소식');
    });

    test('Map이 아니거나 값 타입이 다르면 null이지 예외가 아니다', () {
      expect(one('문자열'), isNull);
      expect(one(null), isNull);
      expect(one({'id': 1, 'title': '제목', 'date': '2026-09-09'}), isNull);
    });

    test('http(s)가 아닌 주소는 링크가 되지 않는다', () {
      // 원격 파일이 javascript:·file:을 실어 보내도 탭 대상이 되면 안 된다.
      final n = one({
        'id': 'a',
        'title': 't',
        'date': '2026-09-09',
        'image': 'javascript:alert(1)',
        'sourceUrl': 'file:///etc/passwd',
      })!;
      expect(n.imageUrl, isNull);
      expect(n.sourceUrl, isNull);

      final ok = one({
        'id': 'b',
        'title': 't',
        'date': '2026-09-09',
        'image': 'https://example.go.kr/a.png',
      })!;
      expect(ok.imageUrl, 'https://example.go.kr/a.png');
    });

    test('changes는 세 칸이 다 문자열일 때만 살아남는다', () {
      final n = one({
        'id': 'a',
        'title': 't',
        'date': '2026-09-09',
        'changes': [
          {'what': '이용 횟수', 'before': '월 60회', 'after': '상한 없음'},
          {'what': '깨진 것', 'before': 3},
          '문자열',
          {'what': '  ', 'before': 'a', 'after': 'b'},
        ],
      })!;
      expect(n.changes.length, 1);
      expect(n.changes.single.after, '상한 없음');
    });

    test('body의 빈 문단은 버린다 — 빈 줄이 기사에 남지 않게', () {
      final n = one({
        'id': 'a',
        'title': 't',
        'date': '2026-09-09',
        'body': ['첫 문단', '   ', 7, '둘째 문단'],
      })!;
      expect(n.body, ['첫 문단', '둘째 문단']);
    });
  });

  group('목록 읽기', () {
    test('한 건이 깨져도 나머지는 그대로 나간다', () async {
      final list = await _loadFrom({
        'notices': [
          {'id': 'ok1', 'title': '괜찮은 것', 'date': '2026-09-01'},
          {'title': 'id가 없다', 'date': '2026-09-02'},
          {'id': 'ok2', 'title': '이것도 괜찮다', 'date': '2026-09-03'},
        ]
      });
      expect(list.map((n) => n.id), ['ok2', 'ok1']); // 최신이 먼저
    });

    test('until이 지난 건은 안 나온다 — 지우러 오지 않아도 된다', () async {
      final list = await _loadFrom({
        'notices': [
          {
            'id': 'gone',
            'title': '끝난 소식',
            'date': '2020-01-01',
            'until': '2020-12-31'
          },
          {'id': 'live', 'title': '사는 소식', 'date': '2026-09-01'},
        ]
      });
      expect(list.map((n) => n.id), ['live']);
    });

    test('망가진 JSON이면 예외 대신 빈 목록', () async {
      final f = await _tmp('{이건 JSON이 아니다');
      RemoteNotices.debugOverride(cacheFile: f, client: _deadClient);
      expect(await RemoteNotices.load(), isEmpty);
    });

    test('인터넷이 안 되면 마지막으로 받아 둔 것을 쓴다', () async {
      final list = await _loadFrom({
        'notices': [
          {'id': 'cached', 'title': '캐시에 있던 것', 'date': '2026-09-01'}
        ]
      });
      expect(list.single.id, 'cached');
    });
  });

  test('docs/notices.json이 앱이 읽는 형태다', () async {
    // 배포 파일 자체를 파서에 통과시킨다. 오타는 push 전에 여기서 걸린다.
    final f = File('docs/notices.json');
    expect(f.existsSync(), isTrue, reason: 'docs/notices.json이 없다');
    final raw = jsonDecode(f.readAsStringSync()) as Map;
    final items = raw['notices'] as List;
    final parsed = [for (final e in items) Notice.tryFrom(e)];
    expect(parsed.where((n) => n == null), isEmpty,
        reason: '읽히지 않는 항목이 있다 — 필수 칸(id·title·date)을 보라');

    final ids = parsed.map((n) => n!.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'id가 중복이다 — 닫기 기록이 섞인다');
  });
}

/// 캐시에 [data]를 넣어 두고, 네트워크는 죽은 상태로 읽는다.
Future<List<Notice>> _loadFrom(Object data) async {
  final f = await _tmp(jsonEncode(data));
  RemoteNotices.debugOverride(cacheFile: f, client: _deadClient);
  return RemoteNotices.load();
}

Future<File> _tmp(String body) async {
  final dir = await Directory.systemTemp.createTemp('sekkeul_notices');
  final f = File('${dir.path}/notices.json');
  await f.writeAsString(body);
  // TTL(6시간) 안이어야 네트워크를 안 탄다.
  return f;
}

/// 어떤 요청이든 실패하는 클라이언트 — 비행기 모드와 같은 상태.
HttpClient _deadClient() => HttpClient(context: SecurityContext(withTrustedRoots: false))
  ..connectionTimeout = const Duration(milliseconds: 1);
