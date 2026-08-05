import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class KpassClimateCardScreen extends StatefulWidget {
  const KpassClimateCardScreen({super.key});

  @override
  State<KpassClimateCardScreen> createState() => _KpassClimateCardScreenState();
}

class _KpassClimateCardScreenState extends State<KpassClimateCardScreen> {
  final _ridesCtrl = TextEditingController(text: '30');
  final _fareCtrl = TextEditingController(text: '1500');
  int _kpassType = 0;
  bool _isYouthClimate = false;
  bool _ddareungi = false;

  static const List<String> _kpassLabels = ['일반', '청년', '저소득', '2자녀', '3자녀+'];
  static const List<double> _kpassRates = [20, 30, 53.3, 30, 50];

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '')) ?? 0;

  int get _rides => _num(_ridesCtrl).clamp(0, 60).toInt();
  double get _fare => _num(_fareCtrl);

  double get _kpassMonthlySpend => _rides * _fare;
  double get _kpassRefund => _kpassMonthlySpend * (_kpassRates[_kpassType] / 100);
  double get _kpassRealCost => _kpassMonthlySpend - _kpassRefund;

  double get _climateFee {
    double base = _isYouthClimate ? 55000 : 62000;
    if (_ddareungi) base += 3000;
    return base;
  }

  bool get _hasInput => _rides > 0 && _fare > 0;


  @override
  void dispose() {
    _ridesCtrl.dispose();
    _fareCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    final bg = AppTheme.surface(context);
    final cheaper = _kpassRealCost <= _climateFee ? 'K-패스' : '기후동행카드';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('K-패스 · 기후동행카드 비교'.keepWords,
            style: AppTheme.serif(16, ink, weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _numField('월 평균 대중교통 이용 횟수', _ridesCtrl, '회', ink, sub, line),
            const SizedBox(height: 16),
            _numField('1회 평균 요금', _fareCtrl, '원', ink, sub, line),
            const SizedBox(height: 20),
            Text('K-패스 대상 유형', style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(_kpassLabels.length, (i) {
                final selected = _kpassType == i;
                return GestureDetector(
                  onTap: () => setState(() => _kpassType = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        border: Border.all(color: selected ? accent : line),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(_kpassLabels[i],
                        style: AppTheme.sans(12, selected ? accent : ink,
                            weight: FontWeight.w600)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Text('기후동행카드 조건', style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _segButton('일반', !_isYouthClimate,
                      () => setState(() => _isYouthClimate = false), ink, line, accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _segButton('청년(19~39세)', _isYouthClimate,
                      () => setState(() => _isYouthClimate = true), ink, line, accent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _ddareungi,
                  onChanged: (v) => setState(() => _ddareungi = v ?? false),
                  activeColor: accent,
                ),
                Text('따릉이 옵션 포함(+3,000원)'.keepWords, style: AppTheme.sans(13, ink)),
              ],
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
                    Text('월 비용 비교', style: AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('더 유리한 카드',
                            style: AppTheme.sans(14, ink, weight: FontWeight.w700)),
                        Text(cheaper,
                            style: AppTheme.sans(16, accent, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('K-패스 환급액', won(_kpassRefund), ink, sub),
                    const SizedBox(height: 8),
                    _row('K-패스 실질 부담액', won(_kpassRealCost), ink, sub),
                    const SizedBox(height: 8),
                    _row('기후동행카드 월 금액', won(_climateFee), ink, sub),
                    const SizedBox(height: 12),
                    Text('* 두 제도는 중복 사용이 불가하며, 하나를 선택해야 합니다.'.keepWords,
                        style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox('K-패스 환급률', const [
              '일반: 20% · 청년(19~34세): 30% · 저소득·차상위: 53.3%',
              '2자녀 가구: 30% · 3자녀 이상: 50%',
              '월 15회 이상 60회까지 실적만 인정',
              '전국 189개 지자체에서 사용 가능, 신분당선·광역버스 포함',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('기후동행카드', const [
              '일반 62,000원/월, 청년(19~39세) 55,000원/월 (따릉이 포함 시 +3,000원)',
              '서울 지역 내 지하철·버스 무제한 이용(신분당선·광역버스 제외)',
              '월 50회 이상 이용 시 유리한 경우가 많습니다.',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('알뜰교통카드 → K-패스 전환 안내', const [
              '알뜰교통카드는 2024년 4월 30일 종료, K-패스는 2024년 5월 1일 시행',
              '자동 전환되지 않으므로 K-패스 공식 홈페이지(korea-pass.kr)에서 별도 가입 필요',
              '기존 알뜰카드 잔여 마일리지는 카드사에서 현금 정산되며 K-패스로 이관되지 않습니다.',
              '청년·저소득 자격은 K-패스에서 증빙서류를 다시 제출해야 합니다.',
            ], line, sub, ink),
          ],
        ),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl, String suffix,
      Color ink, Color sub, Color line) {
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
            suffixText: suffix,
            suffixStyle: AppTheme.sans(14, sub),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: ink)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _segButton(
      String label, bool selected, VoidCallback onTap, Color ink, Color line, Color accent) {
    return GestureDetector(
      onTap: onTap,
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
