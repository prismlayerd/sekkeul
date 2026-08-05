import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

enum _SavingsType { deposit, installment }

class SavingsCalculatorScreen extends StatefulWidget {
  const SavingsCalculatorScreen({super.key});

  @override
  State<SavingsCalculatorScreen> createState() =>
      _SavingsCalculatorScreenState();
}

class _SavingsCalculatorScreenState extends State<SavingsCalculatorScreen> {
  _SavingsType _type = _SavingsType.deposit;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _rateController =
      TextEditingController(text: '3.5');
  final TextEditingController _monthsController =
      TextEditingController(text: '12');
  bool _taxExempt = false;
  final _fmt = NumberFormat('#,###');

  static const double _taxRate = 0.154;

  void _reset() {
    setState(() {
      _type = _SavingsType.deposit;
      _amountController.clear();
      _rateController.text = '3.5';
      _monthsController.text = '12';
      _taxExempt = false;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  double get _amount =>
      double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
  double get _rate =>
      saneInput(double.tryParse(_rateController.text.replaceAll(',', '')) ?? 0.0,
              InputMax.percent) /
          100;
  int get _months => saneInput(
          (int.tryParse(_monthsController.text.replaceAll(',', '')) ?? 0).toDouble(),
          InputMax.months)
      .toInt();

  double get _grossInterest {
    final a = _amount;
    final r = _rate;
    final m = _months;
    if (a <= 0 || r <= 0 || m <= 0) return 0;
    if (_type == _SavingsType.deposit) {
      return a * r * m / 12;
    } else {
      // 적금: 매월 a씩 납입, 총 납입 = a*m
      return a * (r / 12) * m * (m + 1) / 2;
    }
  }

  double get _tax => _taxExempt ? 0.0 : _grossInterest * _taxRate;
  double get _netInterest => _grossInterest - _tax;
  double get _totalPrincipal =>
      _type == _SavingsType.deposit ? _amount : _amount * _months;
  double get _maturityAmount => _totalPrincipal + _netInterest;

  String _won(double v) {
    if (v <= 0) return '0원';
    final eok = v / 100000000;
    if (eok >= 1) return '${eok.toStringAsFixed(2)}억원';
    final man = (v / 10000);
    if (man >= 1) return '${man.toStringAsFixed(1)}만원';
    return '${_fmt.format(v.round())}원';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;

    final hasResult = _amount > 0 && _rate > 0 && _months > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('예·적금 세후 수익',
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
            Text('이자소득세를 빼고\n실제 수령액을 계산해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('이자소득세 15.4% (소득세 14% + 지방소득세 1.4%) 적용'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            // 상품 유형
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('상품 유형',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _typeBtn('예금', _SavingsType.deposit, primary, subColor),
                    const SizedBox(width: 8),
                    _typeBtn('적금', _SavingsType.installment, primary, subColor),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    _type == _SavingsType.deposit
                        ? '목돈을 한 번에 예치하고 만기 시 이자를 받습니다.'
                        : '매월 일정 금액을 납입하고 만기 시 이자를 받습니다.',
                    style: TextStyle(
                        color: subColor.withValues(alpha: 0.8),
                        fontSize: 11,
                        height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 금액·이율·기간
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _type == _SavingsType.deposit ? '예치금액' : '월 납입액',
                    style: TextStyle(color: subColor, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  AmountField(
                    controller: _amountController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('연이율 (%)',
                              style:
                                  TextStyle(color: subColor, fontSize: 14)),
                          const SizedBox(height: 4),
                          _numField(_rateController, '%'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('기간 (개월)',
                              style:
                                  TextStyle(color: subColor, fontSize: 14)),
                          const SizedBox(height: 4),
                          _numField(_monthsController, '개월'),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('비과세 적용',
                          style: TextStyle(color: textColor, fontSize: 14)),
                      Switch(
                        value: _taxExempt,
                        activeColor: primary,
                        onChanged: (v) => setState(() => _taxExempt = v),
                      ),
                    ],
                  ),
                  if (_taxExempt)
                    Text('농특세 1.4% 외 이자세 면제 (비과세종합저축 등)'.keepWords,
                        style: TextStyle(
                            color: subColor.withValues(alpha: 0.8),
                            fontSize: 11)),
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
                    Icon(Icons.savings_outlined, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text('만기 수령액',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(hasResult ? _won(_maturityAmount) : '0원',
                      style: TextStyle(
                          color: primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (hasResult) ...[
                    _row('총 납입원금', _won(_totalPrincipal), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('세전 이자', _won(_grossInterest), subColor, textColor),
                    const SizedBox(height: 8),
                    _row(
                      _taxExempt ? '이자소득세 (비과세)' : '이자소득세 15.4%',
                      _taxExempt ? '0원' : '- ${_won(_tax)}',
                      subColor,
                      textColor,
                    ),
                    const SizedBox(height: 8),
                    _row('세후 이자', _won(_netInterest), subColor, primary),
                  ] else
                    Text('금액·이율·기간을 입력해보세요.'.keepWords,
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
                    '• 이자소득세 = 소득세 14% + 지방소득세 1.4% = 15.4%\n'
                    '• 비과세종합저축(장애인·65세 이상 등 5천만원 한도) 해당 시 비과세.\n'
                    '• ISA·IRP·연금저축 등은 별도 절세 혜택이 있습니다.\n'
                    '• 적금 이자는 납입 순서별 기간에 따라 복잡하게 산정될 수 있습니다.',
                    style:
                        TextStyle(color: subColor, fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBtn(
      String label, _SavingsType type, Color primary, Color subColor) {
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

  Widget _numField(TextEditingController ctrl, String suffix) {
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final primary = Theme.of(context).primaryColor;
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
