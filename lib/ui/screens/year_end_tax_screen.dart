import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/data/db_helper.dart';
import '../../core/tax_engine/employee_tax.dart';
import '../../core/tax_engine/tax_rates.dart';
import '../components/amount_field.dart';
import '../components/check_row.dart';
import 'tax_report_form_screen.dart';
import '../theme/text_wrap.dart';

class YearEndTaxScreen extends StatefulWidget {
  final String userType;
  final bool directWizardMode;

  const YearEndTaxScreen({super.key, required this.userType, this.directWizardMode = false});

  @override
  State<YearEndTaxScreen> createState() => _YearEndTaxScreenState();
}

class _YearEndTaxScreenState extends State<YearEndTaxScreen> {
  // 입력 상태 제어
  bool _isAnalyzed = false;
  final _numberFormat = NumberFormat('#,###');

  // 입력 필드 컨트롤러
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _creditCardController = TextEditingController();
  final TextEditingController _debitCardController = TextEditingController();
  final TextEditingController _paidTaxController = TextEditingController();

  // 프로필에서 로드하는 값
  int _dependentCount = 1;
  bool _isMonthlyRent = false;
  double _monthlyRent = 0.0;
  bool _isMarried = false;
  bool _isSpouseDependent = false;
  bool _hasSpouseDisability = false;
  bool _hasSelfDisability = false;
  int _disabledDependentCount = 0;
  bool _isHomeless = false;         // 무주택 세대주 여부 (is_monthly_rent 기반 proxy)
  double _insuranceDeduction = 0.0; // 4대보험 소득공제 (연금보험료 + 특별소득공제)
  double _specialInsuranceDeduction = 0.0; // 그중 특별소득공제분 (건강+장기요양+고용)
  // 장기주택저당차입금 한도 분기 (소법 §52⑥) — 계산기와 같은 두 조건을 묻는다.
  bool _mortgageFixedRate = false;
  bool _mortgageNonDeferred = false;
  bool _hasElderly70Plus = false;   // 경로우대 (70세 이상 부양가족)
  bool _isFemaleHead = false;       // 부녀자 추가공제
  bool _isSingleParent = false;     // 한부모 추가공제

  // 연말정산 wizard 상태
  bool _isInWizard = false;
  int _wizardStep = 0;
  bool _wizardDone = false;

  // 5월 신고서 Q&A 컨트롤러
  final TextEditingController _infertilityController = TextEditingController();
  final TextEditingController _selfSeniorDisabledController = TextEditingController();
  final TextEditingController _otherDependentMedicalController = TextEditingController();
  final TextEditingController _childrenEduController = TextEditingController();
  final TextEditingController _childrenCountController = TextEditingController();
  final TextEditingController _collegeEduController = TextEditingController();
  final TextEditingController _collegeCountController = TextEditingController();
  final TextEditingController _donationController = TextEditingController();
  final TextEditingController _wizardRentController = TextEditingController();

  // wizard 스텝 0: 자녀·혼인·연금 컨트롤러
  final TextEditingController _wizardChildrenCountController = TextEditingController(text: '0');
  bool _wizardMarried2426 = false;
  final TextEditingController _wizardPensionSavingsController = TextEditingController();
  final TextEditingController _wizardIrpController = TextEditingController();

  // wizard 스텝 2: 본인교육비·장애인특수교육비 컨트롤러
  final TextEditingController _selfEduController = TextEditingController();
  final TextEditingController _disabledSpecialEduController = TextEditingController();

  // wizard 스텝 4: 주담대·고향사랑기부금 컨트롤러
  final TextEditingController _mortgageController = TextEditingController();
  final TextEditingController _hometownDonationController = TextEditingController();
  double _wizardIncomeDedSaving = 0.0;

  // 중소기업취업자 감면
  bool _isSmeEmployee = false;
  int _smeStartYear = 0;
  double _smeExemption = 0.0;

  // 분석 결과 상태 변수
  double _laborDeduction = 0.0;        // 근로소득공제
  double _personalExemption = 0.0;     // 인적공제
  double _cardDeduction = 0.0;         // 신용카드 소득공제
  double _taxableIncome = 0.0;         // 과세표준
  double _calculatedTax = 0.0;         // 산출세액
  double _laborTaxCredit = 0.0;        // 근로소득세액공제
  double _rentRefund = 0.0;            // 월세 세액공제
  double _decidedTax = 0.0;            // 결정세액
  double _paidTax = 0.0;               // 기납부세액
  double _expectedRefund = 0.0;        // 예상 환급액 (양수=환급, 음수=추가납부)
  CreditCardDeductionResult? _cardResult;

  // 5월 신고서 추가 공제 결과
  double _additionalTaxCredit = 0.0;
  SpecialDeductionResult? _specialResult;
  double _wizardRentRefund = 0.0;
  double _wizardChildTaxCredit = 0.0;
  double _wizardMarriageTaxCredit = 0.0;
  double _wizardPensionTaxCredit = 0.0;
  double _wizardStandardTaxCredit = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.directWizardMode) {
      _isAnalyzed = true;
      _isInWizard = true;
    }
    _loadExistingData();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _creditCardController.dispose();
    _debitCardController.dispose();
    _paidTaxController.dispose();
    _infertilityController.dispose();
    _selfSeniorDisabledController.dispose();
    _otherDependentMedicalController.dispose();
    _childrenEduController.dispose();
    _childrenCountController.dispose();
    _collegeEduController.dispose();
    _collegeCountController.dispose();
    _donationController.dispose();
    _wizardRentController.dispose();
    _wizardChildrenCountController.dispose();
    _wizardPensionSavingsController.dispose();
    _wizardIrpController.dispose();
    _selfEduController.dispose();
    _disabledSpecialEduController.dispose();
    _mortgageController.dispose();
    _hometownDonationController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final profile = await dbService.getProfile();
    if (profile != null && mounted) {
      setState(() {
        final grossIncome = profile['gross_income'] as double? ?? 0.0;
        if (grossIncome > 0) {
          _salaryController.text = _numberFormat.format(grossIncome.toInt());
        }
        _dependentCount = profile['dependents'] as int? ?? 0;
        _isMonthlyRent = profile['is_monthly_rent'] == true;
        _monthlyRent = profile['monthly_rent'] as double? ?? 0.0;
        _isHomeless = _isMonthlyRent; // 월세 납부자 = 무주택 세대주 가정
        _isMarried = profile['is_married'] == true;
        _isSpouseDependent = profile['is_spouse_dependent'] == true;
        _hasSpouseDisability = profile['has_spouse_disability'] == true;
        _hasSelfDisability = profile['has_self_disability'] == true;
        _disabledDependentCount = profile['disabled_dependent_count'] as int? ?? 0;
        if (profile['has_disability'] == true && _disabledDependentCount == 0) {
          _disabledDependentCount = 1; // 구 버전 호환
        }
        _hasElderly70Plus = profile['has_elderly_70plus'] == true;
        _isFemaleHead = profile['is_female_head'] == true;
        _isSingleParent = profile['is_single_parent'] == true;
        _isSmeEmployee = profile['is_sme_employee'] == true;
        _smeStartYear = profile['sme_start_year'] as int? ?? 0;
        // 프로필에서 자녀수·혼인연도 자동 로드 (wizard 초기값)
        final childrenCountForCredit = profile['children_count_credit'] as int? ?? 0;
        if (childrenCountForCredit > 0) {
          _wizardChildrenCountController.text = childrenCountForCredit.toString();
        }
        final weddingYear = profile['wedding_year'] as int?;
        if (weddingYear != null && weddingYear >= 2024 && weddingYear <= 2026) {
          _wizardMarried2426 = true;
        }
      });
    }

    final expenses = await dbService.getExpenses(userType: widget.userType);
    if (expenses.isNotEmpty && mounted) {
      int creditTotal = 0;
      int debitTotal = 0;
      for (final exp in expenses) {
        if (exp.paymentMethod == '신용카드') {
          creditTotal += exp.amount;
        } else {
          debitTotal += exp.amount;
        }
      }
      setState(() {
        if (creditTotal > 0) {
          _creditCardController.text = _numberFormat.format(creditTotal);
        }
        if (debitTotal > 0) {
          _debitCardController.text = _numberFormat.format(debitTotal);
        }
      });
    }
  }

  // 내장 가상 파일 탐색기 및 온디바이스 로컬 파싱 시뮬레이션
  Future<void> _pickAndParseFile(String fileType) async {
    final isPdf = fileType == 'PDF';
    final mockFiles = isPdf 
      ? ['국세청_연말정산간소화_2025귀속.pdf', '원천징수영수증_2025_근로소득.pdf']
      : ['국세청_연말정산간소화_2025귀속.xlsx', '카드소비내역_2025.xlsx'];

    final selectedFile = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '기기 내부 $fileType 파일 선택'.keepWords,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Theme.of(context).textTheme.labelMedium!.color!),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...mockFiles.map((fileName) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isPdf ? Icons.picture_as_pdf_rounded : Icons.grid_on_rounded,
                    color: isPdf ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyLarge!.color!,
                  ),
                  title: Text(fileName, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14)),
                  trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).textTheme.labelMedium!.color!),
                  onTap: () => Navigator.pop(context, fileName),
                )).toList(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (selectedFile != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).primaryColor),
                  const SizedBox(height: 20),
                  Text(
                    selectedFile,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '로컬 온디바이스 엔진에서\n민감 정보 보호 하에 판독하고 있습니다.'.keepWords,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12, height: 1.4, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          );
        },
      );

      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        Navigator.pop(context);
      }

      setState(() {
        _salaryController.text = _numberFormat.format(55000000);
        _creditCardController.text = _numberFormat.format(18000000);
        _debitCardController.text = _numberFormat.format(4000000);
        _paidTaxController.text = _numberFormat.format(3960000);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('국세청 간소화 파일 ($selectedFile) 로컬 분석 완료!'.keepWords),
            backgroundColor: Theme.of(context).cardColor,
          ),
        );
      }
    }
  }

  // 세법 엔진 총동원 분석
  void _runAnalysis() {
    final salary = double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;
    final credit = double.tryParse(_creditCardController.text.replaceAll(',', '')) ?? 0.0;
    final debit = double.tryParse(_debitCardController.text.replaceAll(',', '')) ?? 0.0;
    _paidTax = double.tryParse(_paidTaxController.text.replaceAll(',', '')) ?? 0.0;

    if (salary <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('총급여를 입력해주세요.'), backgroundColor: Theme.of(context).cardColor),
      );
      return;
    }

    // 1. 근로소득공제
    _laborDeduction = EmployeeTaxCalculator.calculateLaborDeduction(salary);

    // 2. 인적공제 (본인 1명 + 부양가족 + 배우자)
    int totalDependents = 1 + _dependentCount;
    if (_isSpouseDependent) totalDependents += 1;
    _personalExemption = totalDependents * TaxRates.basicDeductionPerPerson;

    // 추가공제 (장애인 200만원)
    int totalDisabled = _disabledDependentCount;
    if (_hasSelfDisability) totalDisabled += 1;
    if (_hasSpouseDisability) totalDisabled += 1;

    _personalExemption += totalDisabled * 2000000;

    // 추가 인적공제 (경로우대/부녀자/한부모)
    _personalExemption += EmployeeTaxCalculator.calculateAdditionalPersonalDeduction(
      hasElderly70Plus: _hasElderly70Plus,
      isSingleFemaleHead: _isFemaleHead,
      isSingleParent: _isSingleParent,
      // 부녀자공제는 종합소득금액 3천만원 이하만 대상 (소법 §51①3).
      globalIncomeAmount: salary - EmployeeTaxCalculator.calculateLaborDeduction(salary),
    );

    // 3. 신용카드 소득공제
    _cardResult = EmployeeTaxCalculator.calculateCreditCardDeduction(
      grossIncome: salary,
      creditCard: credit,
      debitCardAndCash: debit,
      traditionalMarket: 0,
      publicTransport: 0,
      cultureExpense: 0,
    );
    _cardDeduction = _cardResult!.finalDeduction;

    // 4. 4대보험 소득공제 (연금보험료공제 §51의3 + 특별소득공제 보험료 §52①)
    final insDeduction = EmployeeTaxCalculator.calculateAnnualInsuranceDeduction(salary / 12);
    _insuranceDeduction = insDeduction.total;
    // 이 중 건강·장기요양·고용보험분만 '특별소득공제'(§52①)다. 표준세액공제를
    // 택하면 이쪽만 포기하고 국민연금 보험료공제(§51의3)는 그대로 남는다.
    _specialInsuranceDeduction = insDeduction.specialInsuranceDeduction;

    // 5. 과세표준 산출
    _taxableIncome = salary - _laborDeduction - _personalExemption - _cardDeduction - _insuranceDeduction;
    if (_taxableIncome < 0) _taxableIncome = 0;

    // 5. 산출세액
    _calculatedTax = TaxRates.calculateTax(_taxableIncome);

    // 6. 근로소득세액공제
    _laborTaxCredit = EmployeeTaxCalculator.calculateLaborTaxCredit(
      grossIncome: salary,
      calculatedTaxShare: _calculatedTax,
    );

    // 7. 월세 세액공제: 총급여 7천만·종합소득금액(근로소득금액) 6천만 이하·무주택 (조특법 §95의2)
    _rentRefund = 0.0;
    if (_isMonthlyRent && _monthlyRent > 0 && EmployeeTaxCalculator.isRentCreditEligible(
      grossIncome: salary,
      globalIncomeAmount: salary - _laborDeduction,
      isHomeless: _isHomeless,
    )) {
      final rentResult = EmployeeTaxCalculator.simulateRentRefund(
        grossIncome: salary,
        monthlyRent: _monthlyRent,
        decidedTax: _calculatedTax,
      );
      _rentRefund = rentResult.expectedRefund;
    }

    // 8. 결정세액 = 산출세액 - 중소기업감면 - 근로소득세액공제 - 월세세액공제
    _smeExemption = (_isSmeEmployee && _smeStartYear > 0)
        ? EmployeeTaxCalculator.calculateSmeExemption(calculatedTax: _calculatedTax, smeStartYear: _smeStartYear)
        : 0.0;
    // 감면을 받는 해에는 근로소득세액공제가 감면세액 비율만큼 깎인다
    // (국세청: 근로세액공제 × [1 - 감면세액/근로소득 산출세액]) — 둘 다 온전히
    // 빼면 이중 혜택이라 결정세액이 실제보다 낮게 나온다. 직장인은 근로소득뿐이라
    // 근로소득 산출세액이 곧 종합소득 산출세액이다.
    _laborTaxCredit = EmployeeTaxCalculator.laborTaxCreditAfterSmeExemption(
      laborTaxCredit: _laborTaxCredit,
      smeExemption: _smeExemption,
      laborCalculatedTax: _calculatedTax,
    );
    _decidedTax = _calculatedTax - _smeExemption - _laborTaxCredit - _rentRefund;
    if (_decidedTax < 0) _decidedTax = 0;
    _decidedTax = TaxRates.truncateWon(_decidedTax);

    // 9. 예상 환급액 = 기납부세액 - 결정세액
    _expectedRefund = _paidTax - _decidedTax;

    setState(() {
      _isAnalyzed = true;
    });
  }

  // 연말정산 결과를 기록부에 저장
  Future<void> _saveTaxRecord() async {
    final salary = double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;
    
    final record = {
      'record_year': DateTime.now().year,
      'record_type': '연말정산',
      'gross_income': salary,
      'refund_amount': _expectedRefund,
      'created_at': DateTime.now().toIso8601String(),
    };

    await dbService.insertTaxRecord(record);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('연말정산 기록부에 저장되었습니다. [전체] 탭에서 확인해보세요.'.keepWords),
          backgroundColor: Theme.of(context).primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).textTheme.bodyLarge!.color!),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('연말정산 진단', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _isInWizard
            ? (_wizardDone ? _buildWizardResultLayout() : _buildWizardLayout())
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _isAnalyzed ? _buildResultLayout() : _buildInputLayout(),
              ),
      ),
    );
  }

  // 1단계: 데이터 입력 레이아웃
  Widget _buildInputLayout() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        if (_isMarried)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_rounded, color: Theme.of(context).primaryColor, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '신혼이시라면 올해 혼인신고 시\n결혼특별세액공제(50만 원)를 받을 수 있는지 꼭 확인해 보세요!'.keepWords,
                    style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 13, height: 1.4, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        Text(
          '올해 연말정산 결과를\n미리 확인해 보세요.'.keepWords,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 22, fontWeight: FontWeight.w800, height: 1.4),
        ),
        const SizedBox(height: 24),
        
        // 파일 업로드 카드 리스트
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickAndParseFile('PDF'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Icon(Icons.picture_as_pdf_rounded, color: Theme.of(context).primaryColor, size: 36),
                      SizedBox(height: 8),
                      Text('PDF 파일 가져오기', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _pickAndParseFile('Excel'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Icon(Icons.grid_on_rounded, color: Theme.of(context).textTheme.bodyLarge!.color!, size: 36),
                      SizedBox(height: 8),
                      Text('엑셀 파일 가져오기', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Row(
            children: [
              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('또는 수기 입력', style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12)),
              ),
              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
            ],
          ),
        ),

        // 입력 폼
        _buildInlineFormInputField('총급여 (연봉)', _salaryController),
        const SizedBox(height: 16),
        _buildInlineFormInputField('신용카드 사용총액', _creditCardController),
        const SizedBox(height: 4),
        // 2026 귀속부터 학교·어린이집 수업료와 직업훈련 수강료는 카드공제 대상이
        // 아니다(조특령 §121의2). 카드 합계만으로는 앱이 가려낼 수 없어 알려준다.
        Text('학교·어린이집 수업료와 직업훈련 수강료는 2026년부터 카드공제 대상이 아니에요. 뺀 금액을 넣어주세요.'.keepWords,
            style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12, height: 1.4)),
        const SizedBox(height: 16),
        _buildInlineFormInputField('체크카드·현금영수증', _debitCardController),
        const SizedBox(height: 16),
        _buildInlineFormInputField('기납부세액 (원천징수)', _paidTaxController),
        
        const SizedBox(height: 40),
        
        GestureDetector(
          onTap: _runAnalysis,
          child: Container(
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Theme.of(context).textTheme.bodyLarge!.color!, borderRadius: BorderRadius.circular(16)),
            child: Text('연말정산 진단하기', style: TextStyle(color: Theme.of(context).scaffoldBackgroundColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, color: Theme.of(context).textTheme.labelMedium!.color!, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text('모든 데이터는 서버 전송 없이 기기 내부에만 저장됩니다.'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }

  // 2단계: 결과 레이아웃 — 예상 환급액/추가납부 + 공제 내역 + 놓친 공제
  Widget _buildResultLayout() {
    final salary = double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;
    final isRefund = _expectedRefund >= 0;
    final absAmount = _expectedRefund.abs().toInt();
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        // ── 핵심: 예상 환급액 / 추가납부액 ──
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isRefund ? Theme.of(context).primaryColor.withOpacity(0.3) : Color(0xFFFF4D4D).withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                isRefund ? Icons.savings_rounded : Icons.warning_amber_rounded,
                color: isRefund ? Theme.of(context).primaryColor : Color(0xFFFF4D4D),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                isRefund ? '예상 환급액' : '예상 추가납부액',
                style: TextStyle(
                  color: isRefund ? Theme.of(context).primaryColor : Color(0xFFFF4D4D),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_numberFormat.format(absAmount)}원',
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 36, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                isRefund
                    ? '원천징수로 낸 세금이 결정세액보다 많아요!'
                    : '결정세액이 기납부세액보다 많아 추가 납부가 필요해요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── 공제 항목별 적용 내역 ──
        Text('📋 공제 항목별 적용 내역', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              _buildDeductionRow('총급여', _numberFormat.format(salary.toInt()), false),
              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Theme.of(context).dividerColor)),
              _buildDeductionRow('근로소득공제', '-${_numberFormat.format(_laborDeduction.toInt())}', true),
              // 라벨은 본인을 포함해 센다. `_dependentCount`는 부양가족(본인 제외)이고
              // 공제액은 150만 × (본인 + 부양가족)이라, 그냥 "1인"이라 쓰면
              // 사용자가 1인당 300만원으로 읽는다.
              _buildDeductionRow('인적공제 (본인 포함 ${1 + _dependentCount}인)',
                  '-${_numberFormat.format(_personalExemption.toInt())}', true),
              _buildDeductionRow('4대보험 소득공제', '-${_numberFormat.format(_insuranceDeduction.toInt())}', true),
              _buildDeductionRow('신용카드 소득공제', '-${_numberFormat.format(_cardDeduction.toInt())}', true),
              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Theme.of(context).dividerColor)),
              _buildDeductionRow('과세표준', _numberFormat.format(_taxableIncome.toInt()), false),
              _buildDeductionRow('산출세액', _numberFormat.format(_calculatedTax.toInt()), false),
              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Theme.of(context).dividerColor)),
              if (_smeExemption > 0)
                _buildDeductionRow('중소기업취업자 감면', '-${_numberFormat.format(_smeExemption.toInt())}', true),
              _buildDeductionRow('근로소득세액공제', '-${_numberFormat.format(_laborTaxCredit.toInt())}', true),
              if (_rentRefund > 0)
                _buildDeductionRow('월세 세액공제', '-${_numberFormat.format(_rentRefund.toInt())}', true),
              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Theme.of(context).dividerColor)),
              _buildDeductionRow('결정세액', '${_numberFormat.format(_decidedTax.toInt())}원', false, isBold: true),
              _buildDeductionRow('기납부세액', '${_numberFormat.format(_paidTax.toInt())}원', false),
              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Theme.of(context).dividerColor)),
              _buildDeductionRow(
                isRefund ? '예상 환급' : '추가 납부',
                '${_numberFormat.format(absAmount)}원',
                false,
                isBold: true,
                highlightColor: isRefund ? Theme.of(context).primaryColor : Color(0xFFFF4D4D),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── 놓치고 있는 공제 안내 ──
        _buildMissingDeductionsCard(salary),

        const SizedBox(height: 24),

        // ── 5월 종합소득세 신고서 준비 CTA ──
        _buildTaxReportCtaCard(salary),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => TaxReportFormScreen(
                  reportType: '연말정산',
                  items: [
                    {'title': '총급여액 (수입금액)', 'amount': salary, 'isHeader': true},
                    {'title': '(-) 근로소득공제', 'amount': _laborDeduction},
                    {'title': '(-) 인적공제 (기본/추가)', 'amount': _personalExemption},
                    {'title': '(-) 4대보험 소득공제', 'amount': _insuranceDeduction},
                    {'title': '(-) 신용카드 등 특별공제', 'amount': _cardDeduction},
                    {'title': '(=) 과세표준', 'amount': _taxableIncome, 'isHeader': true, 'highlight': true},
                    {'title': '(×) 산출세액', 'amount': _calculatedTax},
                    if (_smeExemption > 0)
                      {'title': '(-) 중소기업취업자 소득세 감면', 'amount': _smeExemption},
                    {'title': '(-) 세액공제 (근로, 월세 등)', 'amount': _laborTaxCredit + _rentRefund},
                    {'title': '(=) 결정세액', 'amount': _decidedTax, 'isHeader': true, 'highlight': true},
                    {'title': '(-) 기납부세액', 'amount': _paidTax},
                  ],
                  finalAmount: _expectedRefund,
                  isRefund: _expectedRefund >= 0,
                ),
              ));
            },
            child: Text('신고서 양식으로 보기', style: TextStyle(color: Theme.of(context).scaffoldBackgroundColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _saveTaxRecord,
            child: Text('기록부에 저장하기', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _isAnalyzed = false),
          child: Text('다시 입력하기', style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 14)),
        ),
      ],
    );
  }

  // 놓친 공제 항목 안내 카드
  Widget _buildMissingDeductionsCard(double salary) {
    final List<Map<String, String>> missing = [];

    // 월세 세액공제 미적용 안내
    if (!_isMonthlyRent && salary <= 70000000) {
      missing.add({
        'title': '🏠 월세 세액공제',
        'desc': '월세를 내고 계시다면 최대 17%까지 돌려받을 수 있어요. 프로필에서 월세 정보를 등록해 보세요.',
      });
    }

    // 신용카드 문턱 미달 안내
    if (_cardResult != null && _cardResult!.totalSpend < _cardResult!.threshold) {
      final remaining = (_cardResult!.threshold - _cardResult!.totalSpend).toInt();
      missing.add({
        'title': '💳 신용카드 공제 문턱 미달',
        'desc': '총급여의 25%(${_numberFormat.format(_cardResult!.threshold.toInt())}원)까지 ${_numberFormat.format(remaining)}원 부족해요. 문턱을 넘어야 소득공제가 시작돼요.',
      });
    }

    // 의료비 안내
    missing.add({
      'title': '🏥 의료비 세액공제',
      'desc': '총급여의 3%(${_numberFormat.format((salary * 0.03).toInt())}원)를 초과한 의료비가 있다면 15% 공제를 받을 수 있어요.',
    });

    if (missing.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('💡 환급을 더 늘릴 수 있어요'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...missing.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['title']!, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(item['desc']!, style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 13, height: 1.4)),
            ],
          ),
        )).toList(),
      ],
    );
  }

  // 공제 내역 행 위젯
  Widget _buildDeductionRow(String label, String value, bool isDeduction, {bool isBold = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 금액은 절대 줄이지 않는다 — 라벨만 줄여서 넘침을 막는다.
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).textTheme.labelMedium!.color!,
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            isDeduction ? value : value,
            style: TextStyle(
              color: highlightColor ?? (isDeduction ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyLarge!.color!),
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// 라벨과 금액칸을 한 줄에 놓는 입력. (그리지 않던 hint 인자는 지웠다.)
  Widget _buildInlineFormInputField(String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          flex: 6,
          child: AmountField(controller: controller, expand: true),
        ),
      ],
    );
  }

  // ─── 5월 종합소득세 신고서 준비 CTA ───

  Widget _buildTaxReportCtaCard(double salary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.15),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_rounded, color: Theme.of(context).primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '종합소득세 신고서를 준비해드릴까요?'.keepWords,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '의료비·교육비·기부금 등 연말정산에서 빠진 공제 항목을 하나씩 확인하고, 5월 경정청구 신고서를 준비해드릴게요.'.keepWords,
            style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                _isInWizard = true;
                _wizardStep = 0;
                _wizardDone = false;
                _additionalTaxCredit = 0;
                _specialResult = null;
                _wizardRentRefund = 0;
                _wizardChildTaxCredit = 0;
                _wizardMarriageTaxCredit = 0;
                _wizardPensionTaxCredit = 0;
                _wizardMarried2426 = false;
                _wizardChildrenCountController.text = '0';
                _wizardPensionSavingsController.clear();
                _wizardIrpController.clear();
                _selfEduController.clear();
                _disabledSpecialEduController.clear();
                _mortgageController.clear();
                _hometownDonationController.clear();
                _wizardIncomeDedSaving = 0.0;
                _wizardStandardTaxCredit = 0.0;
              });
            },
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '네, 준비해주세요',
                style: TextStyle(color: Theme.of(context).scaffoldBackgroundColor, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Wizard 레이아웃 ───

  bool get _hasRentStep {
    final salary = double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;
    final double laborIncome = salary - EmployeeTaxCalculator.calculateLaborDeduction(salary);
    return _rentRefund == 0 && EmployeeTaxCalculator.isRentCreditEligible(
      grossIncome: salary,
      globalIncomeAmount: laborIncome,
      isHomeless: _isHomeless,
    );
  }

  int get _totalWizardSteps => _hasRentStep ? 6 : 5;

  Widget _buildWizardLayout() {
    return Column(
      children: [
        _buildWizardHeader(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: KeyedSubtree(
              key: ValueKey(_wizardStep),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [_buildWizardStepContent()],
              ),
            ),
          ),
        ),
        _buildWizardNavBar(),
      ],
    );
  }

  Widget _buildWizardHeader() {
    final stepLabels = _hasRentStep
        ? ['자녀·혼인·연금', '의료비', '교육비', '기부금', '주담대·고향사랑', '월세']
        : ['자녀·혼인·연금', '의료비', '교육비', '기부금', '주담대·고향사랑'];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 24, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).textTheme.bodyLarge!.color!, size: 20),
            onPressed: () {
              if (_wizardStep == 0) {
                setState(() => _isInWizard = false);
              } else {
                setState(() => _wizardStep--);
              }
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '누락 공제 확인 ${_wizardStep + 1}/${_totalWizardSteps} — ${stepLabels[_wizardStep]}'.keepWords,
                  style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_wizardStep + 1) / _totalWizardSteps,
                    backgroundColor: Theme.of(context).dividerColor,
                    color: Theme.of(context).primaryColor,
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWizardStepContent() {
    switch (_wizardStep) {
      case 0: return _buildWizardChildMarriagePension();
      case 1: return _buildWizardMedical();
      case 2: return _buildWizardEducation();
      case 3: return _buildWizardDonation();
      case 4: return _buildWizardMortgageHometown();
      case 5: return _buildWizardRent();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildWizardNavBar() {
    final isLast = _wizardStep == _totalWizardSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).dividerColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(0, 50),
              ),
              onPressed: () {
                if (isLast) {
                  _finishWizard();
                } else {
                  setState(() => _wizardStep++);
                }
              },
              child: Text('건너뛰기', style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(0, 50),
              ),
              onPressed: () {
                if (isLast) {
                  _finishWizard();
                } else {
                  setState(() => _wizardStep++);
                }
              },
              child: Text(
                isLast ? '계산하기' : '다음',
                style: TextStyle(color: Theme.of(context).scaffoldBackgroundColor, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Wizard Step 0: 자녀·혼인·연금 ───
  Widget _buildWizardChildMarriagePension() {
    final salary = double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;
    final int childCount = int.tryParse(_wizardChildrenCountController.text.replaceAll(',', '')) ?? 0;
    double previewChildCredit = TaxRates.calculateChildTaxCredit(childCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('👶 자녀·혼인·연금 공제를 확인할게요'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 6),
        Text(
          '연말정산에서 누락됐다면 5월 경정청구로 모두 돌려받을 수 있어요. 없으면 건너뛰세요.'.keepWords,
          style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 24),

        // 자녀세액공제
        Text('${TaxRates.childTaxCreditEligibilityLabel()} 기본공제 대상 자녀 수'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('첫째 25만 · 둘째 55만 · 셋째 이상 1명당 40만원 추가'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12)),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 100, child: _buildWizardCountField(_wizardChildrenCountController)),
            const SizedBox(width: 16),
            if (previewChildCredit > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '→ ${_numberFormat.format(previewChildCredit.toInt())}원 공제'.keepWords,
                  style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),

        Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Divider(color: Theme.of(context).dividerColor)),

        // 혼인세액공제
        Text('2024~2026년 혼인신고를 하셨나요?'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('생애 1회 50만원 세액공제 (이미 연말정산 적용 시 건너뛰기)'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12)),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildSelectChip('해당 없음', !_wizardMarried2426, () => setState(() => _wizardMarried2426 = false)),
            const SizedBox(width: 8),
            _buildSelectChip('해당됩니다', _wizardMarried2426, () => setState(() => _wizardMarried2426 = true)),
          ],
        ),

        Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Divider(color: Theme.of(context).dividerColor)),

        // 연금계좌 세액공제
        Text('연금저축·IRP 납입액을 확인할게요'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          salary <= 55000000
              ? '총급여 5,500만원 이하 → 15% 공제 (연금저축 최대 600만 + IRP 합산 900만 한도)'
              : '총급여 5,500만원 초과 → 12% 공제 (연금저축 최대 600만 + IRP 합산 900만 한도)',
          style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _buildWizardAmountField('연금저축 납입액', '최대 600만원 한도', _wizardPensionSavingsController),
        const SizedBox(height: 12),
        _buildWizardAmountField('IRP / 퇴직연금(DC) 추가 납입액', '예: 1,500,000', _wizardIrpController),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSelectChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).textTheme.bodyLarge!.color! : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Theme.of(context).textTheme.bodyLarge!.color! : Theme.of(context).dividerColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Theme.of(context).scaffoldBackgroundColor : Theme.of(context).textTheme.bodyLarge!.color!,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ─── Wizard Step 1: 의료비 ───
  Widget _buildWizardMedical() {
    final salary = double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;
    final threshold = (salary * 0.03).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('🏥 의료비 지출을 확인할게요', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 6),
        Text(
          '총급여의 3%(${_numberFormat.format(threshold)}원)를 초과한 의료비부터 공제됩니다. 없으면 건너뛰세요.'.keepWords,
          style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, color: Theme.of(context).primaryColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '회사에 알리기 꺼려 연말정산에서 제외하셨거나 깜빡하신 항목이 있으신가요?\n해당 항목만 5월에 직접 신고하면 회사로는 전달되지 않습니다.'.keepWords,
                  style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, height: 1.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildWizardAmountField('난임 시술비', '(30% 공제, 한도 없음)', _infertilityController),
        const SizedBox(height: 16),
        _buildWizardAmountField('본인·65세이상·장애인 의료비', '(15% 공제, 한도 없음)', _selfSeniorDisabledController),
        const SizedBox(height: 16),
        _buildWizardAmountField('일반 부양가족 의료비', '(15% 공제, 연 700만원 한도)', _otherDependentMedicalController),
      ],
    );
  }

  // ─── Wizard Step 2: 교육비 ───
  Widget _buildWizardEducation() {
    final bool hasDisability = _hasSelfDisability || _hasSpouseDisability || _disabledDependentCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('📚 교육비를 확인할게요', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 6),
        Text(
          '15% 공제율이 적용돼요. 없으면 건너뛰세요.'.keepWords,
          style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 24),
        Text('유치원~고등학생', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('자녀 수 · 교육비 합산 (1인당 300만원 한도)'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildWizardCountField(_childrenCountController)),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _buildWizardAmountFieldCompact(_childrenEduController)),
          ],
        ),
        const SizedBox(height: 20),
        Text('대학생', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('자녀 수 · 교육비 합산 (1인당 900만원 한도)'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildWizardCountField(_collegeCountController)),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _buildWizardAmountFieldCompact(_collegeEduController)),
          ],
        ),
        Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Divider(color: Theme.of(context).dividerColor)),
        Text('본인 교육비', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('대학원·직업훈련 포함, 한도 없음 · 15% 공제'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12)),
        const SizedBox(height: 10),
        _buildWizardAmountField('본인 교육비 합산', '수강료·등록금 전액', _selfEduController),
        if (hasDisability) ...[
          const SizedBox(height: 20),
          Text('장애인 특수교육비', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('장애인 재활교육비·특수교육기관 비용, 한도 없음 · 15% 공제'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12)),
          const SizedBox(height: 10),
          _buildWizardAmountField('장애인 특수교육비 합산', '재활교육비 전액', _disabledSpecialEduController),
        ],
      ],
    );
  }

  // ─── Wizard Step 3: 기부금 ───
  Widget _buildWizardDonation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('❤️ 기부금을 확인할게요', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 6),
        Text(
          '1,000만원 이하 15%, 초과분 30% 공제율이 적용돼요. 없으면 건너뛰세요.'.keepWords,
          style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 24),
        _buildWizardAmountField('기부금 합계', '종교·지정기부금 포함', _donationController),
      ],
    );
  }

  // ─── Wizard Step 4: 주택담보대출·고향사랑기부금 ───
  Widget _buildWizardMortgageHometown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('🏡 주담대·고향사랑을 확인할게요'.keepWords, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 6),
        Text(
          '소득공제 항목이에요. 과세표준을 낮춰 세금을 줄여줍니다. 없으면 건너뛰세요.'.keepWords,
          style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 24),
        _buildWizardAmountField('주택담보대출 이자상환액', '상환기간 15년 이상 대출 기준이에요.', _mortgageController),
        // 답에 따라 한도가 800만 → 2,000만으로 갈린다. 금액을 넣은 사람에게만 묻는다.
        if ((double.tryParse(_mortgageController.text.replaceAll(',', '')) ?? 0) > 0)
          MortgageConditionRows(
            fixedRate: _mortgageFixedRate,
            nonDeferred: _mortgageNonDeferred,
            onFixedRate: (v) => setState(() => _mortgageFixedRate = v),
            onNonDeferred: (v) => setState(() => _mortgageNonDeferred = v),
            limit: EmployeeTaxCalculator.mortgageDeductionLimit(
                fixedRate: _mortgageFixedRate,
                nonDeferredRepayment: _mortgageNonDeferred),
          ),
        const SizedBox(height: 20),
        _buildWizardAmountField('고향사랑기부금', '10만원까지 110분의 100 (소득세 9만 909원) · 초과분 세액공제 (연 2,000만원 한도)', _hometownDonationController),
      ],
    );
  }

  // ─── Wizard Step 5: 월세 (조건부) ───
  Widget _buildWizardRent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('🏠 월세를 확인할게요', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 6),
        Text(
          '회사에 알리기 꺼려 연말정산에서 누락한 경우, 5월 경정청구로 되돌려 받을 수 있어요. (총급여 5,500만원 이하 17% / 초과 15%)\n\n'
                  '집은 전용 85㎡ 이하이거나 시가 4억원 이하여야 해요. 2026년부터 기본공제 대상 자녀가 3명 이상이면 100㎡까지 넓어졌어요.'
              .keepWords,
          style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 24),
        _buildWizardAmountField('월 납부액', '월세 금액 (월 기준)', _wizardRentController),
      ],
    );
  }

  Widget _buildWizardAmountField(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.bold)),
        if (hint.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(hint, style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        // 금액에 따라 뒤따르는 질문이 열리고 닫히므로(주담대 조건 등) 입력마다 다시 그린다.
        AmountField(controller: controller, expand: true, onChanged: (_) => setState(() {})),
      ],
    );
  }

  /// 라벨·설명이 이미 위에 있는 자리에 쓰는 좁은 금액칸.
  /// (예전에는 label·hint를 인자로 받았지만 그리지 않아 지웠다.)
  Widget _buildWizardAmountFieldCompact(TextEditingController controller) =>
      AmountField(controller: controller, expand: true);

  /// 사람 수 칸. 라벨은 호출부 위쪽에 이미 있어 인자로 받지 않는다.
  Widget _buildWizardCountField(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: '0명',
        hintStyle: TextStyle(color: Theme.of(context).dividerColor),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        suffixText: '명',
        suffixStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!),
      ),
    );
  }

  // ─── Wizard 완료: 추가 공제 계산 ───

  void _finishWizard() {
    final salary = double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;

    final infertility = double.tryParse(_infertilityController.text.replaceAll(',', '')) ?? 0.0;
    final selfSenior = double.tryParse(_selfSeniorDisabledController.text.replaceAll(',', '')) ?? 0.0;
    final otherMedical = double.tryParse(_otherDependentMedicalController.text.replaceAll(',', '')) ?? 0.0;
    final childrenEdu = double.tryParse(_childrenEduController.text.replaceAll(',', '')) ?? 0.0;
    final childrenCount = int.tryParse(_childrenCountController.text.replaceAll(',', '')) ?? 0;
    final collegeEdu = double.tryParse(_collegeEduController.text.replaceAll(',', '')) ?? 0.0;
    final collegeCount = int.tryParse(_collegeCountController.text.replaceAll(',', '')) ?? 0;
    final selfEdu = double.tryParse(_selfEduController.text.replaceAll(',', '')) ?? 0.0;
    final disabledSpecialEdu = double.tryParse(_disabledSpecialEduController.text.replaceAll(',', '')) ?? 0.0;
    final donation = double.tryParse(_donationController.text.replaceAll(',', '')) ?? 0.0;
    final wizardRent = double.tryParse(_wizardRentController.text.replaceAll(',', '')) ?? 0.0;

    _specialResult = EmployeeTaxCalculator.calculateSpecialDeductions(
      grossIncome: salary,
      infertilityMedical: infertility,
      selfAndSeniorAndDisabledMedical: selfSenior,
      otherDependentMedical: otherMedical,
      childrenEduExpense: childrenEdu,
      childrenCount: childrenCount,
      collegeEduExpense: collegeEdu,
      collegeCount: collegeCount,
      selfEduExpense: selfEdu,
      disabledSpecialExpense: disabledSpecialEdu,
      generalDonation: donation,
      mortgageInterestExpense: 0,
    );

    // 월세 세액공제: 연말정산에서 이미 반영되지 않은 경우만 추가 (동일 자격 조건 재확인)
    _wizardRentRefund = 0.0;
    if (_rentRefund == 0 && EmployeeTaxCalculator.isRentCreditEligible(
      grossIncome: salary,
      globalIncomeAmount: salary - _laborDeduction,
      isHomeless: _isHomeless,
    )) {
      final effectiveRent = wizardRent > 0 ? wizardRent : (_isMonthlyRent ? _monthlyRent : 0.0);
      if (effectiveRent > 0) {
        final rentResult = EmployeeTaxCalculator.simulateRentRefund(
          grossIncome: salary,
          monthlyRent: effectiveRent,
          decidedTax: _decidedTax,
        );
        _wizardRentRefund = rentResult.expectedRefund;
      }
    }

    // 자녀세액공제 (소법 §59의2) — 대상 연령은 TaxRates.childTaxCreditMinAge
    final int wizardChildren = int.tryParse(_wizardChildrenCountController.text.replaceAll(',', '')) ?? 0;
    _wizardChildTaxCredit = TaxRates.calculateChildTaxCredit(wizardChildren);

    // 혼인세액공제 (2024~2026 혼인신고, 생애 1회 50만)
    _wizardMarriageTaxCredit = _wizardMarried2426 ? TaxRates.marriageTaxCredit : 0.0;

    // 연금계좌 세액공제 (연금저축 600만/합산 900만, 총급여 5500만 이하 15%·초과 12%)
    final double wizardPension = double.tryParse(_wizardPensionSavingsController.text.replaceAll(',', '')) ?? 0.0;
    final double wizardIrp = double.tryParse(_wizardIrpController.text.replaceAll(',', '')) ?? 0.0;
    _wizardPensionTaxCredit = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
      pensionSavingsPayment: wizardPension,
      retirementPensionPayment: wizardIrp,
      grossIncome: salary,
    );

    // 주담대 이자는 소득공제(과세표준 차감 → 세율 적용으로 절세액 산출).
    // 고향사랑기부금은 세액공제(조특법 §58)라 절세액이 곧 공제액이다 — 과거 이를
    // 소득공제로 처리해 저소득자에겐 과소·고소득자에겐 과대 계산됐다.
    final double mortgage = double.tryParse(_mortgageController.text.replaceAll(',', '')) ?? 0.0;
    final double hometown = double.tryParse(_hometownDonationController.text.replaceAll(',', '')) ?? 0.0;
    // 한도는 대출 조건에 따라 800만~2,000만원으로 갈린다 (소법 §52⑥).
    final double mortgageDeduction = EmployeeTaxCalculator.calculateMortgageIncomeDeduction(
      mortgage,
      fixedRate: _mortgageFixedRate,
      nonDeferredRepayment: _mortgageNonDeferred,
    );
    _wizardIncomeDedSaving =
        EmployeeTaxCalculator.calculateHometownDonationTaxCredit(hometown);
    if (mortgageDeduction > 0 && _taxableIncome > 0) {
      final double newBase =
          (_taxableIncome - mortgageDeduction).clamp(0.0, double.infinity);
      _wizardIncomeDedSaving += TaxRates.truncateWon(
        TaxRates.calculateTax(_taxableIncome) - TaxRates.calculateTax(newBase),
      );
    }

    // 표준세액공제(13만)와 특별공제는 함께 받을 수 없다 — 소득세법 §59의4⑨.
    //
    // 종전에는 특별세액공제 합계가 13만에 못 미치면 모자란 만큼을 그냥 얹어 줬다.
    // 그러면 특별세액공제가 없는 대부분의 직장인이 13만원을 공짜로 받는데, 실제로는
    // 보험료 특별소득공제(이미 과세표준에서 빠져 있다)를 포기해야 한다.
    // 포기해서 늘어나는 세금까지 빼고 나서야 표준이 유리한지 알 수 있다.
    final double specialTotal = (_specialResult?.medicalTaxCredit ?? 0) +
        (_specialResult?.educationTaxCredit ?? 0) +
        (_specialResult?.donationTaxCredit ?? 0) +
        _wizardRentRefund;
    final double forfeited = TaxRates.calculateTax(_taxableIncome + _specialInsuranceDeduction) -
        TaxRates.calculateTax(_taxableIncome);
    final double standardNet = EmployeeTaxCalculator.getStandardTaxCredit() - forfeited;
    _wizardStandardTaxCredit =
        standardNet > specialTotal ? TaxRates.truncateWon(standardNet - specialTotal) : 0.0;

    double total = specialTotal +
        _wizardStandardTaxCredit +
        _wizardChildTaxCredit +
        _wizardMarriageTaxCredit +
        _wizardPensionTaxCredit +
        _wizardIncomeDedSaving;

    // directWizardMode: 연말정산 결정세액 없이 진행하므로 cap 미적용
    if (!widget.directWizardMode && total > _decidedTax) total = _decidedTax;
    _additionalTaxCredit = total;

    setState(() => _wizardDone = true);
  }

  // ─── Wizard 완료 결과 화면 ───

  Widget _buildWizardResultLayout() {
    final totalRefund = _expectedRefund + _additionalTaxCredit;
    final sr = _specialResult;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        // AppBar 대체 헤더
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).textTheme.bodyLarge!.color!, size: 20),
              onPressed: () => setState(() { _wizardDone = false; _wizardStep = 0; }),
            ),
            Text('5월 종합소득세 신고서', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),

        // 총 예상 환급 카드
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              Icon(Icons.savings_rounded, color: Theme.of(context).primaryColor, size: 44),
              const SizedBox(height: 12),
              Text(
                widget.directWizardMode ? '5월 종합소득세 절세 예상액' : '5월 경정청구 추가 환급 예상액',
                style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '+${_numberFormat.format(_additionalTaxCredit.toInt())}원',
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 34, fontWeight: FontWeight.w900),
              ),
              if (!widget.directWizardMode) ...[
                const SizedBox(height: 4),
                Text(
                  '연말정산 환급(${_numberFormat.format(_expectedRefund.toInt())}원) + 추가 = 총 ${_numberFormat.format(totalRefund.toInt())}원'.keepWords,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12, height: 1.4),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),
        Text('📋 추가 공제 항목 내역', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              if (_wizardChildTaxCredit > 0)
                _buildDeductionRow('자녀세액공제', '-${_numberFormat.format(_wizardChildTaxCredit.toInt())}', true),
              if (_wizardMarriageTaxCredit > 0)
                _buildDeductionRow('혼인세액공제', '-${_numberFormat.format(_wizardMarriageTaxCredit.toInt())}', true),
              if (_wizardPensionTaxCredit > 0)
                _buildDeductionRow('연금계좌 세액공제', '-${_numberFormat.format(_wizardPensionTaxCredit.toInt())}', true),
              if (sr != null && sr.medicalTaxCredit > 0)
                _buildDeductionRow('의료비 세액공제', '-${_numberFormat.format(sr.medicalTaxCredit.toInt())}', true),
              if (sr != null && sr.educationTaxCredit > 0)
                _buildDeductionRow('교육비 세액공제', '-${_numberFormat.format(sr.educationTaxCredit.toInt())}', true),
              if (sr != null && sr.donationTaxCredit > 0)
                _buildDeductionRow('기부금 세액공제', '-${_numberFormat.format(sr.donationTaxCredit.toInt())}', true),
              if (_wizardRentRefund > 0)
                _buildDeductionRow('월세 세액공제', '-${_numberFormat.format(_wizardRentRefund.toInt())}', true),
              if (_wizardIncomeDedSaving > 0)
                _buildDeductionRow('주담대 소득공제·고향사랑 세액공제', '-${_numberFormat.format(_wizardIncomeDedSaving.toInt())}', true),
              if (_wizardStandardTaxCredit > 0)
                _buildDeductionRow('표준세액공제 (13만)', '-${_numberFormat.format(_wizardStandardTaxCredit.toInt())}', true),
              if (_wizardChildTaxCredit == 0 && _wizardMarriageTaxCredit == 0 &&
                  _wizardPensionTaxCredit == 0 && (sr?.medicalTaxCredit ?? 0) == 0 &&
                  (sr?.educationTaxCredit ?? 0) == 0 && (sr?.donationTaxCredit ?? 0) == 0 &&
                  _wizardRentRefund == 0 && _wizardIncomeDedSaving == 0 && _wizardStandardTaxCredit == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('추가 공제 항목이 없습니다.', style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 14)),
                ),
              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Theme.of(context).dividerColor)),
              _buildDeductionRow(
                '추가 환급 합계',
                '+${_numberFormat.format(_additionalTaxCredit.toInt())}원',
                false,
                isBold: true,
                highlightColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: Theme.of(context).primaryColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '5월 종합소득세 신고(경정청구)를 통해 연말정산에서 누락된 공제를 추가로 받을 수 있어요. 실제 신고 시 증빙 서류가 필요합니다.'.keepWords,
                  style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12, height: 1.45),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              final sr = _specialResult;
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => TaxReportFormScreen(
                  reportType: '5월 종합소득세',
                  items: [
                    if (!widget.directWizardMode)
                      {'title': '연말정산 결정세액', 'amount': _decidedTax, 'isHeader': true},
                    if (_wizardChildTaxCredit > 0)
                      {'title': '(-) 자녀세액공제', 'amount': _wizardChildTaxCredit},
                    if (_wizardMarriageTaxCredit > 0)
                      {'title': '(-) 혼인세액공제', 'amount': _wizardMarriageTaxCredit},
                    if (_wizardPensionTaxCredit > 0)
                      {'title': '(-) 연금계좌 세액공제', 'amount': _wizardPensionTaxCredit},
                    if (sr != null && sr.medicalTaxCredit > 0)
                      {'title': '(-) 의료비 세액공제', 'amount': sr.medicalTaxCredit},
                    if (sr != null && sr.educationTaxCredit > 0)
                      {'title': '(-) 교육비 세액공제', 'amount': sr.educationTaxCredit},
                    if (sr != null && sr.donationTaxCredit > 0)
                      {'title': '(-) 기부금 세액공제', 'amount': sr.donationTaxCredit},
                    if (_wizardRentRefund > 0)
                      {'title': '(-) 월세 세액공제', 'amount': _wizardRentRefund},
                    if (_wizardIncomeDedSaving > 0)
                      {'title': '(-) 주담대·고향사랑 절세액', 'amount': _wizardIncomeDedSaving},
                    if (_wizardStandardTaxCredit > 0)
                      {'title': '(-) 표준세액공제', 'amount': _wizardStandardTaxCredit},
                    {'title': '(=) 예상 절세액', 'amount': _additionalTaxCredit, 'isHeader': true, 'highlight': true},
                  ],
                  finalAmount: _additionalTaxCredit,
                  isRefund: true,
                ),
              ));
            },
            child: Text('신고서 양식으로 보기', style: TextStyle(color: Theme.of(context).scaffoldBackgroundColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            if (widget.directWizardMode) {
              Navigator.pop(context);
            } else {
              setState(() { _isInWizard = false; _wizardDone = false; });
            }
          },
          child: Text(
            widget.directWizardMode ? '돌아가기' : '연말정산 결과로 돌아가기',
            style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
