/// 가계부의 유형별 역량 선언 — 직장인/N잡러/프리랜서가 가계부를 쓰는 목적이 달라
/// 화면·입력폼·적립카드 노출 여부가 갈린다. 그 분기를 문자열 비교로 여기저기 흩뿌리는 대신
/// 이 객체 하나로 모아, 유형별 값은 [LedgerProfile.of] 단일 진실 원천에서만 정의한다.
///
/// 순수 데이터 클래스 — 위젯·DB에 의존하지 않는다.
class LedgerProfile {
  /// 소득 입력에서 고를 수 있는 소득 유형. 첫 항목이 그 유형의 기본값.
  final List<String> incomeTypes;

  /// 고정 급여('급여') 입력이 있는가 — 직장인·N잡러.
  final bool showsSalaryInput;

  /// 지출에 "사업경비로 인정" 플래그를 노출하는가 — 프리랜서·N잡러.
  final bool tracksBusinessExpense;

  /// 세금·4대보험 적립 카드를 노출하는가 — 프리랜서·N잡러.
  final bool showsReserveCard;

  /// "월급날" 관련 UI(칩 등)를 노출하는가 — 고정 월급날이 있는 직장인·N잡러.
  final bool showsPaydayChip;

  /// 신용카드 공제 문턱 안내를 노출하는가 — 근로소득이 있는 직장인·N잡러.
  final bool showsCardThreshold;

  /// 4대보험을 스스로 가입·납부하는가(건강보험 지역가입 넛지 대상) — 프리랜서.
  final bool selfPaysInsurance;

  /// 소득 입력 시 원천징수(세후 입력)를 기본으로 켜는가 — 프리랜서.
  final bool withholdingDefault;

  const LedgerProfile({
    required this.incomeTypes,
    required this.showsSalaryInput,
    required this.tracksBusinessExpense,
    required this.showsReserveCard,
    required this.showsPaydayChip,
    required this.showsCardThreshold,
    required this.selfPaysInsurance,
    required this.withholdingDefault,
  });

  /// 소득이 없을 때 폼에 미리 채울 기본 소득 유형.
  String get defaultIncomeType => incomeTypes.first;

  /// 유형 문자열 → 프로필. 알 수 없는 값은 직장인으로 폴백(가장 단순·안전한 형태).
  factory LedgerProfile.of(String userType) {
    switch (userType) {
      case '프리랜서':
        return const LedgerProfile(
          incomeTypes: ['사업소득', '기타소득'],
          showsSalaryInput: false,
          tracksBusinessExpense: true,
          showsReserveCard: true,
          showsPaydayChip: false,
          showsCardThreshold: false,
          selfPaysInsurance: true,
          withholdingDefault: true,
        );
      case 'N잡러':
        return const LedgerProfile(
          incomeTypes: ['급여', '사업소득', '기타소득'],
          showsSalaryInput: true,
          tracksBusinessExpense: true,
          showsReserveCard: true,
          showsPaydayChip: true,
          showsCardThreshold: true,
          selfPaysInsurance: false,
          withholdingDefault: false,
        );
      case '직장인':
      default:
        return const LedgerProfile(
          incomeTypes: ['급여', '기타소득'],
          showsSalaryInput: true,
          tracksBusinessExpense: false,
          showsReserveCard: false,
          showsPaydayChip: true,
          showsCardThreshold: true,
          selfPaysInsurance: false,
          withholdingDefault: false,
        );
    }
  }
}
