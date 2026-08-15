import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/theme/text_wrap.dart';

/// **괄호는 통째로 움직인다.**
///
/// `폐지됐어요(한도 900만).`은 공백 기준으로 두 토큰이라, 하필 괄호 **안**에서
/// 줄이 바뀌어 `(한도`만 앞줄에 남았다. 눈으로만 고치면 다음에 또 돌아온다.
void main() {
  const zwsp = '\u200B'; // 끊어도 되는 자리
  const nbsp = '\u00A0'; // 안 끊기는 공백
  const wj = '\u2060';   // 낱말 안을 붙이는 조이너

  test('여는 괄호 앞에서는 끊을 수 있고, 괄호 안에서는 못 끊는다', () {
    final out = '자녀 대학 교육비, 소득요건이 폐지됐어요(한도 900만).'.keepWords;
    expect(out.contains('$zwsp('), isTrue, reason: '괄호가 통째로 다음 줄로 못 간다');
    expect(out.contains(nbsp), isTrue, reason: '괄호 안 공백에서 줄이 바뀐다');
  });

  test('끊을 자리 옆에 조이너를 붙이지 않는다', () {
    // 붙이면 열어 둔 줄바꿈 자리가 도로 막혀 아무 효과가 없다.
    final out = '한도(900만) 적용'.keepWords;
    expect(out.contains('$wj$zwsp'), isFalse);
    expect(out.contains('$zwsp$wj'), isFalse);
  });

  test('괄호가 없으면 하던 대로 — 어절 안만 붙인다', () {
    final out = '월세 세액공제'.keepWords;
    expect(out.contains(zwsp), isFalse);
    expect(out.contains(nbsp), isFalse);
    expect(out.contains('월${wj}세'), isTrue);
  });
}
