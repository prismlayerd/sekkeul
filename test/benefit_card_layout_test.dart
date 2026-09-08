import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/benefit_screen.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/screen_registry.dart';

/// **혜택 카드가 글 한 덩어리가 아니라 절로 그려지는가.**
///
/// 설명은 `desc` 문자열 하나였고 화면은 그걸 `Text` 하나로 뿌렸다. 그래서 눌러도
/// 글만 나왔다 — 제목을 키울 수도, 바뀐 줄만 강조할 수도 없었다.
/// 이 검사가 지키는 것은 **그 문자열이 다시 한 덩어리로 돌아가지 않는 것**이다.
Future<void> _openBenefits(WidgetTester t) async {
  await seedRealisticUser('직장인');
  await t.pumpWidget(const MaterialApp(home: BenefitScreen(userType: '직장인')));
  await t.pumpAndSettle();
}

/// 화면에 그려진 Text 위젯들의 글자를 모은다.
List<String> _texts(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? '')
    .where((s) => s.isNotEmpty)
    .toList();

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  testWidgets('접힌 목록에서도 요약이 보인다 — 이름만으로 고르지 않게', (t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await _openBenefits(t);

    // 카테고리를 하나 펼쳐 카드 목록을 꺼낸다.
    await t.tap(find.byType(ExpansionTile).first);
    await t.pumpAndSettle();

    // 접힌 카드의 요약은 두 줄로 잘린다. maxLines가 풀려 있으면 목록이 무너진다.
    final clipped = t
        .widgetList<Text>(find.byType(Text))
        .where((w) => w.maxLines == 2 && w.overflow == TextOverflow.ellipsis);
    expect(clipped, isNotEmpty,
        reason: '접힌 카드에 두 줄짜리 요약이 하나도 없다 — 목록이 다시 이름만 남았다');
  });

  testWidgets('카드를 펼치면 절 제목과 항목이 각각 다른 Text로 그려진다', (t) async {
    t.view.physicalSize = const Size(390, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await _openBenefits(t);

    // 카테고리 → 그 안의 첫 카드까지 두 번 펼친다.
    await t.tap(find.byType(ExpansionTile).first);
    await t.pumpAndSettle();
    await t.tap(find.byType(ExpansionTile).at(1));
    await t.pumpAndSettle();

    final texts = _texts(t);

    // 한 덩어리였다면 `\n`이 잔뜩 든 Text가 하나 있었다. 이제 없어야 한다.
    final blobs = texts.where((s) => '\n'.allMatches(s).length >= 3);
    expect(blobs, isEmpty,
        reason: '줄바꿈이 3개 이상인 Text가 남아 있다 — 설명이 다시 한 덩어리로 그려진다:\n$blobs');

    // 마커는 본문에서 떨어져 나와 제 칸에 서 있어야 줄이 넘어가도 안 어긋난다.
    expect(texts, contains('·'),
        reason: '항목 마커가 본문에 붙어 있다 — 줄이 넘어가면 들여쓰기가 무너진다');
    expect(texts.any((s) => s.startsWith('· ')), isFalse,
        reason: '`· ` 로 시작하는 Text가 있다 — 마커를 떼지 않고 통째로 그렸다');
  });
}
