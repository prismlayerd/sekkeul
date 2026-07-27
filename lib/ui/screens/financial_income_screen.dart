import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';

import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../../core/data/db_helper.dart';
import '../../core/tax_engine/combined_tax.dart';
import '../../core/tax_engine/tax_rates.dart';
import '../theme/text_wrap.dart';

/// 금융소득 종합과세 시뮬레이터
/// 엔진: CombinedTaxCalculator.calculateFinancialIncomeTax (소득세법 §62)
/// - 2,000만원 이하: 분리과세 14% 완납 (5월 신고 불필요)
/// - 2,000만원 초과: 비교과세 → 추가 세부담 + 5월 종합소득세 신고 의무
/// - 1,000만원 초과: 건강보험료 소득월액 추가 산정 경고
class FinancialIncomeScreen extends StatefulWidget {
  const FinancialIncomeScreen({super.key});

  @override
  State<FinancialIncomeScreen> createState() => _FinancialIncomeScreenState();
}

class _FinancialIncomeScreenState extends State<FinancialIncomeScreen> {
  final TextEditingController _interestController = TextEditingController();
  final TextEditingController _dividendController = TextEditingController();
  final TextEditingController _otherIncomeController = TextEditingController();
  final _numberFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await dbService.getProfile();
    if (profile != null && mounted) {
      final gross = (profile['gross_income'] as num?)?.toDouble() ?? 0.0;
      if (gross > 0) {
        // 연봉을 근사 과세표준으로 자동 채움 (참고용)
        setState(() {
          _otherIncomeController.text = _numberFormat.format(gross.toInt());
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _interestController.clear();
      _dividendController.clear();
      _otherIncomeController.clear();
    });
  }

  @override
  void dispose() {
    _interestController.dispose();
    _dividendController.dispose();
    _otherIncomeController.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

  String _toManwon(double won) {
    if (won <= 0) return '0원';
    final man = (won / 10000).round();
    return '${_numberFormat.format(man)}만원';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;

    final interest = _parse(_interestController);
    final dividend = _parse(_dividendController);
    final otherIncome = _parse(_otherIncomeController);

    final totalFinancial = interest + dividend;
    final hasFinancial = totalFinancial > 0;

    FinancialIncomeTaxResult? result;
    if (hasFinancial) {
      result = CombinedTaxCalculator.calculateFinancialIncomeTax(
        annualFinancialIncome: totalFinancial,
        otherTaxableIncome: otherIncome,
      );
    }

    final isOverThreshold = totalFinancial > TaxRates.financialIncomeThreshold;
    final isOverHealthThreshold = totalFinancial > TaxRates.financialIncomeHealthThreshold;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('금융소득 종합과세 계산',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
            Text('이자·배당이 많다면\n세금이 더 붙을 수 있어요'.keepWords,
                style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold, height: 1.4)),
            const SizedBox(height: 8),
            Text('연간 금융소득이 2,000만원을 넘으면 종합소득에 합산되어 더 높은 세율이 적용됩니다.'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            // 입력 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('연간 금융소득',
                      style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildInputField('이자소득', _interestController,
                      hint: '은행 이자, 채권이자 등'),
                  const SizedBox(height: 20),
                  _buildInputField('배당소득', _dividendController,
                      hint: '주식 배당금, 펀드 분배금 등'),
                  if (hasFinancial) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (isOverThreshold ? Colors.redAccent : primary).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(
                          isOverThreshold ? Icons.warning_rounded : Icons.check_circle_outline_rounded,
                          color: isOverThreshold ? Colors.redAccent : primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          isOverThreshold
                              ? '합계 ${_toManwon(totalFinancial)} — 2,000만원 초과, 종합과세 의무 신고'
                              : '합계 ${_toManwon(totalFinancial)} — 2,000만원 이하, 분리과세 완납',
                          style: TextStyle(
                            color: isOverThreshold ? Colors.redAccent : primary,
                            fontSize: 12, fontWeight: FontWeight.w600,
                          ),
                        )),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 기타 종합소득 입력 (2,000만 초과 시 비교과세용)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: _buildInputField(
                '기타 종합소득 (근로·사업 등)',
                _otherIncomeController,
                hint: '비교과세 계산에 사용됩니다. 연봉을 입력하면 대략적으로 계산돼요.',
              ),
            ),
            const SizedBox(height: 24),

            // 결과 카드
            if (result != null) ...[
              if (result.isSeparateTax)
                _buildSeparateTaxCard(result, textColor, subColor, primary)
              else
                _buildComprehensiveTaxCard(result, textColor, subColor, primary),
              const SizedBox(height: 16),
            ],

            // 건보료 경고
            if (isOverHealthThreshold)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('건강보험료 추가 부과 주의',
                          style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '연간 금융소득이 1,000만원을 초과하면 건강보험료가 추가로 부과됩니다. '
                        '직장가입자도 소득월액 보험료로 별도 청구될 수 있습니다.',
                        style: TextStyle(color: subColor, fontSize: 12, height: 1.5),
                      ),
                    ]),
                  ),
                ]),
              ),

            if (isOverHealthThreshold) const SizedBox(height: 16),

            // 안내 박스
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
                    Icon(Icons.lightbulb_outline_rounded, color: subColor, size: 16),
                    const SizedBox(width: 6),
                    Text('알아두기', style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '• 이자·배당 합산이 연 2,000만원 이하면 14% 원천징수로 완납됩니다.\n'
                    '• 2,000만원 초과 시 전액 종합소득에 합산되며 5월에 신고해야 합니다.\n'
                    '• 비교과세: 분리과세 세액과 종합합산 세액 중 큰 금액이 결정세액입니다.\n'
                    '• 배당 Gross-up(귀속법인세 가산) 효과는 이 계산기에 미반영됩니다.',
                    style: TextStyle(color: subColor, fontSize: 12, height: 1.6),
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

  Widget _buildSeparateTaxCard(FinancialIncomeTaxResult r, Color textColor, Color subColor, Color primary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getAccentCardDecoration(context, borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.colorSuccess, size: 20),
            const SizedBox(width: 8),
            Text('분리과세 완납 — 신고 불필요'.keepWords,
                style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          Text(_toManwon(r.separateTaxAmount),
              style: TextStyle(color: AppTheme.colorSuccess, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _resultRow('적용 세율', '14% (분리과세)', subColor, textColor),
          const SizedBox(height: 6),
          _resultRow('이미 원천징수됨', '5월 신고 대상 아님', subColor, AppTheme.colorSuccess),
        ],
      ),
    );
  }

  Widget _buildComprehensiveTaxCard(FinancialIncomeTaxResult r, Color textColor, Color subColor, Color primary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getAccentCardDecoration(context, borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.assignment_rounded, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Text('종합과세 대상 — 5월 신고 필요'.keepWords,
                style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          Text('추가 세부담 ${_toManwon(r.additionalTaxBurden)}'.keepWords,
              style: TextStyle(color: Colors.redAccent, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('(종합과세 기준)',
              style: TextStyle(color: subColor, fontSize: 12)),
          const SizedBox(height: 16),
          _resultRow('분리과세 세액 (14%)', _toManwon(r.separateTaxAmount), subColor, textColor),
          const SizedBox(height: 6),
          _resultRow('종합과세 결정세액', _toManwon(r.comprehensiveTaxAmount), subColor, textColor),
          const SizedBox(height: 6),
          _resultRow('추가 세부담', _toManwon(r.additionalTaxBurden), subColor, Colors.redAccent),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.event_note_rounded, color: Colors.redAccent, size: 14),
              const SizedBox(width: 6),
              Text('5월 종합소득세 신고 대상', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {String? hint}) {
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: subColor, fontSize: 14)),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint, style: TextStyle(color: subColor.withValues(alpha: 0.7), fontSize: 11)),
        ],
        const SizedBox(height: 4),
        AmountField(controller: controller, expand: true, onChanged: (_) => setState(() {})),
      ],
    );
  }
}
