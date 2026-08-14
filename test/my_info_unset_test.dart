import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/my_info_screen.dart';

/// 내 정보는 **사용자가 고른 적 없는 값**을 고른 것처럼 보여주면 안 된다.
///
/// 저장이 미입력을 기본값(전세·자녀 0명·급여일 25일)으로 적고, 화면은 "키가 있으면
/// 설정된 것"으로 읽었다. 그래서 예상 연봉·만 나이만 빼고 전부 자동 기입돼 보였다.
void main() {
  testWidgets('안 고른 항목은 미설정으로 보인다', (tester) async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    // 실제 getProfile()은 **모든 키를 담아** 돌려준다 — 안 고른 항목은 값이 null이다.
    // 그래서 화면이 containsKey로 판정하면 전부 "설정됨"이 된다(그게 이 버그였다).
    await dbService.saveProfile({
      'user_type': '직장인',
      'gross_income': 50000000.0,
      'dependents': null,
      'children_count_total': null,
      'children_count_credit': null,
      'is_monthly_rent': null,
      'owns_house': null,
      'pay_day': null,
    });

    await tester.pumpWidget(MaterialApp(
      home: MyInfoScreen(userType: '직장인', onProfileChanged: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('1명당 150만'), findsOneWidget); // 부양가족 미설정
    expect(find.textContaining('카드공제 한도가 올라가요'), findsOneWidget); // 자녀 미설정
    expect(find.textContaining('월세·전세 공제 기준'), findsOneWidget); // 거주형태 미설정
    expect(find.textContaining('급여일 알림에 쓰여요'), findsOneWidget); // 급여일 미설정
    expect(find.text('전세'), findsNothing);
    expect(find.text('매월 25일'), findsNothing);
  });

  test('연봉을 저장하면 user_profile에도 같이 반영된다', () async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({'user_type': '직장인'});
    await dbService.setProfileTypeValues('직장인', grossIncome: 48000000.0);

    // 화면 아홉 개가 user_profile 쪽을 읽는다 — 한쪽만 갱신되면 "설정해도 초기화"다.
    expect((await dbService.getProfile())!['gross_income'], 48000000.0);
    expect((await dbService.getProfileTypeValues('직장인'))['gross_income'], 48000000.0);
  });
}
