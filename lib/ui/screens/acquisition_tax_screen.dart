import 'package:flutter/material.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

class AcquisitionTaxScreen extends StatefulWidget {
  const AcquisitionTaxScreen({super.key});

  @override
  State<AcquisitionTaxScreen> createState() => _AcquisitionTaxScreenState();
}

class _AcquisitionTaxScreenState extends State<AcquisitionTaxScreen> {
  final TextEditingController _priceController = TextEditingController();
  int _houses = 1;
  bool _adjusted = false;

  void _reset() => setState(() {
        _priceController.clear();
        _houses = 1;
        _adjusted = false;
      });

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  double get _price =>
      double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0.0;

  double _generalRate(double price) {
    if (price <= 600000000) return 0.01;
    if (price <= 900000000) return 0.01 + (price - 600000000) / 300000000 * 0.02;
    return 0.03;
  }

  double _acquisitionRate(double price) {
    if (_houses == 1) return _generalRate(price);
    if (_houses == 2) return _adjusted ? 0.08 : _generalRate(price);
    return _adjusted ? 0.12 : 0.08;
  }

  double get _acqTax => _price * _acquisitionRate(_price);

  /// 지방교육세 — 지방세법 §151①1가목.
  ///
  /// 과세표준은 「취득세 표준세율을 적용해 산출한 금액」인데, **주택 유상거래는
  /// 그 세율에 100분의 50을 곱한다**(같은 목 단서). 거기에 세율 20%를 곱하므로
  /// 결과는 `취득가액 × 표준세율 × 10%`다.
  ///
  /// 종전에는 `취득세액 × 20%`로 계산해 **2배**가 나왔다 — 6억 이하 주택은
  /// 취득세 1% + 지방교육세 0.1%(합 1.1%)가 맞는데 1.2%로 안내하고 있었다.
  /// 다주택 중과세율(8·12%)일 때도 지방교육세는 **표준세율 기준**이라
  /// 취득세액에 비례시키면 안 된다.
  double get _eduTax => _price * _generalRate(_price) * 0.1;
  double get _ruralTax =>
      (_houses >= 2 || _price > 900000000) ? _price * 0.002 : 0.0;
  double get _totalTax => _acqTax + _eduTax + _ruralTax;

  String won(double v) {
    if (v <= 0) return '0원';
    final eok = v / 100000000;
    if (eok >= 1) return '${eok.toStringAsFixed(2)}억원';
    final man = v / 10000;
    if (man >= 1) return '${man.toStringAsFixed(0)}만원';
    return '${comma(v.round())}원';
  }

  String _pct(double r) => '${(r * 100).toStringAsFixed(2)}%';

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;
    final hasResult = _price > 0;
    final rate = _acquisitionRate(_price);

    return Scaffold(
      appBar: AppBar(
        title: Text('취득세',
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
            Text('부동산 취득 시\n납부할 세금을 계산해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('취득세 + 지방교육세 + 농어촌특별세 합산 기준'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('취득가액',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AmountField(
                    controller: _priceController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('주택 수 (취득 후 보유 기준)'.keepWords,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _houseBtn('1주택', 1, primary, subColor),
                    const SizedBox(width: 8),
                    _houseBtn('2주택', 2, primary, subColor),
                    const SizedBox(width: 8),
                    _houseBtn('3주택+', 3, primary, subColor),
                  ]),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('조정대상지역',
                              style:
                                  TextStyle(color: textColor, fontSize: 14)),
                          Text('서울 전역·과천·성남·하남 등'.keepWords,
                              style: TextStyle(
                                  color: subColor.withValues(alpha: 0.8),
                                  fontSize: 11)),
                        ],
                      ),
                      Switch(
                        value: _adjusted,
                        activeColor: primary,
                        onChanged: (v) => setState(() => _adjusted = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  AppTheme.getAccentCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.receipt_long_outlined, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text('납부 세금 합계',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(hasResult ? won(_totalTax) : '0원',
                      style: TextStyle(
                          color: primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (hasResult) ...[
                    _row('취득세율', _pct(rate), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('취득세', won(_acqTax), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('지방교육세 (표준세율×10%)', won(_eduTax), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('농어촌특별세 (0.2%)',
                        _ruralTax > 0 ? won(_ruralTax) : '해당없음', subColor,
                        textColor),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    const SizedBox(height: 12),
                    _row('총 납부세액', won(_totalTax), subColor, primary),
                  ] else
                    Text('취득가액을 입력해보세요.',
                        style: TextStyle(color: subColor, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('취득세율 요약',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _rateRow('1주택 · 6억 이하', '1%', subColor, textColor),
                  _rateRow('1주택 · 6~9억', '1%~3% (선형)', subColor, textColor),
                  _rateRow('1주택 · 9억 초과', '3%', subColor, textColor),
                  _rateRow('2주택 · 조정대상', '8%', subColor, textColor),
                  _rateRow('2주택 · 비조정', '일반세율', subColor, textColor),
                  _rateRow('3주택+ · 조정대상', '12%', subColor, textColor),
                  _rateRow('3주택+ · 비조정', '8%', subColor, textColor),
                ],
              ),
            ),
            const SizedBox(height: 12),

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
                    '• 주택 수는 취득 후 1세대 합산 기준입니다.\n'
                    '• 농어촌특별세: 1주택 9억 이하 제외, 나머지 취득가×0.2%.\n'
                    '• 일시적 2주택(3년 내 기존주택 처분 등) 감면 별도 확인.\n'
                    '• 오피스텔·상가 등 비주택 취득세(4.6%)는 별도 계산.',
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

  Widget _houseBtn(String label, int val, Color primary, Color subColor) {
    final sel = _houses == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _houses = val),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color labelColor, Color valueColor) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
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

  Widget _rateRow(
          String label, String rate, Color labelColor, Color valueColor) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: labelColor, fontSize: 12)),
            Text(rate,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
