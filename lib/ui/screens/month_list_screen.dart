import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/data/expense_category.dart';
import '../../core/data/expense_item.dart';
import '../../core/data/income_entry.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

const _incomeColor = Color(0xFF5CB87A); // 수익 — soft green

/// 이번 달 기록을 날짜 역순으로 나열하는 전체화면 — 가계부 달력의 월 라벨을 탭하면 진입.
/// 캘린더가 이미 로드해둔 데이터를 그대로 받아 표시만 하는 읽기 전용 화면.
class MonthListScreen extends StatelessWidget {
  final int year;
  final int month;
  final Map<String, List<ExpenseItem>> expensesByDay;
  final Map<String, List<IncomeEntry>> incomesByDay;

  const MonthListScreen({
    super.key,
    required this.year,
    required this.month,
    required this.expensesByDay,
    required this.incomesByDay,
  });

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _incomeTypeLabel(String type) {
    switch (type) {
      case '급여': return '근로소득';
      case '사업소득': return '사업소득';
      case '기타소득': return '기타소득';
      default: return '기타 수익';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.backgroundColor(context);
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final fmt = NumberFormat('#,###');

    final allUniqueExp = expensesByDay.values.expand((l) => l).toSet().toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final allUniqueInc = incomesByDay.values.expand((l) => l).toSet().toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final dayKeys = <String>{
      ...allUniqueExp.map((e) => _key(e.date)),
      ...allUniqueInc.map((e) => _key(e.date)),
    };
    final sortedDays = dayKeys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        title: Text('$year년 $month월 기록'.keepWords, style: AppTheme.serif(22, ink)),
      ),
      body: SafeArea(
        child: sortedDays.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined, size: 36, color: AppTheme.inkTertiary(context)),
                  const SizedBox(height: 12),
                  Text('이번 달 기록이 없어요',
                      style: AppTheme.sans(15, AppTheme.inkTertiary(context), weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('달력에서 날짜를 탭해 입력하세요.'.keepWords,
                      style: AppTheme.sans(13, AppTheme.inkTertiary(context))),
                ]),
              )
            : _buildList(context, sortedDays, allUniqueExp, allUniqueInc, ink, sub, fmt),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<String> sortedDays,
    List<ExpenseItem> allUniqueExp,
    List<IncomeEntry> allUniqueInc,
    Color ink,
    Color sub,
    NumberFormat fmt,
  ) {
    final tert = AppTheme.inkTertiary(context);
    const wd = ['월', '화', '수', '목', '금', '토', '일'];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: sortedDays.length,
      itemBuilder: (context, idx) {
        final key = sortedDays[idx];
        final day = DateTime.parse(key);
        final exps = allUniqueExp.where((e) => _key(e.date) == key).toList();
        final incs = allUniqueInc.where((e) => _key(e.date) == key).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (idx > 0) const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text('${day.month}월 ${day.day}일'.keepWords,
                      style: AppTheme.sans(13, ink, weight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text('(${wd[day.weekday - 1]})'.keepWords, style: AppTheme.sans(12, tert)),
                ],
              ),
            ),
            AppTheme.hairline(context),
            for (final inc in incs) _incomeRow(context, inc, ink, sub, tert, fmt),
            for (final exp in exps) _expenseRow(context, exp, ink, sub, tert, fmt),
          ],
        );
      },
    );
  }

  Widget _incomeRow(BuildContext context, IncomeEntry entry, Color ink, Color sub, Color tert, NumberFormat fmt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _incomeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.add_rounded, size: 16, color: _incomeColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(_incomeTypeLabel(entry.incomeType),
                    style: AppTheme.sans(14, ink, weight: FontWeight.w600)),
                if (entry.isWithheld) ...[
                  const SizedBox(width: 6),
                  _miniTag(context, entry.incomeType == '기타소득' ? '8.8%' : '3.3%', sub),
                ],
              ],
            ),
          ),
          Text('+${fmt.format(entry.amount)}원',
              style: AppTheme.sans(14, _incomeColor, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _expenseRow(BuildContext context, ExpenseItem exp, Color ink, Color sub, Color tert, NumberFormat fmt) {
    final cat = expenseCategoryById(exp.category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(cat.icon, size: 15, color: cat.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(cat.label, style: AppTheme.sans(14, ink, weight: FontWeight.w600)),
                    if (exp.isBusiness) ...[
                      const SizedBox(width: 6),
                      _miniTag(context, '사업경비', sub),
                    ],
                  ],
                ),
                Text(exp.paymentMethod, style: AppTheme.sans(12, tert)),
              ],
            ),
          ),
          Text('-${fmt.format(exp.amount)}원',
              style: AppTheme.sans(14, sub, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _miniTag(BuildContext context, String text, Color sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line(context)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: AppTheme.sans(10, sub, weight: FontWeight.w600)),
    );
  }
}
