/// 세끌 세법 기준연도 — 단일 출처(single source of truth)와 연 1회 갱신 가이드.
///
/// 이 파일은 "올해 세법으로 맞추려면 무엇을, 어디서 고쳐야 하는가"의 색인이다.
/// 계산 엔진 로직은 그대로 두고, **연도에 따라 바뀌는 값**만 아래 위치에서 갱신한다.
///
/// ─────────────────────────────────────────────────────────────
/// ■ 연 1회 갱신 체크리스트 (귀속연도 바뀔 때)
/// ─────────────────────────────────────────────────────────────
/// 1) [kReferenceTaxYear] 아래 상수 → 새 귀속연도로.
/// 2) 4대보험 요율 (대개 매년 변동)
///    └ lib/core/tax_engine/insurance_engine.dart
///      empHealthInsuranceRate / longTermCareRate / empEmploymentInsuranceRate
///      njobHealthInsuranceRate / healthScoreUnitAmount 등
///    └ 직장인 즉시계산: lib/core/tax_engine/employee_tax.dart 의 보험 요율도 동일 값 확인
/// 3) 국민연금 기준소득월액 상·하한 (매년 7월 고시) **및** 보험료율(%) 자체
///    └ TaxRates.nationalPensionBaseUpperLimit / nationalPensionBaseLowerLimit
///      (insurance_engine 은 이 상수를 참조 — 한 곳만 고치면 됨)
///    └ insurance_engine.dart 의 empNationalPensionRate / freeNationalPensionRate
///      — 상하한(월 소득 범위)만 매년 갱신되는 게 아니라 요율(%) 자체도 개정될 수
///      있음(2026-01-01 국민연금법 개정으로 9%→9.5%/4.5%→4.75%, D-2에서 발견).
///      employee_tax.dart 의 하드코딩 요율도 동일 값인지 반드시 함께 확인.
/// 4) 종합소득세 과세표준 구간·세율 (개정 시)
///    └ TaxRates.incomeTaxBrackets
/// 5) 인적공제·세액공제 (자녀·출산·혼인 등 개정 시)
///    └ TaxRates.basicDeductionPerPerson, additionalDeduction*, calculateChildTaxCredit 등
/// 6) 공제 한도 (연금저축·월세·노란우산 등 개정 시)
///    └ lib/core/tax_engine/employee_tax.dart (연금저축·월세 한도 분기),
///      lib/core/tax_engine/combined_tax.dart (노란우산 한도 등)
/// 7) 주요 세무 일정 (신고·납부 기한)
///    └ lib/core/notifications/system_reminder_catalog.dart (월/일 고정값)
/// 8) 시의성 안내·개정 혜택 문구
///    └ lib/core/data/tax_tips.dart ('2026 혜택' 등 라벨/본문)
/// 9) 공휴일 (대체공휴일·임시공휴일 매년)
///    └ lib/core/data/kr_holidays.dart
///
/// ※ 값을 바꾼 뒤에는 반드시 `flutter test`(엔진 회귀 테스트)로 검증한다.
class TaxYear {
  const TaxYear._();

  /// 앱이 계산 기준으로 삼는 귀속연도. (예: 2026년 귀속 = 2027년 5월 신고)
  ///
  /// 앱의 핵심은 "지금 어떻게 쓰면 환급이 커지는가"를 미리 알려주는 것이라,
  /// 기준은 언제나 **올해 벌고 쓰는 소득의 귀속연도**여야 한다. 지난해 규정으로
  /// 올해 소비를 안내하면 사전 처방이 사후 규정을 따르는 꼴이 된다.
  ///
  /// ⚠ 세무도구의 경정청구는 예외다 — 지난 5년치를 다루므로 영수증의 귀속연도
  /// 규정이 필요하다. 현재 공제율이 하드코딩이라 이 상수로 분기되지 않는다(부채).
  static const int reference = 2026;

  /// 표시용 라벨 — "2026 귀속 기준" 등.
  static String get label => '$reference년 귀속 기준';
}

/// 짧은 전역 별칭.
const int kReferenceTaxYear = TaxYear.reference;
