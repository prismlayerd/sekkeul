import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/income_entry.dart';
import '../../core/data/occupation_data.dart';
import '../../core/tax_engine/bookkeeping_duty.dart';
import '../../core/tax_engine/simple_ledger_builder.dart';
import 'expense_calendar_screen.dart';

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
  final _fmt = NumberFormat('#,###');
  final int _year = DateTime.now().year;
  SimpleLedgerResult? _result;
  BookkeepingJudgment? _judgment;
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

    if (!mounted) return;
    setState(() {
      _judgment = judgment;
      _result = result;
      _loading = false;
    });
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
      content: Text(msg, style: AppTheme.sans(13, Colors.white)),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        titleSpacing: 16,
        title: Text('장부 만들기',
            style: AppTheme.serif(17, ink, weight: FontWeight.w400, spacing: -0.5)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // ── 내 기장의무 ──
                Text('내 기장의무'.toUpperCase(), style: AppTheme.label(context)),
                const SizedBox(height: 10),
                if (_judgment == null)
                  Text('업종코드를 설정하면 기장의무를 알려드려요.',
                      style: AppTheme.sans(13, sub, height: 1.5))
                else ...[
                  Text(_judgment!.isDoubleEntry ? '복식부기의무자' : '간편장부대상자',
                      style: AppTheme.serif(24, ink, weight: FontWeight.w700, spacing: -0.5)),
                  const SizedBox(height: 6),
                  Text(_judgment!.reason, style: AppTheme.sans(13, sub, height: 1.5)),
                ],
                const SizedBox(height: 20),
                AppTheme.hairline(context),

                // ── 가산세 ──
                const SizedBox(height: 20),
                Text('장부가 없으면'.toUpperCase(), style: AppTheme.label(context)),
                const SizedBox(height: 10),
                Text('산출세액의 20%',
                    style: AppTheme.serif(28, AppTheme.colorDanger,
                        weight: FontWeight.w700, spacing: -0.8)),
                const SizedBox(height: 6),
                Text(
                  '무기장가산세(소득세법 §81의5). 장부를 갖추면 붙지 않아요.\n'
                  '신규사업자이거나 직전연도 수입이 4,800만원 미만이면 면제됩니다.',
                  style: AppTheme.sans(13, sub, height: 1.5),
                ),
                if (_judgment?.isSmallBusinessExemptFromPenalty == true) ...[
                  const SizedBox(height: 8),
                  Text('→ 지금은 면제 대상이에요.',
                      style: AppTheme.sans(13, accent, weight: FontWeight.w700)),
                ],
                const SizedBox(height: 20),
                AppTheme.hairline(context),

                // ── 간편장부 만들기 ──
                const SizedBox(height: 20),
                Text('$_year년 간편장부'.toUpperCase(), style: AppTheme.label(context)),
                const SizedBox(height: 10),
                if (r == null || r.isEmpty) ...[
                  Text('가계부에 사업 수입이나 사업경비를 기록하면 여기서 장부를 만들어드려요.',
                      style: AppTheme.sans(13, sub, height: 1.5)),
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
                      Text('가계부에 기록하러 가기',
                          style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, size: 18, color: accent),
                    ]),
                  ),
                ] else ...[
                  Row(children: [
                    _cell('거래', '${r.rows.length}건', ink, tert),
                    Container(width: 1, height: 40, color: AppTheme.line(context)),
                    _cell('수입', '${_fmt.format(r.totalIncome)}원', ink, tert),
                    Container(width: 1, height: 40, color: AppTheme.line(context)),
                    _cell('비용', '${_fmt.format(r.totalExpense)}원', ink, tert),
                  ]),
                  const SizedBox(height: 14),
                  Text(
                    '수입은 원천징수 전(세전) 금액으로, 비용은 “사업경비로 인정”한 지출만 담겼어요.',
                    style: AppTheme.sans(12, tert, height: 1.5),
                  ),
                  if (r.blankDescriptionCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '거래내용이 빈 줄이 ${r.blankDescriptionCount}건이에요. '
                      '거래처와 함께 직접 채워야 장부로 인정받기 좋아요.',
                      style: AppTheme.sans(12, AppTheme.colorDanger, height: 1.5),
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
                        Text('간편장부 내보내기 (CSV)',
                            style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '엑셀에서 열어 거래처·부가세 칸을 채운 뒤 보관하세요. '
                    '홈택스 신고 시 장부 근거가 됩니다.',
                    style: AppTheme.sans(12, tert, height: 1.5),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  '참고용 정리본이에요. 복식부기의무자는 재무제표가 필요해 세무대리인 도움을 권해요.',
                  style: AppTheme.sans(11.5, tert, height: 1.5),
                ),
              ],
            ),
    );
  }

  Widget _cell(String label, String value, Color ink, Color tert) => Expanded(
        child: Column(children: [
          Text(label, style: AppTheme.sans(11, tert)),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.sans(14, ink, weight: FontWeight.w700)),
        ]),
      );
}
