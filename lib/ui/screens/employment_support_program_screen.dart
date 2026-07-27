import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../theme/text_wrap.dart';

class EmploymentSupportProgramScreen extends StatefulWidget {
  const EmploymentSupportProgramScreen({super.key});

  @override
  State<EmploymentSupportProgramScreen> createState() =>
      _EmploymentSupportProgramScreenState();
}

class _EmploymentSupportProgramScreenState
    extends State<EmploymentSupportProgramScreen> {
  int _typeIdx = 0; // 0=I형, 1=II형
  int _dependents = 0; // 0~4
  bool _includeSuccessBonus = true;
  final _fmt = NumberFormat('#,###');

  static const int _monthlyAllowance = 600000;
  static const int _months = 6;
  static const int _dependentBonusPerPerson = 100000;
  static const int _successBonus = 1500000;
  static const int _typeIIAmount = 1954000;

  int get _typeITotal {
    final base = _monthlyAllowance * _months;
    final dependentBonus = _dependentBonusPerPerson * _dependents * _months;
    final success = _includeSuccessBonus ? _successBonus : 0;
    return base + dependentBonus + success;
  }

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
        title: Text('국민취업지원제도',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('유형',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _segButton('I형 (구직촉진수당)', 0, _typeIdx,
                      (v) => setState(() => _typeIdx = v), ink, line, accent)),
              const SizedBox(width: 8),
              Expanded(
                  child: _segButton('II형 (취업활동비용)', 1, _typeIdx,
                      (v) => setState(() => _typeIdx = v), ink, line, accent)),
            ]),
            if (_typeIdx == 0) ...[
              const SizedBox(height: 16),
              Text('부양가족 수',
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
                    value: _dependents,
                    isExpanded: true,
                    style: AppTheme.sans(14, ink),
                    dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                    items: [
                      for (int i = 0; i <= 4; i++)
                        DropdownMenuItem(value: i, child: Text('$i명')),
                    ],
                    onChanged: (v) => setState(() => _dependents = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('취업성공수당 포함',
                  style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _boolButton('포함 (조기취업·장기근속)', true,
                        _includeSuccessBonus,
                        (v) => setState(() => _includeSuccessBonus = v), ink,
                        line, accent)),
                const SizedBox(width: 8),
                Expanded(
                    child: _boolButton('미포함', false, _includeSuccessBonus,
                        (v) => setState(() => _includeSuccessBonus = v), ink,
                        line, accent)),
              ]),
            ],
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
                  Text('예상 총 수령액',
                      style:
                          AppTheme.sans(11, sub, weight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(_typeIdx == 0 ? _won(_typeITotal) : _won(_typeIIAmount),
                      style: AppTheme.sans(20, accent, weight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (_typeIdx == 0) ...[
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('기본 월수당 (6개월)',
                        _won(_monthlyAllowance * _months), ink, sub),
                    const SizedBox(height: 8),
                    _row('부양가족 가산',
                        _won(_dependentBonusPerPerson * _dependents * _months),
                        ink, sub),
                    const SizedBox(height: 8),
                    _row('취업성공수당',
                        _won(_includeSuccessBonus ? _successBonus : 0), ink,
                        sub),
                  ],
                  const SizedBox(height: 12),
                  Text('* 실지급액은 참여자 상황·출석·구직활동 이행 여부에 따라 달라지는 추정치입니다.'.keepWords,
                      style: AppTheme.sans(11, sub)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoBox(
              '대상 요건 비교',
              [
                'I형: 만 15~69세(청년특례 18~34세), 중위소득 60%(청년 120%) 이하, 재산 4억(청년 5억) 이하, 최근 2년 내 취업경험 100일·800시간 이상',
                'II형: 만 15~69세, 중위소득 100% 이하, 취업경험 요건 없음, 재산 기준 완화',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '신청 절차',
              [
                '고용24(work24.go.kr)·워크넷에서 공동인증서 로그인 후 신청',
                '소득·재산·취업경험 서류 제출',
                '14일 이내 고용센터 담당자 면담 예약',
                '취업활동계획(IAP) 수립 후 심사 통과 시 매월 수당 지급 시작',
                '정기 출석·구직활동 미이행 시 해당 월 수당 감액·정지',
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

  Widget _segButton(String label, int value, int groupValue,
      ValueChanged<int> onChanged, Color ink, Color line, Color accent) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: selected ? accent : line),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: AppTheme.sans(12, selected ? accent : ink,
                weight: FontWeight.w600)),
      ),
    );
  }

  Widget _boolButton(String label, bool value, bool groupValue,
      ValueChanged<bool> onChanged, Color ink, Color line, Color accent) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: selected ? accent : line),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: AppTheme.sans(12, selected ? accent : ink,
                weight: FontWeight.w600)),
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
