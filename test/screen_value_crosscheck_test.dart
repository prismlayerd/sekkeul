import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/reserve_estimator.dart';
import 'package:secul/core/tax_engine/tax_year.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';
import 'package:secul/ui/screens/home_screen.dart';

import 'support/tax_law_reference.dart';

/// **화면에 실제로 그려진 숫자**를 엔진 값과 맞춰 본다.
///
/// 지금까지의 페르소나 회귀는 엔진을 부르고, 사용자는 화면을 쓴다. 유형별 감사 7건 중
/// 5건이 "엔진은 맞고 화면이 틀림"이었다 — 그 구멍이 여기서 닫힌다.
///
/// 방식: 프로필·가계부를 심고 화면을 펌프한 뒤, 위젯 트리의 모든 `Text`를 긁어
/// **금액 문자열**을 모은다. 기대값이 그 안에 없으면 실패하고, 화면이 실제로 무엇을
/// 그렸는지 전부 출력한다.
List<String> allTexts(WidgetTester t) {
  final out = <String>[];
  for (final e in t.allWidgets) {
    if (e is Text) {
      final s = e.data ?? e.textSpan?.toPlainText();
      if (s != null && s.trim().isNotEmpty) out.add(s);
    }
  }
  return out;
}

/// 화면에 보이는 금액 문자열만 추린다 — "3,500,000원", "1,125,000" 등.
Set<String> moneyTexts(WidgetTester t) {
  final re = RegExp(r'-?\d{1,3}(,\d{3})+');
  final out = <String>{};
  for (final s in allTexts(t)) {
    for (final m in re.allMatches(s)) {
      out.add(m.group(0)!);
    }
  }
  return out;
}

String comma(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$b';
}

/// 이 파일은 **표시된 값**만 본다. 레이아웃 넘침은
/// `small_screen_overflow_test.dart`가, 알림 플러그인 미초기화
/// (`LateInitializationError` — 실기기에선 초기화돼 있어 테스트 환경에서만 난다)는
/// 어느 쪽의 관심사도 아니다. 여기서는 걸러 두고 값만 본다.
Future<void> pump(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(390, 1400); // 세로로 길게 — 스크롤 밖 요소도 그려지게
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  await t.pumpWidget(MaterialApp(home: w));
  for (int i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
    t.takeException(); // 레이아웃 넘침은 small_screen_overflow_test의 몫
  }
  t.takeException();
}

void expectShown(WidgetTester t, num value, String what) {
  final want = comma(value);
  final shown = moneyTexts(t);
  if (!shown.contains(want)) {
    // ignore: avoid_print
    print('  ✕ $what — 기대 $want원, 화면에 있는 금액: ${(shown.toList()..sort()).join(' / ')}');
  }
  expect(shown, contains(want), reason: '$what — 화면 숫자가 엔진 값과 다르다 (기대 $want원)');
}

void main() {
  final year = TaxYear.reference;
  final month = DateTime.now().month;
  // 카드 공제 연 누적은 **오늘까지**의 지출만 센다(미래 예약분을 넣으면 과대).
  // 시드 날짜가 오늘을 넘지 않게 잡는다.
  final day = DateTime.now().day;

  /// 화면은 `DateTime.now()`를 본다. 시드도 반드시 **이번 달**에 심어야
  /// "이번 달 수령액/지출" 칸이 0으로 남지 않는다.
  Future<void> seedEmployee({
    required double gross,
    required int dependents,
    required int salaryThisMonth,
    required List<(int amount, String method)> expensesThisMonth,
    List<(int month, int amount, String method)> earlier = const [],
  }) async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({
      'user_type': '직장인',
      'gross_income': gross,
      'dependents': dependents,
      'children_count_total': 0,
      'children_count_credit': 0,
    });
    await dbService.setProfileTypeValues('직장인', grossIncome: gross);
    // 3개월치 급여 — 이번 달 포함.
    for (int back = 0; back < 3; back++) {
      final d = DateTime(year, month - back, 25);
      if (d.month < 1) continue;
      await dbService.insertIncomeEntry(IncomeEntry(
          id: 'sal-${d.month}', date: d, amount: salaryThisMonth, memo: '',
          incomeType: '급여', userType: '직장인'));
    }
    for (int i = 0; i < expensesThisMonth.length; i++) {
      final (amt, pm) = expensesThisMonth[i];
      await dbService.insertExpense(ExpenseItem(
          id: 'exp-now-$i', date: DateTime(year, month, day), amount: amt,
          content: '', category: '기타', paymentMethod: pm, isBusiness: false,
          userType: '직장인'));
    }
    for (int i = 0; i < earlier.length; i++) {
      final (m, amt, pm) = earlier[i];
      if (m >= month) continue;
      await dbService.insertExpense(ExpenseItem(
          id: 'exp-$m-$i', date: DateTime(year, m, 15), amount: amt,
          content: '', category: '기타', paymentMethod: pm, isBusiness: false,
          userType: '직장인'));
    }
  }

  testWidgets('홈 — 이번 달 수령액·지출이 가계부 합계 그대로 뜬다', (t) async {
    await seedEmployee(
      gross: 50000000,
      dependents: 1,
      salaryThisMonth: 3500000,
      expensesThisMonth: [(1200000, '신용카드'), (800000, '체크+현금')],
    );
    await pump(t, const HomeScreen());

    expectShown(t, 3500000, '홈 이번 달 수령액');
    expectShown(t, 2000000, '홈 이번 달 지출(120만+80만)');
  });

  testWidgets('홈 — 카드공제 문턱이 총급여 25%로 뜬다', (t) async {
    await seedEmployee(
      gross: 60000000,
      dependents: 0,
      salaryThisMonth: 4000000,
      expensesThisMonth: [(2000000, '신용카드')],
    );
    await pump(t, const HomeScreen());

    // 조특법 §126의2 최저사용금액 = 총급여 25% = 1,500만.
    // 문턱 전이면 화면은 **남은 금액**을 말한다 — 1,500만 − 200만 = 1,300만.
    const threshold = 60000000 * 0.25;
    expectShown(t, threshold - 2000000, '홈 카드공제 문턱까지 남은 금액');
  });

  testWidgets('홈 — 환급 카운터가 엔진 절세액과 같다', (t) async {
    const gross = 50000000.0;
    const credit = 12000000.0;
    const debit = 8000000.0;
    await seedEmployee(
      gross: gross,
      dependents: 0,
      salaryThisMonth: 3500000,
      expensesThisMonth: [(12000000, '신용카드'), (8000000, '체크+현금')],
    );
    final engine = EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: gross,
      dependentsIncludingSelf: 1,
      creditCardYtd: credit,
      debitCashYtd: debit,
    );
    // 조문 검산과도 맞는지 같이 본다.
    final refCard = refCardDeduction(gross: gross, credit: credit, debitCash: debit);
    final refSaving = trunc10((refDecidedTax(gross: gross, compareStandard: false) -
            refDecidedTax(
                gross: gross, otherIncomeDeduction: refCard, compareStandard: false))
        .clamp(0.0, double.infinity));
    expect(engine.taxSaving, closeTo(refSaving, 0.01), reason: '엔진 절세액 = 조문 검산');

    await pump(t, const HomeScreen());
    expectShown(t, engine.taxSaving, '홈 환급 카운터');
  });

  testWidgets('가계부 적립 카드 — 표시 금액이 ReserveEstimator 값과 같다', (t) async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({
      'user_type': '프리랜서',
      'occupation_code': '940306',
      'prior_year_income': 30000000.0,
      'dependents': 0,
    });
    for (int back = 0; back < 3; back++) {
      final d = DateTime(year, month - back, 10);
      if (d.month < 1) continue;
      await dbService.insertIncomeEntry(IncomeEntry(
          id: 'inc-${d.month}', date: d, amount: 4000000, memo: '',
          incomeType: '사업소득', isWithheld: true, userType: '프리랜서'));
    }
    await dbService.insertExpense(ExpenseItem(
        id: 'e1', date: DateTime(year, month, day), amount: 800000, content: '',
        category: '기타', paymentMethod: '신용카드', isBusiness: true,
        userType: '프리랜서'));

    final r = await ReserveEstimator.estimateForCurrentMonth(userType: '프리랜서');
    await pump(t, const ExpenseCalendarScreen());

    // 업종·직전연도가 있으면 경비율이 확정돼 단일 값으로 뜬다.
    expect(r.minMonthlyTaxReserve.round(), r.maxMonthlyTaxReserve.round(),
        reason: '이 조건이면 적립액이 범위가 아니라 단일 값이어야 한다');
    expectShown(t, r.minMonthlyTaxReserve, '가계부 적립 카드 세금적립액');
  });
}
