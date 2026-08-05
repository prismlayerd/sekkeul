import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';

class DisabilityPensionScreen extends StatefulWidget {
  const DisabilityPensionScreen({super.key});

  @override
  State<DisabilityPensionScreen> createState() =>
      _DisabilityPensionScreenState();
}

class _DisabilityPensionScreenState extends State<DisabilityPensionScreen> {
  int _severityIdx = 0; // 0=중증, 1=경증
  int _ageIdx = 0; // 0=18~64세, 1=65세 이상
  int _incomeIdx = 0; // 0=기초생활수급, 1=차상위계층, 2=일반

  // 중증(장애인연금): [연령][소득] -> 월 지급액(원). 2026년 기준.
  // 기초급여 349,700원(물가 2.1% 반영) + 부가급여(보건복지부 장애인연금 개요).
  // 부가급여는 18~64세 9만/8만/3만, 65세 이상 439,700/8만/5만 —
  // 보도자료가 밝힌 범위(18~64세 3만~9만, 전체 3만~439,700)와 맞물린다.
  // 65세 이상은 기초급여가 기초연금으로 대체되므로 349,700원을 더해 총 수령액을 보인다.
  static const _severeAmounts = [
    // 18~64세: 기초생활수급, 차상위, 일반
    [439700, 429700, 379700],
    // 65세 이상
    [789400, 429700, 399700],
  ];

  // 경증(장애수당): 재가 기준, 소득 무관 4만원
  static const int _mildAmount = 40000;

  int get _amount =>
      _severityIdx == 0 ? _severeAmounts[_ageIdx][_incomeIdx] : _mildAmount;


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
        title: Text('장애인연금·장애수당',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('장애 정도',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _segButton('중증 (구 1~3급)', 0, _severityIdx,
                        (v) => setState(() => _severityIdx = v), ink, line,
                        accent)),
                const SizedBox(width: 8),
                Expanded(
                    child: _segButton('경증 (구 4~6급)', 1, _severityIdx,
                        (v) => setState(() => _severityIdx = v), ink, line,
                        accent)),
              ],
            ),
            if (_severityIdx == 0) ...[
              const SizedBox(height: 16),
              Text('연령 구간',
                  style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _segButton('18~64세', 0, _ageIdx,
                          (v) => setState(() => _ageIdx = v), ink, line,
                          accent)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _segButton('65세 이상', 1, _ageIdx,
                          (v) => setState(() => _ageIdx = v), ink, line,
                          accent)),
                ],
              ),
              const SizedBox(height: 16),
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
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('기초생활수급')),
                      DropdownMenuItem(value: 1, child: Text('차상위계층')),
                      DropdownMenuItem(value: 2, child: Text('일반')),
                    ],
                    onChanged: (v) => setState(() => _incomeIdx = v!),
                  ),
                ),
              ),
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
                  Text('월 예상 지원금',
                      style:
                          AppTheme.sans(11, sub, weight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_severityIdx == 0 ? '장애인연금' : '장애수당',
                          style: AppTheme.sans(14, ink,
                              weight: FontWeight.w700)),
                      Text(won(_amount),
                          style: AppTheme.sans(16, accent,
                              weight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                      _severityIdx == 0
                          ? '* 기초급여+부가급여 합산 참고 추정치. 65세 이상 기초생활수급자는 기초연금 통합분 포함.'
                          : '* 재가 거주 기준. 보장시설 입소자는 월 2만원으로 낮아집니다.',
                      style: AppTheme.sans(11, sub)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoBox(
              '대상 요건',
              [
                '만 18세 이상 등록 장애인, 대한민국 국민',
                '장애인연금(중증): 소득인정액 단독 140만원/부부 224만원 이하(2026년)',
                '18세 미만은 장애아동수당 별도(중증 22만원, 경증 11만원)',
                '부양의무자 기준 폐지 — 본인·배우자 소득만 심사',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '신청 방법',
              [
                '읍·면·동 주민센터 방문 또는 복지로(bokjiro.go.kr) 온라인',
                '필요 서류: 장애인등록증·신분증·소득/재산 증빙·통장사본',
                '심사 30~60일, 지급은 신청 다음 달부터 매월 25일',
                '3개 제도(장애인연금·장애수당·장애아동수당)는 중복 불가, 상위 1개만 적용',
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: selected ? accent : line),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AppTheme.sans(13, selected ? accent : ink,
                weight: FontWeight.w600)),
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
