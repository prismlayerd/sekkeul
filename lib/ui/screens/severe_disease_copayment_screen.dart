import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class SevereDiseaseCopaymentScreen extends StatefulWidget {
  const SevereDiseaseCopaymentScreen({super.key});

  @override
  State<SevereDiseaseCopaymentScreen> createState() =>
      _SevereDiseaseCopaymentScreenState();
}

class _SevereDiseaseCopaymentScreenState
    extends State<SevereDiseaseCopaymentScreen> {
  int _typeIdx = 0;
  int _diseaseIdx = 0;
  final _costCtrl = TextEditingController();
  final _fmt = NumberFormat('#,###');

  /// 산정특례 본인부담률은 질환군마다 다르다(국민건강보험 산정특례 안내).
  /// 5%로 뭉뚱그리면 희귀질환자에게 실제의 절반을 보여준다.
  static const _diseases = [
    ('암 · 중증화상', 0.05),
    ('희귀질환 · 중증난치 · 중증치매', 0.10),
    ('결핵 · 잠복결핵감염', 0.00),
  ];

  // 진료유형 라벨, 일반 본인부담률
  static const _types = [
    ('외래-의원', 0.30),
    ('외래-병원', 0.40),
    ('외래-종합병원', 0.50),
    ('외래-상급종합', 0.60),
    ('입원', 0.20),
  ];

  double get _cost => double.tryParse(_costCtrl.text.replaceAll(',', '')) ?? 0;
  double get _generalRate => _types[_typeIdx].$2;
  double get _generalCopay => _cost * _generalRate;
  double get _specialRate => _diseases[_diseaseIdx].$2;
  double get _specialCopay => _cost * _specialRate;
  double get _saved => _generalCopay - _specialCopay;
  bool get _hasInput => _cost > 0;

  String _won(double v) => '${_fmt.format(v.round())}원';

  @override
  void dispose() {
    _costCtrl.dispose();
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
        title: Text('중증질환 산정특례',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('질환군',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(4)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _diseaseIdx,
                  isExpanded: true,
                  style: AppTheme.sans(14, ink),
                  dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                  items: [
                    for (int i = 0; i < _diseases.length; i++)
                      DropdownMenuItem(
                          value: i,
                          child: Text(_diseases[i].$1,
                              style: AppTheme.sans(14, ink))),
                  ],
                  onChanged: (v) => setState(() => _diseaseIdx = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('진료 유형',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(4)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _typeIdx,
                  isExpanded: true,
                  style: AppTheme.sans(14, ink),
                  dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                  items: [
                    for (int i = 0; i < _types.length; i++)
                      DropdownMenuItem(
                          value: i,
                          child: Text(_types[i].$1,
                              style: AppTheme.sans(14, ink))),
                  ],
                  onChanged: (v) => setState(() => _typeIdx = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('총 진료비',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _costCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: const [ThousandsFormatter()],
              style: AppTheme.sans(14, ink),
              decoration: InputDecoration(
                hintText: '5,000,000',
                hintStyle: AppTheme.sans(14, sub),
                suffixText: '원',
                suffixStyle: AppTheme.sans(14, sub),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: line)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: line)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: ink)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              onChanged: (v) {
                final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                final formatted =
                    digits.isEmpty ? '' : _fmt.format(int.parse(digits));
                _costCtrl.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
                setState(() {});
              },
            ),
            const SizedBox(height: 32),
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
                  Text('예상 절감액',
                      style:
                          AppTheme.sans(11, sub, weight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('절감액',
                          style: AppTheme.sans(14, ink,
                              weight: FontWeight.w700)),
                      Text(_hasInput ? _won(_saved) : '-',
                          style: AppTheme.sans(16, accent,
                              weight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: line),
                  const SizedBox(height: 12),
                  _row('일반 본인부담 (${(_generalRate * 100).round()}%)',
                      _won(_generalCopay), ink, sub),
                  const SizedBox(height: 8),
                  _row('산정특례 본인부담 (5%)', _won(_specialCopay), ink, sub),
                  const SizedBox(height: 12),
                  Text('* 암·희귀난치·중증화상 등 대부분 5% 적용, 결핵은 0%(면제)입니다.'.keepWords,
                      style: AppTheme.sans(11, sub)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoBox(
              '대상 질환',
              [
                '암 (C00~C97 / D00~D09): 악성신생물, 상피내암, 제자리암',
                '희귀질환·중증난치 약 1,200여 개 등록 질환',
                '중증치매, 중증화상(체표면 30% 이상), 결핵',
                '심뇌혈관질환(수술 후 입원 30일), 인공관절 치환술, 중증외상',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '적용 기간 및 신청',
              [
                '암·희귀·중증난치: 5년(재등록 가능) / 중증화상: 1년(재등록 가능)',
                '진단 의사가 산정특례 등록신청서 작성 → 공단 전자 등록',
                '등록 확인 후 다음 진료부터 자동 적용, 만료 30일 전 재등록 확인',
                '본인부담상한제와 중복 적용되어 연간 상한 초과분은 사후 환급',
              ],
              line,
              sub,
              ink,
            ),
            const CalcDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color ink, Color sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: AppTheme.sans(13, sub))),
        Text(value, style: AppTheme.sans(13, ink, weight: FontWeight.w600)),
      ],
    );
  }

  Widget _infoBox(
      String title, List<String> items, Color line, Color sub, Color ink) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(4)),
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
                Expanded(
                    child: Text(item,
                        style: AppTheme.sans(13, sub, height: 1.5))),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
