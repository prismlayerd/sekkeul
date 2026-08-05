import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

enum _TaxType { inheritance, gift }

enum _Relation { spouse, adultChild, minorChild, other }

class InheritanceGiftTaxScreen extends StatefulWidget {
  const InheritanceGiftTaxScreen({super.key});

  @override
  State<InheritanceGiftTaxScreen> createState() =>
      _InheritanceGiftTaxScreenState();
}

class _InheritanceGiftTaxScreenState extends State<InheritanceGiftTaxScreen> {
  final TextEditingController _assetController = TextEditingController();
  _TaxType _type = _TaxType.inheritance;
  _Relation _relation = _Relation.adultChild;
  final _fmt = NumberFormat('#,###');

  static const List<(double, double, double)> _brackets = [
    (100000000, 0.10, 0),
    (500000000, 0.20, 10000000),
    (1000000000, 0.30, 60000000),
    (3000000000, 0.40, 160000000),
    (double.infinity, 0.50, 460000000),
  ];

  void _reset() => setState(() {
        _assetController.clear();
        _type = _TaxType.inheritance;
        _relation = _Relation.adultChild;
      });

  @override
  void dispose() {
    _assetController.dispose();
    super.dispose();
  }

  double get _asset =>
      double.tryParse(_assetController.text.replaceAll(',', '')) ?? 0.0;

  double get _deduction {
    if (_type == _TaxType.inheritance) {
      return 500000000; // 일괄공제 5억 (배우자 포함)
    } else {
      switch (_relation) {
        case _Relation.spouse:
          return 600000000;
        case _Relation.adultChild:
          return 50000000;
        case _Relation.minorChild:
          return 20000000;
        case _Relation.other:
          return 10000000;
      }
    }
  }

  double _calcTax(double base) {
    for (final (limit, rate, deduction) in _brackets) {
      if (base <= limit) {
        return base * rate - deduction;
      }
    }
    return base * 0.50 - 460000000;
  }

  (double taxBase, double tax)? _compute() {
    final asset = _asset;
    if (asset <= 0) return null;
    final base = (asset - _deduction).clamp(0.0, double.infinity);
    final tax = base > 0 ? _calcTax(base).clamp(0.0, double.infinity) : 0.0;
    return (base, tax);
  }

  String _won(double v) {
    if (v <= 0) return '0원';
    final eok = v / 100000000;
    if (eok >= 1) return '${eok.toStringAsFixed(2)}억원';
    final man = v / 10000;
    if (man >= 1) return '${man.toStringAsFixed(0)}만원';
    return '${_fmt.format(v.round())}원';
  }

  String get _deductionLabel {
    if (_type == _TaxType.inheritance) return '상속공제 (일괄)';
    switch (_relation) {
      case _Relation.spouse:
        return '배우자 증여공제';
      case _Relation.adultChild:
        return '직계비속(성인) 증여공제';
      case _Relation.minorChild:
        return '직계비속(미성년) 증여공제';
      case _Relation.other:
        return '기타친족 증여공제';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;
    final result = _compute();
    final taxBase = result?.$1 ?? 0.0;
    final tax = result?.$2 ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('상속·증여세',
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
            Text('상속 또는 증여 시\n납부할 세금을 계산해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('공제 후 과세표준 기준, 5단계 누진세율 적용'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('유형',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _typeBtn('상속', _TaxType.inheritance, primary, subColor),
                    const SizedBox(width: 8),
                    _typeBtn('증여', _TaxType.gift, primary, subColor),
                  ]),
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
                  Text('관계',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _relationBtn(
                          '배우자', _Relation.spouse, primary, subColor),
                      _relationBtn(
                          '성인 자녀', _Relation.adultChild, primary, subColor),
                      _relationBtn('미성년 자녀', _Relation.minorChild, primary,
                          subColor),
                      _relationBtn('기타', _Relation.other, primary, subColor),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_deductionLabel,
                            style:
                                TextStyle(color: subColor, fontSize: 12)),
                        Text(_won(_deduction),
                            style: TextStyle(
                                color: primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
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
                  Text('재산가액',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AmountField(
                    controller: _assetController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
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
                    Text('납부 세금',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(result != null ? _won(tax) : '0원',
                      style: TextStyle(
                          color: primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (result != null) ...[
                    _row('재산가액', _won(_asset), subColor, textColor),
                    const SizedBox(height: 8),
                    _row(_deductionLabel, '- ${_won(_deduction)}', subColor,
                        textColor),
                    const SizedBox(height: 8),
                    _row('과세표준', _won(taxBase), subColor, textColor),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    const SizedBox(height: 12),
                    _row('납부 세금', _won(tax), subColor, primary),
                    if (taxBase <= 0) ...[
                      const SizedBox(height: 8),
                      Text('공제액이 재산가액을 초과하여 세금이 없습니다.'.keepWords,
                          style: TextStyle(color: subColor, fontSize: 12)),
                    ],
                  ] else
                    Text('재산가액을 입력해보세요.',
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
                  Text('세율 구간',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _rateRow('1억원 이하', '10%', subColor, textColor),
                  _rateRow('5억원 이하', '20%', subColor, textColor),
                  _rateRow('10억원 이하', '30%', subColor, textColor),
                  _rateRow('30억원 이하', '40%', subColor, textColor),
                  _rateRow('30억원 초과', '50%', subColor, textColor),
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
                    '• 상속: 배우자 공제 최소 5억(실제 취득재산 기준 최대 30억), 일괄공제 5억.\n'
                    '• 증여: 배우자 6억, 성인자녀 5천만, 미성년 2천만, 기타친족 1천만원 (10년 합산).\n'
                    '• 신고세액공제 3%·세대생략 할증(30~40%)은 반영되지 않았습니다.\n'
                    '• 영농상속공제 등 개별 특례는 세무사 상담을 권장합니다.',
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
      String label, _TaxType type, Color primary, Color subColor) {
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _relationBtn(
      String label, _Relation rel, Color primary, Color subColor) {
    final sel = _relation == rel;
    return GestureDetector(
      onTap: () => setState(() => _relation = rel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? primary : primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : subColor,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _row(String label, String value, Color labelColor, Color valueColor) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
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
