import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';
import '../components/calc_widgets.dart';

class SeniorDentalScreen extends StatefulWidget {
  const SeniorDentalScreen({super.key});

  @override
  State<SeniorDentalScreen> createState() => _SeniorDentalScreenState();
}

class _SeniorDentalScreenState extends State<SeniorDentalScreen> {
  int _procIdx = 0; // 0=임플란트 1개, 1=완전틀니, 2=부분틀니
  int _insIdx = 0; // 0=건강보험, 1=의료급여 1종, 2=의료급여 2종

  // 표준금액은 2024년 자료 기준 — 치과 요양급여비용은 매년 수가협상으로 바뀐다(2025년
  // 평균 3.2% 인상 확인됨, 보건복지부 고시). 2025~2026년 개정 표준금액은 1차 미확인.
  static const _procs = [
    ('임플란트 1개', 1300000),
    ('완전틀니', 1400000),
    ('부분틀니', 1400000),
  ];

  static const _insurers = [
    ('건강보험 일반', 0.30),
    ('의료급여 1종', 0.05),
    ('의료급여 2종', 0.15),
  ];

  int get _standardPrice => _procs[_procIdx].$2;
  double get _copayRate => _insurers[_insIdx].$2;
  double get _copay => _standardPrice * _copayRate;
  double get _covered => _standardPrice - _copay;


  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    final bg = AppTheme.surface(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('노인 틀니·임플란트',
            style: AppTheme.serif(AppTheme.tsBase, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('시술 종류',
                style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            _dropdown(_procIdx, _procs.map((e) => e.$1).toList(),
                (v) => setState(() => _procIdx = v), ink, line, context),
            const SizedBox(height: 16),
            Text('보험 종별',
                style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            _dropdown(_insIdx, _insurers.map((e) => e.$1).toList(),
                (v) => setState(() => _insIdx = v), ink, line, context),
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
                  Text('예상 본인부담금',
                      style:
                          AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('본인부담금',
                          style: AppTheme.sans(AppTheme.tsMD, ink,
                              weight: FontWeight.w700)),
                      Text(won(_copay),
                          style: AppTheme.sans(AppTheme.tsBase, accent,
                              weight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: line),
                  const SizedBox(height: 12),
                  calcRow('표준 보험가', won(_standardPrice.toDouble()), ink, sub),
                  const SizedBox(height: 8),
                  calcRow('건강보험·의료급여 부담', won(_covered), ink, sub),
                  const SizedBox(height: 12),
                  Text('* 2024년 표준 보험가 참고치 기반 단순 추정이에요. 치과 수가는 매년 바뀌고 실제 진료비도 치과·지역별로 다를 수 있으니, 정확한 금액은 치과에서 확인하세요.'.keepWords,
                      style: AppTheme.sans(AppTheme.tsXS, sub)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            calcInfoBox(
              '대상 요건',
              [
                '만 65세 이상 건강보험·의료급여 가입자 (생일 기준)',
                '임플란트: 평생 2개(상·하악 합산), 부분무치악 환자 대상',
                '틀니: 완전·부분틀니 각각 7년 1회 보험 적용',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            calcInfoBox(
              '유의사항',
              [
                '지르코니아·세라믹·금 등 고급 재료는 비급여로 전액 본인부담',
                '뼈이식·상악동 거상술 등 추가 수술은 별도 비급여',
                '임플란트는 진단→식립→보철 3단계로 나눠 각 단계마다 본인부담금만 결제',
                '단계 미완료 상태에서 치과를 옮기면 본인부담이 늘어날 수 있음',
              ],
              line,
              sub,
              ink,
            ),
            const CalcDisclaimer(),
          ],
        ),
      )),
    );
  }

  Widget _dropdown(int value, List<String> items, ValueChanged<int> onChanged,
      Color ink, Color line, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(4)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          style: AppTheme.sans(AppTheme.tsMD, ink),
          dropdownColor: AppTheme.backgroundColor(context),
          items: [
            for (int i = 0; i < items.length; i++)
              DropdownMenuItem(
                  value: i, child: Text(items[i], style: AppTheme.sans(AppTheme.tsMD, ink))),
          ],
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }

}
