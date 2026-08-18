import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';

/// **전통시장·대중교통·도서공연은 공제율이 다르다.**
///
/// 조특법 §126의2는 이 셋을 신용카드등사용금액에서 **빼고** 따로 센다 —
/// 전통시장 40% · 대중교통 40% · 도서공연 30%, 신용카드는 15%다.
///
/// 엔진은 처음부터 이 셈을 알고 있었는데 부르는 쪽이 0을 박아 넘겨서 그 능력이
/// 통째로 죽어 있었다. 전통시장에서 쓴 돈이 15%로 계산됐다는 뜻이다.
void main() {
  test('전통시장 40%가 신용카드 15%보다 많이 공제된다', () {
    const salary = 40000000.0; // 문턱 1,000만
    const spend = 5000000.0;

    final asCredit = EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: salary,
      creditCardYtd: 10000000 + spend,
      debitCashYtd: 0,
    );
    final asMarket = EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: salary,
      creditCardYtd: 10000000,
      debitCashYtd: 0,
      traditionalMarket: spend,
    );

    expect(asMarket.totalEligibleSpend, asCredit.totalEligibleSpend,
        reason: '문턱 판정에는 다섯 갈래가 다 들어간다 — 총액은 같아야 한다');
    expect(asMarket.deduction, greaterThan(asCredit.deduction),
        reason: '전통시장 40%가 신용카드 15%로 계산되고 있다');
  });

  test('세 갈래를 안 주면 예전과 같은 값이다', () {
    // 기본값이 0이라 기존 호출부는 그대로 돈다.
    final a = EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: 40000000, creditCardYtd: 15000000, debitCashYtd: 0);
    final b = EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: 40000000, creditCardYtd: 15000000, debitCashYtd: 0,
      traditionalMarket: 0, publicTransport: 0, cultureExpense: 0);
    expect(a.deduction, b.deduction);
  });

  test('공제 구분이 저장되고 다시 읽힌다', () async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.insertExpense(ExpenseItem(
      id: 'm1',
      date: DateTime.now(),
      amount: 32000,
      content: '',
      category: '마트',
      paymentMethod: '신용카드',
      deductionType: '전통시장',
      userType: '직장인',
    ));
    final back = (await dbService.getExpenses()).single;
    expect(back.deductionType, '전통시장',
        reason: '저장은 됐는데 못 읽으면 공제가 조용히 사라진다');
  });

  test('표식이 없으면 null이다 — 지난 기록을 짐작하지 않는다', () async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.insertExpense(ExpenseItem(
      id: 'x1',
      date: DateTime.now(),
      amount: 9000,
      content: '',
      category: '교통',
      paymentMethod: '신용카드',
      userType: '직장인',
    ));
    // 카테고리가 '교통'이어도 대중교통 공제로 세면 안 된다 —
    // 택시·주차가 섞여 있고 그건 공제 대상이 아니다.
    expect((await dbService.getExpenses()).single.deductionType, isNull);
  });
}
