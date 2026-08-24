import 'dart:convert';

import 'db_helper.dart';

/// 급여 말고 들어오는 소득 — **한 해 합계로 받는다.**
///
/// 사업소득·기타소득은 가계부가 날짜별로 갖고 있다(`YearSnapshot`). 여기 담기는
/// 것은 **가계부가 다룰 성질이 아닌 둘**이다.
///
/// - 이자·배당은 대개 자동 재투자되고, 2,000만원 이하면 이미 분리과세로 끝난
///   돈이다. 매달 통장을 열어 옮겨 적게 하면 아무도 안 한다.
/// - 임대료는 매달 들어오지만 생활비 흐름이 아니라 자산이 버는 돈이다.
///   가계부에 섞으면 「이번 달 수입」이 급여와 뒤엉킨다.
class OtherIncome {
  /// 이자 + 배당 총액 (원).
  final double financial;

  /// 그 금융소득이 **원천징수됐는가.** 소법 §14③6은 2,000만원 이하「이면서
  /// 원천징수된」 것만 분리과세로 끝낸다 — 국외 계좌에서 받은 이자·배당처럼
  /// 원천징수가 안 된 것은 **금액과 상관없이 종합과세**다. 국내 은행·증권사를
  /// 통했으면 참이라 기본값을 참으로 둔다.
  final bool financialWithheld;

  /// 주택임대 월세 연 합계 (원).
  final double rentalRent;

  /// 소유한 주택 수. 0이면 임대 없음.
  ///
  /// **1주택이면 대개 비과세다**(§12 2호 나목) — 기준시가 12억을 넘거나 국외에
  /// 있는 주택만 예외. 이걸 안 물으면 1주택 임대인에게 없는 신고 의무를 만든다.
  final int houseCount;

  /// 1주택인데 기준시가가 12억원을 넘는가 (또는 국외 주택인가).
  final bool overHighValue;

  /// 임대보증금 합계 (원). **3주택 이상일 때만 총수입에 들어간다** —
  /// (보증금 − 3억) × 60% × 정기예금이자율 (시행령 §53③1).
  final double deposit;

  const OtherIncome({
    this.financial = 0,
    this.financialWithheld = true,
    this.rentalRent = 0,
    this.houseCount = 0,
    this.overHighValue = false,
    this.deposit = 0,
  });

  bool get isEmpty => financial <= 0 && rentalRent <= 0;

  Map<String, dynamic> toJson() => {
        'financial': financial,
        'financialWithheld': financialWithheld,
        'rentalRent': rentalRent,
        'houseCount': houseCount,
        'overHighValue': overHighValue,
        'deposit': deposit,
      };

  static OtherIncome fromJson(Map<String, dynamic> m) => OtherIncome(
        financial: (m['financial'] as num?)?.toDouble() ?? 0,
        financialWithheld: m['financialWithheld'] as bool? ?? true,
        // 옛 키 — 월세·보증금을 가르기 전에는 'rental' 하나였다.
        rentalRent: (m['rentalRent'] as num?)?.toDouble() ??
            (m['rental'] as num?)?.toDouble() ??
            0,
        houseCount: (m['houseCount'] as num?)?.toInt() ?? 0,
        overHighValue: m['overHighValue'] as bool? ?? false,
        deposit: (m['deposit'] as num?)?.toDouble() ?? 0,
      );
}

/// 종합과세로 넘어가는 문턱 — 소득마다 다르고, 하나는 아예 없다.
class IncomeThreshold {
  final String label;
  final double amount;

  /// 이 금액을 넘으면 종합과세. 0이면 **문턱 자체가 없다**(사업소득).
  final double limit;

  /// 넘었거나, 문턱이 없는데 금액이 있는가.
  final bool over;

  /// **앱이 판정할 수 없는 상태.** 참이면 [over]를 믿으면 안 된다.
  final bool undecided;

  /// 무슨 일이 생기는지 한 줄.
  final String consequence;

  const IncomeThreshold({
    required this.label,
    required this.amount,
    required this.limit,
    required this.over,
    required this.consequence,
    this.undecided = false,
  });
}

class OtherIncomeStore {
  const OtherIncomeStore._();

  static String _key(int year) => 'other_income_$year';

  static Future<OtherIncome> load(int year) async {
    final raw = await dbService.getAppState(_key(year));
    if (raw == null || raw.isEmpty) return const OtherIncome();
    try {
      return OtherIncome.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const OtherIncome();
    }
  }

  static Future<void> save(int year, OtherIncome v) =>
      dbService.setAppState(_key(year), jsonEncode(v.toJson()));
}

const double _twentyMillion = 20000000;

/// 간주임대료 계산에 쓰는 정기예금이자율 — **연 3.1%**.
///
/// 소득세법 시행규칙 §23① 「연 1천분의 31」 (시행 2026-07-01, 확인일 2026-08-24).
/// 재정경제부령이라 **해마다 바뀔 수 있다** — 세법 유지보수 때 같이 본다.
const double kDepositInterestRate = 0.031;

/// 간주임대료 — 3주택 이상일 때 보증금이 총수입에 들어가는 몫.
///
/// 시행령 §53③1: (보증금 − 3억) × 60% × 정기예금이자율.
///
/// ponytail: 조문은 **적수**(월말 잔액 × 경과일수 ÷ 365)로 재는데, 여기서는
/// 연중 보증금이 같다고 보고 근사한다. 앱이 월별 보증금 변동을 받지 않아서다 —
/// 보증금이 중간에 바뀐 사람은 실제와 다를 수 있고, 화면이 그렇게 밝힌다.
double deemedRentalIncome(double deposit) {
  final over = deposit - 300000000;
  if (over <= 0) return 0;
  return over * 0.6 * kDepositInterestRate;
}

/// **급여 말고 들어온 돈이 신고 의무를 만드는가.**
///
/// 근로소득「만」 있는 사람은 확정신고를 안 해도 된다(소법 §73①1). 그 「만」이
/// 깨지는 지점이 소득마다 다르다.
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
      if (other.financial > 0) _financial(other),
      if (other.rentalRent > 0 && other.houseCount > 0) _rental(other),
    ];

IncomeThreshold _financial(OtherIncome o) {
  // §14③6 — 「2천만원 이하이면서 원천징수된」 둘 다여야 분리과세다.
  if (!o.financialWithheld) {
    return IncomeThreshold(
      label: '금융소득 (이자·배당)',
      amount: o.financial,
      limit: 0,
      over: true,
      consequence: '원천징수가 안 된 이자·배당은 금액과 상관없이 종합과세예요 '
          '(국외 계좌 등).',
    );
  }
  final over = o.financial > _twentyMillion;
  return IncomeThreshold(
    label: '금융소득 (이자·배당)',
    amount: o.financial,
    limit: _twentyMillion,
    over: over,
    consequence: over
        ? '2,000만원을 넘어 종합과세예요. 넘은 만큼만 다른 소득과 합산돼요.'
        : '2,000만원까지는 떼인 15.4%로 끝나요.',
  );
}

IncomeThreshold _rental(OtherIncome o) {
  // §12 2호 나목 — **1주택은 비과세다.** 기준시가 12억 초과·국외 주택만 예외.
  // 이걸 안 보면 1주택 임대인에게 없는 신고 의무를 만든다.
  if (o.houseCount == 1 && !o.overHighValue) {
    return IncomeThreshold(
      label: '주택임대소득',
      amount: o.rentalRent,
      limit: 0,
      over: false,
      consequence: '1주택이고 기준시가 12억원 이하라 비과세예요 — 신고 안 하셔도 돼요.',
    );
  }

  // 시행령 §53③1 — 3주택 이상이면 보증금 중 3억 초과분도 총수입에 들어간다.
  final deemed = o.houseCount >= 3 ? deemedRentalIncome(o.deposit) : 0.0;
  final total = o.rentalRent + deemed;
  final over = total > _twentyMillion;

  return IncomeThreshold(
    label: '주택임대소득',
    amount: total,
    limit: _twentyMillion,
    over: over,
    consequence: [
      if (deemed > 0)
        '보증금 중 3억원 초과분의 간주임대료 ${_comma(deemed.round())}원이 '
            '총수입에 더해졌어요 (시행령 §53③1).',
      over
          ? '총수입 2,000만원을 넘어 종합과세예요.'
          : '총수입 2,000만원까지는 14% 분리과세를 고를 수 있어요 (필요경비 50% 인정).',
    ].join(' '),
  );
}

String _comma(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// 확정신고를 해야 하는가 — 하나라도 문턱을 넘었으면 참.
bool mustFileReturn(List<IncomeThreshold> t) => t.any((x) => x.over);

/// 앱이 단정할 수 없는 항목이 있는가 — 있으면 「아니다」도 단정하면 안 된다.
bool hasUndecided(List<IncomeThreshold> t) => t.any((x) => x.undecided);
