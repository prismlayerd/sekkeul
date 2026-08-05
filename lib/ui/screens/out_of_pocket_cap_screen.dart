import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

/// (소득분위 라벨, 일반 상한액, 요양병원 120일 초과 입원 상한액) — 원 단위.
///
/// 출처: 보건복지부 「2025년도 본인부담상한액」 사전정보공표
/// (mohw.go.kr, list_no=1486195). 확인일 2026-08-01.
///
/// 종전 값은 **어느 연도와도 맞지 않았다.** 7개 구간 중 3개만 2024년 값과
/// 같고 나머지는 2024·2025 어느 쪽도 아니었다(4~5분위 162만, 6~7분위 303만,
/// 8분위 414만, 9분위 497만). 요양병원 열도 연도가 뒤섞여 있었고 8분위 이상은
/// 일반값이 그대로 들어가 있었다.
///
/// 보건복지부 고시로 **매년 바뀐다.** 추적: test/notice_expiry_test.dart
const outOfPocketCapTiers = [
  ('1분위 (하위 10% 이하)', 890000, 1410000),
  ('2~3분위', 1100000, 1780000),
  ('4~5분위', 1700000, 2400000),
  ('6~7분위', 3200000, 3960000),
  ('8분위', 4370000, 5690000),
  ('9분위', 5250000, 6840000),
  ('10분위 (상위 10% 이상)', 8260000, 10740000),
];

class OutOfPocketCapScreen extends StatefulWidget {
  const OutOfPocketCapScreen({super.key});

  @override
  State<OutOfPocketCapScreen> createState() => _OutOfPocketCapScreenState();
}

class _OutOfPocketCapScreenState extends State<OutOfPocketCapScreen> {
  int _tierIdx = 3;
  /// 요양병원에 120일을 넘겨 입원했는가 — 그러면 상한액이 따로 적용된다.
  /// 1분위 기준 89만 → 141만으로 52만원이나 달라져서, 안 물으면 그만큼 틀린
  /// 환급액을 보여주게 된다.
  bool _longTermCare = false;
  final _amountCtrl = TextEditingController();


  double get _amount =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
  int get _cap =>
      _longTermCare ? outOfPocketCapTiers[_tierIdx].$3 : outOfPocketCapTiers[_tierIdx].$2;
  double get _refund => _amount > _cap ? _amount - _cap : 0;
  bool get _hasInput => _amount > 0;


  @override
  void dispose() {
    _amountCtrl.dispose();
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
        title: Text('본인부담상한제 환급',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('소득분위',
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
                  value: _tierIdx,
                  isExpanded: true,
                  style: AppTheme.sans(14, ink),
                  dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                  items: [
                    for (int i = 0; i < outOfPocketCapTiers.length; i++)
                      DropdownMenuItem(
                          value: i,
                          child: Text(outOfPocketCapTiers[i].$1,
                              style: AppTheme.sans(14, ink))),
                  ],
                  onChanged: (v) => setState(() => _tierIdx = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('연간 건강보험 본인부담금 총합'.keepWords,
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: const [ThousandsFormatter()],
              style: AppTheme.sans(14, ink),
              decoration: InputDecoration(
                hintText: '3,000,000',
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
                    digits.isEmpty ? '' : comma(int.parse(digits));
                _amountCtrl.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
                setState(() {});
              },
            ),
            const SizedBox(height: 20),

            // 요양병원 120일 초과 입원은 상한액이 따로 있다 — 안 물으면 1분위 기준
            // 52만원(89만 vs 141만)이나 틀린 환급액을 보여주게 된다.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('요양병원 120일 초과 입원',
                          style: AppTheme.sans(14, ink)),
                      Text('올해 요양병원 입원일수가 120일을 넘으면 상한액이 따로 적용돼요'
                          .keepWords,
                          style: AppTheme.sans(11, sub)),
                    ],
                  ),
                ),
                Switch(
                  value: _longTermCare,
                  onChanged: (v) => setState(() => _longTermCare = v),
                ),
              ],
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
                  Text('예상 환급 결과',
                      style:
                          AppTheme.sans(11, sub, weight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('예상 환급액',
                          style: AppTheme.sans(14, ink,
                              weight: FontWeight.w700)),
                      Text(_hasInput ? won(_refund) : '-',
                          style: AppTheme.sans(16, accent,
                              weight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: line),
                  const SizedBox(height: 12),
                  _row('적용 상한액', won(_cap.toDouble()), ink, sub),
                  const SizedBox(height: 8),
                  if (_hasInput && _refund <= 0)
                    Text('* 본인부담금이 상한액을 초과하지 않아 환급 대상이 아닙니다.'.keepWords,
                        style: AppTheme.sans(11, sub)),
                  Text(
                      '* 2025년 기준 상한액'
                      '${_longTermCare ? ' (요양병원 120일 초과)' : ''}. '
                      '연도별 상한액은 매년 8월경 재고시됩니다.'.keepWords,
                      style: AppTheme.sans(11, sub)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoBox(
              '포함/제외 항목',
              [
                '포함: 건강보험 급여 진료의 본인부담금(입원·외래·약국) 합산',
                '제외: 비급여(선택진료·상급병실차액·미용성형), 치과 임플란트 비급여, 한방 비급여',
                '의료급여 수급자는 별도 제도 적용',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '환급 절차',
              [
                '전년도 본인부담금 집계 후 다음해 6~7월 정산',
                '8월경 공단이 환급 대상자에게 우편·모바일로 안내',
                '민원여기요(minwon.nhis.or.kr)·The건강보험 앱·지사 방문·전화(1577-1000)로 신청',
                '신청하지 않으면 5년(소멸시효) 후 환급금 소멸',
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
