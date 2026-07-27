import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../core/data/occupation_data.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/deduction_options.dart';
import 'occupation_search_screen.dart';
import 'tax_tools_screen.dart';
import '../components/tax_pipeline_rail.dart';
import '../components/calc_disclaimer.dart';
import '../../core/parsing/pdf_text_extractor.dart';
import '../../core/parsing/pension_income_parser.dart';
import '../../core/parsing/freelancer_income_parser.dart';
import '../../core/parsing/withholding_parser.dart';
import '../../core/tax_engine/freelancer_tax.dart';
import '../../core/tax_engine/combined_tax.dart';
import '../../core/tax_engine/employee_tax.dart';
import '../../core/tax_engine/tax_rates.dart';
import '../../core/tax_engine/bookkeeping_duty.dart';
import 'expense_calendar_screen.dart';
import 'tax_report_form_screen.dart';

class TaxSimulatorScreen extends StatefulWidget {
  /// 공제 고르기(DeductionGateScreen)에서 고른 항목 id. 해당 입력 카드를 미리 펼친다.
  /// 고르지 않은 카드는 접힌 채로 두어, 자기와 무관한 입력을 훑지 않아도 되게 한다.
  final Set<String>? preOpened;

  final String userType;

  const TaxSimulatorScreen({
    super.key,
    required this.userType, this.preOpened,});

  @override
  State<TaxSimulatorScreen> createState() => _TaxSimulatorScreenState();
}

class _TaxSimulatorScreenState extends State<TaxSimulatorScreen> {
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _creditCardController = TextEditingController();
  final TextEditingController _monthlyRentController = TextEditingController();

  final TextEditingController _freelancerIncomeController = TextEditingController();
  // 기본값 12 — 이 화면은 5월 종합소득세 확정신고(완결된 연도 전체 소득) 준비용이라,
  // months=12이면 연환산 (income/12)*12=income 이 항등식이 되어 실제 연간 세액과 일치한다.
  // (연중 진행 추정은 가계부 적립 예상 카드가 별도로 담당.)
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
  /// 게이트에서 고른 항목. null이면 게이트를 거치지 않고 바로 들어온 것 —
  /// 그때는 '안 고른 항목' 안내를 띄우지 않는다(고른 적이 없으니 놓친 것도 없다).
  Set<String>? _gatePicks;
  bool _showSensitiveSection = false;
  // '(선택)' 카드 3개 — 기본 접힘(스크롤 압박 완화). 필요한 사람만 펼쳐 입력.
  bool _showOtherIncome = false;
  bool _showExtraDeduction = false;
  bool _showExtraCredit = false;

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
  final TextEditingController _childrenForCreditController = TextEditingController(text: '0');
  final TextEditingController _newbornCountController = TextEditingController(text: '0');
  final TextEditingController _pensionSavingsSimController = TextEditingController();
  final TextEditingController _irpSimController = TextEditingController();

  // 기장의무 판정 컨트롤러 — 직전연도 수입·신규사업자·겸업 (프로필에 영속 저장)
  final TextEditingController _priorYearIncomeController = TextEditingController();
  bool _isNewBusiness = false;
  bool _hasMultipleBusinesses = false;
  Map<String, dynamic>? _profileCache;

  // 기장 vs 추계 비교 (2단계) — 가계부 사업경비 누적 + 비교 결과.
  double _businessExpenseAccumulated = 0.0;
  BookkeepingComparison? _bookkeepingComparison;
  // 추계 쪽에 적용된 경비율(직전연도 수입 기준 강제 판정 결과) — 비교 카드 라벨용.
  bool _estimateUsesStandardRate = false;

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
    _applyGatePicks();
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
    _childrenForCreditController.addListener(_calculateTax);
    _newbornCountController.addListener(_calculateTax);
    _pensionSavingsSimController.addListener(_calculateTax);
    _irpSimController.addListener(_calculateTax);
    _childrenForCreditController.addListener(_saveChildrenForCreditToProfile);
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
    _applySavedPicks(profile);
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
    OccupationInfo? profileOccupation;
    if (profile != null) {
      final gross = profile['gross_income'] as double? ?? 0.0;
      if (gross > 0) {
        annualIncome = gross;
      } else {
        // 유형별로 필터링된 달력 기록 합산 — 다른 유형으로 기록한 소득이 섞이지 않도록
        // monthly_income_records(유형 미분리 캐시) 대신 income_entries를 직접 월별 합산한다.
        for (int m = 1; m <= 12; m++) {
          final monthEntries = await dbService.getIncomeEntriesForMonth(now.year, m, userType: widget.userType);
          annualIncome += monthEntries.fold(0.0, (a, e) => a + e.amount);
        }
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
      // 자녀 수는 적립·환급 계산에도 쓰이므로 프로필 값으로 미리 채운다.
      final savedChildrenForCredit = (profile['children_count_credit'] as int?) ?? 0;
      if (savedChildrenForCredit > 0 && _childrenForCreditController.text == '0') {
        _childrenForCreditController.text = savedChildrenForCredit.toString();
      }
      final profileOccCode = profile['occupation_code'] as String?;
      if (profileOccCode != null) profileOccupation = OccupationData.occupations[profileOccCode];
    }

    // 신용카드 연간 누적 (지출 달력 기록)
    final expenses = await dbService.getExpenses(userType: widget.userType);
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
      if (profileOccupation != null) _selectedOccupation = profileOccupation;
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
      // 업종코드 복원(레거시 N잡러 기록 전용) — 프로필의 occupation_code가 이제 단일 출처라
      // 이미 채워져 있으면 건드리지 않는다.
      if (_selectedOccupation == null) {
        final occCode = rec['occupationCode'] as String?;
        if (occCode != null && occCode.isNotEmpty) {
          final occ = OccupationData.occupations[occCode];
          if (occ != null) _selectedOccupation = occ;
        }
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
    _childrenForCreditController.dispose();
    _newbornCountController.dispose();
    _pensionSavingsSimController.dispose();
    _irpSimController.dispose();
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

      // 자녀세액공제·연금계좌세액공제·보장성보험료세액공제 — N잡러 계산(_isEmployee &&
      // _isFreelancer 분기)과 동일한 컨트롤러를 공유하는데, 과거엔 그 분기에서만 계산돼
      // 순수 직장인은 입력해도 예상환급액에 전혀 반영되지 않았다.
      final childrenForCredit = int.tryParse(_childrenForCreditController.text) ?? 0;
      final newborns = int.tryParse(_newbornCountController.text) ?? 0;
      final childCredit = EmployeeTaxCalculator.calculateChildTaxCredit(
        childrenCount: childrenForCredit,
        newbornCount: newborns,
      );
      final pensionSav = double.tryParse(_pensionSavingsSimController.text) ?? 0.0;
      final irpPay = double.tryParse(_irpSimController.text) ?? 0.0;
      final pensionCredit = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
        pensionSavingsPayment: pensionSav,
        retirementPensionPayment: irpPay,
        grossIncome: salary,
      );
      final insurancePrem = double.tryParse(_insurancePremiumController.text) ?? 0.0;
      final insuranceCredit = EmployeeTaxCalculator.calculateInsurancePremiumTaxCredit(
        generalInsurancePremium: insurancePrem,
        disabledInsurancePremium: 0,
      );

      // 주담대이자는 과세표준을 낮추는 소득공제라, 간이 과세표준을 근사 산출해
      // 절세액(세율 적용분 차이)으로 환산한다. 고향사랑기부금은 세액공제(조특법 §58)라
      // 공제액이 곧 절세액이다. (year_end_tax_screen.dart의 wizard와 동일한 방식.)
      final mortgage = double.tryParse(_mortgageSimController.text) ?? 0.0;
      final hometown = double.tryParse(_hometownDonationSimController.text) ?? 0.0;
      double incomeDedSaving =
          EmployeeTaxCalculator.calculateHometownDonationTaxCredit(hometown);
      if (mortgage > 0) {
        final laborDeduction = EmployeeTaxCalculator.calculateLaborDeduction(salary);
        final personalExemption = (1 + _dependentCount) * TaxRates.basicDeductionPerPerson;
        final insDeduction =
            EmployeeTaxCalculator.calculateAnnualInsuranceDeduction(salary / 12).total;
        final baseTaxable = (salary -
                laborDeduction -
                personalExemption -
                cResult.finalDeduction -
                insDeduction)
            .clamp(0.0, double.infinity);
        final mortgageDeduction = EmployeeTaxCalculator.calculateMortgageIncomeDeduction(mortgage);
        final newBase =
            (baseTaxable - mortgageDeduction).clamp(0.0, double.infinity);
        incomeDedSaving += TaxRates.truncateWon(
          TaxRates.calculateTax(baseTaxable) - TaxRates.calculateTax(newBase),
        );
      }

      final double totalCredit = rResult.expectedRefund
          + specialResult.medicalTaxCredit
          + specialResult.donationTaxCredit
          + specialResult.educationTaxCredit
          + childCredit
          + pensionCredit
          + insuranceCredit
          + incomeDedSaving;
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
      final judgment = _bookkeepingJudgment;

      // 추계 시 적용 경비율은 직전연도 수입 기준으로 강제된다(단순경비율 미대상이면
      // 기준경비율) — 세금 낮은 쪽을 고르는 선택 사항이 아님.
      final priorIncome = int.tryParse(_priorYearIncomeController.text.replaceAll(',', '')) ?? 0;
      final simpleRateEligible = isSimpleExpenseRateEligible(
        occupation: _selectedOccupation!,
        priorYearIncome: priorIncome,
        isNewBusiness: _isNewBusiness,
        currentYearIncome: (income / months) * 12,
      );

      if (judgment != null && judgment.isSimplified) {
        // 간편장부대상자 — 가계부 실제경비(기장) vs 경비율(추계) 중 유리한 쪽을 채택.
        final comparison = FreelancerTaxCalculator.compareBookkeepingVsEstimate(
          accumulatedIncome: income,
          accumulatedActualExpense: _businessExpenseAccumulated,
          inputMonths: months,
          allowanceCount: _dependentCount,
          occupationCode: _selectedOccupation!.code,
          yellowUmbrellaPayment: yellowUmbrella,
          childrenCountForCredit: int.tryParse(_childrenForCreditController.text) ?? 0,
          newbornCount: int.tryParse(_newbornCountController.text) ?? 0,
          disabledDependentCount: _disabledDependentCount,
          hasSelfDisability: _hasSelfDisability,
          forceStandardExpenseRate: !simpleRateEligible,
        );
        setState(() {
          _bookkeepingComparison = comparison;
          _estimateUsesStandardRate = !simpleRateEligible;
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
          childrenCountForCredit: int.tryParse(_childrenForCreditController.text) ?? 0,
          newbornCount: int.tryParse(_newbornCountController.text) ?? 0,
          disabledDependentCount: _disabledDependentCount,
          hasSelfDisability: _hasSelfDisability,
          useStandardExpenseRate: !simpleRateEligible,
        );
        setState(() {
          _bookkeepingComparison = null;
          _freelancerResult = result;
        });
      }
    }
    else if (_isEmployee && _isFreelancer) {
      final judgment = _bookkeepingJudgment;
      final isDoubleEntry = judgment != null && !judgment.isSimplified;
      if (_salaryController.text.isEmpty || _selectedOccupation == null) {
        setState(() => _combinedResult = null);
        return;
      }
      // 복식부기의무자는 사업소득 입력칸 자체를 숨기므로(경비율 계산 미적용),
      // 근로소득 입력만으로도 계산이 진행되게 이 조건만 예외로 둔다.
      if (_freelancerIncomeController.text.isEmpty && !isDoubleEntry) {
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
      final childrenForCredit = int.tryParse(_childrenForCreditController.text) ?? 0;
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
      final laborPaidTax = double.tryParse(_paidTaxController.text) ?? 0.0;
      // 부업 사업소득 추계 경비율도 직전연도 수입 기준으로 강제된다(프리랜서 분기와 동일).
      final priorIncome = int.tryParse(_priorYearIncomeController.text.replaceAll(',', '')) ?? 0;
      final simpleRateEligible = isSimpleExpenseRateEligible(
        occupation: _selectedOccupation!,
        priorYearIncome: priorIncome,
        isNewBusiness: _isNewBusiness,
        currentYearIncome: (fIncome / months) * 12,
      );
      final result = CombinedTaxCalculator.calculateCombinedTax(
        grossIncome: salary,
        accumulatedFreelancerIncome: fIncome,
        inputMonths: months,
        occupationCode: _selectedOccupation!.code,
        useStandardExpenseRate: !simpleRateEligible,
        creditCard: creditCard,
        debitCardAndCash: 0,
        traditionalMarket: 0,
        publicTransport: 0,
        cultureExpense: 0,
        allowanceCount: _dependentCount,
        decidedTax: laborPaidTax,
        monthlyRent: monthlyRent,
        isHomeless: true, // 월세 입력자는 무주택 가정, 소득 요건은 엔진이 게이트
        yellowUmbrellaPayment: yellowUmbrella,
        pensionIncome: pensionIncome,
        otherIncome: otherIncome,
        insurancePremium: insurancePrem,
        childrenCountForCredit: childrenForCredit,
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
    final result = await OccupationSearchScreen.show(context);
    if (result != null) {
      setState(() => _selectedOccupation = result);
      _calculateTax();
      // 프로필의 occupation_code에도 저장 — My Info 화면과 동일한 단일 출처라
      // 다음에 진단을 다시 열어도 업종이 유지된다.
      final updated = Map<String, dynamic>.from(_profileCache ?? {});
      updated['occupation_code'] = result.code;
      _profileCache = updated;
      await dbService.saveProfile(updated);
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

  /// 게이트에서 고른 항목이 든 카드만 펼친다.
  void _applyGatePicks() {
    final picks = widget.preOpened;
    if (picks == null) return;
    _gatePicks = Set.of(picks);
    _openCardsFor(_gatePicks!);
  }

  /// 게이트를 안 거치고 바로 들어왔어도, 지난번에 고른 게 있으면 그대로 쓴다.
  /// 저장된 적이 없으면 건드리지 않는다 — 고른 적이 없으면 놓친 것도 없다.
  void _applySavedPicks(Map<String, dynamic>? profile) {
    if (_gatePicks != null) return;
    final saved = (profile?['deduction_picks'] as String?) ?? '';
    if (saved.isEmpty) return;
    _gatePicks = saved.split(',').where((e) => e.isNotEmpty).toSet();
    _openCardsFor(_gatePicks!);
  }

  /// 고른 항목이 든 카드를 펼친다. 카드 구성이 바뀌면 여기만 고치면 된다.
  void _openCardsFor(Set<String> ids) {
    bool any(List<String> k) => k.any(ids.contains);
    if (any(['medical', 'education', 'donation'])) _showSensitiveSection = true;
    if (any(['hometown', 'mortgage'])) _showExtraDeduction = true;
    if (any(['insurance', 'pension', 'newborn'])) _showExtraCredit = true;
  }

  /// 입력칸의 금액. 되묻기 판단에 쓴다.
  double _amountOf(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '')) ?? 0;

  /// 한도를 넘거나 고율 항목이 섞일 때만 세부 입력을 연다.
  ///
  /// 측정(2026-07-27): 총액이 한도 아래면 어떻게 쪼개든 결과가 **0원** 달라진다.
  /// 넘을 때만 갈리므로(교육비 90만·연금 45만·의료비 24.75만) 그때만 묻는다.
  Widget _followUp(String note, {String? label, TextEditingController? controller}) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                border: Border(
                    left: BorderSide(color: AppTheme.accentColor(context), width: 2)),
              ),
              child: Text(note,
                  style: AppTheme.sans(12, AppTheme.ink(context), height: 1.45)),
            ),
            if (label != null && controller != null) ...[
              const SizedBox(height: 12),
              Text(label,
                  style: AppTheme.sans(13, AppTheme.ink(context), weight: FontWeight.w600)),
              const SizedBox(height: 6),
              _buildSensitiveTextField(controller, '0'),
            ],
          ],
        ),
      );

  /// 게이트에서 고르지 않은 항목 — 숨긴 대가로 손해가 나면 안 된다.
  List<DeductionOption> get _missedOptions {
    final picks = _gatePicks;
    if (picks == null) return const [];
    final gross = double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0;
    final rest = deductionOptions(userType: widget.userType, grossIncome: gross)
        .where((e) => !picks.contains(e.id))
        .toList();
    rest.sort((a, b) => b.maxCredit.compareTo(a.maxCredit));
    return rest;
  }

  /// 안 고른 항목을 결과 아래에 놓는다. 목록이 아니라 질문으로 쓴다 —
  /// "월세로 살아요"는 훑고 지나가도 걸리지만 "월세액"은 안 걸린다.
  Widget _missedDeductionsBlock() {
    final missed = _missedOptions;
    if (missed.isEmpty) return const SizedBox.shrink();
    final top = missed.take(3).toList();
    final ink = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);
    final fmt = NumberFormat('#,###');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 36),
        Text('혹시 이건 어떠세요'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 8),
        Text('고르지 않은 항목이에요. 해당되면 눌러서 입력하세요.',
            style: AppTheme.sans(12, AppTheme.inkSecondary(context), height: 1.5)),
        const SizedBox(height: 14),
        for (final o in top)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              _gatePicks!.add(o.id);
              _openCardsFor({o.id});
            }),
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.line(context), width: 1)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.label,
                            style: AppTheme.sans(14, ink, weight: FontWeight.w600, spacing: -0.2)),
                        const SizedBox(height: 2),
                        Text(o.basis,
                            style: AppTheme.sans(11.5, AppTheme.inkTertiary(context))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('+${fmt.format(o.maxCredit.round())}원',
                      style: AppTheme.sans(13, accent, weight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Icon(Icons.add_rounded, size: 16, color: accent),
                ],
              ),
            ),
          ),
        if (missed.length > top.length) ...[
          const SizedBox(height: 10),
          Text('이 밖에 ${missed.length - top.length}개가 더 있어요.',
              style: AppTheme.sans(12, AppTheme.inkTertiary(context))),
        ],
      ],
    );
  }

  /// 자녀세액공제 대상 자녀 수를 프로필에 남긴다 — 가계부 적립·환급 계산이 같은 값을 쓰도록.
  /// 이 화면에서만 들고 있으면 적립액이 자녀세액공제를 빼놓고 과대 추정한다.
  Future<void> _saveChildrenForCreditToProfile() async {
    final v = int.tryParse(_childrenForCreditController.text.trim()) ?? 0;
    final updated = Map<String, dynamic>.from(_profileCache ?? {});
    if ((updated['children_count_credit'] as int?) == v) return;
    updated['children_count_credit'] = v;
    // 총 자녀 수가 공제대상 수보다 적으면 앞뒤가 안 맞는다 — 최소한 같은 수로 올린다.
    final total = (updated['children_count_total'] as int?) ?? 0;
    if (total < v) updated['children_count_total'] = v;
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
            '업종 경비율로 추정하는 추계 중 세금이 더 적은 쪽을 골랐어요. '
            '추계에는 직전연도 수입 기준으로 ${_estimateUsesStandardRate ? '기준' : '단순'}경비율이 적용돼요.',
            style: TextStyle(color: bodyColor.withOpacity(0.6), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column('간편장부(실제경비)', c.bookkeeping.annualTotalTax, c.bookkeepingIsBetter),
              const SizedBox(width: 12),
              column('추계(${_estimateUsesStandardRate ? '기준' : '단순'}경비율)', c.estimate.annualTotalTax, !c.bookkeepingIsBetter),
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

  /// `_field`의 밑줄 입력부만 떼어낸 것 — 라벨/레이아웃을 직접 짜는 곳(2열 배치 등)에서
  /// 필드 시각 언어를 통일하기 위해 재사용한다(도면 스타일 헤어라인 밑줄).
  Widget _underlineInput(TextEditingController controller, {required String hint, String suffix = '원'}) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Container(
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
              hintText: hint,
              hintStyle: AppTheme.sans(22, AppTheme.inkTertiary(context), weight: FontWeight.w300),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(suffix, style: AppTheme.sans(15, sub, weight: FontWeight.w600)),
      ]),
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

  /// 사업소득 원천징수영수증([별지23]) PDF → 총수입금액 자동 입력.
  /// 구 "사업소득 기록하기" 화면의 PDF 가져오기를 진단에 흡수한 것 — 값은 그대로
  /// 진단 입력(누적 수입)에 채워 넣고, 소득금액·세액은 진단 엔진(경비율/기장 비교)이 재계산한다.
  Future<void> _pickFreelancerPdf() async {
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
      final r = parseFreelancerText(extractPdfText(bytes));
      if (r.grossIncome <= 0) {
        _toast('사업소득 원천징수영수증 PDF가 맞는지 확인해 주세요.');
        return;
      }
      _freelancerIncomeController.text = r.grossIncome.toString();
      final f = NumberFormat('#,###');
      _toast('총수입 ${f.format(r.grossIncome)}원을 불러왔어요');
    } catch (_) {
      _toast('PDF를 분석하지 못했어요. 사업소득 원천징수영수증 PDF인지 확인해 주세요.');
    }
  }

  /// 근로소득 원천징수영수증([별지24(1)]) PDF → 총급여·결정세액 자동 입력.
  /// N잡러가 근로분 자료를 ①진단에서 바로 채울 수 있게 함(구 "근로+사업 자료 기록하기"
  /// 화면의 근로 PDF 가져오기를 흡수).
  Future<void> _pickLaborWithholdingPdf() async {
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
      final w = parseWithholdingText(extractPdfText(bytes));
      if (w.grossSalary <= 0) {
        _toast('근로소득 원천징수영수증 PDF가 맞는지 확인해 주세요.');
        return;
      }
      _salaryController.text = w.grossSalary.toString();
      _paidTaxController.text = w.decidedTax.toString();
      final f = NumberFormat('#,###');
      _toast('총급여 ${f.format(w.grossSalary)}원을 불러왔어요');
    } catch (_) {
      _toast('PDF를 분석하지 못했어요. 근로소득 원천징수영수증 PDF인지 확인해 주세요.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// '(선택)' 카드 헤더 — 탭하면 본문 펼침/접힘(기본 접힘, 스크롤 압박 완화).
  Widget _optionalCardHeader(String title, String subtitle, bool expanded, VoidCallback onToggle) {
    final color = Theme.of(context).textTheme.bodyLarge!.color!;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: color.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppTheme.inkTertiary(context)),
        ],
      ),
    );
  }

  Widget _buildSensitiveTextField(TextEditingController controller, String hint,
      {Key? fieldKey}) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.line(context), width: 1))),
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Expanded(
          child: TextField(
            key: fieldKey,
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
      return Column(children: [_renderBanner(isRefund, amount, r.reserveNudgeMessage), const CalcDisclaimer()]);
    }

    if (_isEmployee && _isFreelancer) {
      if (_combinedResult == null) return const SizedBox.shrink();
      final r = _combinedResult!;
      final isRefund = r.expectedRefundOrPayment >= 0;
      final amount = r.expectedRefundOrPayment.abs().toInt();
      final judgment = _bookkeepingJudgment;
      final isDoubleEntry = judgment != null && !judgment.isSimplified;
      final message = isDoubleEntry
          ? '사업소득은 복식부기 대상이라 이 앱이 계산하지 않아요. 근로소득 관련 공제만 반영한 금액이에요 — 사업소득분은 세무사와 확인하세요.'
          : r.reserveNudgeMessage;
      return Column(children: [_renderBanner(isRefund, amount, message), const CalcDisclaimer()]);
    }

    if (_isEmployee && !_isFreelancer) {
      if (_employeeTotalRefund <= 0 && (_employeeRentResult == null || _monthlyRentController.text.isEmpty || _monthlyRentController.text == '0')) {
        return const SizedBox.shrink();
      }
      return Column(children: [_buildEmployeeRefundBreakdown(), const CalcDisclaimer()]);
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
                // 두 문장짜리 안내가 폭 기준으로 아무 데서나 잘려 넘어가지 않도록
                // 문장 경계('. ')에서 명시적으로 줄바꿈.
                message.replaceAll('. ', '.\n'),
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
      final judgment = _bookkeepingJudgment;
      final isDoubleEntry = judgment != null && !judgment.isSimplified;
      items = [
        {'title': '근로소득금액', 'amount': r.laborIncomeAmount},
        {
          'title': isDoubleEntry ? '(+) 사업(프리랜서)소득금액 (복식부기 — 세무사 계산 필요, 미포함)' : '(+) 사업(프리랜서)소득금액',
          'amount': r.estimatedFreelancerBusinessIncome,
        },
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
        userType: widget.userType,
      ),
    ));
  }

  /// 보조 경로 — 프리랜서·N잡러가 실제 사업경비를 가계부에 기록하러 가는 옆길.
  /// 기록이 쌓이면 기장(간편장부) vs 추계 비교가 정확해진다.
  void _openLedgerForExpenses() {
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TaxPipelineRail(
                labels: taxRailLabels(widget.userType),
                current: taxRailIndex(widget.userType, 'simulator'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                  trailing: _isFreelancer
                      ? GestureDetector(
                          onTap: _pickLaborWithholdingPdf,
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
                        )
                      : null,
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
                  note: '회사가 연말정산 후 납부한 세액이에요.\n원천징수영수증에서 확인하세요.',
                ),
                const SizedBox(height: 28),

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
                        Text('그 밖의 의료비 (공제율 15%)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_otherDependentMedicalController, '0',
                            fieldKey: const Key('medicalOtherField')),
                        // 700만 한도에 걸릴 때만 물어본다 — 그 아래에선 나눠도 결과가 같다.
                        if (_amountOf(_otherDependentMedicalController) > 7000000)
                          _followUp(
                              '700만원이 넘었어요. 본인·65세 이상·장애인 의료비는 한도가 없으니, '
                              '그만큼을 따로 적으면 더 돌려받아요.',
                              label: '그중 본인·65세 이상·장애인 의료비',
                              controller: _selfSeniorDisabledMedicalController),

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
                        // 초중고 한도(1인당 300만)에 걸릴 때만 대학 칸을 연다 —
                        // 그 아래에선 어느 칸에 넣든 공제액이 같다(측정 결과 0원 차이).
                        if (_amountOf(_childrenEduController) >
                            3000000 * (int.tryParse(_childrenCountController.text) ?? 1)
                                .clamp(1, 99)) ...[
                          _followUp(
                              '초·중·고 교육비는 1인당 300만원이 한도예요. 대학생 학비가 섞여 있다면 '
                              '따로 적어주세요 — 대학은 1인당 900만원까지 돼요.'),
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
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
              ],

              if (_isFreelancer) ...[
                Text('나의 프리랜서 업종코드', style: AppTheme.sans(14, AppTheme.ink(context), weight: FontWeight.w700, spacing: -0.2)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _openOccupationSheet,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.lineStrong(context), width: 1.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedOccupation != null
                                ? '${_selectedOccupation!.code} · ${_selectedOccupation!.name}'
                                : '업종코드를 검색해주세요',
                            style: _selectedOccupation != null
                                ? AppTheme.sans(15, AppTheme.ink(context), weight: FontWeight.w600, spacing: -0.2)
                                : AppTheme.sans(15, AppTheme.inkTertiary(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.search, size: 18, color: AppTheme.inkSecondary(context)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                ..._buildBookkeepingJudgmentSection(),

                if (_bookkeepingJudgment == null || _bookkeepingJudgment!.isSimplified) ...[
                // 일한 개월 수 입력은 제거 — 5월 확정신고는 연간 전체 소득 기준이라
                // 개월 수는 12로 고정(_monthsController 기본값 '12', 연환산이 항등식이 됨).
                Row(children: [
                  Expanded(child: Text('총 사업소득 (연간)', style: AppTheme.sans(14, AppTheme.ink(context), weight: FontWeight.w700, spacing: -0.2))),
                  GestureDetector(
                      onTap: _pickFreelancerPdf,
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
                const SizedBox(height: 8),
                _underlineInput(_freelancerIncomeController, hint: '0', suffix: '원'),
                if (_incomeAutoFilled) ...[
                  const SizedBox(height: 6),
                  _buildAutoFilledBadge(),
                ],
                const SizedBox(height: 8),
                Text('3.3% 떼기 전 금액을 입력하세요.', style: AppTheme.sans(12, AppTheme.inkSecondary(context), height: 1.4)),
                const SizedBox(height: 28),

                // 자녀세액공제(소법 §59의2)는 종합소득자 전원 대상이라 프리랜서도 받는다.
                if (!_isEmployee) ...[
                  Text('${TaxRates.childTaxCreditEligibilityLabel()} 자녀 수', style: AppTheme.sans(14, AppTheme.ink(context), weight: FontWeight.w700, spacing: -0.2)),
                  const SizedBox(height: 4),
                  Text('1명 25만 원, 2명 55만 원, 셋째부터 1명당 40만 원이\n세금에서 바로 빠져요.', style: AppTheme.sans(12, AppTheme.inkSecondary(context), height: 1.4)),
                  const SizedBox(height: 8),
                  _underlineInput(_childrenForCreditController, hint: '0', suffix: '명'),
                  const SizedBox(height: 20),
                  Text('올해 출산·입양한 자녀 수', style: AppTheme.sans(14, AppTheme.ink(context), weight: FontWeight.w700, spacing: -0.2)),
                  const SizedBox(height: 4),
                  Text('첫째 30만 원, 둘째 50만 원, 셋째부터 70만 원이 위 금액에\n더해져요. 출산·입양한 해에만 받을 수 있어요.', style: AppTheme.sans(12, AppTheme.inkSecondary(context), height: 1.4)),
                  const SizedBox(height: 8),
                  _underlineInput(_newbornCountController, hint: '0', suffix: '명'),
                  const SizedBox(height: 28),
                ],

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.getCardDecoration(context),
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

                // N잡러 전용: 연금소득·기타소득 등 — 근로소득 관련 항목이라 사업분
                // 기장의무 판정(복식부기)과 무관하게 항상 노출한다("기장/추계는 사업분에만").
                if (_isEmployee && _isFreelancer) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.getCardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _optionalCardHeader('기타 합산소득 (선택)', '연금·기타소득이 있다면 5월 신고 시 합산됩니다.', _showOtherIncome, () => setState(() => _showOtherIncome = !_showOtherIncome)),
                        if (_showOtherIncome) ...[
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
                      ],
                    ),
                  ),
                ],
              ],

              // 직장인 공통(N잡러 포함): 연말정산에서 흔히 쓰는 소득·세액공제 카드.
              // 과거엔 이 두 카드가 if (_isFreelancer) 블록 안에 갇혀 있어 순수
              // 직장인은 입력 자체가 불가능했다(①진단 예상환급액이 과소 계산됨).
              if (_isEmployee) ...[
                const SizedBox(height: 16),
                Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.getCardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _optionalCardHeader('소득공제 추가항목 (선택)', '과세표준을 낮춰 세금을 줄여줍니다. 없으면 비워두세요.', _showExtraDeduction, () => setState(() => _showExtraDeduction = !_showExtraDeduction)),
                        if (_showExtraDeduction) ...[
                        const SizedBox(height: 20),
                        Text('주택담보대출 이자상환액 (연 최대 2,000만원 공제)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('15년 이상 고정금리·비거치식 기준', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.5), fontSize: 11)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_mortgageSimController, '예: 8,000,000'),
                        const SizedBox(height: 16),
                        Text('고향사랑기부금 (10만원까지 전액 환급, 초과분 세액공제)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_hometownDonationSimController, '예: 500,000'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.getCardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _optionalCardHeader(
                            '세액공제 (선택)',
                            _isFreelancer
                                ? '보험료·자녀·연금저축은 5월 신고 시 추가 공제됩니다.'
                                : '보험료·자녀·연금저축 등 놓치기 쉬운 세액공제 항목이에요.',
                            _showExtraCredit,
                            () => setState(() => _showExtraCredit = !_showExtraCredit)),
                        if (_showExtraCredit) ...[
                        const SizedBox(height: 20),
                        Text('보장성보험료 (12% 공제, 연 100만원 한도)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_insurancePremiumController, '예: 1,000,000'),
                        const SizedBox(height: 16),
                        Text('${TaxRates.childTaxCreditEligibilityLabel()} 자녀수 (자녀세액공제)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('첫째 25만 · 둘째 55만 · 셋째이상 1명당 40만', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.5), fontSize: 11)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            SizedBox(width: 100, child: _buildCountTextField(_childrenForCreditController)),
                            const SizedBox(width: 16),
                            Expanded(child: Text('출산·입양 자녀', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600))),
                            SizedBox(width: 100, child: _buildCountTextField(_newbornCountController)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('연금저축 납입액 (15% 공제, 연 600만 한도)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        _buildSensitiveTextField(_pensionSavingsSimController, '0',
                            fieldKey: const Key('pensionSavingsField')),
                        // 연금저축 한도(600만)를 넘길 때만 IRP를 묻는다 — 그 아래에선
                        // 어디에 넣었든 공제액이 같다.
                        if (_amountOf(_pensionSavingsSimController) > 6000000)
                          _followUp(
                              '연금저축은 600만원이 한도예요. 넘는 금액을 IRP·퇴직연금으로 넣으면 '
                              '합쳐서 900만원까지 공제돼요.',
                              label: 'IRP·퇴직연금(DC) 납입액',
                              controller: _irpSimController),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
              ],

              _buildBookkeepingComparisonCard(),
              _buildResultBanner(),

              // 안 고른 항목은 **주 CTA 앞**에 둔다. 버튼 뒤에 두면 누르고 나가버려
              // 숨긴 대가로 손해가 난다.
              _missedDeductionsBlock(),

              const SizedBox(height: 16),
              // 주 CTA — 파이프라인 ②가상신고서로. 계산 결과가 있어야 의미가 있어 게이트.
              // 주 CTA — 파이프라인 다음 단계(②가상신고서). 계산 결과가 아직 없어도 항상
              // 노출한다(과거엔 결과 없으면 숨겨져 가계부 버튼만 남아 앞으로 갈 길이 안 보였음).
              SimulatorTossButton(
                text: '가상 신고서로 넘어가기',
                onTap: _showReportForm,
              ),
              const SizedBox(height: 12),
              // 보조 경로(프리랜서·N잡러) — 실제 경비를 가계부에 기록하면 기장 vs 추계 비교가
              // 정확해진다. 파이프라인 옆길이라 채움 버튼이 아닌 테두리 버튼으로 위계를 낮춤.
              if (_isFreelancer) ...[
                GestureDetector(
                  onTap: _openLedgerForExpenses,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.lineStrong(context), width: 1.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('가계부에 경비 기록하기',
                        style: AppTheme.sans(15, AppTheme.ink(context), weight: FontWeight.w700, spacing: -0.2)),
                  ),
                ),
                const SizedBox(height: 8),
                Text('실제 사업경비를 기록하면 기장 vs 추계 비교가 더 정확해져요.',
                    style: AppTheme.sans(12, AppTheme.inkSecondary(context), height: 1.4)),
              ],
              const SizedBox(height: 40),
            ],
          ),
              ),
            ),
          ],
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
