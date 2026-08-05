import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../../core/data/db_helper.dart';
import '../../core/tax_engine/employee_tax.dart';
import '../../core/tax_engine/tax_rates.dart';
import 'tax_simulator_screen.dart';
import 'tax_tools_screen.dart';
import '../theme/app_theme.dart';
import '../components/tax_pipeline_rail.dart';
import '../theme/text_wrap.dart';

class TaxAnnualReportScreen extends StatefulWidget {
  final String userType;
  const TaxAnnualReportScreen({super.key, required this.userType});

  @override
  State<TaxAnnualReportScreen> createState() => _TaxAnnualReportScreenState();
}

class _TaxAnnualReportScreenState extends State<TaxAnnualReportScreen> {
  final _fmt = NumberFormat('#,###');
  bool _isLoading = true;
  final int _year = DateTime.now().year;

  // ── 프리랜서·N잡러(사업소득 분) 전용 — ①진단에서 저장한 가상 신고서를
  // 그대로 재사용해 홈택스 화면 순서대로 숫자를 안내한다. 직장인은 아래
  // 연말정산 재계산 UI를 그대로 쓴다.
  bool get _isBusiness => widget.userType != '직장인';
  Map<String, dynamic>? _businessDraft;

  // ── 자동 수집 데이터 ──
  double _grossIncome = 0.0;
  int _dependentCount = 1;
  bool _isMonthlyRent = false;
  double _monthlyRent = 0.0;
  bool _isHomeless = false;
  double _annualCreditCard = 0.0;
  double _annualDebitCash = 0.0;

  // ── 수동 입력 컨트롤러 ──
  final _grossIncomeCtrl = TextEditingController();
  final _pensionSavingsCtrl = TextEditingController();
  final _retirementPensionCtrl = TextEditingController();
  final _generalInsuranceCtrl = TextEditingController();
  final _disabledInsuranceCtrl = TextEditingController();
  final _childrenCountCtrl = TextEditingController(text: '0');
  final _newbornCountCtrl = TextEditingController(text: '0');
  final _mortgageCtrl = TextEditingController();
  final _medicalSelfCtrl = TextEditingController();
  final _medicalOtherCtrl = TextEditingController();
  final _donationCtrl = TextEditingController();
  final _politicalDonationCtrl = TextEditingController();

  // ── 섹션 확장 상태 ──
  final Set<String> _expanded = {};

  // ── 계산 결과 ──
  double _laborDeduction = 0.0;
  double _personalExemption = 0.0;
  double _insuranceDeduction = 0.0;
  double _creditCardDeduction = 0.0;
  double _mortgageDeduction = 0.0;
  double _taxableIncome = 0.0;
  double _calculatedTax = 0.0;
  double _laborTaxCredit = 0.0;
  double _childTaxCredit = 0.0;
  double _pensionCredit = 0.0;
  double _insurancePremiumCredit = 0.0;
  double _medicalCredit = 0.0;
  double _donationCredit = 0.0;
  double _rentCredit = 0.0;
  double _decidedTaxResult = 0.0;

  List<TextEditingController> get _allControllers => [
    _grossIncomeCtrl, _pensionSavingsCtrl, _retirementPensionCtrl,
    _generalInsuranceCtrl, _disabledInsuranceCtrl, _childrenCountCtrl,
    _newbornCountCtrl, _mortgageCtrl, _medicalSelfCtrl, _medicalOtherCtrl,
    _donationCtrl, _politicalDonationCtrl,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    for (final ctrl in _allControllers) {
      ctrl.addListener(_calculate);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _allControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isBusiness) {
      _businessDraft = await dbService.getReportDraft(widget.userType);
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final profile = await dbService.getProfile();
      if (profile != null) {
        _grossIncome = profile['gross_income'] as double? ?? 0.0;
        _dependentCount = profile['dependents'] as int? ?? 1;
        _isMonthlyRent = profile['is_monthly_rent'] == true;
        _monthlyRent = profile['monthly_rent'] as double? ?? 0.0;
        _isHomeless = _isMonthlyRent;
        if (_grossIncome > 0) {
          _grossIncomeCtrl.text = _grossIncome.toInt().toString();
        }
      }

      // 연간 지출 합산 (지출 달력 + expenses 테이블)
      final expenses = await dbService.getExpenses(userType: widget.userType);
      double credit = 0.0;
      double debit = 0.0;
      for (final e in expenses) {
        if (e.date.year == _year) {
          if (e.paymentMethod == '신용카드') {
            credit += e.amount;
          } else {
            debit += e.amount;
          }
        }
      }
      _annualCreditCard = credit;
      _annualDebitCash = debit;
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
      _calculate();
    }
  }

  void _calculate() {
    final gross = double.tryParse(_grossIncomeCtrl.text.replaceAll(',', '')) ?? 0.0;
    if (gross <= 0) {
      setState(() {});
      return;
    }

    // 소득공제
    _laborDeduction = EmployeeTaxCalculator.calculateLaborDeduction(gross);
    _personalExemption = _dependentCount * TaxRates.basicDeductionPerPerson;

    final insDeduction = EmployeeTaxCalculator.calculateAnnualInsuranceDeduction(gross / 12);
    _insuranceDeduction = insDeduction.total;

    final cardResult = EmployeeTaxCalculator.calculateCreditCardDeduction(
      grossIncome: gross,
      creditCard: _annualCreditCard,
      debitCardAndCash: _annualDebitCash,
      traditionalMarket: 0,
      publicTransport: 0,
      cultureExpense: 0,
    );
    _creditCardDeduction = cardResult.finalDeduction;

    _mortgageDeduction = EmployeeTaxCalculator.calculateMortgageIncomeDeduction(
      double.tryParse(_mortgageCtrl.text.replaceAll(',', '')) ?? 0.0,
    );

    // 과세표준
    _taxableIncome = gross - _laborDeduction - _personalExemption
        - _insuranceDeduction - _creditCardDeduction - _mortgageDeduction;
    if (_taxableIncome < 0) _taxableIncome = 0;

    // 산출세액
    _calculatedTax = TaxRates.calculateTax(_taxableIncome);

    // 세액공제
    _laborTaxCredit = EmployeeTaxCalculator.calculateLaborTaxCredit(
      grossIncome: gross,
      calculatedTaxShare: _calculatedTax,
    );

    _childTaxCredit = EmployeeTaxCalculator.calculateChildTaxCredit(
      childrenCount: int.tryParse(_childrenCountCtrl.text.replaceAll(',', '')) ?? 0,
      newbornCount: int.tryParse(_newbornCountCtrl.text.replaceAll(',', '')) ?? 0,
    );

    _pensionCredit = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
      pensionSavingsPayment: double.tryParse(_pensionSavingsCtrl.text.replaceAll(',', '')) ?? 0.0,
      retirementPensionPayment: double.tryParse(_retirementPensionCtrl.text.replaceAll(',', '')) ?? 0.0,
      grossIncome: gross,
    );

    _insurancePremiumCredit = EmployeeTaxCalculator.calculateInsurancePremiumTaxCredit(
      generalInsurancePremium: double.tryParse(_generalInsuranceCtrl.text.replaceAll(',', '')) ?? 0.0,
      disabledInsurancePremium: double.tryParse(_disabledInsuranceCtrl.text.replaceAll(',', '')) ?? 0.0,
    );

    _medicalCredit = EmployeeTaxCalculator.calculateMedicalTaxCredit(
      grossIncome: gross,
      infertilityExpense: 0,
      selfAndSeniorAndDisabledExpense: double.tryParse(_medicalSelfCtrl.text.replaceAll(',', '')) ?? 0.0,
      otherDependentExpense: double.tryParse(_medicalOtherCtrl.text.replaceAll(',', '')) ?? 0.0,
    );

    _donationCredit = EmployeeTaxCalculator.calculateDonationTaxCredit(
      generalDonation: double.tryParse(_donationCtrl.text.replaceAll(',', '')) ?? 0.0,
      politicalDonation: double.tryParse(_politicalDonationCtrl.text.replaceAll(',', '')) ?? 0.0,
    );

    _rentCredit = 0.0;
    if (_isMonthlyRent && _monthlyRent > 0 && EmployeeTaxCalculator.isRentCreditEligible(
      grossIncome: gross,
      globalIncomeAmount: gross - _laborDeduction,
      isHomeless: _isHomeless,
    )) {
      final rentResult = EmployeeTaxCalculator.simulateRentRefund(
        grossIncome: gross,
        monthlyRent: _monthlyRent,
        decidedTax: _calculatedTax,
      );
      _rentCredit = rentResult.expectedRefund;
    }

    final totalCredit = _laborTaxCredit + _childTaxCredit + _pensionCredit +
        _insurancePremiumCredit + _medicalCredit + _donationCredit + _rentCredit;

    _decidedTaxResult = _calculatedTax - totalCredit;
    if (_decidedTaxResult < 0) _decidedTaxResult = 0;
    _decidedTaxResult = TaxRates.truncateWon(_decidedTaxResult);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final textColor = theme.textTheme.bodyLarge!.color!;
    final subColor = theme.textTheme.labelMedium!.color!;
    final cardColor = theme.cardColor;
    final bgColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('종합소득세 신고 가이드', style: AppTheme.serif(AppTheme.serifMD, textColor)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TaxPipelineRail(
                    labels: taxRailLabels(widget.userType),
                    current: taxRailIndex(widget.userType, 'annual'),
                  ),
                ),
                Expanded(
                  child: _isBusiness
                      ? _buildBusinessBody(primary, textColor, subColor, cardColor)
                      : _buildBody(primary, textColor, subColor, cardColor, bgColor),
                ),
              ],
            ),
    );
  }

  // ──────────────────────────────────────────────
  //  프리랜서·N잡러 — 홈택스 입력값 가이드 (①진단 결과 재사용)
  // ──────────────────────────────────────────────
  Widget _buildBusinessBody(Color primary, Color textColor, Color subColor, Color cardColor) {
    final draft = _businessDraft;
    final items = (draft?['items'] as List<Map<String, dynamic>>?) ?? const [];

    if (draft == null || items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          Text('${_year}년 귀속\n종합소득세 신고서'.keepWords, style: AppTheme.serif(28, textColor, spacing: -0.5, height: 1.2)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.getCardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('아직 진단 결과가 없어요', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('①종소세 진단에서 계산한 뒤 "가상 신고서 양식 보기"를 눌러야 홈택스에 입력할 숫자가 여기 채워져요.'.keepWords,
                    style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TaxSimulatorScreen(userType: widget.userType))),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(4)),
                    child: const Text('①진단으로 가기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final finalAmount = (draft['final_amount'] as num?)?.toDouble() ?? 0.0;
    final isRefund = draft['is_refund'] == true;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        Text('${_year}년 귀속\n종합소득세 신고서'.keepWords, style: AppTheme.serif(28, textColor, spacing: -0.5, height: 1.2)),
        const SizedBox(height: 4),
        Text('①진단 결과를 홈택스 화면에 나오는 순서대로 안내해드려요.\n신고 기한: 매년 5월 1일 ~ 5월 31일'.keepWords,
            style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.format_list_numbered_rounded, color: primary, size: 18),
                const SizedBox(width: 8),
                Text('홈택스에 이 순서로 입력하세요'.keepWords, style: TextStyle(color: primary, fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 14),
              for (int i = 0; i < items.length; i++) _businessItemRow(i + 1, items[i], primary, textColor, subColor),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: primary.withOpacity(0.35), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isRefund ? '5월 예상 환급액' : '5월 추가 납부 예상액', style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('${_fmt.format(finalAmount.abs().toInt())}원',
                  style: TextStyle(color: textColor, fontSize: 30, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildBusinessHomeTaxGuide(primary, textColor, subColor),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _businessItemRow(int n, Map<String, dynamic> item, Color primary, Color textColor, Color subColor) {
    final title = item['title'] as String? ?? '';
    final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final isHeader = item['isHeader'] == true;
    final highlight = item['highlight'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: highlight ? primary : subColor.withOpacity(0.3), shape: BoxShape.circle),
          child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: TextStyle(color: textColor, fontSize: 13, fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal)),
        ),
        Text('${_fmt.format(amount.toInt())}원',
            style: TextStyle(color: highlight ? primary : textColor, fontSize: 13, fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600)),
      ]),
    );
  }

  /// 국세청 「종합소득세 전자신고 매뉴얼」 홈택스 화면 흐름(검증됨: ../sekkeul-지식/JSON/금융소득_종합과세_및_종소세신고.json).
  Widget _buildBusinessHomeTaxGuide(Color primary, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.open_in_browser_rounded, color: primary, size: 18),
            const SizedBox(width: 8),
            Text('홈택스 종합소득세 신고 순서', style: TextStyle(color: primary, fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 14),
          _step('1', 'hometax.go.kr 접속 → 로그인\n(공동인증서 또는 카카오·네이버 간편인증)', primary, textColor),
          _step('2', '세금신고 > 종합소득세 신고 > 일반신고서\n> 정기신고 (5.1~5.31)', primary, textColor),
          _step('3', '종합소득금액 입력 — 사업소득 명세\n(지급명세서 불러오기 또는 직접입력, 위 ①~③ 숫자 참고)', primary, textColor),
          _step('4', '소득공제 입력 — 인적공제는 자동, 노란우산 등은 직접입력', primary, textColor),
          _step('5', '세액공제·감면 입력 후 계산 결과 확인', primary, textColor),
          _step('6', '신고서 제출 → 환급 시 환급계좌 등록', primary, textColor),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.schedule_rounded, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '신고 기한: 매년 5월 1일 ~ 5월 31일\n기한 초과 시 무신고 가산세 20% + 납부 지연 가산세 발생'.keepWords,
                style: TextStyle(color: Colors.orange, fontSize: 12, height: 1.5),
              )),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Color primary, Color textColor, Color subColor, Color cardColor, Color bgColor) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // ── 인트로 ──
        Text(
          '${_year}년 귀속\n종합소득세 신고서'.keepWords,
          style: AppTheme.serif(28, textColor, spacing: -0.5, height: 1.2),
        ),
        const SizedBox(height: 4),
        Text(
          '홈택스에 입력해야 할 항목을 앱이 안내합니다.\n신고 기한: 매년 5월 1일 ~ 5월 31일'.keepWords,
          style: TextStyle(color: subColor, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),

        // ── 자동 수집 현황 ──
        _buildAutoDataSection(primary, textColor, subColor, cardColor, bgColor),
        const SizedBox(height: 24),

        // ── 소득공제 ──
        _buildSectionTitle('소득공제', '과세표준을 낮추는 항목', textColor, subColor),
        const SizedBox(height: 10),
        _buildAutoItem('근로소득공제', '총급여 구간별 자동 계산', _laborDeduction, primary, textColor, subColor, cardColor),
        const SizedBox(height: 8),
        _buildAutoItem('인적공제 $_dependentCount인', '1인당 150만원 × ${_dependentCount}인', _personalExemption, primary, textColor, subColor, cardColor),
        const SizedBox(height: 8),
        _buildAutoItem('4대보험 소득공제', '연금·건강·고용보험 자동 계산', _insuranceDeduction, primary, textColor, subColor, cardColor),
        const SizedBox(height: 8),
        _buildAutoItem('신용카드 등 소득공제', '올해 지출 기준 자동 계산', _creditCardDeduction, primary, textColor, subColor, cardColor),
        const SizedBox(height: 8),
        _buildManualItem(
          id: 'mortgage',
          title: '주택담보대출 이자상환액',
          subtitle: '장기주택저당차입금 소득공제',
          resultAmount: _mortgageDeduction,
          isDeduction: true,
          controllers: [_mortgageCtrl],
          labels: ['연간 이자상환액'],
          hints: ['예: 5,000,000'],
          note: '15년 이상 상환·고정금리·비거치식 기준 최대 2,000만원\n주택 기준시가 6억 이하, 무주택 또는 1주택자',
          homeTaxPath: '세금신고 > 종합소득세 신고 > 공제명세서\n> 주택자금 > 장기주택저당차입금 이자상환액',
          documents: ['장기주택저당차입금 이자상환증명서 (금융기관 앱·지점 발급)'],
          primary: primary, textColor: textColor, subColor: subColor, cardColor: cardColor,
        ),

        const SizedBox(height: 24),

        // ── 세액공제 ──
        _buildSectionTitle('세액공제', '산출세액에서 직접 차감되는 항목', textColor, subColor),
        const SizedBox(height: 10),
        _buildAutoItem('근로소득세액공제', '자동 적용 (총급여 기준)', _laborTaxCredit, primary, textColor, subColor, cardColor),
        const SizedBox(height: 8),
        if (_isMonthlyRent && _monthlyRent > 0) ...[
          _buildAutoItem('월세 세액공제', '프로필 월세 기준 자동', _rentCredit, primary, textColor, subColor, cardColor),
          const SizedBox(height: 8),
        ],
        _buildManualItem(
          id: 'children',
          title: '자녀세액공제',
          subtitle: '${TaxRates.childTaxCreditEligibilityLabel()} 자녀 · 출산·입양',
          resultAmount: _childTaxCredit,
          isDeduction: false,
          controllers: [_childrenCountCtrl, _newbornCountCtrl],
          labels: ['${TaxRates.childTaxCreditEligibilityLabel()} 자녀 수', '출산·입양 자녀 수 (올해)'],
          hints: ['0', '0'],
          isCount: true,
          note: '${TaxRates.childTaxCreditEligibilityLabel()}: 첫째 25만 / 둘째 30만 / 셋째 이상 40만원\n출산·입양: 첫째 30만 / 둘째 50만 / 셋째 이상 70만원',
          homeTaxPath: '세금신고 > 종합소득세 신고 > 공제명세서\n> 자녀 세액공제 > 기본공제 자녀 수 입력',
          documents: ['주민등록등본 또는 가족관계증명서'],
          primary: primary, textColor: textColor, subColor: subColor, cardColor: cardColor,
        ),
        const SizedBox(height: 8),
        _buildManualItem(
          id: 'pension',
          title: '연금계좌 세액공제',
          subtitle: '연금저축·IRP·퇴직연금 납입액',
          resultAmount: _pensionCredit,
          isDeduction: false,
          controllers: [_pensionSavingsCtrl, _retirementPensionCtrl],
          labels: ['연금저축 연간 납입액', 'IRP·퇴직연금(DC) 납입액'],
          hints: ['예: 6,000,000 (한도 600만)', '예: 3,000,000 (합산 한도 900만)'],
          note: '총급여 5,500만 이하: 15% / 초과: 12%\n연금저축 단독 최대 600만 / IRP 포함 합산 최대 900만까지 공제',
          homeTaxPath: '세금신고 > 종합소득세 신고 > 공제명세서\n> 연금계좌 세액공제 > 연금저축·퇴직연금 납입액 입력',
          documents: ['연금납입확인서 (세액공제용) — 금융기관 앱·홈페이지에서 발급', 'IRP 가입 확인서 (금융기관 발급)'],
          primary: primary, textColor: textColor, subColor: subColor, cardColor: cardColor,
        ),
        const SizedBox(height: 8),
        _buildManualItem(
          id: 'insurance',
          title: '보장성보험료 세액공제',
          subtitle: '실손·암·종신 등 보장성보험',
          resultAmount: _insurancePremiumCredit,
          isDeduction: false,
          controllers: [_generalInsuranceCtrl, _disabledInsuranceCtrl],
          labels: ['보장성보험 연간 납입액', '장애인전용보장성보험 납입액'],
          hints: ['예: 1,200,000 (한도 100만)', '예: 0 (한도 100만)'],
          note: '보장성보험: 연 100만 한도 × 12%\n장애인전용보장성: 연 100만 한도 × 15%\n⚠ 자동차보험·실손보험은 공제 불가',
          homeTaxPath: '세금신고 > 종합소득세 신고 > 공제명세서\n> 특별세액공제 > 보험료 > 보장성보험료 칸',
          documents: ['보험료납입증명서 (보험사 앱·홈페이지에서 발급)', '연말정산 간소화 서비스에서도 조회 가능'],
          primary: primary, textColor: textColor, subColor: subColor, cardColor: cardColor,
        ),
        const SizedBox(height: 8),
        _buildManualItem(
          id: 'medical',
          title: '의료비 세액공제',
          subtitle: '총급여 3% 초과분부터 공제',
          resultAmount: _medicalCredit,
          isDeduction: false,
          controllers: [_medicalSelfCtrl, _medicalOtherCtrl],
          labels: ['본인·65세 이상·장애인 의료비 (한도 없음)', '일반 부양가족 의료비 (한도 700만)'],
          hints: ['예: 1,500,000', '예: 500,000'],
          note: '총급여의 3%를 넘는 의료비부터 15% 공제\n안경·콘택트렌즈: 1인당 50만 한도 포함\n산후조리원: 출산 1회당 200만 한도 포함\n난임시술비는 30% (본 입력란 아닌 별도 신고)',
          homeTaxPath: '세금신고 > 종합소득세 신고 > 공제명세서\n> 특별세액공제 > 의료비 > 의료비 명세서 작성',
          documents: ['의료비 명세서 (국세청 연말정산 간소화 서비스 조회)', '간소화 미조회 항목은 영수증 직접 첨부'],
          primary: primary, textColor: textColor, subColor: subColor, cardColor: cardColor,
        ),
        const SizedBox(height: 8),
        _buildManualItem(
          id: 'donation',
          title: '기부금 세액공제',
          subtitle: '일반기부금 · 정치자금기부금',
          resultAmount: _donationCredit,
          isDeduction: false,
          controllers: [_donationCtrl, _politicalDonationCtrl],
          labels: ['일반·지정기부금 합계', '정치자금기부금'],
          hints: ['예: 500,000', '예: 100,000'],
          // 정치자금 10만원 이하는 소득세 세액공제 110분의 100(=90,909원)이다.
          // "전액 환급"은 지방소득세 9,091원까지 합쳤을 때 얘기 — 이 화면은 소득세만
          // 다루므로 그렇게 쓰면 엔진이 내는 값과 어긋난다.
          note: '일반기부금: 1천만 이하 15% / 초과 30%\n정치자금: 10만원까지 110분의 100 (소득세 90,909원, 지방소득세까지 합치면 10만원) / 초과분 15%\n⚠ 고향사랑기부금은 별도 신고 항목',
          homeTaxPath: '세금신고 > 종합소득세 신고 > 기부금명세서 작성\n> 기부유형 선택 후 금액 입력',
          documents: ['기부금영수증 (기부처에서 직접 발급)', '정치자금 영수증 (정당·선관위 발급)'],
          primary: primary, textColor: textColor, subColor: subColor, cardColor: cardColor,
        ),

        const SizedBox(height: 28),

        // ── 계산 결과 ──
        _buildResultCard(primary, textColor, subColor, cardColor),

        const SizedBox(height: 20),

        // ── 홈택스 신고 가이드 ──
        _buildHomeTaxGuide(primary, textColor, subColor),

        const SizedBox(height: 40),
      ],
    );
  }

  // ──────────────────────────────────────────────
  //  자동 수집 섹션
  // ──────────────────────────────────────────────
  Widget _buildAutoDataSection(Color primary, Color textColor, Color subColor, Color cardColor, Color bgColor) {
    final gross = double.tryParse(_grossIncomeCtrl.text.replaceAll(',', '')) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, color: primary, size: 18),
            const SizedBox(width: 8),
            Text('앱이 자동으로 수집한 정보',
                style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 14),
          _autoRow('부양가족', '$_dependentCount인 (인적공제 ${_fmt.format((_dependentCount * TaxRates.basicDeductionPerPerson).toInt())}원)', textColor, subColor),
          _autoRow('연간 신용카드 지출', _annualCreditCard > 0 ? '${_fmt.format(_annualCreditCard.toInt())}원' : '기록 없음', textColor, subColor),
          _autoRow('연간 체크카드·현금', _annualDebitCash > 0 ? '${_fmt.format(_annualDebitCash.toInt())}원' : '기록 없음', textColor, subColor),
          if (_isMonthlyRent && _monthlyRent > 0)
            _autoRow('월세', '${_fmt.format(_monthlyRent.toInt())}원/월 (무주택)', textColor, subColor),
          const SizedBox(height: 14),
          Text('총급여 (수정 가능)',
              style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _buildAmountField(_grossIncomeCtrl, '예: 55,000,000', textColor, subColor, bgColor),
          if (gross <= 0) ...[
            const SizedBox(height: 8),
            Text('총급여를 입력해야 계산이 시작됩니다.'.keepWords,
                style: TextStyle(color: Colors.orange, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _autoRow(String label, String value, Color textColor, Color subColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.green, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: subColor, fontSize: 13))),
        const SizedBox(width: 8),
        // 금액이 길어지면 이 줄이 넘친다 — 좁을 때만 줄어들게.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  // ──────────────────────────────────────────────
  //  섹션 제목
  // ──────────────────────────────────────────────
  Widget _buildSectionTitle(String title, String sub, Color textColor, Color subColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(sub, style: TextStyle(color: subColor, fontSize: 12)),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  //  자동 항목 카드
  // ──────────────────────────────────────────────
  Widget _buildAutoItem(String title, String subtitle, double amount,
      Color primary, Color textColor, Color subColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
            Text(subtitle, style: TextStyle(color: subColor, fontSize: 11)),
          ],
        )),
        Text(
          amount > 0 ? '-${_fmt.format(amount.toInt())}원' : '—',
          style: TextStyle(
            color: amount > 0 ? Colors.green : subColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ]),
    );
  }

  // ──────────────────────────────────────────────
  //  수동 입력 항목 카드
  // ──────────────────────────────────────────────
  Widget _buildManualItem({
    required String id,
    required String title,
    required String subtitle,
    required double resultAmount,
    required bool isDeduction,
    required List<TextEditingController> controllers,
    required List<String> labels,
    required List<String> hints,
    required String note,
    required String homeTaxPath,
    required List<String> documents,
    bool isCount = false,
    required Color primary,
    required Color textColor,
    required Color subColor,
    required Color cardColor,
  }) {
    final isExpanded = _expanded.contains(id);
    final hasValue = controllers.any((c) {
      final v = c.text.trim();
      return v.isNotEmpty && v != '0';
    });

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: hasValue ? Border.all(color: primary.withOpacity(0.5), width: 1.2) : null,
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() {
            if (isExpanded) _expanded.remove(id);
            else _expanded.add(id);
          }),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              Icon(
                hasValue ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: hasValue ? primary : subColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(color: subColor, fontSize: 11)),
                ],
              )),
              if (resultAmount > 0) ...[
                Text(
                  '-${_fmt.format(resultAmount.toInt())}원',
                  style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: subColor, size: 20,
              ),
            ]),
          ),
        ),
        if (isExpanded) ...[
          Divider(height: 1, color: subColor.withOpacity(0.15)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 입력 필드
                for (int i = 0; i < controllers.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Text(labels[i], style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  isCount
                      ? _buildCountField(controllers[i], textColor, subColor)
                      : _buildAmountField(controllers[i], hints[i], textColor, subColor, Theme.of(context).scaffoldBackgroundColor),
                ],
                const SizedBox(height: 14),
                // 공제 조건 안내
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(note, style: TextStyle(color: textColor, fontSize: 12, height: 1.5)),
                ),
                const SizedBox(height: 14),
                // 홈택스 입력 경로
                _guideBlock(
                  Icons.computer_rounded,
                  '홈택스 입력 경로',
                  homeTaxPath,
                  primary, textColor, subColor,
                ),
                const SizedBox(height: 10),
                // 필요 서류
                _guideBlock(
                  Icons.description_outlined,
                  '필요 서류',
                  documents.map((d) => '• $d').join('\n'),
                  Colors.orange, textColor, subColor,
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }

  Widget _guideBlock(IconData icon, String label, String content, Color accent, Color textColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: accent, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 5),
        Text(content, style: TextStyle(color: textColor, fontSize: 12, height: 1.5)),
      ],
    );
  }

  // ──────────────────────────────────────────────
  //  입력 필드 위젯들
  // ──────────────────────────────────────────────
  Widget _buildAmountField(TextEditingController ctrl, String hint,
      Color textColor, Color subColor, Color fillColor) {
    return AmountField(controller: ctrl, expand: true, onChanged: (_) => setState(() {}));
  }

  Widget _buildCountField(TextEditingController ctrl, Color textColor, Color subColor) {
    return Row(children: [
      _countButton(Icons.remove_circle_outline, subColor, () {
        final v = (int.tryParse(ctrl.text.replaceAll(',', '')) ?? 0) - 1;
        ctrl.text = v < 0 ? '0' : v.toString();
      }),
      const SizedBox(width: 12),
      Expanded(
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: subColor.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            suffixText: '명',
            suffixStyle: TextStyle(color: subColor),
          ),
        ),
      ),
      const SizedBox(width: 12),
      _countButton(Icons.add_circle_outline, subColor, () {
        final v = (int.tryParse(ctrl.text.replaceAll(',', '')) ?? 0) + 1;
        ctrl.text = v.toString();
      }),
    ]);
  }

  Widget _countButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: 28),
    );
  }

  // ──────────────────────────────────────────────
  //  계산 결과 카드
  // ──────────────────────────────────────────────
  Widget _buildResultCard(Color primary, Color textColor, Color subColor, Color cardColor) {
    final totalDeduction = _laborDeduction + _personalExemption + _insuranceDeduction
        + _creditCardDeduction + _mortgageDeduction;
    final totalCredit = _laborTaxCredit + _childTaxCredit + _pensionCredit
        + _insurancePremiumCredit + _medicalCredit + _donationCredit + _rentCredit;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: primary.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('예상 결정세액',
              style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            _decidedTaxResult > 0 ? '${_fmt.format(_decidedTaxResult.toInt())}원' : '—',
            style: TextStyle(color: textColor, fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          _resultRow('총급여', double.tryParse(_grossIncomeCtrl.text.replaceAll(',', '')) ?? 0.0, textColor, subColor),
          _resultRow('소득공제 합계', totalDeduction, textColor, subColor, minus: true),
          _resultRow('과세표준', _taxableIncome, textColor, subColor, highlight: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1),
          ),
          _resultRow('산출세액', _calculatedTax, textColor, subColor),
          _resultRow('세액공제 합계', totalCredit, textColor, subColor, minus: true, green: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1),
          ),
          _resultRow('결정세액', _decidedTaxResult, textColor, subColor, highlight: true, bold: true),
        ],
      ),
    );
  }

  Widget _resultRow(String label, double amount, Color textColor, Color subColor,
      {bool minus = false, bool green = false, bool highlight = false, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(
          color: highlight ? textColor : subColor,
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ))),
        Text(
          '${minus ? '-' : ''}${_fmt.format(amount.toInt())}원',
          style: TextStyle(
            color: green ? Colors.green : (highlight ? textColor : subColor),
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ]),
    );
  }

  // ──────────────────────────────────────────────
  //  홈택스 신고 순서 가이드
  // ──────────────────────────────────────────────
  Widget _buildHomeTaxGuide(Color primary, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.open_in_browser_rounded, color: primary, size: 18),
            const SizedBox(width: 8),
            Text('홈택스 종합소득세 신고 순서',
                style: TextStyle(color: primary, fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 14),
          _step('1', 'hometax.go.kr 접속 → 로그인\n(공동인증서 또는 카카오·네이버 간편인증)', primary, textColor),
          _step('2', '상단 메뉴: 세금신고 > 종합소득세 신고\n> 일반신고서 > 정기신고 (5.1~5.31)', primary, textColor),
          _step('3', '기본정보 확인 → 근로소득 조회\n(회사가 신고한 내역이 자동으로 뜹니다)', primary, textColor),
          _step('4', '소득공제 명세서 작성\n(주택자금·신용카드 등 — 앱의 \'소득공제\' 참고)', primary, textColor),
          _step('5', '세액공제 명세서 작성\n(연금계좌·보험료·의료비 등 — 앱의 \'세액공제\' 참고)', primary, textColor),
          _step('6', '계산 결과 확인 → 납부·환급세액 확인', primary, textColor),
          _step('7', '신고서 제출 → 환급 시 환급계좌 등록', primary, textColor),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.schedule_rounded, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '신고 기한: 매년 5월 1일 ~ 5월 31일\n기한 초과 시 무신고 가산세 20% + 납부 지연 가산세 발생'.keepWords,
                style: TextStyle(color: Colors.orange, fontSize: 12, height: 1.5),
              )),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _step(String num, String text, Color primary, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
          child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: textColor, fontSize: 12, height: 1.5))),
      ]),
    );
  }
}
