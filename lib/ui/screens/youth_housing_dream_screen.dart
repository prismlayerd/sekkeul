import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class YouthHousingDreamScreen extends StatefulWidget {
  const YouthHousingDreamScreen({super.key});

  @override
  State<YouthHousingDreamScreen> createState() =>
      _YouthHousingDreamScreenState();
}

class _YouthHousingDreamScreenState extends State<YouthHousingDreamScreen> {
  final _monthlyCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController();

  double get _monthly => saneInput(
      double.tryParse(_monthlyCtrl.text.replaceAll(',', '')) ?? 0, InputMax.money);
  double get _months => saneInput(
      double.tryParse(_monthsCtrl.text.replaceAll(',', '')) ?? 0, InputMax.months);

  /// 기금 상품안내(FP07010301) 이율표의 '2년 이상~10년 이내' 칸.
  /// 같은 표에서 주택청약종합저축은 3.1%다 — 2.8%는 1~2년 구간 값이라
  /// 2년을 넘겨 비교하는 이 화면에서는 차이를 부풀린다.
  static const _dreamRate = 0.045;
  static const _normalRate = 0.031;

  /// 조특법 §87② — 주택청약종합저축 납입액 연 300만원 한도의 40%.
  /// 240만원은 2023년까지의 한도였다.
  static const _deductionCap = 3000000.0;

  double _interest(double rate) =>
      _monthly * _months * rate / 2 / 12 * _months;

  double get _dreamTotal => _monthly * _months + _interest(_dreamRate);
  double get _normalTotal => _monthly * _months + _interest(_normalRate);

  double get _diff => _dreamTotal - _normalTotal;

  double get _annualDeposit => _monthly * 12;
  double get _deductionBase => _annualDeposit.clamp(0, _deductionCap) * 0.40;
  double get _taxRefund => _deductionBase * 0.165;

  bool get _hasInput => _monthly > 0 && _months > 0;

  String _manwon(double v) {
    if (v <= 0) return '-';
    return '약 ${comma((v / 10000).round())}만원';
  }

  String won(double v) {
    if (v <= 0) return '-';
    return '약 ${comma(v.round())}원';
  }

  @override
  void dispose() {
    _monthlyCtrl.dispose();
    _monthsCtrl.dispose();
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
      appBar: AppBar(
        title: Text('청년 주택드림 청약통장'.keepWords,
            style: AppTheme.serif(AppTheme.tsBase, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _inputField('월 납입액', _monthlyCtrl, '500,000', '원', ink, sub, line),
            const SizedBox(height: 16),
            _inputField('납입 기간', _monthsCtrl, '24', '개월', ink, sub, line),
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
                    Text('이자 비교 (단리 추정)'.keepWords,
                        style:
                            AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _row('드림 통장 (연 ${_dreamRate * 100}%)',
                        _manwon(_dreamTotal), ink, sub),
                    const SizedBox(height: 8),
                    _row('종합저축 (연 ${(_normalRate * 100).toStringAsFixed(1)}%)',
                        _manwon(_normalTotal), ink, sub),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('드림 통장 추가 이익',
                            style: AppTheme.sans(AppTheme.tsMD, ink,
                                weight: FontWeight.w700)),
                        Text(_manwon(_diff),
                            style: AppTheme.sans(AppTheme.tsBase, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('연간 납입액', _manwon(_annualDeposit), ink, sub),
                    const SizedBox(height: 8),
                    _row('소득공제 금액 (40%)', _manwon(_deductionBase), ink, sub),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('연 세금 환급 추정 (16.5%)'.keepWords,
                            style: AppTheme.sans(AppTheme.tsSM, ink,
                                weight: FontWeight.w700)),
                        Text(won(_taxRefund),
                            style: AppTheme.sans(AppTheme.tsSM, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        '* 소득공제 한도 연 300만원. 세율 16.5%(소득세 15%+지방세 1.5%) 기준.'.keepWords,
                        style: AppTheme.sans(AppTheme.tsXS, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '자격 및 혜택',
              [
                '만 19~34세 무주택자 (병역 이행기간 최대 6년 인정)',
                '연소득 5,000만원 이하',
                '2년 이상~10년 이내 연 4.5%, 그 전에는 2.3~2.8%',
                '월 2만~50만원 자유납입',
                '청약 1순위: 수도권 1년·그 밖 6개월·규제지역 2년',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '소득공제 & 대출 연계',
              [
                '연 납입액 300만원 한도의 40% 소득공제 (총급여 7천만원 이하 무주택)',
                '300만원을 채우면 120만원 공제 — 연 약 198,000원 환급',
                '당첨 후 청년 주택드림 디딤돌: 연 2.4~4.15%, 미혼 3억·신혼 4억원',
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
        Text(label, style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
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
          style: AppTheme.sans(AppTheme.tsMD, ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTheme.sans(AppTheme.tsMD, sub),
            suffixText: suffix,
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
      ],
    );
  }

  Widget _row(String label, String value, Color ink, Color sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: AppTheme.sans(AppTheme.tsSM, sub))),
        Text(value, style: AppTheme.sans(AppTheme.tsSM, ink, weight: FontWeight.w600)),
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
          Text(title, style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: AppTheme.sans(AppTheme.tsSM, sub)),
                Expanded(
                    child: Text(item,
                        style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5))),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
