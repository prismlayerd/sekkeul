/// 거주 형태 — 어떤 주택 공제를 보여줄지 가르는 기준.
///
/// 예전에는 불리언 두 개(`owns_house`, `is_monthly_rent`)로만 저장했다. 그래서
/// 내 정보가 선택지를 넷 주고도 **「반전세」를 고르면 「전세」로 저장**됐다.
/// 하필 반전세가 둘 다 받는 경우다 — 보증금 대출 원리금(소법 §52④)도 받고
/// 월세액 세액공제(조특법 §95의2)도 받는다. 답을 버리면 그 사람에게 월세 칸을
/// 안 보여준다.
///
/// 지금은 `residence_type`이 정본이고 불리언 둘은 옛 읽는 쪽을 위해 같이 쓴다.
library;

const List<String> kResidenceTypes = ['전세', '월세', '반전세', '자가'];

/// 프로필에서 거주 형태를 읽는다. 아직 안 정했으면 null.
String? residenceOf(Map<String, dynamic>? p) {
  final t = p?['residence_type'] as String?;
  if (t != null && kResidenceTypes.contains(t)) return t;
  // v45 이전에 저장된 프로필 — 불리언 둘에서 되살린다(반전세는 복원 불가).
  if (p?['owns_house'] == true) return '자가';
  if (p?['is_monthly_rent'] == true) return '월세';
  if (p?['owns_house'] == false || p?['is_monthly_rent'] == false) return '전세';
  return null;
}

/// 매달 월세를 내는가 — 월세액 세액공제(조특법 §95의2) 대상 판정용.
bool paysMonthlyRent(Map<String, dynamic>? p) {
  final t = residenceOf(p);
  return t == '월세' || t == '반전세';
}

/// 보증금이 걸려 있는가 — 주택임차차입금 원리금 공제(소법 §52④) 대상 판정용.
bool hasLeaseDeposit(Map<String, dynamic>? p) {
  final t = residenceOf(p);
  return t == '전세' || t == '반전세';
}

/// 집이 있는가. 무주택 요건이 걸린 공제는 전부 여기서 걸러진다.
bool ownsHome(Map<String, dynamic>? p) => residenceOf(p) == '자가';

/// 주민등록상 세대주인가 (소법 §52④·⑤, 조특법 §87②·§95의2 공통 요건).
///
/// §87②만 「세대주 또는 그 배우자」까지 넓다. 나머지는 세대주 본인이다.
bool isHouseholdHead(Map<String, dynamic>? p) => p?['is_household_head'] == true;

/// 거주 형태를 옛 불리언 두 개로 되돌린다 — 저장할 때 같이 쓴다.
Map<String, dynamic> residenceFields(String type) => {
      'residence_type': type,
      'is_monthly_rent': type == '월세' || type == '반전세',
      'owns_house': type == '자가',
    };
