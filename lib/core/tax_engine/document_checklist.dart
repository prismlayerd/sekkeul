/// 홈택스 간소화에서 자동 수집되지 않아 사용자가 직접 준비해야 하는 서류 목록.
/// 순수 함수 — DB·위젯 의존 없음. 프로필 플래그 기반이므로 오탐 없음.
library;

class DocItem {
  final String title;
  final String subtitle;
  final bool isHometaxAuto;

  const DocItem({
    required this.title,
    required this.subtitle,
    this.isHometaxAuto = false,
  });
}

List<DocItem> buildChecklist(Map<String, dynamic> profile, String userType) {
  final items = <DocItem>[];
  final isEmployee = userType == '직장인' || userType == 'N잡러';
  final isBusiness = userType == '프리랜서' || userType == 'N잡러';

  // `dbService.getProfile()`은 DB의 0/1을 **bool로 정규화해서** 돌려준다.
  // 여기서 `as int?`로 캐스팅하면 프로필을 한 번이라도 저장한 사용자에게
  // `type 'bool' is not a subtype of type 'int?'`로 화면이 통째로 죽는다.
  // (프로필이 비어 있을 때만 null이라 지금까지 테스트에서 드러나지 않았다.)
  final isMonthlyRent = profile['is_monthly_rent'] == true;
  final isMarried = profile['is_married'] == true;
  final dependents = (profile['dependents'] as int?) ?? 0;
  final hasSelfDisability = profile['has_self_disability'] == true;
  final hasSpouseDisability = profile['has_spouse_disability'] == true;
  final disabledDependentCount = (profile['disabled_dependent_count'] as int?) ?? 0;
  final weddingYear = (profile['wedding_year'] as int?) ?? 0;
  final isSmeEmployee = profile['is_sme_employee'] == true;

  final now = DateTime.now();
  final isRecentWedding = weddingYear >= now.year - 2 && weddingYear > 0;

  if (isMonthlyRent) {
    items.add(const DocItem(
      title: '임대차계약서 사본',
      subtitle: '월세 세액공제 신청용 — 집주인 서명본',
    ));
    items.add(const DocItem(
      title: '월세 이체확인서',
      subtitle: '해당 연도분 은행 이체내역 또는 계좌 거래명세서',
    ));
  }

  if (isMarried || dependents > 0) {
    items.add(const DocItem(
      title: '가족관계증명서',
      subtitle: '간소화에 미등록된 부양가족이 있는 경우 필요',
    ));
  }

  if (isRecentWedding && isEmployee) {
    items.add(const DocItem(
      title: '혼인관계증명서',
      subtitle: '혼인 세액공제 신청용 (혼인 신고 연도 기준)',
    ));
  }

  if (hasSelfDisability || hasSpouseDisability || disabledDependentCount > 0) {
    items.add(const DocItem(
      title: '장애인증명서',
      subtitle: '병원·기관에서 발급 — 세액공제 신청 필수',
    ));
  }

  if (isSmeEmployee && isEmployee) {
    items.add(const DocItem(
      title: '중소기업 취업자 감면신청서',
      subtitle: '회사 인사/급여팀에 요청 — 연말정산 전 제출',
    ));
  }

  if (isBusiness) {
    items.add(const DocItem(
      title: '사업소득 경비 영수증',
      subtitle: '교통비·통신비·임차료 등 비용 처리 항목',
    ));
    items.add(const DocItem(
      title: '3.3% 원천징수 지급명세서',
      subtitle: '거래처별 발급 요청 — 미발급 시 홈택스에서 조회',
    ));
  }

  // 홈택스 간소화 자동 수집 항목 (체크 불필요, 안내용)
  items.add(DocItem(
    title: '홈택스 간소화 자동 수집',
    subtitle: isEmployee
        ? '보험료·의료비·교육비·기부금·연금저축·주택자금 등은 1월 15일부터 간소화 서비스에서 자동 수집돼요.'
        : '보험료·의료비·기부금 등은 홈택스 간소화 서비스에서 한 번에 불러올 수 있어요.',
    isHometaxAuto: true,
  ));

  return items;
}
