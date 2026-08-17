import 'package:flutter/material.dart';

/// 사용자가 고른 글자 크기 배율. 시작 시 DB(app_state 'text_scale')에서 로드되고,
/// 설정에서 바꾸면 갱신된다. (테마와 같은 전역 ValueNotifier 패턴)
///
/// **기기 설정만으로는 부족했다.** "글자가 작다"는 의견이 여럿 모였는데, 그중
/// 상당수는 안드로이드 글꼴 크기를 건드릴 줄 모르거나, 다른 앱까지 커지는 게
/// 싫어서 안 건드리는 사람들이다. 앱 안에서 이 앱만 키울 수 있어야 한다.
final ValueNotifier<double> textScaleNotifier = ValueNotifier(textScaleSteps.first);

/// 고를 수 있는 단계. **첫 값이 지금까지의 크기**다 — 즉 제일 작은 것이 기존이고,
/// 위로만 올라간다. 쓰던 사람의 화면이 저절로 바뀌지 않는다.
const List<double> textScaleSteps = [1.0, 1.15, 1.3];

/// 화면이 안 넘치는 게 확인된 상한.
///
/// 시스템 배율과 이 설정을 곱한 값이 여기를 넘지 않게 자른다. 1.5배로 올려 보니
/// 89개 화면 중 14곳이 넘쳤다(`overflow_at_max_text_scale_test`가 그 자리를 짚는다).
/// 그 열넷을 고치기 전에는 여기를 올리지 않는다 — 글자를 키워 쓰는 사람은 눈이
/// 불편한 사람이고, 그 사람 화면에서 글자가 잘리면 앱을 아예 못 쓴다.
///
/// **main.dart와 넘침 테스트가 이 상수 하나를 같이 본다.** 예전에는 양쪽에 1.3이
/// 따로 박혀 있어서, 한쪽만 올리면 검사 없이 올라갈 수 있었다.
const double maxTextScale = 1.3;

/// 시스템 배율과 앱 설정을 합친 실제 배율.
double effectiveTextScale(double system, double appStep) =>
    (system * appStep).clamp(1.0, maxTextScale);

/// DB 문자열 → 배율. 저장된 값이 없거나 모르는 값이면 기존 크기.
double textScaleFromDb(String? value) {
  final v = double.tryParse(value ?? '');
  if (v == null) return textScaleSteps.first;
  // 단계가 바뀌어도 저장된 옛 값이 그대로 살아나지 않게 한다.
  return textScaleSteps.contains(v) ? v : textScaleSteps.first;
}

String textScaleToDb(double v) => v.toString();

/// 설정 화면 표시 라벨.
String textScaleLabel(double v) {
  final i = textScaleSteps.indexOf(v);
  return switch (i) {
    0 => '보통',
    1 => '크게',
    2 => '아주 크게',
    _ => '보통',
  };
}
