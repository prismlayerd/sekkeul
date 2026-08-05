import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

/// 주택연금(역모기지) 예상 월지급금 참고 추정기.
/// HF 공시 종신·정액형 참고 데이터포인트(3억/60세=63만, 3억/70세=90만,
/// 5억/65세=125만, 5억/75세=192만, 9억/70세=270만)로부터 연령별 억당 지급률을
/// 선형보간하고, 월 375만원 상한(2026 HF 공시)을 적용한 단순 추정치.
class HousingPensionScreen extends StatefulWidget {
  const HousingPensionScreen({super.key});

  @override
  State<HousingPensionScreen> createState() => _HousingPensionScreenState();
}

class _HousingPensionScreenState extends State<HousingPensionScreen> {
  final _ageCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(); // 만원 단위
  final _fmt = NumberFormat('#,###');

  static const int _capWon = 3750000;
  /// 연령 → 1억원당 월지급금(만원) — 종신지급·정액형·일반주택.
  ///
  /// 출처: 한국주택금융공사 「월지급금 예시」(hf.go.kr/ko/sub03/sub03_01_01_02.do),
  /// **2026년 3월 1일 기준**. 확인일 2026-08-01.
  ///
  /// 종전에는 15/21/25/30/38.4라는 어림값을 쓰고 있었다. 공시표와 −3.8%~+0.8%
  /// 어긋났고(70세 3억 주택에서 90만원 vs 공시 92.3만원), 방향도 일정하지 않아
  /// 어느 쪽으로 틀릴지 예측할 수 없었다. 공시표가 있으므로 근사할 이유가 없다.
  ///
  /// 80세를 표에 넣으면 75세 이상이 상수로 고정되지 않고 계속 오른다.
  /// 매년 공시가 갱신되므로 추적: test/notice_expiry_test.dart
  static const _rateAges = [55, 60, 65, 70, 75, 80];
  static const _rates = [15.6, 21.0, 25.2, 30.7, 38.1, 48.3];

  int get _age => int.tryParse(_ageCtrl.text.replaceAll(',', '')) ?? 0;
  double get _priceManwon =>
      double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;
  bool get _hasInput => _ageCtrl.text.isNotEmpty && _priceCtrl.text.isNotEmpty;
  bool get _ageEligible => _age >= 55;
  bool get _priceEligible => _priceManwon <= 120000;

  double get _rate {
    if (_age <= _rateAges.first) return _rates.first;
    if (_age >= _rateAges.last) return _rates.last;
    for (int i = 0; i < _rateAges.length - 1; i++) {
      final a0 = _rateAges[i], a1 = _rateAges[i + 1];
      if (_age >= a0 && _age <= a1) {
        final t = (_age - a0) / (a1 - a0);
        return _rates[i] + (_rates[i + 1] - _rates[i]) * t;
      }
    }
    return _rates.last;
  }

  int get _monthlyPaymentWon {
    if (!_ageEligible || _priceManwon <= 0) return 0;
    final eok = _priceManwon / 10000;
    final raw = (eok * _rate * 10000).round();
    return raw > _capWon ? _capWon : raw;
  }

  String _won(int v) => '${_fmt.format(v)}원';

  @override
  void dispose() {
    _ageCtrl.dispose();
    _priceCtrl.dispose();
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
        title: Text('주택연금',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _inputField('가입자 연령 (부부 중 연소자 기준)', _ageCtrl, '65', '세', ink, sub,
                line),
            const SizedBox(height: 16),
            Text('주택 공시가격 (만원)',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: const [ThousandsFormatter()],
              style: AppTheme.sans(14, ink),
              decoration: InputDecoration(
                hintText: '50,000',
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
              onChanged: (v) {
                final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                final formatted =
                    digits.isEmpty ? '' : _fmt.format(int.parse(digits));
                _priceCtrl.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
                setState(() {});
              },
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
                    Text('예상 월지급금 (종신·정액형 기준)'.keepWords,
                        style:
                            AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('월지급금',
                            style: AppTheme.sans(14, ink,
                                weight: FontWeight.w700)),
                        Text(
                            _ageEligible && _priceEligible
                                ? _won(_monthlyPaymentWon)
                                : '-',
                            style: AppTheme.sans(16, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    if (!_ageEligible)
                      Text('* 만 55세 이상부터 가입 가능합니다.'.keepWords,
                          style: AppTheme.sans(11, sub)),
                    if (!_priceEligible)
                      Text('* 공시가격 12억원(120,000만원) 이하만 가입 가능합니다(다주택 합산).'.keepWords,
                          style: AppTheme.sans(11, sub)),
                    if (_ageEligible && _priceEligible)
                      Text('* HF 공시 월지급금표 기반 선형보간 참고 추정치이며 실제 신청 시 HF 공식 계산기·상담 결과와 다를 수 있습니다.'.keepWords,
                          style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '대상 요건',
              [
                '만 55세 이상 (부부 중 연소자 기준), 대한민국 국적',
                '공시가격 12억원 이하 (다주택자는 합산 공시가격 기준, 12억 초과 2주택은 3년 내 1주택 처분 조건부 가입)',
                '가입 주택에 실거주(전입신고 필수)',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '지급 방식',
              [
                '종신지급 — 평생 매월 동일 금액 수령(가장 일반적)',
                '확정기간혼합 — 일정 기간 집중 수령 후 잔여기간 감액',
                '대출상환방식 — 주택담보대출 잔액 일시 상환 + 잔여분 월지급',
                '우대지급방식 — 부부 중 1명 만 65세 이상 + 기초연금 수급자, 월지급금 최대 20% 증액',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '비용 구조',
              [
                '초기보증료: 주택가격의 1.5% (최초 1회, 분할납부 가능)',
                '연보증료: 보증잔액의 0.75%/년',
                '집값 하락으로 처분가가 지급액 합계보다 낮아도 차액은 HF·정부가 부담(추가 청구 없음)',
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

  Widget _inputField(String label, TextEditingController ctrl, String hint,
      String suffix, Color ink, Color sub, Color line) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          inputFormatters: [
            if (suffix == '원' || suffix == '만원')
              const ThousandsFormatter()
            else
              FilteringTextInputFormatter.digitsOnly,
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
