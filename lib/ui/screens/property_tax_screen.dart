import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

class PropertyTaxScreen extends StatefulWidget {
  const PropertyTaxScreen({super.key});

  @override
  State<PropertyTaxScreen> createState() => _PropertyTaxScreenState();
}

class _PropertyTaxScreenState extends State<PropertyTaxScreen> {
  final List<TextEditingController> _priceControllers = [
    TextEditingController(),
  ];
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _yearsController = TextEditingController();
  bool _urbanArea = false;
  bool _jointOwnership = false;
  final _fmt = NumberFormat('#,###');

  void _reset() => setState(() {
        for (final c in _priceControllers) {
          c.dispose();
        }
        _priceControllers
          ..clear()
          ..add(TextEditingController());
        _ageController.clear();
        _yearsController.clear();
        _urbanArea = false;
        _jointOwnership = false;
      });

  void _addProperty() => setState(() {
        _priceControllers.add(TextEditingController());
      });

  void _removeProperty(int i) => setState(() {
        _priceControllers[i].dispose();
        _priceControllers.removeAt(i);
        if (_priceControllers.length <= 1) _jointOwnership = false;
      });

  @override
  void dispose() {
    for (final c in _priceControllers) {
      c.dispose();
    }
    _ageController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  List<double> get _prices => _priceControllers
      .map((c) => double.tryParse(c.text.replaceAll(',', '')) ?? 0.0)
      .toList();
  double get _totalPrice => _prices.fold(0.0, (a, b) => a + b);
  int get _houses {
    final filled = _prices.where((p) => p > 0).length;
    return filled == 0 ? 1 : filled;
  }
  int get _age => int.tryParse(_ageController.text.replaceAll(',', '')) ?? 0;
  int get _years => int.tryParse(_yearsController.text.replaceAll(',', '')) ?? 0;

  bool get _creditEligible => _houses == 1 && !_jointOwnership;

  // ── 재산세 (주택분) — 물건별 개별 누진계산 후 합산, 공정시장가액비율 60% 고정 ──
  double _propertyTaxForPrice(double price) {
    final base = price * 0.60;
    if (base <= 60000000) return base * 0.001;
    if (base <= 150000000) return 60000 + (base - 60000000) * 0.0015;
    if (base <= 300000000) return 195000 + (base - 150000000) * 0.0025;
    return 570000 + (base - 300000000) * 0.004;
  }

  double get _propertyTax =>
      _prices.fold(0.0, (sum, p) => sum + _propertyTaxForPrice(p));

  double get _localEduTax => _propertyTax * 0.2;
  double get _urbanAreaTax =>
      _urbanArea ? _totalPrice * 0.60 * 0.0014 : 0.0;
  double get _propertyTaxTotal => _propertyTax + _localEduTax + _urbanAreaTax;

  // ── 종합부동산세 (주택분) — 물건 합산가격 기준 ──
  double get _cdeduction {
    if (_houses == 1) return _jointOwnership ? 1800000000 : 1200000000;
    return 900000000;
  }

  double get _comprehensiveBase {
    final excess = _totalPrice - _cdeduction;
    if (excess <= 0) return 0.0;
    return excess * 0.6;
  }

  double get _comprehensiveTaxBeforeCredit {
    final base = _comprehensiveBase;
    if (base <= 0) return 0.0;
    if (base <= 300000000) return base * 0.005;
    if (base <= 600000000) return 1500000 + (base - 300000000) * 0.007;
    if (base <= 1200000000) return 3600000 + (base - 600000000) * 0.010;
    if (base <= 2500000000) return 9600000 + (base - 1200000000) * 0.013;
    if (base <= 5000000000) return 26500000 + (base - 2500000000) * 0.015;
    if (base <= 9400000000) return 64000000 + (base - 5000000000) * 0.020;
    return 152000000 + (base - 9400000000) * 0.027;
  }

  double get _seniorCreditRate {
    if (!_creditEligible) return 0.0;
    if (_age >= 70) return 0.40;
    if (_age >= 65) return 0.30;
    if (_age >= 60) return 0.20;
    return 0.0;
  }

  double get _longTermCreditRate {
    if (!_creditEligible) return 0.0;
    if (_years >= 15) return 0.50;
    if (_years >= 10) return 0.40;
    if (_years >= 5) return 0.20;
    return 0.0;
  }

  double get _combinedCreditRate =>
      (_seniorCreditRate + _longTermCreditRate).clamp(0.0, 0.80);

  double get _creditAmount => _comprehensiveTaxBeforeCredit * _combinedCreditRate;

  double get _comprehensiveTax =>
      _comprehensiveTaxBeforeCredit - _creditAmount;

  double get _ruralSpecialTax => _comprehensiveTax * 0.2;
  double get _comprehensiveTaxTotal => _comprehensiveTax + _ruralSpecialTax;

  double get _grandTotal => _propertyTaxTotal + _comprehensiveTaxTotal;

  String _won(double v) {
    if (v <= 0) return '0원';
    final eok = v / 100000000;
    if (eok >= 1) return '${eok.toStringAsFixed(2)}억원';
    final man = v / 10000;
    if (man >= 1) return '${man.toStringAsFixed(0)}만원';
    return '${_fmt.format(v.round())}원';
  }

  String _pct(double r) => '${(r * 100).toStringAsFixed(2)}%';

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;
    final hasResult = _totalPrice > 0;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('종부세·재산세',
            style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
            Text('주택 보유 중\n매년 낼 보유세를 계산해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('재산세는 물건별로, 종부세는 합산 기준으로 계산해요'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('보유 주택별 공시가격 (1세대 합산)'.keepWords,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  for (int i = 0; i < _priceControllers.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('${i + 1}주택',
                            style: TextStyle(color: subColor, fontSize: 12)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AmountField(
                            controller: _priceControllers[i],
                            expand: true,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_priceControllers.length > 1) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _removeProperty(i),
                            child: Icon(Icons.close_rounded,
                                size: 18, color: subColor),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _addProperty,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: primary),
                        const SizedBox(width: 4),
                        Text('주택 추가',
                            style: TextStyle(
                                color: primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('도시지역',
                              style:
                                  TextStyle(color: textColor, fontSize: 14)),
                          Text('재산세 도시지역분 0.14% 추가'.keepWords,
                              style: TextStyle(
                                  color: subColor.withValues(alpha: 0.8),
                                  fontSize: 11)),
                        ],
                      ),
                      Switch(
                        value: _urbanArea,
                        activeColor: primary,
                        onChanged: (v) => setState(() => _urbanArea = v),
                      ),
                    ],
                  ),
                  if (_houses == 1) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('부부 공동명의',
                                  style:
                                      TextStyle(color: textColor, fontSize: 14)),
                              Text('종부세 공제 9억×2인 대신 세액공제 미적용'.keepWords,
                                  style: TextStyle(
                                      color: subColor.withValues(alpha: 0.8),
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _jointOwnership,
                          activeColor: primary,
                          onChanged: (v) =>
                              setState(() => _jointOwnership = v),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (_creditEligible) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration:
                    AppTheme.getCardDecoration(context, borderRadius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1세대 1주택 종부세 세액공제'.keepWords,
                        style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('고령자·장기보유 공제 합산 최대 80%'.keepWords,
                        style: TextStyle(
                            color: subColor.withValues(alpha: 0.8),
                            fontSize: 11)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: Text('만 나이',
                            style: TextStyle(color: textColor, fontSize: 14)),
                      ),
                      SizedBox(width: 90, child: _numField(_ageController, '세')),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: Text('보유기간',
                            style: TextStyle(color: textColor, fontSize: 14)),
                      ),
                      SizedBox(
                          width: 90, child: _numField(_yearsController, '년')),
                    ]),
                    if (_combinedCreditRate > 0) ...[
                      const SizedBox(height: 8),
                      Text('세액공제율: ${_pct(_combinedCreditRate)}'.keepWords,
                          style: TextStyle(
                              color: primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
            ],
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
                    Text('연간 보유세 합계',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(hasResult ? _won(_grandTotal) : '0원',
                      style: TextStyle(
                          color: primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (hasResult) ...[
                    _row('재산세 (물건별 합산)', _won(_propertyTax), subColor,
                        textColor),
                    const SizedBox(height: 8),
                    _row('지방교육세 (재산세×20%)', _won(_localEduTax), subColor,
                        textColor),
                    const SizedBox(height: 8),
                    _row('도시지역분 (0.14%)',
                        _urbanAreaTax > 0 ? _won(_urbanAreaTax) : '해당없음',
                        subColor, textColor),
                    const SizedBox(height: 8),
                    _row('재산세 소계', _won(_propertyTaxTotal), subColor, textColor),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    const SizedBox(height: 12),
                    _row(
                        '종합부동산세',
                        _comprehensiveTaxBeforeCredit > 0
                            ? _won(_comprehensiveTaxBeforeCredit)
                            : '해당없음 (공제 이하)',
                        subColor,
                        textColor),
                    if (_creditAmount > 0) ...[
                      const SizedBox(height: 8),
                      _row('세액공제 (${_pct(_combinedCreditRate)})',
                          '- ${_won(_creditAmount)}', subColor, textColor),
                    ],
                    const SizedBox(height: 8),
                    _row(
                        '농어촌특별세 (종부세×20%)',
                        _ruralSpecialTax > 0 ? _won(_ruralSpecialTax) : '해당없음',
                        subColor,
                        textColor),
                    const SizedBox(height: 8),
                    _row('종부세 소계', _won(_comprehensiveTaxTotal), subColor,
                        textColor),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    const SizedBox(height: 12),
                    _row('총 보유세', _won(_grandTotal), subColor, primary),
                  ] else
                    Text('주택 공시가격을 입력해보세요.'.keepWords,
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
                  Text('종부세 과세 기준',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _rateRow('1세대 1주택자 공제', '공시가격 합계 12억원', subColor, textColor),
                  _rateRow('부부 공동명의 공제', '공시가격 18억원 (9억×2)', subColor, textColor),
                  _rateRow('2주택 이상 공제', '공시가격 합계 9억원', subColor, textColor),
                  _rateRow('공정시장가액비율', '60%', subColor, textColor),
                  _rateRow('세율 (주택수 무관 단일표)', '0.5%~2.7% (7단계)', subColor,
                      textColor),
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
                    '• 재산세는 주택마다 개별 공시가격으로 누진계산 후 합산합니다(1주택 특례 미반영, 2026년 기준 60% 단일 적용).\n'
                    '• 종부세는 모든 주택의 공시가격 합계에서 공제액을 뺀 뒤 계산하며, 세율은 2023년 개정 이후 주택수와 무관한 단일표입니다.\n'
                    '• 고령자·장기보유 세액공제는 1세대1주택 단독명의(공제 12억)만 해당하며, 부부 공동명의 선택 시 적용되지 않습니다.\n'
                    '• 세부담 상한제 등은 미반영이며, 공정시장가액비율·세율은 매년 바뀔 수 있어 고지서와 차이가 날 수 있습니다.',
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

  Widget _numField(TextEditingController ctrl, String suffix) {
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final primary = Theme.of(context).primaryColor;
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        suffixText: suffix,
        suffixStyle: TextStyle(color: subColor, fontSize: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: TextStyle(color: textColor, fontSize: 15),
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
            Flexible(
                child: Text(label,
                    style: TextStyle(color: labelColor, fontSize: 12))),
            const SizedBox(width: 8),
            Text(rate,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
