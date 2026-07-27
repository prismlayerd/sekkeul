import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

class JeonseVsWolseScreen extends StatefulWidget {
  const JeonseVsWolseScreen({super.key});

  @override
  State<JeonseVsWolseScreen> createState() => _JeonseVsWolseScreenState();
}

class _JeonseVsWolseScreenState extends State<JeonseVsWolseScreen> {
  final TextEditingController _jeonseController = TextEditingController();
  final TextEditingController _wolseDepositController = TextEditingController();
  final TextEditingController _wolseMonthlyController = TextEditingController();
  final TextEditingController _rateController =
      TextEditingController(text: '3.5');
  final _fmt = NumberFormat('#,###');

  void _reset() {
    setState(() {
      _jeonseController.clear();
      _wolseDepositController.clear();
      _wolseMonthlyController.clear();
      _rateController.text = '3.5';
    });
  }

  @override
  void dispose() {
    _jeonseController.dispose();
    _wolseDepositController.dispose();
    _wolseMonthlyController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  double get _jeonse =>
      double.tryParse(_jeonseController.text.replaceAll(',', '')) ?? 0.0;
  double get _wolseDeposit =>
      double.tryParse(_wolseDepositController.text.replaceAll(',', '')) ?? 0.0;
  double get _wolseMonthly =>
      double.tryParse(_wolseMonthlyController.text.replaceAll(',', '')) ?? 0.0;
  double get _rate =>
      (double.tryParse(_rateController.text.replaceAll(',', '')) ?? 0.0) / 100;

  // 전세 기회비용 (연간) = 전세보증금의 금리 환산
  double get _jeonseCostAnnual => _jeonse * _rate;

  // 월세 실제 연간 비용 = 월세*12 + 월세보증금 기회비용
  double get _wolseCostAnnual =>
      _wolseMonthly * 12 + _wolseDeposit * _rate;

  // 손익분기 전환율 = 월세*12 / (전세 - 월세보증금) * 100
  double get _breakEvenRate {
    final diff = _jeonse - _wolseDeposit;
    if (diff <= 0) return 0;
    return _wolseMonthly * 12 / diff * 100;
  }

  String _won(double v) {
    if (v <= 0) return '0원';
    final eok = v / 100000000;
    if (eok >= 1) return '${eok.toStringAsFixed(1)}억원';
    return '${_fmt.format((v / 10000).round())}만원';
  }

  bool get _hasInput =>
      _jeonse > 0 && _wolseMonthly > 0 && _rate > 0;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;

    final jCost = _jeonseCostAnnual;
    final wCost = _wolseCostAnnual;
    final jeonseIsBetter = jCost <= wCost;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('전세 vs 월세 비교',
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
            Text('전세·월세의 실질 비용을\n비교해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('보증금 기회비용(금리 환산)까지 포함한 연간 비용으로 비교합니다.'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            // 전세 입력
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('전세 보증금',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AmountField(
                    controller: _jeonseController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 월세 입력
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('월세 조건',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('보증금', style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 4),
                  AmountField(
                    controller: _wolseDepositController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text('월 임차료',
                      style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 4),
                  AmountField(
                    controller: _wolseMonthlyController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 기준 금리
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('기회비용 적용 금리 (%)',
                            style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('예금금리 또는 대출금리를 입력하세요.'.keepWords,
                            style: TextStyle(
                                color: subColor.withValues(alpha: 0.8),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 100,
                    child: _numField(_rateController, '%'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 비교 결과
            if (_hasInput) ...[
              // verdict
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.getAccentCardDecoration(context,
                    borderRadius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.compare_arrows_rounded,
                          color: primary, size: 20),
                      const SizedBox(width: 8),
                      Text('비교 결과',
                          style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                      jeonseIsBetter ? '전세가 유리합니다' : '월세가 유리합니다',
                      style: TextStyle(
                          color: primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      jeonseIsBetter
                          ? '연간 ${_won(wCost - jCost)} 절감'
                          : '연간 ${_won(jCost - wCost)} 절감',
                      style: TextStyle(
                          color: subColor, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // side-by-side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.getCardDecoration(context,
                          borderRadius: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('전세',
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _miniRow('보증금', _won(_jeonse), subColor, textColor),
                          const SizedBox(height: 8),
                          _miniRow('기회비용/년', _won(jCost), subColor,
                              jeonseIsBetter ? primary : textColor),
                          const SizedBox(height: 8),
                          Divider(
                              height: 1,
                              color: Theme.of(context).dividerColor),
                          const SizedBox(height: 8),
                          _miniRow('연간 비용', _won(jCost), subColor,
                              jeonseIsBetter ? primary : textColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.getCardDecoration(context,
                          borderRadius: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('월세',
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _miniRow('월세 합계', _won(_wolseMonthly * 12),
                              subColor, textColor),
                          const SizedBox(height: 8),
                          _miniRow('보증금 기회비용', _won(_wolseDeposit * _rate),
                              subColor, textColor),
                          const SizedBox(height: 8),
                          Divider(
                              height: 1,
                              color: Theme.of(context).dividerColor),
                          const SizedBox(height: 8),
                          _miniRow('연간 비용', _won(wCost), subColor,
                              !jeonseIsBetter ? primary : textColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 손익분기 전환율
              Container(
                padding: const EdgeInsets.all(16),
                decoration:
                    AppTheme.getCardDecoration(context, borderRadius: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('손익분기 전환율',
                        style: TextStyle(color: subColor, fontSize: 13)),
                    Text(
                      '${_breakEvenRate.toStringAsFixed(2)}%',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.getAccentCardDecoration(context,
                    borderRadius: 20),
                child: Text('전세보증금·월세 조건·금리를 입력해보세요.'.keepWords,
                    style: TextStyle(color: subColor, fontSize: 13)),
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
                    '• 전세: 보증금을 은행에 예치했을 때 받을 수 있는 이자가 기회비용입니다.\n'
                    '• 월세: 월 임차료 + 보증금의 기회비용을 합산한 연간 비용입니다.\n'
                    '• 손익분기 전환율: 이 금리보다 높으면 월세, 낮으면 전세가 유리합니다.\n'
                    '• 전세 레버리지·갱신 리스크 등 질적 요소는 반영되지 않습니다.',
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

  Widget _miniRow(
      String label, String value, Color labelColor, Color valueColor) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
              child: Text(label,
                  style: TextStyle(color: labelColor, fontSize: 11))),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      );
}
