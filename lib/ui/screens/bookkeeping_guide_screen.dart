import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/income_entry.dart';
import '../../core/data/occupation_data.dart';
import '../../core/data/year_coverage.dart';
import '../../core/data/year_snapshot.dart';
import '../../core/tax_engine/bookkeeping_duty.dart';
import '../../core/tax_engine/combined_tax.dart';
import '../../core/tax_engine/freelancer_tax.dart';
import '../../core/tax_engine/simple_ledger_builder.dart';
import 'expense_calendar_screen.dart';
import '../theme/text_wrap.dart';

/// 기장의무 안내 + 가계부 기록으로 간편장부 만들기.
///
/// 무기장가산세(산출세액 20%, 소득세법 §81의5)는 장부를 갖추면 사라진다.
/// 앱은 이미 수입·사업경비를 날짜별로 갖고 있으므로, 그걸 국세청 간편장부
/// 열 구성으로 옮겨 CSV로 내보낸다.
class BookkeepingGuideScreen extends StatefulWidget {
  final String userType;
  const BookkeepingGuideScreen({super.key, required this.userType});

  @override
  State<BookkeepingGuideScreen> createState() => _BookkeepingGuideScreenState();
}

class _BookkeepingGuideScreenState extends State<BookkeepingGuideScreen> {
  /// 어느 해 장부인가.
  ///
  /// **올해로 못 박아 두면 정작 신고철에 쓸모가 없다.** 5월에 신고하는 건 작년
  /// 장부다. 그래서 1~5월이면 작년을, 그 뒤엔 올해를 기본으로 연다 — 연중에는
  /// 쌓이는 걸 보고, 신고철에는 낼 것을 본다.
  late int _year = DateTime.now().month <= 5
      ? DateTime.now().year - 1
      : DateTime.now().year;

  SimpleLedgerResult? _result;
  BookkeepingJudgment? _judgment;

  /// 그 해 백필에 담긴 사업 수입·경비. 장부에는 안 들어간다 — 합계라 거래 줄로
  /// 못 쪼갠다(「가짜 기록을 만들지 않는다」). 대신 빠졌다고 말해 준다.
  Backfill _backfill = const Backfill();

  /// 장부(실제경비) vs 추계(경비율) — 어느 쪽 세금이 적은가.
  /// 「장부를 만들까?」에 답하는 것이 이 화면의 일이다. 무기장가산세만 말하면
  /// 경비율이 더 유리한 사람에게도 헛수고를 시킨다.
  double? _bookkeepingGain;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await dbService.getProfile();
    final expenses = await dbService.getExpenses(userType: widget.userType);
    final incomes = <IncomeEntry>[];
    for (int m = 1; m <= 12; m++) {
      incomes.addAll(
          await dbService.getIncomeEntriesForMonth(_year, m, userType: widget.userType));
    }

    final occCode = (profile?['occupation_code'] as String?) ?? '';
    final occ = OccupationData.occupations[occCode];
    final judgment = occ == null
        ? null
        : judgeBookkeepingDuty(
            occupation: occ,
            priorYearIncome: (profile?['prior_year_income'] as num?)?.toInt() ?? 0,
            isNewBusiness: profile?['is_new_business'] == true,
          );

    final result = SimpleLedgerBuilder.build(
      year: _year,
      incomes: incomes,
      expenses: expenses,
    );
    final backfill = await YearCoverage.backfill(_year);
    // N잡러 비교에는 카드공제가 필요하다 — 근로 쪽 과세표준을 낮춰 사업소득의
    // 한계세율을 바꾼다. 0으로 넘기면 장부 효과가 부풀려진다.
    final snap = await YearSnapshot.load(widget.userType, year: _year);
    final gain = _compare(profile, occ, judgment, result, snap);

    if (!mounted) return;
    setState(() {
      _judgment = judgment;
      _result = result;
      _backfill = backfill;
      _bookkeepingGain = gain;
      _loading = false;
    });
  }

  /// 장부로 신고하면 추계보다 세금이 **얼마나 줄어드는가.** 음수면 경비율이 낫다.
  ///
  /// 복식부기의무자에게는 계산하지 않는다 — 그쪽은 선택지가 없다.
  double? _compare(Map<String, dynamic>? profile, OccupationInfo? occ,
      BookkeepingJudgment? judgment, SimpleLedgerResult r, YearSnapshot snap) {
    if (occ == null || judgment == null || !judgment.isSimplified) return null;
    if (r.totalIncome <= 0) return null;

    final months = _year == DateTime.now().year ? DateTime.now().month : 12;
    final prior = (profile?['prior_year_income'] as num?)?.toInt() ?? 0;
    final newBiz = profile?['is_new_business'] == true;
    // 추계 경비율은 고르는 게 아니라 강제된다 — 세금 낮은 쪽을 임의로 못 쓴다.
    final forceStandard = !isSimpleExpenseRateEligible(
      occupation: occ,
      priorYearIncome: prior,
      isNewBusiness: newBiz,
      currentYearIncome: (r.totalIncome / months) * 12,
    );
    final deps = (profile?['dependents'] as int?) ?? 0;
    final kids = (profile?['children_count_credit'] as int?) ?? 0;

    if (widget.userType == 'N잡러') {
      // 근로소득까지 합산해야 세율 구간이 맞는다. `actualExpense`를 주고 안 주고로
      // 두 번 돌려 차이를 낸다 — 엔진이 그러라고 이 인자를 갖고 있다.
      final gross = (profile?['gross_income'] as num?)?.toDouble() ?? 0.0;
      if (gross <= 0) return null;
      double tax({double? actual}) => CombinedTaxCalculator.calculateCombinedTax(
            grossIncome: gross,
            accumulatedFreelancerIncome: r.totalIncome.toDouble(),
            inputMonths: months,
            allowanceCount: deps,
            occupationCode: occ.code,
            childrenCountForCredit: kids,
            useStandardExpenseRate: forceStandard,
            actualExpense: actual,
            creditCard: snap.creditCard,
            debitCardAndCash: snap.debitCash,
            traditionalMarket: snap.market,
            publicTransport: snap.transport,
            cultureExpense: snap.culture,
            monthlyRent: (profile?['monthly_rent'] as num?)?.toDouble() ?? 0,
            decidedTax: 0,
          ).annualTotalTax;
      return tax() - tax(actual: (r.totalExpense / months) * 12);
    }

    final cmp = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
      accumulatedIncome: r.totalIncome.toDouble(),
      accumulatedActualExpense: r.totalExpense.toDouble(),
      inputMonths: months,
      allowanceCount: deps,
      occupationCode: occ.code,
      childrenCountForCredit: kids,
      forceStandardExpenseRate: forceStandard,
      paysNationalPension: profile?['pension_enrolled'] == true,
      paysLocalHealth: profile?['health_enrolled'] == true,
    );
    return cmp.estimate.annualTotalTax - cmp.bookkeeping.annualTotalTax;
  }

  Future<void> _exportCsv() async {
    final r = _result;
    if (r == null || r.isEmpty) return;
    final csv = SimpleLedgerBuilder.toCsv(r);
    if (kIsWeb) {
      _toast('웹에서는 파일 저장이 안 돼요. 휴대폰 앱에서 내보내세요.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/간편장부_${r.year}.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: '간편장부 ${r.year}');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: AppTheme.sans(AppTheme.tsSM, AppTheme.backgroundColor(context))),
      backgroundColor: AppTheme.ink(context),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final r = _result;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text('장부 만들기',
            style: AppTheme.serif(AppTheme.tsLG, ink, weight: FontWeight.w400, spacing: -0.5)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // ── 어느 해 장부 ──
                _yearPicker(ink, sub, accent),
                const SizedBox(height: 20),
                AppTheme.hairline(context),
                const SizedBox(height: 20),

                // ── 내 기장의무 ──
                Text('내 기장의무'.toUpperCase(), style: AppTheme.label(context)),
                const SizedBox(height: 10),
                if (_judgment == null)
                  Text('업종코드를 설정하면 기장의무를 알려드려요.'.keepWords,
                      style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5))
                else ...[
                  Text(_judgment!.isDoubleEntry ? '복식부기의무자' : '간편장부대상자',
                      style: AppTheme.serif(AppTheme.serifLG, ink, weight: FontWeight.w700, spacing: -0.5)),
                  const SizedBox(height: 6),
                  Text(_judgment!.reason, style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5)),
                ],
                const SizedBox(height: 20),
                AppTheme.hairline(context),

                // ── 가산세 ──
                const SizedBox(height: 20),
                Text('장부가 없으면'.toUpperCase(), style: AppTheme.label(context)),
                const SizedBox(height: 10),
                Text('산출세액의 20%',
                    style: AppTheme.serif(AppTheme.serifXL, AppTheme.colorDanger,
                        weight: FontWeight.w700, spacing: -0.8)),
                const SizedBox(height: 6),
                Text(
                  '무기장가산세(소득세법 §81의5). 장부를 갖추면 붙지 않아요.\n'
                  '신규사업자이거나 직전연도 수입이 4,800만원 미만이면 면제됩니다.'.keepWords,
                  style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5),
                ),
                if (_judgment?.isSmallBusinessExemptFromPenalty == true) ...[
                  const SizedBox(height: 8),
                  Text('→ 지금은 면제 대상이에요.'.keepWords,
                      style: AppTheme.sans(AppTheme.tsSM, accent, weight: FontWeight.w700)),
                ],
                // ── 장부가 이득인가 ──
                if (_bookkeepingGain != null) ...[
                  const SizedBox(height: 20),
                  AppTheme.hairline(context),
                  const SizedBox(height: 20),
                  _gainBlock(ink, sub, tert, accent),
                ],

                // ── 복식부기로 하면 ──
                if (_judgment?.isSimplified == true) ...[
                  const SizedBox(height: 20),
                  AppTheme.hairline(context),
                  const SizedBox(height: 20),
                  Text('복식부기로 신고하면'.toUpperCase(), style: AppTheme.label(context)),
                  const SizedBox(height: 10),
                  Text(
                      '간편장부대상자가 복식부기로 신고하면 기장세액공제를 받아요 — '
                              '산출세액의 20%, 연 100만원 한도(소득세법 §56의2).'
                          .keepWords,
                      style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5)),
                  const SizedBox(height: 6),
                  // **금액은 계산하지 않는다.** 「N원 더 받아요」라고 하면 그럼
                  // 복식부기 하자가 되는데, 세무대리인 비용이 그 공제를 먹는다.
                  // 앱이 그 비용을 모르는 채로 유리하다고 말할 수 없다.
                  Text(
                      '다만 복식부기는 재무제표를 만들어야 해서 대개 세무대리인을 씁니다. '
                              '기장 대행료가 보통 연 30~50만원이라, 공제액보다 클 수도 있어요. '
                              '견적을 받아 보고 정하세요.'
                          .keepWords,
                      style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.5)),
                ],

                const SizedBox(height: 20),
                AppTheme.hairline(context),

                // ── 간편장부 만들기 ──
                const SizedBox(height: 20),
                Text('$_year년 간편장부'.toUpperCase(), style: AppTheme.label(context)),
                const SizedBox(height: 10),
                if (r == null || r.isEmpty) ...[
                  Text('가계부에 사업 수입이나 사업경비를 기록하면 여기서 장부를 만들어드려요.'.keepWords,
                      style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5)),
                  const SizedBox(height: 14),
                  GestureDetector(
                    // 기록하고 돌아오면 곧바로 장부가 채워져 있어야 한다 —
                    // 다시 읽지 않으면 "기록했는데 그대로"라 길이 끊긴다.
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ExpenseCalendarScreen()));
                      if (mounted) await _load();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(children: [
                      Icon(Icons.edit_calendar_outlined, size: 17, color: accent),
                      const SizedBox(width: 8),
                      Text('가계부에 기록하러 가기'.keepWords,
                          style: AppTheme.sans(AppTheme.tsMD, accent, weight: FontWeight.w700)),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, size: 18, color: accent),
                    ]),
                  ),
                ] else ...[
                  Row(children: [
                    _cell('거래', '${r.rows.length}건', ink, tert),
                    Container(width: 1, height: 40, color: AppTheme.line(context)),
                    _cell('수입', '${comma(r.totalIncome)}원', ink, tert),
                    Container(width: 1, height: 40, color: AppTheme.line(context)),
                    _cell('비용', '${comma(r.totalExpense)}원', ink, tert),
                  ]),
                  const SizedBox(height: 14),
                  Text(
                    '수입은 원천징수 전(세전) 금액으로, 비용은 “사업경비로 인정”한 지출만 담겼어요.'.keepWords,
                    style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.5),
                  ),
                  if (_backfill.bizIncome > 0 || _backfill.bizExpense > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                        '「이전 달 채우기」에 넣은 1~지난달 금액은 장부에 없어요. '
                                '합계로 받은 값이라 거래 한 줄씩으로 쪼갤 수가 없거든요 — '
                                '없는 거래를 지어내면 그게 그대로 신고서에 실립니다. '
                                '그 기간은 통장·카드 내역을 보고 직접 채워 넣으세요.'
                            .keepWords,
                        style: AppTheme.sans(AppTheme.tsXS, AppTheme.colorDanger, height: 1.5)),
                  ],
                  if (r.blankDescriptionCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '거래내용이 빈 줄이 ${r.blankDescriptionCount}건이에요. '
                      '거래처와 함께 직접 채워야 장부로 인정받기 좋아요.'.keepWords,
                      style: AppTheme.sans(AppTheme.tsXS, AppTheme.colorDanger, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _exportCsv,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: accent, width: 1.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.ios_share_rounded, size: 17, color: accent),
                        const SizedBox(width: 8),
                        Text('간편장부 내보내기 (CSV)'.keepWords,
                            style: AppTheme.sans(AppTheme.tsMD, accent, weight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '엑셀에서 열어 거래처·부가세 칸을 채운 뒤 보관하세요. '
                    '홈택스 신고 시 장부 근거가 됩니다.'.keepWords,
                    style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.5),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  '참고용 정리본이에요. 복식부기의무자는 재무제표가 필요해 세무대리인 도움을 권해요.'.keepWords,
                  style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.5),
                ),
              ],
            ),
    );
  }

  /// 올해와 작년 중 고른다. 5월 신고는 작년 장부다.
  Widget _yearPicker(Color ink, Color sub, Color accent) {
    final now = DateTime.now().year;
    return Row(children: [
      for (final y in [now, now - 1])
        Expanded(
          child: GestureDetector(
            onTap: _year == y
                ? null
                : () {
                    setState(() {
                      _year = y;
                      _loading = true;
                    });
                    _load();
                  },
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _year == y ? accent.withValues(alpha: 0.12) : null,
                border: Border.all(
                    color: _year == y ? accent : AppTheme.line(context),
                    width: _year == y ? 1.4 : 1.0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('$y년 장부',
                  style: AppTheme.sans(AppTheme.tsSM, _year == y ? ink : sub,
                      weight: _year == y ? FontWeight.w700 : FontWeight.w500)),
            ),
          ),
        ),
    ]);
  }

  /// 장부 vs 경비율 — 무기장가산세만 말하면 경비율이 유리한 사람도 장부를 쓴다.
  Widget _gainBlock(Color ink, Color sub, Color tert, Color accent) {
    final gain = _bookkeepingGain!;
    final better = gain > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('장부로 신고하면'.toUpperCase(), style: AppTheme.label(context)),
      const SizedBox(height: 10),
      Text(better ? '${comma(gain.round())}원 덜 내요' : '경비율이 더 유리해요',
          style: AppTheme.serif(AppTheme.serifLG, better ? accent : ink,
              weight: FontWeight.w700, spacing: -0.5)),
      const SizedBox(height: 6),
      Text(
          better
              ? '가계부에 적은 사업경비가 업종 경비율보다 커서 그래요. 경비를 더 찾아 적을수록 벌어져요.'
              : '지금은 업종 경비율로 인정받는 경비가 가계부에 적은 것보다 커요. '
                  '그래도 장부는 갖춰 두세요 — 무기장가산세는 그것과 별개예요.',
          style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5)),
      const SizedBox(height: 6),
      Text('${_year}년 기록 기준 추정이에요.',
          style: AppTheme.sans(AppTheme.tsXS, tert)),
    ]);
  }

  Widget _cell(String label, String value, Color ink, Color tert) => Expanded(
        child: Column(children: [
          Text(label, style: AppTheme.sans(AppTheme.tsXS, tert)),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.sans(AppTheme.tsMD, ink, weight: FontWeight.w700)),
        ]),
      );
}
