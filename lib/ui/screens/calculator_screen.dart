import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../components/search_field.dart';
import 'salary_net_screen.dart';
import 'pension_calculator_screen.dart';
import 'insurance_premium_screen.dart';
import 'dependent_deduction_screen.dart';
import 'financial_income_screen.dart';
import 'withholding_calc_screen.dart';
import 'four_insurance_screen.dart';
import 'weekly_holiday_pay_screen.dart';
import 'severance_pay_screen.dart';
import 'unemployment_benefit_screen.dart';
import 'national_pension_timing_screen.dart';
import 'earned_income_tax_credit_screen.dart';
import 'isa_tax_benefits_screen.dart';
import 'didimdol_loan_screen.dart';
import 'beotimmok_loan_screen.dart';
import 'jeonse_insurance_screen.dart';
import 'monthly_rent_tax_credit_screen.dart';
import 'loan_interest_screen.dart';
import 'loan_schedule_screen.dart';
import 'compound_interest_screen.dart';
import 'savings_calculator_screen.dart';
import 'jeonse_vs_wolse_screen.dart';
import 'housing_subscription_screen.dart';
import 'acquisition_tax_screen.dart';
import 'capital_gains_tax_screen.dart';
import 'inheritance_gift_tax_screen.dart';
import 'property_tax_screen.dart';
import 'youth_leap_account_screen.dart';
import 'youth_housing_dream_screen.dart';
import 'naeil_chaeum_screen.dart';
import 'retirement_pension_screen.dart';
import 'parental_leave_6plus6_screen.dart';
import 'newborn_special_loan_screen.dart';
import 'daycare_fee_screen.dart';
import 'out_of_pocket_cap_screen.dart';
import 'basic_pension_screen.dart';
import 'senior_dental_screen.dart';
import 'housing_pension_screen.dart';
import 'severe_disease_copayment_screen.dart';
import 'disability_pension_screen.dart';
import 'bogeumjari_loan_screen.dart';
import 'newlywed_special_supply_screen.dart';
import 'household_separation_screen.dart';
import 'employment_support_program_screen.dart';
import 'driver_license_renewal_screen.dart';
import 'fresh_start_fund_screen.dart';
import 'passport_fee_screen.dart';
import 'minimum_wage_impact_screen.dart';
import 'car_lease_buy_rent_screen.dart';
import 'ev_vs_gas_screen.dart';
import 'hourly_rate_converter_screen.dart';
import 'car_tax_annual_screen.dart';
import 'kpass_climate_card_screen.dart';
import 'light_car_fuel_refund_screen.dart';
import 'carbon_neutral_points_screen.dart';
import 'energy_voucher_screen.dart';

class _Calc {
  final String name;
  final String desc;
  final WidgetBuilder? builder;

  const _Calc({required this.name, required this.desc, this.builder});
}

class _CalcCategory {
  final String label;
  final List<_Calc> items;

  const _CalcCategory({required this.label, required this.items});
}

final _categories = <_CalcCategory>[
  _CalcCategory(label: '급여 · 근로', items: [
    _Calc(name: '연봉 실수령액', desc: '세전연봉에서 4대보험·세금 제한 실수령 계산', builder: (_) => const SalaryNetScreen()),
    _Calc(name: '4대 보험료', desc: '국민연금·건강보험·고용보험 보험료 산출', builder: (_) => const FourInsuranceScreen()),
    _Calc(name: '퇴직금', desc: '평균임금 기준 퇴직금 예상액 계산', builder: (_) => const SeverancePayScreen()),
    _Calc(name: '주휴수당 · 최저임금', desc: '아르바이트·단시간 근로 주휴수당 산정', builder: (_) => const WeeklyHolidayPayScreen()),
    _Calc(name: '3.3% 원천징수 계산기', desc: '계약금액에서 원천징수세액·실수령액 계산', builder: (_) => const WithholdingCalcScreen()),
    _Calc(name: '실업급여', desc: '고용보험 가입기간·임금 기준 수급액 추정', builder: (_) => const UnemploymentBenefitScreen()),
    _Calc(name: '국민연금 조기·연기', desc: '수령 시기별 연금액 변화 비교', builder: (_) => const NationalPensionTimingScreen()),
    _Calc(name: '퇴직연금', desc: 'DB형·DC형 퇴직급여 예상액 비교', builder: (_) => const RetirementPensionScreen()),
    _Calc(name: '최저임금 인상 영향', desc: '전년 대비 시급 인상분 기준 월·연 추가수입 추정', builder: (_) => const MinimumWageImpactScreen()),
    _Calc(name: '시급 환산기', desc: '시급·작업시간 기준 프로젝트 견적·일급·월급 환산', builder: (_) => const HourlyRateConverterScreen()),
  ]),
  _CalcCategory(label: '세금 · 연금 · 환급', items: [
    _Calc(name: '근로·자녀장려금', desc: '소득·재산 기준 장려금 지급액 추정', builder: (_) => const EarnedIncomeTaxCreditScreen()),
    _Calc(name: '연금저축·IRP 절세', desc: '납입액별 세액공제 환급액 계산', builder: (_) => const PensionCalculatorScreen()),
    _Calc(name: '보험료 세액공제', desc: '보장성보험료 최대 27만원 공제 계산', builder: (_) => const InsurancePremiumScreen()),
    _Calc(name: '부양가족 공제', desc: '소득·나이 요건 충족 여부 및 공제액 확인', builder: (_) => const DependentDeductionScreen()),
    _Calc(name: '금융소득 종합과세', desc: '이자·배당소득 2천만원 초과 종합과세 시뮬레이터', builder: (_) => const FinancialIncomeScreen()),
    _Calc(name: 'ISA 절세', desc: '비과세·분리과세 혜택 포함 세후 수익 비교', builder: (_) => const IsaTaxBenefitsScreen()),
    _Calc(name: '월세 세액공제', desc: '무주택 세입자 월세 세액공제 12~17% 산출', builder: (_) => const MonthlyRentTaxCreditScreen()),
  ]),
  _CalcCategory(label: '주거 · 부동산', items: [
    _Calc(name: '디딤돌 대출', desc: '내 집 마련 정책 대출 원리금균등 월상환액 계산', builder: (_) => const DidimdolLoanScreen()),
    _Calc(name: '버팀목 대출', desc: '전세자금 정책 대출 만기일시 월이자 계산', builder: (_) => const BeotimmokLoanScreen()),
    _Calc(name: '보금자리론', desc: '중간소득층 정책 대출 원리금균등 월상환액 계산', builder: (_) => const BogeumjariLoanScreen()),
    _Calc(name: '전세보증보험료', desc: 'HUG·HF·SGI 보증료 비교 계산', builder: (_) => const JeonseInsuranceScreen()),
    _Calc(name: '신혼특공 자격진단', desc: '혼인기간·소득·자산 기준 특별공급 순위·자격 진단', builder: (_) => const NewlywedSpecialSupplyScreen()),
    _Calc(name: '세대분리 가능여부 진단', desc: '나이·혼인·소득·주거 기준 세대분리 가능여부 판정', builder: (_) => const HouseholdSeparationScreen()),
  ]),
  _CalcCategory(label: '대출 · 저축', items: [
    _Calc(name: '대출이자 계산', desc: '원리금균등·원금균등·만기일시 월상환액 비교', builder: (_) => const LoanInterestScreen()),
    _Calc(name: '대출 상환 스케줄', desc: '월별 원금·이자·잔금 전체 상환표 조회', builder: (_) => const LoanScheduleScreen()),
    _Calc(name: '복리 계산기', desc: '연·월 복리 기준 자산 성장 시뮬레이터', builder: (_) => const CompoundInterestScreen()),
    _Calc(name: '예·적금 세후 수익', desc: '이자소득세 15.4% 제외 세후 실수령 계산', builder: (_) => const SavingsCalculatorScreen()),
    _Calc(name: '전세 vs 월세 비교', desc: '보증금 운용수익·월세 기회비용 비교', builder: (_) => const JeonseVsWolseScreen()),
  ]),
  _CalcCategory(label: '부동산 세금', items: [
    _Calc(name: '청약가점', desc: '무주택기간·부양가족·청약통장 기준 가점 계산', builder: (_) => const HousingSubscriptionScreen()),
    _Calc(name: '취득세', desc: '주택 가격·취득 목적별 취득세율 계산', builder: (_) => const AcquisitionTaxScreen()),
    _Calc(name: '양도소득세', desc: '보유기간·1가구1주택 여부 기준 양도세 추정', builder: (_) => const CapitalGainsTaxScreen()),
    _Calc(name: '상속·증여세', desc: '공제 적용 후 세율 구간별 세액 계산', builder: (_) => const InheritanceGiftTaxScreen()),
    _Calc(name: '종부세·재산세', desc: '공시지가·세율 기준 보유세 추정', builder: (_) => const PropertyTaxScreen()),
  ]),
  _CalcCategory(label: '청년 · 장병', items: [
    _Calc(name: '청년도약계좌', desc: '소득 구간별 정부기여금 포함 5년 만기액 추정', builder: (_) => const YouthLeapAccountScreen()),
    _Calc(name: '청년 주택드림 청약통장', desc: '드림 vs 일반 금리 이자 비교 + 소득공제 환급액', builder: (_) => const YouthHousingDreamScreen()),
    _Calc(name: '내일채움공제', desc: '2024년 신규가입 종료 안내 및 대체 상품', builder: (_) => const NaeilChaeumScreen()),
  ]),
  _CalcCategory(label: '출산 · 육아', items: [
    _Calc(name: '6+6 부모육아휴직급여', desc: '부모 각각 첫 6개월 통상임금 100% 급여 추정', builder: (_) => const ParentalLeave6Plus6Screen()),
    _Calc(name: '신생아 특례대출', desc: '대출금액·금리·기간별 원리금균등 월상환액 계산', builder: (_) => const NewbornSpecialLoanScreen()),
    _Calc(name: '보육료 · 가정양육 비교', desc: '연령별 어린이집 보육료 vs 가정양육 현금 비교', builder: (_) => const DaycareFeeScreen()),
  ]),
  _CalcCategory(label: '의료 · 복지', items: [
    _Calc(name: '본인부담상한제 환급', desc: '소득분위별 연간 상한액 초과분 예상 환급액 계산', builder: (_) => const OutOfPocketCapScreen()),
    _Calc(name: '기초연금', desc: '나이·가구구분·소득인정액 기준 수급 가능여부 및 예상 월수급액', builder: (_) => const BasicPensionScreen()),
    _Calc(name: '노인 틀니 · 임플란트', desc: '시술종류·보험종별 기준 예상 본인부담금 계산', builder: (_) => const SeniorDentalScreen()),
    _Calc(name: '주택연금', desc: '연령·주택 공시가격 기준 예상 월지급금 추정', builder: (_) => const HousingPensionScreen()),
    _Calc(name: '중증질환 산정특례', desc: '진료유형·진료비 기준 본인부담 절감액 계산', builder: (_) => const SevereDiseaseCopaymentScreen()),
    _Calc(name: '장애인연금 · 장애수당', desc: '장애정도·연령·소득구간 기준 예상 월지원금', builder: (_) => const DisabilityPensionScreen()),
  ]),
  _CalcCategory(label: '일자리 · 행정', items: [
    _Calc(name: '국민취업지원제도', desc: '유형·부양가족·성공수당 기준 예상 총 수령액', builder: (_) => const EmploymentSupportProgramScreen()),
    _Calc(name: '운전면허 갱신 만료일', desc: '취득일·연령 기준 다음 갱신 만료일 계산', builder: (_) => const DriverLicenseRenewalScreen()),
    _Calc(name: '새출발기금 채무조정', desc: '차주상태·채무액 기준 감면액·월상환액 계산', builder: (_) => const FreshStartFundScreen()),
    _Calc(name: '여권 발급 수수료', desc: '여권 종류·면수별 수수료·유효기간 조회', builder: (_) => const PassportFeeScreen()),
  ]),
  _CalcCategory(label: '교통 · 에너지', items: [
    _Calc(name: '리스 · 구매 · 렌트 비교', desc: '차량 이용 방식별 총 지출 비교', builder: (_) => const CarLeaseBuyRentScreen()),
    _Calc(name: '전기차 vs 휘발유차', desc: '연료비·구매가 기준 총소유비용(TCO) 및 손익분기점 계산', builder: (_) => const EvVsGasScreen()),
    _Calc(name: '자동차세 연납 할인', desc: '신청 시기별 공제율 적용 절감액 계산', builder: (_) => const CarTaxAnnualScreen()),
    _Calc(name: 'K-패스 · 기후동행카드 비교', desc: '이용 횟수·요금 기준 더 유리한 교통카드 비교', builder: (_) => const KpassClimateCardScreen()),
    _Calc(name: '경차 유류세 환급', desc: '유종·월 주유량 기준 예상 환급액 계산', builder: (_) => const LightCarFuelRefundScreen()),
    _Calc(name: '탄소중립포인트', desc: '친환경 활동별 연간 예상 적립 포인트 계산', builder: (_) => const CarbonNeutralPointsScreen()),
    _Calc(name: '에너지바우처 예상액', desc: '가구원 수 기준 여름·겨울 바우처 예상액 조회', builder: (_) => const EnergyVoucherScreen()),
  ]),
];

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _searchExpanded = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (!_searchExpanded) {
        _searchCtrl.clear();
        _query = '';
      }
    });
  }

  /// 이름·설명 어디에 걸려도 잡는다 — 사용자가 제도명을 정확히 아는 경우가 드물어서다.
  bool _matches(_Calc c) {
    final q = _query.toLowerCase();
    return c.name.toLowerCase().contains(q) || c.desc.toLowerCase().contains(q);
  }

  void _onTap(BuildContext context, _Calc calc) {
    if (calc.builder != null) {
      Navigator.push(context, MaterialPageRoute(builder: calc.builder!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('아직 준비 중이에요.',
              style: AppTheme.sans(13, Colors.white)),
          backgroundColor: AppTheme.ink(context),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final line = AppTheme.line(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Text('계산기',
            style: AppTheme.serif(17, ink,
                weight: FontWeight.w400, spacing: -0.5)),
        actions: [
          IconButton(
            icon: Icon(_searchExpanded ? Icons.close_rounded : Icons.search_rounded, color: ink),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _searchExpanded
                ? SearchField(
                    controller: _searchCtrl,
                    hint: '연봉, 퇴직금, 대출…',
                    onChanged: (v) => setState(() => _query = v.trim()),
                    autofocus: true,
                  )
                : const SizedBox(width: double.infinity),
          ),
          Expanded(child: _buildList(ink, sub, tert, line)),
        ],
      ),
    );
  }

  Widget _buildList(Color ink, Color sub, Color tert, Color line) {
    // 검색 중엔 카테고리를 접고 결과만 편다 — 찾는 사람은 폴더가 아니라 답을 원한다.
    if (_query.isNotEmpty) {
      final hits = [
        for (final cat in _categories)
          for (final calc in cat.items)
            if (_matches(calc)) (cat.label, calc),
      ];
      if (hits.isEmpty) {
        return ListView(children: [
          SearchEmptyState(
            query: _query,
            suggestion: '이 이름의 계산기는 없어요.\n받을 수 있는 지원금이라면 혜택 탭에 있어요.',
          ),
        ]);
      }
      return ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        itemCount: hits.length,
        itemBuilder: (context, i) => _buildItem(
          context, hits[i].$2, ink, sub, tert, line,
          category: hits[i].$1,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: _categories.fold<int>(0, (sum, c) => sum + 1 + c.items.length),
      itemBuilder: (context, idx) {
        int offset = 0;
        for (final cat in _categories) {
          if (idx == offset) {
            return _buildHeader(context, cat.label, line);
          }
          offset++;
          for (final calc in cat.items) {
            if (idx == offset) {
              return _buildItem(context, calc, ink, sub, tert, line);
            }
            offset++;
          }
        }
        return null;
      },
    );
  }

  Widget _buildHeader(BuildContext context, String label, Color line) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(label.toUpperCase(), style: AppTheme.label(context)),
        ),
        Divider(height: 1, thickness: 1, color: line),
      ],
    );
  }

  /// [category]가 있으면 검색 결과 — 어느 묶음에서 나왔는지 위에 얹어준다.
  Widget _buildItem(BuildContext context, _Calc calc, Color ink, Color sub,
      Color tert, Color line, {String? category}) {
    final ready = calc.builder != null;
    return Column(
      children: [
        GestureDetector(
          onTap: () => _onTap(context, calc),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (category != null) ...[
                        Text(category.toUpperCase(), style: AppTheme.label(context)),
                        const SizedBox(height: 5),
                      ],
                      Text(calc.name,
                          style: AppTheme.sans(15, ink,
                              weight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(calc.desc,
                          style: AppTheme.sans(12, sub, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (ready)
                  Icon(Icons.chevron_right_rounded, size: 20, color: tert)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: line),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('준비 중', style: AppTheme.sans(11, tert)),
                  ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: line, indent: 16),
      ],
    );
  }
}
