import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/core/data/occupation_data.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/ui/screens/tax_annual_report_screen.dart';
import 'package:secul/ui/screens/tax_simulator_screen.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/tax_law_reference.dart';

/// 세무도구 ①진단 화면 — **화면에 뜬 세금이 조문 검산과 같은지** 본다.
///
/// 이 화면은 가계부에서 수입·경비를 자동으로 끌어오고 개월 수를 12로 고정한다
/// (연환산이 항등식이 되어 계산이 결정적이다). 그래서 시드만 정하면 정답을
/// 손으로 계산할 수 있다.
///
/// 근거: 시행령 §143③1의2 단순경비율 / 소법 §50① 인적공제 / §55① 세율
///      / §59의4⑨ 표준세액공제 7만 / §127 원천징수 3.3% / 지방세법 §92
String comma(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$b';
}

Set<String> moneyTexts(WidgetTester t) {
  final re = RegExp(r'-?\d{1,3}(,\d{3})+');
  final out = <String>{};
  for (final w in t.allWidgets) {
    if (w is Text) {
      final s = w.data ?? w.textSpan?.toPlainText();
      if (s == null) continue;
      for (final m in re.allMatches(s)) {
        out.add(m.group(0)!);
      }
    }
  }
  return out;
}

void expectShown(WidgetTester t, num value, String what) {
  final want = comma(value);
  final shown = moneyTexts(t);
  if (!shown.contains(want)) {
    // ignore: avoid_print
    print('  ✕ $what — 기대 $want, 화면의 금액: ${(shown.toList()..sort()).join(' / ')}');
  }
  expect(shown, contains(want), reason: '$what — 화면 숫자가 조문 검산과 다르다 (기대 $want)');
}

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  // ── 시드: 계산이 손으로 따라가지는 최소 조합 ──
  const occ = '940306'; // 1인미디어 — 단순경비율 기본 64.1 / 초과 49.7
  const monthlyIncome = 5000000; // × 3개월 = 1,500만
  const monthlyExpense = 1000000; // × 3개월 = 300만 (사업경비)
  const dependents = 1; // 본인 포함 2명

  Future<void> seed() async {
    final now = DateTime.now();
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({
      'user_type': '프리랜서',
      'occupation_code': occ,
      'prior_year_income': 30000000.0, // 7,500만 미만 → 간편장부대상자
      'dependents': dependents,
      // 아래는 전부 꺼 둔다 — 계산에 끼어들면 손계산이 흐려진다.
      'is_new_business': false,
      'has_multiple_businesses': false,
      'pension_enrolled': false,
      'yellow_umbrella': 0.0,
      'children_count_credit': 0,
      'newborn_count': 0,
      'disabled_dependent_count': 0,
      'has_self_disability': false,
    });
    for (int back = 0; back < 3; back++) {
      final d = DateTime(now.year, now.month - back, 1);
      await dbService.insertIncomeEntry(IncomeEntry(
          id: 'inc-$back', date: d, amount: monthlyIncome, memo: '',
          incomeType: '사업소득', isWithheld: true, userType: '프리랜서'));
      await dbService.insertExpense(ExpenseItem(
          id: 'exp-$back', date: d, amount: monthlyExpense, content: '',
          category: '기타', paymentMethod: '신용카드', isBusiness: true,
          userType: '프리랜서'));
    }
  }

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(home: TaxSimulatorScreen(userType: '프리랜서')));
    for (int i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 300));
      t.takeException();
    }
  }

  /// 결정세액(국세) — 소득금액에서 인적공제만 빼고 세율·표준세액공제 7만 적용.
  double decidedNational(double incomeAmount) {
    final base = (incomeAmount - 1500000.0 * (dependents + 1)).clamp(0.0, double.infinity);
    return trunc10((refProgressiveTax(base) - 70000).clamp(0.0, double.infinity));
  }

  testWidgets('①진단(프리랜서) — 기장 vs 추계 결정세액이 조문 검산과 일치한다', (t) async {
    await seed();
    await pump(t);

    const revenue = monthlyIncome * 3.0; // 개월 수 12 고정 → 연환산이 항등식
    const actualExpense = monthlyExpense * 3.0;
    final o = OccupationData.occupations[occ]!;

    // ── 추계(단순경비율) — 시행령 §143③1의2 ──
    final estimateExpense = revenue <= 40000000
        ? revenue * (o.simpleBaseRate / 100.0)
        : 40000000 * (o.simpleBaseRate / 100.0) +
            (revenue - 40000000) * (o.simpleExcessRate / 100.0);
    final estimateNational = decidedNational(revenue - estimateExpense);
    final estimateTotal = estimateNational + trunc10(estimateNational * 0.1);

    // ── 간편장부(가계부 실제경비) ──
    final bookNational = decidedNational(revenue - actualExpense);
    final bookTotal = bookNational + trunc10(bookNational * 0.1);

    // ignore: avoid_print
    print('수입 ${comma(revenue)} · 추계경비 ${comma(estimateExpense)} → 결정세액(지방 포함) '
        '${comma(estimateTotal)}\n    실제경비 ${comma(actualExpense)} → '
        '결정세액 ${comma(bookTotal)}');

    expectShown(t, estimateTotal, '추계 결정세액(지방세 포함)');
    expectShown(t, bookTotal, '간편장부 결정세액(지방세 포함)');

    // 경비가 적으면 추계가 유리해야 한다 — 유리한 쪽을 잘못 고르면 사용자가
    // 더 낼 쪽으로 신고하게 된다.
    expect(estimateTotal, lessThan(bookTotal),
        reason: '이 시드에서는 추계가 유리해야 한다(실제경비 300만 < 추계경비 961만)');
  });

  testWidgets('①진단(프리랜서) — 5월 예상 환급액 = 기납부 3.3% − 결정세액', (t) async {
    await seed();
    await pump(t);

    const revenue = monthlyIncome * 3.0;
    final o = OccupationData.occupations[occ]!;
    final estimateExpense = revenue * (o.simpleBaseRate / 100.0);
    final estimateNational = decidedNational(revenue - estimateExpense);
    final estimateLocal = trunc10(estimateNational * 0.1);

    // 원천징수 3.3% — 소법 §127(국세 3%) + 지방세법 §103의13(지방 0.3%).
    // 국세·지방세를 각각 10원 절사한다.
    final paidNational = trunc10(revenue * 0.03);
    final paidLocal = trunc10(revenue * 0.003);
    final refund = (paidNational + paidLocal) - (estimateNational + estimateLocal);

    // ignore: avoid_print
    print('기납부 ${comma(paidNational + paidLocal)} − 결정세액 '
        '${comma(estimateNational + estimateLocal)} = 환급 ${comma(refund)}');

    expect(refund, greaterThan(0), reason: '이 시드는 환급이 나와야 한다');
    expectShown(t, refund, '5월 예상 환급액');
  });

  // ── 직장인 경로 ─────────────────────────────────────────────────
  // 같은 화면이지만 build()의 최상위 if(_isFreelancer)로 갈라져 완전히 다른 코드다.
  // 직장인 진단은 **연말정산에서 놓친 공제**만 센다 — 카드공제처럼 회사가 이미
  // 반영했을 항목은 여기서 다시 세지 않는다.
  Future<void> seedEmployee({
    required double gross,
    required double monthlyRent,
  }) async {
    final now = DateTime.now();
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({
      'user_type': '직장인',
      'gross_income': gross,
      'dependents': 0,
      'is_monthly_rent': monthlyRent > 0,
      'owns_house': false,
      'monthly_rent': monthlyRent,
      'children_count_total': 0,
      'children_count_credit': 0,
      'newborn_count': 0,
    });
    for (int b = 0; b < 3; b++) {
      final d = DateTime(now.year, now.month - b, 1);
      await dbService.insertIncomeEntry(IncomeEntry(
          id: 'i$b', date: d, amount: 3500000, memo: '',
          incomeType: '급여', userType: '직장인'));
      await dbService.insertExpense(ExpenseItem(
          id: 'c$b', date: d, amount: 4000000, content: '', category: '기타',
          paymentMethod: '신용카드', isBusiness: false, userType: '직장인'));
    }
  }

  // 같은 테스트에서 두 번 펌프할 때는 **키를 바꿔야** State가 새로 만들어진다.
  // 안 그러면 initState가 다시 안 돌아 이전 프로필이 그대로 남는다.
  int pumpSeq = 0;
  Future<void> pumpEmployee(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 4000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        home: TaxSimulatorScreen(
            key: ValueKey('sim-${pumpSeq++}'), userType: '직장인')));
    for (int i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 300));
      t.takeException();
    }
  }

  /// 조특법 §95의2 월세 세액공제 — 총급여 5,500만 이하 17% / 5,500만~8,000만 15%,
  /// 연 월세액 1,000만원 한도, 무주택 세대주.
  double refRentCredit({required double gross, required double monthlyRent}) {
    if (gross > 80000000) return 0;
    final annual = monthlyRent * 12;
    final capped = annual > 10000000 ? 10000000.0 : annual;
    return capped * (gross <= 55000000 ? 0.17 : 0.15);
  }

  testWidgets('①진단(직장인) — 월세 세액공제가 조문 공제율·한도대로 뜬다', (t) async {
    const gross = 50000000.0;
    const rent = 600000.0;
    await seedEmployee(gross: gross, monthlyRent: rent);
    await pumpEmployee(t);

    final credit = refRentCredit(gross: gross, monthlyRent: rent);
    // ignore: avoid_print
    print('총급여 ${comma(gross)} · 월세 ${comma(rent)}/월 → 세액공제 ${comma(credit)} (17% 구간)');
    expect(credit, 1224000.0, reason: '720만 × 17% = 122만 4천');
    expectShown(t, credit, '직장인 진단 월세 세액공제');
  });

  testWidgets('①진단(직장인) — 총급여 5,500만 경계에서 공제율이 17%→15%로 꺾인다', (t) async {
    const rent = 600000.0;
    // 5,500만 이하 = 17%
    await seedEmployee(gross: 55000000, monthlyRent: rent);
    await pumpEmployee(t);
    expectShown(t, refRentCredit(gross: 55000000, monthlyRent: rent),
        '총급여 5,500만 월세 세액공제(17%)');

    // 1원만 넘어도 15%
    await seedEmployee(gross: 55000001, monthlyRent: rent);
    await pumpEmployee(t);
    expectShown(t, refRentCredit(gross: 55000001, monthlyRent: rent),
        '총급여 5,500만+1원 월세 세액공제(15%)');
  });

  testWidgets('①진단(직장인) — 총급여 8,000만 초과는 월세 공제 대상이 아니다', (t) async {
    await seedEmployee(gross: 85000000, monthlyRent: 600000);
    await pumpEmployee(t);
    // 대상이 아니면 그 금액이 화면 어디에도 있으면 안 된다.
    final wouldBe = comma(10000000 * 0.15); // 한도까지 받았다면 나올 숫자
    expect(moneyTexts(t), isNot(contains(wouldBe)),
        reason: '총급여 8,000만 초과에 월세 공제가 잡혔다 (조특법 §95의2 소득요건)');
  });

  testWidgets('①진단(직장인) — 추가 환급은 결정세액을 넘지 않는다', (t) async {
    // 저소득 + 큰 월세 — 공제는 크지만 낼 세금이 없는 사람.
    const gross = 20000000.0;
    await seedEmployee(gross: gross, monthlyRent: 800000);
    await pumpEmployee(t);

    final cap = EmployeeTaxCalculator.estimateDecidedTaxBeforeCredits(
      grossIncome: gross,
      dependentsIncludingSelf: 1,
    );
    final refCap = refDecidedTax(gross: gross);
    expect(cap, closeTo(refCap, 0.01), reason: '결정세액 상한이 조문 검산과 다르다');

    // 월세 공제만으로 163만원인데 결정세액은 그보다 훨씬 작다.
    // 공제액 자체를 항목으로 보여주는 건 사실이라 맞다. 상한이 걸려야 하는 건
    // **최종 환급액**이다.
    final rentCredit = refRentCredit(gross: gross, monthlyRent: 800000);
    // 화면은 카드공제도 함께 넘긴다 — 카드공제가 과세표준을 낮추면 남은 세금(상한)도
    // 그만큼 줄어든다. 시드의 신용카드 누적 1,200만원을 같은 조문 규칙으로 계산해 넣는다.
    final cardDeduction =
        refCardDeduction(gross: gross, credit: 12000000, debitCash: 0);
    final est = EmployeeTaxCalculator.estimateEmployeeRefund(
      grossIncome: gross,
      dependentsIncludingSelf: 1,
      cardDeduction: cardDeduction,
      rentCredit: rentCredit,
    );
    // ignore: avoid_print
    print('총급여 ${comma(gross)} — 월세공제 ${comma(rentCredit)} · 결정세액 상한 '
        '${comma(cap)} → 환급 ${comma(est.refund)}');

    expect(rentCredit, greaterThan(cap), reason: '이 시드는 상한이 걸리는 조건이어야 한다');
    expect(est.isCapped, isTrue, reason: '상한이 걸렸다고 표시돼야 한다');
    // 환급액은 결정세액을 넘을 수 없다(10원 미만 절사 — 국고금관리법 §47).
    expect(est.refund, lessThanOrEqualTo(trunc10(cap) + 0.01),
        reason: '환급액이 결정세액을 넘는다 — 결정세액 0원 법칙 위반');
    expect(est.refund, lessThan(rentCredit),
        reason: '공제액보다 환급이 크면 안 된다');
    // 화면도 상한이 걸린 값을 그린다.
    expectShown(t, est.refund, '직장인 진단 5월 추가 환급(상한 적용)');
  });

  // ── ①진단 → ②가상신고서 → ③홈택스 파이프라인 ─────────────────────
  // ②는 ①이 저장한 draft를 그대로 쓰고, ③도 같은 draft를 읽는다. 그래서
  // 세 화면이 **같은 숫자를 말하는지**가 이 파이프라인의 유일한 계약이다.
  testWidgets('①→②→③ — 가상신고서 항목이 서로 맞아떨어지고 ③에도 같은 값이 간다', (t) async {
    await seed();
    await pump(t);

    // ①에서 '가상 신고서로 넘어가기'를 누른다 → draft 저장 + ② 화면 진입
    final cta = find.text('가상 신고서로 넘어가기');
    expect(cta, findsOneWidget, reason: '①진단에 ②로 가는 CTA가 있어야 한다');
    await t.tap(cta);
    for (int i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 300));
      t.takeException();
    }

    final draft = await dbService.getReportDraft('프리랜서');
    expect(draft, isNotNull, reason: '②로 넘어갈 때 draft가 저장돼야 ③이 채워진다');

    final items = (draft!['items'] as List).cast<Map<String, dynamic>>();
    double amountOf(String contains) => (items.firstWhere(
            (m) => (m['title'] as String).contains(contains))['amount'] as num)
        .toDouble();

    final revenue = amountOf('총수입금액');
    final expense = amountOf('필요경비');
    final deduction = amountOf('소득공제');
    final taxBase = amountOf('과세표준');
    final decided = amountOf('결정세액');
    final paid = amountOf('기납부세액');

    // ignore: avoid_print
    print('신고서 — 수입 ${comma(revenue)} − 경비 ${comma(expense)} − 공제 ${comma(deduction)}'
        ' = 과세표준 ${comma(taxBase)}\n    결정세액 ${comma(decided)}'
        ' · 기납부 ${comma(paid)} → ${comma(draft['final_amount'] as num)}');

    // ── 신고서 안에서 수식이 닫히는가 ──
    // 사용자는 이 표를 보고 홈택스에 그대로 옮겨 적는다. 줄끼리 안 맞으면
    // 어느 줄을 믿어야 할지 알 수 없다.
    expect(taxBase, closeTo((revenue - expense - deduction).clamp(0.0, double.infinity), 1),
        reason: '과세표준 = 총수입 − 필요경비 − 소득공제');
    expect((draft['final_amount'] as num).toDouble(), closeTo(paid - decided, 1),
        reason: '환급/납부 = 기납부세액 − 결정세액');

    // ── 조문 검산과도 맞는가 ──
    const rev = monthlyIncome * 3.0;
    final o = OccupationData.occupations[occ]!;
    final refExpense = rev * (o.simpleBaseRate / 100.0);
    final refNational = decidedNational(rev - refExpense);
    final refDecided = refNational + trunc10(refNational * 0.1);
    expect(decided, closeTo(refDecided, 0.01), reason: '신고서 결정세액이 조문 검산과 다르다');

    // ── ③ 홈택스 가이드가 같은 draft를 읽는가 ──
    await t.pumpWidget(MaterialApp(
        key: const ValueKey('report'),
        home: const TaxAnnualReportScreen(userType: '프리랜서')));
    for (int i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 300));
      t.takeException();
    }
    expectShown(t, refDecided, '③홈택스 가이드의 결정세액');
  });
}
