/// 계산이 위젯 State 안에 있는 화면을 **실제로 세워 놓고 그려진 숫자를 읽는** 검사에
/// 공통으로 쓰는 도구. 값 대조 테스트 10개가 이 셋을 각자 베껴 쓰고 있었다.
///
/// 조문 검산식(refLaborDeduction 등)은 여기 두지 않는다 —
/// 그건 tax_law_reference.dart의 몫이고, 이 파일은 **화면을 만지는 법**만 안다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:secul/core/data/db_helper.dart';

final NumberFormat _thousands = NumberFormat('#,###');

/// 화면이 그리는 천단위 표기와 같은 모양으로 기대값을 만든다.
String comma(num v) => _thousands.format(v.round());

/// 위젯 트리의 모든 `Text`에서 [re]에 걸리는 토큰을 긁는다.
///
/// [re]를 인자로 받는 이유: 화면마다 쓰는 단위가 다르고(원·만원·회·시간),
/// 넓은 정규식으로 통일하면 `isNot(contains(...))` 검사가 무뎌진다.
/// 각 테스트가 자기 화면의 표기만 넘긴다.
Set<String> screenTokens(WidgetTester t, RegExp re) {
  final out = <String>{};
  for (final w in t.allWidgets) {
    if (w is Text) {
      final s = w.data ?? w.textSpan?.toPlainText();
      if (s == null) continue;
      for (final m in re.allMatches(s)) {
        out.add(m.group(0)!);
      }
    }
  }
  return out;
}

/// 기대값이 화면에 없으면 실패한다.
/// 실패 메시지에 화면이 실제로 그린 값을 전부 실어 보낸다 — 무엇이 틀렸는지
/// 다시 돌려보지 않고 알 수 있어야 한다.
void expectScreenToken(WidgetTester t, RegExp re, String want, String what) {
  final shown = screenTokens(t, re);
  expect(shown, contains(want),
      reason: '$what — 화면 값이 조문 검산과 다르다 (기대 $want)\n'
          '  화면: ${(shown.toList()..sort()).join(' / ')}');
}

int _seq = 0;

/// 화면 하나를 빈 DB 위에 세우고 [inputs]의 `(칸 번호, 값)`을 순서대로 넣는다.
///
/// 루트 키를 매번 바꿔 State 재사용을 막는다. 세로를 길게 잡는 건 계산 결과가
/// 스크롤 아래에 있어도 트리에 올라오게 하려는 것이다.
Future<void> openScreen(
  WidgetTester t,
  Widget screen, {
  List<(int, String)> inputs = const [],
  double height = 4000,
  int stepMs = 250,
}) async {
  t.view.physicalSize = Size(390, height);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  dbService = InMemoryDatabaseHelper();
  await dbService.initDatabase();
  await t.pumpWidget(MaterialApp(key: ValueKey('probe-${_seq++}'), home: screen));
  await t.pump(const Duration(milliseconds: 300));
  for (final (idx, text) in inputs) {
    await t.enterText(find.byType(TextField).at(idx), text);
    await t.pump(Duration(milliseconds: stepMs));
  }
  await t.pump(const Duration(milliseconds: 400));
  t.takeException();
}
