import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data_vintage.dart';

/// **앱이 말하는 "기준 시점"이 실제 대조 기록보다 뒤처지지 않는지 본다.**
///
/// 계산기 하단과 업데이트 카드가 `DataVintage.checkedOn`을 그대로 보여준다.
/// 혜택 카탈로그를 새로 대조하고 이 상수를 안 올리면, 앱이 사용자에게
/// **실제보다 오래된 날짜를 말하게 된다** — 틀린 방향이 아니라 손해 보는 방향이라
/// 눈에 잘 안 띈다.
void main() {
  test('기준 시점이 혜택 카탈로그의 확인일보다 오래되지 않았다', () {
    final src =
        File('lib/ui/screens/benefit_screen.dart').readAsStringSync();
    final dates = [
      for (final m in RegExp(r"on:\s*'(\d{4}-\d{2}-\d{2})'").allMatches(src))
        DateTime.parse(m.group(1)!),
    ];
    expect(dates, isNotEmpty, reason: 'verified 기록을 못 찾았다 — 파싱이 깨졌는지 볼 것');

    final newest = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final stated = DateTime.parse(DataVintage.checkedOn);
    expect(stated.isBefore(newest), isFalse,
        reason: 'DataVintage.checkedOn(${DataVintage.checkedOn})이 '
            '카탈로그 최신 확인일(${newest.toIso8601String().split('T').first})보다 이르다 — '
            '대조를 하고 상수를 안 올렸다');
  });

  test('사용자에게 보이는 문장이 읽을 만하다', () {
    // 업데이트 카드에 그대로 나가는 문구라 형식이 깨지면 바로 보인다.
    expect(DataVintage.label, matches(RegExp(r'^\d{4}년 \d{1,2}월$')));
  });
}
