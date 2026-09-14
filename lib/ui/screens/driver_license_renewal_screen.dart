import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../components/calc_widgets.dart';
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
      appBar: AppBar(
        title: Text('운전면허 갱신 만료일',
            style: AppTheme.serif(AppTheme.tsBase, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('취득(또는 마지막 갱신) 날짜'.keepWords,
                style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
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
            Text('다음 갱신 시점의 만 나이'.keepWords,
                style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _ageAtRenewalCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTheme.sans(AppTheme.tsMD, ink),
              decoration: InputDecoration(
                hintText: '40',
                hintStyle: AppTheme.sans(AppTheme.tsMD, sub),
                suffixText: '세',
                suffixStyle: AppTheme.sans(AppTheme.tsMD, sub),
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
                    Text('예상 다음 갱신 만료일'.keepWords,
                        style:
                            AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(
                        next != null
                            ? '${next.year}년 ${next.month}월 ${next.day}일'
                            : '날짜를 확인해주세요',
                        style: AppTheme.sans(AppTheme.tsLG, accent,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    calcRow('적용 갱신주기', '$_cycleYears년', ink, sub),
                    const SizedBox(height: 8),
                    Text('* 갱신 기간은 생일 전후 각각 6개월(총 1년)이며, 만료일 기준 안내입니다.'.keepWords,
                        style: AppTheme.sans(AppTheme.tsXS, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            calcInfoBox(
              '연령별 갱신 주기',
              [
                '일반(2011.12.9 이후 취득): 10년',
                '65세 이상 75세 미만: 5년',
                '75세 이상: 3년 + 2시간 교통안전교육 의무',
                '정기 적성검사는 1종 전부와 70세 이상 2종만 받는다',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            // 아래 수수료 검증(확인일 2026-09-15):
            // - 2종 갱신·1종 정기 적성검사·재발급·신체검사비: 도로교통법 제139조제1항 단서·
            //   제2항제2호 및 시행규칙 제131조제3항에 따라 금액이 법령 별표가 아니라
            //   한국도로교통공단이 경찰청장 승인을 받아 결정·공고하는 수수료(공단 공고 사항,
            //   법령 원문에는 구체 금액 없음). 한국도로교통공단 안전운전 통합민원
            //   (safedriving.or.kr 발급신청 안내) 공식 수수료 안내와 대조해 금액 일치 확인함.
            // - 국제운전면허증 9,000원(1년 유효): 도로교통법 제139조제1항제7호·제98조제2항,
            //   시행규칙 제131조제1항 별표36(수수료 금액표, 제131조제1항 관련) 원문 직접 대조로
            //   금액·유효기간 모두 일치 확인함.
            calcInfoBox(
              '2026년 수수료',
              [
                '2종 면허 갱신: 일반 10,000원 / 모바일IC 15,000원',
                '1종 정기 적성검사: 일반 16,000원 / 모바일IC 21,000원',
                '신체검사비 별도: 1종 대형·특수 8,000원 / 그 밖 7,000원',
                '면허증 재발급: 일반 10,000원 / 모바일IC 15,000원',
                '국제운전면허증: 9,000원 (1년 유효)',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            calcInfoBox(
              '미갱신 시 불이익',
              [
                '갱신 미이행: 과태료 2만원',
                '정기 적성검사 미이행: 과태료 3만원',
                '적성검사 기간 만료 다음 날부터 1년 초과: 면허 취소(재응시 필요)',
              ],
              line,
              sub,
              ink,
            ),
          ],
        ),
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
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppTheme.sans(AppTheme.tsMD, ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTheme.sans(AppTheme.tsMD, sub),
        suffixText: suffix,
        suffixStyle: AppTheme.sans(AppTheme.tsXS, sub),
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

}
