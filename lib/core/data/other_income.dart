import 'dart:convert';

import 'db_helper.dart';

/// 급여 말고 들어오는 소득 — **한 해 합계로 받는다.**
///
/// 사업소득·기타소득은 가계부가 날짜별로 갖고 있다(`YearSnapshot`). 여기 담기는
/// 것은 **가계부가 다룰 성질이 아닌 둘**이다.
///
/// - 이자·배당은 대개 자동 재투자되고, 2,000만원 이하면 이미 분리과세로 끝난
///   돈이다. 매달 통장을 열어 옮겨 적게 하면 아무도 안 한다 — 증권사·은행이
///   연말에 합계를 준다.
/// - 임대료는 매달 들어오지만 생활비 흐름이 아니라 자산이 버는 돈이다.
///   가계부에 섞으면 「이번 달 수입」이 급여와 뒤엉킨다.
class OtherIncome {
  /// 이자 + 배당 총액 (원). 소법 §14③6 — 2,000만원 초과면 종합과세.
  final double financial;

  /// 주택임대 총수입금액 (원). 소법 §64의2 — 2,000만원 초과면 종합과세.
  final double rental;

  const OtherIncome({this.financial = 0, this.rental = 0});

  bool get isEmpty => financial <= 0 && rental <= 0;
}

/// 종합과세로 넘어가는 문턱 — 소득마다 다르고, 하나는 아예 없다.
class IncomeThreshold {
  final String label;

  /// 올해 쌓인 금액.
  final double amount;

  /// 이 금액을 넘으면 종합과세. 0이면 **문턱 자체가 없다**(사업소득).
  final double limit;

  /// 문턱을 넘었거나, 문턱이 없는데 금액이 있는가.
  final bool over;

  /// 넘었을 때 무슨 일이 생기는지 한 줄.
  final String consequence;

  const IncomeThreshold({
    required this.label,
    required this.amount,
    required this.limit,
    required this.over,
    required this.consequence,
  });
}

class OtherIncomeStore {
  const OtherIncomeStore._();

  static String _key(int year) => 'other_income_$year';

  static Future<OtherIncome> load(int year) async {
    final raw = await dbService.getAppState(_key(year));
    if (raw == null || raw.isEmpty) return const OtherIncome();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return OtherIncome(
        financial: (m['financial'] as num?)?.toDouble() ?? 0,
        rental: (m['rental'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return const OtherIncome();
    }
  }

  static Future<void> save(int year, OtherIncome v) => dbService.setAppState(
      _key(year), jsonEncode({'financial': v.financial, 'rental': v.rental}));
}

/// **급여 말고 들어온 돈이 신고 의무를 만드는가.**
///
/// 근로소득「만」 있는 사람은 확정신고를 안 해도 된다(소법 §73①1). 그 「만」이
/// 깨지는 지점이 소득마다 다르다 — 사업소득은 1원이라도 있으면 깨지고, 나머지
/// 셋은 문턱까지는 분리과세로 끝난다.
///
/// [businessIncome]·[otherIncomeAmount]는 가계부에서, [other]는 직접 입력에서 온다.
/// 기타소득은 **소득금액**(수입 − 필요경비)으로 판정한다 — 강의료 500만원은
/// 필요경비 60%를 빼면 소득금액 200만원이라 아직 문턱 아래다.
List<IncomeThreshold> incomeThresholds({
  required double businessIncome,
  required double otherIncomeAmount,
  required OtherIncome other,
}) =>
    [
      if (businessIncome > 0)
        IncomeThreshold(
          label: '사업소득',
          amount: businessIncome,
          limit: 0,
          over: true,
          consequence: '금액과 상관없이 5월에 종합소득세를 신고해야 해요.',
        ),
      if (otherIncomeAmount > 0)
        IncomeThreshold(
          label: '기타소득',
          amount: otherIncomeAmount,
          limit: 3000000,
          over: otherIncomeAmount > 3000000,
          consequence: otherIncomeAmount > 3000000
              ? '소득금액 300만원을 넘어 종합과세로 넘어가요.'
              : '소득금액 300만원까지는 떼인 8.8%로 끝나요. 종합과세를 고를 수도 있어요.',
        ),
      if (other.financial > 0)
        IncomeThreshold(
          label: '금융소득 (이자·배당)',
          amount: other.financial,
          limit: 20000000,
          over: other.financial > 20000000,
          consequence: other.financial > 20000000
              ? '2,000만원을 넘어 종합과세예요. 넘은 만큼만 다른 소득과 합산돼요.'
              : '2,000만원까지는 떼인 15.4%로 끝나요.',
        ),
      if (other.rental > 0)
        IncomeThreshold(
          label: '주택임대소득',
          amount: other.rental,
          limit: 20000000,
          over: other.rental > 20000000,
          consequence: other.rental > 20000000
              ? '총수입 2,000만원을 넘어 종합과세예요.'
              : '총수입 2,000만원까지는 14% 분리과세를 고를 수 있어요.',
        ),
    ];

/// 확정신고를 해야 하는가 — 하나라도 문턱을 넘었으면 참.
bool mustFileReturn(List<IncomeThreshold> t) => t.any((x) => x.over);
