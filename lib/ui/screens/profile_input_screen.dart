import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import '../../core/tax_engine/employee_tax.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

final NumberFormat _amountFormat = NumberFormat('#,###');

/// 기초 프로필 작성 — 치수가 매겨진 도면 시트 메타포.
/// 각 질문은 세금신고의 실제 챕터(청년 감면·거주·인적 공제…)로 묶이고,
/// 상단의 측정 스케일이 진행을 "항목 N / M"으로 읽어준다.
class ProfileInputScreen extends StatefulWidget {
  final String userType;

  const ProfileInputScreen({super.key, required this.userType});

  @override
  State<ProfileInputScreen> createState() => _ProfileInputScreenState();
}

class _ProfileInputScreenState extends State<ProfileInputScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 0. 예상 연봉 (직장인·N잡러만 — 유형별 독립 저장, profile_type_values)
  final TextEditingController _grossIncomeController = TextEditingController();

  // 1. 중소기업 및 청년 감면 관련
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _militaryMonthsController = TextEditingController();
  bool _hasMilitaryService = false;
  bool _isSmeEmployee = false;
  DateTime? _smeStartDate;
  DateTime? _smeEndDate;
  bool _stillEmployed = true; // 퇴사일 미정(현재 재직 중)

  // 2. 거주 및 주택 관련
  bool _isHeadOfHousehold = false;
  String _residenceType = '전세';
  bool _ownsCar = false;

  // 3. 가족 및 인적공제 관련
  bool _isMarried = false;
  bool _isNewlywed = false; // 2024~2026년 혼인신고 → 혼인 세액공제 대상
  bool _isSpouseDependent = false;
  bool _hasSpouseDisability = false;
  int _dependentCount = 0;
  int _disabledDependentCount = 0;
  bool _hasSelfDisability = false;

  // 4. 추가 인적공제 관련
  bool _hasElderly70Plus = false;  // 경로우대 (70세 이상 부양가족)
  bool _isFemaleHead = false;      // 부녀자 (여성 세대주 or 여성+배우자 있음)
  bool _isSingleParent = false;    // 한부모 (배우자없고 부양가족있음)

  // ── 청년 감면 적격 판정 (입력값 기준) ─────────────────────────
  int get _enteredAge => int.tryParse(_ageController.text.trim()) ?? 0;
  int get _enteredMilitaryMonths => _hasMilitaryService
      ? (int.tryParse(_militaryMonthsController.text.trim()) ?? 0)
      : 0;
  /// 군 복무기간(최대 6년)을 빼고도 만 34세 이하면 청년. 나이 미입력 시 안내 유지.
  bool get _isYouthEligible {
    if (_enteredAge <= 0) return true;
    final militaryYears = (_enteredMilitaryMonths / 12).floor().clamp(0, 6);
    return (_enteredAge - militaryYears) <= 34;
  }
  /// 군 복무로도 청년이 될 수 없는 나이(만 40세 초과)면 복무 질문을 생략.
  bool get _askMilitaryQuestion => _enteredAge == 0 || _enteredAge <= 40;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadGrossIncome();
  }

  /// 예상 연봉은 유형별 독립 저장(profile_type_values) — 홈 화면과 동일한 출처.
  Future<void> _loadGrossIncome() async {
    final values = await dbService.getProfileTypeValues(widget.userType);
    final gross = values['gross_income'] ?? 0.0;
    if (mounted && gross > 0) {
      setState(() => _grossIncomeController.text = _amountFormat.format(gross.toInt()));
    }
  }

  Future<void> _loadProfileData() async {
    final profile = await dbService.getProfile();
    if (profile != null && mounted) {
      setState(() {
        final age = profile['age'] as int?;
        if (age != null && age > 0) _ageController.text = age.toString();
        final mil = profile['military_months'] as int?;
        if (mil != null && mil > 0) {
          _hasMilitaryService = true;
          _militaryMonthsController.text = mil.toString();
        }
        _isMarried = profile['is_married'] == true;
        final wYear = profile['wedding_year'] as int?;
        _isNewlywed = wYear != null && wYear >= 2024 && wYear <= 2026;
        _isSpouseDependent = profile['is_spouse_dependent'] == true;
        _hasSpouseDisability = profile['has_spouse_disability'] == true;
        _hasSelfDisability = profile['has_self_disability'] == true;
        _dependentCount = profile['dependents'] ?? 0;
        _disabledDependentCount = profile['disabled_dependent_count'] ?? 0;
        if (profile['has_disability'] == true && _disabledDependentCount == 0) {
          _disabledDependentCount = 1;
        }
        final bool isRent = profile['is_monthly_rent'] == true;
        if (isRent) {
          _residenceType = '월세';
          _isHeadOfHousehold = true;
        }
        if (profile['owns_house'] == true) _residenceType = '자가';
        _ownsCar = profile['owns_car'] == true;
        _hasElderly70Plus = profile['has_elderly_70plus'] == true;
        _isFemaleHead = profile['is_female_head'] == true;
        _isSingleParent = profile['is_single_parent'] == true;
        _isSmeEmployee = profile['is_sme_employee'] == true;
        final smeYear = profile['sme_start_year'] as int?;
        if (smeYear != null) _smeStartDate = DateTime(smeYear, 1, 1);
      });
    }
  }

  Future<void> _saveProfileData() async {
    final existingProfile = await dbService.getProfile() ?? {};
    final isRent = _residenceType == '월세';
    final int? age = int.tryParse(_ageController.text.trim());
    final int militaryMonths = _hasMilitaryService
        ? (int.tryParse(_militaryMonthsController.text.trim()) ?? 0)
        : 0;
    // 프리랜서는 입력 페이지 자체가 없어 텍스트가 비어있음 — 기존 값 보존.
    final double? enteredGross =
        double.tryParse(_grossIncomeController.text.replaceAll(',', ''));
    final double gross = enteredGross ?? (existingProfile['gross_income'] as num?)?.toDouble() ?? 0.0;
    final newProfile = {
      // 이 화면이 안 다루는 항목(자녀 수·급여일·업종코드·유형판정 등)은 기존 값을 그대로
      // 얹는다. saveProfile은 행 전체를 덮어쓰므로, 여기 안 적힌 키는 지워진다 —
      // 내 정보에서 방금 입력한 값이 이 화면을 다녀오면 미설정으로 돌아가던 원인.
      ...existingProfile,
      'user_type': existingProfile['user_type'] ?? widget.userType,
      'gross_income': gross,
      'dependents': _dependentCount,
      'age': age,
      'military_months': militaryMonths,
      'is_monthly_rent': isRent,
      'monthly_rent': existingProfile['monthly_rent'] ?? 0.0,
      'decided_tax': existingProfile['decided_tax'] ?? 0.0,
      'yellow_umbrella': existingProfile['yellow_umbrella'] ?? 0.0,
      'monthly_income': existingProfile['monthly_income'] ?? 0.0,
      'is_married': _isMarried,
      // 신혼(2024~2026 혼인) → 혼인 세액공제 기준연도 저장. 기존 값이 범위면 유지.
      'wedding_year': (_isMarried && _isNewlywed)
          ? (() {
              final existing = existingProfile['wedding_year'] as int?;
              return (existing != null && existing >= 2024 && existing <= 2026)
                  ? existing
                  : DateTime.now().year;
            })()
          : null,
      'is_spouse_dependent': _isMarried ? _isSpouseDependent : false,
      'has_spouse_disability': _isMarried ? _hasSpouseDisability : false,
      'has_self_disability': _hasSelfDisability,
      'disabled_dependent_count': _disabledDependentCount,
      'data_mode': existingProfile['data_mode'] ?? 'manual',
      'paid_tax': existingProfile['paid_tax'],
      'withholding_text': existingProfile['withholding_text'],
      'expense_target': existingProfile['expense_target'],
      'has_elderly_70plus': _hasElderly70Plus,
      'is_female_head': _isFemaleHead,
      'is_single_parent': _isSingleParent,
      'is_sme_employee': _isSmeEmployee,
      'sme_start_year': _smeStartDate?.year,
      'owns_car': _ownsCar,
      'owns_house': _residenceType == '자가',
    };
    await dbService.saveProfile(newProfile);
    // 홈 화면은 유형별 독립 저장(profile_type_values)을 출처로 쓰므로 함께 갱신.
    if (enteredGross != null) {
      await dbService.setProfileTypeValues(widget.userType, grossIncome: enteredGross);
    }
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();
    final pages = _buildPages();
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _prevPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _finish() async {
    await _saveProfileData();
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  /// 연/월/일 휠 시트를 열어 날짜를 고른다. 도면 측정 게이트 스타일.
  Future<DateTime?> _pickWheelDate({required String title, DateTime? initial}) {
    final now = DateTime.now();
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppTheme.backgroundColor(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
      builder: (ctx) => _DateWheelSheet(
        title: title,
        initial: initial ?? DateTime(now.year, now.month, now.day),
        minYear: 1980,
        maxYear: now.year,
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await _pickWheelDate(title: '입사일', initial: _smeStartDate);
    if (picked != null) {
      setState(() {
        _smeStartDate = picked;
        if (_smeEndDate != null && picked.isAfter(_smeEndDate!)) _smeEndDate = null;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await _pickWheelDate(
        title: '퇴사일', initial: _smeEndDate ?? _smeStartDate);
    if (picked != null) {
      setState(() {
        _stillEmployed = false;
        _smeEndDate = picked;
      });
    }
  }

  // ── 페이지 공통 머리 — 챕터 라벨 + 세리프 질문 + 보조설명 ──────────
  Widget _pageHead(String label, String title, String? subtitle) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 14),
        Text(title, style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.25)),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(subtitle, style: AppTheme.sans(14, sub, height: 1.55)),
        ],
      ],
    );
  }

  Widget _buildInputPage({
    required String label,
    required String title,
    String? subtitle,
    required TextEditingController controller,
    String? suffix,
    ValueChanged<String>? onChanged,
    Widget? footer,
  }) {
    final ink = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHead(label, title, subtitle),
          const SizedBox(height: 44),
          // 헤어라인 기준선 위 세리프 숫자 입력 — 도면의 치수 기입란
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.lineStrong(context), width: 1.4)),
            ),
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      if (suffix == '원' || suffix == '만원')
                        const ThousandsFormatter()
                      else
                        FilteringTextInputFormatter.digitsOnly,
                    ],
                    textAlign: TextAlign.right,
                    autofocus: true,
                    cursorColor: accent,
                    style: AppTheme.serif(40, ink, spacing: -1.0, height: 1.0),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      hintText: '0',
                      hintStyle: AppTheme.serif(40, AppTheme.inkTertiary(context), spacing: -1.0, height: 1.0),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: onChanged,
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 10),
                  Text(suffix, style: AppTheme.sans(18, AppTheme.inkSecondary(context), weight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 14),
            footer,
          ],
        ],
      ),
    );
  }

  /// 예상 연봉 입력 페이지 — 천 단위 콤마 자동 삽입 + 실시간 세후 예상 표시.
  Widget _buildSelectionPage({
    required String label,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHead(label, title, subtitle),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(child: _choiceCell('네', value == true, () => onChanged(true))),
              const SizedBox(width: 12),
              Expanded(child: _choiceCell('아니요', value == false, () => onChanged(false))),
            ],
          ),
        ],
      ),
    );
  }

  /// 선택 셀 — 선택 시 잉크 반전(블루 틴트 없음, 홈 화면 언어).
  Widget _choiceCell(String text, bool selected, VoidCallback onTap) {
    final ink = AppTheme.ink(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? ink : null,
          border: Border.all(color: selected ? ink : AppTheme.line(context), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: AppTheme.sans(15, selected ? AppTheme.backgroundColor(context) : ink,
                weight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _buildCounterPage({
    required String label,
    required String title,
    String? subtitle,
    required int count,
    required ValueChanged<int> onChanged,
  }) {
    final ink = AppTheme.ink(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHead(label, title, subtitle),
          const SizedBox(height: 40),
          AppTheme.hairline(context),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _stepperButton(Icons.remove, count > 0, () { if (count > 0) onChanged(count - 1); }),
                // 세리프 숫자 — 도면 수치
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$count', style: AppTheme.serif(48, ink, spacing: -1.5, height: 1.0)),
                    const SizedBox(width: 4),
                    Text('명', style: AppTheme.sans(18, AppTheme.inkSecondary(context), weight: FontWeight.w600)),
                  ],
                ),
                _stepperButton(Icons.add, true, () => onChanged(count + 1)),
              ],
            ),
          ),
          AppTheme.hairline(context),
        ],
      ),
    );
  }

  /// 증감 버튼 — 채운 원이 아니라 얇은 테두리 사각.
  Widget _stepperButton(IconData icon, bool active, VoidCallback onTap) {
    final ink = AppTheme.ink(context);
    return GestureDetector(
      onTap: active ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: active ? AppTheme.lineStrong(context) : AppTheme.line(context), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 22, color: active ? ink : AppTheme.inkTertiary(context)),
      ),
    );
  }

  Widget _buildDatesPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHead('중소기업 감면', '중소기업에 언제부터\n일하고 계신가요?', '재직 기간만큼 소득세 감면이 적용돼요.'),
          const SizedBox(height: 36),
          AppTheme.hairline(context),
          // 입사일 — 휠로 선택
          _dateValueRow(
            '입사일',
            _smeStartDate == null ? null : DateFormat('yyyy.MM.dd').format(_smeStartDate!),
            _pickStartDate,
          ),
          AppTheme.hairline(context),
          // 퇴사일 — 재직 중 / 날짜 지정 토글
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('퇴사일', style: AppTheme.sans(15, AppTheme.ink(context), weight: FontWeight.w600)),
                    Row(children: [
                      _segCell('재직 중', _stillEmployed, () {
                        setState(() { _stillEmployed = true; _smeEndDate = null; });
                      }),
                      const SizedBox(width: 8),
                      _segCell('퇴사일 지정', !_stillEmployed, _pickEndDate),
                    ]),
                  ],
                ),
                // 날짜 지정 모드일 때만 고른 날짜 표시
                if (!_stillEmployed) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickEndDate,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _smeEndDate == null ? '날짜 선택' : DateFormat('yyyy.MM.dd').format(_smeEndDate!),
                          style: _smeEndDate == null
                              ? AppTheme.sans(15, AppTheme.inkTertiary(context))
                              : AppTheme.sans(15, AppTheme.accentColor(context), weight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.inkTertiary(context)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppTheme.hairline(context),
        ],
      ),
    );
  }

  /// 값 표시 + 휠 진입 행 (입사일).
  Widget _dateValueRow(String label, String? value, VoidCallback onTap) {
    final ink = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);
    final tert = AppTheme.inkTertiary(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.sans(15, ink, weight: FontWeight.w600)),
            Row(children: [
              Text(value ?? '선택해주세요',
                  style: value == null
                      ? AppTheme.sans(15, tert)
                      : AppTheme.sans(15, accent, weight: FontWeight.w700)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 18, color: tert),
            ]),
          ],
        ),
      ),
    );
  }

  /// 작은 분절 토글 셀 — 선택 시 잉크 반전.
  Widget _segCell(String text, bool selected, VoidCallback onTap) {
    final ink = AppTheme.ink(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? ink : null,
          border: Border.all(color: selected ? ink : AppTheme.line(context), width: 1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(text,
            style: AppTheme.sans(12, selected ? AppTheme.backgroundColor(context) : AppTheme.inkSecondary(context),
                weight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  /// 내 정보에서만 진입한다("더 많은 공제 항목 입력하기"). 예상 연봉·만 나이·
  /// 거주 형태·부양가족 수는 그 화면에 인라인으로 있어 여기서 다시 묻지 않는다 —
  /// 값은 프로필에서 로드하고 그대로 저장하므로 유지된다.
  List<Widget> _buildPages() {
    List<Widget> pages = [];
    bool isFreelancerOnly = widget.userType == '프리랜서';

    if (!isFreelancerOnly) {
      if (_askMilitaryQuestion) {
        pages.add(_buildSelectionPage(
          label: '청년 감면',
          title: '군대에\n다녀오셨나요?',
          subtitle: '군 복무 기간만큼 청년 나이 제한이 연장돼요.',
          value: _hasMilitaryService,
          onChanged: (v) {
            setState(() { _hasMilitaryService = v; if (!v) _militaryMonthsController.clear(); });
            Future.delayed(const Duration(milliseconds: 250), _nextPage);
          },
        ));
        if (_hasMilitaryService) {
          pages.add(_buildInputPage(
            label: '청년 감면',
            title: '군 복무 기간은\n몇 개월인가요?',
            controller: _militaryMonthsController,
            suffix: '개월',
          ));
        }
      }
      pages.add(_buildSelectionPage(
        label: '중소기업 감면',
        title: '현재 중소기업에\n재직 중이신가요?',
        subtitle: _isYouthEligible
            ? '청년(만 34세 이하)은 취업 후 5년간 소득세를 90%까지 감면받아요.'
            : '청년 나이는 지났지만, 60세 이상·장애인·경력단절여성이면 3년간 70% 감면 대상이에요.',
        value: _isSmeEmployee,
        onChanged: (v) {
          setState(() => _isSmeEmployee = v);
          Future.delayed(const Duration(milliseconds: 250), _nextPage);
        },
      ));
      if (_isSmeEmployee) {
        pages.add(_buildDatesPage());
      }
      pages.add(_buildSelectionPage(
        label: '거주 · 주택',
        title: '주민등록상\n세대주이신가요?',
        subtitle: '주택청약, 대출 공제를 받으려면 세대주여야 해요.',
        value: _isHeadOfHousehold,
        onChanged: (v) {
          setState(() => _isHeadOfHousehold = v);
          Future.delayed(const Duration(milliseconds: 250), _nextPage);
        },
      ));
    }

    // Common
    pages.add(_buildSelectionPage(
      label: '자산',
      title: '차량을\n보유하고 계신가요?',
      subtitle: '자동차세 연납 등 차량 관련 알림 대상 여부를 판단해요.',
      value: _ownsCar,
      onChanged: (v) {
        setState(() => _ownsCar = v);
        Future.delayed(const Duration(milliseconds: 250), _nextPage);
      },
    ));
    pages.add(_buildSelectionPage(
      label: '배우자',
      title: '현재\n기혼이신가요?',
      subtitle: '혼인 세액공제 및 배우자 공제 확인에 필요해요.',
      value: _isMarried,
      onChanged: (v) {
        setState(() { _isMarried = v; if (!v) { _isNewlywed = false; _isSpouseDependent = false; _hasSpouseDisability = false; }});
        Future.delayed(const Duration(milliseconds: 250), _nextPage);
      },
    ));
    if (_isMarried) {
      pages.add(_buildSelectionPage(
        label: '배우자',
        title: '2024년 이후에\n혼인신고를 하셨나요?',
        subtitle: '2024~2026년 혼인신고는 혼인 세액공제(생애 1회 50만 원) 대상이에요.',
        value: _isNewlywed,
        onChanged: (v) {
          setState(() => _isNewlywed = v);
          Future.delayed(const Duration(milliseconds: 250), _nextPage);
        },
      ));
      pages.add(_buildSelectionPage(
        label: '배우자',
        title: '배우자분이 기본공제\n대상인가요?',
        subtitle: '배우자의 연 소득금액 100만 원\n(근로소득만 있다면 500만 원) 이하',
        value: _isSpouseDependent,
        onChanged: (v) {
          setState(() => _isSpouseDependent = v);
          Future.delayed(const Duration(milliseconds: 250), _nextPage);
        },
      ));
      if (_isSpouseDependent) {
        pages.add(_buildSelectionPage(
          label: '배우자',
          title: '배우자가 장애인 공제\n대상인가요?',
          subtitle: '장애·중증질환 등으로 돌봄이 필요한 경우 — 추가공제 200만 원',
          value: _hasSpouseDisability,
          onChanged: (v) {
            setState(() => _hasSpouseDisability = v);
            Future.delayed(const Duration(milliseconds: 250), _nextPage);
          },
        ));
      }
    }

    if (_dependentCount > 0) {
      pages.add(_buildCounterPage(
        label: '부양가족',
        title: '그 중 장애인 공제\n대상은 몇 명인가요?',
        subtitle: '장애·중증질환 등 해당 가족 1명당 200만 원 추가 공제',
        count: _disabledDependentCount,
        onChanged: (v) {
          if (v <= _dependentCount) setState(() => _disabledDependentCount = v);
        },
      ));
    }

    pages.add(_buildSelectionPage(
      label: '본인',
      title: '장애인 공제 대상에\n해당하시나요?',
      subtitle: '장애인복지법상 장애인, 중증환자, 국가유공 상이자 등 — 추가공제 200만 원',
      value: _hasSelfDisability,
      onChanged: (v) {
        setState(() => _hasSelfDisability = v);
        Future.delayed(const Duration(milliseconds: 250), _nextPage);
      },
    ));

    // 추가 인적공제 — 경로우대
    if (_dependentCount > 0) {
      pages.add(_buildSelectionPage(
        label: '추가 공제',
        title: '부양가족 중\n만 70세 이상이 있나요?',
        subtitle: '경로우대 추가공제 100만 원 적용',
        value: _hasElderly70Plus,
        onChanged: (v) {
          setState(() => _hasElderly70Plus = v);
          Future.delayed(const Duration(milliseconds: 250), _nextPage);
        },
      ));
    }

    // 추가 인적공제 — 부녀자
    pages.add(_buildSelectionPage(
      label: '추가 공제',
      title: '부녀자공제\n해당되시나요?',
      subtitle: '여성 근로자로 배우자가 있거나(소득 3천만원 이하),\n또는 배우자 없이 부양가족 있는 여성 세대주 → 50만 원',
      value: _isFemaleHead,
      onChanged: (v) {
        setState(() => _isFemaleHead = v);
        Future.delayed(const Duration(milliseconds: 250), _nextPage);
      },
    ));

    // 추가 인적공제 — 한부모
    if (!_isMarried && _dependentCount > 0) {
      pages.add(_buildSelectionPage(
        label: '추가 공제',
        title: '한부모공제\n해당되시나요?',
        subtitle: '배우자가 없고 기본공제 대상 자녀·직계비속이 있는 경우 100만 원\n(부녀자공제와 중복 시 한부모공제 우선 적용)',
        value: _isSingleParent,
        onChanged: (v) {
          setState(() => _isSingleParent = v);
          Future.delayed(const Duration(milliseconds: 250), _nextPage);
        },
      ));
    }

    return pages;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = _buildPages();
    bool isLast = _currentPage >= pages.length - 1;
    final total = pages.length;
    final step = (_currentPage + 1).clamp(1, total == 0 ? 1 : total);
    final double progress = total == 0 ? 0 : step / total;
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final bg = AppTheme.backgroundColor(context);

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _prevPage();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
            onPressed: _prevPage,
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // ── 측정 스케일: "항목 N / M" 주석 + 얇은 진행선 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Row(
                  children: [
                    Text('항목 ', style: AppTheme.label(context)),
                    Text('${step.toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                        style: AppTheme.sans(12, ink, weight: FontWeight.w700, spacing: 1.0)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 2,
                          backgroundColor: AppTheme.line(context),
                          valueColor: AlwaysStoppedAnimation<Color>(ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  children: pages,
                ),
              ),
              // ── 하단 진행 버튼 — 잉크 채움, 화살표 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: GestureDetector(
                  onTap: isLast ? _finish : _nextPage,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isLast ? '프로필 완성' : '다음',
                            style: AppTheme.sans(15, bg, weight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Icon(isLast ? Icons.check_rounded : Icons.arrow_forward, size: 16, color: bg),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 연 · 월 · 일 휠 시트 — 도면 측정 게이트.
/// 중앙 두 헤어라인이 값을 가두고, 위·아래는 흐려져 오도미터처럼 읽힌다.
class _DateWheelSheet extends StatefulWidget {
  final String title;
  final DateTime initial;
  final int minYear;
  final int maxYear;
  const _DateWheelSheet({
    required this.title,
    required this.initial,
    required this.minYear,
    required this.maxYear,
  });

  @override
  State<_DateWheelSheet> createState() => _DateWheelSheetState();
}

class _DateWheelSheetState extends State<_DateWheelSheet> {
  static const double _extent = 44;

  late int _year;
  late int _month;
  late int _day;

  late final FixedExtentScrollController _yearCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _dayCtrl;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year.clamp(widget.minYear, widget.maxYear);
    _month = widget.initial.month;
    _day = widget.initial.day;
    _yearCtrl = FixedExtentScrollController(initialItem: _year - widget.minYear);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  /// 연·월 변경 시 일수가 줄면 일을 보정하고 휠을 맞춘다.
  void _clampDay() {
    final max = _daysInMonth;
    if (_day > max) {
      _day = max;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dayCtrl.jumpToItem(_day - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final bg = AppTheme.backgroundColor(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.line(context), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(widget.title, style: AppTheme.serif(22, ink)),
            const SizedBox(height: 18),
            // 열 캡션
            Row(children: [
              Expanded(child: Center(child: Text('연', style: AppTheme.label(context)))),
              Expanded(child: Center(child: Text('월', style: AppTheme.label(context)))),
              Expanded(child: Center(child: Text('일', style: AppTheme.label(context)))),
            ]),
            const SizedBox(height: 6),
            // 휠 3개 + 중앙 측정 게이트
            SizedBox(
              height: _extent * 5,
              child: Stack(
                children: [
                  // 선택 게이트 — 상·하 헤어라인
                  Center(
                    child: IgnorePointer(
                      child: Container(
                        height: _extent,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppTheme.lineStrong(context), width: 1),
                            bottom: BorderSide(color: AppTheme.lineStrong(context), width: 1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(children: [
                    Expanded(
                      child: _wheel(
                        controller: _yearCtrl,
                        count: widget.maxYear - widget.minYear + 1,
                        builder: (i) => '${widget.minYear + i}',
                        onChanged: (i) => setState(() { _year = widget.minYear + i; _clampDay(); }),
                      ),
                    ),
                    Expanded(
                      child: _wheel(
                        controller: _monthCtrl,
                        count: 12,
                        builder: (i) => '${i + 1}',
                        onChanged: (i) => setState(() { _month = i + 1; _clampDay(); }),
                      ),
                    ),
                    Expanded(
                      child: _wheel(
                        controller: _dayCtrl,
                        count: _daysInMonth,
                        builder: (i) => '${i + 1}',
                        onChanged: (i) => setState(() => _day = i + 1),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.pop(context, DateTime(_year, _month, _day)),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(4)),
                child: Text('적용', style: AppTheme.sans(15, bg, weight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int) builder,
    required ValueChanged<int> onChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _extent,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.5,
      perspective: 0.0028,
      squeeze: 1.1,
      overAndUnderCenterOpacity: 0.32,
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, i) => Center(
          child: Text(builder(i), style: AppTheme.serif(28, AppTheme.ink(context), spacing: 0, height: 1.0)),
        ),
      ),
    );
  }
}
