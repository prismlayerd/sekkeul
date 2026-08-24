import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';

/// **유형을 바꿔도 돈이 사라지거나 겹치지 않는다.**
///
/// 유형을 갈아타면 그동안 적은 가계부를 새 유형으로 옮겨 올 수 있다. 지출은
/// 개인 소비라 전부 따라오고, 수입은 **새 유형이 다루는 소득 유형만** 온다 —
/// 직장인으로 가면서 사업소득을 끌고 가면 없는 소득이 생긴다.
///
/// 옮겨지지 않은 수입은 **원래 유형에 그대로 남는다.** 지워지는 게 아니다.
/// 다시 그 유형으로 돌아가면 있어야 한다.
void main() {
  ExpenseItem exp(String id, String userType, int amount) => ExpenseItem(
        id: id,
        date: DateTime(2026, 8, 10),
        amount: amount,
        content: '',
        category: '기타',
        paymentMethod: '신용카드',
        userType: userType,
      );

  IncomeEntry inc(String id, String userType, String type, int amount) => IncomeEntry(
        id: id,
        date: DateTime(2026, 8, 10),
        amount: amount,
        memo: '',
        incomeType: type,
        userType: userType,
      );

  setUp(() async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
  });

  test('지출은 한 건도 빠짐없이 따라온다', () async {
    for (final e in [
      exp('e1', '프리랜서', 12000),
      exp('e2', '프리랜서', 3400),
      exp('e3', '직장인', 9999), // 원래 대상 유형에 있던 것 — 건드리면 안 된다
    ]) {
      await dbService.insertExpense(e);
    }

    await dbService.moveLedgerRecords(from: '프리랜서', to: '직장인');

    final moved = await dbService.getExpenses(userType: '직장인');
    expect(moved.length, 3);
    expect(moved.fold<int>(0, (s, e) => s + e.amount), 12000 + 3400 + 9999,
        reason: '옮기면서 금액이 바뀌었다');
    expect(await dbService.getExpenses(userType: '프리랜서'), isEmpty);
  });

  test('새 유형이 못 다루는 수입은 옮기지 않고 원래 자리에 둔다', () async {
    for (final e in [
      inc('i1', '직장인', '급여', 3000000),
      inc('i2', '직장인', '사업소득', 1000000),
    ]) {
      await dbService.insertIncomeEntry(e);
    }

    // 프리랜서는 급여를 다루지 않는다. (직장인은 2026-08-24부터 사업소득을
    // 받는다 — 부업이 생긴 걸 앱이 알아야 신고 의무를 알릴 수 있다.)
    await dbService.moveLedgerRecords(from: '직장인', to: '프리랜서');

    final all = await dbService.getIncomeEntriesForMonth(2026, 8);
    expect(all.length, 2, reason: '수입이 사라지거나 복제됐다');

    final byId = {for (final e in all) e.id: e};
    expect(byId['i1']!.userType, '직장인', reason: '급여가 프리랜서에게 넘어갔다');
    expect(byId['i2']!.userType, '프리랜서', reason: '사업소득은 프리랜서도 다룬다');
  });

  test('미리보기 숫자가 실제로 옮겨지는 수와 같다', () async {
    for (final e in [exp('e1', 'N잡러', 1), exp('e2', 'N잡러', 2)]) {
      await dbService.insertExpense(e);
    }
    for (final e in [
      inc('i1', 'N잡러', '사업소득', 1),
      inc('i2', 'N잡러', '급여', 2),
      inc('i3', 'N잡러', '기타소득', 3),
    ]) {
      await dbService.insertIncomeEntry(e);
    }

    final preview = await dbService.previewLedgerMove(from: 'N잡러', to: '직장인');
    await dbService.moveLedgerRecords(from: 'N잡러', to: '직장인');

    final movedExp = await dbService.getExpenses(userType: '직장인');
    final movedInc = (await dbService.getIncomeEntriesForMonth(2026, 8))
        .where((e) => e.userType == '직장인')
        .length;
    final left = (await dbService.getIncomeEntriesForMonth(2026, 8))
        .where((e) => e.userType == 'N잡러')
        .length;

    expect(preview.expenseCount, movedExp.length);
    expect(preview.movableIncomeCount, movedInc,
        reason: '옮긴다고 알려 준 수와 실제가 다르면 사용자가 잃은 줄 안다');
    expect(preview.orphanIncomeCount, left);
    expect(preview.movableIncomeCount + preview.orphanIncomeCount, 3);
  });

  test('옛 기록 기타도 기타소득으로 쳐서 옮긴다', () async {
    await dbService.insertIncomeEntry(inc('i1', '직장인', '기타', 5000));
    await dbService.moveLedgerRecords(from: '직장인', to: '프리랜서');

    final all = await dbService.getIncomeEntriesForMonth(2026, 8);
    expect(all.single.userType, '프리랜서',
        reason: "'기타'는 '기타소득'의 옛 이름이다 — 남겨 두면 유형을 옮긴 뒤 안 보인다");
  });
}
