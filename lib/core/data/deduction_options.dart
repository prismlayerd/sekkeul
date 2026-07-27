import '../tax_engine/employee_tax.dart';
import '../tax_engine/tax_rates.dart';

/// 공제 항목 카탈로그 — 「공제 고르기」와 계산기의 「안 고른 항목」이 같은 목록을 쓴다.
///
/// 문구는 세법 용어가 아니라 사용자의 생활로 쓴다("월세로 살아요").
/// 금액은 하드코딩하지 않고 엔진 함수로 그 사람의 총급여에서 계산한다 —
/// 총급여 5,500만 경계에서 월세 17/15%, 연금 15/12%가 갈리는 것까지 따라간다.
class DeductionOption {
  final String id;
  final String label; // 사용자 말
  final String basis; // 왜 이 금액인지 한 줄
  final double maxCredit; // 이 사람 기준 최대 환급액

  /// 고르면 금액을 물어보는 항목(true) / 사람 수만 세면 되는 항목(false).
  final bool isSpending;

  const DeductionOption(this.id, this.label, this.basis, this.maxCredit,
      {this.isSpending = true});
}

/// 총급여를 모르면 중앙값 근처로 잡는다 — 0원 표시는 아무 도움이 안 된다.
const double kFallbackGrossIncome = 45000000;

/// 소득공제 1원이 환급으로 바뀌는 비율 — 이 사람의 한계세율.
double marginalRateFor(double grossIncome) {
  final g = grossIncome > 0 ? grossIncome : kFallbackGrossIncome;
  final base = EmployeeTaxCalculator.estimateSalaryTaxBase(grossIncome: g);
  return (TaxRates.calculateTax(base + 1000000) - TaxRates.calculateTax(base)) / 1000000;
}

/// 유형별 공제 항목. 해당 없는 항목은 애초에 넣지 않는다.
List<DeductionOption> deductionOptions({
  required String userType,
  required double grossIncome,
}) {
  final bool isEmployee = userType != '프리랜서';
  final double g = grossIncome > 0 ? grossIncome : kFallbackGrossIncome;
  final double marginal = marginalRateFor(g);
  final double rentRate = g <= 55000000 ? 0.17 : 0.15;
  final double pensionRate = g <= 55000000 ? 0.15 : 0.12;

  return [
    // ── 돈을 쓴 곳 ──
    DeductionOption(
        'rent',
        '월세로 살아요',
        isEmployee
            ? '연 1,000만원까지 ${(rentRate * 100).round()}%'
            : '성실사업자만 · 연 1,000만원까지 ${(rentRate * 100).round()}%',
        10000000 * rentRate),
    DeductionOption('pension', '연금저축이나 IRP에 넣어요',
        '연 900만원까지 ${(pensionRate * 100).round()}%', 9000000 * pensionRate),
    DeductionOption('medical', '병원비를 많이 썼어요', '총급여 3% 넘는 금액부터 15%', 7000000 * 0.15),
    DeductionOption('education', '학비를 냈어요', '대학 900만·초중고 300만까지 15%', 9000000 * 0.15),
    DeductionOption('insurance', '보장성보험료를 내요', '연 100만원까지 12%', 1000000 * 0.12),
    if (isEmployee)
      DeductionOption('mortgage', '주택담보대출 이자를 내요',
          '15년 이상이면 800만원부터, 고정금리·비거치식이면 2,000만원까지 과세표준에서 빼요',
          20000000 * marginal),
    DeductionOption('donation', '기부했어요', '1,000만원까지 15%, 넘으면 30%', 10000000 * 0.15),
    DeductionOption('hometown', '고향사랑기부를 했어요', '10만원까지는 전액 돌려받아요',
        EmployeeTaxCalculator.calculateHometownDonationTaxCredit(100000)),

    // ── 나와 가족 ──
    DeductionOption(
        'newborn',
        '올해 아이가 태어났어요',
        '첫째 30만·둘째 50만·셋째부터 70만',
        EmployeeTaxCalculator.calculateChildTaxCredit(childrenCount: 0, newbornCount: 1),
        isSpending: false),
    DeductionOption('disabled', '장애가 있는 가족이 있어요', '1명당 200만원을 과세표준에서 빼요',
        2000000 * marginal,
        isSpending: false),
    DeductionOption('elderly', '70세 이상 가족을 부양해요', '1명당 100만원을 과세표준에서 빼요',
        1000000 * marginal,
        isSpending: false),
    DeductionOption('singleParent', '혼자 아이를 키워요', '100만원을 과세표준에서 빼요',
        1000000 * marginal,
        isSpending: false),
    if (isEmployee)
      DeductionOption('sme', '중소기업에 다녀요', '청년은 5년간 소득세 90%를 깎아줘요', 2000000,
          isSpending: false),
  ];
}
