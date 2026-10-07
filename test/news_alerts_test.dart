import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/remote_notices.dart';
import 'package:secul/core/notifications/news_alerts.dart';
import 'package:secul/ui/screens/benefit_screen.dart';
import 'package:secul/ui/screens/home/info_alerts_section.dart';
import 'package:secul/ui/screens/notification_settings_screen.dart';

/// 1장(소식·정보)과 2장(가계부)은 알림 설정이 따로다.
/// 소식 마감 알림은 **내게 맞고 아직 알릴 때가 남은** 소식만 건다.
Notice _n(String id, {DateTime? until, Target target = const Target()}) => Notice(
    id: id,
    label: '청년',
    title: '제목 $id',
    summary: '요약',
    body: const [],
    date: DateTime(2026, 10, 1),
    until: until,
    target: target);

void main() {
  final now = DateTime(2026, 10, 7, 12);

  test('마감 3일 전 아침이 남은 소식만 건다', () {
    final list = [
      _n('a', until: DateTime(2026, 10, 16)), // 10/13 09:00 — 남음
      _n('b', until: DateTime(2026, 10, 9)), // 10/6 09:00 — 이미 지남
      _n('c'), // 마감 없음
      _n('d', until: DateTime(2026, 10, 1)), // 만료
    ];
    final due = NewsAlerts.due(list, const UserFacts(), now);
    expect(due.map((e) => e.$1.id), ['a']);
    expect(due.single.$2, DateTime(2026, 10, 13, 9));
  });

  test('내게 맞지 않는 소식은 안 건다', () {
    final seoul = _n('s', until: DateTime(2026, 10, 16), target: const Target(regions: ['서울']));
    expect(NewsAlerts.due([seoul], const UserFacts(sido: '부산'), now), isEmpty);
    expect(NewsAlerts.due([seoul], const UserFacts(sido: '서울'), now), hasLength(1));
    expect(NewsAlerts.due([seoul], const UserFacts(), now), isEmpty, reason: '지역을 모르면 숨긴다');
  });

  test('알림 ID는 같은 소식이면 같고, 기존 알림 번호 밖이다', () {
    final a = NewsAlerts.idFor(_n('2026-09-19-youth-future-2nd'));
    expect(a, NewsAlerts.idFor(_n('2026-09-19-youth-future-2nd')));
    expect(a, inInclusiveRange(3000, 3899));
  });

  test('조건이 걸린 소식은 공통이 아니고, 맨몸은 공통이다', () {
    expect(_n('c').isCommon, isTrue);
    expect(_n('a', target: const Target(audience: ['직장인'])).isCommon, isFalse);
    expect(_n('r', target: const Target(regions: ['서울'])).isCommon, isFalse);
    expect(_n('g', target: const Target(ageMax: 34)).isCommon, isFalse);
    expect(_n('q', target: const Target(requires: ['car'])).isCommon, isFalse);
  });

  test('공통 소식은 마감이 가깝거나 올라온 지 2주가 안 된 것만 배너에 오른다', () {
    final recent = _n('x'); // date 10/1, 마감 없음
    expect(recent.inBannerOrFresh(DateTime(2026, 10, 7)), isTrue);
    expect(recent.inBannerOrFresh(DateTime(2026, 10, 20)), isFalse);
    expect(_n('y', until: DateTime(2026, 10, 25)).inBannerOrFresh(DateTime(2026, 10, 20)), isTrue);
    expect(_n('z', until: DateTime(2026, 10, 5)).inBannerOrFresh(DateTime(2026, 10, 7)), isFalse,
        reason: '마감 지난 소식은 올라온 지 얼마 안 됐어도 배너에서 뺀다');
  });

  test('올라온 지 일주일 안이면 최신이다', () {
    final n = _n('f'); // date 10/1
    expect(n.isFresh(DateTime(2026, 10, 8)), isTrue);
    expect(n.isFresh(DateTime(2026, 10, 9)), isFalse);
  });

  test('앱 공지는 kind로 가려지고, 모르는 값은 혜택 소식이다', () {
    Notice? parse(Object? kind) => Notice.tryFrom(
        {'id': 'k', 'title': 't', 'date': '2026-10-01', if (kind != null) 'kind': kind});
    expect(parse('app')!.isApp, isTrue);
    expect(parse(null)!.isApp, isFalse);
    expect(parse('whatever')!.isApp, isFalse);
  });

  test('앱 공지에는 마감 알림을 안 건다', () {
    final app = Notice(
        id: 'p', label: '세끌', title: '패치', summary: '', body: const [],
        date: DateTime(2026, 10, 1), until: DateTime(2026, 10, 16), kind: 'app');
    expect(NewsAlerts.due([app], const UserFacts(), now), isEmpty);
  });

  testWidgets('앱 공지(패치 내역)는 맞춤 혜택 목록에 안 쌓인다', (t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final patch = Notice(
        id: 'p', label: '세끌', title: '패치 내역 소식', summary: '', body: const [],
        date: DateTime(2026, 10, 1), kind: 'app');
    await t.pumpWidget(MaterialApp(
        home: BenefitScreen(userType: '직장인', notices: [_n('b'), patch])));
    await t.pumpAndSettle();
    expect(find.text('제목 b'), findsOneWidget);
    expect(find.text('패치 내역 소식'), findsNothing);
  });

  Future<void> pumpSettings(WidgetTester t, NotifScope scope) async {
    t.view.physicalSize = const Size(390, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({'user_type': '직장인', 'type_identified': true});
    // 파일 입출력은 가짜 시계 밖(runAsync)에서 해야 끝난다.
    await t.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('sekkeul_news');
      final f = File('${dir.path}/notices.json');
      await f.writeAsString(jsonEncode({'notices': []}));
      RemoteNotices.debugOverride(cacheFile: f);
    });
    await t.pumpWidget(MaterialApp(
        home: NotificationSettingsScreen(userType: '직장인', scope: scope)));
    // 파일 읽기가 단계마다 실제 시계를 한 번씩 필요로 한다.
    for (var i = 0; i < 12; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('1장 설정에는 소식·정보만, 세금·가계부 알림은 없다', (t) async {
    await pumpSettings(t, NotifScope.news);
    expect(find.text('소식·정보 알림'), findsOneWidget);
    expect(find.text('소식 마감 알림'), findsOneWidget);
    expect(find.text('혜택·생활 정보'), findsOneWidget);
    expect(find.text('세금 일정'), findsNothing);
    expect(find.text('내 기록 알림'), findsNothing);
    expect(find.text('내 리마인더 관리'), findsNothing);
  });

  testWidgets('2장 설정에는 세금·가계부만, 소식 알림은 없다', (t) async {
    await pumpSettings(t, NotifScope.ledger);
    expect(find.text('가계부 알림'), findsOneWidget);
    expect(find.text('세금 일정'), findsOneWidget);
    expect(find.text('내 기록 알림'), findsOneWidget);
    expect(find.text('내 리마인더 관리'), findsOneWidget);
    expect(find.text('소식 마감 알림'), findsNothing);
    expect(find.text('혜택·생활 정보'), findsNothing);
  });

  testWidgets('전체 설정은 둘 다 보인다', (t) async {
    await pumpSettings(t, NotifScope.all);
    for (final s in ['소식 마감 알림', '혜택·생활 정보', '세금 일정', '내 기록 알림', '내 리마인더 관리']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
  });

  testWidgets('홈에는 최신 소식 둘만 — 오래된 건 맞춤 혜택으로', (t) async {
    t.view.physicalSize = const Size(390, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    final today = DateTime.now();
    Notice at(String id, int daysAgo, {DateTime? until}) => Notice(
        id: id, label: '청년', title: '제목 $id', summary: '요약', body: const [],
        date: today.subtract(Duration(days: daysAgo)), until: until);
    final ns = [
      at('n1', 1), at('n2', 2), at('n3', 3), // 일주일 안 — 셋이어도 둘만
      at('old', 20), // 일주일이 넘음
      at('ended', 1, until: today.subtract(const Duration(days: 3))), // 마감 지남
    ];
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: InfoAlertsSection(
                    userType: '직장인', notices: ns, allCount: 9, onOpenBenefits: () {})))));
    await t.pumpAndSettle();
    expect(find.text('제목 n1'), findsOneWidget);
    expect(find.text('제목 n2'), findsOneWidget);
    expect(find.text('제목 n3'), findsNothing, reason: '최대 둘');
    expect(find.text('제목 old'), findsNothing, reason: '일주일 넘은 소식이 홈에 남았다');
    expect(find.text('제목 ended'), findsNothing, reason: '마감 지난 소식이 홈에 남았다');
    expect(find.textContaining('지난 소식까지 맞춤 혜택 9건 보기'), findsOneWidget);
  });
}
