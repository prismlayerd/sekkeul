import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

class EnergyVoucherScreen extends StatefulWidget {
  const EnergyVoucherScreen({super.key});

  @override
  State<EnergyVoucherScreen> createState() => _EnergyVoucherScreenState();
}

class _EnergyVoucherScreenState extends State<EnergyVoucherScreen> {
  int _householdSize = 0;
  bool _isEligible = false;
  final _fmt = NumberFormat('#,###');

  static const List<String> _sizeLabels = ['1인', '2인', '3인', '4인 이상'];

  /// 2026년 가구원수별 지원금액(한국에너지공단 energyv.or.kr).
  ///
  /// 2026년부터 **하·동절기 구분이 없어졌다.** 종전에는 여름·겨울 바우처를
  /// 따로 두고 각각 사용 상한이 있었는데, 이제 사용기간(26.7.1~27.5.31)
  /// 동안 연간 총액을 자유롭게 쓴다.
  static const List<int> _annual = [295200, 407500, 532700, 701300];

  int get _annualTotal => _annual[_householdSize];

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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        title: Text('에너지바우처 예상액',
            style: AppTheme.serif(16, ink, weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _isEligible,
                  onChanged: (v) => setState(() => _isEligible = v ?? false),
                  activeColor: accent,
                ),
                Expanded(
                    child: Text('생계·의료·주거·교육급여 수급자 또는 차상위계층에 해당'.keepWords,
                        style: AppTheme.sans(13, ink))),
              ],
            ),
            const SizedBox(height: 16),
            Text('가구원 수', style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(_sizeLabels.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == _sizeLabels.length - 1 ? 0 : 6),
                    child: _segButton(_sizeLabels[i], i, _householdSize,
                        (v) => setState(() => _householdSize = v), ink, line, accent),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            if (_isEligible) ...[
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
                    Text('예상 지원액', style: AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('연간 합계',
                            style: AppTheme.sans(14, ink, weight: FontWeight.w700)),
                        Text(_won(_annualTotal),
                            style: AppTheme.sans(16, accent, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('사용기간', '26.7.1 ~ 27.5.31', ink, sub),
                    const SizedBox(height: 8),
                    _row('계절 구분', '없음 (기간 내 자유 사용)', ink, sub),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    border: Border.all(color: line), borderRadius: BorderRadius.circular(4)),
                child: Text('가구원 구성 요건(65세 이상·영유아·임산부·장애인·한부모·희귀난치질환자 등)을 충족하는지 먼저 확인하세요.'.keepWords,
                    style: AppTheme.sans(13, sub, height: 1.5)),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox('대상 요건 (모두 충족)', const [
              '소득: 생계·의료·주거·교육급여 수급자 또는 차상위계층(차상위 자활·장애수당 포함)',
              '가구원: 65세 이상 노인, 영유아(만 6세 미만), 임산부, 등록장애인, 한부모가족, 소년소녀가정, 중증·희귀질환자 중 1인 이상 포함',
              '자동으로 지급되지 않으며 반드시 별도 신청이 필요합니다.',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('신청 방법 · 기간', const [
              '읍·면·동 주민센터 방문(신분증, 가족관계증명서 지참)',
              '복지로(bokjiro.go.kr)에서 온라인 신청 가능',
              '거동이 불편한 경우 주민센터에 방문 신청 요청 가능',
              '2026년 신청기간: 5.27~12.31',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('사용 방법 · 유의사항', const [
              '여름(7.1~9.30): 전기요금에서 자동 차감',
              '겨울(10.15~4.30): 전기요금 차감 또는 국민행복카드로 가스·등유·LPG·연탄 등 구입',
              '겨울 바우처는 한국에너지재단 등유 지원과 중복 수급이 불가합니다.',
              '미사용 잔액은 이월·환급되지 않고 소멸됩니다.',
            ], line, sub, ink),
            const CalcDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _segButton(String label, int value, int groupValue,
      ValueChanged<int> onChanged, Color ink, Color line, Color accent) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            border: Border.all(color: selected ? accent : line),
            borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            style: AppTheme.sans(12, selected ? accent : ink, weight: FontWeight.w600)),
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

  Widget _infoBox(String title, List<String> items, Color line, Color sub, Color ink) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(4)),
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
                Expanded(child: Text(item, style: AppTheme.sans(13, sub, height: 1.5))),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
