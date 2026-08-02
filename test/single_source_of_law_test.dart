import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/tax_rates.dart';
import 'package:secul/ui/screens/out_of_pocket_cap_screen.dart';

/// **법정 상수는 엔진 한 곳에만 둔다.**
///
/// 지금까지 나온 오류 12건 중 4건이 같은 병이었다 — 세율·요율·한도가 화면마다
/// 복사돼 있어서, 개정이 오면 한 곳만 고치고 나머지는 조용히 낡는다.
///
/// - 양도소득세 세율표가 2022년 이전 값 (4,600만 경계 → 46.8만원 과대)
/// - 홈 N잡러 배너 한계세율이 2022년 이전 값 ("2024년 기준"이라 주석까지 달려 있었다)
/// - 4대보험 요율이 두 벌 (한쪽에만 건보료 상·하한이 빠져 있었다)
/// - 최저임금이 세 화면에 각각
///
/// 값이 틀렸는지는 조문 대조가 잡는다. 이 파일은 **값이 두 곳에 있는 것 자체**를
/// 막는다 — 복사본은 지금 맞아도 다음 개정에 반드시 틀어진다.
void main() {
  late List<({String path, String source})> screens;

  setUpAll(() {
    screens = [
      for (final f in Directory('lib/ui/screens').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          (path: f.path.replaceAll(r'\', '/'), source: f.readAsStringSync()),
    ];
  });

  /// 소득세법 §55① 세율 구간 경계 — 현행·구버전 양쪽 다 화면에 있으면 안 된다.
  /// (구버전이면 낡은 것이고, 현행이어도 복사본이라 다음 개정에 낡는다.)
  test('화면이 종합소득세율 구간표를 복사해 두지 않았다', () {
    // 두 개 이상 함께 나타나야 "표를 복사했다"고 본다 — 단일 숫자는 다른 뜻일 수 있다.
    const currentEdges = ['14000000', '50000000', '88000000', '150000000'];
    const legacyEdges = ['12000000', '46000000'];

    final offenders = <String>[];
    for (final s in screens) {
      // 양도세·상속증여세처럼 **다른 법의** 세율표를 가진 화면은 대상이 아니다.
      // 여기서 보는 건 §55① 구간을 그대로 옮겨 적은 경우다.
      final hitsCurrent = currentEdges.where((e) => s.source.contains(e)).length;
      final hitsLegacy = legacyEdges.where((e) => s.source.contains(e)).length;
      if (hitsCurrent >= 3) {
        offenders.add('${s.path} — 현행 구간표 복사본 (TaxRates.incomeTaxBrackets를 쓸 것)');
      } else if (hitsLegacy >= 2) {
        offenders.add('${s.path} — **2022년 이전** 구간표가 남아 있다');
      }
    }
    for (final o in offenders) {
      // ignore: avoid_print
      print('  ✕ $o');
    }
    expect(offenders, isEmpty,
        reason: '세율 구간은 TaxRates.incomeTaxBrackets 하나만 본다');
  });

  /// 4대보험 요율·최저임금처럼 **매년 바뀌는 값**은 화면에 직접 적으면 안 된다.
  test('매년 바뀌는 요율·최저임금이 화면에 직접 박혀 있지 않다', () {
    final watched = <String, String>{
      '0.0475': '국민연금 본인부담 요율 → InsuranceEngine',
      '0.03595': '건강보험 본인부담 요율 → InsuranceEngine',
      '0.009448': '장기요양보험료율 → InsuranceEngine',
      '0.0719': '건강보험료율 → InsuranceEngine',
      '6590000': '국민연금 기준소득월액 상한 → TaxRates',
      '10320': '최저임금 → TaxRates.minimumHourlyWage2026',
      '10030': '최저임금(2025) → TaxRates.minimumHourlyWage2025',
    };
    final offenders = <String>[];
    for (final s in screens) {
      for (final e in watched.entries) {
        if (RegExp(r'(?<![\d.])' + RegExp.escape(e.key) + r'(?![\d])')
            .hasMatch(s.source)) {
          offenders.add('${s.path}: ${e.key} — ${e.value}');
        }
      }
    }
    for (final o in offenders) {
      // ignore: avoid_print
      print('  ✕ $o');
    }
    expect(offenders, isEmpty,
        reason: '매년 바뀌는 값을 화면에 적으면 갱신 때 한 곳을 빠뜨린다');
  });

  /// 파생 상수를 리터럴로 바꿔 놓는 것도 같은 병이다.
  ///
  /// `unemploymentDailyFloor`를 `66048.0`으로 적어도 **오늘은 두 값이 같아서**
  /// 어떤 값 검사도 안 깨진다. 최저임금이 바뀌는 내년에야 어긋난다 —
  /// 실행 시점 검사로는 못 잡으므로 소스를 본다.
  test('파생으로 정의된 상수가 리터럴로 바뀌지 않았다', () {
    final src = File('lib/core/tax_engine/tax_rates.dart').readAsStringSync();
    // 고용보험법 §46② — 구직급여 하한은 최저임금일액(시급 × 8시간)의 80%다.
    final m = RegExp(r'unemploymentDailyFloor\s*=\s*([^;]+);').firstMatch(src);
    expect(m, isNotNull, reason: 'unemploymentDailyFloor 정의를 못 찾았다');
    final rhs = m!.group(1)!.trim();
    // ignore: avoid_print
    print('  unemploymentDailyFloor = ' + rhs);
    expect(rhs.contains('minimumHourlyWage'), isTrue,
        reason: '구직급여 하한이 최저임금에서 파생되지 않고 리터럴로 박혀 있다 — '
            '오늘은 값이 같아도 최저임금이 바뀌면 어긋난다');
  });

  /// 혜택 탭 설명문이 계산기 화면의 표를 베껴 적는 것도 같은 병이다.
  ///
  /// 본인부담상한액 7개 구간이 두 벌 있었다. 계산기만 2025년 값으로 고치고
  /// 혜택 탭은 2024년 값인 채 "2025년 기준"이라 써 붙어 있었다 —
  /// 같은 앱의 두 화면이 사용자에게 다른 금액을 말했다.
  test('혜택 설명이 계산기 상수를 리터럴로 베끼지 않았다', () {
    final benefit = File('lib/ui/screens/benefit_screen.dart').readAsStringSync();
    // 설명문을 상수에서 만들어 쓰는 한 두 값이 어긋날 길이 없다.
    // 금액 리터럴을 세는 방식은 안 쓴다 — 월세 공제 170만원처럼 무관한 제도의
    // 금액이 우연히 겹쳐서 엉뚱한 곳을 가리킨다.
    expect(benefit.contains('outOfPocketCapTiers'), isTrue,
        reason: '본인부담상한 표를 상수에서 만들지 않고 설명문에 다시 적었다 — '
            '두 벌이 되면 한쪽만 갱신되고 사용자는 화면마다 다른 금액을 본다');

    // 옛 복사본으로 되돌아가는 것도 막는다(2024년 값).
    for (final stale in ['162만원', '303만원', '414만원', '497만원', '808만원']) {
      expect(benefit.contains(stale), isFalse,
          reason: '$stale — 2024년 본인부담상한액이 설명문에 되살아났다');
    }
  });

  test('엔진의 한계세율 함수가 구간표와 일치한다', () {
    // 화면이 쓰는 안내용 한계세율이 실제 세율표에서 파생되는지.
    expect(TaxRates.marginalRatePercent(13999999), 6);
    expect(TaxRates.marginalRatePercent(14000000), 6);
    expect(TaxRates.marginalRatePercent(14000001), 15);
    expect(TaxRates.marginalRatePercent(50000000), 15);
    expect(TaxRates.marginalRatePercent(50000001), 24);
    // 2022년 이전 표였다면 4,700만은 24%로 나온다.
    expect(TaxRates.marginalRatePercent(47000000), 15,
        reason: '4,600만~5,000만 구간 — 옛 표를 쓰면 여기서 갈린다');
    expect(TaxRates.marginalRatePercent(2000000000), 45);
  });
}
