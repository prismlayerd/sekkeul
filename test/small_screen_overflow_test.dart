import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/ui/screens/annual_backfill_screen.dart';
import 'package:secul/ui/screens/benefit_screen.dart';
import 'package:secul/ui/screens/bookkeeping_guide_screen.dart';
import 'package:secul/ui/screens/correction_request_screen.dart';
import 'package:secul/ui/screens/deduction_gate_screen.dart';
import 'package:secul/ui/screens/diagnosis_screen.dart';
import 'package:secul/ui/screens/document_checklist_screen.dart';
import 'package:secul/ui/screens/forms_screen.dart';
import 'package:secul/ui/screens/missed_deduction_diagnosis_screen.dart';
import 'package:secul/ui/screens/notification_settings_screen.dart';
import 'package:secul/ui/screens/profile_input_screen.dart';
import 'package:secul/ui/screens/tax_annual_report_screen.dart';
import 'package:secul/ui/screens/tax_record_import_screen.dart';
import 'package:secul/ui/screens/tax_simulator_screen.dart';
import 'package:secul/ui/screens/tax_tools_screen.dart';
import 'package:secul/ui/screens/year_end_tax_screen.dart';
import 'package:secul/ui/screens/acquisition_tax_screen.dart';
import 'package:secul/ui/screens/basic_pension_screen.dart';
import 'package:secul/ui/screens/beotimmok_loan_screen.dart';
import 'package:secul/ui/screens/bogeumjari_loan_screen.dart';
import 'package:secul/ui/screens/calculator_screen.dart';
import 'package:secul/ui/screens/capital_gains_tax_screen.dart';
import 'package:secul/ui/screens/car_lease_buy_rent_screen.dart';
import 'package:secul/ui/screens/car_tax_annual_screen.dart';
import 'package:secul/ui/screens/carbon_neutral_points_screen.dart';
import 'package:secul/ui/screens/compound_interest_screen.dart';
import 'package:secul/ui/screens/daycare_fee_screen.dart';
import 'package:secul/ui/screens/dependent_deduction_screen.dart';
import 'package:secul/ui/screens/didimdol_loan_screen.dart';
import 'package:secul/ui/screens/disability_pension_screen.dart';
import 'package:secul/ui/screens/driver_license_renewal_screen.dart';
import 'package:secul/ui/screens/earned_income_tax_credit_screen.dart';
import 'package:secul/ui/screens/employment_support_program_screen.dart';
import 'package:secul/ui/screens/energy_voucher_screen.dart';
import 'package:secul/ui/screens/ev_vs_gas_screen.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';
import 'package:secul/ui/screens/financial_income_screen.dart';
import 'package:secul/ui/screens/four_insurance_screen.dart';
import 'package:secul/ui/screens/fresh_start_fund_screen.dart';
import 'package:secul/ui/screens/home_screen.dart';
import 'package:secul/ui/screens/hourly_rate_converter_screen.dart';
import 'package:secul/ui/screens/household_separation_screen.dart';
import 'package:secul/ui/screens/housing_pension_screen.dart';
import 'package:secul/ui/screens/housing_subscription_screen.dart';
import 'package:secul/ui/screens/inheritance_gift_tax_screen.dart';
import 'package:secul/ui/screens/insurance_premium_screen.dart';
import 'package:secul/ui/screens/isa_tax_benefits_screen.dart';
import 'package:secul/ui/screens/jeonse_insurance_screen.dart';
import 'package:secul/ui/screens/jeonse_vs_wolse_screen.dart';
import 'package:secul/ui/screens/kpass_climate_card_screen.dart';
import 'package:secul/ui/screens/light_car_fuel_refund_screen.dart';
import 'package:secul/ui/screens/loan_interest_screen.dart';
import 'package:secul/ui/screens/loan_schedule_screen.dart';
import 'package:secul/ui/screens/minimum_wage_impact_screen.dart';
import 'package:secul/ui/screens/monthly_rent_tax_credit_screen.dart';
import 'package:secul/ui/screens/naeil_chaeum_screen.dart';
import 'package:secul/ui/screens/national_pension_timing_screen.dart';
import 'package:secul/ui/screens/newborn_special_loan_screen.dart';
import 'package:secul/ui/screens/newlywed_special_supply_screen.dart';
import 'package:secul/ui/screens/notification_inbox_screen.dart';
import 'package:secul/ui/screens/occupation_search_screen.dart';
import 'package:secul/ui/screens/onboarding_screen.dart';
import 'package:secul/ui/screens/out_of_pocket_cap_screen.dart';
import 'package:secul/ui/screens/parental_leave_6plus6_screen.dart';
import 'package:secul/ui/screens/passport_fee_screen.dart';
import 'package:secul/ui/screens/pension_calculator_screen.dart';
import 'package:secul/ui/screens/property_tax_screen.dart';
import 'package:secul/ui/screens/recurring_templates_screen.dart';
import 'package:secul/ui/screens/reminder_form_screen.dart';
import 'package:secul/ui/screens/retirement_pension_screen.dart';
import 'package:secul/ui/screens/salary_net_screen.dart';
import 'package:secul/ui/screens/savings_calculator_screen.dart';
import 'package:secul/ui/screens/senior_dental_screen.dart';
import 'package:secul/ui/screens/severance_pay_screen.dart';
import 'package:secul/ui/screens/severe_disease_copayment_screen.dart';
import 'package:secul/ui/screens/unemployment_benefit_screen.dart';
import 'package:secul/ui/screens/weekly_holiday_pay_screen.dart';
import 'package:secul/ui/screens/withholding_calc_screen.dart';
import 'package:secul/ui/screens/youth_housing_dream_screen.dart';
import 'package:secul/ui/screens/youth_leap_account_screen.dart';

/// 작은 화면(360×800 — 갤럭시 S/아이폰 SE급)에서 화면이 넘치는 곳을 전수로 찾는다.
///
/// 오버플로는 실기기에서 노란·검정 줄무늬로 보이고, 잘린 쪽 글자는 아예 읽을 수 없다.
/// 개발용 큰 화면에서는 절대 드러나지 않아 눈으로는 못 잡는다.
/// 최근 3개월치 수입·지출을 심는다 — 긴 금액 문구가 실제로 그려지게 하려면
/// 빈 DB로는 부족하다. 자릿수가 큰 값을 일부러 쓴다.
Future<void> seedLedger(String userType) async {
  final now = DateTime.now();
  final incomeType = userType == '프리랜서' ? '사업소득' : '급여';
  for (int back = 0; back < 3; back++) {
    final d = DateTime(now.year, now.month - back, 1);
    await dbService.insertIncomeEntry(IncomeEntry(
        id: 'sd-inc-$back', date: d, amount: 4500000, memo: '',
        incomeType: incomeType, userType: userType));
    await dbService.insertExpense(ExpenseItem(
        id: 'sd-exp-c-$back', date: d, amount: 4800000, content: '',
        category: '기타', paymentMethod: '신용카드', isBusiness: false,
        userType: userType));
    await dbService.insertExpense(ExpenseItem(
        id: 'sd-exp-d-$back', date: d, amount: 1200000, content: '',
        category: '기타', paymentMethod: '체크+현금', isBusiness: true,
        userType: userType));
  }
}

void main() {
  final screens = <(String, Widget Function())>[
    ('AcquisitionTaxScreen', () => const AcquisitionTaxScreen()),
    ('BasicPensionScreen', () => const BasicPensionScreen()),
    ('BeotimmokLoanScreen', () => const BeotimmokLoanScreen()),
    ('BogeumjariLoanScreen', () => const BogeumjariLoanScreen()),
    ('CalculatorScreen', () => const CalculatorScreen()),
    ('CapitalGainsTaxScreen', () => const CapitalGainsTaxScreen()),
    ('CarLeaseBuyRentScreen', () => const CarLeaseBuyRentScreen()),
    ('CarTaxAnnualScreen', () => const CarTaxAnnualScreen()),
    ('CarbonNeutralPointsScreen', () => const CarbonNeutralPointsScreen()),
    ('CompoundInterestScreen', () => const CompoundInterestScreen()),
    ('DaycareFeeScreen', () => const DaycareFeeScreen()),
    ('DependentDeductionScreen', () => const DependentDeductionScreen()),
    ('DidimdolLoanScreen', () => const DidimdolLoanScreen()),
    ('DisabilityPensionScreen', () => const DisabilityPensionScreen()),
    ('DriverLicenseRenewalScreen', () => const DriverLicenseRenewalScreen()),
    ('EarnedIncomeTaxCreditScreen', () => const EarnedIncomeTaxCreditScreen()),
    ('EmploymentSupportProgramScreen', () => const EmploymentSupportProgramScreen()),
    ('EnergyVoucherScreen', () => const EnergyVoucherScreen()),
    ('EvVsGasScreen', () => const EvVsGasScreen()),
    ('ExpenseCalendarScreen', () => const ExpenseCalendarScreen()),
    ('FinancialIncomeScreen', () => const FinancialIncomeScreen()),
    ('FourInsuranceScreen', () => const FourInsuranceScreen()),
    ('FreshStartFundScreen', () => const FreshStartFundScreen()),
    ('HomeScreen', () => const HomeScreen()),
    ('HourlyRateConverterScreen', () => const HourlyRateConverterScreen()),
    ('HouseholdSeparationScreen', () => const HouseholdSeparationScreen()),
    ('HousingPensionScreen', () => const HousingPensionScreen()),
    ('HousingSubscriptionScreen', () => const HousingSubscriptionScreen()),
    ('InheritanceGiftTaxScreen', () => const InheritanceGiftTaxScreen()),
    ('InsurancePremiumScreen', () => const InsurancePremiumScreen()),
    ('IsaTaxBenefitsScreen', () => const IsaTaxBenefitsScreen()),
    ('JeonseInsuranceScreen', () => const JeonseInsuranceScreen()),
    ('JeonseVsWolseScreen', () => const JeonseVsWolseScreen()),
    ('KpassClimateCardScreen', () => const KpassClimateCardScreen()),
    ('LightCarFuelRefundScreen', () => const LightCarFuelRefundScreen()),
    ('LoanInterestScreen', () => const LoanInterestScreen()),
    ('LoanScheduleScreen', () => const LoanScheduleScreen()),
    ('MinimumWageImpactScreen', () => const MinimumWageImpactScreen()),
    ('MonthlyRentTaxCreditScreen', () => const MonthlyRentTaxCreditScreen()),
    ('NaeilChaeumScreen', () => const NaeilChaeumScreen()),
    ('NationalPensionTimingScreen', () => const NationalPensionTimingScreen()),
    ('NewbornSpecialLoanScreen', () => const NewbornSpecialLoanScreen()),
    ('NewlywedSpecialSupplyScreen', () => const NewlywedSpecialSupplyScreen()),
    ('NotificationInboxScreen', () => const NotificationInboxScreen()),
    ('OccupationSearchScreen', () => const OccupationSearchScreen()),
    ('OnboardingScreen', () => const OnboardingScreen()),
    ('OutOfPocketCapScreen', () => const OutOfPocketCapScreen()),
    ('ParentalLeave6Plus6Screen', () => const ParentalLeave6Plus6Screen()),
    ('PassportFeeScreen', () => const PassportFeeScreen()),
    ('PensionCalculatorScreen', () => const PensionCalculatorScreen()),
    ('PropertyTaxScreen', () => const PropertyTaxScreen()),
    ('RecurringTemplatesScreen', () => const RecurringTemplatesScreen()),
    ('ReminderFormScreen', () => const ReminderFormScreen()),
    ('RetirementPensionScreen', () => const RetirementPensionScreen()),
    ('SalaryNetScreen', () => const SalaryNetScreen()),
    ('SavingsCalculatorScreen', () => const SavingsCalculatorScreen()),
    ('SeniorDentalScreen', () => const SeniorDentalScreen()),
    ('SeverancePayScreen', () => const SeverancePayScreen()),
    ('SevereDiseaseCopaymentScreen', () => const SevereDiseaseCopaymentScreen()),
    ('UnemploymentBenefitScreen', () => const UnemploymentBenefitScreen()),
    ('WeeklyHolidayPayScreen', () => const WeeklyHolidayPayScreen()),
    ('WithholdingCalcScreen', () => const WithholdingCalcScreen()),
    ('YouthHousingDreamScreen', () => const YouthHousingDreamScreen()),
    ('YouthLeapAccountScreen', () => const YouthLeapAccountScreen()),
  ];

  testWidgets('360×800에서 넘치는 화면이 없다', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    final problems = <String>[];
    String current = '';
    // 오버플로만 걷어 담고 나머지는 삼킨다. 테스트 환경에는 알림 플러그인 같은
    // 네이티브 채널이 없어서 화면마다 무관한 비동기 예외가 딸려 나온다.
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exception.toString();
      if (!s.contains('overflowed')) return;
      final where =
          RegExp(r'(\w+_screen\.dart|\w+\.dart):(\d+)').firstMatch(d.toString());
      final line = '$current — ${s.split('.').first} @ ${where?.group(0) ?? '?'}';
      if (!problems.contains(line)) problems.add(line);
    };
    addTearDown(() => FlutterError.onError = old);

    for (final (name, build) in screens) {
      current = name;
      dbService = InMemoryDatabaseHelper();
      await dbService.initDatabase();
      try {
        await t.pumpWidget(MaterialApp(home: build()));
        await t.pump(const Duration(milliseconds: 400));
        await t.pump(const Duration(milliseconds: 400));
      } catch (_) {
        // 화면 자체가 못 뜨는 건 이 테스트의 관심사가 아니다.
      }
      t.takeException();
    }
    FlutterError.onError = old;

    for (final p in problems) {
      // ignore: avoid_print
      print('넘침: $p');
    }
    // ignore: avoid_print
    print('검사한 화면 ${screens.length}개 · 넘친 곳 ${problems.length}건');
    expect(problems, isEmpty, reason: '작은 화면에서 잘리는 곳이 있다');
  });

  testWidgets('유형별 화면도 360×800에서 넘치지 않는다', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    // userType 하나만 받는 화면들 — 인자가 있다는 이유로 지금까지 한 번도
    // 열어 본 적이 없었다. 이모지가 섞인 문구에서 렌더링이 죽던 버그도 여기 있었다.
    final byType = <(String, Widget Function(String))>[
      ('AnnualBackfillScreen', (u) => AnnualBackfillScreen(userType: u)),
      ('BenefitScreen', (u) => BenefitScreen(userType: u)),
      ('BookkeepingGuideScreen', (u) => BookkeepingGuideScreen(userType: u)),
      ('CorrectionRequestScreen', (u) => CorrectionRequestScreen(userType: u)),
      ('DeductionGateScreen', (u) => DeductionGateScreen(userType: u)),
      ('DiagnosisScreen', (u) => DiagnosisScreen(userType: u)),
      ('DocumentChecklistScreen', (u) => DocumentChecklistScreen(userType: u)),
      ('FormsScreen', (u) => FormsScreen(userType: u)),
      ('MissedDeductionDiagnosisScreen', (u) => MissedDeductionDiagnosisScreen(userType: u)),
      ('NotificationSettingsScreen', (u) => NotificationSettingsScreen(userType: u)),
      ('ProfileInputScreen', (u) => ProfileInputScreen(userType: u)),
      ('TaxAnnualReportScreen', (u) => TaxAnnualReportScreen(userType: u)),
      ('TaxRecordImportScreen', (u) => TaxRecordImportScreen(userType: u)),
      ('TaxSimulatorScreen', (u) => TaxSimulatorScreen(userType: u)),
      ('TaxToolsScreen', (u) => TaxToolsScreen(userType: u)),
      ('YearEndTaxScreen', (u) => YearEndTaxScreen(userType: u)),
    ];

    final problems = <String>[];
    String current = '';
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exception.toString();
      final isOverflow = s.contains('overflowed');
      final isUtf16 = s.contains('not well-formed UTF-16');
      if (!isOverflow && !isUtf16) return;
      final where =
          RegExp(r'(\w+_screen\.dart|\w+\.dart):(\d+)').firstMatch(d.toString());
      final line = '$current — ${s.split('.').first} @ ${where?.group(0) ?? '?'}';
      if (!problems.contains(line)) problems.add(line);
    };
    addTearDown(() => FlutterError.onError = old);

    // 빈 상태로만 훑으면 **데이터가 있을 때만 나타나는 넘침**을 통째로 놓친다.
    // 실제로 '카드 공제 문턱 (연봉의 25%)' + '12,500,000원 남음'이 한 줄에 안 들어가
    // 60px 넘치던 것을 이 시드가 없어서 못 잡고 있었다.
    for (final userType in ['직장인', '프리랜서', 'N잡러']) {
      for (final (name, build) in byType) {
        current = '$name($userType)';
        dbService = InMemoryDatabaseHelper();
        await dbService.initDatabase();
        await dbService.saveProfile({
          'user_type': userType,
          'gross_income': 42000000.0,
          'occupation_code': '940306',
          'prior_year_income': 30000000.0,
          'dependents': 2,
          'children_count_total': 2,
          'children_count_credit': 2,
          'is_monthly_rent': true,
          'monthly_rent': 600000.0,
        });
        await seedLedger(userType);
        try {
          await t.pumpWidget(MaterialApp(home: build(userType)));
          await t.pump(const Duration(milliseconds: 400));
          await t.pump(const Duration(milliseconds: 400));
        } catch (_) {
          // 화면이 못 뜨는 건 이 테스트의 관심사가 아니다.
        }
        t.takeException();
      }
    }
    FlutterError.onError = old;

    for (final p in problems) {
      // ignore: avoid_print
      print('넘침: $p');
    }
    // ignore: avoid_print
    print('유형별 화면 ${byType.length}개 × 3유형 · 문제 ${problems.length}건');
    expect(problems, isEmpty, reason: '작은 화면에서 잘리거나 렌더링이 죽는 곳이 있다');
  });
}
