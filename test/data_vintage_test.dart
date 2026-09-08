import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data_vintage.dart';

/// **앱이 말하는 "기준 시점"이 카탈로그의 가장 낡은 항목과 같은지 본다.**
///
/// 계산기 하단과 업데이트 카드가 `DataVintage.checkedOn`을 그대로 보여준다.
/// 양쪽으로 다 틀릴 수 있다 — 일부만 대조하고 올리면 안 본 항목까지 그날
/// 확인한 척이 되고, 전수 대조를 하고 안 올리면 실제보다 낡았다고 말한다.
/// 앞쪽이 더 위험하다. 사용자가 낡은 값을 최신으로 믿는다.
void main() {
  test('기준 시점이 카탈로그의 가장 오래된 확인일과 같다', () {
    final src =
        File('lib/ui/screens/benefit_screen.dart').readAsStringSync();
    final dates = [
      for (final m in RegExp(r"on:\s*'(\d{4}-\d{2}-\d{2})'").allMatches(src))
        DateTime.parse(m.group(1)!),
    ];
    expect(dates, isNotEmpty, reason: 'verified 기록을 못 찾았다 — 파싱이 깨졌는지 볼 것');

    // **가장 오래된 확인일**과 맞아야 한다. 최신과 맞추면 일부만 다시 보고도
    // 상수가 올라가서, 앱이 안 본 항목까지 그날 확인한 것처럼 말하게 된다.
    // 반대로 오래된 쪽보다 이르면 실제보다 낡았다고 말하는 것이라 이것도 틀리다.
    final oldest = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final stated = DateTime.parse(DataVintage.checkedOn);
    expect(stated, oldest,
        reason: 'DataVintage.checkedOn(${DataVintage.checkedOn})이 '
            '카탈로그의 가장 오래된 확인일'
            '(${oldest.toIso8601String().split('T').first})과 다르다 — '
            '전수 대조를 끝낸 날에만 올린다');
  });

  test('사용자에게 보이는 문장이 읽을 만하다', () {
    // 업데이트 카드에 그대로 나가는 문구라 형식이 깨지면 바로 보인다.
    expect(DataVintage.label, matches(RegExp(r'^\d{4}년 \d{1,2}월$')));
  });
}
