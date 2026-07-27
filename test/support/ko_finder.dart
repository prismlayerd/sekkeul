import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 화면에 그려진 한글에는 줄바꿈 보호용 워드조이너(U+2060)가 섞여 있을 수 있다
/// (`text_wrap.dart`의 `keepWords` — 좁은 화면에서 낱말이 잘리지 않게).
///
/// 그래서 `find.textContaining('월세로 살아요')`는 그 위젯을 못 찾는다. 그렇다고
/// 찾는 쪽에만 워드조이너를 넣으면, 이번엔 `keepWords`를 안 쓴 위젯을 못 찾는다.
/// **양쪽 다 조이너를 지우고 비교**해야 어느 쪽이든 걸린다.
const String _joiner = '⁠';

String _strip(String s) => s.replaceAll(_joiner, '');

/// Text만 본다. Text는 내부에 RichText를 하나 더 만들기 때문에, 둘 다 세면
/// 같은 문구가 늘 2건으로 잡혀 `findsOneWidget`이 통과할 수 없다.
String? _textOf(Widget w) {
  if (w is Text) return w.data ?? w.textSpan?.toPlainText();
  return null;
}

/// 부분 일치 — 워드조이너는 무시한다.
Finder findKo(String text) {
  final needle = _strip(text);
  return find.byWidgetPredicate(
    (w) {
      final s = _textOf(w);
      return s != null && _strip(s).contains(needle);
    },
    description: '텍스트에 "$needle"을 포함하는 위젯',
  );
}

/// 정확히 일치 — 워드조이너는 무시한다.
Finder findKoExact(String text) {
  final needle = _strip(text);
  return find.byWidgetPredicate(
    (w) {
      final s = _textOf(w);
      return s != null && _strip(s) == needle;
    },
    description: '텍스트가 "$needle"인 위젯',
  );
}
