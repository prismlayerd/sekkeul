import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/core/tax_engine/simple_ledger_builder.dart';

/// 기타소득은 사업소득이 아니다(소득세법 §21①) — 사업 장부 수입에 섞이면 안 된다.
void main() {
  IncomeEntry inc(String id, int m, int amt, String type, {bool w = true}) => IncomeEntry(
      id: id, date: DateTime(2026, m, 1), amount: amt, incomeType: type, memo: 'm', isWithheld: w);

  test('기타소득은 장부에서 빠지고 건수·세전합계만 알려준다', () {
    final r = SimpleLedgerBuilder.build(year: 2026, expenses: const [], incomes: [
      inc('a', 3, 967000, '사업소득'),
      inc('b', 4, 912000, '기타소득'),
    ]);
    expect(r.rows.length, 1);
    expect(r.totalIncome, 1000000);
    expect(r.otherIncomeCount, 1);
    expect(r.otherIncomeGross, 1000000);
  });

  test('CSV에 사업용자산 증감 칸이 있고 합계 줄 칸 수가 헤더와 같다', () {
    final r = SimpleLedgerBuilder.build(
        year: 2026, expenses: const [], incomes: [inc('a', 3, 1000, '사업소득', w: false)]);
    final lines = SimpleLedgerBuilder.toCsv(r).trim().split('\n');
    expect(lines.first, contains('사업용자산 증감'));
    expect(lines.last.split(',').length, lines.first.split(',').length);
  });
}
