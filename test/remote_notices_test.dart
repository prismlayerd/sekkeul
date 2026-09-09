import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/remote_notices.dart';
import 'package:secul/ui/screens/notice_detail_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:secul/ui/theme/text_wrap.dart';

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

    test('망가진 캐시는 쓰지 않고 앱에 실어 둔 것으로 떨어진다', () async {
      // 예외를 던지지 않는 게 첫째고, 깨진 걸 억지로 읽지 않는 게 둘째다.
      final f = await _tmp('{이건 JSON이 아니다');
      RemoteNotices.debugOverride(cacheFile: f, client: _deadClient);
      final list = await RemoteNotices.load();
      expect(list.map((n) => n.id), contains('2026-09-09-catalog-recheck'));
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

  testWidgets('소식 제목이 홈 카드 두 줄 안에 들어간다', (t) async {
    // 카드 헤드라인은 maxLines 2에 ellipsis인데, 한글은 줄임표가 붙기 전에
    // 뒷줄이 통째로 사라진다 — 잘린 줄 자체를 모르게 된다. 실제로 한 번
    // "K-패스가 「모두의카드」로 / 바뀌었어요"의 뒷줄을 잃었다.
    //
    // 그래서 글자 수 어림이 아니라 **실제 폭으로 잰다.** 폰트나 타입 스케일을
    // 건드리면 이 검사가 같이 움직인다.
    // 테스트 기본 글꼴은 모든 글자를 같은 네모로 그린다 — 그걸로 재면
    // keepWords가 넣는 폭 0의 조이너까지 한 글자를 먹어 폭이 두 배가 된다.
    // 앱이 실제로 쓰는 글꼴을 실어서 잰다.
    for (final f in const {
      'IBM Plex Mono': 'assets/fonts/IBMPlexMono-Bold.ttf',
      'Nanum Gothic Coding': 'assets/fonts/NanumGothicCoding-Bold.ttf',
    }.entries) {
      // 파일을 **동기로** 읽는다. testWidgets 안에서 진짜 비동기 I/O를
      // 기다리면 가짜 시계가 돌지 않아 그대로 멈춘다.
      await (FontLoader(f.key)
            ..addFont(
                Future.value(ByteData.sublistView(File(f.value).readAsBytesSync()))))
          .load();
    }

    const screen = 375.0; // 흔한 폰 너비. 이보다 좁으면 더 잘린다.
    const cardPad = 20.0 * 2; // 홈 좌우 여백
    const textShare = 0.60; // 사진이 있는 카드가 글자에 주는 몫
    final maxWidth = (screen - cardPad) * textShare;

    final raw = jsonDecode(File('docs/notices.json').readAsStringSync()) as Map;
    final tooLong = <String>[];
    for (final e in (raw['notices'] as List).cast<Map>()) {
      final n = Notice.tryFrom(e)!;
      final painter = TextPainter(
        text: TextSpan(
          text: (n.title.contains('\n') ? n.title : '${n.title}\n').keepWords,
          style: AppTheme.display(AppTheme.serifSM, const Color(0xFF000000),
              height: 1.3),
        ),
        maxLines: 2,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      if (painter.didExceedMaxLines) tooLong.add('${n.id} → ${n.title}');
      painter.dispose();
    }
    expect(tooLong, isEmpty,
        reason: '카드에서 뒷줄이 잘린다. 제목을 줄이거나 줄바꿈 위치를 옮겨라');
  });

  group('기사 화면', () {
    // 배포 파일의 진짜 한 건을 파서에 통과시켜 그대로 그린다 —
    // JSON → 모델 → 화면이 한 줄로 이어지는지 여기서 걸린다.
    Notice fromFeed(String id) {
      final raw = jsonDecode(File('docs/notices.json').readAsStringSync()) as Map;
      final hit = (raw['notices'] as List).cast<Map>().where((e) => e['id'] == id);
      expect(hit, isNotEmpty, reason: '$id 소식이 docs/notices.json에 없다');
      return Notice.tryFrom(hit.first)!;
    }

    testWidgets('전후 표가 「무엇이 얼마에서 얼마로」를 다 보여준다', (t) async {
      final n = fromFeed('2026-09-09-mudeuui-card');
      expect(n.changes, isNotEmpty);
      // 기사는 한 화면보다 길다. ListView는 화면 밖을 안 그리므로
      // 판을 길게 잡아 전부 세워 놓고 본다.
      await t.binding.setSurfaceSize(const Size(400, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(MaterialApp(home: NoticeDetailScreen(notice: n)));
      await t.pumpAndSettle();

      expect(find.text('무엇이 바뀌었나'), findsOneWidget);
      for (final c in n.changes) {
        // 화면은 .keepWords로 줄바꿈 힌트를 섞어 그린다 — 기대값도 같은 변환을 거친다.
        expect(find.text(c.what.keepWords), findsOneWidget, reason: '항목이 안 보인다');
        expect(find.text(c.before.keepWords), findsOneWidget, reason: '이전 값이 안 보인다');
        expect(find.text(c.after.keepWords), findsOneWidget, reason: '바뀐 값이 안 보인다');
      }
      expect(find.textContaining('출처'), findsOneWidget);
      expect(find.text('원문 보기'), findsOneWidget);
    });

    testWidgets('전후가 없는 소식은 표를 그리지 않는다', (t) async {
      final n = fromFeed('2026-09-09-catalog-recheck');
      expect(n.changes, isEmpty);
      await t.pumpWidget(MaterialApp(home: NoticeDetailScreen(notice: n)));
      await t.pumpAndSettle();
      expect(find.text('무엇이 바뀌었나'), findsNothing);
      expect(find.text(n.body.first.keepWords), findsOneWidget);
    });

    testWidgets('사진이 없어도 화면이 선다', (t) async {
      final n = fromFeed('2026-09-09-kmove-settlement');
      expect(n.imageUrl, isNull, reason: '이 소식에 사진이 없어야 이 검사가 뜻이 있다');
      await t.pumpWidget(MaterialApp(home: NoticeDetailScreen(notice: n)));
      await t.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text(n.summary.keepWords), findsOneWidget);
    });
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
