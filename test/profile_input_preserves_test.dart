import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/profile_input_screen.dart';

/// 「더 많은 공제 항목 입력하기」(ProfileInputScreen)를 다녀와도 내 정보에서 입력한
/// 값이 살아있어야 한다.
///
/// saveProfile은 user_profile 행을 통째로 지우고 다시 넣는다. 그래서 이 화면이
/// 저장 맵에 안 적은 컬럼은 전부 날아간다 — 자녀 수·급여일·업종코드처럼 이 화면이
/// 묻지 않는 항목이 "미설정"으로 되돌아가던 원인이다.
void main() {
  testWidgets('공제 항목 입력을 마쳐도 이 화면이 안 묻는 프로필 값은 유지된다', (tester) async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({
      'user_type': '직장인',
      'gross_income': 50000000.0,
      'age': 33,
      'dependents': 1,
      // ↓ ProfileInputScreen이 묻지 않는 값들 — 여기가 지워지면 회귀다.
      'children_count_total': 2,
      'children_count_credit': 1,
      'pay_day': 10,
      'occupation_code': '940306',
      'type_identified': true,
    });

    await tester.pumpWidget(const MaterialApp(
      home: ProfileInputScreen(userType: '직장인'),
    ));
    await tester.pumpAndSettle();

    // 마지막 장까지 '다음'을 누르고 '프로필 완성'으로 저장한다.
    for (int i = 0; i < 30; i++) {
      final next = find.text('다음');
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('프로필 완성'));
    await tester.pumpAndSettle();

    final saved = await dbService.getProfile();
    expect(saved!['children_count_total'], 2, reason: '자녀 수가 지워졌다');
    expect(saved['children_count_credit'], 1, reason: '자녀세액공제 대상 수가 지워졌다');
    expect(saved['pay_day'], 10, reason: '급여일이 기본값 25로 되돌아갔다');
    expect(saved['occupation_code'], '940306', reason: '업종코드가 지워졌다');
    expect(saved['type_identified'], true, reason: '유형 판정 여부가 지워졌다');
    // 이 화면이 실제로 묻는 값은 그대로 저장돼야 한다.
    expect(saved['age'], 33);
    expect(saved['gross_income'], 50000000.0);
  });
}
