import '../data/expense_item.dart';
import '../data/income_entry.dart';

/// 간편장부 한 줄 — 국세청 간편장부 서식(소득세법 시행규칙 별지 제82호)의 열 구성.
///
/// | 일자 | 계정과목 | 거래내용 | 거래처 | 수입(금액/부가세) | 비용(금액/부가세) | 비고 |
///
/// 이 앱은 가계부에 거래처·부가세를 받지 않으므로 그 칸은 비운다 — 지어내면
/// 그대로 신고서에 실려 나가므로, 빈칸으로 두고 사용자가 채우게 한다.
class SimpleLedgerRow {
  final DateTime date;

  /// 계정과목 — 수입은 '매출', 비용은 가계부 지출 카테고리를 그대로 쓴다.
  final String account;

  /// 거래내용 — 가계부 메모/내용.
  final String description;

  /// 수입 금액(원). 비용 줄이면 0.
  final int income;

  /// 비용 금액(원). 수입 줄이면 0.
  final int expense;

  /// 비고 — 원천징수 여부·결제수단처럼 증빙 찾을 때 단서가 되는 것.
  final String note;

  const SimpleLedgerRow({
    required this.date,
    required this.account,
    required this.description,
    required this.income,
    required this.expense,
    required this.note,
  });
}

/// 가계부 기록 → 간편장부 변환 결과.
class SimpleLedgerResult {
  final int year;
  final List<SimpleLedgerRow> rows;
  final int totalIncome;
  final int totalExpense;

  /// 거래내용이 비어 있어 사용자가 채워야 하는 줄 수 — 신고 전 보완 안내용.
  final int blankDescriptionCount;

  const SimpleLedgerResult({
    required this.year,
    required this.rows,
    required this.totalIncome,
    required this.totalExpense,
    required this.blankDescriptionCount,
  });

  bool get isEmpty => rows.isEmpty;
}

/// 가계부의 그 해 기록을 간편장부 형식으로 정리한다.
///
/// - 수입: 사업소득·기타소득만(급여는 근로소득이라 사업 장부에 넣지 않는다).
///   원천징수로 세후 입력된 건은 **세전으로 환산**해 적는다 — 장부의 수입금액은
///   총수입금액(매출)이지 실수령액이 아니다.
/// - 비용: `isBusiness`로 표시한 사업경비만. 개인 지출은 장부에 들어가면 안 된다.
class SimpleLedgerBuilder {
  /// 원천징수 세후액 → 세전 환산. 가계부 입력 화면·적립 계산과 같은 상수.
  static int _grossOf(int amount, String incomeType, bool isWithheld) {
    if (!isWithheld) return amount;
    final divisor = incomeType == '기타소득' ? 0.912 : 0.967;
    return (amount / divisor).round();
  }

  static SimpleLedgerResult build({
    required int year,
    required List<IncomeEntry> incomes,
    required List<ExpenseItem> expenses,
  }) {
    final rows = <SimpleLedgerRow>[];
    int totalIncome = 0;
    int totalExpense = 0;
    int blank = 0;

    for (final e in incomes) {
      if (e.date.year != year) continue;
      if (e.incomeType == '급여') continue; // 근로소득은 사업 장부 대상이 아님
      final gross = _grossOf(e.amount, e.incomeType, e.isWithheld);
      totalIncome += gross;
      if (e.memo.trim().isEmpty) blank++;
      rows.add(SimpleLedgerRow(
        date: e.date,
        account: '매출',
        description: e.memo.trim(),
        income: gross,
        expense: 0,
        note: e.isWithheld
            ? '원천징수 후 ${e.amount}원 수령 (세전 환산)'
            : '',
      ));
    }

    for (final x in expenses) {
      if (x.date.year != year) continue;
      if (!x.isBusiness) continue; // 개인 지출 제외
      totalExpense += x.amount;
      if (x.content.trim().isEmpty) blank++;
      rows.add(SimpleLedgerRow(
        date: x.date,
        account: x.category,
        description: x.content.trim(),
        income: 0,
        expense: x.amount,
        note: x.paymentMethod,
      ));
    }

    rows.sort((a, b) => a.date.compareTo(b.date));

    return SimpleLedgerResult(
      year: year,
      rows: rows,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      blankDescriptionCount: blank,
    );
  }

  /// 엑셀·홈택스에 붙여넣을 수 있는 CSV. 국세청 서식 열 순서를 따른다.
  /// 거래처·부가세 칸은 앱이 받지 않는 정보라 비워 두고 사용자가 채운다.
  static String toCsv(SimpleLedgerResult r) {
    String esc(String s) =>
        s.contains(',') || s.contains('"') || s.contains('\n')
            ? '"${s.replaceAll('"', '""')}"'
            : s;

    final b = StringBuffer();
    // 엑셀이 UTF-8 한글을 깨지 않도록 BOM을 붙인다.
    b.write('﻿');
    b.writeln('일자,계정과목,거래내용,거래처,수입-금액,수입-부가세,비용-금액,비용-부가세,비고');
    for (final row in r.rows) {
      final d = '${row.date.year}-'
          '${row.date.month.toString().padLeft(2, '0')}-'
          '${row.date.day.toString().padLeft(2, '0')}';
      b.writeln([
        d,
        esc(row.account),
        esc(row.description),
        '', // 거래처 — 앱이 받지 않음
        row.income == 0 ? '' : '${row.income}',
        '', // 수입 부가세
        row.expense == 0 ? '' : '${row.expense}',
        '', // 비용 부가세
        esc(row.note),
      ].join(','));
    }
    b.writeln();
    b.writeln('합계,,,,${r.totalIncome},,${r.totalExpense},,');
    return b.toString();
  }
}
