import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **혜택 설명문과 계산기가 같은 금액을 말하는지 본다.**
///
/// 원문 대조로는 이 병을 못 잡는다. 두 화면이 서로 다른 말을 해도 각각 따로
/// 보면 둘 다 그럴듯한 숫자라서, "앱 값 vs 원문"만 보면 통과한다.
///
/// 실제로 세 번 벌어졌다 —
/// - 본인부담상한: 계산기만 2025년 값으로 고치고 설명문은 2024년인 채 뒀다
/// - 여권 수수료·보육료·에너지바우처: 설명문만 고치고 계산기를 안 봤다
///
/// 표를 한 곳에 두는 게 근본 해결이고 본인부담상한은 그렇게 했다
/// (`outOfPocketCapTiers`). 나머지는 계산기가 표를 갖고 설명문이 문장으로
/// 풀어 쓰는 형태라, 두 파일의 숫자가 같은지만 확인한다.
void main() {
  String read(String name) =>
      File('lib/ui/screens/$name.dart').readAsStringSync();

  /// 소스에서 `숫자` 리터럴을 뽑는다(자릿수 구분 쉼표 없음).
  Set<int> ints(String src) => {
        for (final m in RegExp(r'(?<![\w.])(\d{4,})(?![\w.])').allMatches(src))
          int.parse(m.group(1)!)
      };

  /// 설명문에서 `52,000원`과 `58.4만원`을 모두 원 단위로 뽑는다.
  /// 같은 금액이라도 표기 단위가 화면마다 달라서 한쪽만 보면 놓친다.
  Set<int> won(String src) => {
        for (final m in RegExp(r'([\d,]+(?:\.\d+)?)\s*(만원|원)').allMatches(src))
          (double.parse(m.group(1)!.replaceAll(',', '')) *
                  (m.group(2) == '만원' ? 10000 : 1))
              .round()
      };

  late String benefit;
  setUpAll(() => benefit = read('benefit_screen'));

  void agree(String what, String calcFile, List<int> table) {
    final calc = ints(read(calcFile));
    final desc = won(benefit);
    final missingInCalc = table.where((v) => !calc.contains(v)).toList();
    final missingInDesc = table.where((v) => !desc.contains(v)).toList();
    expect(missingInCalc, isEmpty,
        reason: '$what — $missingInCalc 이 계산기($calcFile)에 없다. '
            '설명문만 고치고 계산기를 빠뜨렸는지 볼 것');
    expect(missingInDesc, isEmpty,
        reason: '$what — $missingInDesc 이 혜택 설명문에 없다. '
            '계산기만 고치고 설명문을 빠뜨렸는지 볼 것');
  }

  test('여권 수수료가 설명문과 계산기에서 같다', () {
    // 외교부 여권안내 수수료표. 성인 10년은 국제교류기여금 12,000원 포함.
    agree('여권 수수료', 'passport_fee_screen',
        [52000, 49000, 44000, 41000, 35000, 32000, 17000, 27000, 50000]);
  });

  test('보육료 지원단가가 설명문과 계산기에서 같다', () {
    // 2026년 기본보육 단가(아이사랑). 0~2세는 3~5% 인상됐다.
    agree('보육료', 'daycare_fee_screen', [584000, 515000, 426000, 280000]);
  });

  test('에너지바우처 지원액이 설명문과 계산기에서 같다', () {
    // 2026년부터 하·동절기 구분 없이 연간 총액 하나다(한국에너지공단).
    agree('에너지바우처', 'energy_voucher_screen',
        [295200, 407500, 532700, 701300]);
  });

  test('없어진 계절별 바우처 값이 되살아나지 않았다', () {
    // 2025년까지의 여름·겨울 분리 금액. 남아 있으면 옛 구조로 되돌린 것이다.
    for (final stale in [55700, 254500, 117000, 599300, 716300]) {
      expect(read('energy_voucher_screen').contains('$stale'), isFalse,
          reason: '$stale — 폐지된 계절별 바우처 금액이 계산기에 남아 있다');
    }
  });
}
