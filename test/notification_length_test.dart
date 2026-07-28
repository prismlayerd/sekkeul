import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/notifications/system_reminder_catalog.dart';

/// 알림 문구 길이 상한 — 실기기에서 문장이 잘리던 것을 막는다.
///
/// 안드로이드 접힌 알림은 제목·본문을 각각 **한 줄만** 보여주고 나머지는 `…`로
/// 자른다. 한글 기본 폰트 기준 좁은 화면에서 제목 16자·본문 30자쯤이 한계라,
/// 그 안에서 끊기지 않게 못박는다. 넘겨야 할 이유가 생기면 상한을 올리는 게
/// 아니라 문구를 줄인다 — 잘린 문장은 안 읽힌다.
const int kTitleMax = 16;
const int kBodyMax = 30;

void main() {
  test('알림 카탈로그 문구가 한 줄 안에 들어간다', () {
    final over = <String>[];
    for (final item in kSystemReminderCatalog) {
      // runes로 센다 — 이모지·서로게이트가 섞여도 사람이 보는 글자 수와 맞다.
      final t = item.title.runes.length;
      final b = item.body.runes.length;
      if (t > kTitleMax) over.add('제목 $t자 (${item.title})');
      if (b > kBodyMax) over.add('본문 $b자 (${item.body})');
    }
    expect(over, isEmpty, reason: '한 줄을 넘겨 잘린다:\n${over.join('\n')}');
  });

  test('본문이 제목을 그대로 반복하지 않는다', () {
    // 접힌 알림은 두 줄뿐이다. 한 줄을 제목 반복에 쓰면 누를 이유가 안 남는다.
    final dup = kSystemReminderCatalog
        .where((e) => e.body.contains(e.title))
        .map((e) => e.title)
        .toList();
    expect(dup, isEmpty, reason: '본문이 제목을 반복한다: $dup');
  });
}
