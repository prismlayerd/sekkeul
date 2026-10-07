import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/notifications/system_reminder_catalog.dart';

/// 내 정보로 알림·소식을 거르는 규칙 — 모르는 칸에 조건이 걸리면 숨긴다.
void main() {
  SystemReminder sys(String key) => kSystemReminderCatalog.firstWhere((s) => s.key == key);

  test('빈 프로필 — 유형 조건 걸린 건 안 가고, 권유는 유형부터', () {
    const u = UserFacts();
    expect(sys('sys_car_tax_jan').appliesTo(u), isFalse, reason: '차 없는 사람에게 자동차세');
    expect(missingFactsLine(sys('sys_car_tax_jan').target.missing(u)),
        '유형을 고르면 맞는 알림만 보여드려요');
  });

  test('차는 있다고 답해야 자동차세가 간다 — 모르면 숨기고 권유', () {
    const known = UserFacts(type: '직장인', flags: {'car': true});
    const unknown = UserFacts(type: '직장인');
    const none = UserFacts(type: '직장인', flags: {'car': false});
    final car = sys('sys_car_tax_jan');
    expect(car.appliesTo(known), isTrue);
    expect(car.appliesTo(unknown), isFalse);
    expect(car.target.missing(unknown), {'car'});
    expect(car.appliesTo(none), isFalse);
    expect(car.target.missing(none), isEmpty, reason: '없다고 답했으면 권유도 안 한다');
  });

  test('K-Move — 프리랜서·만 34세 이하, 병역 가산 없음', () {
    final k = sys('sys_kmove_h1');
    expect(k.appliesTo(const UserFacts(type: '프리랜서', age: 30)), isTrue);
    expect(k.appliesTo(const UserFacts(type: '프리랜서', age: 35)), isFalse);
    expect(k.appliesTo(const UserFacts(type: '직장인', age: 30)), isFalse);
    expect(k.target.missing(const UserFacts(type: '직장인')), isEmpty,
        reason: '유형에서 이미 떨어졌으면 나이를 물을 이유가 없다');
  });

  test('청년 나이 상한은 병역 기간만큼 늘어난다', () {
    const t = Target(ageMin: 19, ageMax: 34, ageMilitary: true);
    expect(t.matches(const UserFacts(age: 36, militaryMonths: 24)), isTrue);
    expect(t.matches(const UserFacts(age: 37, militaryMonths: 24)), isFalse);
  });

  test('주민세는 세대주에게만', () {
    final r = sys('sys_resident_tax');
    expect(r.appliesTo(const UserFacts(type: 'N잡러', flags: {'householdHead': true})), isTrue);
    expect(r.appliesTo(const UserFacts(type: 'N잡러', flags: {'householdHead': false})), isFalse);
  });

  test('카탈로그 모든 항목에 유형 대상이 있다 — 비면 전원에게 간다', () {
    for (final s in kSystemReminderCatalog) {
      expect(s.target.audience, isNotEmpty, reason: s.key);
    }
  });

  test('fromProfile — 프로필 없으면 전부 모름, 있으면 유형은 안다', () {
    expect(UserFacts.fromProfile(null).type, isNull);
    final u = UserFacts.fromProfile({'owns_car': false, 'age': 0});
    expect(u.type, '직장인');
    expect(u.age, isNull);
    expect(u.flags['car'], isFalse);
  });
}
