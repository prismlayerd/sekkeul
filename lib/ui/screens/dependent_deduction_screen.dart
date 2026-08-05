import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../../core/data/db_helper.dart';
import '../../core/tax_engine/employee_tax.dart';
import '../../core/tax_engine/tax_rates.dart';
import '../theme/text_wrap.dart';

/// 부양가족 공제 확인
/// 기본공제(1인 150만) + 장애인 추가공제(200만) + 추가 인적공제(경로/부녀자/한부모)
/// + 자녀세액공제 미리보기. 입력값은 프로필에 저장되어 연말정산 진단과 공유됨.
class DependentDeductionScreen extends StatefulWidget {
  const DependentDeductionScreen({super.key});

  @override
  State<DependentDeductionScreen> createState() => _DependentDeductionScreenState();
}

class _DependentDeductionScreenState extends State<DependentDeductionScreen> {

  // 기본공제 대상
  int _dependents = 0;          // 본인·배우자 제외 부양가족 수
  bool _isSpouseDependent = false;

  // 장애인
  bool _hasSelfDisability = false;
  bool _hasSpouseDisability = false;
  int _disabledDependentCount = 0;

  // 추가 인적공제
  bool _hasElderly70Plus = false;
  bool _isFemaleHead = false;
  bool _isSingleParent = false;

  // 자녀세액공제 (프로필 미저장, 로컬 미리보기)
  int _childrenCount = 0;
  int _newbornCount = 0;

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  bool _asBool(dynamic v) => v == true || v == 1;

  /// 부녀자공제 소득요건 판정용 — 내 정보의 예상 연봉.
  double _grossIncome = 0.0;

  Future<void> _loadProfile() async {
    final profile = await dbService.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _dependents = (profile['dependents'] as int?) ?? 0;
        _isSpouseDependent = _asBool(profile['is_spouse_dependent']);
        _hasSelfDisability = _asBool(profile['has_self_disability']);
        _hasSpouseDisability = _asBool(profile['has_spouse_disability']);
        _disabledDependentCount = (profile['disabled_dependent_count'] as int?) ?? 0;
        _hasElderly70Plus = _asBool(profile['has_elderly_70plus']);
        _isFemaleHead = _asBool(profile['is_female_head']);
        _grossIncome = (profile['gross_income'] as num?)?.toDouble() ?? 0.0;
        _isSingleParent = _asBool(profile['is_single_parent']);
        _loaded = true;
      });
    } else if (mounted) {
      setState(() => _loaded = true);
    }
  }

  void _reset() {
    setState(() {
      _dependents = 0;
      _isSpouseDependent = false;
      _hasSelfDisability = false;
      _hasSpouseDisability = false;
      _disabledDependentCount = 0;
      _hasElderly70Plus = false;
      _isFemaleHead = false;
      _isSingleParent = false;
      _childrenCount = 0;
      _newbornCount = 0;
    });
  }

  Future<void> _save() async {
    final profile = await dbService.getProfile() ?? {};
    profile['dependents'] = _dependents;
    profile['is_spouse_dependent'] = _isSpouseDependent;
    profile['has_self_disability'] = _hasSelfDisability;
    profile['has_spouse_disability'] = _hasSpouseDisability;
    profile['disabled_dependent_count'] = _disabledDependentCount;
    profile['has_elderly_70plus'] = _hasElderly70Plus;
    profile['is_female_head'] = _isFemaleHead;
    profile['is_single_parent'] = _isSingleParent;
    await dbService.saveProfile(profile);
  }

  String _toManwon(double won) {
    if (won <= 0) return '0원';
    final man = (won / 10000).round();
    return '${comma(man)}만원';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;

    // ── 계산 ──
    final basicCount = 1 + (_isSpouseDependent ? 1 : 0) + _dependents;
    final basicDeduction = basicCount * TaxRates.basicDeductionPerPerson;

    final totalDisabled = _disabledDependentCount +
        (_hasSelfDisability ? 1 : 0) +
        (_hasSpouseDisability ? 1 : 0);
    final disabledDeduction = totalDisabled * 2000000.0;

    final additionalDeduction = EmployeeTaxCalculator.calculateAdditionalPersonalDeduction(
      hasElderly70Plus: _hasElderly70Plus,
      isSingleFemaleHead: _isFemaleHead,
      isSingleParent: _isSingleParent,
      // 부녀자공제는 종합소득금액 3천만원 이하만 대상 (소법 §51①3).
      // 내 정보에 연봉이 없으면 요건을 충족한 것으로 본다.
      globalIncomeAmount: _grossIncome > 0
          ? _grossIncome - EmployeeTaxCalculator.calculateLaborDeduction(_grossIncome)
          : 0.0,
    );

    final totalIncomeDeduction = basicDeduction + disabledDeduction + additionalDeduction;

    final childCredit = EmployeeTaxCalculator.calculateChildTaxCredit(
      childrenCount: _childrenCount,
      newbornCount: _newbornCount,
    );

    if (!_loaded) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('부양가족 공제 확인',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 20, color: subColor),
            tooltip: '초기화',
            onPressed: _reset,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('우리 가족,\n얼마나 공제받을 수 있을까요?'.keepWords,
                style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold, height: 1.4)),
            const SizedBox(height: 8),
            Text('부양가족 1명당 기본 150만원이 소득에서 공제됩니다.'.keepWords,
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            // 결과 카드 (상단 고정)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getAccentCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.people_alt_rounded, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text('총 인적 소득공제',
                        style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(_toManwon(totalIncomeDeduction),
                      style: TextStyle(color: primary, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  _resultRow('기본공제 ($basicCount명 × 150만)', _toManwon(basicDeduction), subColor, textColor),
                  if (totalDisabled > 0) ...[
                    const SizedBox(height: 8),
                    _resultRow('장애인 추가공제 ($totalDisabled명 × 200만)', _toManwon(disabledDeduction), subColor, textColor),
                  ],
                  if (additionalDeduction > 0) ...[
                    const SizedBox(height: 8),
                    _resultRow('경로/부녀자/한부모 추가', _toManwon(additionalDeduction), subColor, textColor),
                  ],
                  if (childCredit > 0) ...[
                    const SizedBox(height: 12),
                    Divider(color: Theme.of(context).dividerColor, height: 1),
                    const SizedBox(height: 12),
                    _resultRow('자녀세액공제 (세액에서 직접 차감)', _toManwon(childCredit), subColor, primary),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 기본 공제 대상
            _sectionTitle('공제 대상 가족', textColor),
            const SizedBox(height: 12),
            _buildCard([
              _stepperRow('부양가족 수 (본인·배우자 제외)', _dependents,
                  (v) => setState(() => _dependents = v), subColor, textColor),
              _toggleRow('배우자 기본공제 대상', _isSpouseDependent,
                  (v) => setState(() => _isSpouseDependent = v), subColor, textColor),
            ]),
            const SizedBox(height: 16),

            // 장애인
            _sectionTitle('장애인 공제 (1명당 200만)', textColor),
            const SizedBox(height: 12),
            _buildCard([
              _toggleRow('본인 장애인', _hasSelfDisability,
                  (v) => setState(() => _hasSelfDisability = v), subColor, textColor),
              _toggleRow('배우자 장애인', _hasSpouseDisability,
                  (v) => setState(() => _hasSpouseDisability = v), subColor, textColor),
              _stepperRow('장애인 부양가족 수', _disabledDependentCount,
                  (v) => setState(() => _disabledDependentCount = v), subColor, textColor),
            ]),
            const SizedBox(height: 16),

            // 추가 인적공제
            _sectionTitle('추가 인적공제', textColor),
            const SizedBox(height: 12),
            _buildCard([
              _toggleRow('경로우대 (70세 이상 부양가족, +100만)', _hasElderly70Plus,
                  (v) => setState(() => _hasElderly70Plus = v), subColor, textColor),
              _toggleRow('부녀자 (여성 세대주, 소득 3천만원 이하, +50만)', _isFemaleHead,
                  (v) => setState(() => _isFemaleHead = v), subColor, textColor),
              _toggleRow('한부모 (+100만, 부녀자와 중복 시 우선)', _isSingleParent,
                  (v) => setState(() => _isSingleParent = v), subColor, textColor),
            ]),
            const SizedBox(height: 16),

            // 자녀세액공제
            _sectionTitle('자녀세액공제 (${TaxRates.childTaxCreditEligibilityLabel()})', textColor),
            const SizedBox(height: 12),
            _buildCard([
              _stepperRow('${TaxRates.childTaxCreditEligibilityLabel()} 자녀 수', _childrenCount,
                  (v) => setState(() => _childrenCount = v), subColor, textColor),
              _stepperRow('출산·입양 자녀 수', _newbornCount,
                  (v) => setState(() => _newbornCount = v), subColor, textColor),
            ]),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  await _save();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('공제 정보를 저장했어요. 연말정산 진단에 반영됩니다.'.keepWords)),
                    );
                    Navigator.pop(context, true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('저장하기',
                    style: TextStyle(color: Theme.of(context).scaffoldBackgroundColor, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const CalcDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t, Color c) =>
      Text(t, style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.bold));

  Widget _buildCard(List<Widget> children) {
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Divider(color: Theme.of(context).dividerColor, height: 1));
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: AppTheme.getCardDecoration(context, borderRadius: 16),
      child: Column(children: rows),
    );
  }

  Widget _resultRow(String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: TextStyle(color: labelColor, fontSize: 13))),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged, Color subColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: textColor, fontSize: 14))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _stepperRow(String label, int value, ValueChanged<int> onChanged, Color subColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: textColor, fontSize: 14))),
          _stepBtn(Icons.remove_rounded, value > 0 ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 36,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          _stepBtn(Icons.add_rounded, () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    final primary = Theme.of(context).primaryColor;
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: (disabled ? primary.withValues(alpha: 0.08) : primary.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: disabled ? primary.withValues(alpha: 0.3) : primary),
      ),
    );
  }
}
