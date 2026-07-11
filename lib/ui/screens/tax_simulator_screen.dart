import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../core/data/occupation_data.dart';
import '../../core/data/db_helper.dart';
import '../components/occupation_search_bottom_sheet.dart';
import '../../core/parsing/pdf_text_extractor.dart';
import '../../core/parsing/pension_income_parser.dart';
import '../../core/tax_engine/freelancer_tax.dart';
import '../../core/tax_engine/combined_tax.dart';
import '../../core/tax_engine/employee_tax.dart';
import '../../core/tax_engine/bookkeeping_duty.dart';
import 'expense_calendar_screen.dart';
import 'tax_report_form_screen.dart';

class TaxSimulatorScreen extends StatefulWidget {
  final String userType;

  const TaxSimulatorScreen({
    super.key,
    required this.userType,
  });

  @override
  State<TaxSimulatorScreen> createState() => _TaxSimulatorScreenState();
}

class _TaxSimulatorScreenState extends State<TaxSimulatorScreen> {
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _creditCardController = TextEditingController();
  final TextEditingController _monthlyRentController = TextEditingController();

  final TextEditingController _freelancerIncomeController = TextEditingController();
  final TextEditingController _monthsController = TextEditingController(text: '12');
  final TextEditingController _yellowUmbrellaController = TextEditingController();
  final TextEditingController _pensionIncomeController = TextEditingController();
  final TextEditingController _otherIncomeController = TextEditingController();

  OccupationInfo? _selectedOccupation;
  bool _hasYellowUmbrella = false;

  FreelancerTaxResult? _freelancerResult;
  CombinedTaxResult? _combinedResult;
  CreditCardDeductionResult? _employeeCardResult;
  RentRefundResult? _employeeRentResult;
  SpecialDeductionResult? _specialDeductionResult;
  double _employeeTotalRefund = 0.0;
  bool _showSensitiveSection = false;

  final TextEditingController _paidTaxController = TextEditingController();
  final TextEditingController _withholdingTextController = TextEditingController();
  final TextEditingController _infertilityMedicalController = TextEditingController();
  final TextEditingController _selfSeniorDisabledMedicalController = TextEditingController();
  final TextEditingController _otherDependentMedicalController = TextEditingController();
  final TextEditingController _donationController = TextEditingController();
  final TextEditingController _childrenEduController = TextEditingController();
  final TextEditingController _childrenCountController = TextEditingController(text: '0');
  final TextEditingController _collegeEduController = TextEditingController();
  final TextEditingController _collegeCountController = TextEditingController(text: '0');

  bool get _isEmployee => widget.userType == '직장인' || widget.userType == 'N잡러';
  bool get _isFreelancer => widget.userType == '프리랜서' || widget.userType == 'N잡러';

  bool _incomeAutoFilled = false;
  bool _creditAutoFilled = false;
  bool _rentAutoFilled   = false;
  // 자동기입 출처 라벨 — 달력(월 소득) vs 연말정산/사업 기록.
  String _autoFillLabel  = '달력 기록에서 불러옴';

  // 프로필에서 로드하는 인적 정보
  int _dependentCount = 0;
  bool _hasSelfDisability = false;
  int _disabledDependentCount = 0;

  // N잡러 세액공제 컨트롤러
  final TextEditingController _insurancePremiumController = TextEditingController();
  final TextEditingController _childrenCount8PlusController = TextEditingController(text: '0');
  final TextEditingController _newbornCountController = TextEditingController(text: '0');
  final TextEditingController _pensionSavingsSimController = TextEditingController();
  final TextEditingController _irpSimController = TextEditingController();

  // 프리랜서 건강보험 지역가입자 컨트롤러
  final TextEditingController _freelancerHealthInsController = TextEditingController();

  // 기장의무 판정 컨트롤러 — 직전연도 수입·신규사업자·겸업 (프로필에 영속 저장)
  final TextEditingController _priorYearIncomeController = TextEditingController();
  bool _isNewBusiness = false;
  bool _hasMultipleBusinesses = false;
  Map<String, dynamic>? _profileCache;

  // 기장 vs 추계 비교 (2단계) — 가계부 사업경비 누적 + 비교 결과.
  double _businessExpenseAccumulated = 0.0;
  BookkeepingComparison? _bookkeepingComparison;

  // N잡러 소득공제 추가항목 컨트롤러
  final TextEditingController _mortgageSimController = TextEditingController();
  final TextEditingController _hometownDonationSimController = TextEditingController();

  // 프로필 자동 로드 (추가 인적공제 + 혼인·중소기업)
  bool _hasElderly70Plus = false;
  bool _isSingleParent = false;
  bool _isSingleFemaleHead = false;
  bool _weddingCredit2426 = false;
  bool _isSmeEmployee = false;
  int _smeStartYear = 0;
  bool _isYouthSme = false;

  @override
  void initState() {
    super.initState();
    _salaryController.addListener(_calculateTax);
    _freelancerIncomeController.addListener(_calculateTax);
    _monthsController.addListener(_calculateTax);
    _yellowUmbrellaController.addListener(_calculateTax);
    _pensionIncomeController.addListener(_calculateTax);
    _otherIncomeController.addListener(_calculateTax);
    _creditCardController.addListener(_calculateTax);
    _monthlyRentController.addListener(_calculateTax);
    _paidTaxController.addListener(_calculateTax);
    _infertilityMedicalController.addListener(_calculateTax);
    _selfSeniorDisabledMedicalController.addListener(_calculateTax);
    _otherDependentMedicalController.addListener(_calculateTax);
    _donationController.addListener(_calculateTax);
    _childrenEduController.addListener(_calculateTax);
    _childrenCountController.addListener(_calculateTax);
    _collegeEduController.addListener(_calculateTax);
    _collegeCountController.addListener(_calculateTax);
    _insurancePremiumController.addListener(_calculateTax);
    _childrenCount8PlusController.addListener(_calculateTax);
    _newbornCountController.addListener(_calculateTax);
    _pensionSavingsSimController.addListener(_calculateTax);
    _irpSimController.addListener(_calculateTax);
    _freelancerHealthInsController.addListener(_calculateTax);
    _mortgageSimController.addListener(_calculateTax);
    _hometownDonationSimController.addListener(_calculateTax);
    _priorYearIncomeController.addListener(_onBookkeepingInputChanged);
    _loadFromCalendar();
  }

  Future<void> _loadFromCalendar() async {
    final now = DateTime.now();

    // 소득: 프로필 연소득 우선, 없으면 달력 월별 합산
    final profile = await dbService.getProfile();
    _profileCache = profile ?? {};
    double annualIncome = 0.0;
    double priorYearIncome = 0.0;
    bool isNewBusiness = false;
    bool hasMultipleBusinesses = false;
    int dependentCount = 0;
    bool hasSelfDisability = false;
    int disabledDependentCount = 0;
    bool hasElderly70Plus = false;
    bool isSingleParent = false;
    bool isSingleFemaleHead = false;
    bool weddingCredit2426 = false;
    bool isSmeEmployee = false;
    int smeStartYear = 0;
    bool isYouthSme = false;
    if (profile != null) {
      final gross = profile['gross_income'] as double? ?? 0.0;
      if (gross > 0) {
        annualIncome = gross;
      } else {
        final monthly = await dbService.getMonthlyIncomesForYear(now.year);
        annualIncome = monthly.values.fold(0.0, (a, b) => a + b);
      }
      dependentCount = profile['dependents'] as int? ?? 0;
      hasSelfDisability = profile['has_self_disability'] == true;
      disabledDependentCount = profile['disabled_dependent_count'] as int? ?? 0;
      hasElderly70Plus = profile['has_elderly_70plus'] == true;
      isSingleParent = profile['is_single_parent'] == true;
      isSingleFemaleHead = profile['is_female_head'] == true;
      final wYear = profile['wedding_year'] as int?;
      weddingCredit2426 = (wYear != null && wYear >= 2024 && wYear <= 2026);
      isSmeEmployee = profile['is_sme_employee'] == true;
      smeStartYear = profile['sme_start_year'] as int? ?? 0;
      final age = profile['age'] as int? ?? 0;
      final militaryMonths = profile['military_months'] as int? ?? 0;
      isYouthSme = EmployeeTaxCalculator.isYouthSmeEligible(
          age: age, militaryMonths: militaryMonths);
      priorYearIncome = profile['prior_year_income'] as double? ?? 0.0;
      isNewBusiness = profile['is_new_business'] == true;
      hasMultipleBusinesses = profile['has_multiple_businesses'] == true;
    }

    // 신용카드 연간 누적 (지출 달력 기록)
    final expenses = await dbService.getExpenses();
    double creditTotal = 0.0;
    double businessExpenseTotal = 0.0;
    for (final e in expenses) {
      if (e.date.year != now.year) continue;
      if (e.paymentMethod == '신용카드') creditTotal += e.amount;
      if (e.isBusiness) businessExpenseTotal += e.amount;
    }

    if (!mounted) return;

    // 월세: 프로필에서 로드
    double monthlyRent = 0.0;
    if (profile != null) {
      monthlyRent = profile['monthly_rent'] as double? ?? 0.0;
    }

    if (annualIncome > 0) {
      if (_isEmployee) {
        _salaryController.text = annualIncome.toInt().toString();
      } else {
        _freelancerIncomeController.text = annualIncome.toInt().toString();
      }
    }
    if (creditTotal > 0 && _isEmployee) {
      _creditCardController.text = creditTotal.toInt().toString();
    }
    if (monthlyRent > 0 && _isEmployee) {
      _monthlyRentController.text = monthlyRent.toInt().toString();
    }
    if (priorYearIncome > 0) {
      _priorYearIncomeController.text = priorYearIncome.toInt().toString();
    }

    setState(() {
      _incomeAutoFilled = annualIncome > 0;
      _creditAutoFilled = creditTotal > 0 && _isEmployee;
      _rentAutoFilled   = monthlyRent > 0 && _isEmployee;
      _isNewBusiness = isNewBusiness;
      _hasMultipleBusinesses = hasMultipleBusinesses;
      _businessExpenseAccumulated = businessExpenseTotal;
      _dependentCount = dependentCount;
      _hasSelfDisability = hasSelfDisability;
      _disabledDependentCount = disabledDependentCount;
      _hasElderly70Plus = hasElderly70Plus;
      _isSingleParent = isSingleParent;
      _isSingleFemaleHead = isSingleFemaleHead;
      _weddingCredit2426 = weddingCredit2426;
      _isSmeEmployee = isSmeEmployee;
      _smeStartYear = smeStartYear;
      _isYouthSme = isYouthSme;
    });

    // 연말정산 기록(수기/PDF)이 있으면 진단 입력을 자동기입(있으면 우선).
    // 기록이 없으면 그대로 비워 두어 사용자가 직접 입력하도록 허용.
    final rec = await dbService.getAnnualRecord(widget.userType);
    if (rec != null && mounted) {
      void put(TextEditingController c, dynamic v) {
        final n = (v as num?)?.toInt() ?? 0;
        if (n > 0) c.text = n.toString();
      }
      final gross = (rec['grossSalary'] as num?)?.toInt() ?? 0;
      if (gross > 0) {
        (_isEmployee ? _salaryController : _freelancerIncomeController).text = gross.toString();
      }
      if (_isEmployee) {
        put(_creditCardController, rec['creditCard']);
        final rentAnnual = (rec['rent'] as num?)?.toInt() ?? 0;
        if (rentAnnual > 0) _monthlyRentController.text = (rentAnnual ~/ 12).toString();
        // N잡러: 사업 총수입 자동기입 (진단과 동일한 총수입+업종 모델).
        put(_freelancerIncomeController, rec['bizGrossIncome']);
      }
      // 업종코드 복원 (프리랜서 기록·N잡러 기록 공통). 진단의 경비율 계산에 쓰인다.
      final occCode = rec['occupationCode'] as String?;
      if (occCode != null && occCode.isNotEmpty) {
        final occ = OccupationData.occupations[occCode];
        if (occ != null) _selectedOccupation = occ;
      }
      put(_otherDependentMedicalController, rec['medical']);
      put(_donationController, rec['donation']);
      put(_childrenEduController, rec['education']);
      put(_insurancePremiumController, rec['lifeInsurance']);
      put(_pensionSavingsSimController, rec['pensionSavings']);
      if (gross > 0) {
        setState(() {
          _incomeAutoFilled = true;
          _autoFillLabel = '기록에서 불러옴'; // 출처: 연말정산/사업 기록 (달력보다 우선)
        });
      }
      // 업종 복원·자동기입 직후 결과 재계산 (프리랜서는 공제 put이 없어
      // 리스너가 안 돌 수 있으므로 명시적으로 한 번 호출).
      _calculateTax();
    }
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _freelancerIncomeController.dispose();
    _monthsController.dispose();
    _yellowUmbrellaController.dispose();
    _pensionIncomeController.dispose();
    _otherIncomeController.dispose();
    _creditCardController.dispose();
    _monthlyRentController.dispose();
    _paidTaxController.dispose();
    _withholdingTextController.dispose();
    _infertilityMedicalController.dispose();
    _selfSeniorDisabledMedicalController.dispose();
    _otherDependentMedicalController.dispose();
    _donationController.dispose();
    _childrenEduController.dispose();
    _childrenCountController.dispose();
    _collegeEduController.dispose();
    _collegeCountController.dispose();
    _insurancePremiumController.dispose();
    _childrenCount8PlusController.dispose();
    _newbornCountController.dispose();
    _pensionSavingsSimController.dispose();
    _irpSimController.dispose();
    _freelancerHealthInsController.dispose();
    _mortgageSimController.dispose();
    _hometownDonationSimController.dispose();
    _priorYearIncomeController.dispose();
    super.dispose();
  }

  void _calculateTax() {
    if (_isEmployee && !_isFreelancer) {
      if (_salaryController.text.isEmpty) {
        setState(() {
          _employeeCardResult = null;
          _employeeRentResult = null;
          _specialDeductionResult = null;
          _employeeTotalRefund = 0.0;
        });
        return;
      }
      final salary = double.tryParse(_salaryController.text) ?? 0.0;
      final creditCard = double.tryParse(_creditCardController.text) ?? 0.0;
      final monthlyRent = double.tryParse(_monthlyRentController.text) ?? 0.0;
      final paidTax = double.tryParse(_paidTaxController.text) ?? 0.0;

      final cResult = EmployeeTaxCalculator.calculateCreditCardDeduction(
        grossIncome: salary,
        creditCard: creditCard,
        debitCardAndCash: 0,
        traditionalMarket: 0,
        publicTransport: 0,
        cultureExpense: 0,
      );

      // 월세 세액공제: 기납부세액 입력 여부와 무관하게 금액 전체 계산 후 나중에 cap
      final rResult = EmployeeTaxCalculator.simulateRentRefund(
        grossIncome: salary,
        monthlyRent: monthlyRent,
        decidedTax: 999999999.0,
      );

      // 민감항목 공제
      final infertilityMedical = double.tryParse(_infertilityMedicalController.text) ?? 0.0;
      final selfSeniorMedical = double.tryParse(_selfSeniorDisabledMedicalController.text) ?? 0.0;
      final otherMedical = double.tryParse(_otherDependentMedicalController.text) ?? 0.0;
      final donation = double.tryParse(_donationController.text) ?? 0.0;
      final childrenEdu = double.tryParse(_childrenEduController.text) ?? 0.0;
      final childrenCount = int.tryParse(_childrenCountController.text) ?? 0;
      final collegeEdu = double.tryParse(_collegeEduController.text) ?? 0.0;
      final collegeCount = int.tryParse(_collegeCountController.text) ?? 0;

      final specialResult = EmployeeTaxCalculator.calculateSpecialDeductions(
        grossIncome: salary,
        infertilityMedical: infertilityMedical,
        selfAndSeniorAndDisabledMedical: selfSeniorMedical,
        otherDependentMedical: otherMedical,
        childrenEduExpense: childrenEdu,
        childrenCount: childrenCount,
        collegeEduExpense: collegeEdu,
        collegeCount: collegeCount,
        generalDonation: donation,
        mortgageInterestExpense: 0,
      );

      final double totalCredit = rResult.expectedRefund
          + specialResult.medicalTaxCredit
          + specialResult.donationTaxCredit
          + specialResult.educationTaxCredit;
      final double netRefund = paidTax > 0 ? (totalCredit > paidTax ? paidTax : totalCredit) : totalCredit;

      setState(() {
        _employeeCardResult = cResult;
        _employeeRentResult = rResult;
        _specialDeductionResult = specialResult;
        _employeeTotalRefund = netRefund;
      });
    }
    else if (_isFreelancer && !_isEmployee) {
      if (_freelancerIncomeController.text.isEmpty || _selectedOccupation == null) {
        setState(() {
          _freelancerResult = null;
          _bookkeepingComparison = null;
        });
        return;
      }
      final income = double.tryParse(_freelancerIncomeController.text) ?? 0.0;
      final months = int.tryParse(_monthsController.text) ?? 12;
      final yellowUmbrella = _hasYellowUmbrella ? (double.tryParse(_yellowUmbrellaController.text) ?? 0.0) : 0.0;
      final healthIns = double.tryParse(_freelancerHealthInsController.text) ?? 0.0;
      final judgment = _bookkeepingJudgment;

      if (judgment != null && judgment.isSimplified) {
        // 간편장부대상자 — 가계부 실제경비(기장) vs 경비율(추계) 중 유리한 쪽을 채택.
        final comparison = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
          accumulatedIncome: income,
          accumulatedActualExpense: _businessExpenseAccumulated,
          inputMonths: months,
          allowanceCount: _dependentCount,
          occupationCode: _selectedOccupation!.code,
          yellowUmbrellaPayment: yellowUmbrella,
          freelancerHealthInsurance: healthIns,
          disabledDependentCount: _disabledDependentCount,
          hasSelfDisability: _hasSelfDisability,
        );
        setState(() {
          _bookkeepingComparison = comparison;
          _freelancerResult = comparison.bookkeepingIsBetter ? comparison.bookkeeping : comparison.estimate;
        });
      } else {
        // 복식부기의무자 등 — 비교 없이 경비율 추정만(입력 자체가 UI에서 숨겨짐).
        final result = FreelancerTaxCalculator.calculateTaxSimulation(
          accumulatedIncome: income,
          inputMonths: months,
          allowanceCount: _dependentCount,
          occupationCode: _selectedOccupation!.code,
          isBookkeeping: false,
          yellowUmbrellaPayment: yellowUmbrella,
          freelancerHealthInsurance: healthIns,
          disabledDependentCount: _disabledDependentCount,
          hasSelfDisability: _hasSelfDisability,
        );
        setState(() {
          _bookkeepingComparison = null;
          _freelancerResult = result;
        });
      }
    }
    else if (_isEmployee && _isFreelancer) {
      if (_freelancerIncomeController.text.isEmpty || _salaryController.text.isEmpty || _selectedOccupation == null) {
        setState(() => _combinedResult = null);
        return;
      }
      final salary = double.tryParse(_salaryController.text) ?? 0.0;
      final fIncome = double.tryParse(_freelancerIncomeController.text) ?? 0.0;
      final months = int.tryParse(_monthsController.text) ?? 12;
      final yellowUmbrella = _hasYellowUmbrella ? (double.tryParse(_yellowUmbrellaController.text) ?? 0.0) : 0.0;
      final creditCard = double.tryParse(_creditCardController.text) ?? 0.0;
      final monthlyRent = double.tryParse(_monthlyRentController.text) ?? 0.0;
      final pensionIncome = double.tryParse(_pensionIncomeController.text) ?? 0.0;
      final otherIncome = double.tryParse(_otherIncomeController.text) ?? 0.0;

      final insurancePrem = double.tryParse(_insurancePremiumController.text) ?? 0.0;
      final children8Plus = int.tryParse(_childrenCount8PlusController.text) ?? 0;
      final newborns = int.tryParse(_newbornCountController.text) ?? 0;
      final pensionSav = double.tryParse(_pensionSavingsSimController.text) ?? 0.0;
      final irpPay = double.tryParse(_irpSimController.text) ?? 0.0;
      final mortgage = double.tryParse(_mortgageSimController.text) ?? 0.0;
      final hometown = double.tryParse(_hometownDonationSimController.text) ?? 0.0;
      final infertilityMed = double.tryParse(_infertilityMedicalController.text) ?? 0.0;
      final selfSeniorMed = double.tryParse(_selfSeniorDisabledMedicalController.text) ?? 0.0;
      final otherMed = double.tryParse(_otherDependentMedicalController.text) ?? 0.0;
      final donation = double.tryParse(_donationController.text) ?? 0.0;
      final childrenEdu = double.tryParse(_childrenEduController.text) ?? 0.0;
      final childrenEduCnt = int.tryParse(_childrenCountController.text) ?? 0;
      final collegeEdu = double.tryParse(_collegeEduController.text) ?? 0.0;
      final collegeEduCnt = int.tryParse(_collegeCountController.text) ?? 0;
      final result = CombinedTaxCalculator.calculateCombinedTax(
        grossIncome: salary,
        accumulatedFreelancerIncome: fIncome,
        inputMonths: months,
        occupationCode: _selectedOccupation!.code,
        creditCard: creditCard,
        debitCardAndCash: 0,
        traditionalMarket: 0,
        publicTransport: 0,
        cultureExpense: 0,
        allowanceCount: _dependentCount,
        decidedTax: 0,
        monthlyRent: monthlyRent,
        isHomeless: true, // 월세 입력자는 무주택 가정, 소득 요건은 엔진이 게이트
        yellowUmbrellaPayment: yellowUmbrella,
        pensionIncome: pensionIncome,
        otherIncome: otherIncome,
        insurancePremium: insurancePrem,
        childrenCount8Plus: children8Plus,
        newbornCount: newborns,
        pensionSavings: pensionSav,
        irpPayment: irpPay,
        hasElderly70Plus: _hasElderly70Plus,
        isSingleParent: _isSingleParent,
        isSingleFemaleHead: _isSingleFemaleHead,
        mortgageInterest: mortgage,
        hometownDonation: hometown,
        infertilityMedical: infertilityMed,
        selfSeniorDisabledMedical: selfSeniorMed,
        otherDependentMedical: otherMed,
        generalDonation: donation,
        childrenEdu: childrenEdu,
        childrenEduCount: childrenEduCnt,
        collegeEdu: collegeEdu,
        collegeEduCount: collegeEduCnt,
        weddingCredit2426: _weddingCredit2426,
        isSmeEmployee: _isSmeEmployee,
        smeStartYear: _smeStartYear,
        isYouthSme: _isYouthSme,
      );
      setState(() => _combinedResult = result);
    }
  }

  void _openOccupationSheet() async {
    final result = await OccupationSearchBottomSheet.show(context);
    if (result != null) {
      setState(() => _selectedOccupation = result);
      _calculateTax();
    }
  }

  /// 기장의무 판정 — 업종이 선택돼야 계산 가능. 규칙은 결정적이라 결과는 단정하되,
  /// 겸업(복수 업종)만 [BookkeepingJudgment.needsInputReview]로 입력 전제 확인을 유도한다.
  BookkeepingJudgment? get _bookkeepingJudgment {
    final occ = _selectedOccupation;
    if (occ == null) return null;
    final prior = int.tryParse(_priorYearIncomeController.text.replaceAll(',', '')) ?? 0;
    return judgeBookkeepingDuty(
      occupation: occ,
      priorYearIncome: prior,
      isNewBusiness: _isNewBusiness,
      hasMultipleBusinesses: _hasMultipleBusinesses,
    );
  }

  void _onBookkeepingInputChanged() {
    setState(() {});
    _saveBookkeepingProfile();
  }

  Future<void> _saveBookkeepingProfile() async {
    final updated = Map<String, dynamic>.from(_profileCache ?? {});
    updated['prior_year_income'] = double.tryParse(_priorYearIncomeController.text) ?? 0.0;
    updated['is_new_business'] = _isNewBusiness;
    updated['has_multiple_businesses'] = _hasMultipleBusinesses;
    _profileCache = updated;
    await dbService.saveProfile(updated);
  }

  /// 업종 선택 직후 노출되는 기장의무 판정 입력(직전연도 수입·신규·겸업) + 판정 배너.
  /// 업종 미선택 시 빈 리스트(아직 판정 불가).
  List<Widget> _buildBookkeepingJudgmentSection() {
    final judgment = _bookkeepingJudgment;
    if (judgment == null) return const [];
    final bodyColor = Theme.of(context).textTheme.bodyLarge!.color!;
    return [
      Text('직전연도 수입금액', style: TextStyle(color: bodyColor, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('작년 한 해 이 업종으로 번 총수입이에요. 기장의무(간편장부·복식부기) 판단에 쓰여요.',
          style: TextStyle(color: bodyColor.withOpacity(0.6), fontSize: 12)),
      const SizedBox(height: 8),
      TextField(
        controller: _priorYearIncomeController,
        keyboardType: TextInputType.number,
        style: TextStyle(color: bodyColor, fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: TextStyle(color: bodyColor.withOpacity(0.2), fontSize: 20),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          suffixText: '원',
          suffixStyle: TextStyle(color: bodyColor, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: Text('올해 처음 시작한 사업이에요', style: TextStyle(color: bodyColor, fontSize: 14, fontWeight: FontWeight.w600))),
        Switch(
          value: _isNewBusiness,
          onChanged: (v) {
            setState(() => _isNewBusiness = v);
            _saveBookkeepingProfile();
          },
          activeColor: Theme.of(context).scaffoldBackgroundColor,
          activeTrackColor: bodyColor,
          inactiveThumbColor: bodyColor.withOpacity(0.5),
          inactiveTrackColor: Theme.of(context).scaffoldBackgroundColor,
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text('다른 업종도 함께 하고 있어요 (겸업)', style: TextStyle(color: bodyColor, fontSize: 14, fontWeight: FontWeight.w600))),
        Switch(
          value: _hasMultipleBusinesses,
          onChanged: (v) {
            setState(() => _hasMultipleBusinesses = v);
            _saveBookkeepingProfile();
          },
          activeColor: Theme.of(context).scaffoldBackgroundColor,
          activeTrackColor: bodyColor,
          inactiveThumbColor: bodyColor.withOpacity(0.5),
          inactiveTrackColor: Theme.of(context).scaffoldBackgroundColor,
        ),
      ]),
      const SizedBox(height: 24),
      _buildJudgmentBanner(judgment),
      const SizedBox(height: 32),
    ];
  }

  /// 간편장부(가계부 실제경비) vs 추계(경비율) 비교 카드 — 유리한 쪽에 뱃지.
  Widget _buildBookkeepingComparisonCard() {
    final c = _bookkeepingComparison;
    if (c == null) return const SizedBox.shrink();
    final bodyColor = Theme.of(context).textTheme.bodyLarge!.color!;
    String fmt(double v) => v.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    Widget column(String label, double tax, bool isBetter) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: isBetter ? Border.all(color: AppTheme.accentColor(context), width: 1.4) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(label, style: TextStyle(color: bodyColor, fontSize: 13, fontWeight: FontWeight.w700))),
                  if (isBetter) AppTheme.blueprintBadge(context, '유리'),
                ]),
                const SizedBox(height: 10),
                Text('${fmt(tax)}원', style: TextStyle(color: bodyColor, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('결정세액(지방세 포함)', style: TextStyle(color: bodyColor.withOpacity(0.5), fontSize: 11)),
              ],
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('간편장부 vs 추계 비교', style: AppTheme.label(context)),
          const SizedBox(height: 4),
          Text(
            '가계부에 기록한 사업경비(${fmt(_businessExpenseAccumulated)}원)를 실제 경비로 인정받는 간편장부와, '
            '업종 경비율로 추정하는 추계 중 세금이 더 적은 쪽을 골랐어요.',
            style: TextStyle(color: bodyColor.withOpacity(0.6), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column('간편장부(실제경비)', c.bookkeeping.annualTotalTax, c.bookkeepingIsBetter),
              const SizedBox(width: 12),
              column('추계(경비율)', c.estimate.annualTotalTax, !c.bookkeepingIsBetter),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJudgmentBanner(BookkeepingJudgment j) {
    final bodyColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final isDouble = j.isDoubleEntry;
    final tone = isDouble ? AppTheme.colorDanger : AppTheme.colorSuccess;
    final title = isDouble ? '복식부기의무자예요' : '간편장부대상자예요';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withOpacity(0.4), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(isDouble ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: tone, size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: bodyColor, fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(j.reason, style: TextStyle(color: bodyColor.withOpacity(0.75), fontSize: 13, height: 1.5)),
          if (isDouble) ...[
            const SizedBox(height: 12),
            Text(
              '복식부기는 재무제표 수준의 장부가 필요해 세무사·기장대행과 함께 준비하는 걸 권장해요. '
              '이 앱의 간편장부·경비율 계산은 복식부기의무자에게는 적용되지 않아요.',
              style: TextStyle(color: bodyColor.withOpacity(0.75), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              '가계부에 기록해온 지출 내역은 세무사에게 그대로 전달해 기장 대행을 맡길 수 있어요.',
              style: TextStyle(color: bodyColor.withOpacity(0.6), fontSize: 12, height: 1.5),
            ),
          ],
          if (j.needsInputReview) ...[
            const SizedBox(height: 12),
            Text(
              '여러 업종을 겸업 중이면 주업종 환산 등 규칙이 복잡해요. 위 업종·수입 전제가 실제와 맞는지 확인해주세요.',
              style: TextStyle(color: bodyColor.withOpacity(0.6), fontSize: 12, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  void _showRentTooltipDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('🏠 월세 세액공제 꿀팁', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontWeight: FontWeight.bold)),
        content: Text(
          '새 계약서가 없어도 계좌이체 내역과 주민등록등본만 있으면 5월 종합소득세 때 최대 17%까지 똑같이 돌려받을 수 있어요!\n\n걱정 말고 매월 내는 월세 금액을 적어주세요.',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인했어요', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }

  Widget _buildAutoFilledBadge() {
    final accent = AppTheme.accentColor(context);
    return Row(
      children: [
        Icon(Icons.event_available_rounded, size: 12, color: accent),
        const SizedBox(width: 4),
        Text(_autoFillLabel, style: AppTheme.sans(12, accent, weight: FontWeight.w600)),
      ],
    );
  }

  /// 에디토리얼 입력 필드 — 라벨 + 헤어라인 밑줄 + 접미사. (앱 공통 톤)
  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? note,
    bool autoFilled = false,
    String suffix = '원',
    Widget? trailing,
  }) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(label, style: AppTheme.sans(14, ink, weight: FontWeight.w700, spacing: -0.2))),
          if (trailing != null) trailing,
        ]),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note, style: AppTheme.sans(12, sub, height: 1.4)),
        ],
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.lineStrong(context), width: 1.2))),
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: AppTheme.sans(22, ink, weight: FontWeight.w700, spacing: -0.5),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: AppTheme.sans(22, AppTheme.inkTertiary(context), weight: FontWeight.w300),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(suffix, style: AppTheme.sans(15, sub, weight: FontWeight.w600)),
          ]),
        ),
        if (autoFilled) ...[
          const SizedBox(height: 6),
          _buildAutoFilledBadge(),
        ],
      ],
    );
  }

  /// 연금소득 원천징수영수증[별지24(5)] PDF → 총연금액 자동 입력.
  Future<void> _pickPensionPdf() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (res == null) return;
      final bytes = res.files.single.bytes;
      if (bytes == null) {
        _toast('파일을 읽지 못했어요. 다시 선택해 주세요.');
        return;
      }
      final r = parsePensionText(extractPdfText(bytes));
      if (r.grossPension <= 0) {
        _toast('연금소득 원천징수영수증 PDF가 맞는지 확인해 주세요.');
        return;
      }
      // 합산 입력은 총연금액(공제 전). 콤마 없는 원시 숫자로 채워 _calculateTax와 호환.
      // text 설정이 리스너(_calculateTax)를 트리거해 합산이 자동 갱신된다.
      _pensionIncomeController.text = r.grossPension.toString();
      final f = NumberFormat('#,###');
      final settle = r.finalSettlement != 0
          ? ' · ${r.isRefund ? '환급' : '납부'} ${f.format(r.settlementAbs)}원'
          : '';
      _toast('총연금액 ${f.format(r.grossPension)}원을 불러왔어요$settle');
    } catch (_) {
      _toast('PDF를 분석하지 못했어요. 연금소득 원천징수영수증 PDF인지 확인해 주세요.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildSensitiveTextField(TextEditingController controller, String hint) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.line(context), width: 1))),
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: AppTheme.sans(15, ink, weight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: '0',
              hintStyle: AppTheme.sans(15, AppTheme.inkTertiary(context), weight: FontWeight.w300),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('원', style: AppTheme.sans(14, sub, weight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildCountTextField(TextEditingController controller) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.line(context), width: 1))),
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: AppTheme.sans(15, ink, weight: FontWeight.w700),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('명', style: AppTheme.sans(13, sub)),
      ]),
    );
  }

  Widget _buildTrafficLightBanner() {
    if (!_isEmployee) return const SizedBox.shrink();
    
    CreditCardDeductionResult? cardResult;
    if (!_isFreelancer) {
      cardResult = _employeeCardResult;
    } else if (_isFreelancer && _combinedResult != null) {
      cardResult = _combinedResult!.cardResult;
    }

    if (cardResult == null) return const SizedBox.shrink();

    String statusText;
    IconData icon;

    if (cardResult.totalSpend >= cardResult.threshold) {
      statusText = '🎉 25% 문턱 돌파!';
      icon = Icons.check_circle_outline;
    } else {
      statusText = '💡 공제 문턱 미달';
      icon = Icons.lightbulb_outline;
    }

    final passed = cardResult.totalSpend >= cardResult.threshold;
    final tone = passed ? AppTheme.colorSuccess : AppTheme.accentColor(context);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line(context), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusText, style: AppTheme.sans(14, AppTheme.ink(context), weight: FontWeight.w700, spacing: -0.2)),
                const SizedBox(height: 6),
                Text(cardResult.guideMessage, style: AppTheme.sans(13, AppTheme.inkSecondary(context), height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner() {
    if (_isFreelancer && !_isEmployee) {
      if (_freelancerResult == null) return const SizedBox.shrink();
      final r = _freelancerResult!;
      final isRefund = r.expectedRefundOrPayment >= 0;
      final amount = r.expectedRefundOrPayment.abs().toInt();
      return _renderBanner(isRefund, amount, r.reserveNudgeMessage);
    }
    
    if (_isEmployee && _isFreelancer) {
      if (_combinedResult == null) return const SizedBox.shrink();
      final r = _combinedResult!;
      final isRefund = r.expectedRefundOrPayment >= 0;
      final amount = r.expectedRefundOrPayment.abs().toInt();
      return _renderBanner(isRefund, amount, r.reserveNudgeMessage);
    }

    if (_isEmployee && !_isFreelancer) {
      if (_employeeTotalRefund <= 0 && (_employeeRentResult == null || _monthlyRentController.text.isEmpty || _monthlyRentController.text == '0')) {
        return const SizedBox.shrink();
      }
      return _buildEmployeeRefundBreakdown();
    }

    return const SizedBox.shrink();
  }

  Widget _renderBanner(bool isRefund, int amount, String message) {
    final tone = isRefund ? AppTheme.accentColor(context) : AppTheme.colorDanger;
    final amountStr = amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 24),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.lineStrong(context), width: 1.4),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRefund ? '5월 예상 환급액' : '5월 추가 납부 예상액',
            style: AppTheme.label(context),
          ),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(amountStr, style: AppTheme.serif(34, tone, spacing: -1.2, height: 1.0)),
            const SizedBox(width: 5),
            Text('원', style: AppTheme.sans(15, AppTheme.inkSecondary(context), weight: FontWeight.w600)),
          ]),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, height: 1.5),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildEmployeeRefundBreakdown() {
    final rentCredit = _employeeRentResult?.expectedRefund ?? 0.0;
    final medCredit = _specialDeductionResult?.medicalTaxCredit ?? 0.0;
    final donCredit = _specialDeductionResult?.donationTaxCredit ?? 0.0;
    final eduCredit = _specialDeductionResult?.educationTaxCredit ?? 0.0;
    final total = _employeeTotalRefund;
    final paidTax = double.tryParse(_paidTaxController.text) ?? 0.0;
    final isCapped = paidTax > 0 && (rentCredit + medCredit + donCredit + eduCredit) > paidTax;

    String fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('5월 종합소득세 추가 환급 예상', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (rentCredit > 0)
            _buildCreditRow('월세 세액공제', rentCredit),
          if (medCredit > 0)
            _buildCreditRow('의료비 세액공제', medCredit),
          if (donCredit > 0)
            _buildCreditRow('기부금 세액공제', donCredit),
          if (eduCredit > 0)
            _buildCreditRow('교육비 세액공제', eduCredit),
          const SizedBox(height: 12),
          Divider(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('예상 환급액', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.w700)),
              Text('${fmt(total)}원', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
          if (isCapped) ...[
            const SizedBox(height: 8),
            Text('* 기납부세액(${fmt(paidTax)}원) 초과분은 공제되지 않아요.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.6), fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildCreditRow(String label, double amount) {
    final fmt = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.8), fontSize: 14)),
          Text('$fmt원', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  bool _hasCalculatedResults() {
    if (_isFreelancer && !_isEmployee) return _freelancerResult != null;
    if (_isEmployee && _isFreelancer) return _combinedResult != null;
    if (_isEmployee && !_isFreelancer) return _employeeTotalRefund > 0 || _employeeRentResult != null;
    return false;
  }

  void _showReportForm() {
    String reportType = '종합소득세';
    List<Map<String, dynamic>> items = [];
    double finalAmount = 0.0;
    bool isRefund = false;

    if (_isFreelancer && !_isEmployee && _freelancerResult != null) {
      final r = _freelancerResult!;
      items = [
        {'title': '총수입금액 (연환산)', 'amount': r.annualEstimatedIncome, 'isHeader': true},
        {'title': '(-) 필요경비 (단순/기준경비율 적용)', 'amount': r.estimatedExpense},
        {'title': '(-) 소득공제 및 노란우산 등', 'amount': r.yellowUmbrellaDeduction},
        {'title': '(=) 과세표준', 'amount': r.taxBase, 'isHeader': true, 'highlight': true},
        {'title': '(×) 산출세액 (지방세 포함)', 'amount': r.annualIncomeTax + r.annualLocalTax},
        {'title': '(=) 결정세액', 'amount': r.annualTotalTax, 'isHeader': true, 'highlight': true},
        {'title': '(-) 기납부세액 (3.3%)', 'amount': r.annualEstimatedTotalWithholding},
      ];
      finalAmount = r.expectedRefundOrPayment;
      isRefund = finalAmount >= 0;
    } else if (_isEmployee && _isFreelancer && _combinedResult != null) {
      final r = _combinedResult!;
      items = [
        {'title': '근로소득금액', 'amount': r.laborIncomeAmount},
        {'title': '(+) 사업(프리랜서)소득금액', 'amount': r.estimatedFreelancerBusinessIncome},
        if (r.pensionIncomeAmount > 0)
          {'title': '(+) 연금소득금액', 'amount': r.pensionIncomeAmount},
        if (r.otherIncomeAmount > 0)
          {'title': '(+) 기타소득금액', 'amount': r.otherIncomeAmount},
        {'title': '(=) 종합소득금액', 'amount': r.totalGlobalIncome, 'isHeader': true},
        {'title': '(=) 과세표준', 'amount': r.taxBase, 'isHeader': true, 'highlight': true},
        {'title': '(×) 산출세액 (지방세 포함)', 'amount': r.annualIncomeTax + r.annualLocalTax},
        {'title': '(-) 기납부세액 합계', 'amount': r.annualEstimatedTotalWithholding},
      ];
      finalAmount = r.expectedRefundOrPayment;
      isRefund = finalAmount >= 0;
    } else if (_isEmployee && !_isFreelancer) {
      final r = _employeeRentResult;
      final s = _specialDeductionResult;
      if (r != null) items.add({'title': '월세 세액공제', 'amount': r.expectedRefund});
      if (s != null) {
        if (s.medicalTaxCredit > 0) items.add({'title': '의료비 세액공제', 'amount': s.medicalTaxCredit});
        if (s.donationTaxCredit > 0) items.add({'title': '기부금 세액공제', 'amount': s.donationTaxCredit});
        if (s.educationTaxCredit > 0) items.add({'title': '교육비 세액공제', 'amount': s.educationTaxCredit});
      }
      items.add({'title': '(=) 예상 환급액 합계', 'amount': _employeeTotalRefund, 'isHeader': true, 'highlight': true});
      finalAmount = _employeeTotalRefund;
      isRefund = true;
    }

    // ②진단 결과를 저장 → ③ 가상 신고서가 자동기입으로 채워짐
    if (items.isNotEmpty) {
      dbService.saveReportDraft(widget.userType,
          reportType: reportType, items: items, finalAmount: finalAmount, isRefund: isRefund);
    }

    Navigator.push(context, MaterialPageRoute(
      builder: (context) => TaxReportFormScreen(
        reportType: reportType,
        items: items,
        finalAmount: finalAmount,
        isRefund: isRefund,
      ),
    ));
  }

  void _onNextPressed() {
    if (_isFreelancer) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const ExpenseCalendarScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('직장인 데이터가 저장되었습니다! (직장인은 별도의 장부 작성이 필요하지 않습니다)'),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // 앱 배경색
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.inkSecondary(context)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.userType} 진단'.toUpperCase(), style: AppTheme.label(context)),
              const SizedBox(height: 12),
              Text('빠진 공제를 찾아\n돌려받을 세금 계산',
                  style: AppTheme.serif(28, AppTheme.ink(context), spacing: -0.5, height: 1.2)),
              const SizedBox(height: 10),
              Text('소득과 공제를 입력하면 5월 종합소득세로 돌려받을 금액을 계산해드려요.',
                  style: AppTheme.sans(14, AppTheme.inkSecondary(context), height: 1.55)),
              const SizedBox(height: 34),

              if (_isEmployee) ...[
                _field(
                  label: '세전 총급여 (연봉)',
                  controller: _salaryController,
                  hint: '예: 50,000,000',
                  note: '원천징수 전 세전 금액으로 입력해주세요.',
                  autoFilled: _incomeAutoFilled,
                ),
                const SizedBox(height: 28),

                _field(
                  label: '올해 신용카드 총 사용액',
                  controller: _creditCardController,
                  hint: '예: 15,000,000',
                  autoFilled: _creditAutoFilled,
                ),
                _buildTrafficLightBanner(),
                const SizedBox(height: 28),

                _field(
                  label: '매월 내는 월세액',
                  controller: _monthlyRentController,
                  hint: '예: 600,000',
                  autoFilled: _rentAutoFilled,
                  trailing: GestureDetector(
                    onTap: _showRentTooltipDialog,
                    behavior: HitTestBehavior.opaque,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.help_outline_rounded, size: 14, color: AppTheme.inkTertiary(context)),
                      const SizedBox(width: 4),
                      Text('자동 연장됐나요?', style: AppTheme.sans(12, AppTheme.inkSecondary(context), weight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(height: 28),

                // 기납부세액 입력
                _field(
                  label: '기납부 결정세액',
                  controller: _paidTaxController,
                  hint: '예: 1,200,000',
                  note: '회사가 연말정산 후 납부한 세액이에요. 원천징수영수증에서 확인하세요.',
                ),
                const SizedBox(height: 32),

                // 민감항목 공제 섹션 (토글)
                AppTheme.hairline(context),
                GestureDetector(
                  onTap: () => setState(() => _showSensitiveSection = !_showSensitiveSection),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('민감항목 추가 공제 신청', style: AppTheme.sans(15, AppTheme.ink(context), weight: FontWeight.w700, spacing: -0.2)),
                              const SizedBox(height: 4),
                              Text('의료비 · 기부금 · 교육비 (5월 종합소득세)', style: AppTheme.sans(12, AppTheme.inkSecondary(context))),
                            ],
                          ),
                        ),
                        Icon(_showSensitiveSection ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppTheme.inkTertiary(context)),
                      ],
                    ),
                  ),
                ),
                if (_showSensitiveSection) ...[
                  Container(
                    decoration: BoxDecoration(border: Border(left: BorderSide(color: AppTheme.lineStrong(context), width: 1.4))),
                    padding: const EdgeInsets.only(left: 16, top: 4, bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 의료비
                        Text('의료비 세액공제 (총급여의 3% 초과분)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Text('난임시술비 (공제율 30%)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_infertilityMedicalController, '예: 500,000'),
                        const SizedBox(height: 12),
                        Text('본인·65세이상·장애인 의료비 (공제율 15%)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_selfSeniorDisabledMedicalController, '예: 1,000,000'),
                        const SizedBox(height: 12),
                        Text('일반 부양가족 의료비 (공제율 15%, 700만원 한도)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_otherDependentMedicalController, '예: 2,000,000'),

                        Divider(height: 32, color: Theme.of(context).scaffoldBackgroundColor),

                        // 기부금
                        Text('기부금 세액공제', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('1,000만원 이하 15%, 초과분 30%', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.6), fontSize: 12)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_donationController, '예: 500,000'),

                        Divider(height: 32, color: Theme.of(context).scaffoldBackgroundColor),

                        // 교육비
                        Text('교육비 세액공제 (공제율 15%)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('유치원~고등학생 교육비', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text('1인당 300만원 한도', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.5), fontSize: 11)),
                                  const SizedBox(height: 6),
                                  _buildSensitiveTextField(_childrenEduController, '합산 금액'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 80,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('인원 수', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(' ', style: TextStyle(fontSize: 11)),
                                  const SizedBox(height: 6),
                                  _buildCountTextField(_childrenCountController),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('대학생 교육비', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text('1인당 900만원 한도', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.5), fontSize: 11)),
                                  const SizedBox(height: 6),
                                  _buildSensitiveTextField(_collegeEduController, '합산 금액'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 80,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('인원 수', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(' ', style: TextStyle(fontSize: 11)),
                                  const SizedBox(height: 6),
                                  _buildCountTextField(_collegeCountController),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],

              if (_isFreelancer) ...[
                Text('나의 프리랜서 업종코드', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _openOccupationSheet,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedOccupation != null
                                ? '${_selectedOccupation!.code} (${_selectedOccupation!.name})'
                                : '업종코드를 검색해주세요',
                            style: TextStyle(
                              color: _selectedOccupation != null ? Theme.of(context).textTheme.bodyLarge!.color! : Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.3),
                              fontSize: _selectedOccupation != null ? 16 : 18,
                              fontWeight: _selectedOccupation != null ? FontWeight.w600 : FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.search, color: Theme.of(context).textTheme.bodyLarge!.color!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                ..._buildBookkeepingJudgmentSection(),

                if (_bookkeepingJudgment == null || _bookkeepingJudgment!.isSimplified) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('현재까지 누적 수입', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _freelancerIncomeController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: '30,000,000',
                              hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.2), fontSize: 20),
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                              suffixText: '원',
                              suffixStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (_incomeAutoFilled) ...[
                            const SizedBox(height: 6),
                            _buildAutoFilledBadge(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('일한 개월 수', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _monthsController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: '12',
                              hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.2), fontSize: 20),
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                              suffixText: '개월',
                              suffixStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('* 3.3% 떼기 전 금액을 입력하세요.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 32),

                // N잡러 전용: 연금소득·기타소득 (선택 입력)
                if (_isEmployee && _isFreelancer) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('기타 합산소득 (선택)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('연금·기타소득이 있다면 5월 신고 시 합산됩니다.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.6), fontSize: 12)),
                        const SizedBox(height: 20),
                        Row(children: [
                          Expanded(
                            child: Text('총연금액 (국민연금·직역연금 수령액)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          GestureDetector(
                            onTap: _pickPensionPdf,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.accentColor(context), width: 1.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.upload_file_outlined, size: 13, color: AppTheme.accentColor(context)),
                                const SizedBox(width: 5),
                                Text('PDF로 불러오기', style: AppTheme.sans(12, AppTheme.accentColor(context), weight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text('연금소득공제 적용 후 종합소득에 합산됩니다. 원천징수영수증 PDF를 올리면 자동 입력돼요.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.5), fontSize: 11)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_pensionIncomeController, '예: 12,000,000'),
                        const SizedBox(height: 16),
                        Text('기타소득 총수입금액 (강사료·원고료·상금 등)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('필요경비 60% 공제 후 종합소득에 합산됩니다.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.5), fontSize: 11)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_otherIncomeController, '예: 5,000,000'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('소득공제 추가항목 (선택)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('과세표준을 낮춰 세금을 줄여줍니다. 없으면 비워두세요.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.6), fontSize: 12)),
                        const SizedBox(height: 20),
                        Text('주택담보대출 이자상환액 (연 최대 2,000만원 공제)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('15년 이상 고정금리·비거치식 기준', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.5), fontSize: 11)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_mortgageSimController, '예: 8,000,000'),
                        const SizedBox(height: 16),
                        Text('고향사랑기부금 (연 2,000만원 한도, 100% 과표차감)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_hometownDonationSimController, '예: 500,000'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('세액공제 (선택)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('보험료·자녀·연금저축은 5월 신고 시 추가 공제됩니다.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.6), fontSize: 12)),
                        const SizedBox(height: 20),
                        Text('보장성보험료 (12% 공제, 연 100만원 한도)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_insurancePremiumController, '예: 1,000,000'),
                        const SizedBox(height: 16),
                        Text('8세이상 자녀수 (자녀세액공제)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('첫째 25만 · 둘째 55만 · 셋째이상 1명당 40만', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.5), fontSize: 11)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            SizedBox(width: 100, child: _buildCountTextField(_childrenCount8PlusController)),
                            const SizedBox(width: 16),
                            Expanded(child: Text('출산·입양 자녀', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600))),
                            SizedBox(width: 100, child: _buildCountTextField(_newbornCountController)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('연금저축 납입액 (15% 공제, 연 600만 한도)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_pensionSavingsSimController, '예: 6,000,000'),
                        const SizedBox(height: 12),
                        Text('IRP / 퇴직연금 추가납입 (합산 900만 한도)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_irpSimController, '예: 3,000,000'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // 프리랜서 전용: 건강보험 지역가입자 소득공제
                if (!_isEmployee) ...[
                  Text('건강보험 지역가입자 보험료 (전액 소득공제)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('* 직장가입자가 아닌 경우, 납부한 건강보험료 전액이 소득공제됩니다.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _freelancerHealthInsController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.2), fontSize: 20),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      suffixText: '원',
                      suffixStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('노란우산공제 가입', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('사업소득 4천만 이하 최대 600만원 공제', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Switch(
                            value: _hasYellowUmbrella,
                            onChanged: (value) {
                              setState(() { _hasYellowUmbrella = value; });
                              _calculateTax();
                            },
                            activeColor: Theme.of(context).scaffoldBackgroundColor,
                            activeTrackColor: Theme.of(context).textTheme.bodyLarge!.color!,
                            inactiveThumbColor: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.5),
                            inactiveTrackColor: Theme.of(context).scaffoldBackgroundColor,
                          ),
                        ],
                      ),
                      if (_hasYellowUmbrella) ...[
                        const SizedBox(height: 20),
                        Divider(color: Theme.of(context).scaffoldBackgroundColor),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('올해 총 납입 예상액', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _yellowUmbrellaController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.2), fontSize: 18),
                            filled: true,
                            fillColor: Theme.of(context).scaffoldBackgroundColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            suffixText: '원',
                            suffixStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ],
              ],

              _buildBookkeepingComparisonCard(),
              _buildResultBanner(),
              
              const SizedBox(height: 16),
              if (_hasCalculatedResults()) ...[
                SimulatorTossButton(
                  text: '가상 신고서 양식 보기',
                  onTap: _showReportForm,
                ),
                const SizedBox(height: 12),
              ],
              // 토스 스타일 물리적 애니메이션이 들어간 햅틱 버튼
              SimulatorTossButton(
                text: '다음으로 넘어가기',
                onTap: _onNextPressed,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// 토스 스타일 스케일 애니메이션 버튼 컴포넌트
class SimulatorTossButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const SimulatorTossButton({super.key, required this.text, required this.onTap});

  @override
  State<SimulatorTossButton> createState() => _SimulatorTossButtonState();
}

class _SimulatorTossButtonState extends State<SimulatorTossButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).textTheme.bodyLarge!.color!, // 메인 강조 버튼은 화이트
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              color: Theme.of(context).scaffoldBackgroundColor, // 글씨는 앱 배경색으로 대비
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
