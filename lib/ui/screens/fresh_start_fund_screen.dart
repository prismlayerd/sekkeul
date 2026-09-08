import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class FreshStartFundScreen extends StatefulWidget {
  const FreshStartFundScreen({super.key});

  @override
  State<FreshStartFundScreen> createState() => _FreshStartFundScreenState();
}

class _FreshStartFundScreenState extends State<FreshStartFundScreen> {
  final _debtCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController(text: '10');
  final _cutCtrl = TextEditingController(text: '0');

  /// 부실차주(90일 이상 연체)인지. 부실우려차주는 원금조정이 아예 없다 —
  /// 종전에는 "부실우려 30% 감면"이라고 적어 두어, 캠코가 주지 않는 돈을
  /// 계산해서 보여 주고 있었다.
  bool _isDefault = true;

  /// 원금조정 폭은 보유재산과 상환능력을 봐서 정해진다(0~80%).
  /// 저소득자·사회취약계층은 신용대출 순부채의 90%까지 간다.
  int get _maxCut => 90;

  double get _debt => double.tryParse(_debtCtrl.text.replaceAll(',', '')) ?? 0;
  int get _years => int.tryParse(_yearsCtrl.text.replaceAll(',', '')) ?? 0;
  double get _rate => _isDefault
      ? (double.tryParse(_cutCtrl.text) ?? 0).clamp(0, _maxCut) / 100
      : 0;

  double get _reduction => _debt * _rate;
  double get _afterDebt => _debt - _reduction;
  double get _monthlyPayment => _years > 0 ? _afterDebt / (_years * 12) : 0;

  bool get _hasInput => _debt > 0 && _years > 0;


  @override
  void dispose() {
    _debtCtrl.dispose();
    _yearsCtrl.dispose();
    _cutCtrl.dispose();
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
        title: Text('새출발기금 채무조정',
            style: AppTheme.serif(AppTheme.tsBase, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('차주 분류'.keepWords,
                style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(4)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<bool>(
                  value: _isDefault,
                  isExpanded: true,
                  style: AppTheme.sans(AppTheme.tsMD, ink),
                  dropdownColor: AppTheme.backgroundColor(context),
                  items: const [
                    DropdownMenuItem(
                        value: true, child: Text('부실차주 (90일 이상 연체)')),
                    DropdownMenuItem(
                        value: false, child: Text('부실우려차주 (원금조정 없음)')),
                  ],
                  onChanged: (v) => setState(() => _isDefault = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isDefault) ...[
              Text('원금 감면율 (심사로 정해집니다)'.keepWords,
                  style:
                      AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _cutCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTheme.sans(AppTheme.tsMD, ink),
                decoration: InputDecoration(
                  suffixText: '% (보유재산 반영 0~80, 취약계층 최대 90)',
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
            ],
            Text('총 사업자 채무',
                style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _debtCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: const [ThousandsFormatter()],
              style: AppTheme.sans(AppTheme.tsMD, ink),
              decoration: InputDecoration(
                hintText: '50,000,000',
                hintStyle: AppTheme.sans(AppTheme.tsMD, sub),
                suffixText: '원',
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
              onChanged: (v) {
                final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                final formatted =
                    digits.isEmpty ? '' : comma(int.parse(digits));
                _debtCtrl.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Text('분할 상환 기간',
                style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _yearsCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTheme.sans(AppTheme.tsMD, ink),
              decoration: InputDecoration(
                suffixText: '년 (무담보 1~10년 · 부동산담보 1~20년)',
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
                    Text('예상 월 분할상환액',
                        style:
                            AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(won(_monthlyPayment),
                        style: AppTheme.sans(AppTheme.tsXL, accent,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('원금 감면액', won(_reduction), ink, sub),
                    const SizedBox(height: 8),
                    _row('감면 후 원금', won(_afterDebt), ink, sub),
                    const SizedBox(height: 12),
                    Text(
                        '* 무이자 분할 가정 단순 추정치. 부실우려차주는 원금이 아니라 금리가'
                                ' 조정됩니다(연체 30일 이후 3.9~4.7%).'
                            .keepWords,
                        style: AppTheme.sans(AppTheme.tsXS, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '대상 요건',
              [
                '2020년 4월~2025년 6월 중 사업을 영위한 개인사업자 또는 법인 소상공인',
                '프리랜서·특수형태근로종사자도 됩니다. 폐업 법인은 안 됩니다',
                '부동산 임대·매매업, 금융업, 법무·회계·세무·의료 등 전문직종은 제외',
                '부실차주: 1개 이상 대출에서 3개월 이상 장기연체',
                '부실우려차주: 폐업·6개월 이상 휴업, 만기연장이 어려운 차주, 세금 체납 등',
                '조정한도: 총 채무액 15억원 (담보 10억 + 무담보 5억)',
                '신청은 평생 1회만 가능합니다',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '차주 분류에 따라 창구가 다릅니다',
              [
                '부실차주 — 새출발기금.kr 또는 캠코. 전체 채무를 매입해 조정하며 채무를 골라낼 수 없습니다',
                '부실우려차주 — 신용회복위원회. 조정할 대출을 직접 고르고, 원금이 아니라 금리를 조정합니다',
                '취업·재창업 교육을 이수한 부실 폐업자는 원금을 최대 10% 더 감면받습니다',
                '신청 다음 날부터 추심과 강제집행이 멈춥니다',
                '약정하면 공공정보로 등록되고, 1년간 성실상환하면 해제됩니다',
                '문의: 새출발기금 콜센터 1660-1378',
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
