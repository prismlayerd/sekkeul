import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

/// 퇴직금 계산기
/// 공식: 평균임금 × 30 × (재직일수 ÷ 365)
/// 평균임금 = (최근 3개월 총임금 + 연간상여×3/12 + 연차수당×3/12) ÷ 91일
class SeverancePayScreen extends StatefulWidget {
  const SeverancePayScreen({super.key});

  @override
  State<SeverancePayScreen> createState() => _SeverancePayScreenState();
}

class _SeverancePayScreenState extends State<SeverancePayScreen> {
  DateTime? _joinDate;
  DateTime? _leaveDate;
  final TextEditingController _threeMonthController = TextEditingController();
  final TextEditingController _bonusController = TextEditingController();
  final TextEditingController _leaveAllowanceController =
      TextEditingController();
  final _fmt = NumberFormat('#,###');

  void _reset() {
    setState(() {
      _joinDate = null;
      _leaveDate = null;
      _threeMonthController.clear();
      _bonusController.clear();
      _leaveAllowanceController.clear();
    });
  }

  @override
  void dispose() {
    _threeMonthController.dispose();
    _bonusController.dispose();
    _leaveAllowanceController.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

  String _won(double v) => v <= 0 ? '0원' : '${_fmt.format(v.round())}원';
  String _manwon(double v) {
    if (v <= 0) return '0원';
    final man = (v / 10000).round();
    return '${_fmt.format(man)}만원';
  }

  Future<void> _pickDate(bool isJoin) async {
    final initial = isJoin
        ? (_joinDate ?? DateTime(2020))
        : (_leaveDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2099),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() {
        if (isJoin) {
          _joinDate = picked;
        } else {
          _leaveDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;
    final dateFmt = DateFormat('yyyy.MM.dd');

    final threeMonthPay = _parse(_threeMonthController);
    final bonus = _parse(_bonusController);
    final leaveAllowance = _parse(_leaveAllowanceController);

    int? workDays;
    double? avgDailyWage;
    double? severance;

    if (_joinDate != null &&
        _leaveDate != null &&
        _leaveDate!.isAfter(_joinDate!)) {
      workDays = _leaveDate!.difference(_joinDate!).inDays;
      const threeMoDays = 91;
      final totalThreeMonth =
          threeMonthPay + bonus * 3 / 12 + leaveAllowance * 3 / 12;
      if (totalThreeMonth > 0) {
        avgDailyWage = totalThreeMonth / threeMoDays;
        if (workDays >= 365) {
          severance = avgDailyWage * 30 * workDays / 365;
        }
      }
    }

    final hasInput =
        _joinDate != null && _leaveDate != null && threeMonthPay > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('퇴직금 계산기',
            style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
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
            Text('퇴직 시 받을 수 있는\n퇴직금을 계산해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('1년 이상 근무한 근로자에게 지급됩니다.'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            // 근무 기간
            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('근무 기간',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _dateTile('입사일', _joinDate, () => _pickDate(true), dateFmt,
                      textColor, subColor),
                  const SizedBox(height: 10),
                  _dateTile('퇴직일', _leaveDate, () => _pickDate(false),
                      dateFmt, textColor, subColor),
                  if (workDays != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            (workDays >= 365 ? primary : Colors.orange)
                                .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(
                          workDays >= 365
                              ? Icons.check_circle_outline_rounded
                              : Icons.warning_amber_rounded,
                          color: workDays >= 365 ? primary : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          workDays >= 365
                              ? '총 ${_fmt.format(workDays)}일 근무 — 퇴직금 발생'
                              : '총 ${_fmt.format(workDays)}일 — 1년 미만 (퇴직금 미발생)',
                          style: TextStyle(
                            color: workDays >= 365
                                ? primary
                                : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 임금 정보
            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('임금 정보',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _inputField('최근 3개월 총 급여', _threeMonthController,
                      '기본급+수당 포함, 상여 제외', subColor),
                  const SizedBox(height: 16),
                  _inputField('연간 상여금 총액', _bonusController,
                      '명절·성과급 등 연간 합산 (없으면 0)', subColor),
                  const SizedBox(height: 16),
                  _inputField('연차수당 총액', _leaveAllowanceController,
                      '미사용 연차 보상액 (없으면 0)', subColor),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 결과
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getAccentCardDecoration(context,
                  borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text('예상 퇴직금',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    severance != null
                        ? _manwon(severance)
                        : (hasInput && workDays != null && workDays < 365)
                            ? '해당 없음'
                            : '0원',
                    style: TextStyle(
                        color: primary,
                        fontSize: 32,
                        fontWeight: FontWeight.w900),
                  ),
                  if (severance != null && workDays != null && workDays < 365)
                    Text('1년 미만 — 퇴직금 미발생',
                        style: TextStyle(color: Colors.orange, fontSize: 12)),
                  const SizedBox(height: 16),
                  if (severance != null && avgDailyWage != null) ...[
                    _row('1일 평균임금', _won(avgDailyWage), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('재직일수', '${_fmt.format(workDays)}일', subColor,
                        textColor),
                    const SizedBox(height: 12),
                    Divider(
                        color: Theme.of(context).dividerColor,
                        height: 1,
                        thickness: 1),
                    const SizedBox(height: 12),
                    _row('세전 퇴직금', _won(severance), subColor, primary),
                  ] else if (!hasInput)
                    Text('날짜와 급여 정보를 입력해보세요.'.keepWords,
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
                    '• 퇴직금 = 평균임금 × 30 × (재직일수 ÷ 365)\n'
                    '• 1년 이상 근무 + 주 15시간 이상이어야 발생합니다.\n'
                    '• 평균임금이 통상임금보다 낮으면 통상임금이 적용됩니다.\n'
                    '• IRP 계좌 수령 시 퇴직소득세 과세이연 혜택이 있습니다.',
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

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap,
      DateFormat fmt, Color textColor, Color subColor) {
    return Row(children: [
      SizedBox(
        width: 52,
        child: Text(label,
            style: TextStyle(color: subColor, fontSize: 14)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  date != null ? fmt.format(date) : '날짜 선택',
                  style: TextStyle(
                      color: date != null ? textColor : subColor,
                      fontSize: 15),
                ),
              ),
              Icon(Icons.calendar_today_rounded, color: subColor, size: 16),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _inputField(String label, TextEditingController controller,
      String hint, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: subColor, fontSize: 14)),
        const SizedBox(height: 2),
        Text(hint,
            style: TextStyle(
                color: subColor.withValues(alpha: 0.7), fontSize: 11)),
        const SizedBox(height: 4),
        AmountField(
            controller: controller,
            expand: true,
            onChanged: (_) => setState(() {})),
      ],
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
