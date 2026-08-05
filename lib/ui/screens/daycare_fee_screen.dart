import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

class DaycareFeeScreen extends StatefulWidget {
  const DaycareFeeScreen({super.key});

  @override
  State<DaycareFeeScreen> createState() => _DaycareFeeScreenState();
}

class _DaycareFeeScreenState extends State<DaycareFeeScreen> {
  int _ageIdx = 0;
  final _fmt = NumberFormat('#,###');

  // 연령 구간, 어린이집 지원 보육료(월), 가정양육 현금(월), 현금 항목명
  static const _ages = [
    // 2026년 기본보육 단가(아이사랑 childcare.go.kr 공지). 0~2세는 3~5% 인상됐다.
    ('만 0세 (0~11개월)', 584000, 1000000, '부모급여'),
    ('만 1세 (12~23개월)', 515000, 500000, '부모급여'),
    ('만 2세 (24~35개월)', 426000, 100000, '가정양육수당'),
    ('만 3~5세 (누리과정)', 280000, 100000, '가정양육수당'),
  ];

  int get _daycare => _ages[_ageIdx].$2;
  int get _homeCash => _ages[_ageIdx].$3;
  String get _homeLabel => _ages[_ageIdx].$4;

  String _won(int v) => '${_fmt.format(v)}원';

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
        title: Text('보육료 · 가정양육 비교',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('아동 연령',
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
                  value: _ageIdx,
                  isExpanded: true,
                  style: AppTheme.sans(14, ink),
                  dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                  items: [
                    for (int i = 0; i < _ages.length; i++)
                      DropdownMenuItem(
                          value: i,
                          child: Text(_ages[i].$1,
                              style: AppTheme.sans(14, ink))),
                  ],
                  onChanged: (v) => setState(() => _ageIdx = v!),
                ),
              ),
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
                  Text('월 지원액 비교 (택일)',
                      style: AppTheme.sans(11, sub, weight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('어린이집 이용 (보육료 지원)'.keepWords,
                            style: AppTheme.sans(13, ink,
                                weight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text(_won(_daycare),
                          style: AppTheme.sans(14, accent,
                              weight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('어린이집에 직접 지급 (부모 현금 아님)'.keepWords,
                      style: AppTheme.sans(11, sub)),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: line),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('가정양육 ($_homeLabel)'.keepWords,
                          style: AppTheme.sans(13, ink,
                              weight: FontWeight.w600)),
                      Text(_won(_homeCash),
                          style: AppTheme.sans(14, accent,
                              weight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('보호자에게 현금 지급',
                      style: AppTheme.sans(11, sub)),
                  const SizedBox(height: 12),
                  Text('* 보육료와 가정양육 현금은 중복 수급 불가, 둘 중 하나만 선택합니다.'.keepWords,
                      style: AppTheme.sans(11, sub)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoBox(
              '이용 안내',
              [
                '어린이집 이용 시 보육료는 국민행복카드(아이행복카드)로 결제',
                '가정양육 시 부모급여(0~1세)·가정양육수당(2세~) 현금 지급',
                '어린이집 ↔ 가정양육 전환은 매월 15일 기준 복지로·주민센터에서 변경',
                '3~5세 누리과정은 유치원 이용 시 유아학비로 별도 지원',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '신청 방법',
              [
                '복지로(bokjiro.go.kr) 온라인 신청',
                '주민센터 방문 신청',
                '출생신고 시 행복출산 원스톱으로 통합 신청 가능',
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
