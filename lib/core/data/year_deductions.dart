import 'dart:convert';

import 'db_helper.dart';

/// **올해 모아 둔 공제 금액** — 항목 id → 금액.
///
/// 가계부가 못 보는 돈이 있다. 의료비·교육비·기부금·보험료·연금저축·월세,
/// 그리고 청약 납입액과 전세대출 원리금. 이것들은 결제할 때마다 문턱이 움직이는
/// 종류가 아니라 **연말에 증명서 한 장으로 확인하는 종류**라, 매일 적게 하면
/// 가계부만 복잡해지고 아무도 안 적는다.
///
/// 그래서 규칙을 이렇게 나눈다.
/// - 긁을 때마다 달라지는 것(카드 3종·전통시장·대중교통·도서공연) → 가계부
/// - 증명서로 확인하는 것 → 여기
///
/// 항목 id는 `kDeductionCatalog`의 id와 같다. 새 항목을 카탈로그에 넣으면
/// 저장은 자동으로 따라온다 — 여기 손댈 일이 없다.
class YearDeductions {
  const YearDeductions._();

  static String _key(int year) => 'year_deductions_$year';

  static Future<Map<String, int>> load(int year) async {
    final raw = await dbService.getAppState(_key(year));
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in m.entries)
          if ((e.value as num?) != null) e.key: (e.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  /// 0원은 지운다 — 「골랐다가 비운 항목」이 남아 있으면 다음에 열었을 때
  /// 체크만 되어 있고 금액이 빈 줄이 되살아난다.
  static Future<void> save(int year, Map<String, int> amounts) async {
    final clean = {
      for (final e in amounts.entries)
        if (e.value > 0) e.key: e.value,
    };
    await dbService.setAppState(_key(year), jsonEncode(clean));
  }
}
