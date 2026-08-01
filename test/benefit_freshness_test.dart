import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **혜택 카탈로그의 금액이 언제 원문과 대조됐는지 추적한다.**
///
/// 혜택 탭은 제도 53개 · 금액 288개가 전부 손으로 적은 문자열이다. 세법과 달리
/// 이 값들은 조문에서 파생되지 않아 검산할 대상이 없고, 매년 고시로 조용히 바뀐다.
/// 표본 6개를 원문과 맞춰 봤더니 3개가 낡아 있었다 — 에너지바우처 4개 값 전부,
/// 아동수당 지역차등 누락, 장애인연금 선정기준액 2년 묵음.
///
/// 값이 맞는지는 사람이 원문을 봐야 안다. 이 파일이 하는 일은 **무엇이 언제
/// 확인됐는지 세는 것**이다. 확인 안 된 제도가 몇 개인지 모르는 상태가 제일 나쁘다.
void main() {
  const path = 'lib/ui/screens/benefit_screen.dart';

  /// 고시는 대개 연 단위로 바뀐다. 1년 넘은 확인은 확인이 아니다.
  const staleAfterDays = 365;

  late List<({String name, String? on, String? source})> entries;

  setUpAll(() {
    final src = File(path).readAsStringSync();
    // `_Benefit(` 로 시작하는 덩어리마다 name/verified를 집는다.
    final chunks = src.split('_Benefit(').skip(1);
    entries = [
      for (final c in chunks)
        if (RegExp(r"name:\s*'([^']*)'").firstMatch(c) case final n?)
          (
            name: n.group(1)!,
            on: RegExp(r"on:\s*'([\d-]+)'").firstMatch(c)?.group(1),
            source: RegExp(r"source:\s*'([^']*)'").firstMatch(c)?.group(1),
          ),
    ];
  });

  test('제도 목록을 읽어냈다', () {
    // 파싱이 깨지면 아래 검사가 전부 조용히 통과한다.
    expect(entries.length, greaterThan(40),
        reason: '_Benefit 파싱이 깨졌다 — 모델이 바뀌었는지 볼 것');
  });

  test('모든 제도에 원문 대조 기록이 있다', () {
    final missing = [
      for (final e in entries)
        if (e.on == null || e.source == null) e.name
    ];
    if (missing.isNotEmpty) {
      // ignore: avoid_print
      print('  ✕ 미확인 ${missing.length}/${entries.length}건: ${missing.join(' · ')}');
    }
    expect(missing, isEmpty,
        reason: '원문과 대조하고 verified: (source: ..., on: ...)를 붙일 것. '
            '확인 안 된 금액은 낡았는지조차 알 수 없다');
  });

  test('대조 기록이 1년 넘게 묵지 않았다', () {
    final today = DateTime.now();
    final stale = <String>[];
    for (final e in entries) {
      if (e.on == null) continue; // 위 검사가 따로 잡는다
      final on = DateTime.tryParse(e.on!);
      expect(on, isNotNull, reason: '${e.name}: on 날짜 형식이 YYYY-MM-DD가 아니다');
      final days = today.difference(on!).inDays;
      if (days > staleAfterDays) stale.add('${e.name} (${e.on}, $days일 전)');
    }
    for (final s in stale) {
      // ignore: avoid_print
      print('  ✕ 묵은 대조: $s');
    }
    expect(stale, isEmpty, reason: '원문을 다시 보고 on을 갱신할 것');
  });

  test('출처가 원문 주소다', () {
    // 블로그·요약 사이트는 근거가 못 된다. 실제로 한 번 당했다 —
    // 사설 계산기 사이트가 자기 페이지 안에서 서로 다른 값을 말하고 있었다.
    const allowed = [
      'go.kr', // 정부·공공기관
      'or.kr', // 공단·공사
      'law.go.kr',
    ];
    final bad = [
      for (final e in entries)
        if (e.source != null && !allowed.any((d) => Uri.parse(e.source!).host.endsWith(d)))
          '${e.name} → ${e.source}'
    ];
    for (final b in bad) {
      // ignore: avoid_print
      print('  ✕ 원문이 아닌 출처: $b');
    }
    expect(bad, isEmpty, reason: '정부·공공기관(go.kr/or.kr) 주소만 근거로 쓴다');
  });
}
