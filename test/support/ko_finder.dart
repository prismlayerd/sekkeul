import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/theme/text_wrap.dart';

/// 화면에 그려진 한글에는 줄바꿈 보호용 워드조이너(U+2060)가 섞여 있다
/// (`text_wrap.dart`의 `keepWords` — 좁은 화면에서 낱말이 잘리지 않게).
///
/// 그래서 `find.textContaining('월세로 살아요')`는 매칭되지 않는다. 찾는 쪽에도
/// 같은 처리를 해 줘야 한다. 이 함수를 쓰면 그 사정을 매번 떠올리지 않아도 된다.
Finder findKo(String text) => find.textContaining(text.keepWords);

/// 정확히 일치하는 텍스트 찾기(워드조이너 포함).
Finder findKoExact(String text) => find.text(text.keepWords);
