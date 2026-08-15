import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/tax_tips.dart';

/// **배너 본문은 한 줄이거나, 문장 경계에서 두 줄로 떨어져야 한다.**
///
/// 고정폭이라 한 줄에 들어가는 칸 수가 정해져 있고(한글 1칸, 숫자·영문 0.5칸),
/// 그리는 쪽은 폭이 차면 그냥 끊는다. 그래서 문구를 조금만 늘려도
/// `…대상이 / 넓어졌어요.`처럼 문장 중간에서 갈라진다. 눈으로 잡으면 다음
/// 문구를 고칠 때 또 놓치므로, 줄나눔을 여기서 흉내 내 규칙을 박아 둔다.
void main() {
  // 홈 배너 본문이 쓸 수 있는 폭. 390px 기기에서 실측한 값이다.
  const cap = 27.0;

  double width(String s) =>
      s.runes.fold(0.0, (w, r) => w + (r < 128 ? 0.5 : 1.0));

  /// 끊을 수 있는 덩이. 괄호는 통째로 움직인다(text_wrap.dart와 같은 규칙).
  List<String> chunks(String t) {
    final out = <String>[];
    var buf = StringBuffer();
    var depth = 0;
    for (final ch in t.split('')) {
      if (ch == '(') {
        if (buf.toString().trim().isNotEmpty) out.add(buf.toString());
        buf = StringBuffer();
        depth++;
        buf.write(ch);
      } else if (ch == ')') {
        if (depth > 0) depth--;
        buf.write(ch);
      } else if (ch == ' ' && depth == 0) {
        if (buf.isNotEmpty) out.add(buf.toString());
        buf = StringBuffer();
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  List<String> wrap(String t) {
    final lines = <String>[];
    var cur = '';
    for (final c in chunks(t)) {
      final trial = cur.isEmpty
          ? c
          : (c.startsWith('(') ? '$cur$c' : '$cur $c');
      if (width(trial) <= cap) {
        cur = trial;
      } else {
        if (cur.isNotEmpty) lines.add(cur);
        cur = c;
      }
    }
    if (cur.isNotEmpty) lines.add(cur);
    return lines;
  }

  test('모든 팁 본문이 한 줄이거나 문장 경계에서 갈라진다', () {
    final bad = <String>[];
    for (final t in allTaxTips) {
      final lines = wrap(t.body);
      if (lines.length == 1) continue;
      if (lines.length > 2) {
        bad.add('3줄 — ${t.body}');
        continue;
      }
      // 첫 줄이 문장부호로 끝나야 읽는 사람이 거기서 쉰다.
      final head = lines.first.trimRight();
      if (!(head.endsWith('.') || head.endsWith(',') || head.endsWith(')'))) {
        bad.add('문장 중간에서 갈라짐 — ${lines.first} / ${lines.last}');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
