import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class DriverLicenseRenewalScreen extends StatefulWidget {
  const DriverLicenseRenewalScreen({super.key});

  @override
  State<DriverLicenseRenewalScreen> createState() =>
      _DriverLicenseRenewalScreenState();
}

class _DriverLicenseRenewalScreenState
    extends State<DriverLicenseRenewalScreen> {
  final _yearCtrl = TextEditingController();
  final _monthCtrl = TextEditingController();
  final _dayCtrl = TextEditingController();
  final _ageAtRenewalCtrl = TextEditingController();

  int? get _year => int.tryParse(_yearCtrl.text.replaceAll(',', ''));
  int? get _month => int.tryParse(_monthCtrl.text.replaceAll(',', ''));
  int? get _day => int.tryParse(_dayCtrl.text.replaceAll(',', ''));
  int get _ageAtRenewal => int.tryParse(_ageAtRenewalCtrl.text.replaceAll(',', '')) ?? 0;

  bool get _hasInput =>
      _year != null && _month != null && _day != null && _ageAtRenewalCtrl.text.isNotEmpty;

  int get _cycleYears {
    if (_ageAtRenewal >= 75) return 3;
    if (_ageAtRenewal >= 65) return 5;
    return 10;
  }

  DateTime? get _nextExpiry {
    if (_year == null || _month == null || _day == null) return null;
    try {
      final last = DateTime(_year!, _month!, _day!);
      return DateTime(last.year + _cycleYears, last.month, last.day);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _ageAtRenewalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    final bg = AppTheme.surface(context);
    final next = _nextExpiry;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('운전면허 갱신 만료일',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('취득(또는 마지막 갱신) 날짜'.keepWords,
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  flex: 2,
                  child: _dateBox(_yearCtrl, '2020', '년', ink, sub, line)),
              const SizedBox(width: 8),
              Expanded(child: _dateBox(_monthCtrl, '5', '월', ink, sub, line)),
              const SizedBox(width: 8),
              Expanded(child: _dateBox(_dayCtrl, '10', '일', ink, sub, line)),
            ]),
            const SizedBox(height: 16),
            Text('다음 갱신 시점의 만 나이',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _ageAtRenewalCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTheme.sans(14, ink),
              decoration: InputDecoration(
                hintText: '40',
                hintStyle: AppTheme.sans(14, sub),
                suffixText: '세',
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
                    Text('예상 다음 갱신 만료일',
                        style:
                            AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(
                        next != null
                            ? '${next.year}년 ${next.month}월 ${next.day}일'
                            : '날짜를 확인해주세요',
                        style: AppTheme.sans(18, accent,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('적용 갱신주기', '$_cycleYears년', ink, sub),
                    const SizedBox(height: 8),
                    Text('* 갱신 기간은 생일 전후 6개월(총 1년)이며, 만료일 기준 안내입니다.'.keepWords,
                        style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '연령별 갱신 주기',
              [
                '일반(2011.12.9 이후 취득): 10년',
                '65~74세: 5년 (정기 적성검사 필수)',
                '75세 이상: 3년 + 2시간 교통안전교육 의무',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '2026년 수수료',
              [
                '2종 면허 갱신: 8,000원',
                '1종 정기 적성검사: 12,500원 (신체검사료 약 6,000원 별도)',
                '면허증 재발급: 10,000원 (모바일 7,500원)',
                '국제운전면허증: 8,500원 (1년 유효)',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '미갱신 시 불이익',
              [
                '갱신기간 경과 후 1년 이내: 과태료 2만원',
                '1년 초과: 과태료 3만원 + 면허 효력 정지',
                '정지 후에도 미갱신: 면허 취소(재응시 필요)',
              ],
              line,
              sub,
              ink,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateBox(TextEditingController ctrl, String hint, String suffix,
      Color ink, Color sub, Color line) {
    return TextField(
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
        suffixStyle: AppTheme.sans(12, sub),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: ink)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      ),
      onChanged: (_) => setState(() {}),
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
