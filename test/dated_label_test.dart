import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/tax_engine/tax_year.dart';

/// **"N년 기준"이라고 써 놓은 문구가 낡지 않았는지 본다.**
///
/// 값 대조는 금액이 화면에 있는지만 확인하므로, 라벨이 잘못 붙어도 통과한다.
/// 실제로 두 번 당했다 —
/// - 홈 한계세율에 "2024년 기준" 주석이 붙어 있었지만 값은 2022년 이전 표였다
/// - 연말정산 "인적공제 (1인)"인데 금액은 본인 포함 2인분이었다
///
/// 여기서 보는 건 **연도 주장**이다. "2023년 고시 기준"이라 쓰여 있으면
/// 그 숫자는 3년 묵은 것이고, 사용자는 그걸 오늘 값으로 읽는다.
/// 값을 고치는 건 원문이 있어야 하므로, 이 파일은 고치지 않고 **기한을 건다**.
void main() {
  /// 화면 문구가 "이 숫자는 N년 것"이라고 주장하는 자리들.
  ///
  /// `reviewBy` = 이 연도까지는 그대로 둬도 된다. 기준 귀속연도가 그걸 넘기면
  /// 터진다 — 새 고시를 확인해서 값을 갱신하고 연도를 올리라는 뜻이다.
  const registry = <String, ({int reviewBy, String note})>{
    '2026년 기준': (
      reviewBy: 2026,
      note: '4대보험 요율·재산세·보금자리론·기초연금 등 — 현행. 귀속연도가 바뀌면 다시 본다.',
    ),
    '2025년 기준': (
      reviewBy: 2026,
      note: '본인부담상한액 — 2025년 고시가 최신. 2026년분은 통상 연말 고시.',
    ),
    '2026년 고시 기준': (
      reviewBy: 2026,
      note: '주거급여 기준임대료 — 국토부 고시 제2025-506호(2026년 적용). 마이홈 공시표로 확인.',
    ),
    '2024년 표준': (
      reviewBy: 2026,
      note: '어르신 임플란트 보험가 참고치. "참고치 기반 단순 추정"이라 명시.',
    ),
  };

  /// "N년 ... 기준" / "N년 표준" 꼴만 잡는다.
  /// "2024년부터 종료", "2021년 폐지" 같은 **과거 사실 서술**은 낡을 수 없으므로 대상이 아니다.
  final claim = RegExp(r'(\d{4}(?:~\d{4})?년\s*(?:고시\s*)?(?:기준|표준))');

  test('화면의 연도 주장이 전부 등록돼 있고, 아직 기한이 남았다', () {
    final found = <String, List<String>>{};
    for (final f in Directory('lib/ui').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      // 문자열 리터럴 안에 있는 것만 — 주석이나 식별자는 사용자가 안 본다.
      for (final lit in RegExp(r"'([^'\\]|\\.)*'").allMatches(f.readAsStringSync())) {
        for (final m in claim.allMatches(lit.group(0)!)) {
          found.putIfAbsent(m.group(1)!, () => []).add(rel);
        }
      }
    }

    final unregistered = found.keys.where((k) => !registry.containsKey(k)).toList();
    for (final k in unregistered) {
      // ignore: avoid_print
      print('  ✕ 미등록 연도 주장: "$k" — ${found[k]!.toSet().join(', ')}');
    }
    expect(unregistered, isEmpty,
        reason: '새 연도 주장이 생겼다. registry에 reviewBy를 정해 등록할 것 — '
            '등록 안 하면 아무도 갱신 시점을 모른다');

    final expired = <String>[];
    registry.forEach((k, v) {
      if (TaxYear.reference > v.reviewBy) {
        expired.add('"$k" (reviewBy ${v.reviewBy}) — ${v.note}');
      }
    });
    for (final e in expired) {
      // ignore: avoid_print
      print('  ✕ 기한 만료: $e');
    }
    expect(expired, isEmpty,
        reason: '기준 귀속연도가 ${TaxYear.reference}인데 문구는 더 옛날 값을 주장한다. '
            '원문을 확인해 값과 연도를 함께 올릴 것');
  });

  /// 등록해 놓고 화면에서 지워 버리면 registry가 유령이 된다.
  test('registry에 화면에 없는 항목이 남아 있지 않다', () {
    final source = [
      for (final f in Directory('lib/ui').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart')) f.readAsStringSync(),
    ].join();
    final dead = registry.keys.where((k) {
      // 공백이 줄바꿈으로 바뀌었을 수 있으니 느슨하게 본다.
      return !RegExp(k.replaceAll(' ', r'\s*')).hasMatch(source);
    }).toList();
    expect(dead, isEmpty, reason: '화면에서 사라진 문구가 registry에 남아 있다');
  });
}
