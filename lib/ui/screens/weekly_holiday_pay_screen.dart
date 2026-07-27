import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

/// 주휴수당 · 최저임금 계산기 (2026년 기준)
/// 최저임금: 10,320원/시간
/// 주휴수당: 1주 소정근로시간 ÷ 40 × 8 × 시급 (주 15시간 이상 조건)
class WeeklyHolidayPayScreen extends StatefulWidget {
  const WeeklyHolidayPayScreen({super.key});

  @override
  State<WeeklyHolidayPayScreen> createState() =>
      _WeeklyHolidayPayScreenState();
}

class _WeeklyHolidayPayScreenState extends State<WeeklyHolidayPayScreen> {
  final TextEditingController _hourlyController = TextEditingController();
  final TextEditingController _dailyHoursController =
      TextEditingController(text: '8');
  int _workDaysPerWeek = 5;
  final _fmt = NumberFormat('#,###');

  static const double _minimumWage2026 = 10320.0;

  void _reset() {
    setState(() {
      _hourlyController.clear();
      _dailyHoursController.text = '8';
      _workDaysPerWeek = 5;
    });
  }

  @override
  void dispose() {
    _hourlyController.dispose();
    _dailyHoursController.dispose();
    super.dispose();
  }

  double get _hourlyWage =>
      double.tryParse(_hourlyController.text.replaceAll(',', '')) ?? 0.0;

  double get _dailyHours =>
      double.tryParse(_dailyHoursController.text.replaceAll(',', '')) ?? 0.0;

  String _won(double v) => v <= 0 ? '0원' : '${_fmt.format(v.round())}원';

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;

    final hourly = _hourlyWage;
    final dailyHours = _dailyHours.clamp(0.0, 8.0);
    final weeklyHours = dailyHours * _workDaysPerWeek;

    final bool hasInput = hourly > 0 && dailyHours > 0;
    final bool qualifiesForHoliday = weeklyHours >= 15;

    // 주휴수당 = (주근로시간 ÷ 40) × 8 × 시급
    final holidayPay =
        qualifiesForHoliday ? (weeklyHours / 40) * 8 * hourly : 0.0;

    final weeklyPay = hourly * weeklyHours + holidayPay;
    final monthlyPay = weeklyPay * 52 / 12;

    final bool belowMinWage = hourly > 0 && hourly < _minimumWage2026;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('주휴수당 · 최저임금',
            style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 20, color: subColor),
            tooltip: '초기화',
            onPressed: _reset,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('아르바이트 급여,\n주휴수당까지 확인해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('주 15시간 이상 일하면 주휴수당이 발생합니다. (2026 최저임금 10,320원)'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: primary, size: 18),
                const SizedBox(width: 10),
                Text('2026년 최저임금 시급 10,320원'.keepWords,
                    style: TextStyle(
                        color: primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('시급',
                      style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 4),
                  AmountField(
                    controller: _hourlyController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (belowMinWage) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_rounded,
                            color: Colors.redAccent, size: 14),
                        const SizedBox(width: 6),
                        Text('최저임금 미달 (10,320원 이상이어야 합니다)'.keepWords,
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('하루 근무시간',
                      style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _dailyHoursController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      suffixText: '시간',
                      suffixStyle:
                          TextStyle(color: subColor, fontSize: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Theme.of(context).dividerColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Theme.of(context).dividerColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: primary, width: 1.5)),
                    ),
                    style: TextStyle(color: textColor, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Text('주 근무일수',
                      style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final selected = _workDaysPerWeek == day;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _workDaysPerWeek = day),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: selected
                                ? primary
                                : primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text('$day일',
                              style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : subColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getAccentCardDecoration(context,
                  borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.payments_outlined, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text('주휴수당 포함 주급',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(hasInput ? _won(weeklyPay) : '0원',
                      style: TextStyle(
                          color: primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (hasInput) ...[
                    _row('주 근로시간',
                        '${weeklyHours.toStringAsFixed(1)}시간', subColor,
                        textColor),
                    const SizedBox(height: 8),
                    _row('주 근로 수당', _won(hourly * weeklyHours), subColor,
                        textColor),
                    const SizedBox(height: 8),
                    _row(
                      qualifiesForHoliday
                          ? '주휴수당'
                          : '주휴수당 (주 15h 미만 — 미발생)',
                      _won(holidayPay),
                      subColor,
                      qualifiesForHoliday ? primary : subColor,
                    ),
                    const SizedBox(height: 12),
                    Divider(
                        color: Theme.of(context).dividerColor,
                        height: 1,
                        thickness: 1),
                    const SizedBox(height: 12),
                    _row('월 예상 수령액 (52주÷12 기준)',
                        _won(monthlyPay), subColor, primary),
                  ] else
                    Text('시급과 근무조건을 입력해보세요.'.keepWords,
                        style: TextStyle(color: subColor, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: subColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        color: subColor, size: 16),
                    const SizedBox(width: 6),
                    Text('알아두기',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '• 주 15시간 이상 근무 시 주휴수당이 발생합니다.\n'
                    '• 주휴수당 = (주 근로시간 ÷ 40) × 8 × 시급\n'
                    '• 최저임금 미달 시 사업주가 법적 책임을 집니다.\n'
                    '• 하루 근무시간 8시간 초과분은 계산에서 제외했습니다.',
                    style: TextStyle(
                        color: subColor, fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
            const CalcDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _row(
          String label, String value, Color labelColor, Color valueColor) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(color: labelColor, fontSize: 13))),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      );
}
