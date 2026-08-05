import 'package:flutter/material.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

enum _HouseholdType { single, oneEarner, dualEarner }

class EarnedIncomeTaxCreditScreen extends StatefulWidget {
  const EarnedIncomeTaxCreditScreen({super.key});

  @override
  State<EarnedIncomeTaxCreditScreen> createState() =>
      _EarnedIncomeTaxCreditScreenState();
}

class _EarnedIncomeTaxCreditScreenState
    extends State<EarnedIncomeTaxCreditScreen> {
  _HouseholdType _type = _HouseholdType.single;
  final TextEditingController _incomeController = TextEditingController();
  int _children = 0;

  void _reset() {
    setState(() {
      _type = _HouseholdType.single;
      _incomeController.clear();
      _children = 0;
    });
  }

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  double get _income =>
      (double.tryParse(_incomeController.text.replaceAll(',', '')) ?? 0.0) /
      10000; // 원 → 만원

  // 근로장려금 (만원 단위)
  double _earnedCredit(double income) {
    switch (_type) {
      // 조특법 §100의5 — 세 가구 유형이 모두 같은 구조다.
      //   점증: 총급여액 등 × (최대액 / 점증경계)
      //   평탄: 최대액
      //   점감: 최대액 − (총급여액 등 − 평탄끝) × (최대액 / (상한 − 평탄끝))
      //
      // 맞벌이 표는 「2025년 개정세법 해설」p.298 원문으로 확인했고
      // (800 / 800~1,700 / 2,700분의 330, 상한 4,400),
      // 점감 분모 = 상한 − 평탄끝이라는 관계가 세 유형에서 모두 성립한다.
      //   단독   400 / 400~900   / 1,300분의 165  (2,200 − 900)
      //   홑벌이 700 / 700~1,400 / 1,800분의 285  (3,200 − 1,400)
      //
      // 종전 코드는 단독 900/2,100/2,200(점감 분모 100), 홑벌이 1,400/2,100/3,200
      // 이었다 — 점감 분모가 상한 − 평탄끝과 맞지 않아 조문 구조와 양립할 수 없다.
      // 그 결과 저소득자에게는 과소(총급여 300만: 55만 vs 123.8만),
      // 중간 소득자에게는 과대(1,500만: 165만 vs 88.8만) 안내했다.
      //
      // ⚠ 조문 계산식이 law.go.kr에 **이미지로만** 실려 텍스트 원문은 못 읽었다.
      //   추적: test/notice_expiry_test.dart (1차 미확인)
      case _HouseholdType.single:
        if (income <= 0) return 0;
        if (income < 400) return income / 400 * 165;
        if (income < 900) return 165;
        if (income < 2200) return 165 - (income - 900) * 165 / 1300;
        return 0;
      case _HouseholdType.oneEarner:
        if (income <= 0) return 0;
        if (income < 700) return income / 700 * 285;
        if (income < 1400) return 285;
        if (income < 3200) return 285 - (income - 1400) * 285 / 1800;
        return 0;
      case _HouseholdType.dualEarner:
        // 조특법 §100의5 — 2025.1.1. 이후 신청분부터.
        // 출처: 「2025년 개정세법 해설」 p.298 "맞벌이 가구 근로장려금 소득상한금액 인상"
        //   800만원 미만        : 총급여액 등 × 800분의 330
        //   800만~1,700만원 미만 : 330만원
        //   1,700만~4,400만원 미만: 330만원 − (총급여액 등 − 1,700만) × 2,700분의 330
        //
        // 종전 코드는 1,700 / 2,500 / 3,800에 2,100분의 330을 쓰고 있었다 —
        // 구간 경계가 전부 어긋났고 상한도 개정 전(3,800만) 값이었다.
        if (income <= 0) return 0;
        if (income < 800) return income / 800 * 330;
        if (income < 1700) return 330;
        if (income < 4400) return 330 - (income - 1700) * 330 / 2700;
        return 0;
    }
  }

  // 자녀장려금 (만원 단위)
  double _childCredit(double income) {
    if (_children <= 0 || income <= 0 || income > 4000) return 0;
    final perChild =
        income <= 2100 ? 100.0 : (100.0 * (4000 - income) / 1900).clamp(0, 100);
    return (_children * perChild).toDouble();
  }

  String _manwon(double v) {
    if (v <= 0) return '0원';
    return '${comma(v.round())}만원';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;

    final income = _income;
    final hasInput = income > 0;
    final earnedCredit = _earnedCredit(income);
    final childCredit = _childCredit(income);
    final total = earnedCredit + childCredit;

    return Scaffold(
      appBar: AppBar(
        title: Text('근로·자녀장려금',
            style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
            Text('저소득 근로자를 위한\n장려금을 계산해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('근로장려금과 자녀장려금은 매년 5월에 신청합니다.'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            // 가구 유형
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('가구 유형',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _typeBtn('단독가구', _HouseholdType.single, primary, subColor),
                    const SizedBox(width: 8),
                    _typeBtn('홑벌이', _HouseholdType.oneEarner, primary, subColor),
                    const SizedBox(width: 8),
                    _typeBtn('맞벌이', _HouseholdType.dualEarner, primary, subColor),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    _type == _HouseholdType.single
                        ? '배우자·부양자녀 없는 단독 가구 (소득상한 2,200만원, 최대 165만원)'
                        : _type == _HouseholdType.oneEarner
                            ? '배우자 또는 부양자녀가 있는 홑벌이 (소득상한 3,200만원, 최대 285만원)'
                            : '부부 모두 근로·사업소득이 있는 맞벌이 (소득상한 4,400만원, 최대 330만원)',
                    style: TextStyle(
                        color: subColor.withValues(alpha: 0.8),
                        fontSize: 11,
                        height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 연간 총소득
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('연간 총소득',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('근로소득 + 사업소득 + 기타소득 합산'.keepWords,
                      style: TextStyle(
                          color: subColor.withValues(alpha: 0.7),
                          fontSize: 11)),
                  const SizedBox(height: 8),
                  AmountField(
                    controller: _incomeController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (hasInput) ...[
                    const SizedBox(height: 6),
                    Text('= ${comma(income.round())}만원'.keepWords,
                        style: TextStyle(color: subColor, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 자녀 수
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('부양자녀 수 (18세 미만)',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (i) {
                      final sel = _children == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _children = i),
                          child: Container(
                            margin: EdgeInsets.only(right: i < 4 ? 8 : 0),
                            height: 42,
                            decoration: BoxDecoration(
                              color: sel
                                  ? primary
                                  : primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text('$i명',
                                style: TextStyle(
                                    color: sel ? Colors.white : subColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 결과
            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  AppTheme.getAccentCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text('예상 장려금',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(hasInput ? _manwon(total) : '0원',
                      style: TextStyle(
                          color: primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (hasInput) ...[
                    _row('근로장려금', _manwon(earnedCredit), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('자녀장려금', _manwon(childCredit), subColor, textColor),
                    const SizedBox(height: 12),
                    Divider(
                        color: Theme.of(context).dividerColor,
                        height: 1,
                        thickness: 1),
                    const SizedBox(height: 12),
                    _row('합계', _manwon(total), subColor, primary),
                  ] else
                    Text('가구유형과 소득을 입력해보세요.'.keepWords,
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
                    '• 재산 합계 2억 원 미만인 경우에만 신청 가능합니다.\n'
                    '• 자녀장려금 소득상한은 부부합산 4,000만원입니다.\n'
                    '• 매년 5월 1일~31일 홈택스·모바일에서 신청합니다.\n'
                    '• 소득·재산 기준은 전년도(과세기간) 기준입니다.',
                    style:
                        TextStyle(color: subColor, fontSize: 12, height: 1.6),
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

  Widget _typeBtn(
      String label, _HouseholdType type, Color primary, Color subColor) {
    final sel = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: sel ? primary : primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  color: sel ? Colors.white : subColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color labelColor, Color valueColor) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child:
                  Text(label, style: TextStyle(color: labelColor, fontSize: 13))),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      );
}
