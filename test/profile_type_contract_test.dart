import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/tax_engine/document_checklist.dart';

/// `dbService.getProfile()`이 돌려주는 **값의 타입**을 못박는다.
///
/// DB에는 0/1로 저장되지만 `getProfile()`은 bool로 정규화해 돌려준다. 이 계약을
/// 모르고 `as int?`로 캐스팅한 코드가 있었고, 프로필을 한 번이라도 저장한 사용자에게
/// 서류 체크리스트 화면이 통째로 죽었다 — 빈 프로필에서는 null이라 드러나지 않았다.
///
/// 여기서 계약을 고정해 두면 같은 사고가 다시 나지 않는다.
void main() {
  const boolKeys = [
    'is_monthly_rent', 'is_married', 'is_spouse_dependent',
    'has_spouse_disability', 'has_self_disability', 'has_elderly_70plus',
    'is_female_head', 'is_single_parent', 'is_sme_employee', 'type_identified',
    'pension_enrolled', 'health_enrolled', 'employment_enrolled',
    'industrial_accident_enrolled', 'is_new_business', 'has_multiple_businesses',
  ];
  const intKeys = [
    'dependents', 'disabled_dependent_count', 'children_count_total',
    'children_count_credit', 'newborn_count', 'newborn_year', 'pay_day',
  ];

  test('저장 후 다시 읽으면 불리언 컬럼은 bool, 카운트 컬럼은 int로 온다', () async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({
      'user_type': '직장인',
      'gross_income': 42000000.0,
      'dependents': 2,
      'children_count_total': 2,
      'children_count_credit': 2,
      'is_monthly_rent': true,
      'monthly_rent': 600000.0,
      'is_married': true,
      'has_self_disability': false,
      'is_sme_employee': false,
    });
    final p = (await dbService.getProfile())!;

    final wrong = <String>[];
    for (final k in boolKeys) {
      final v = p[k];
      if (v != null && v is! bool) wrong.add('$k: ${v.runtimeType} (bool이어야 함)');
    }
    for (final k in intKeys) {
      final v = p[k];
      if (v != null && v is! int) wrong.add('$k: ${v.runtimeType} (int이어야 함)');
    }
    expect(wrong, isEmpty, reason: '프로필 값 타입 계약이 깨졌다: ${wrong.join(' / ')}');
  });

  test('실제로 채워진 프로필로 서류 체크리스트가 만들어진다 — 3유형 전부', () async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({
      'user_type': '직장인',
      'gross_income': 42000000.0,
      'dependents': 2,
      'is_monthly_rent': true,
      'monthly_rent': 600000.0,
      'is_married': true,
      'has_self_disability': true,
      'has_spouse_disability': true,
      'is_sme_employee': true,
      'wedding_year': 2025,
      'disabled_dependent_count': 1,
    });
    final p = (await dbService.getProfile())!;
    for (final u in ['직장인', '프리랜서', 'N잡러']) {
      final items = buildChecklist(p, u);
      expect(items, isNotEmpty, reason: '$u: 체크리스트가 비었다');
    }
  });

  /// 같은 사고가 다시 나지 않게 **소스를 훑는다.** 위 계약 테스트는 그 코드를
  /// 실행하는 화면을 열어야만 잡지만, 이건 코드가 존재하기만 해도 잡는다.
  test('프로필 불리언 컬럼을 int로 캐스팅하는 코드가 없다', () {
    final offenders = <String>[];
    final castRe = RegExp(r"\['(\w+)'\]\s+as\s+(int|num|double)");
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      // db_helper는 정규화 **전**의 sqlite 원본 행을 읽으므로 int 캐스팅이 맞다.
      if (f.path.replaceAll(r'', '/').endsWith('core/data/db_helper.dart')) continue;
      final lines = f.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        for (final m in castRe.allMatches(lines[i])) {
          if (boolKeys.contains(m.group(1))) {
            offenders.add('${f.path}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
    }
    for (final o in offenders) {
      // ignore: avoid_print
      print('  · $o');
    }
    expect(offenders, isEmpty,
        reason: 'getProfile()은 이 키들을 bool로 준다 — int로 캐스팅하면 '
            '프로필을 저장한 사용자에게서 TypeError로 화면이 죽는다');
  });
}
