import 'package:flutter/material.dart';
import '../../core/tax_engine/tax_rates.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

/// 실업급여(구직급여) 계산기
/// 일액 = 평균임금 × 60%, 하한 66,048원, 상한 68,100원
/// 지급기간: 나이·피보험기간 기준 120~270일
class UnemploymentBenefitScreen extends StatefulWidget {
  const UnemploymentBenefitScreen({super.key});

  @override
  State<UnemploymentBenefitScreen> createState() =>
      _UnemploymentBenefitScreenState();
}

class _UnemploymentBenefitScreenState
    extends State<UnemploymentBenefitScreen> {
  final TextEditingController _wageController = TextEditingController();
  int _insuredMonths = 12;
  bool _isOver50 = false;
  bool _isDisabled = false;

  // 2026년 기준
  // 하한은 최저임금에서 파생된다 — 최저임금만 갱신하면 따라 움직인다.
  static const double _minDailyLimit = TaxRates.unemploymentDailyFloor;
  /// 구직급여 상한액 — 2026.1.1. 이후 이직자부터 66,000원 → 68,100원.
  /// 2019년 이후 6년 만의 인상이고, 사유는 최저임금 인상으로 **하한이 종전 상한을
  /// 넘어섰기** 때문이다(하한 66,048 = 10,320 × 8 × 80% > 66,000).
  /// 상한과 하한이 이렇게 맞물리므로 최저임금이 오르면 상한도 함께 확인해야 한다.
  /// 추적: test/notice_expiry_test.dart (1차 자료 미확인 상태로 기록돼 있다)
  static const double _maxDailyLimit = 68100.0;

  void _reset() {
    setState(() {
      _wageController.clear();
      _insuredMonths = 12;
      _isOver50 = false;
      _isDisabled = false;
    });
  }

  @override
  void dispose() {
    _wageController.dispose();
    super.dispose();
  }

  double _parse() =>
      double.tryParse(_wageController.text.replaceAll(',', '')) ?? 0.0;

  String _won(double v) => v <= 0 ? '0원' : '${comma(v.round())}원';
  String _manwon(double v) {
    if (v <= 0) return '0원';
    final man = (v / 10000).round();
    return '${comma(man)}만원';
  }

  int _benefitDays(int months, bool over50orDisabled) {
    if (months < 12) return 0;
    if (months < 36) return over50orDisabled ? 180 : 150;
    if (months < 60) return over50orDisabled ? 210 : 180;
    if (months < 120) return over50orDisabled ? 240 : 210;
    return over50orDisabled ? 270 : 240;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;

    final monthlyWage = _parse();
    final hasInput = monthlyWage > 0;
    final bool qualified = _insuredMonths >= 12;
    final bool over50orDisabled = _isOver50 || _isDisabled;

    double? dailyWage;
    double? benefitDaily;
    int benefitDays = 0;
    double? totalBenefit;

    if (hasInput) {
      dailyWage = monthlyWage / 30.0;
      final raw = dailyWage * 0.6;
      benefitDaily = raw.clamp(_minDailyLimit, _maxDailyLimit);
      benefitDays = _benefitDays(_insuredMonths, over50orDisabled);
      if (qualified) {
        totalBenefit = benefitDaily * benefitDays;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('실업급여 계산기',
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
            Text('실직 후 받을 수 있는\n구직급여를 계산해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('고용보험 피보험기간 12개월 이상이어야 수급 자격이 있습니다.'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            // 임금 입력
            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('퇴직 전 월 평균임금',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('최근 3개월 합계를 3으로 나눈 월 평균'.keepWords,
                      style: TextStyle(
                          color: subColor.withValues(alpha: 0.7),
                          fontSize: 11)),
                  const SizedBox(height: 8),
                  AmountField(
                    controller: _wageController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (hasInput && dailyWage != null && benefitDaily != null) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.calculate_outlined,
                          size: 14, color: subColor),
                      const SizedBox(width: 6),
                      Text(
                        '일 평균임금 ${_won(dailyWage)}  →  구직급여 일액 ${_won(benefitDaily)}'.keepWords,
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 피보험 기간
            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('고용보험 피보험 기간',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _insuredSelector(subColor, primary, textColor),
                  const SizedBox(height: 16),
                  _toggleRow('50세 이상', _isOver50,
                      (v) => setState(() => _isOver50 = v), textColor),
                  const SizedBox(height: 4),
                  _toggleRow('장애인', _isDisabled,
                      (v) => setState(() => _isDisabled = v), textColor),
                  if (!qualified) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text('피보험기간 12개월 미만 — 수급 자격 없음'.keepWords,
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ],
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
                    Text('예상 수급 총액',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    totalBenefit != null
                        ? _manwon(totalBenefit)
                        : (!qualified && hasInput)
                            ? '해당 없음'
                            : '0원',
                    style: TextStyle(
                        color: primary,
                        fontSize: 32,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  if (totalBenefit != null && benefitDaily != null) ...[
                    _row('구직급여 일액', _won(benefitDaily), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('지급기간', '$benefitDays일', subColor, textColor),
                    const SizedBox(height: 8),
                    _row('월 환산 수령액 (×30)',
                        _won(benefitDaily * 30), subColor, textColor),
                    const SizedBox(height: 12),
                    Divider(
                        color: Theme.of(context).dividerColor,
                        height: 1,
                        thickness: 1),
                    const SizedBox(height: 12),
                    _row('합계', _won(totalBenefit), subColor, primary),
                  ] else if (!hasInput)
                    Text('임금과 피보험기간을 입력해보세요.'.keepWords,
                        style: TextStyle(color: subColor, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _benefitTable(context, textColor, subColor, primary),
            const SizedBox(height: 16),

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
                    '• 비자발적 이직(권고사직·계약만료 등)이어야 수급 가능합니다.\n'
                    '• 구직급여 일액 하한: ${comma(_minDailyLimit.round())}원, 상한: ${comma(_maxDailyLimit.round())}원 (2026년)\n'
                    '• 실제 지급은 고용센터 신청·실업인정일 기준입니다.\n'
                    '• 이직 전 18개월 중 피보험단위기간 180일 이상 필요합니다.',
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

  Widget _insuredSelector(Color subColor, Color primary, Color textColor) {
    final labels = ['6m', '12m', '18m', '24m', '36m', '48m', '60m', '10y+'];
    final values = [6, 12, 18, 24, 36, 48, 60, 120];
    final idx = values.indexOf(_insuredMonths).clamp(0, values.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 칩 8개는 360px 화면에 한 줄로 못 들어간다 — 넘치면 다음 줄로 접는다.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: labels.asMap().entries.map((e) {
            final selected = idx == e.key;
            return GestureDetector(
              onTap: () => setState(() => _insuredMonths = values[e.key]),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? primary
                      : primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(e.value,
                    style: TextStyle(
                        color: selected ? Colors.white : subColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text('선택: $_insuredMonths개월'.keepWords,
            style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _toggleRow(
      String label, bool value, ValueChanged<bool> onChanged, Color textColor) {
    return Row(children: [
      Expanded(
          child: Text(label,
              style: TextStyle(color: textColor, fontSize: 14))),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).primaryColor,
      ),
    ]);
  }

  Widget _benefitTable(BuildContext context, Color textColor, Color subColor,
      Color primary) {
    final rows = [
      ['1년 미만', '수급 불가', '수급 불가'],
      ['1~3년', '150일', '180일'],
      ['3~5년', '180일', '210일'],
      ['5~10년', '210일', '240일'],
      ['10년 이상', '240일', '270일'],
    ];
    return Container(
      decoration: AppTheme.getCardDecoration(context, borderRadius: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              Expanded(
                  flex: 2,
                  child: Text('피보험기간',
                      style: TextStyle(
                          color: subColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  child: Text('~50세',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: subColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  child: Text('50세+/장애',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: subColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
            ]),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          ...rows.map((r) => Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(children: [
                    Expanded(
                        flex: 2,
                        child: Text(r[0],
                            style:
                                TextStyle(color: textColor, fontSize: 13))),
                    Expanded(
                        child: Text(r[1],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: r[1] == '수급 불가'
                                    ? Colors.orange
                                    : textColor,
                                fontSize: 13))),
                    Expanded(
                        child: Text(r[2],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: r[2] == '수급 불가'
                                    ? Colors.orange
                                    : primary,
                                fontSize: 13,
                                fontWeight: r[2] == '수급 불가'
                                    ? FontWeight.normal
                                    : FontWeight.w600))),
                  ]),
                ),
                Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                    indent: 16),
              ])),
        ],
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
