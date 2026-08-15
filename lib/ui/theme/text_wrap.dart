/// 한글 줄바꿈이 단어를 끊지 않게 한다.
///
/// Flutter는 UAX #14 기본 규칙을 쓰는데, 한글은 음절 사이 어디서나 줄을 바꿀 수 있다.
/// 그래서 좁은 화면에서 "2,000만원까 / 지"처럼 낱말이 잘린다. CSS의 `word-break: keep-all`에
/// 해당하는 설정이 Flutter에는 없다.
///
/// 어절 안의 글자 사이에 **U+2060 WORD JOINER**(폭 0, 보이지 않음)를 끼워 넣으면
/// 그 자리에서는 줄이 바뀌지 않는다. 결과적으로 띄어쓰기에서만 줄이 바뀐다.
/// 폭 0의 줄바꿈 **허용** 지점. 여기서는 끊어도 된다.
const String _zwsp = '​';

/// 보이는 공백이지만 줄이 안 바뀐다.
const String _nbsp = ' ';

/// 괄호를 한 덩이로 묶는다.
///
/// `폐지됐어요(한도 900만).`은 공백 기준으로 `폐지됐어요(한도` / `900만).` 두
/// 토큰이라, 하필 괄호 **안**에서 줄이 바뀌어 `(한도` 만 앞줄에 남는다.
///
/// 규칙 둘이면 끝난다.
///   • 괄호 안의 공백은 안 끊기는 공백으로 — 괄호가 쪼개지지 않는다.
///   • 여는 괄호 **앞**에는 끊어도 되는 자리를 넣는다 — 통째로 다음 줄로 간다.
String _bindParens(String s) {
  final b = StringBuffer();
  var depth = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '(' || c == '[') {
      // 앞 글자가 공백이 아니면 여기서 끊을 수 있게 표시한다.
      if (i > 0 && s[i - 1].trim().isNotEmpty) b.write(_zwsp);
      depth++;
      b.write(c);
    } else if (c == ')' || c == ']') {
      if (depth > 0) depth--;
      b.write(c);
    } else if (c == ' ' && depth > 0) {
      b.write(_nbsp);
    } else {
      b.write(c);
    }
  }
  return b.toString();
}

extension KeepWords on String {
  /// 어절 안에서는 줄이 바뀌지 않게 한 문자열.
  ///
  /// 화면 폭보다 긴 어절을 붙여 두면 잘리지 못해 넘쳐흐르므로,
  /// 14자를 넘는 어절은 손대지 않는다(끊기더라도 넘치는 것보다 낫다).
  String get keepWords {
    const maxToken = 14;
    if (isEmpty) return this;
    final src = _bindParens(this);
    const joiner = '⁠';
    // 줄바꿈(\n)과 공백은 그대로 둔다 — 거기서 줄이 바뀌어야 하니까.
    return src.splitMapJoin(
      RegExp(r'[^\s]+'),
      onMatch: (m) {
        final w = m[0]!;
        // **코드 유닛이 아니라 코드 포인트(runes)로 쪼갠다.** 이모지 같은 BMP 밖 글자는
        // UTF-16에서 2코드 유닛(서로게이트 쌍)이라, `split('')`로 나누면 쌍이 갈라져
        // 잘못된 UTF-16 문자열이 된다 — 그리는 순간 렌더링이 예외로 죽는다.
        final runes = w.runes.toList();
        if (runes.length <= 1 || runes.length > maxToken) return w;
        // 조이너를 넣되 **끊어도 되는 자리(_zwsp) 양옆은 건드리지 않는다** —
        // 거기까지 붙여 버리면 괄호 앞에 열어 둔 줄바꿈 자리가 도로 막힌다.
        final b = StringBuffer();
        for (var i = 0; i < runes.length; i++) {
          final cur = String.fromCharCode(runes[i]);
          if (i > 0) {
            final prev = String.fromCharCode(runes[i - 1]);
            if (prev != _zwsp && cur != _zwsp) b.write(joiner);
          }
          b.write(cur);
        }
        return b.toString();
      },
      onNonMatch: (s) => s,
    );
  }
}
