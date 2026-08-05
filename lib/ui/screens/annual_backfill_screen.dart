import 'package:flutter/material.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/expense_item.dart';
import '../../core/data/income_entry.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

/// 연중 가입 사용자를 위한 1~N월 소급 입력 — 간단히 결제수단·소득유형별 총액만 받는다.
/// 실제 expenses/income_entries에 매달 1건씩 기록(카테고리는 세분화하지 않음).
class AnnualBackfillScreen extends StatefulWidget {
  final String userType;

  const AnnualBackfillScreen({super.key, required this.userType});

  @override
  State<AnnualBackfillScreen> createState() => _AnnualBackfillScreenState();
}

class _MonthRow {
  final int month;
  final bool hasData; // 이미 실제 기록이 있어 입력 대상에서 제외
  final TextEditingController labor = TextEditingController();
  final TextEditingController business = TextEditingController();
  final TextEditingController other = TextEditingController();
  final TextEditingController credit = TextEditingController();
  final TextEditingController debit = TextEditingController();
  final TextEditingController etc = TextEditingController();
  _MonthRow(this.month, this.hasData);
}

class _AnnualBackfillScreenState extends State<AnnualBackfillScreen> {
  bool _loading = true;
  List<_MonthRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final allExpenses = await dbService.getExpenses(userType: widget.userType);
    final rows = <_MonthRow>[];
    for (int m = 1; m < now.month; m++) {
      final hasExpense = allExpenses.any((e) => e.date.year == now.year && e.date.month == m);
      final incomeEntries = await dbService.getIncomeEntriesForMonth(now.year, m, userType: widget.userType);
      rows.add(_MonthRow(m, hasExpense || incomeEntries.isNotEmpty));
    }
    if (mounted) setState(() { _rows = rows; _loading = false; });
  }

  int _num(TextEditingController c) => int.tryParse(c.text.replaceAll(',', '')) ?? 0;

  Future<void> _save() async {
    final now = DateTime.now();
    for (final row in _rows) {
      if (row.hasData) continue;
      final date = DateTime(now.year, row.month, 1);
      final labor = _num(row.labor);
      final business = _num(row.business);
      final other = _num(row.other);
      final credit = _num(row.credit);
      final debit = _num(row.debit);
      final etc = _num(row.etc);
      if (labor > 0) {
        await dbService.insertIncomeEntry(IncomeEntry(
            id: 'backfill_${now.year}_${row.month}_labor',
            date: date, amount: labor, memo: '소급 입력', incomeType: '급여',
            userType: widget.userType));
      }
      if (business > 0) {
        await dbService.insertIncomeEntry(IncomeEntry(
            id: 'backfill_${now.year}_${row.month}_business',
            date: date, amount: business, memo: '소급 입력', incomeType: '사업소득',
            userType: widget.userType));
      }
      if (other > 0) {
        await dbService.insertIncomeEntry(IncomeEntry(
            id: 'backfill_${now.year}_${row.month}_other',
            date: date, amount: other, memo: '소급 입력', incomeType: '기타소득',
            userType: widget.userType));
      }
      if (credit > 0) {
        await dbService.insertExpense(ExpenseItem(
            id: 'backfill_${now.year}_${row.month}_credit',
            date: date, amount: credit, content: '소급 입력', category: '기타', paymentMethod: '신용카드',
            userType: widget.userType));
      }
      if (debit > 0) {
        await dbService.insertExpense(ExpenseItem(
            id: 'backfill_${now.year}_${row.month}_debit',
            date: date, amount: debit, content: '소급 입력', category: '기타', paymentMethod: '체크+현금',
            userType: widget.userType));
      }
      if (etc > 0) {
        await dbService.insertExpense(ExpenseItem(
            id: 'backfill_${now.year}_${row.month}_etc',
            date: date, amount: etc, content: '소급 입력', category: '기타', paymentMethod: '기타',
            userType: widget.userType));
      }
    }
    await dbService.setAppState('annual_backfill_done_${now.year}', 'true');
    if (mounted) Navigator.pop(context, true);
  }


  Widget _field(String label, TextEditingController c) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: const [ThousandsFormatter()],
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            isDense: true,
            labelText: label,
            labelStyle: AppTheme.sans(11, AppTheme.inkTertiary(context)),
            border: const OutlineInputBorder(),
          ),
          style: AppTheme.sans(13, AppTheme.ink(context)),
          onChanged: (v) {
            final n = v.replaceAll(',', '');
            if (n.isEmpty) return;
            final parsed = int.tryParse(n);
            if (parsed == null) return;
            final f = comma(parsed);
            if (f != c.text) {
              c.value = TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text('올해 간단 입력', style: AppTheme.sans(16, ink, weight: FontWeight.w700)),
      ),
      body: _loading
          ? const SizedBox.shrink()
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    '연초부터 기록이 없으면 이번 달 판정이 부정확해질 수 있어요. '
                    '간단하게 달마다 수입·지출 총액만 입력해두면 정확도가 올라가요. 몰라도 건너뛰어도 괜찮아요.',
                    style: AppTheme.sans(13, sub),
                  ),
                  const SizedBox(height: 20),
                  for (final row in _rows) ...[
                    if (row.hasData)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text('${row.month}월 — 이미 기록 있음'.keepWords, style: AppTheme.sans(13, tert)),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${row.month}월', style: AppTheme.sans(14, ink, weight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Row(children: [
                              _field('급여수입', row.labor),
                              _field('사업소득', row.business),
                              _field('기타소득', row.other),
                            ]),
                            const SizedBox(height: 6),
                            Row(children: [
                              _field('카드지출', row.credit),
                              _field('체크·현금', row.debit),
                              _field('기타지출', row.etc),
                            ]),
                          ],
                        ),
                      ),
                    Divider(color: AppTheme.line(context)),
                  ],
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(4)),
                      child: Text('저장',
                          style: AppTheme.sans(14, AppTheme.backgroundColor(context), weight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
