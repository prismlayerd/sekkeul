import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/theme/text_wrap.dart';

/// 좁은 폭에서 한글이 어디서 줄바꿈되는지 실제로 재본다.
/// TextPainter가 Flutter 본체와 같은 줄바꿈 규칙을 쓰므로 화면과 같은 결과가 나온다.
void main() {
  List<String> lines(String s, double width) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    final boxes = tp.computeLineMetrics();
    final out = <String>[];
    int start = 0;
    for (final m in boxes) {
      final end = tp
          .getPositionForOffset(Offset(width, m.baseline))
          .offset;
      out.add(s.substring(start, end.clamp(start, s.length)));
      start = end;
    }
    return out;
  }

  const raw = '15년 이상 고정금리면 최대 2,000만원까지 과세표준에서 빼요';

  test('손대지 않으면 어절 중간에서 끊긴다', () {
    final ls = lines(raw, 150);
    expect(ls.length, greaterThan(1), reason: '좁은 폭이라 여러 줄이어야 한다');
    // 어느 줄이든 공백이 아닌 자리에서 끝나면 어절이 잘린 것
    final brokeMidWord = ls
        .take(ls.length - 1)
        .any((l) => l.isNotEmpty && !l.endsWith(' ') && !l.endsWith('\n'));
    expect(brokeMidWord, isTrue, reason: '기본 규칙은 한글 음절 사이를 끊는다');
  });

  test('keepWords를 쓰면 띄어쓰기에서만 끊긴다', () {
    final ls = lines(raw.keepWords, 150);
    expect(ls.length, greaterThan(1));
    for (final l in ls.take(ls.length - 1)) {
      // 줄 끝이 공백이거나, 줄에 담긴 마지막 어절이 온전해야 한다
      expect(l.trimRight().endsWith('⁠'), isFalse,
          reason: '워드조이너 자리에서 끊기면 안 된다');
    }
    // 잘린 조각("까"로 끝나는 줄)이 없어야 한다
    expect(ls.any((l) => l.replaceAll('⁠', '').trimRight().endsWith('까')), isFalse);
  });

  test('화면보다 긴 어절은 손대지 않는다 — 넘치는 것보다 끊기는 게 낫다', () {
    const long = '개인정보처리방침및이용약관동의안내문구';
    expect(long.keepWords, long);
  });

  test('띄어쓰기와 줄바꿈은 그대로 둔다', () {
    const s = '가나 다라\n마바';
    final k = s.keepWords;
    expect(k.replaceAll('⁠', ''), s);
    expect(k.contains('\n'), isTrue);
  });
}
