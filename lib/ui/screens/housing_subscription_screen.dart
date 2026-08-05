import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

class HousingSubscriptionScreen extends StatefulWidget {
  const HousingSubscriptionScreen({super.key});

  @override
  State<HousingSubscriptionScreen> createState() =>
      _HousingSubscriptionScreenState();
}

class _HousingSubscriptionScreenState
    extends State<HousingSubscriptionScreen> {
  // 무주택기간: 0년~15년 (index 0~15), 16년+ (index 16)
  static const List<int> _homelessPoints = [
    0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32
  ];
  static const List<String> _homelessLabels = [
    '0년', '1년', '2년', '3년', '4년', '5년', '6년', '7년', '8년',
    '9년', '10년', '11년', '12년', '13년', '14년', '15년', '16년+'
  ];

  // 부양가족: 0명~6명+
  static const List<int> _dependentPoints = [5, 10, 15, 20, 25, 30, 35];
  static const List<String> _dependentLabels = [
    '0명', '1명', '2명', '3명', '4명', '5명', '6명+'
  ];

  // 청약통장 가입기간: 0~15년, 17점은 15년+
  static const List<int> _subscriptionPoints = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17
  ];
  static const List<String> _subscriptionLabels = [
    '6개월미만', '6개월', '1년', '2년', '3년', '4년', '5년', '6년',
    '7년', '8년', '9년', '10년', '11년', '12년', '13년', '14년', '15년+'
  ];

  int _homelessIdx = 0;
  int _dependentIdx = 0;
  int _subscriptionIdx = 0;

  void _reset() => setState(() {
        _homelessIdx = 0;
        _dependentIdx = 0;
        _subscriptionIdx = 0;
      });

  int get _homelessPts => _homelessPoints[_homelessIdx];
  int get _dependentPts => _dependentPoints[_dependentIdx];
  int get _subscriptionPts => _subscriptionPoints[_subscriptionIdx];
  int get _total => _homelessPts + _dependentPts + _subscriptionPts;

  String _grade(int total) {
    if (total >= 70) return '상위권';
    if (total >= 55) return '중상위';
    if (total >= 40) return '중위권';
    return '하위권';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;
    final total = _total;

    return Scaffold(
      appBar: AppBar(
        title: Text('청약가점',
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
            Text('청약가점을\n계산해요',
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text('무주택기간 + 부양가족 수 + 청약통장 기간으로 최대 84점'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            // 무주택기간
            _sectionCard(
              context,
              title: '무주택기간',
              subtitle: '만 30세 이후 또는 혼인 시점부터 산정',
              maxPts: 32,
              pts: _homelessPts,
              textColor: textColor,
              subColor: subColor,
              primary: primary,
              child: _scrollSelector(
                labels: _homelessLabels,
                selectedIdx: _homelessIdx,
                onTap: (i) => setState(() => _homelessIdx = i),
                primary: primary,
                subColor: subColor,
              ),
            ),
            const SizedBox(height: 12),

            // 부양가족
            _sectionCard(
              context,
              title: '부양가족 수',
              subtitle: '본인 제외, 주민등록 등재 부양가족',
              maxPts: 35,
              pts: _dependentPts,
              textColor: textColor,
              subColor: subColor,
              primary: primary,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_dependentLabels.length, (i) {
                  final sel = _dependentIdx == i;
                  return GestureDetector(
                    onTap: () => setState(() => _dependentIdx = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? primary
                            : primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_dependentLabels[i]}  ${_dependentPoints[i]}점'.keepWords,
                        style: TextStyle(
                            color: sel ? Colors.white : subColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),

            // 청약통장
            _sectionCard(
              context,
              title: '청약통장 가입기간',
              subtitle: '청약저축·주택청약종합저축 기준',
              maxPts: 17,
              pts: _subscriptionPts,
              textColor: textColor,
              subColor: subColor,
              primary: primary,
              child: _scrollSelector(
                labels: _subscriptionLabels,
                selectedIdx: _subscriptionIdx,
                onTap: (i) => setState(() => _subscriptionIdx = i),
                primary: primary,
                subColor: subColor,
              ),
            ),
            const SizedBox(height: 24),

            // 결과
            Container(
              padding: const EdgeInsets.all(20),
              decoration:
                  AppTheme.getAccentCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.home_outlined, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text('나의 청약가점',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$total',
                          style: TextStyle(
                              color: primary,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              height: 1)),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('/ 84점',
                            style: TextStyle(
                                color: subColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_grade(total),
                            style: TextStyle(
                                color: primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _row('무주택기간', '$_homelessPts점', subColor, textColor),
                  const SizedBox(height: 8),
                  _row('부양가족', '$_dependentPts점', subColor, textColor),
                  const SizedBox(height: 8),
                  _row('청약통장', '$_subscriptionPts점', subColor, textColor),
                  const SizedBox(height: 12),
                  // 진행 바
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total / 84,
                      minHeight: 8,
                      backgroundColor: primary.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                ],
              ),
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
                    '• 무주택기간은 만 30세 또는 혼인 시점부터 산정됩니다.\n'
                    '• 부양가족은 세대원(배우자·직계존비속 등) 기준입니다.\n'
                    '• 청약통장은 가입일 기준, 최대 15년+에 17점이 부여됩니다.\n'
                    '• 분양 시 당첨자 발표일 기준으로 가점이 산정됩니다.',
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

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int maxPts,
    required int pts,
    required Color textColor,
    required Color subColor,
    required Color primary,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      Text(subtitle,
                          style: TextStyle(
                              color: subColor.withValues(alpha: 0.8),
                              fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('$pts / $maxPts점',
                    style: TextStyle(
                        color: primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );

  Widget _scrollSelector({
    required List<String> labels,
    required int selectedIdx,
    required void Function(int) onTap,
    required Color primary,
    required Color subColor,
  }) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (i) {
            final sel = selectedIdx == i;
            return GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                margin: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? primary : primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(labels[i],
                    style: TextStyle(
                        color: sel ? Colors.white : subColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            );
          }),
        ),
      );

  Widget _row(String label, String value, Color labelColor, Color valueColor) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      );
}
