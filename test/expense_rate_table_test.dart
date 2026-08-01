import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/occupation_data.dart';

/// 업종별 경비율 표 1,542종을 **국세청 고시 원문과 전수 대조**한다.
///
/// 지금까지 이 표는 "값이 맞는지 확인할 방법이 없는 것"으로 남아 있었다. 고시 원문
/// (`2025년 귀속 경비율 고시.hwpx`)을 옮긴 JSON을 `test/fixtures/`에 스냅샷으로 넣어
/// 매 실행마다 비교한다 — 외부 저장소가 없어도 돌아간다.
///
/// **매년 갱신 절차**: 국세청이 새 귀속연도 고시를 내면
/// `test/fixtures/expense_rate_notice_YYYY.json`을 새로 넣고 이 테스트의 상수를 바꾼다.
/// 그러면 `occupation_data.dart`에서 바뀐 값·추가된 업종·사라진 업종이 전부 여기서 터진다.
///
/// 고시 JSON 행 구조: [업종코드, 업종명, 단순경비율 기본율, 단순경비율 초과율, 기준경비율]
/// 초과율 칸은 비어 있을 수 있다(기본율만 있는 업종).
const _fixture = 'test/fixtures/expense_rate_notice_2025.json';
const _noticeYear = 2025; // 귀속연도

void main() {
  late List<({String code, String name, double base, double excess, double standard})> notice;

  setUpAll(() {
    final raw = jsonDecode(File(_fixture).readAsStringSync()) as Map<String, dynamic>;
    final rows = (raw['데이터'] as List).cast<List>();
    notice = [
      for (final r in rows)
        if (r.length >= 5 && RegExp(r'^\d{6}$').hasMatch('${r[0]}'))
          (
            code: '${r[0]}',
            name: '${r[1]}',
            base: double.parse('${r[2]}'),
            excess: '${r[3]}'.isEmpty ? 0.0 : double.parse('${r[3]}'),
            standard: double.parse('${r[4]}'),
          ),
    ];
  });

  test('고시 원문을 읽었다 — 행 수가 표와 맞는다', () {
    // ignore: avoid_print
    print('$_noticeYear년 귀속 고시 ${notice.length}행 / 앱 표 ${OccupationData.occupations.length}종');
    expect(notice.length, greaterThan(1500), reason: '고시 파싱이 깨졌다');
  });

  test('앱 표의 모든 업종이 고시에 있고 경비율 3종이 정확히 일치한다', () {
    final byCode = {for (final n in notice) n.code: n};
    final missing = <String>[];
    final mismatched = <String>[];

    for (final e in OccupationData.occupations.entries) {
      final n = byCode[e.key];
      if (n == null) {
        missing.add('${e.key} ${e.value.name}');
        continue;
      }
      final o = e.value;
      final diffs = <String>[];
      if (o.simpleBaseRate != n.base) {
        diffs.add('단순기본 앱 ${o.simpleBaseRate} ≠ 고시 ${n.base}');
      }
      if (o.simpleExcessRate != n.excess) {
        diffs.add('단순초과 앱 ${o.simpleExcessRate} ≠ 고시 ${n.excess}');
      }
      if (o.standardRate != n.standard) {
        diffs.add('기준 앱 ${o.standardRate} ≠ 고시 ${n.standard}');
      }
      if (diffs.isNotEmpty) mismatched.add('${e.key} ${o.name}: ${diffs.join(' · ')}');
    }

    // ignore: avoid_print
    print('고시에 없는 업종 ${missing.length}건 · 값이 다른 업종 ${mismatched.length}건');
    for (final m in [...missing.take(10), ...mismatched.take(20)]) {
      // ignore: avoid_print
      print('  · $m');
    }
    expect(missing, isEmpty, reason: '앱에는 있는데 고시에 없는 업종코드');
    expect(mismatched, isEmpty, reason: '고시와 경비율이 다른 업종');
  });

  test('고시에 있는데 앱 표에서 빠진 업종이 없다', () {
    final appCodes = OccupationData.occupations.keys.toSet();
    final dropped = [
      for (final n in notice)
        if (!appCodes.contains(n.code)) '${n.code} ${n.name}'
    ];
    // ignore: avoid_print
    print('앱 표에서 빠진 업종 ${dropped.length}건');
    for (final d in dropped.take(20)) {
      // ignore: avoid_print
      print('  · $d');
    }
    expect(dropped, isEmpty, reason: '고시에 있는 업종이 앱 표에 없다 — 그 업종 사용자는 계산 불가');
  });
}
