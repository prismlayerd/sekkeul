import 'db_helper.dart';
import 'occupation_data.dart';
import 'residence.dart';

/// 대상 판정에 쓰는 「내 정보」 — **모르는 칸은 null**이다.
///
/// 예전엔 소식(유형·시/도)과 정부 일정(차·집, 비면 '있음')이 따로 판정했고
/// 기본값도 제각각이었다. 여기 하나로 모은다. 규칙은 [Target.matches].
class UserFacts {
  final String? type;
  final String? sido;
  final int? age;
  final int militaryMonths;

  /// car·house·noHouse·householdHead·children·disabled·vatLiable·vatExempt
  final Map<String, bool?> flags;

  const UserFacts({
    this.type,
    this.sido,
    this.age,
    this.militaryMonths = 0,
    this.flags = const {},
  });

  /// 프로필이 없으면 유형도 모른다. 있으면 유형을 정한 것으로 본다 —
  /// 홈 머리줄의 「유형 미설정」과 같은 기준이다.
  factory UserFacts.fromProfile(Map<String, dynamic>? p) {
    if (p == null) return const UserFacts();
    final res = residenceOf(p);
    final code = p['occupation_code'] as String?;
    final occ = code == null ? null : OccupationData.occupations[code];
    final kids = p['children_count_total'] as int?;
    final age = p['age'] as int?;
    return UserFacts(
      type: p['user_type'] as String? ?? '직장인',
      sido: p['sido'] as String?,
      age: (age == null || age <= 0) ? null : age,
      militaryMonths: p['military_months'] as int? ?? 0,
      flags: {
        'car': p['owns_car'] as bool?,
        'house': res == null ? null : res == '자가',
        'noHouse': res == null ? null : res != '자가',
        'householdHead': p['is_household_head'] as bool?,
        'children': kids == null ? null : kids > 0,
        'disabled': p['has_self_disability'] as bool?,
        'vatExempt': occ?.isPersonalService,
        'vatLiable': occ == null ? null : !occ.isPersonalService,
      },
    );
  }

  static Future<UserFacts> load() async => UserFacts.fromProfile(await dbService.getProfile());
}

/// 알림·소식 한 건이 누구에게 가는가. 비어 있는 조건은 안 거른다.
class Target {
  final List<String> audience;
  final List<String> regions;
  final List<String> requires;
  final int? ageMin;
  final int? ageMax;

  /// 청년 제도 — 병역 기간만큼 나이 상한을 늘린다.
  final bool ageMilitary;

  const Target({
    this.audience = const [],
    this.regions = const [],
    this.requires = const [],
    this.ageMin,
    this.ageMax,
    this.ageMilitary = false,
  });

  /// 아무 조건도 안 걸린 공통 대상 — 누구에게나 뜬다.
  bool get isCommon =>
      audience.isEmpty && regions.isEmpty && requires.isEmpty && ageMin == null && ageMax == null;

  /// 조건을 다 채우면 true. **모르는 칸에 조건이 걸리면 false** — 대신
  /// [missing]이 무엇을 채우면 되는지 말해 준다.
  bool matches(UserFacts u) => _check(u).ok;

  /// 모르는 칸만 채우면 받을 수 있는 경우, 그 칸 이름들. 아니면 빈 집합.
  Set<String> missing(UserFacts u) {
    final r = _check(u);
    return r.failedKnown ? const {} : r.unknown;
  }

  ({bool ok, bool failedKnown, Set<String> unknown}) _check(UserFacts u) {
    var failed = false;
    final unknown = <String>{};
    void need(bool? v, String label) {
      if (v == null) {
        unknown.add(label);
      } else if (!v) {
        failed = true;
      }
    }

    if (audience.isNotEmpty) need(u.type == null ? null : audience.contains(u.type), 'type');
    if (regions.isNotEmpty) need(u.sido == null ? null : regions.contains(u.sido), 'sido');
    if (ageMin != null || ageMax != null) {
      final a = u.age;
      final max = ageMax == null ? null : ageMax! + (ageMilitary ? u.militaryMonths ~/ 12 : 0);
      need(a == null ? null : a >= (ageMin ?? 0) && (max == null || a <= max), 'age');
    }
    for (final k in requires) {
      need(u.flags[k], k);
    }
    return (ok: !failed && unknown.isEmpty, failedKnown: failed, unknown: unknown);
  }

  static Target fromJson(Map raw) {
    List<String> strs(String k) => [
          for (final v in (raw[k] is List ? raw[k] as List : const []))
            if (v is String && v.trim().isNotEmpty) v.trim(),
        ];
    int? n(String k) => raw[k] is num ? (raw[k] as num).toInt() : null;
    return Target(
      audience: strs('audience'),
      regions: strs('regions'),
      requires: strs('requires'),
      ageMin: n('ageMin'),
      ageMax: n('ageMax'),
      ageMilitary: raw['ageMilitary'] == true,
    );
  }
}

/// 권유 한 줄에 쓰는 이름 — 「내 정보」 화면의 칸 이름과 맞춘다.
const Map<String, String> kFactLabels = {
  'type': '유형',
  'sido': '사는 지역',
  'age': '나이',
  'car': '차량',
  'house': '거주 형태',
  'noHouse': '거주 형태',
  'householdHead': '세대주',
  'children': '자녀',
  'disabled': '장애 여부',
  'vatLiable': '업종',
  'vatExempt': '업종',
};

/// "차량·나이를 넣으면 …" — 모르는 칸이 없으면 null.
String? missingFactsLine(Iterable<String> keys, {String what = '알림'}) {
  final labels = <String>{for (final k in keys) kFactLabels[k] ?? k}.toList();
  if (labels.isEmpty) return null;
  if (labels.contains('유형')) return '유형을 고르면 맞는 $what만 보여드려요';
  return '${labels.take(3).join('·')}을(를) 넣으면 맞는 $what만 보여드려요';
}
