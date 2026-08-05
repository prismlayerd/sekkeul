import 'package:flutter/material.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

class CompoundInterestScreen extends StatefulWidget {
  const CompoundInterestScreen({super.key});

  @override
  State<CompoundInterestScreen> createState() => _CompoundInterestScreenState();
}

class _CompoundInterestScreenState extends State<CompoundInterestScreen> {
  final TextEditingController _principalController = TextEditingController();
  final TextEditingController _monthlyController = TextEditingController();
  final TextEditingController _rateController =
      TextEditingController(text: '7.0');
  final TextEditingController _yearsController =
      TextEditingController(text: '20');

  void _reset() {
    setState(() {
      _principalController.clear();
      _monthlyController.clear();
      _rateController.text = '7.0';
      _yearsController.text = '20';
    });
  }

  @override
  void dispose() {
    _principalController.dispose();
    _monthlyController.dispose();
    _rateController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  double get _principal =>
      double.tryParse(_principalController.text.replaceAll(',', '')) ?? 0.0;
  double get _monthly =>
      double.tryParse(_monthlyController.text.replaceAll(',', '')) ?? 0.0;
  double get _rate => double.tryParse(_rateController.text.replaceAll(',', '')) ?? 0.0;
  int get _years => int.tryParse(_yearsController.text.replaceAll(',', '')) ?? 0;

  List<(int year, double balance, double invested)> _buildData() {
    final rate = _rate / 100;
    final monthlyRate = rate / 12;
    final years = _years;
    final monthly = _monthly;
    final principal = _principal;
    if ((principal <= 0 && monthly <= 0) || monthlyRate <= 0 || years <= 0) {
      return [];
    }
    final result = <(int, double, double)>[];
    double balance = principal;
    double invested = principal;
    for (int m = 1; m <= years * 12; m++) {
      balance = balance * (1 + monthlyRate) + monthly;
      invested += monthly;
      if (m % 12 == 0) {
        result.add((m ~/ 12, balance, invested));
      }
    }
    return result;
  }

  String _manwon(double v) {
    if (v <= 0) return '0원';
    final eok = v / 100000000;
    if (eok >= 1) return '${eok.toStringAsFixed(1)}억원';
    return '${comma((v / 10000).round())}만원';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;

    final data = _buildData();
    final hasResult = data.isNotEmpty;
    final finalBalance = hasResult ? data.last.$2 : 0.0;
    final finalInvested = hasResult ? data.last.$3 : (_principal + _monthly * _years * 12);
    final totalInterest = hasResult ? finalBalance - finalInvested : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('복리 계산기',
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
            Text('복리의 마법으로\n자산 성장을 확인해요'.keepWords,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('월 복리 기준으로 계산됩니다.'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            // 입력 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('초기 투자금',
                      style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 4),
                  AmountField(
                    controller: _principalController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Text('월 추가 납입',
                      style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 4),
                  AmountField(
                    controller: _monthlyController,
                    expand: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('연 수익률 (%)',
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
                          Text('투자 기간 (년)',
                              style:
                                  TextStyle(color: subColor, fontSize: 14)),
                          const SizedBox(height: 4),
                          _numField(_yearsController, '년'),
                        ],
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 결과
            if (hasResult) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.getAccentCardDecoration(context,
                    borderRadius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.trending_up_rounded,
                          color: primary, size: 20),
                      const SizedBox(width: 8),
                      Text('${_years}년 후 예상 자산'.keepWords,
                          style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 12),
                    Text(_manwon(finalBalance),
                        style: TextStyle(
                            color: primary,
                            fontSize: 32,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    _row('총 투자원금', _manwon(finalInvested), subColor, textColor),
                    const SizedBox(height: 8),
                    _row('수익(이자+복리)', _manwon(totalInterest), subColor, primary),
                    const SizedBox(height: 8),
                    _row('수익률',
                        '${(totalInterest / finalInvested * 100).toStringAsFixed(1)}%',
                        subColor, textColor),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 연도별 표
              Container(
                decoration:
                    AppTheme.getCardDecoration(context, borderRadius: 16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Row(children: [
                        SizedBox(
                            width: 40,
                            child: Text('년차',
                                style: TextStyle(
                                    color: subColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600))),
                        Expanded(
                            child: Text('납입원금',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    color: subColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600))),
                        Expanded(
                            child: Text('평가금액',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    color: subColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600))),
                        Expanded(
                            child: Text('수익',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    color: subColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600))),
                      ]),
                    ),
                    Divider(
                        height: 1, color: Theme.of(context).dividerColor),
                    ...data.map((rec) {
                      final (yr, bal, inv) = rec;
                      final gain = bal - inv;
                      return Column(children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Row(children: [
                            SizedBox(
                                width: 40,
                                child: Text('$yr년',
                                    style: TextStyle(
                                        color: subColor, fontSize: 12))),
                            Expanded(
                                child: Text(_manwon(inv),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: textColor, fontSize: 12))),
                            Expanded(
                                child: Text(_manwon(bal),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                            Expanded(
                                child: Text(_manwon(gain),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: primary.withValues(alpha: 0.7),
                                        fontSize: 12))),
                          ]),
                        ),
                        Divider(
                            height: 1,
                            color: Theme.of(context).dividerColor,
                            indent: 12),
                      ]);
                    }),
                  ],
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.getAccentCardDecoration(context,
                    borderRadius: 20),
                child: Text('투자금·수익률·기간을 입력해보세요.'.keepWords,
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
                    '• 월 복리로 계산됩니다 (연이율 ÷ 12로 매월 적용).\n'
                    '• 세금·수수료는 반영되지 않았습니다.\n'
                    '• 실제 투자 수익은 시장 상황에 따라 달라집니다.\n'
                    '• 이 계산기는 투자 권유가 아닌 참고용입니다.',
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
