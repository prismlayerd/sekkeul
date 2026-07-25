import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/core/data/ledger_profile.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/reserve_estimator.dart';
import 'package:secul/core/tax_engine/combined_tax.dart';
import 'package:secul/core/tax_engine/simple_ledger_builder.dart';

/// N잡러·직장인 페르소나 회귀.
///
/// N잡러는 프리랜서와 직장인의 기능을 둘 다 켠 유형이라, 어느 쪽 엔진을 타는지가
/// 갈린다. 이 파일은 그 경계(적립카드=사업 쪽, 카드공제=근로 쪽)가 유지되는지와
/// 각 숫자가 올바른 소득 기준을 쓰는지를 고정한다.
///
/// 모든 페르소나는 수입·지출 각각 3개월 이상(이번 달 포함).
class P {
  final String name;
  final String userType;
  final String occ;
  final int priorYear;
  final bool newBiz;
  final int dependents;
  /// 예상 연봉(프로필). 0이면 미설정 — 홈이 이번 달 기록을 연환산해 대체한다.
  final double grossIncome;
  final String residence;
  final double monthlyRent;
  final double yellowUmbrella;
  final bool employment;
  final bool industrial;

  /// (월, 입력액, 소득종류, 원천징수여부)
  final List<(int, int, String, bool)> incomes;

  /// (월, 금액, 결제수단, 사업경비여부)
  final List<(int, int, String, bool)> expenses;

  const P(this.name, {
    required this.userType,
    this.occ = '',
    this.priorYear = 0,
    this.newBiz = false,
    this.dependents = 0,
    this.grossIncome = 0,
    this.residence = '전세',
    this.monthlyRent = 0,
    this.yellowUmbrella = 0,
    this.employment = false,
    this.industrial = false,
    required this.incomes,
    required this.expenses,
  });
}

const njobPersonas = <P>[
  // ① 표준 — 급여 + 부업 소액. 부업 소득금액이 2,000만 이하라 건보 추가부과 없음.
  P('① 급여+부업 소액', userType: 'N잡러', occ: '940306', priorYear: 20000000,
    grossIncome: 48000000,
    incomes: [(1, 4000000, '급여', false), (1, 800000, '사업소득', true),
              (4, 4000000, '급여', false), (4, 900000, '사업소득', true),
              (7, 4000000, '급여', false), (7, 700000, '사업소득', true)],
    expenses: [(2, 1500000, '신용카드', false), (5, 1200000, '체크+현금', false),
               (7, 1300000, '신용카드', false), (7, 400000, '신용카드', true)]),

  // ② 부업 고소득 — 소득금액 2,000만 초과 → 건보 소득월액보험료 추가 부과
  P('② 부업 고소득(건보 추가)', userType: 'N잡러', occ: '940306', priorYear: 40000000,
    grossIncome: 60000000,
    incomes: [(1, 5000000, '급여', false), (1, 12000000, '사업소득', true),
              (4, 5000000, '급여', false), (4, 15000000, '사업소득', true),
              (7, 5000000, '급여', false), (7, 13000000, '사업소득', true)],
    expenses: [(3, 3000000, '신용카드', true), (5, 3000000, '체크+현금', true),
               (7, 2000000, '신용카드', false)]),

  // ③ 예상연봉 미설정 — 카드공제 문턱이 어느 소득을 기준으로 잡히는지 드러난다
  P('③ 예상연봉 미설정', userType: 'N잡러', occ: '940306', priorYear: 20000000,
    grossIncome: 0,
    incomes: [(2, 3000000, '급여', false), (2, 5000000, '사업소득', true),
              (5, 3000000, '급여', false), (5, 5000000, '사업소득', true),
              (7, 3000000, '급여', false), (7, 5000000, '사업소득', true)],
    expenses: [(3, 2000000, '신용카드', false), (6, 2000000, '체크+현금', false),
               (7, 2000000, '신용카드', false)]),

  // ④ 업종 미설정 — 경비율을 몰라 적립 추정 불가
  P('④ 업종 미설정', userType: 'N잡러', grossIncome: 45000000,
    incomes: [(2, 4000000, '급여', false), (2, 2000000, '사업소득', true),
              (5, 4000000, '급여', false), (5, 2000000, '사업소득', true),
              (7, 4000000, '급여', false), (7, 2000000, '사업소득', true)],
    expenses: [(3, 1000000, '신용카드', false), (5, 1000000, '체크+현금', false),
               (7, 1000000, '신용카드', true)]),

  // ⑤ 직전연도 미입력 — 경비율 미정이라 적립이 범위로 나온다
  P('⑤ 직전연도 미입력', userType: 'N잡러', occ: '940306', grossIncome: 45000000,
    incomes: [(2, 4000000, '급여', false), (2, 2000000, '사업소득', true),
              (5, 4000000, '급여', false), (5, 2000000, '사업소득', true),
              (7, 4000000, '급여', false), (7, 2000000, '사업소득', true)],
    expenses: [(3, 1000000, '신용카드', false), (5, 1000000, '체크+현금', false),
               (7, 1000000, '신용카드', true)]),

  // ⑥ 복식부기 의무자 + 무기장가산세 대상(직전연도 4,800만 이상)
  P('⑥ 복식부기·가산세', userType: 'N잡러', occ: '940306', priorYear: 90000000,
    grossIncome: 50000000,
    incomes: [(1, 4200000, '급여', false), (1, 10000000, '사업소득', true),
              (4, 4200000, '급여', false), (4, 12000000, '사업소득', true),
              (7, 4200000, '급여', false), (7, 10000000, '사업소득', true)],
    expenses: [(2, 4000000, '신용카드', true), (5, 4000000, '체크+현금', true),
               (7, 3000000, '신용카드', false)]),

  // ⑦ 기타소득 혼재(8.8% 원천징수)
  P('⑦ 기타소득 혼재', userType: 'N잡러', occ: '940306', priorYear: 20000000,
    grossIncome: 45000000,
    incomes: [(2, 3800000, '급여', false), (2, 3000000, '기타소득', true),
              (5, 3800000, '급여', false), (5, 3000000, '사업소득', true),
              (7, 3800000, '급여', false), (7, 2000000, '기타소득', true)],
    expenses: [(3, 1500000, '신용카드', false), (5, 1500000, '체크+현금', false),
               (7, 1000000, '신용카드', true)]),

  // ⑧ 카드 문턱 돌파 — 근로소득 기준 25%를 넘겨 환급 카운터가 자란다
  P('⑧ 카드 문턱 돌파', userType: 'N잡러', occ: '940306', priorYear: 20000000,
    grossIncome: 40000000,
    incomes: [(1, 3300000, '급여', false), (1, 1000000, '사업소득', true),
              (4, 3300000, '급여', false), (4, 1000000, '사업소득', true),
              (7, 3300000, '급여', false), (7, 1000000, '사업소득', true)],
    expenses: [(2, 6000000, '신용카드', false), (4, 5000000, '체크+현금', false),
               (7, 4000000, '체크+현금', false)]),

  // ⑨ 부양가족3 + 월세 + 노란우산 — 공제 배선 확인
  P('⑨ 부양3·월세·노란우산', userType: 'N잡러', occ: '940306', priorYear: 20000000,
    grossIncome: 55000000, dependents: 3, residence: '월세', monthlyRent: 700000,
    yellowUmbrella: 3000000,
    incomes: [(1, 4500000, '급여', false), (1, 2000000, '사업소득', true),
              (4, 4500000, '급여', false), (4, 2000000, '사업소득', true),
              (7, 4500000, '급여', false), (7, 2000000, '사업소득', true)],
    expenses: [(3, 2000000, '신용카드', false), (6, 2000000, '체크+현금', false),
               (7, 1500000, '신용카드', true)]),

  // ⑩ 고용·산재 임의가입 프리랜서형 N잡러
  P('⑩ 고용·산재 가입', userType: 'N잡러', occ: '940306', priorYear: 30000000,
    grossIncome: 42000000, employment: true, industrial: true,
    incomes: [(2, 3500000, '급여', false), (2, 4000000, '사업소득', true),
              (5, 3500000, '급여', false), (5, 4000000, '사업소득', true),
              (7, 3500000, '급여', false), (7, 4000000, '사업소득', true)],
    expenses: [(3, 2000000, '신용카드', true), (6, 1500000, '체크+현금', true),
               (7, 1500000, '신용카드', false)]),
];

const employeePersonas = <P>[
  // ① 문턱 미달 — 카드공제 0
  P('① 문턱 미달', userType: '직장인', grossIncome: 50000000,
    incomes: [(1, 3500000, '급여', false), (4, 3500000, '급여', false),
              (7, 3500000, '급여', false)],
    expenses: [(2, 2000000, '신용카드', false), (5, 2000000, '체크+현금', false),
               (7, 2000000, '신용카드', false)]),

  // ② 문턱 돌파 — 환급 카운터가 자라기 시작
  P('② 문턱 돌파', userType: '직장인', grossIncome: 50000000,
    incomes: [(1, 3500000, '급여', false), (4, 3500000, '급여', false),
              (7, 3500000, '급여', false)],
    expenses: [(2, 8000000, '신용카드', false), (5, 6000000, '체크+현금', false),
               (7, 4000000, '체크+현금', false)]),

  // ③ 한도 도달 — 더 써도 공제가 안 늘어난다(총급여 7천 이하 → 한도 300만)
  P('③ 한도 도달', userType: '직장인', grossIncome: 50000000,
    incomes: [(1, 3500000, '급여', false), (4, 3500000, '급여', false),
              (7, 3500000, '급여', false)],
    expenses: [(2, 20000000, '신용카드', false), (5, 20000000, '체크+현금', false),
               (7, 10000000, '체크+현금', false)]),

  // ④ 고소득 — 총급여 7천 초과라 기본한도가 250만으로 줄어든다
  P('④ 고소득(한도 250만)', userType: '직장인', grossIncome: 90000000,
    incomes: [(1, 6000000, '급여', false), (4, 6000000, '급여', false),
              (7, 6000000, '급여', false)],
    expenses: [(2, 20000000, '신용카드', false), (5, 20000000, '체크+현금', false),
               (7, 15000000, '체크+현금', false)]),

  // ⑤ 예상연봉 미설정 — 이번 달 급여 연환산으로 대체된다
  P('⑤ 예상연봉 미설정', userType: '직장인', grossIncome: 0,
    incomes: [(2, 3000000, '급여', false), (5, 3000000, '급여', false),
              (7, 3000000, '급여', false)],
    expenses: [(3, 3000000, '신용카드', false), (6, 3000000, '체크+현금', false),
               (7, 3000000, '신용카드', false)]),

  // ⑥ 부양가족3 — 인적공제로 결정세액이 줄어 환급 상한도 낮아진다
  P('⑥ 부양가족3', userType: '직장인', grossIncome: 50000000, dependents: 3,
    incomes: [(1, 3500000, '급여', false), (4, 3500000, '급여', false),
              (7, 3500000, '급여', false)],
    expenses: [(2, 8000000, '신용카드', false), (5, 6000000, '체크+현금', false),
               (7, 4000000, '체크+현금', false)]),

  // ⑦ 저소득 — 결정세액이 0이라 공제해도 돌려받을 게 없다
  P('⑦ 저소득', userType: '직장인', grossIncome: 18000000,
    incomes: [(1, 1500000, '급여', false), (4, 1500000, '급여', false),
              (7, 1500000, '급여', false)],
    expenses: [(2, 3000000, '신용카드', false), (5, 3000000, '체크+현금', false),
               (7, 2000000, '체크+현금', false)]),

  // ⑧ '기타' 결제수단만 — 현금영수증 없는 지출은 공제 대상 밖
  P('⑧ 기타 결제수단만', userType: '직장인', grossIncome: 50000000,
    incomes: [(1, 3500000, '급여', false), (4, 3500000, '급여', false),
              (7, 3500000, '급여', false)],
    expenses: [(2, 8000000, '기타', false), (5, 8000000, '기타', false),
               (7, 5000000, '기타', false)]),
];

String won(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}${b.toString()}원';
}

void main() {
  final now = DateTime.now();

  /// 프로필·기록을 심고 화면이 쓰는 값들을 그대로 재현한다.
  Future<Map<String, dynamic>> seed(P p) async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await dbService.saveProfile({
      'user_type': p.userType,
      'occupation_code': p.occ,
      'prior_year_income': p.priorYear.toDouble(),
      'is_new_business': p.newBiz,
      'dependents': p.dependents,
      'gross_income': p.grossIncome,
      'is_monthly_rent': p.residence == '월세',
      'owns_house': p.residence == '자가',
      'monthly_rent': p.monthlyRent,
      'yellow_umbrella': p.yellowUmbrella,
      'employment_enrolled': p.employment,
      'industrial_accident_enrolled': p.industrial,
    });

    final incomes = p.incomes.where((e) => e.$1 <= now.month).toList();
    final expenses = p.expenses.where((e) => e.$1 <= now.month).toList();
    for (final (m, amt, type, wh) in incomes) {
      await dbService.insertIncomeEntry(IncomeEntry(
        id: 'i$m-$amt-$type', date: DateTime(now.year, m, 10),
        amount: amt, memo: '', incomeType: type, isWithheld: wh, userType: p.userType));
    }
    for (final (m, amt, pm, biz) in expenses) {
      await dbService.insertExpense(ExpenseItem(
        id: 'e$m-$amt-$pm-$biz', date: DateTime(now.year, m, 15),
        amount: amt, content: '', category: '기타', paymentMethod: pm,
        isBusiness: biz, userType: p.userType));
    }

    // home_screen._loadCurrentMonthIncome / _loadMonthlyExpenses와 같은 규칙
    double labor = 0, other = 0, mExpense = 0;
    for (final (m, amt, type, wh) in incomes) {
      if (m != now.month) continue;
      if (type == '급여') {
        labor += amt;
      } else {
        other += amt;
      }
      if (wh) {} // 세전 환산은 헤드라인 토글용이라 여기선 생략
    }
    for (final (m, amt, _, __) in expenses) {
      if (m == now.month) mExpense += amt;
    }
    // 카드공제는 연 누적. '기타' 결제수단은 현금영수증 없는 지출로 보아 제외.
    double creditYtd = 0, debitYtd = 0;
    for (final (_, amt, pm, __) in expenses) {
      if (pm == '신용카드') creditYtd += amt;
      if (pm == '체크+현금') debitYtd += amt;
    }

    return {
      'labor': labor, 'other': other, 'monthlyIncome': labor + other,
      'mExpense': mExpense, 'creditYtd': creditYtd, 'debitYtd': debitYtd,
      'incomeMonths': incomes.map((e) => e.$1).toSet(),
      'expenseMonths': expenses.map((e) => e.$1).toSet(),
    };
  }

  /// home_status_section이 카드 환급 카운터를 계산하는 방식 그대로.
  /// 문턱은 총급여(근로소득) 기준 — N잡러는 사업소득을 빼고 근로소득만 연환산한다.
  CreditCardRefundEstimate cardRefund(P p, Map<String, dynamic> s) {
    final fallbackMonthly =
        p.userType == 'N잡러' ? (s['labor'] as double) : (s['monthlyIncome'] as double);
    final annualSalary = p.grossIncome > 0 ? p.grossIncome : fallbackMonthly * 12;
    return EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: annualSalary,
      dependentsIncludingSelf: 1 + p.dependents,
      creditCardYtd: s['creditYtd'] as double,
      debitCashYtd: s['debitYtd'] as double,
    );
  }

  test('N잡러 10인 — 적립카드(사업) + 카드공제(근로)', () async {
    for (final p in njobPersonas) {
      final s = await seed(p);
      final r = await ReserveEstimator.estimateForCurrentMonth(userType: p.userType);
      final cc = cardRefund(p, s);
      final lp = LedgerProfile.of(p.userType);

      // ignore: avoid_print
      print('\n═══ ${p.name} ═══');
      // ignore: avoid_print
      print(' [내 정보]  업종=${p.occ.isEmpty ? "미설정" : p.occ}  직전연도=${won(p.priorYear)}'
          '  예상연봉=${p.grossIncome > 0 ? won(p.grossIncome) : "미설정"}  부양=${p.dependents}명'
          '  거주=${p.residence}  고용/산재=${p.employment}/${p.industrial}');
      // ignore: avoid_print
      print(' [수익지출카드] 이번 달 근로소득 ${won(s['labor'])}   다른소득 ${won(s['other'])}'
          '   지출 ${won(s['mExpense'])}');
      // ignore: avoid_print
      print(' [적립카드]   세금적립/월='
          '${r.hasOccupationCode ? (r.minMonthlyTaxReserve.round() == r.maxMonthlyTaxReserve.round() ? won(r.minMonthlyTaxReserve) : "${won(r.minMonthlyTaxReserve)}~${won(r.maxMonthlyTaxReserve)}") : "업종 설정 필요"}'
          '   보험적립/월=${won(r.insuranceReserve)}'
          '   무기장가산세=${r.includesNoBookkeepingPenalty ? "포함" : "면제"}');
      // 화면은 절세액만 합산 엔진 값으로 갈아끼운다(문턱·공제액·한도는 총급여 기준).
      final shownSaving = r.cardDeductionTaxSaving ?? cc.taxSaving;
      // ignore: avoid_print
      print(' [카드공제]   문턱=${won(cc.threshold)}  누적사용=${won(cc.totalEligibleSpend)}'
          '  공제=${won(cc.deduction)}');
      // ignore: avoid_print
      print('              환급카운터=${won(shownSaving)}'
          ' (근로소득만 보면 ${won(cc.taxSaving)})${cc.isCapped ? " · 한도도달" : ""}');
      // ignore: avoid_print
      print(' [환급블록]   ${r.refundProgress == null ? "없음(N잡러는 대상 아님)" : "있음 ← 예상과 다름!"}');

      // ── 세무도구: 가계부 → 간편장부 (bookkeeping_guide_screen과 같은 경로) ──
      final ledgerIncomes = <IncomeEntry>[];
      for (int m = 1; m <= 12; m++) {
        ledgerIncomes.addAll(
            await dbService.getIncomeEntriesForMonth(now.year, m, userType: p.userType));
      }
      final ledger = SimpleLedgerBuilder.build(
        year: now.year,
        incomes: ledgerIncomes,
        expenses: await dbService.getExpenses(userType: p.userType),
      );
      final usableIncomes = p.incomes.where((e) => e.$1 <= now.month).toList();
      final usableExpenses = p.expenses.where((e) => e.$1 <= now.month).toList();
      final salaryRows = usableIncomes.where((e) => e.$3 == '급여').length;
      final bizExpenseRows = usableExpenses.where((e) => e.$4).length;
      // ignore: avoid_print
      print(' [세무도구]   장부 ${ledger.rows.length}줄  수입계=${won(ledger.totalIncome)}'
          '  비용계=${won(ledger.totalExpense)}'
          '   (급여 $salaryRows건은 근로소득이라 제외)');

      // N잡러 전용 불변식 — 급여가 사업 장부에 실리면 사업소득이 부풀어
      // 무기장가산세·경비율 판정이 전부 어긋난다.
      expect(ledger.rows.length,
          usableIncomes.length - salaryRows + bizExpenseRows,
          reason: '${p.name}: 장부 줄 수 = (수입 - 급여) + 사업경비');
      expect(ledger.totalExpense,
          usableExpenses.where((e) => e.$4).fold<int>(0, (s2, e) => s2 + e.$2),
          reason: '${p.name}: 장부 비용계 = isBusiness 지출만');
      for (final row in ledger.rows) {
        expect(row.account, isNot('급여'), reason: '${p.name}: 장부에 급여 줄이 있으면 안 된다');
      }

      // ── 유형 경계 불변식 ──
      expect(lp.tracksBusinessExpense, isTrue, reason: '${p.name}: N잡러는 사업경비 추적');
      expect(lp.showsCardThreshold, isTrue, reason: '${p.name}: N잡러는 카드공제 대상');
      expect(r.refundProgress, isNull,
          reason: '${p.name}: N잡러 환급블록은 아직 미지원(CombinedTaxCalculator가 실제경비 미수용)');
      expect(r.insuranceProfileSet, isTrue,
          reason: '${p.name}: N잡러 건보 소득월액은 프로필 없이도 소득 기반 자동 산정');
      expect(r.cardDeductionTaxSaving, isNotNull,
          reason: '${p.name}: N잡러 카드 절세액은 합산 엔진이 채워야 한다');
      expect(r.cardDeductionTaxSaving, greaterThanOrEqualTo(0));
      // 문턱 미달이면 공제가 0이므로 절세액도 0이어야 한다 —
      // 엔진과 홈이 근로소득 연환산 기준을 달리 쓰면 여기서 어긋난다.
      if (cc.totalEligibleSpend < cc.threshold) {
        expect(r.cardDeductionTaxSaving, 0,
            reason: '${p.name}: 문턱 미달인데 절세액이 잡히면 두 기준이 어긋난 것');
      }

      // ── 값 불변식 ──
      expect(r.minMonthlyTaxReserve, greaterThanOrEqualTo(0));
      expect(r.minMonthlyTaxReserve, lessThanOrEqualTo(r.maxMonthlyTaxReserve + 1));
      expect(r.minUsable, greaterThanOrEqualTo(0));
      expect(cc.taxSaving, greaterThanOrEqualTo(0));
      expect((s['incomeMonths'] as Set).length, greaterThanOrEqualTo(3));
      expect((s['expenseMonths'] as Set).length, greaterThanOrEqualTo(3));
      expect(s['labor'] as double, greaterThan(0), reason: '${p.name}: 이번 달 근로소득 필요');
      expect(s['mExpense'] as double, greaterThan(0), reason: '${p.name}: 이번 달 지출 필요');
    }
  });

  test('직장인 8인 — 카드공제 환급 카운터', () async {
    for (final p in employeePersonas) {
      final s = await seed(p);
      final cc = cardRefund(p, s);
      final lp = LedgerProfile.of(p.userType);

      final String stage;
      if (cc.totalEligibleSpend < cc.threshold || cc.taxSaving <= 0) {
        stage = 'A(문턱 전)';
      } else if (cc.isCapped) {
        stage = 'C(한도 도달)';
      } else {
        stage = 'B(자람)';
      }

      // ignore: avoid_print
      print('\n═══ ${p.name} ═══');
      // ignore: avoid_print
      print(' [내 정보]  예상연봉=${p.grossIncome > 0 ? won(p.grossIncome) : "미설정"}'
          '  부양=${p.dependents}명');
      // ignore: avoid_print
      print(' [수익지출카드] 이번 달 수령액 ${won(s['labor'])}   지출 ${won(s['mExpense'])}');
      // ignore: avoid_print
      print(' [카드공제]   $stage  문턱=${won(cc.threshold)}  누적사용=${won(cc.totalEligibleSpend)}');
      // ignore: avoid_print
      print('              신용=${won(s['creditYtd'])} 체크·현금=${won(s['debitYtd'])}'
          '  공제=${won(cc.deduction)}  환급카운터=${won(cc.taxSaving)}');

      // ── 유형 경계 ──
      expect(lp.tracksBusinessExpense, isFalse, reason: '${p.name}: 직장인은 사업경비 없음');
      expect(lp.showsReserveCard, isFalse, reason: '${p.name}: 직장인은 적립카드 없음');
      expect(lp.incomeTypes, isNot(contains('사업소득')),
          reason: '${p.name}: 직장인 소득 종류에 사업소득 없음');

      // ── 값 불변식 ──
      expect(cc.taxSaving, greaterThanOrEqualTo(0));
      expect(cc.deduction, lessThanOrEqualTo(7000000 + 1), reason: '${p.name}: 총한도 700만');
      final baseLimit = (p.grossIncome > 0 ? p.grossIncome : 0) <= 70000000 ? 3000000.0 : 2500000.0;
      if (p.grossIncome > 0) {
        expect(cc.deduction, lessThanOrEqualTo(baseLimit + 1),
            reason: '${p.name}: 카드공제만 쓰면 기본한도가 상한');
      }
      expect((s['incomeMonths'] as Set).length, greaterThanOrEqualTo(3));
      expect((s['expenseMonths'] as Set).length, greaterThanOrEqualTo(3));
    }
  });

  test('카드공제 기본한도는 자녀 수에 따라 오른다 (조특법 §126의2⑩, 2025 개정)', () {
    // | 총급여 | 무자녀 | 자녀 1명 | 자녀 2명 이상 |
    // | 7천만 이하 | 300만 | 350만 | 400만 |
    // | 7천만 초과 | 250만 | 275만 | 300만 |
    double limit(double gross, int kids) =>
        EmployeeTaxCalculator.creditCardBaseLimit(grossIncome: gross, childrenCount: kids);

    expect(limit(50000000, 0), 3000000);
    expect(limit(50000000, 1), 3500000);
    expect(limit(50000000, 2), 4000000);
    expect(limit(50000000, 5), 4000000, reason: '2명 이상은 더 늘지 않는다');
    expect(limit(90000000, 0), 2500000);
    expect(limit(90000000, 1), 2750000);
    expect(limit(90000000, 2), 3000000);
    expect(limit(90000000, 5), 3000000);

    // 실제 공제액에도 반영되는지 — 한도까지 쓴 사람이면 자녀 수만큼 더 공제된다.
    final noKids = EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: 50000000, creditCardYtd: 30000000, debitCashYtd: 30000000);
    final twoKids = EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: 50000000, creditCardYtd: 30000000, debitCashYtd: 30000000,
      childrenCount: 2);
    // ignore: avoid_print
    print('\n[카드 한도] 무자녀 공제=${won(noKids.deduction)} 환급=${won(noKids.taxSaving)}'
        '  →  자녀2 공제=${won(twoKids.deduction)} 환급=${won(twoKids.taxSaving)}');
    expect(twoKids.deduction, greaterThan(noKids.deduction));
    expect(twoKids.taxSaving, greaterThan(noKids.taxSaving));
  });

  // ── 2026-07-25 N잡러 세법 대조에서 나온 확정 오류 3건의 회귀 고정 ──

  test('중소기업 감면은 근로소득분 산출세액에만 걸린다 (조특령 §27⑧)', () {
    // 감면세액 = 종합소득산출세액 × (근로소득금액/종합소득금액) × 감면급여비율.
    // 종합 산출세액 전체에 걸면 부업 사업소득분까지 감면돼 세금이 과소해진다.
    // 총급여 3,000만 — 감면액이 연 200만 한도에 걸리지 않는 구간이라야 산식이 드러난다.
    CombinedTaxResult run(double bizIncome) => CombinedTaxCalculator.calculateCombinedTax(
          grossIncome: 30000000,
          accumulatedFreelancerIncome: bizIncome,
          inputMonths: 12,
          occupationCode: '940306',
          creditCard: 0, debitCardAndCash: 0, traditionalMarket: 0,
          publicTransport: 0, cultureExpense: 0,
          allowanceCount: 0, decidedTax: 0, monthlyRent: 0,
          isSmeEmployee: true, smeStartYear: DateTime.now().year, isYouthSme: true,
        );

    final withBiz = run(20000000);
    final laborShare = withBiz.laborIncomeAmount / withBiz.totalGlobalIncome;
    final byLaw = withBiz.calculatedTax * laborShare * 0.90;
    final ifWholeTax = withBiz.calculatedTax * 0.90; // 고쳤던 버그가 내던 값
    // ignore: avoid_print
    print('\n[중소기업 감면] 산출세액=${won(withBiz.calculatedTax)}'
        '  근로비중=${(laborShare * 100).toStringAsFixed(1)}%'
        '  →  감면=${won(withBiz.smeExemption)}  (조문식 ${won(byLaw)} / 전체산출세액 기준이면 ${won(ifWholeTax)})');

    expect(withBiz.smeExemption, lessThan(2000000),
        reason: '한도에 걸리면 산식 검증이 안 되므로 한도 아래 구간이어야 한다');
    expect(withBiz.smeExemption, closeTo(byLaw, 10),
        reason: '감면 = 종합소득산출세액 × 근로소득금액/종합소득금액 × 90%');
    expect(withBiz.smeExemption, lessThan(ifWholeTax),
        reason: '부업이 있으면 전체 산출세액 기준보다 작아야 한다');
  });

  test('중소기업 감면을 받으면 근로소득세액공제가 사라진다 (조특령 §27⑨)', () {
    // 세액공제액 = 근로세액공제 × (1 - 감면급여비율). 근무처가 하나면 비율 1 → 0.
    // 둘 다 온전히 빼면 이중 혜택이라 결정세액이 실제보다 낮게 나온다.
    expect(
      EmployeeTaxCalculator.laborTaxCreditAfterSmeExemption(
          laborTaxCredit: 660000, smeExemption: 500000),
      0,
      reason: '감면을 받는 해에는 근로세액공제가 남지 않는다',
    );
    expect(
      EmployeeTaxCalculator.laborTaxCreditAfterSmeExemption(
          laborTaxCredit: 660000, smeExemption: 0),
      660000,
      reason: '감면기간이 끝나면 근로세액공제는 온전히 살아난다',
    );
  });

  test('월세 17%는 종합소득금액 4,500만 이하일 때만 (조특법 §95의2)', () {
    // 총급여만 보면 5,500만 이하라 17%지만, 부업 때문에 종합소득금액이 4,500만을
    // 넘으면 15%다. N잡러는 이 경계에 걸리기 쉬워 환급이 과대해진다.
    CombinedTaxResult run(double bizIncome) => CombinedTaxCalculator.calculateCombinedTax(
          grossIncome: 50000000,
          accumulatedFreelancerIncome: bizIncome,
          inputMonths: 12,
          occupationCode: '940306',
          creditCard: 0, debitCardAndCash: 0, traditionalMarket: 0,
          publicTransport: 0, cultureExpense: 0,
          allowanceCount: 0, decidedTax: 0,
          monthlyRent: 800000, isHomeless: true,
        );

    // 부업 없음: 근로소득금액 = 5,000만 - 근로소득공제 ≈ 3,725만 → 4,500만 이하 → 17%
    final low = run(0);
    // 부업 3,000만: 종합소득금액이 4,500만을 넘어 15%
    final high = run(30000000);
    // ignore: avoid_print
    print('\n[월세 공제율] 종합소득금액 ${won(low.totalGlobalIncome)} → 공제 ${won(low.rentTaxCredit)}'
        '   |   ${won(high.totalGlobalIncome)} → ${won(high.rentTaxCredit)}');
    expect(low.totalGlobalIncome, lessThanOrEqualTo(45000000));
    expect(high.totalGlobalIncome, greaterThan(45000000));
    expect(low.rentTaxCredit, closeTo(9600000 * 0.17, 1), reason: '17% 구간');
    expect(high.rentTaxCredit, closeTo(9600000 * 0.15, 1), reason: '15% 구간');
  });

  test('N잡러 카드 절세액은 종합 과세표준 기준 — 부업이 구간을 밀어올리면 커진다', () async {
    // 조특법 §126의2는 "근로소득금액에서 공제"라 공제액·한도는 총급여 기준이지만,
    // 줄어든 과세표준은 종합소득 구간에서 세율이 매겨진다. 근로소득만으로 절세액을
    // 계산하면 부업이 상위 구간을 만든 만큼 과소 추정된다(2026-07-25 수정).
    Future<(double engine, double laborOnly)> run(int bizMonthly) async {
      final p = P('probe', userType: 'N잡러', occ: '940306', priorYear: 20000000,
        grossIncome: 40000000,
        incomes: [
          for (int m = 1; m <= 12; m++) ...[
            (m, 3300000, '급여', false),
            (m, bizMonthly, '사업소득', true),
          ]
        ],
        expenses: [(2, 12000000, '신용카드', false), (5, 10000000, '체크+현금', false),
                   (7, 100000, '신용카드', false)]);
      final s = await seed(p);
      final r = await ReserveEstimator.estimateForCurrentMonth(userType: 'N잡러');
      return (r.cardDeductionTaxSaving!, cardRefund(p, s).taxSaving);
    }

    final small = await run(500000);   // 부업 소액 — 구간 이동 없음
    final big = await run(9000000);    // 부업 큼 — 상위 구간으로 이동

    // ignore: avoid_print
    print('\n[카드 절세액] 부업 소액: 엔진 ${won(small.$1)} / 근로기준 ${won(small.$2)}');
    // ignore: avoid_print
    print('              부업 큼  : 엔진 ${won(big.$1)} / 근로기준 ${won(big.$2)}');

    expect(big.$1, greaterThan(big.$2),
        reason: '부업이 세율 구간을 올리면 카드공제 절세액도 커진다');
    expect(big.$1, greaterThan(small.$1),
        reason: '같은 카드 사용액이라도 소득이 높으면 절세액이 크다');
  });

  test('N잡러 카드공제 문턱은 근로소득(총급여) 기준 — 사업소득이 섞이면 안 된다', () async {
    // 조특법 §126의2 — 문턱은 "총급여액의 25%". 사업소득은 총급여가 아니다.
    // 예상연봉 미설정 시 홈은 이번 달 기록을 연환산해 쓰는데, N잡러의
    // monthlyIncome은 근로+사업 합계라 그대로 쓰면 문턱이 부풀려진다(2026-07-25 수정).
    final p = njobPersonas[2]; // ③ 예상연봉 미설정
    final s = await seed(p);
    final cc = cardRefund(p, s);

    final labor = s['labor'] as double;
    final combined = s['monthlyIncome'] as double;

    // ignore: avoid_print
    print('\n[문턱 기준] 적용된 문턱=${won(cc.threshold)}'
        '  근로소득 기준=${won(labor * 12 * 0.25)}'
        '  (근로+사업 기준이면 ${won(combined * 12 * 0.25)})');

    expect(cc.threshold, closeTo(labor * 12 * 0.25, 1),
        reason: '문턱은 근로소득만으로 잡혀야 한다');
    expect(cc.threshold, lessThan(combined * 12 * 0.25),
        reason: '사업소득이 섞이면 문턱이 부풀려진다');
  });
}
