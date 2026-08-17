import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/tax_tips.dart';

/// **모든 팁은 언젠가 보여야 한다.**
///
/// 예전에는 점수만 매겨 위에서 둘을 잘랐다. 그래서 직장인은 열두 달 내내
/// 「2026 혜택」 같은 두 장만 봤고, 아홉 개 중 넷은 아무에게도 안 떴다.
/// 라벨이 고정된 것처럼 보인다는 말이 나온 게 이것 때문이다.
void main() {
  const types = ['직장인', 'N잡러', '프리랜서'];

  /// 이 유형이 1년 동안 실제로 보게 되는 팁.
  Set<String> shown(String type) => {
        for (var m = 1; m <= 12; m++)
          for (final t in taxTipsFor(type, m)) t.title,
      };

  test('상시 팁은 1년 안에 모두 한 번은 뜬다', () {
    for (final type in types) {
      final expected = allTaxTips
          .where((t) =>
              t.months.isEmpty && (t.types.isEmpty || t.types.contains(type)))
          .map((t) => t.title)
          .toSet();
      final missing = expected.difference(shown(type));
      expect(missing, isEmpty,
          reason: '$type에게 영영 안 뜨는 팁이 있다: ${missing.join(', ')}');
    }
  });

  test('한 유형이 같은 두 장만 보지 않는다', () {
    for (final type in types) {
      // 상시 팁이 셋 이상인 유형이면 달마다 짝이 바뀌어야 한다.
      final pool = allTaxTips
          .where((t) =>
              t.months.isEmpty && (t.types.isEmpty || t.types.contains(type)))
          .length;
      if (pool < 3) continue;
      expect(shown(type).length, greaterThan(2),
          reason: '$type은 1년 내내 같은 두 장만 본다');
    }
  });

  test('그 유형 것이 아닌 팁은 안 뜬다', () {
    for (final type in types) {
      for (var m = 1; m <= 12; m++) {
        for (final t in taxTipsFor(type, m)) {
          expect(t.types.isEmpty || t.types.contains(type), isTrue,
              reason: '$type $m월에 남의 유형 팁이 떴다: ${t.title} (${t.types})');
        }
      }
    }
  });

  test('다른 달 일정 팁이 새어 나오지 않는다', () {
    for (final type in types) {
      for (var m = 1; m <= 12; m++) {
        for (final t in taxTipsFor(type, m)) {
          expect(t.months.isEmpty || t.months.contains(m), isTrue,
              reason: '$m월에 ${t.months} 전용 팁이 떴다: ${t.title}');
        }
      }
    }
  });
}
