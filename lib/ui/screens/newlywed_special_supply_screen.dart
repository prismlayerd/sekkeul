import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';

/// 신혼부부 특별공급(공공분양) 자격 참고 진단.
///
/// 소득·자산은 LH청약플러스 분양가이드의 2026년 적용표를 쓴다.
/// 민영·국민주택은 기준이 달라(소득 140%/맞벌이 160%) 이 화면이 다루지 않는다.
class NewlywedSpecialSupplyScreen extends StatefulWidget {
  const NewlywedSpecialSupplyScreen({super.key});

  @override
  State<NewlywedSpecialSupplyScreen> createState() =>
      _NewlywedSpecialSupplyScreenState();
}

class _NewlywedSpecialSupplyScreenState
    extends State<NewlywedSpecialSupplyScreen> {
  final _marriageYearsCtrl = TextEditingController();
  final _childrenCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController(); // 부부합산 월소득, 만원
  final _realEstateCtrl = TextEditingController(); // 만원
  final _carCtrl = TextEditingController(); // 만원
  final _subscriptionMonthsCtrl = TextEditingController();
  bool _dualIncome = false;
  bool _noHouse = true;
  int _householdIdx = 0;

  // 도시근로자 가구당 월평균소득 100%(원) — LH청약플러스 2026년 적용표.
  // 종전 값은 2024년 고시라 7%쯤 낮았다. 분모가 낮으면 소득비율이 부풀려져
  // 자격이 되는 사람에게 "미달"이라고 답한다.
  static const _householdLabels = ['3인 이하', '4인', '5인', '6인', '7인', '8인 이상'];
  static const _avgIncomes = [
    7533763,
    8802202,
    9326985,
    9906263,
    10485541,
    11064819,
  ];

  // LH청약플러스 자산기준(2026년 적용): 부동산 215,500천원 · 자동차 45,420천원.
  // 자동차는 3,683만원(2022년 값)으로 굳어 있었다 — 설명문은 4,542만원이라
  // 적어 두고 판정만 옛 값으로 해서, 4천만원짜리 차를 잘못 떨어뜨렸다.
  static const int _realEstateLimit = 21550; // 만원
  static const int _carLimit = 4542; // 만원

  int get _marriageYears => int.tryParse(_marriageYearsCtrl.text.replaceAll(',', '')) ?? -1;
  int get _children => int.tryParse(_childrenCtrl.text.replaceAll(',', '')) ?? 0;
  double get _income =>
      double.tryParse(_incomeCtrl.text.replaceAll(',', '')) ?? 0;
  double get _realEstate =>
      double.tryParse(_realEstateCtrl.text.replaceAll(',', '')) ?? 0;
  double get _car => double.tryParse(_carCtrl.text.replaceAll(',', '')) ?? 0;
  int get _subscriptionMonths => int.tryParse(_subscriptionMonthsCtrl.text.replaceAll(',', '')) ?? 0;

  bool get _hasInput =>
      _marriageYearsCtrl.text.isNotEmpty && _incomeCtrl.text.isNotEmpty;

  double get _incomeRatio {
    final avg = _avgIncomes[_householdIdx];
    final monthlyWon = _income * 10000;
    return avg > 0 ? monthlyWon / avg * 100 : 0;
  }

  double get _priorityThreshold => _dualIncome ? 120 : 100;
  double get _generalThreshold => _dualIncome ? 140 : 130;

  bool get _marriageOk => _marriageYears >= 0 && _marriageYears <= 7;
  bool get _houseOk => _noHouse;
  bool get _assetOk => _realEstate <= _realEstateLimit && _car <= _carLimit;
  bool get _subscriptionOk => _subscriptionMonths >= 6;

  String get _resultText {
    if (!_marriageOk) return '자격 미달 — 혼인 7년 초과';
    if (!_houseOk) return '자격 미달 — 무주택 요건 미충족';
    if (!_assetOk) return '자격 미달 — 자산 기준 초과';
    if (!_subscriptionOk) return '자격 미달 — 청약통장 6개월 미만';
    if (_incomeRatio <= _priorityThreshold) {
      final rank = _children >= 1 ? '1순위' : '2순위';
      return '우선공급(70%) 대상 · $rank';
    }
    if (_incomeRatio <= _generalThreshold) {
      final rank = _children >= 1 ? '1순위' : '2순위';
      return '일반공급(20%) 대상 · $rank';
    }
    return '자격 미달 — 소득 기준 초과';
  }

  bool get _eligible => _resultText.startsWith('우선') || _resultText.startsWith('일반');

  @override
  void dispose() {
    _marriageYearsCtrl.dispose();
    _childrenCtrl.dispose();
    _incomeCtrl.dispose();
    _realEstateCtrl.dispose();
    _carCtrl.dispose();
    _subscriptionMonthsCtrl.dispose();
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
        title: Text('신혼특공 자격진단',
            style: AppTheme.serif(AppTheme.tsBase, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _numField('혼인 기간', _marriageYearsCtrl, '3', '년', ink, sub, line),
            const SizedBox(height: 16),
            _numField('미성년 자녀 수 (태아 포함)', _childrenCtrl, '1', '명', ink, sub, line),
            const SizedBox(height: 16),
            Text('무주택 여부',
                style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _segButton('무주택', true, _noHouse,
                      (v) => setState(() => _noHouse = v), ink, line, accent)),
              const SizedBox(width: 8),
              Expanded(
                  child: _segButton('주택 보유', false, _noHouse,
                      (v) => setState(() => _noHouse = v), ink, line, accent)),
            ]),
            const SizedBox(height: 16),
            Text('맞벌이 여부',
                style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _segButton('외벌이', false, _dualIncome,
                      (v) => setState(() => _dualIncome = v), ink, line, accent)),
              const SizedBox(width: 8),
              Expanded(
                  child: _segButton('맞벌이', true, _dualIncome,
                      (v) => setState(() => _dualIncome = v), ink, line, accent)),
            ]),
            const SizedBox(height: 16),
            Text('가구원수',
                style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(4)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _householdIdx,
                  isExpanded: true,
                  style: AppTheme.sans(AppTheme.tsMD, ink),
                  dropdownColor: AppTheme.backgroundColor(context),
                  items: [
                    for (int i = 0; i < _householdLabels.length; i++)
                      DropdownMenuItem(
                          value: i,
                          child: Text(_householdLabels[i],
                              style: AppTheme.sans(AppTheme.tsMD, ink))),
                  ],
                  onChanged: (v) => setState(() => _householdIdx = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _numField('부부합산 월소득', _incomeCtrl, '650', '만원', ink, sub, line),
            const SizedBox(height: 16),
            _numField('보유 부동산가액', _realEstateCtrl, '0', '만원', ink, sub, line),
            const SizedBox(height: 16),
            _numField('보유 자동차가액', _carCtrl, '0', '만원', ink, sub, line),
            const SizedBox(height: 16),
            _numField('청약통장 가입 기간', _subscriptionMonthsCtrl, '24', '개월', ink, sub,
                line),
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
                        style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(_resultText,
                        style: AppTheme.sans(AppTheme.tsBase, _eligible ? accent : ink,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('소득 수준',
                        '도시근로자 월평균 대비 ${_incomeRatio.toStringAsFixed(0)}%',
                        ink, sub),
                    const SizedBox(height: 8),
                    _row('우선공급 기준', '${_priorityThreshold.toStringAsFixed(0)}% 이하',
                        ink, sub),
                    const SizedBox(height: 8),
                    _row('일반공급 기준', '${_generalThreshold.toStringAsFixed(0)}% 이하',
                        ink, sub),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox(
              '대상 요건',
              [
                '혼인 7년 이내 또는 6세 이하 자녀 (예비신혼부부·한부모가족 포함)',
                '세대구성원 모두 무주택, 청약통장 6개월 경과 + 6회 이상 납입',
                '자산: 부동산 2억 1,550만원 이하 · 자동차 4,542만원 이하 (2026년 적용)',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '순위·공급 비중',
              [
                '1순위: 혼인기간 중 출산(임신·입양 포함)한 자녀가 있거나 한부모가족',
                '2순위: 그 밖 — 1순위에서 남은 물량을 받는다',
                '공공분양은 건설량의 10% 범위 — 우선 70% · 일반 20% · 추첨 10%',
                '민영 15%·국민주택 20% 범위는 소득 140%(맞벌이 160%)로 기준이 다르다',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '신청 방법',
              [
                '입주자모집공고 확인(청약홈·LH·SH) → 자격요건 확인 → 인증서 로그인 신청',
                '당첨자 발표 후 혼인관계증명서·소득증명원·등본·자산증빙 서류 제출',
                '부적격 판정 시 당첨 취소 + 1년간 청약 제한',
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: selected ? accent : line),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AppTheme.sans(AppTheme.tsSM, selected ? accent : ink,
                weight: FontWeight.w600)),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl, String hint,
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
