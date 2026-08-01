import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class CarLeaseBuyRentScreen extends StatefulWidget {
  const CarLeaseBuyRentScreen({super.key});

  @override
  State<CarLeaseBuyRentScreen> createState() => _CarLeaseBuyRentScreenState();
}

class _CarLeaseBuyRentScreenState extends State<CarLeaseBuyRentScreen> {
  final _priceCtrl = TextEditingController();
  final _leaseMonthlyCtrl = TextEditingController();
  final _leaseDepositCtrl = TextEditingController();
  final _rentMonthlyCtrl = TextEditingController();
  final _rentDepositCtrl = TextEditingController();
  final _loanRateCtrl = TextEditingController(text: '5.5');
  final _loanRatioCtrl = TextEditingController(text: '70');
  final _residualRateCtrl = TextEditingController(text: '50');
  int _months = 60;
  final _fmt = NumberFormat('#,###');

  double _num(TextEditingController c) => saneInput(
      double.tryParse(c.text.replaceAll(',', '')) ?? 0, InputMax.money);

  double get _price => saneInput(_num(_priceCtrl), InputMax.money);
  // 월 납입액은 '월' 단위라 금액 상한을 그대로 쓰면 개월수만큼 부풀어 오른다.
  double get _leaseTotal =>
      _num(_leaseDepositCtrl) +
      saneInput(_num(_leaseMonthlyCtrl), InputMax.unitPrice * 100) * _months;
  double get _rentTotal =>
      _num(_rentDepositCtrl) +
      saneInput(_num(_rentMonthlyCtrl), InputMax.unitPrice * 100) * _months;

  double get _buyTotal {
    final loanPrincipal =
        _price * (saneInput(_num(_loanRatioCtrl), InputMax.percent) / 100);
    final interest = loanPrincipal *
        (saneInput(_num(_loanRateCtrl), InputMax.percent) / 100) *
        (_months / 12);
    final residual =
        _price * (saneInput(_num(_residualRateCtrl), InputMax.percent) / 100);
    return _price + interest - residual;
  }

  bool get _hasInput => _price > 0;

  String _won(double v) => '${_fmt.format(v.round())}원';

  @override
  void dispose() {
    _priceCtrl.dispose();
    _leaseMonthlyCtrl.dispose();
    _leaseDepositCtrl.dispose();
    _rentMonthlyCtrl.dispose();
    _rentDepositCtrl.dispose();
    _loanRateCtrl.dispose();
    _loanRatioCtrl.dispose();
    _residualRateCtrl.dispose();
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
        title: Text('리스 · 구매 · 렌트 비교',
            style: AppTheme.serif(16, ink, weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _amountField('차량 가격', _priceCtrl, ink, sub, line),
            const SizedBox(height: 16),
            Text('이용 기간', style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [36, 48, 60]
                  .map((m) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _segButton('$m개월', m, _months,
                              (v) => setState(() => _months = v), ink, line, accent),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            Text('리스', style: AppTheme.sans(13, ink, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            _amountField('보증금', _leaseDepositCtrl, ink, sub, line),
            const SizedBox(height: 12),
            _amountField('월 납입금', _leaseMonthlyCtrl, ink, sub, line),
            const SizedBox(height: 20),
            Text('장기렌트', style: AppTheme.sans(13, ink, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            _amountField('보증금', _rentDepositCtrl, ink, sub, line),
            const SizedBox(height: 12),
            _amountField('월 납입금', _rentMonthlyCtrl, ink, sub, line),
            const SizedBox(height: 20),
            Text('구매(대출)', style: AppTheme.sans(13, ink, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            _percentField('대출 비율', _loanRatioCtrl, ink, sub, line),
            const SizedBox(height: 12),
            _percentField('대출 이자율(연)', _loanRateCtrl, ink, sub, line),
            const SizedBox(height: 12),
            _percentField('예상 잔존가치율', _residualRateCtrl, ink, sub, line),
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
                    Text('$_months개월 총 지출 비교'.keepWords,
                        style: AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _resultRow('리스', _leaseTotal, ink, sub, accent),
                    const SizedBox(height: 8),
                    _resultRow('장기렌트', _rentTotal, ink, sub, accent),
                    const SizedBox(height: 8),
                    _resultRow('구매(대출)', _buyTotal, ink, sub, accent),
                    const SizedBox(height: 12),
                    Text('* 보증금은 환급 여부와 무관하게 총 지출액에 포함한 단순 비교치입니다.'.keepWords,
                        style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox('참고', const [
              '리스: 소유권 없이 사용, 보험·세금 리스사 대납 상품도 있음',
              '장기렌트: 보험·정비 포함 상품 다수, 사업자는 부가세 매입공제 가능',
              '구매(대출): 소유권 확보, 잔존가치는 실제 중고차 시세와 다를 수 있음',
              '중형 세단 5년 유지비는 차량가의 50~80% 수준이 일반적 기준입니다.',
            ], line, sub, ink),
          ],
        ),
      ),
    );
  }

  Widget _amountField(String label, TextEditingController ctrl, Color ink,
      Color sub, Color line) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          inputFormatters: const [ThousandsFormatter()],
          style: AppTheme.sans(14, ink),
          decoration: InputDecoration(
            suffixText: '원',
            suffixStyle: AppTheme.sans(14, sub),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: ink)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onChanged: (v) {
            final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
            final formatted = digits.isEmpty ? '' : _fmt.format(int.parse(digits));
            ctrl.value = TextEditingValue(
                text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _percentField(String label, TextEditingController ctrl, Color ink,
      Color sub, Color line) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: AppTheme.sans(14, ink),
          decoration: InputDecoration(
            suffixText: '%',
            suffixStyle: AppTheme.sans(14, sub),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: ink)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _segButton(String label, int value, int groupValue,
      ValueChanged<int> onChanged, Color ink, Color line, Color accent) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            border: Border.all(color: selected ? accent : line),
            borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            style: AppTheme.sans(13, selected ? accent : ink, weight: FontWeight.w600)),
      ),
    );
  }

  Widget _resultRow(String label, double value, Color ink, Color sub, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.sans(13, ink, weight: FontWeight.w600)),
        Text(_won(value), style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
      ],
    );
  }

  Widget _infoBox(String title, List<String> items, Color line, Color sub, Color ink) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(4)),
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
                Expanded(child: Text(item, style: AppTheme.sans(13, sub, height: 1.5))),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
