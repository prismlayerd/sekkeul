import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/core/tax_engine/reserve_estimator.dart';
import 'package:secul/core/tax_engine/employee_tax.dart';
import 'package:secul/core/tax_engine/simple_ledger_builder.dart';

/// 프리랜서 10인 페르소나 회귀 — 실제 코드 경로(ReserveEstimator)에 태워 검증한다.
/// dbService를 InMemory로 갈아끼워 화면이 부르는 함수를 그대로 호출하므로,
/// 프로필 배선이 끊기거나 단계 판정이 틀어지면 여기서 잡힌다.
///
/// 모든 페르소나는 수입·지출 각각 3개월 이상(이번 달 포함)을 갖는다 —
/// 수익지출카드의 머리 숫자와 적립카드의 '지금 써도 되는 돈'이 이번 달만 보기 때문에,
/// 이번 달 기록이 없으면 그 칸들이 0으로 남아 검증이 안 된다.
class P {
  final String name;
  final String occ;
  final int priorYear;
  final bool newBiz;
  final int dependents;
  final int disabledDeps;
  final bool selfDisability;
  final double yellowUmbrella;
  final String residence; // 전세 | 월세 | 자가
  final double monthlyRent;
  final bool pension;
  final bool health;
  final double property;

  /// (월, 입력액, 소득종류, 원천징수여부) — 입력액은 화면과 같이 '세후 실수령액'.
  final List<(int, int, String, bool)> incomes;

  /// (월, 금액, 결제수단, 사업경비여부)
  final List<(int, int, String, bool)> expenses;

  const P(this.name, {
    required this.occ,
    this.priorYear = 0,
    this.newBiz = false,
    this.dependents = 0,
    this.disabledDeps = 0,
    this.selfDisability = false,
    this.yellowUmbrella = 0,
    this.residence = '전세',
    this.monthlyRent = 0,
    this.pension = false,
    this.health = false,
    this.property = 0,
    required this.incomes,
    required this.expenses,
  });
}

const personas = <P>[
  // ① 표준 — 업종·직전연도 입력 완료, 경비가 분기점에 못 미침
  P('① 기본 프리랜서', occ: '940306', priorYear: 30000000,
    incomes: [(1, 3000000, '사업소득', true), (3, 4000000, '사업소득', true),
              (5, 5000000, '사업소득', true), (7, 3000000, '사업소득', true)],
    expenses: [(2, 2000000, '신용카드', true), (4, 3000000, '신용카드', true),
               (6, 1500000, '체크+현금', true), (7, 1000000, '신용카드', true),
               (7, 800000, '신용카드', false)]),

  // ② 공제가 많아 이미 세금이 거의 0 — 유도해봐야 실익이 없는 케이스
  P('② 부양3·노란우산', occ: '940306', priorYear: 30000000, dependents: 3, yellowUmbrella: 3000000,
    incomes: [(1, 5000000, '사업소득', true), (4, 6000000, '사업소득', true),
              (7, 5000000, '사업소득', true)],
    expenses: [(2, 3000000, '신용카드', true), (5, 2500000, '체크+현금', true),
               (7, 1500000, '신용카드', true)]),

  // ③ 업종 미설정 — 경비율을 몰라 세액 추정 불가(숫자 대신 유도가 떠야 함)
  P('③ 업종 미설정', occ: '',
    incomes: [(2, 4000000, '사업소득', true), (5, 4000000, '사업소득', true),
              (7, 4000000, '사업소득', true)],
    expenses: [(3, 1500000, '신용카드', true), (5, 1000000, '체크+현금', true),
               (7, 1200000, '신용카드', true)]),

  // ④ 업종은 있으나 직전연도 미입력 — 경비율 미정이라 적립은 범위, 환급블록은 없음
  P('④ 직전연도 미입력', occ: '940306',
    incomes: [(2, 4000000, '사업소득', true), (5, 4000000, '사업소득', true),
              (7, 4000000, '사업소득', true)],
    expenses: [(3, 1500000, '신용카드', true), (5, 1000000, '체크+현금', true),
               (7, 1200000, '신용카드', true)]),

  // ⑤ 복식부기 의무자(직전연도 7,500만 이상) — 간편장부 비교 대상 아님
  P('⑤ 복식부기 의무자', occ: '940306', priorYear: 90000000,
    incomes: [(1, 10000000, '사업소득', true), (4, 12000000, '사업소득', true),
              (7, 10000000, '사업소득', true)],
    expenses: [(2, 5000000, '신용카드', true), (5, 5000000, '체크+현금', true),
               (7, 4000000, '신용카드', true)]),

  // ⑥ 신규사업자 — 첫해 간편장부, 단순경비율 대상
  P('⑥ 신규사업자', occ: '940306', newBiz: true,
    incomes: [(3, 6000000, '사업소득', true), (5, 6000000, '사업소득', true),
              (7, 6000000, '사업소득', true)],
    expenses: [(4, 3000000, '신용카드', true), (6, 3000000, '체크+현금', true),
               (7, 2000000, '신용카드', true)]),

  // ⑦ 기타소득 혼재(8.8% 원천징수·정률 60% 경비) + 분기점 돌파
  P('⑦ 기타소득 혼재', occ: '940306', priorYear: 30000000,
    incomes: [(2, 6000000, '사업소득', true), (4, 3000000, '기타소득', true),
              (6, 6000000, '사업소득', true), (7, 3000000, '사업소득', true)],
    expenses: [(3, 4000000, '신용카드', true), (5, 4000000, '체크+현금', true),
               (7, 3000000, '신용카드', true)]),

  // ⑧ 저소득 — 어느 쪽으로 신고해도 낼 세금이 없음
  P('⑧ 저소득', occ: '940306', priorYear: 8000000,
    incomes: [(3, 1300000, '사업소득', true), (5, 1300000, '사업소득', true),
              (7, 1300000, '사업소득', true)],
    expenses: [(4, 300000, '체크+현금', true), (6, 200000, '신용카드', true),
               (7, 200000, '체크+현금', true)]),

  // ⑨ 경비 과다 기록 → 결정세액 0(C단계) + 4대보험 자가납부·재산 보유
  P('⑨ 경비과다·보험가입', occ: '940306', priorYear: 30000000,
    pension: true, health: true, property: 50000000,
    incomes: [(1, 7000000, '사업소득', true), (4, 7000000, '사업소득', true),
              (7, 6000000, '사업소득', true)],
    expenses: [(2, 9000000, '신용카드', true), (5, 9000000, '체크+현금', true),
               (7, 4000000, '신용카드', true)]),

  // ⑩ 월세 거주 + 본인·부양 장애 — 월세공제는 성실사업자만이라 미적용이 정답
  P('⑩ 월세·본인장애', occ: '940306', priorYear: 30000000, residence: '월세', monthlyRent: 600000,
    selfDisability: true, disabledDeps: 1, dependents: 1,
    incomes: [(2, 8000000, '사업소득', true), (5, 8000000, '사업소득', true),
              (7, 4000000, '사업소득', true)],
    expenses: [(3, 5000000, '신용카드', true), (6, 2000000, '체크+현금', true),
               (7, 2000000, '신용카드', true)]),
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

  test('프리랜서 10인 — 내 정보 / 수익지출카드 / 적립카드', () async {
    for (final p in personas) {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();

      await dbService.saveProfile({
        'user_type': '프리랜서',
        'occupation_code': p.occ,
        'prior_year_income': p.priorYear.toDouble(),
        'is_new_business': p.newBiz,
        'dependents': p.dependents,
        'disabled_dependent_count': p.disabledDeps,
        'has_self_disability': p.selfDisability,
        'yellow_umbrella': p.yellowUmbrella,
        'is_monthly_rent': p.residence == '월세',
        'owns_house': p.residence == '자가',
        'monthly_rent': p.monthlyRent,
        'pension_enrolled': p.pension,
        'health_enrolled': p.health,
        'property_value': p.property,
      });

      final usableIncomes = p.incomes.where((e) => e.$1 <= now.month).toList();
      final usableExpenses = p.expenses.where((e) => e.$1 <= now.month).toList();

      for (final (m, amt, type, wh) in usableIncomes) {
        await dbService.insertIncomeEntry(IncomeEntry(
          id: 'i$m-$amt-$type', date: DateTime(now.year, m, 10),
          amount: amt, memo: '', incomeType: type, isWithheld: wh, userType: '프리랜서'));
      }
      for (final (m, amt, pm, biz) in usableExpenses) {
        await dbService.insertExpense(ExpenseItem(
          id: 'e$m-$amt-$pm-$biz', date: DateTime(now.year, m, 15),
          amount: amt, content: '', category: '기타', paymentMethod: pm,
          isBusiness: biz, userType: '프리랜서'));
      }

      // ── 수익지출카드(홈)가 표시하는 값 — home_screen._loadCurrentMonthIncome과 동일 규칙 ──
      // 이번 달만 본다. 프리랜서는 '세후(기록값)'가 기본이고 탭하면 세전 환산을 보여준다.
      double mNet = 0, mGross = 0;
      for (final (m, amt, type, wh) in usableIncomes) {
        if (m != now.month) continue;
        mNet += amt;
        final div = wh ? (type == '기타소득' ? 0.912 : 0.967) : 1.0;
        mGross += amt / div;
      }
      final mExpense = usableExpenses
          .where((e) => e.$1 == now.month)
          .fold<int>(0, (s, e) => s + e.$2);

      final incomeMonths = usableIncomes.map((e) => e.$1).toSet();
      final expenseMonths = usableExpenses.map((e) => e.$1).toSet();

      final r = await ReserveEstimator.estimateForCurrentMonth(userType: '프리랜서');

      final ytdBizExp = usableExpenses.where((e) => e.$4).fold<int>(0, (s, e) => s + e.$2);
      final ytdGross = usableIncomes.fold<double>(0, (s, e) {
        final div = e.$4 ? (e.$3 == '기타소득' ? 0.912 : 0.967) : 1.0;
        return s + e.$2 / div;
      });

      // ignore: avoid_print
      print('\n═══ ${p.name} ═══');
      // ignore: avoid_print
      print(' [내 정보]  업종=${p.occ.isEmpty ? '미설정' : p.occ}  직전연도=${won(p.priorYear)}  신규=${p.newBiz}');
      // ignore: avoid_print
      print('            부양=${p.dependents}명  장애(본인/부양)=${p.selfDisability}/${p.disabledDeps}'
          '  노란우산=${won(p.yellowUmbrella)}  거주=${p.residence}'
          '${p.monthlyRent > 0 ? '(월 ${won(p.monthlyRent)})' : ''}');
      // ignore: avoid_print
      print('            연금/건보=${p.pension}/${p.health}  재산=${won(p.property)}');
      // ignore: avoid_print
      print(' [입력범위] 수입 ${incomeMonths.length}개월${incomeMonths.toList()..sort()}'
          '  지출 ${expenseMonths.length}개월${expenseMonths.toList()..sort()}');
      // ignore: avoid_print
      print(' [수익지출카드] 이번 달 수입 ${won(mNet)}(세후) / ${won(mGross)}(세전)'
          '   이번 달 지출 ${won(mExpense)}');
      // ignore: avoid_print
      print(' [올해 누계]   수입(세전) ${won(ytdGross)}   사업경비 ${won(ytdBizExp)}   경과 ${now.month}개월');

      final reserveTxt = r.hasOccupationCode
          ? (r.minMonthlyTaxReserve.round() == r.maxMonthlyTaxReserve.round()
              ? won(r.minMonthlyTaxReserve)
              : '${won(r.minMonthlyTaxReserve)}~${won(r.maxMonthlyTaxReserve)}')
          : '업종 설정 필요(숫자 숨김)';
      final usableTxt = r.hasOccupationCode
          ? (r.minUsable.round() == r.maxUsable.round()
              ? won(r.minUsable)
              : '${won(r.minUsable)}~${won(r.maxUsable)}')
          : '(숨김)';
      // ignore: avoid_print
      print(' [기장의무]   ${r.bookkeepingJudgment == null ? "판정 불가(업종 미설정)" : (r.bookkeepingJudgment!.isDoubleEntry ? "복식부기의무자" : "간편장부대상자")}'
          '   무기장가산세 ${r.includesNoBookkeepingPenalty ? "포함(20%)" : "면제(소규모사업자)"}');
      // ignore: avoid_print
      print(' [적립카드]   세금적립/월=$reserveTxt');
      // ignore: avoid_print
      print('              보험적립/월=${r.insuranceProfileSet ? won(r.insuranceReserve) : "프로필 설정 시"}'
          '   지금써도되는돈=$usableTxt');

      // ── 세무도구: 가계부 → 간편장부 만들기 (bookkeeping_guide_screen이 부르는 경로) ──
      final ledgerIncomes = <IncomeEntry>[];
      for (int m = 1; m <= 12; m++) {
        ledgerIncomes.addAll(
            await dbService.getIncomeEntriesForMonth(now.year, m, userType: '프리랜서'));
      }
      final ledger = SimpleLedgerBuilder.build(
        year: now.year,
        incomes: ledgerIncomes,
        expenses: await dbService.getExpenses(userType: '프리랜서'),
      );
      final csv = SimpleLedgerBuilder.toCsv(ledger);
      final csvLines = csv.trim().split('\n');
      // ignore: avoid_print
      print(' [세무도구]   장부 ${ledger.rows.length}줄  수입계=${won(ledger.totalIncome)}'
          '  비용계=${won(ledger.totalExpense)}  거래내용 빈칸=${ledger.blankDescriptionCount}줄');
      // ignore: avoid_print
      print('              CSV 헤더: ${csvLines.first.replaceFirst('﻿', '')}');
      // ignore: avoid_print
      print('              CSV 합계: ${csvLines.last}');

      // 장부 수입은 세전(총수입금액)이어야 한다 — 실수령액을 적으면 매출 과소신고가 된다.
      expect(ledger.totalIncome, closeTo(ytdGross, 2 * usableIncomes.length),
          reason: '${p.name}: 장부 수입계 = 세전 환산 누계');
      // 장부 비용은 사업경비만 — 개인 지출이 섞이면 필요경비 과대계상이 된다.
      expect(ledger.totalExpense, ytdBizExp,
          reason: '${p.name}: 장부 비용계 = isBusiness 지출만');
      expect(ledger.rows.length,
          usableIncomes.length + usableExpenses.where((e) => e.$4).length,
          reason: '${p.name}: 장부 줄 수 = 수입 건 + 사업경비 건');
      expect(csvLines.last, '합계,,,,${ledger.totalIncome},,${ledger.totalExpense},,',
          reason: '${p.name}: CSV 합계 줄이 장부 합계와 같아야 한다');
      // 장부 총액은 적립·환급 계산이 쓰는 값과 같은 세계에 있어야 한다.
      final progressForLedger = r.refundProgress;
      if (progressForLedger != null) {
        expect(ledger.totalExpense, closeTo(progressForLedger.recordedExpense, 1),
            reason: '${p.name}: 장부 비용계 = 환급블록 기록경비');
      }

      final rp = r.refundProgress;
      if (rp == null) {
        // ignore: avoid_print
        print(' [환급블록]   없음 — 업종/직전연도 미입력 또는 복식부기의무자');
      } else {
        final String stage, caption;
        if (rp.noTaxEitherWay || (!rp.isAhead && !rp.worthPursuing)) {
          stage = rp.noTaxEitherWay ? '숨김(낼 세금 없음)' : '숨김(실익 미미)';
          caption = rp.noTaxEitherWay
              ? '지금 소득에선 어느 쪽으로 신고해도 낼 세금이 없어요'
              : '공제를 빼면 낼 세금이 거의 없어서, 경비를 더 찾아도 돌려받을 게 적어요';
        } else if (!rp.isAhead) {
          stage = 'A(분기점 전)';
          caption = '${won(rp.shortfall)}을 더 찾으면 환급이 쌓이기 시작해요 (최대 ${won(rp.maxGain)})';
        } else if (rp.isCapped) {
          stage = 'C(상한)';
          caption = '올해 원천징수된 세금을 다 돌려받는 상태예요 · 더 적어도 환급은 안 늘어요';
        } else {
          stage = 'B(자람)';
          caption = '경비를 더 찾을수록 늘어요 · 예상';
        }
        // ignore: avoid_print
        print(' [환급블록]   $stage   카운터=${won(rp.refundGain)}');
        // ignore: avoid_print
        print('              기록경비=${won(rp.recordedExpense)}  분기점=${won(rp.breakevenExpense)}'
            '  추계세액=${won(rp.estimateTax)}  장부세액=${won(rp.bookkeepingTax)}');
        // ignore: avoid_print
        print('              문구: "$caption"');

        expect(rp.refundGain, greaterThanOrEqualTo(0), reason: '${p.name}: 카운터 음수 불가');
        expect(rp.refundGain, lessThanOrEqualTo(rp.estimateTax + 1),
            reason: '${p.name}: 이득이 추계세액(상한)을 넘을 수 없다');
        if (rp.isCapped) {
          expect(rp.bookkeepingTax, lessThanOrEqualTo(0), reason: '${p.name}: C는 결정세액 0');
        }
        if (rp.isAhead && !rp.noTaxEitherWay) {
          expect(rp.recordedExpense, greaterThanOrEqualTo(rp.breakevenExpense - 1),
              reason: '${p.name}: 이겼다면 기록경비가 분기점 이상');
        }
      }

      // ── 공통 불변식 ──
      expect(incomeMonths.length, greaterThanOrEqualTo(3), reason: '${p.name}: 수입 3개월 이상');
      expect(expenseMonths.length, greaterThanOrEqualTo(3), reason: '${p.name}: 지출 3개월 이상');
      expect(incomeMonths, contains(now.month), reason: '${p.name}: 이번 달 수입 필요');
      expect(expenseMonths, contains(now.month), reason: '${p.name}: 이번 달 지출 필요');
      expect(mNet, greaterThan(0), reason: '${p.name}: 수익지출카드 이번 달 수입이 0이면 검증 안 됨');
      expect(mExpense, greaterThan(0), reason: '${p.name}: 수익지출카드 이번 달 지출이 0이면 검증 안 됨');
      expect(r.minUsable, greaterThanOrEqualTo(0), reason: '${p.name}: 써도되는돈 음수 불가');
      expect(r.minMonthlyTaxReserve, greaterThanOrEqualTo(0), reason: '${p.name}: 적립 음수 불가');
      expect(r.minMonthlyTaxReserve, lessThanOrEqualTo(r.maxMonthlyTaxReserve + 1),
          reason: '${p.name}: min<=max');
      expect(r.hasOccupationCode, p.occ.isNotEmpty, reason: '${p.name}: 업종 설정 플래그');
    }
  });

  test('부양가족이 실제로 세금을 낮추는가 (프로필 배선 회귀)', () async {
    Future<double> reserveWith(int deps) async {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
      await dbService.saveProfile({
        'user_type': '프리랜서', 'occupation_code': '940306',
        'prior_year_income': 30000000.0, 'dependents': deps,
      });
      for (int m = 1; m <= now.month; m++) {
        await dbService.insertIncomeEntry(IncomeEntry(
          id: 'x$m', date: DateTime(now.year, m, 10), amount: 3000000,
          memo: '', incomeType: '사업소득', isWithheld: true, userType: '프리랜서'));
      }
      final r = await ReserveEstimator.estimateForCurrentMonth(userType: '프리랜서');
      return r.minMonthlyTaxReserve;
    }

    final d0 = await reserveWith(0);
    final d3 = await reserveWith(3);
    // ignore: avoid_print
    print('\n[배선 회귀] 부양 0명 적립/월=${won(d0)}  →  3명=${won(d3)}');
    expect(d3, lessThan(d0), reason: '부양가족이 늘면 세금 적립이 줄어야 한다');
  });

  // 자녀세액공제(소법 §59의2)는 "종합소득이 있는 거주자"가 대상이라 프리랜서도 받는다.
  // 과거엔 엔진에 파라미터 자체가 없어 늘 0이었다.
  test('8세 이상 자녀가 세금을 낮추는가 — 자녀세액공제 배선', () async {
    Future<double> reserveWith(int childrenForCredit) async {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
      await dbService.saveProfile({
        'user_type': '프리랜서', 'occupation_code': '940306',
        'prior_year_income': 30000000.0,
        'children_count_total': childrenForCredit,
        'children_count_credit': childrenForCredit,
      });
      for (int m = 1; m <= now.month; m++) {
        await dbService.insertIncomeEntry(IncomeEntry(
          id: 'h$m', date: DateTime(now.year, m, 10), amount: 4000000,
          memo: '', incomeType: '사업소득', isWithheld: true, userType: '프리랜서'));
      }
      final r = await ReserveEstimator.estimateForCurrentMonth(userType: '프리랜서');
      return r.minMonthlyTaxReserve;
    }

    final none = await reserveWith(0);
    final two = await reserveWith(2); // 8세 이상 2명 → 연 55만 세액공제
    // ignore: avoid_print
    print('\n[자녀세액공제] 0명 적립/월=${won(none)}  →  8세 이상 2명=${won(two)}');
    expect(two, lessThan(none), reason: '자녀세액공제는 종합소득자 전원 대상이라 세금이 줄어야 한다');
  });

  test('무기장가산세 — 소규모사업자는 면제, 넘으면 산출세액 20%', () async {
    Future<(double, bool)> run(int priorYear) async {
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
      await dbService.saveProfile({
        'user_type': '프리랜서', 'occupation_code': '940306',
        'prior_year_income': priorYear.toDouble(),
      });
      for (int m = 1; m <= now.month; m++) {
        await dbService.insertIncomeEntry(IncomeEntry(
          id: 'p$m', date: DateTime(now.year, m, 10), amount: 4000000,
          memo: '', incomeType: '사업소득', isWithheld: true, userType: '프리랜서'));
      }
      final r = await ReserveEstimator.estimateForCurrentMonth(userType: '프리랜서');
      return (r.minMonthlyTaxReserve, r.includesNoBookkeepingPenalty);
    }

    // 4,800만 미만 → 소규모사업자로 면제
    final (taxExempt, exemptFlag) = await run(40000000);
    // 4,800만 이상 → 가산세 부과 대상
    final (taxPenal, penalFlag) = await run(50000000);

    // ignore: avoid_print
    print('\n[무기장가산세] 직전연도 4,000만(면제)=${won(taxExempt)}/월'
        '  →  5,000만(부과)=${won(taxPenal)}/월');
    expect(exemptFlag, isFalse, reason: '직전연도 4,800만 미만은 면제');
    expect(penalFlag, isTrue, reason: '직전연도 4,800만 이상은 부과 대상');
    // 같은 수입인데 가산세가 붙으므로 적립액이 더 커야 한다.
    expect(taxPenal, greaterThan(taxExempt), reason: '가산세가 적립액에 반영돼야 한다');
  });

  test('간편장부 변환 — 세전 환산·사업경비만·개인지출 제외', () {
    final rows = SimpleLedgerBuilder.build(
      year: now.year,
      incomes: [
        IncomeEntry(id: 'a', date: DateTime(now.year, 3, 2), amount: 967000,
            memo: '외주', incomeType: '사업소득', isWithheld: true),
        IncomeEntry(id: 'b', date: DateTime(now.year, 4, 1), amount: 500000,
            memo: '급여', incomeType: '급여'), // 근로소득 → 제외
      ],
      expenses: [
        ExpenseItem(id: 'c', date: DateTime(now.year, 3, 5), amount: 200000,
            content: '장비', category: '기타', paymentMethod: '신용카드', isBusiness: true),
        ExpenseItem(id: 'd', date: DateTime(now.year, 3, 6), amount: 50000,
            content: '개인', category: '기타', paymentMethod: '신용카드', isBusiness: false),
      ],
    );
    // ignore: avoid_print
    print('[간편장부] 줄=${rows.rows.length} 수입=${won(rows.totalIncome)} 비용=${won(rows.totalExpense)}');
    expect(rows.rows.length, 2, reason: '급여·개인지출은 장부에서 빠진다');
    expect(rows.totalIncome, 1000000, reason: '967,000 ÷ 0.967 = 세전 100만');
    expect(rows.totalExpense, 200000, reason: '사업경비만');
    final csv = SimpleLedgerBuilder.toCsv(rows);
    expect(csv, contains('일자,계정과목,거래내용,거래처'));
    expect(csv, contains('합계'));
  });

  test('기타소득 정률 60% 경비가 반영되는가', () {
    final amt = EmployeeTaxCalculator.calculateOtherIncomeAmount(10000000);
    // ignore: avoid_print
    print('[기타소득] 연 1,000만 → 소득금액 ${won(amt)}');
    expect(amt, closeTo(4000000, 1));
  });
}
