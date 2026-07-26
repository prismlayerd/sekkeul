import '../parsing/simplified_data_parser.dart';
import '../parsing/withholding_parser.dart';

/// 공제 항목 1종의 표시·매핑 메타데이터.
/// 계산(한도·세율)은 엔진이 처리하므로 여기선 표시·홈택스 안내·필드 매핑만 담는다.
/// [id] 는 `GansoDeductions`/`getAnnualRecord`의 필드명과 일치시켜 변환을 단순화한다.
class DeductionCategory {
  final String id;        // 'medical' | 'education' | ...
  final String name;      // 의료비
  final String summary;   // 한 줄 설명
  final String findHint;  // 어디서 찾나 (간소화 자료)
  final String fileHint;  // 홈택스 어디에 입력하나

  const DeductionCategory({
    required this.id,
    required this.name,
    required this.summary,
    required this.findHint,
    required this.fileHint,
  });
}

/// 연말정산에서 빠뜨리기 쉬운 세액공제 6종 (직장인·N잡러 공통).
const List<DeductionCategory> kDeductionCatalog = [
  DeductionCategory(
    id: 'medical',
    name: '의료비',
    summary: '총급여 3% 초과분을 15% 돌려받아요 (난임시술 30%).',
    findHint: '홈택스 → 연말정산 간소화 → 의료비. 실손보험으로 받은 금액은 빼요.',
    fileHint: '세액공제 → 의료비 칸에 본인부담 의료비 합계를 적어요.',
  ),
  DeductionCategory(
    id: 'education',
    name: '교육비',
    summary: '본인·자녀 교육비를 15% 공제받아요.',
    findHint: '홈택스 → 연말정산 간소화 → 교육비 (납입액 합계).',
    fileHint: '세액공제 → 교육비 칸에 대상자별 납입액을 적어요.',
  ),
  DeductionCategory(
    id: 'donation',
    name: '기부금',
    summary: '기부금을 15% (1천만 초과분 30%) 공제받아요.',
    findHint: '홈택스 → 연말정산 간소화 → 기부금, 또는 기부금영수증 합계.',
    fileHint: '세액공제 → 기부금 칸에 기부처별 금액을 적어요.',
  ),
  DeductionCategory(
    id: 'lifeInsurance',
    name: '보장성보험',
    summary: '보장성보험료를 연 100만원 한도로 12% 공제받아요.',
    findHint: '홈택스 → 연말정산 간소화 → 보장성보험료.',
    fileHint: '세액공제 → 보험료 칸에 납입액(최대 100만원)을 적어요.',
  ),
  DeductionCategory(
    id: 'pensionSavings',
    name: '연금저축',
    summary: '연금저축 납입액을 600만원 한도로 12~15% 공제받아요.',
    findHint: '홈택스 → 연말정산 간소화 → 연금저축, 또는 금융사 납입증명.',
    fileHint: '세액공제 → 연금계좌 칸에 납입액을 적어요.',
  ),
  DeductionCategory(
    id: 'rent',
    name: '월세액',
    summary: '무주택 세대주는 월세를 연 1천만 한도로 15~17% 공제받아요.',
    findHint: '임대차계약서·계좌이체 내역. 총급여 8천만원 이하·무주택 세대주만.',
    fileHint: '세액공제 → 월세액 칸에 1년치 월세 합계를 적어요.',
  ),
];

/// 선택 금액(id→금액)으로 `GansoDeductions`(가능액) 구성.
GansoDeductions gansoFromAmounts(Map<String, int> amounts) => GansoDeductions(
      medical: amounts['medical'] ?? 0,
      education: amounts['education'] ?? 0,
      donation: amounts['donation'] ?? 0,
      lifeInsurance: amounts['lifeInsurance'] ?? 0,
      pensionSavings: amounts['pensionSavings'] ?? 0,
      rent: amounts['rent'] ?? 0,
    );

/// 잊은 항목은 '신고액 0' — 총급여·결정세액만 채운 `WithholdingReceipt`.
WithholdingReceipt forgottenReceipt({
  required int accrualYear,
  required int grossSalary,
  required int decidedTax,
}) =>
    WithholdingReceipt(
        accrualYear: accrualYear, grossSalary: grossSalary, decidedTax: decidedTax);

/// `getAnnualRecord` 맵에서 카탈로그 id별 가능액을 뽑아낸다(PDF 보조 프리필).
Map<String, int> amountsFromAnnualRecord(Map<String, dynamic> record) {
  int v(String k) => (record[k] as num?)?.toInt() ?? 0;
  final out = <String, int>{};
  for (final c in kDeductionCatalog) {
    final amt = v(c.id);
    if (amt > 0) out[c.id] = amt;
  }
  return out;
}
