import 'dart:convert';

import 'db_helper.dart';

/// **가계부가 올 한 해를 덮고 있는가.**
///
/// 8월에 앱을 깐 사람은 8~12월 기록만 갖는다. 그런데 카드 공제 문턱(총급여의
/// 25%)도, 올해 예상 환급도 **1월부터의 누적**으로 계산된다. 1~7월이 비어 있는
/// 채로 그 숫자를 내놓으면 앱이 자신 있게 틀린 값을 말한다 — 실제로는 문턱을
/// 이미 넘었는데 "912만원 남았다"고 하는 식이다.
///
/// 그래서 앱은 **자기 데이터가 한 해를 덮는지 알아야 한다.** 안 덮으면 연간
/// 누적 숫자를 내놓지 않고, 채우라고 말한다.
///
/// 판정은 **사용자가 「다 넣었어요」를 누른 것**으로만 한다. 기록이 있는지로
/// 세면 안 된다 — 1~7월에 카드를 안 쓴 사람의 정답은 0원이고, 그 사람은 아무리
/// 기다려도 기록이 안 생긴다. 반대로 한 달만 적은 사람이 통과해서도 안 된다.
class YearCoverage {
  const YearCoverage._();

  static String _doneKey(int year) => 'backfill_done_$year';
  static String _specialKey(int year) => 'card_special_$year';

  /// 이 해의 1월~지난달을 채웠다고 사용자가 확인했는가.
  static Future<bool> isComplete(int year) async {
    if (await dbService.getAppState(_doneKey(year)) == 'y') return true;
    // 1월부터 써 온 사람은 채울 것이 없다. 그 해 1월 기록이 있으면 통과.
    return await _hasJanuaryRecord(year);
  }

  static Future<void> markComplete(int year) =>
      dbService.setAppState(_doneKey(year), 'y');

  static Future<bool> _hasJanuaryRecord(int year) async {
    final all = await dbService.getExpenses();
    return all.any((e) => e.date.year == year && e.date.month == 1);
  }

  /// 공제율이 다른 세 갈래의 **올해(1월~오늘) 누적액**.
  ///
  /// 가계부는 결제수단만 셋(신용카드·체크현금·기타)이라 이 셋을 담을 자리가
  /// 없다. 날짜별 기록으로 쪼개 넣을 수도 없고(그건 없는 기록을 지어내는 것),
  /// 그래서 연 단위 값으로 따로 둔다.
  ///
  /// 계산할 때는 **신용카드 누계에서 뺀다.** 전통시장에서 카드로 긁은 돈은
  /// 가계부에 이미 신용카드로 들어와 있으므로, 안 빼면 15%와 40%로 두 번 센다
  /// (조특법 §126의2 — 이 셋은 신용카드등사용금액에서 제외하고 별도 계산).
  static Future<CardSpecials> specials(int year) async {
    final raw = await dbService.getAppState(_specialKey(year));
    if (raw == null || raw.isEmpty) return const CardSpecials();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return CardSpecials(
        market: (m['market'] as num?)?.toDouble() ?? 0,
        transport: (m['transport'] as num?)?.toDouble() ?? 0,
        culture: (m['culture'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return const CardSpecials();
    }
  }

  static Future<void> setSpecials(int year, CardSpecials v) =>
      dbService.setAppState(
          _specialKey(year),
          jsonEncode({
            'market': v.market,
            'transport': v.transport,
            'culture': v.culture,
          }));

  static String _backfillKey(int year) => 'backfill_$year';

  /// 채워 넣은 지난달까지의 카드·현금 누계.
  ///
  /// **가짜 기록을 만들지 않는다.** 「1~7월에 신용카드 480만원」을 날짜별로
  /// 쪼개 넣으면 달력에 없던 지출이 생긴다. 그건 사용자가 적은 적 없는 일이고,
  /// 나중에 그 칸을 눌러 보면 설명할 수 없는 항목이 나온다. 요약은 요약으로
  /// 둔다 — 달력의 1~7월은 비어 있는 게 사실이다.
  static Future<Backfill> backfill(int year) async {
    final raw = await dbService.getAppState(_backfillKey(year));
    if (raw == null || raw.isEmpty) return const Backfill();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return Backfill(
        credit: (m['credit'] as num?)?.toDouble() ?? 0,
        debit: (m['debit'] as num?)?.toDouble() ?? 0,
        bizIncome: (m['bizIncome'] as num?)?.toDouble() ?? 0,
        bizExpense: (m['bizExpense'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return const Backfill();
    }
  }

  static Future<void> setBackfill(int year, Backfill v) =>
      dbService.setAppState(
          _backfillKey(year),
          jsonEncode({
            'credit': v.credit,
            'debit': v.debit,
            'bizIncome': v.bizIncome,
            'bizExpense': v.bizExpense,
          }));
}

/// 채워 넣은 1월~지난달 합계.
///
/// 유형마다 쓰는 칸이 다르다. 직장인은 카드 둘, 프리랜서는 사업 둘,
/// N잡러는 넷 다 — 근로소득이 있어 카드공제 대상이면서 사업소득도 있어서다.
class Backfill {
  /// 신용카드 사용액 — 카드 공제 문턱·공제율 계산에 들어간다(근로소득자만).
  final double credit;

  /// 체크카드·현금(현금영수증) 사용액.
  final double debit;

  /// 사업 총수입금액. **떼기 전 금액**이다 — 3.3% 원천징수 후 입금액이 아니라
  /// 지급명세서에 찍히는 총액. 세금은 총액 기준으로 계산된다.
  final double bizIncome;

  /// 사업 필요경비. 비워 두면 경비율로 계산되므로 **모르면 비워 두는 게 맞다** —
  /// 어림잡아 넣으면 경비율보다 나쁜 답이 나올 수 있다.
  final double bizExpense;

  const Backfill({
    this.credit = 0,
    this.debit = 0,
    this.bizIncome = 0,
    this.bizExpense = 0,
  });

  double get total => credit + debit;
}

/// 전통시장 40% · 대중교통 40% · 도서·공연·영화 30%.
class CardSpecials {
  final double market;
  final double transport;
  final double culture;

  const CardSpecials({this.market = 0, this.transport = 0, this.culture = 0});

  double get total => market + transport + culture;
  bool get isEmpty => total <= 0;
}
