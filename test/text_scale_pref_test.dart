import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/text_scale_pref.dart';

/// **글자를 키워도 상한을 넘지 않는다.**
///
/// 기기 설정과 앱 설정이 곱해지기 때문에, 둘 다 크게 잡은 사람은 검증한 적 없는
/// 배율로 앱을 보게 된다. 그 자리에서 글자가 잘리면 눈이 불편한 사람이 앱을
/// 아예 못 쓴다. 곱셈 결과가 늘 [maxTextScale] 안에 있는지만 붙잡으면 된다.
void main() {
  test('기존 크기가 제일 작은 단계다', () {
    // 쓰던 사람의 화면이 업데이트만으로 저절로 바뀌면 안 된다.
    expect(textScaleSteps.first, 1.0);
    expect(textScaleFromDb(null), 1.0, reason: '설정한 적 없으면 기존 크기');
  });

  test('단계는 커지기만 한다', () {
    for (var i = 1; i < textScaleSteps.length; i++) {
      expect(textScaleSteps[i], greaterThan(textScaleSteps[i - 1]));
    }
    expect(textScaleSteps.last, lessThanOrEqualTo(maxTextScale),
        reason: '고를 수 있는데 상한에 걸려 안 커지는 단계는 고장 난 설정이다');
  });

  test('기기 설정과 곱해도 상한을 안 넘는다', () {
    for (final system in [1.0, 1.15, 1.3, 1.5, 2.0]) {
      for (final step in textScaleSteps) {
        final v = effectiveTextScale(system, step);
        expect(v, lessThanOrEqualTo(maxTextScale),
            reason: '기기 $system × 앱 $step = $v — 검증 안 된 배율이다');
        expect(v, greaterThanOrEqualTo(1.0));
      }
    }
  });

  test('기기가 기본값이면 고른 단계가 그대로 적용된다', () {
    for (final step in textScaleSteps) {
      expect(effectiveTextScale(1.0, step), step,
          reason: '고른 값이 안 먹으면 설정이 있으나 마나다');
    }
  });

  test('저장했다 불러오면 같은 값이다', () {
    for (final step in textScaleSteps) {
      expect(textScaleFromDb(textScaleToDb(step)), step);
    }
  });

  test('모르는 값이 저장돼 있으면 기존 크기로 돌아온다', () {
    // 나중에 단계를 바꿨을 때 옛 값이 그대로 살아나면 안 된다.
    for (final junk in ['1.7', 'big', '', '0']) {
      expect(textScaleFromDb(junk), textScaleSteps.first, reason: junk);
    }
  });

  test('단계마다 이름이 있다', () {
    final names = textScaleSteps.map(textScaleLabel).toSet();
    expect(names.length, textScaleSteps.length, reason: '이름이 겹치면 무엇을 고른지 모른다');
  });
}
