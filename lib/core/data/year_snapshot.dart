import 'db_helper.dart';
import 'expense_item.dart';
import 'residence.dart';
import 'year_coverage.dart';
import 'year_deductions.dart';

/// 카드공제에서 이 지출이 세어지는 갈래. `null`이면 공제 대상이 아니다.
///
/// **이 규칙이 화면마다 따로 적혀 있었다.** 홈 02는 셋으로 갈랐는데 연말정산
/// 진단과 홈택스 가이드는 둘로 갈라, 「기타」(현금영수증 없는 지출)를 체크·현금에
/// 섞어 공제를 부풀렸다. 같은 앱의 두 화면이 다른 카드공제액을 말한 것이다.
/// 규칙은 여기 하나만 둔다.
///
/// 전통시장·대중교통·도서공연은 신용카드등사용금액에서 **빼고** 따로 센다
/// (조특법 §126의2②). 안 빼면 같은 돈이 15%와 40%로 두 번 계산된다.
String? cardBucket(ExpenseItem e) {
  if (e.paymentMethod == '기타') return null;
  final dt = e.deductionType;
  if (dt == '전통시장' || dt == '대중교통' || dt == '도서공연') return dt;
  if (e.paymentMethod == '신용카드') return '신용카드';
  if (e.paymentMethod == '체크+현금') return '체크+현금';
  return null;
}

/// 채워야 하는데 아직 빈 칸 하나.
class MissingInput {
  final String label;

  /// 어디로 가서 채우나 — 화면에 그대로 찍는다.
  final String where;

  /// 없으면 **숫자가 틀린다**. 경고(있으면 좋다)와 구분한다 —
  /// 신고서가 "정확하지 않다"고 말할지 말지가 여기서 갈린다.
  final bool blocking;

  const MissingInput(this.label, this.where, {this.blocking = false});
}

/// **올해 이 사람의 숫자 한 벌.**
///
/// 예전에는 화면마다 `getExpenses`를 돌려 각자의 규칙으로 다시 셌다. 홈 02,
/// 연말정산 진단, 홈택스 가이드, 적립 카드가 전부 그랬다. 그래서 규칙이 하나
/// 바뀔 때마다 한 군데씩 뒤처졌고, 실제로 두 화면이 다른 카드공제액을 말했다.
///
/// 이제 연말 화면들은 전부 여기서 시작한다. 진단을 안 돌려도 신고서가 채워지고,
/// 무엇이 비었는지도 같이 나온다 — 사용자가 01·02를 꾸준히 쓴 것이 연말에
/// 그대로 보여야 한다.
class YearSnapshot {
  final int year;
  final String userType;
  final Map<String, dynamic> profile;

  /// 근로소득 총급여 (내 정보의 예상 연봉).
  final double laborIncome;

  /// 사업 총수입 — 가계부 수입 + 백필.
  final double businessIncome;

  /// 기타소득 총수입 (강사료·원고료 등).
  final double otherIncome;

  /// 사업 필요경비 — 가계부에서 「사업」 표시한 지출 + 백필.
  final double businessExpense;

  /// 카드공제용 연 누계. 특례 셋은 이미 빠져 있다.
  final double creditCard;
  final double debitCash;

  /// 「기타」 결제수단 — 문턱에 안 들어간다. 왜 안 늘어나는지 설명하는 데 쓴다.
  final double excluded;

  final double market;
  final double transport;
  final double culture;

  /// 「올해 받을 공제」에 모아 둔 금액 (id → 원).
  final Map<String, int> deductions;

  /// 1월~지난달을 채웠는가.
  final bool yearCovered;

  final List<MissingInput> missing;

  const YearSnapshot({
    required this.year,
    required this.userType,
    required this.profile,
    required this.laborIncome,
    required this.businessIncome,
    required this.otherIncome,
    required this.businessExpense,
    required this.creditCard,
    required this.debitCash,
    required this.excluded,
    required this.market,
    required this.transport,
    required this.culture,
    required this.deductions,
    required this.yearCovered,
    required this.missing,
  });

  bool get isEmployee => userType == '직장인' || userType == 'N잡러';
  bool get hasBusiness => userType == '프리랜서' || userType == 'N잡러';

  /// 채워야 정확해지는 칸이 남았는가 — 신고서가 "정확하지 않다"고 말할 조건.
  bool get hasBlocking => missing.any((m) => m.blocking);

  /// 카드공제 대상 총액 (문턱 판정용).
  double get cardTotal => creditCard + debitCash + market + transport + culture;

  static Future<YearSnapshot> load(String userType, {int? year}) async {
    final now = DateTime.now();
    final y = year ?? now.year;
    final profile = await dbService.getProfile() ?? <String, dynamic>{};

    final covered = await YearCoverage.isComplete(y);
    final backfill = await YearCoverage.backfill(y);
    final special = await YearCoverage.specials(y);
    final deductions = await YearDeductions.load(y);

    double credit = 0, debit = 0, excluded = 0;
    double market = special.market,
        transport = special.transport,
        culture = special.culture;
    double bizExpense = backfill.bizExpense;

    for (final e in await dbService.getExpenses(userType: userType)) {
      if (e.date.year != y) continue;
      if (e.isBusiness) bizExpense += e.amount;
      switch (cardBucket(e)) {
        case '신용카드':
          credit += e.amount;
        case '체크+현금':
          debit += e.amount;
        case '전통시장':
          market += e.amount;
        case '대중교통':
          transport += e.amount;
        case '도서공연':
          culture += e.amount;
        default:
          excluded += e.amount;
      }
    }
    credit += backfill.credit;
    debit += backfill.debit;

    double bizIncome = backfill.bizIncome, other = 0;
    for (var m = 1; m <= 12; m++) {
      for (final i in await dbService.getIncomeEntriesForMonth(y, m, userType: userType)) {
        if (i.incomeType == '기타소득') {
          other += i.amount;
        } else {
          bizIncome += i.amount;
        }
      }
    }

    final labor = (profile['gross_income'] as num?)?.toDouble() ?? 0.0;

    return YearSnapshot(
      year: y,
      userType: userType,
      profile: profile,
      laborIncome: labor,
      businessIncome: bizIncome,
      otherIncome: other,
      businessExpense: bizExpense,
      creditCard: credit,
      debitCash: debit,
      excluded: excluded,
      market: market,
      transport: transport,
      culture: culture,
      deductions: deductions,
      yearCovered: covered,
      missing: _audit(
        userType: userType,
        profile: profile,
        labor: labor,
        bizIncome: bizIncome,
        bizExpense: bizExpense,
        covered: covered,
        deductions: deductions,
      ),
    );
  }

  /// **무엇이 비었는지 앱이 판단한다.**
  ///
  /// 서류 준비 목록(`buildChecklist`)과 다르다. 저쪽은 "홈택스에 뭘 들고 가라"고,
  /// 이쪽은 "앱에 뭘 아직 안 넣었다"고 말한다. 지금까지 후자를 말하는 곳이
  /// 없어서, 반쯤 채운 신고서가 다 채운 것처럼 보였다.
  static List<MissingInput> _audit({
    required String userType,
    required Map<String, dynamic> profile,
    required double labor,
    required double bizIncome,
    required double bizExpense,
    required bool covered,
    required Map<String, int> deductions,
  }) {
    final employee = userType == '직장인' || userType == 'N잡러';
    final business = userType == '프리랜서' || userType == 'N잡러';
    final out = <MissingInput>[];

    if (employee && labor <= 0) {
      out.add(const MissingInput('예상 연봉', '내 정보', blocking: true));
    }
    if (business && bizIncome <= 0) {
      out.add(const MissingInput('사업 수입', '가계부', blocking: true));
    }
    if (business && (profile['occupation_code'] as String?) == null) {
      // 업종코드가 없으면 경비율을 못 고른다 — 세금이 통째로 안 나온다.
      out.add(const MissingInput('업종', '내 정보', blocking: true));
    }
    if (!covered) {
      out.add(const MissingInput('1월~지난달 기록', '홈 배너 · 이전 달 채우기',
          blocking: true));
    }
    if (residenceOf(profile) == null) {
      out.add(const MissingInput('거주 형태', '내 정보'));
    } else if (!ownsHome(profile) && profile['is_household_head'] == null) {
      out.add(const MissingInput('세대주 여부', '내 정보'));
    }
    if (profile['dependents'] == null) {
      out.add(const MissingInput('부양가족 수', '내 정보'));
    }
    if (employee && deductions.isEmpty) {
      out.add(const MissingInput('의료비·교육비 등 공제', '홈 02 · 올해 받을 공제'));
    }
    if (business && bizExpense <= 0) {
      out.add(const MissingInput('사업 경비', '가계부 · 지출에 「사업」 표시'));
    }
    return out;
  }
}
