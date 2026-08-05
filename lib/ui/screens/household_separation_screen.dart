import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class HouseholdSeparationScreen extends StatefulWidget {
  const HouseholdSeparationScreen({super.key});

  @override
  State<HouseholdSeparationScreen> createState() =>
      _HouseholdSeparationScreenState();
}

class _HouseholdSeparationScreenState
    extends State<HouseholdSeparationScreen> {
  final _ageCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController(); // 만원
  int _maritalIdx = 0; // 0=미혼, 1=기혼(혼인신고), 2=이혼·사별+자녀부양
  bool _hasHousing = true;

  /// 기준중위소득 40%(1인). 2026년 1인 중위소득 2,564,238원 × 40%.
  /// 매년 보건복지부 고시로 바뀐다 — 2026년은 6.51% 올랐다.
  static const int _incomeThresholdWon = 1025695;

  int get _age => int.tryParse(_ageCtrl.text.replaceAll(',', '')) ?? -1;
  double get _income =>
      double.tryParse(_incomeCtrl.text.replaceAll(',', '')) ?? 0;
  bool get _hasInput => _ageCtrl.text.isNotEmpty;

  bool get _byAge => _age >= 30;
  bool get _byMarriage => _maritalIdx == 1;
  bool get _byDivorceChild => _maritalIdx == 2;
  bool get _byIncome => _income * 10000 >= _incomeThresholdWon;

  String? get _basis {
    if (_byMarriage) return '혼인신고 완료';
    if (_byDivorceChild) return '이혼·사별 후 자녀 부양';
    if (_byAge) return '만 30세 이상';
    if (_byIncome) return '소득 기준중위소득 40% 이상';
    return null;
  }

  bool get _eligible => _basis != null && _hasHousing;

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
        title: Text('세대분리 가능여부 진단',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('만 나이',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTheme.sans(14, ink),
              decoration: InputDecoration(
                hintText: '28',
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
            const SizedBox(height: 16),
            Text('혼인 상태',
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
                  value: _maritalIdx,
                  isExpanded: true,
                  style: AppTheme.sans(14, ink),
                  dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('미혼')),
                    DropdownMenuItem(value: 1, child: Text('기혼 (혼인신고 완료)')),
                    DropdownMenuItem(value: 2, child: Text('이혼·사별 + 자녀 부양')),
                  ],
                  onChanged: (v) => setState(() => _maritalIdx = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('월 평균 소득',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _incomeCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: const [ThousandsFormatter()],
              style: AppTheme.sans(14, ink),
              decoration: InputDecoration(
                hintText: '100',
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
            const SizedBox(height: 16),
            Text('별도 주거 확보 여부',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _segButton('확보함 (자취·전월세·기숙사)', true, _hasHousing,
                      (v) => setState(() => _hasHousing = v), ink, line, accent)),
              const SizedBox(width: 8),
              Expanded(
                  child: _segButton('아니오', false, _hasHousing,
                      (v) => setState(() => _hasHousing = v), ink, line, accent)),
            ]),
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
                    Text('진단 결과',
                        style: AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(_eligible ? '세대분리 가능 (요건 충족)' : '세대분리 재검토 필요',
                        style: AppTheme.sans(15, _eligible ? accent : ink,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    if (_basis != null)
                      Text('충족 요건: $_basis',
                          style: AppTheme.sans(13, sub))
                    else
                      Text('연령·혼인·소득 요건 중 하나도 충족하지 못했습니다.'.keepWords,
                          style: AppTheme.sans(13, sub)),
                    const SizedBox(height: 8),
                    if (!_hasHousing)
                      Text('* 실제 별도 거주지가 없으면 위장전입으로 간주되어 분리가 불가합니다.'.keepWords,
                          style: AppTheme.sans(11, sub)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '분리 요건 (하나 이상 충족)',
              [
                '만 30세 이상',
                '혼인신고 완료',
                '기준중위소득 40% 이상 (1인 월 약 95만원)',
                '배우자 사망·이혼 후 자녀 부양',
                '+ 모든 경우 공통: 실제 별도 주거지 필수(자취·전월세·기숙사)',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '세대분리의 영향',
              [
                '청약: 부모 명의 주택이 있어도 무주택 세대주로 인정 → 특별공급·1순위 자격',
                '건강보험료: 지역가입자 분리 시 재산·소득 분리 산정으로 절감 가능',
                '양도소득세·종합부동산세: 1세대 1주택 판정·세대 합산에서 분리 효과',
                '취득세: 다주택 중과 판단 시 세대 기준 적용, 회피 목적 분리는 엄격 심사',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '신청 절차',
              [
                '1. 본인 명의 주거지 확보 + 계약서 사본',
                '2. 전입신고 (정부24 또는 주민센터)',
                '3. 세대주 변경·분리 신청 (주민센터·정부24)',
                '4. 30세 미만은 소득 증빙 서류 추가 제출',
                '5. 주민등록표 등본 재발급으로 분리 확인',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '유의사항',
              [
                '실거주 없는 위장전입: 3년 이하 징역 또는 3천만원 이하 벌금 (주민등록법 §37)',
                '청약 부정청약: 3년 이하 징역·3천만원 이하 벌금 + 10년 청약 제한',
                '양도세·취득세 회피 목적 분리는 국세청 실지조사로 부인될 수 있습니다',
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

  Widget _segButton(String label, bool value, bool groupValue,
      ValueChanged<bool> onChanged, Color ink, Color line, Color accent) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
