import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/occupation_data.dart';
import '../../core/tax_engine/insurance_engine.dart';
import '../../core/notifications/reminder_scheduler.dart';
import '../../core/tax_engine/employee_tax.dart';
import '../../core/tax_engine/tax_rates.dart';
import 'occupation_search_screen.dart';
import '../components/amount_field.dart';
import 'profile_input_screen.dart';

/// 내 정보 — 하단 탭 허브. 정확한 절세 계산의 출발점이라 가장 앞에 둔다.
/// 프로필 완성도 + 핵심 입력값 요약 + 작성/수정 진입.
/// 설정(알림·다크모드·백업 등)은 홈 우상단 톱니(SettingsScreen)에서 관리.
class MyInfoScreen extends StatefulWidget {
  final String userType;

  /// 프로필이 저장되면 홈 대시보드를 다시 읽도록 알린다.
  final VoidCallback onProfileChanged;

  const MyInfoScreen({
    super.key,
    required this.userType,
    required this.onProfileChanged,
  });

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  final _fmt = NumberFormat('#,###');

  Map<String, dynamic>? _profile;
  bool _loading = true;

  // ── 항목별 인라인 수정 — 팝업 없이 항목을 펼쳐 그 자리에서 편집한다 ──
  String? _editingKey;
  final TextEditingController _grossEditCtrl = TextEditingController();
  final TextEditingController _ageEditCtrl = TextEditingController();
  int _dependentsEditValue = 0;
  String _residenceEditValue = '전세';
  int _payDayEditValue = 0;
  int _childrenTotalEditValue = 0;
  int _children8PlusEditValue = 0;

  /// 자녀등 총 수 — 카드공제 기본한도 상향(조특법 §126의2⑩, 2025 개정)에 쓰인다.
  int get _childrenTotal => (_profile?['children_count_total'] as int?) ?? 0;

  /// 8세 이상 자녀 수 — 자녀세액공제(소법 §59의2)에 쓰인다.
  int get _children8Plus => (_profile?['children_count_8plus'] as int?) ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _grossEditCtrl.dispose();
    _ageEditCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await dbService.getProfile();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  /// 프리랜서는 예상 연봉·나이·급여일이 세금 계산에 안 쓰인다 —
  /// 소득은 가계부 실적으로 잡고, 청년 감면·급여일 알림은 근로자 개념이라서다.
  bool get _isFreelancer => widget.userType == '프리랜서';

  // ── 프로필 완성도 ───────────────────────────────────────────────
  /// 절세 진단에 직접 쓰이는 핵심 입력값들이 채워졌는지로 완성도를 읽는다.
  /// 프리랜서는 관련 없는 항목(예상 연봉·나이·급여일)을 완성도에서 뺀다.
  List<({String label, bool filled})> get _checklist {
    final p = _profile ?? const {};
    double d(String k) => (p[k] as num?)?.toDouble() ?? 0.0;
    int i(String k) => (p[k] as int?) ?? 0;
    if (_isFreelancer) {
      return [
        (label: '부양가족', filled: p.containsKey('dependents')),
        // 자녀세액공제는 종합소득자 전원 대상이라 프리랜서도 채워야 한다.
        (label: '자녀', filled: p.containsKey('children_count_total')),
        (label: '거주 형태', filled: p.containsKey('is_monthly_rent')),
      ];
    }
    return [
      (label: '예상 연봉', filled: d('gross_income') > 0),
      (label: '나이', filled: i('age') > 0),
      (label: '부양가족', filled: p.containsKey('dependents')),
      // 자녀 수는 카드공제 한도(자녀 1명당 +50만)와 자녀세액공제 양쪽에 쓰인다.
      (label: '자녀', filled: p.containsKey('children_count_total')),
      (label: '거주 형태', filled: p.containsKey('is_monthly_rent')),
      (label: '급여일', filled: i('pay_day') > 0),
    ];
  }

  int get _filledCount => _checklist.where((e) => e.filled).length;
  double get _completeness => _checklist.isEmpty ? 0 : _filledCount / _checklist.length;

  Future<void> _openProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileInputScreen(userType: widget.userType)),
    );
    if (result == true) {
      await _load();
      widget.onProfileChanged();
    }
  }

  /// 항목 행을 펼치거나 접는다. 펼칠 때 편집값을 현재 프로필로 초기화.
  void _toggleEdit(String key) {
    final p = _profile ?? const {};
    setState(() {
      if (_editingKey == key) {
        _editingKey = null;
        return;
      }
      _editingKey = key;
      switch (key) {
        case 'gross_income':
          final v = (p['gross_income'] as num?)?.toDouble() ?? 0.0;
          _grossEditCtrl.text = v > 0 ? _fmt.format(v.toInt()) : '';
        case 'age':
          final v = (p['age'] as int?) ?? 0;
          _ageEditCtrl.text = v > 0 ? '$v' : '';
        case 'dependents':
          _dependentsEditValue = (p['dependents'] as int?) ?? 0;
        case 'residence':
          _residenceEditValue = p['owns_house'] == true
              ? '자가'
              : (p['is_monthly_rent'] == true ? '월세' : '전세');
        case 'pay_day':
          _payDayEditValue = (p['pay_day'] as int?) ?? 0;
        case 'children':
          _childrenTotalEditValue = (p['children_count_total'] as int?) ?? 0;
          _children8PlusEditValue = (p['children_count_8plus'] as int?) ?? 0;
      }
    });
  }

  /// 예상 연봉은 홈 화면이 읽는 유형별 독립 저장(profile_type_values)에도 함께 쓴다.
  Future<void> _saveGrossIncomeInline() async {
    final v = double.tryParse(_grossEditCtrl.text.replaceAll(',', '')) ?? 0.0;
    await _updateProfileFields({'gross_income': v});
    await dbService.setProfileTypeValues(widget.userType, grossIncome: v);
    if (mounted) setState(() => _editingKey = null);
  }

  Future<void> _saveChildrenInline() async {
    // 8세 이상이 총 자녀 수를 넘을 수 없다 — 넘기면 총 수에 맞춰 깎는다.
    final eight = _children8PlusEditValue > _childrenTotalEditValue
        ? _childrenTotalEditValue
        : _children8PlusEditValue;
    await _updateProfileFields({
      'children_count_total': _childrenTotalEditValue,
      'children_count_8plus': eight,
    });
    if (mounted) setState(() => _editingKey = null);
  }

  Future<void> _saveAgeInline() async {
    final v = int.tryParse(_ageEditCtrl.text.trim()) ?? 0;
    await _updateProfileFields({'age': v});
    if (mounted) setState(() => _editingKey = null);
  }

  Future<void> _saveDependentsInline() async {
    final updates = <String, dynamic>{'dependents': _dependentsEditValue};
    final disabled = (_profile?['disabled_dependent_count'] as int?) ?? 0;
    if (disabled > _dependentsEditValue) updates['disabled_dependent_count'] = _dependentsEditValue;
    await _updateProfileFields(updates);
    if (mounted) setState(() => _editingKey = null);
  }

  Future<void> _saveResidenceInline() async {
    await _updateProfileFields({
      'is_monthly_rent': _residenceEditValue == '월세',
      'owns_house': _residenceEditValue == '자가',
    });
    if (mounted) setState(() => _editingKey = null);
  }

  Future<void> _savePayDayInline() async {
    await _savePayDay(_payDayEditValue);
    if (mounted) setState(() => _editingKey = null);
  }

  Future<void> _savePayDay(int day) async {
    final updated = Map<String, dynamic>.from(_profile ?? {});
    updated['pay_day'] = day;
    await dbService.saveProfile(updated);
    if (!mounted) return;
    setState(() => _profile = updated);
    widget.onProfileChanged();
    if (!kIsWeb) {
      await ReminderScheduler.scheduleAll(payDay: day, userType: widget.userType);
    }
  }

  // ── 프리랜서·N잡러 전용: 업종코드·재산액·4대보험 가입여부 ──────────
  // 유형(직장인/N잡러/프리랜서) 전환과 무관하게 단일 값으로 저장한다 —
  // 실제로 어떤 일을 하는지는 앱이 그 사람을 어떻게 부르는지와 무관한 사실이라서다.
  bool get _isBusinessUser => widget.userType == '프리랜서' || widget.userType == 'N잡러';

  String? get _occupationCode => _profile?['occupation_code'] as String?;
  OccupationInfo? get _occupationInfo => OccupationData.occupations[_occupationCode];

  Future<void> _updateProfileFields(Map<String, dynamic> changes) async {
    final updated = Map<String, dynamic>.from(_profile ?? {});
    updated.addAll(changes);
    await dbService.saveProfile(updated);
    if (!mounted) return;
    setState(() => _profile = updated);
    widget.onProfileChanged();
  }

  Future<void> _pickOccupation() async {
    final result = await OccupationSearchScreen.show(context);
    if (result == null) return;
    final changes = <String, dynamic>{'occupation_code': result.code};
    // 특고(노무제공자) 매핑 업종이 아니면 고용·산재보험은 대상이 아니라 자동으로 끈다.
    if (!specialWorkerIndustrialRates.containsKey(result.code)) {
      changes['employment_enrolled'] = false;
      changes['industrial_accident_enrolled'] = false;
    }
    await _updateProfileFields(changes);
  }

  Future<void> _openPropertyValueDialog() async {
    final current = (_profile?['property_value'] as num?)?.toDouble() ?? 0.0;
    final picked = await showDialog<double>(
      context: context,
      builder: (ctx) => _AmountDialog(
        title: '재산액',
        subtitle: '전세보증금 등 재산가액을 입력해주세요',
        current: current,
      ),
    );
    if (picked == null) return;
    await _updateProfileFields({'property_value': picked});
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                children: [
                  Text('내 정보', style: AppTheme.serif(28, ink, spacing: -0.5)),
                  const SizedBox(height: 10),
                  Text('정확한 절세 계산은 여기서 시작해요. 입력할수록 진단과 신고 준비가 정밀해져요.',
                      style: AppTheme.sans(14, sub, height: 1.55)),
                  const SizedBox(height: 24),

                  _profileBlock(ink, sub),
                ],
              ),
      ),
    );
  }

  /// 프로필 완성도 블록 — 도면 시트 메타포(측정 스케일 + 항목 목록).
  Widget _profileBlock(Color ink, Color sub) {
    final accent = AppTheme.accentColor(context);
    final done = _filledCount == _checklist.length;
    final pct = (_completeness * 100).round();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line(context), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(widget.userType, style: AppTheme.serif(22, ink, spacing: -0.5)),
              ),
              Text('$pct%',
                  style: AppTheme.serif(28, done ? AppTheme.colorSuccess : accent, spacing: -1, height: 1.0)),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _completeness,
            minHeight: 3,
            backgroundColor: AppTheme.line(context),
            valueColor: AlwaysStoppedAnimation<Color>(done ? AppTheme.colorSuccess : accent),
          ),
          const SizedBox(height: 4),
          AppTheme.hairline(context),
          _infoRows(ink, sub, accent),
          if (_isBusinessUser) ...[
            AppTheme.hairline(context),
            _professionSection(ink, sub, accent),
          ],
          AppTheme.hairline(context),
          // 위 인라인 항목은 대표 5종뿐 — 나머지 세부 공제 질문 전체로 가는 입구.
          GestureDetector(
            onTap: _openProfile,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 18, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('더 많은 공제 항목 입력하기',
                        style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
                    const SizedBox(height: 2),
                    Text(
                      _isFreelancer
                          ? '혼인·장애·경로우대 등 세부 공제를 확인해요'
                          : '군 감면·혼인·장애·경로우대 등 세부 공제를 확인해요',
                      style: AppTheme.sans(12, sub),
                    ),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.inkTertiary(context)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// 핵심 입력값 5종 — 세로로 나열, 탭하면 그 자리에서 펼쳐져 편집된다(팝업 없음).
  Widget _infoRows(Color ink, Color sub, Color accent) {
    final p = _profile ?? const {};
    final gross = (p['gross_income'] as num?)?.toDouble() ?? 0.0;
    final age = (p['age'] as int?) ?? 0;
    final dependents = p['dependents'] as int?;
    final hasResidence = p.containsKey('is_monthly_rent');
    // 전세·반전세는 저장상 구분되지 않아(둘 다 is_monthly_rent=false, owns_house=false) '전세'로 표시.
    final residence = p['owns_house'] == true ? '자가' : (p['is_monthly_rent'] == true ? '월세' : '전세');
    final payDay = (p['pay_day'] as int?) ?? 0;
    // 항목엔 세전 연봉을 적었으니, 바로 아래에 4대보험·소득세 반영한 세후 추정치를 덧붙인다.
    double netAnnual = 0.0;
    if (gross > 0) {
      final insurance = EmployeeTaxCalculator.calculateMonthlyInsurance(gross / 12);
      final monthlyTax = EmployeeTaxCalculator.estimateMonthlyIncomeTax(
        grossAnnual: gross,
        dependentsIncludingSelf: 1 + (dependents ?? 0),
      );
      netAnnual = gross - (insurance.total + monthlyTax) * 12;
    }

    // 프리랜서는 예상 연봉·나이·급여일이 세금 계산에 안 쓰여 노출하지 않는다.
    final rows = <Widget>[
      if (!_isFreelancer)
        _infoRow(
          icon: Icons.payments_outlined,
          label: '예상 연봉',
          value: gross > 0 ? '${_fmt.format(gross.toInt())}원 (세전)' : null,
          valueExtra: gross > 0 ? '세후 약 ${_fmt.format(netAnnual.toInt())}원' : null,
          placeholder: '설정되지 않았어요 — 카드공제·환급 계산 기준이 돼요',
          isSet: gross > 0,
          editKey: 'gross_income',
          ink: ink,
          sub: sub,
          accent: accent,
          editor: _grossIncomeEditor(),
        ),
      if (!_isFreelancer)
        _infoRow(
          icon: Icons.cake_outlined,
          label: '나이',
          value: age > 0 ? '$age세' : null,
          placeholder: '설정되지 않았어요 — 청년 감면 확인에 필요해요',
          isSet: age > 0,
          editKey: 'age',
          ink: ink,
          sub: sub,
          accent: accent,
          editor: _ageEditor(sub, accent),
        ),
      _infoRow(
        icon: Icons.groups_outlined,
        label: '부양가족',
        value: dependents != null ? '$dependents명' : null,
        placeholder: '설정되지 않았어요 — 1명당 150만 원 공제돼요',
        isSet: dependents != null,
        editKey: 'dependents',
        ink: ink,
        sub: sub,
        accent: accent,
        editor: _dependentsEditor(ink),
      ),
      // 자녀는 부양가족과 별도로 받는다 — 카드공제 한도가 자녀 수에만 반응하고
      // (조특법 §126의2⑩), 자녀세액공제는 그중 8세 이상만 대상이라 수가 따로 필요하다.
      // 카드공제는 근로소득자 전용이라 프리랜서에겐 자녀세액공제(소법 §59의2)만 걸린다.
      _infoRow(
        icon: Icons.child_care_outlined,
        label: '자녀',
        value: _profile?.containsKey('children_count_total') == true
            ? '$_childrenTotal명${_children8Plus > 0 ? ' (8세 이상 $_children8Plus명)' : ''}'
            : null,
        valueExtra: _isFreelancer
            ? (_children8Plus > 0
                ? '자녀세액공제 ${_fmt.format(TaxRates.calculateChildTaxCredit(_children8Plus).toInt())}원'
                : null)
            : (_childrenTotal > 0
                ? '카드공제 한도 +${_fmt.format((_childrenTotal > 2 ? 2 : _childrenTotal) * 500000)}원'
                : null),
        placeholder: _isFreelancer
            ? '설정되지 않았어요 — 8세 이상 자녀는 세금에서 바로 빠져요'
            : '설정되지 않았어요 — 카드공제 한도가 올라가요',
        isSet: _profile?.containsKey('children_count_total') == true,
        editKey: 'children',
        ink: ink,
        sub: sub,
        accent: accent,
        editor: _childrenEditor(ink, sub),
      ),
      _infoRow(
        icon: Icons.home_outlined,
        label: '거주 형태',
        value: hasResidence ? residence : null,
        placeholder: '설정되지 않았어요 — 월세·전세 공제 기준이 달라요',
        isSet: hasResidence,
        editKey: 'residence',
        ink: ink,
        sub: sub,
        accent: accent,
        editor: _residenceEditor(ink),
      ),
      if (!_isFreelancer)
        _infoRow(
          icon: Icons.calendar_today_outlined,
          label: '급여일',
          value: payDay > 0 ? '매월 $payDay일' : null,
          placeholder: '설정되지 않았어요 — 급여일 알림에 쓰여요',
          isSet: payDay > 0,
          editKey: 'pay_day',
          ink: ink,
          sub: sub,
          accent: accent,
          editor: _payDayEditor(ink, accent),
        ),
    ];

    // 행 사이에만 헤어라인을 끼운다.
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(AppTheme.hairline(context));
      children.add(rows[i]);
    }
    return Column(children: children);
  }

  /// 행 하나 — 라벨·값·펼침 화살표. 탭하면 [editor]가 바로 아래에 펼쳐진다.
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String? value,
    String? valueExtra,
    required String placeholder,
    required bool isSet,
    required String editKey,
    required Color ink,
    required Color sub,
    required Color accent,
    required Widget editor,
  }) {
    final expanded = _editingKey == editKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _toggleEdit(editKey),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [
              Icon(icon, size: 18, color: isSet ? sub : accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(value ?? placeholder, style: AppTheme.sans(12, isSet ? sub : accent)),
                  if (valueExtra != null) ...[
                    const SizedBox(height: 1),
                    Text(valueExtra, style: AppTheme.sans(12, sub)),
                  ],
                ]),
              ),
              Icon(expanded ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
                  size: 20, color: AppTheme.inkTertiary(context)),
            ]),
          ),
        ),
        if (expanded) Padding(padding: const EdgeInsets.only(bottom: 14), child: editor),
      ],
    );
  }

  Widget _editActions({required VoidCallback onCancel, required VoidCallback onSave}) {
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      TextButton(onPressed: onCancel, child: Text('취소', style: AppTheme.sans(13, sub))),
      const SizedBox(width: 4),
      TextButton(onPressed: onSave, child: Text('저장', style: AppTheme.sans(13, accent, weight: FontWeight.w700))),
    ]);
  }

  Widget _grossIncomeEditor() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AmountField(controller: _grossEditCtrl, expand: true, autofocus: true),
      const SizedBox(height: 10),
      _editActions(onCancel: () => setState(() => _editingKey = null), onSave: _saveGrossIncomeInline),
    ]);
  }

  /// 자녀 수 — 두 세제가 서로 다른 기준을 쓴다.
  /// 카드공제 한도는 자녀등 전체, 자녀세액공제는 8세 이상만이라 둘 다 받는다.
  Widget _childrenEditor(Color ink, Color sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _stepperRow('자녀 수', _childrenTotalEditValue, ink,
          onMinus: _childrenTotalEditValue > 0
              ? () => setState(() {
                    _childrenTotalEditValue--;
                    if (_children8PlusEditValue > _childrenTotalEditValue) {
                      _children8PlusEditValue = _childrenTotalEditValue;
                    }
                  })
              : null,
          onPlus: () => setState(() => _childrenTotalEditValue++)),
      const SizedBox(height: 8),
      _stepperRow('그중 8세 이상', _children8PlusEditValue, ink,
          onMinus: _children8PlusEditValue > 0
              ? () => setState(() => _children8PlusEditValue--)
              : null,
          onPlus: _children8PlusEditValue < _childrenTotalEditValue
              ? () => setState(() => _children8PlusEditValue++)
              : null),
      const SizedBox(height: 6),
      // 카드공제는 근로소득자 전용(조특법 §126의2)이라 프리랜서에게 안내하면 안 된다.
      Text(
          _isFreelancer
              ? '8세 이상 자녀만 자녀세액공제에 쓰여요. 1명 25만·2명 55만·셋째부터 40만씩.'
              : '자녀 수는 카드공제 한도(1명 +50만·2명 이상 +100만), '
                  '8세 이상은 자녀세액공제에 쓰여요.',
          style: AppTheme.sans(11.5, AppTheme.inkTertiary(context), height: 1.4)),
      const SizedBox(height: 10),
      _editActions(onCancel: () => setState(() => _editingKey = null), onSave: _saveChildrenInline),
    ]);
  }

  Widget _stepperRow(String label, int value, Color ink,
      {VoidCallback? onMinus, VoidCallback? onPlus}) {
    return Row(children: [
      Expanded(child: Text(label, style: AppTheme.sans(13, AppTheme.inkSecondary(context)))),
      IconButton(
        onPressed: onMinus,
        icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
        visualDensity: VisualDensity.compact,
      ),
      SizedBox(
        width: 52,
        child: Text('$value명',
            textAlign: TextAlign.center,
            style: AppTheme.sans(15, ink, weight: FontWeight.w700)),
      ),
      IconButton(
        onPressed: onPlus,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
        visualDensity: VisualDensity.compact,
      ),
    ]);
  }

  Widget _ageEditor(Color sub, Color accent) {
    final ink = AppTheme.ink(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _ageEditCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: AppTheme.sans(16, ink, weight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              hintText: '0',
              hintStyle: AppTheme.sans(16, AppTheme.inkTertiary(context)),
              filled: true,
              fillColor: AppTheme.surface(context),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppTheme.line(context))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppTheme.line(context))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: accent, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('세', style: AppTheme.sans(15, sub, weight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      _editActions(onCancel: () => setState(() => _editingKey = null), onSave: _saveAgeInline),
    ]);
  }

  Widget _dependentsEditor(Color ink) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          onPressed: _dependentsEditValue > 0 ? () => setState(() => _dependentsEditValue--) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 60,
          child: Text('$_dependentsEditValue명',
              textAlign: TextAlign.center, style: AppTheme.serif(22, ink, spacing: -0.5)),
        ),
        IconButton(
          onPressed: () => setState(() => _dependentsEditValue++),
          icon: const Icon(Icons.add_rounded),
        ),
      ]),
      const SizedBox(height: 6),
      _editActions(onCancel: () => setState(() => _editingKey = null), onSave: _saveDependentsInline),
    ]);
  }

  Widget _residenceEditor(Color ink) {
    const types = ['전세', '월세', '반전세', '자가'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: types.map((type) {
          final isSelected = _residenceEditValue == type;
          return GestureDetector(
            onTap: () => setState(() => _residenceEditValue = type),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? ink : null,
                border: Border.all(color: isSelected ? ink : AppTheme.line(context), width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(type,
                  style: AppTheme.sans(13, isSelected ? Theme.of(context).cardColor : ink,
                      weight: isSelected ? FontWeight.w700 : FontWeight.w500)),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 10),
      _editActions(onCancel: () => setState(() => _editingKey = null), onSave: _saveResidenceInline),
    ]);
  }

  Widget _payDayEditor(Color ink, Color accent) {
    return Column(children: [
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1,
        ),
        itemCount: 31,
        itemBuilder: (ctx, i) {
          final day = i + 1;
          final isSelected = day == _payDayEditValue;
          return GestureDetector(
            onTap: () => setState(() => _payDayEditValue = day),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? accent : Colors.transparent,
                border: Border.all(color: isSelected ? accent : AppTheme.line(context), width: 1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('$day',
                  style: AppTheme.sans(13, isSelected ? Colors.white : ink,
                      weight: isSelected ? FontWeight.w700 : FontWeight.w400)),
            ),
          );
        },
      ),
      const SizedBox(height: 10),
      _editActions(onCancel: () => setState(() => _editingKey = null), onSave: _savePayDayInline),
    ]);
  }

  /// 프리랜서·N잡러 전용 — 세금·4대보험 적립 추정에 쓰이는 값들.
  /// 가계부 적립 카드에서 "내 정보 수정"으로 이 섹션에 바로 진입한다.
  Widget _professionSection(Color ink, Color sub, Color accent) {
    final occ = _occupationInfo;
    final propertyValue = (_profile?['property_value'] as num?)?.toDouble() ?? 0.0;
    final isSpecialWorker = _occupationCode != null && specialWorkerIndustrialRates.containsKey(_occupationCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickOccupation,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [
              Icon(Icons.work_outline_rounded, size: 18, color: occ != null ? sub : accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('업종코드',
                      style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(occ != null ? occ.name : '설정되지 않았어요 — 세금 적립액 정확도에 쓰여요',
                      style: AppTheme.sans(12, occ != null ? sub : accent)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.inkTertiary(context)),
            ]),
          ),
        ),
        AppTheme.hairline(context),
        GestureDetector(
          onTap: _openPropertyValueDialog,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [
              Icon(Icons.home_work_outlined, size: 18, color: propertyValue > 0 ? sub : accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('재산액(보증금 등)',
                      style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
                  const SizedBox(height: 2),
                  Text('건강보험료 부과점수 계산에 쓰여요', style: AppTheme.sans(12, sub)),
                ]),
              ),
              Text(propertyValue > 0 ? '${_fmt.format(propertyValue.toInt())}원' : '설정',
                  style: AppTheme.sans(15, propertyValue > 0 ? ink : accent, weight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.inkTertiary(context)),
            ]),
          ),
        ),
        AppTheme.hairline(context),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('4대보험 가입여부', style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
              const SizedBox(height: 2),
              Text('실제로 가입한 것만 켜두세요 — 나중에 언제든 바꿀 수 있어요',
                  style: AppTheme.sans(12, sub)),
              const SizedBox(height: 6),
              _insuranceToggle('국민연금', 'pension_enrolled', ink, sub, accent),
              _insuranceToggle('건강보험', 'health_enrolled', ink, sub, accent),
              if (isSpecialWorker) ...[
                _insuranceToggle('고용보험', 'employment_enrolled', ink, sub, accent),
                _insuranceToggle('산재보험', 'industrial_accident_enrolled', ink, sub, accent),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _insuranceToggle(String label, String key, Color ink, Color sub, Color accent) {
    final enabled = _profile?[key] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: AppTheme.sans(14, ink))),
        Switch(
          value: enabled,
          activeColor: accent,
          onChanged: (v) => _updateProfileFields({key: v}),
        ),
      ]),
    );
  }
}

/// 금액(원) 입력 다이얼로그 — 재산액(프리랜서·N잡러 전용 세부 섹션) 전용.
class _AmountDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final double current;
  const _AmountDialog({required this.title, required this.subtitle, required this.current});

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.current > 0 ? NumberFormat('#,###').format(widget.current.toInt()) : '',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: AppTheme.serif(17, ink, weight: FontWeight.w400, spacing: -0.3)),
        const SizedBox(height: 4),
        Text(widget.subtitle, style: AppTheme.sans(12, sub, height: 1.4)),
      ]),
      content: SizedBox(
        width: 280,
        child: AmountField(controller: _ctrl, expand: true, autofocus: true),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소', style: AppTheme.sans(14, sub)),
        ),
        TextButton(
          onPressed: () {
            final value = double.tryParse(_ctrl.text.replaceAll(',', '')) ?? 0.0;
            Navigator.pop(context, value);
          },
          child: Text('저장', style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
        ),
      ],
    );
  }
}
