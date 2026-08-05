import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class YouthLeapAccountScreen extends StatefulWidget {
  const YouthLeapAccountScreen({super.key});

  @override
  State<YouthLeapAccountScreen> createState() =>
      _YouthLeapAccountScreenState();
}

class _YouthLeapAccountScreenState extends State<YouthLeapAccountScreen> {
  final _ctrl = TextEditingController();
  int _incomeIdx = 0;

  // 소득 구간, 월 정부기여금
  static const _brackets = [
    ('2,400만원 이하', 33000),
    ('2,400~3,600만원', 29000),
    ('3,600~4,800만원', 25000),
    ('4,800~6,000만원', 21000),
    ('6,000~7,500만원', 0),
  ];

  int get _monthlyGov => _brackets[_incomeIdx].$2;
  double get _monthly =>
      double.tryParse(_ctrl.text.replaceAll(',', '')) ?? 0;

  double get _totalSelf => _monthly * 60;
  double get _totalGov => _monthlyGov * 60.0;
  // 단리 추정: 원금 × 연 6% × 5년 / 2 (평균 잔액 기준)
  double get _interest => _totalSelf * 0.06 * 2.5;
  double get _total => _totalSelf + _totalGov + _interest;

  String _manwon(double v) {
    if (v <= 0) return '-';
    final man = (v / 10000).round();
    return '약 ${comma(man)}만원';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    final bg = AppTheme.surface(context);
    final hasInput = _monthly > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('청년도약계좌',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('소득 구간',
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
                  value: _incomeIdx,
                  isExpanded: true,
                  style: AppTheme.sans(14, ink),
                  dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                  items: [
                    for (int i = 0; i < _brackets.length; i++)
                      DropdownMenuItem(
                          value: i,
                          child: Text(_brackets[i].$1,
                              style: AppTheme.sans(14, ink))),
                  ],
                  onChanged: (v) => setState(() => _incomeIdx = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('월 납입액 (최대 700,000원)'.keepWords,
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: const [ThousandsFormatter()],
              style: AppTheme.sans(14, ink),
              decoration: InputDecoration(
                hintText: '700,000',
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
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 32),
            if (hasInput) ...[
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
                    Text('5년 만기 예상',
                        style:
                            AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _row('본인 납입 합계', _manwon(_totalSelf), ink, sub),
                    const SizedBox(height: 8),
                    if (_monthlyGov > 0) ...[
                      _row('정부기여금 합계 (월 ${comma(_monthlyGov)}원)',
                          _manwon(_totalGov), ink, sub),
                      const SizedBox(height: 8),
                    ],
                    _row('예상 이자 (연 6% 단리 추정)', _manwon(_interest), ink, sub),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('예상 만기액',
                            style: AppTheme.sans(14, ink,
                                weight: FontWeight.w700)),
                        Text(_manwon(_total),
                            style: AppTheme.sans(16, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    if (_monthlyGov == 0) ...[
                      const SizedBox(height: 8),
                      Text('해당 소득 구간은 비과세 혜택만 적용됩니다.'.keepWords,
                          style: AppTheme.sans(11, sub)),
                    ],
                    const SizedBox(height: 8),
                    Text('* 이자는 연 6% 단리 기준 추정값. 실제 은행 금리에 따라 상이.'.keepWords,
                        style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '자격 요건',
              [
                '만 19~34세 (병역 이행 기간 최대 6년 추가 인정)',
                '총급여 7,500만원 이하',
                '가구소득 중위 250% 이하',
                '취급 은행: 국민·신한·하나·우리·농협 등 11개',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '구간별 정부기여금',
              [
                '2,400만원 이하: 기여율 6.0% / 월 최대 33,000원',
                '2,400~3,600만원: 4.6% / 월 최대 29,000원',
                '3,600~4,800만원: 3.7% / 월 최대 25,000원',
                '4,800~6,000만원: 3.0% / 월 최대 21,000원',
                '6,000~7,500만원: 비과세 혜택만 (정부기여금 없음)',
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
          Text(title,
              style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
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
