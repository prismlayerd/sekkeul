import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

class SeniorDentalScreen extends StatefulWidget {
  const SeniorDentalScreen({super.key});

  @override
  State<SeniorDentalScreen> createState() => _SeniorDentalScreenState();
}

class _SeniorDentalScreenState extends State<SeniorDentalScreen> {
  int _procIdx = 0; // 0=임플란트 1개, 1=완전틀니, 2=부분틀니
  int _insIdx = 0; // 0=건강보험, 1=의료급여 1종, 2=의료급여 2종
  final _fmt = NumberFormat('#,###');

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

  String _won(double v) => '${_fmt.format(v.round())}원';

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
        title: Text('노인 틀니·임플란트',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('시술 종류',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            _dropdown(_procIdx, _procs.map((e) => e.$1).toList(),
                (v) => setState(() => _procIdx = v), ink, line, context),
            const SizedBox(height: 16),
            Text('보험 종별',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
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
                          AppTheme.sans(11, sub, weight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('본인부담금',
                          style: AppTheme.sans(14, ink,
                              weight: FontWeight.w700)),
                      Text(_won(_copay),
                          style: AppTheme.sans(16, accent,
                              weight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: line),
                  const SizedBox(height: 12),
                  _row('표준 보험가', _won(_standardPrice.toDouble()), ink, sub),
                  const SizedBox(height: 8),
                  _row('건강보험·의료급여 부담', _won(_covered), ink, sub),
                  const SizedBox(height: 12),
                  Text('* 2024년 표준 보험가 참고치 기반 단순 추정이며, 실제 진료비는 치과·지역별로 다를 수 있습니다.'.keepWords,
                      style: AppTheme.sans(11, sub)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoBox(
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
            _infoBox(
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
      ),
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
          style: AppTheme.sans(14, ink),
          dropdownColor: Theme.of(context).scaffoldBackgroundColor,
          items: [
            for (int i = 0; i < items.length; i++)
              DropdownMenuItem(
                  value: i, child: Text(items[i], style: AppTheme.sans(14, ink))),
          ],
          onChanged: (v) => onChanged(v!),
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
