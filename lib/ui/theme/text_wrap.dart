/// 한글 줄바꿈이 단어를 끊지 않게 한다.
///
/// Flutter는 UAX #14 기본 규칙을 쓰는데, 한글은 음절 사이 어디서나 줄을 바꿀 수 있다.
/// 그래서 좁은 화면에서 "2,000만원까 / 지"처럼 낱말이 잘린다. CSS의 `word-break: keep-all`에
/// 해당하는 설정이 Flutter에는 없다.
///
/// 어절 안의 글자 사이에 **U+2060 WORD JOINER**(폭 0, 보이지 않음)를 끼워 넣으면
/// 그 자리에서는 줄이 바뀌지 않는다. 결과적으로 띄어쓰기에서만 줄이 바뀐다.
extension KeepWords on String {
  /// 어절 안에서는 줄이 바뀌지 않게 한 문자열.
  ///
  /// 화면 폭보다 긴 어절을 붙여 두면 잘리지 못해 넘쳐흐르므로,
  /// 14자를 넘는 어절은 손대지 않는다(끊기더라도 넘치는 것보다 낫다).
  String get keepWords {
    const maxToken = 14;
    if (isEmpty) return this;
    const joiner = '⁠';
    // 줄바꿈(\n)과 공백은 그대로 둔다 — 거기서 줄이 바뀌어야 하니까.
    return splitMapJoin(
      RegExp(r'[^\s]+'),
      onMatch: (m) {
        final w = m[0]!;
        // **코드 유닛이 아니라 코드 포인트(runes)로 쪼갠다.** 이모지 같은 BMP 밖 글자는
        // UTF-16에서 2코드 유닛(서로게이트 쌍)이라, `split('')`로 나누면 쌍이 갈라져
        // 잘못된 UTF-16 문자열이 된다 — 그리는 순간 렌더링이 예외로 죽는다.
        final runes = w.runes.toList();
        if (runes.length <= 1 || runes.length > maxToken) return w;
        return runes.map(String.fromCharCode).join(joiner);
      },
      onNonMatch: (s) => s,
    );
  }
}
