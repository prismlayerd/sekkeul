import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class BasicPensionScreen extends StatefulWidget {
  const BasicPensionScreen({super.key});

  @override
  State<BasicPensionScreen> createState() => _BasicPensionScreenState();
}

class _BasicPensionScreenState extends State<BasicPensionScreen> {
  final _ageCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController(); // 소득인정액, 만원 단위
  int _householdIdx = 0; // 0=단독, 1=부부
  final _fmt = NumberFormat('#,###');

  static const _thresholdManwon = [247, 395]; // 단독/부부 선정기준액(만원)
  static const _baseAmountWon = [349700, 279760]; // 단독 최대 / 부부 1인당(20% 감액)

  int get _age => int.tryParse(_ageCtrl.text.replaceAll(',', '')) ?? 0;
  double get _income => double.tryParse(_incomeCtrl.text.replaceAll(',', '')) ?? 0;
  bool get _hasInput => _ageCtrl.text.isNotEmpty && _incomeCtrl.text.isNotEmpty;

  bool get _ageEligible => _age >= 65;
  bool get _incomeEligible => _income <= _thresholdManwon[_householdIdx];
  bool get _eligible => _ageEligible && _incomeEligible;

  int get _monthlyAmount {
    if (!_eligible) return 0;
    if (_householdIdx == 0) return _baseAmountWon[0];
    return _baseAmountWon[1] * 2; // 부부 각각 수급 시 가구 합산 표시
  }

  String _won(int v) => '${_fmt.format(v)}원';

  @override
  void dispose() {
    _ageCtrl.dispose();
    _incomeCtrl.dispose();
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
        title: Text('기초연금 계산기',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('가구 구분',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _segButton('단독가구', 0, ink, sub, line, accent)),
                const SizedBox(width: 8),
                Expanded(child: _segButton('부부가구', 1, ink, sub, line, accent)),
              ],
            ),
            const SizedBox(height: 16),
            _inputField('만 나이', _ageCtrl, '65', '세', ink, sub, line, isDecimal: false),
            const SizedBox(height: 16),
            Text('월 소득인정액 (만원)',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _incomeCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: const [ThousandsFormatter()],
              style: AppTheme.sans(14, ink),
              decoration: InputDecoration(
                hintText: '150',
                hintStyle: AppTheme.sans(14, sub),
                suffixText: '만원',
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
            if (_hasInput) ...[
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
                    Text('수급 가능 여부',
                        style: AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_eligible ? '수급 가능' : '수급 불가',
                            style: AppTheme.sans(16, ink,
                                weight: FontWeight.w700)),
                        Text(_eligible ? _won(_monthlyAmount) : '-',
                            style: AppTheme.sans(16, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    if (!_ageEligible)
                      Text('* 만 65세 이상부터 신청 가능합니다.'.keepWords,
                          style: AppTheme.sans(11, sub)),
                    if (_ageEligible && !_incomeEligible)
                      Text(
                          '* 소득인정액이 선정기준액(${_thresholdManwon[_householdIdx]}만원)을 초과했습니다.'.keepWords,
                          style: AppTheme.sans(11, sub)),
                    if (_eligible)
                      Text('* 국민연금 연계감액·부부감액·소득역전방지감액 적용 전 기준연금액입니다.'.keepWords,
                          style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '대상 요건',
              [
                '만 65세 이상 대한민국 국민, 국내 거주자',
                '소득인정액: 단독가구 247만원 이하 / 부부가구 395.2만원 이하 (하위 70%)',
                '공무원·사학·군인·별정우체국 등 직역연금 수급자 및 배우자는 제외(특례 예외)',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '감액 규정',
              [
                '부부 모두 수급 시 각각 20% 감액',
                '국민연금 월 수령액이 기준연금액의 150%(약 52.5만원) 초과 시 단계적 감액',
                '소득인정액이 선정기준선에 근접하면 소득역전방지 감액 적용',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '신청 방법',
              [
                '읍·면·동 주민센터 방문, 국민연금공단 지사 방문',
                '복지로(bokjiro.go.kr) 온라인 신청',
                '생일 한 달 전부터 신청 가능, 신청한 달부터 지급(소급 없음)',
                '매월 25일 지정 계좌 입금',
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

  Widget _segButton(String label, int idx, Color ink, Color sub, Color line,
      Color accent) {
    final selected = _householdIdx == idx;
    return GestureDetector(
      onTap: () => setState(() => _householdIdx = idx),
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

  Widget _inputField(String label, TextEditingController ctrl, String hint,
      String suffix, Color ink, Color sub, Color line,
      {bool isDecimal = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
          textAlign: TextAlign.right,
inputFormatters: [
            if (suffix == '원' || suffix == '만원')
              const ThousandsFormatter()
            else
              isDecimal
                  ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  : FilteringTextInputFormatter.digitsOnly,
          ],
          style: AppTheme.sans(14, ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTheme.sans(14, sub),
            suffixText: suffix,
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
