import 'package:flutter/material.dart';
import '../../core/tax_engine/tax_rates.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';

/// 2025→2026 최저임금 인상(10,030원→10,320원, +290원/+2.9%)이
/// 근로자 급여에 미치는 영향을 추정하는 계산기.
class MinimumWageImpactScreen extends StatefulWidget {
  const MinimumWageImpactScreen({super.key});

  @override
  State<MinimumWageImpactScreen> createState() =>
      _MinimumWageImpactScreenState();
}

class _MinimumWageImpactScreenState extends State<MinimumWageImpactScreen> {
  final _hoursCtrl = TextEditingController(text: '40');
  final _fmt = NumberFormat('#,###');

  static int get _wage2025 => TaxRates.minimumHourlyWage2025.toInt();
  static int get _wage2026 => TaxRates.minimumHourlyWage2026.toInt();
  static int get _hourlyDiff => _wage2026 - _wage2025;
  static double get _raiseRate => (_hourlyDiff / _wage2025) * 100;

  double get _weeklyHours => double.tryParse(_hoursCtrl.text.replaceAll(',', '')) ?? 0;
  bool get _hasWeeklyHoliday => _weeklyHours >= 15;

  double get _weeklyPaidHours =>
      _hasWeeklyHoliday ? _weeklyHours * 1.2 : _weeklyHours;
  double get _monthlyPaidHours => _weeklyPaidHours * 4.345;

  double get _monthlyExtra => _monthlyPaidHours * _hourlyDiff;
  double get _yearlyExtra => _monthlyExtra * 12;

  bool get _hasInput => _weeklyHours > 0;

  String _won(double v) => '${_fmt.format(v.round())}원';

  @override
  void dispose() {
    _hoursCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    final bg = AppTheme.surface(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        title: Text('최저임금 인상 영향',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('주 근무시간',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _hoursCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTheme.sans(14, ink),
              decoration: InputDecoration(
                suffixText: '시간',
                suffixStyle: AppTheme.sans(14, sub),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: line)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: line)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: ink)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 32),
            if (_hasInput) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('2025→2026 인상 영향',
                        style:
                            AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('월 추가 수입',
                            style: AppTheme.sans(14, ink,
                                weight: FontWeight.w700)),
                        Text('+${_won(_monthlyExtra)}',
                            style: AppTheme.sans(16, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('연 추가 수입', '+${_won(_yearlyExtra)}', ink, sub),
                    const SizedBox(height: 8),
                    _row('인상률', '+${_raiseRate.toStringAsFixed(1)}%', ink, sub),
                    const SizedBox(height: 8),
                    _row('유급 월 근무시간', '${_monthlyPaidHours.toStringAsFixed(1)}시간',
                        ink, sub),
                    const SizedBox(height: 12),
                    Text(
                        _hasWeeklyHoliday
                            ? '* 주 15시간 이상 근무로 주휴수당이 포함된 계산입니다.'
                            : '* 주 15시간 미만은 주휴수당이 적용되지 않습니다.',
                        style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '2026년 최저임금',
              [
                '시급 10,320원 (2025년 10,030원 대비 +290원, +2.9%)',
                '월급(주 40시간, 월 209시간 기준): 2,156,880원',
                '연환산: 약 25,882,560원',
                '실질 시급(주휴 포함 환산): 약 12,414원',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '예외 규정',
              [
                '수습 3개월: 최저임금 90% 감액 가능(1년 이상 계약만 해당)',
                '단순노무직: 감액 불가',
                '주 15시간 미만: 주휴수당·퇴직금·연차 미적용',
                '위반 시 3년 이하 징역 또는 2천만원 이하 벌금',
              ],
              line,
              sub,
              ink,
            ),
            const CalcDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color ink, Color sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: AppTheme.sans(13, sub))),
        Text(value, style: AppTheme.sans(13, ink, weight: FontWeight.w600)),
      ],
    );
  }

  Widget _infoBox(
      String title, List<String> items, Color line, Color sub, Color ink) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: AppTheme.sans(13, sub)),
                Expanded(
                    child: Text(item,
                        style: AppTheme.sans(13, sub, height: 1.5))),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
