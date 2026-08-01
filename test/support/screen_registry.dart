import 'package:flutter/material.dart';
export 'package:secul/core/data/db_helper.dart' show dbService, InMemoryDatabaseHelper;
export 'package:secul/core/data/expense_item.dart';
export 'package:secul/core/data/income_entry.dart';
export 'package:secul/ui/screens/home_screen.dart';

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

/// 화면 레지스트리 — 전수 검사들이 함께 쓴다.
///
/// 목록이 두 벌로 갈라지면 한쪽에만 화면이 추가돼 조용히 빠진다. 넘침 검사와
/// 스모크 검사가 같은 목록을 보게 한 곳에 둔다.

/// 인자 없이 뜨는 화면.
final noArgScreens = <(String, Widget Function())>[
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

/// 사용자 유형 하나를 받는 화면.
final byTypeScreens = <(String, Widget Function(String))>[
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

/// 실제 사용자에 가까운 프로필 — **모든 불리언·카운트 컬럼을 채운다.**
///
/// 빈 프로필로만 화면을 열면 `null as int?`가 통과해 버려서, 프로필을 저장한
/// 사용자에게만 터지는 타입 오류가 안 잡힌다. 실제로 서류 체크리스트·혜택 탭이
/// 그렇게 죽고 있었다.
Map<String, dynamic> filledProfile(String userType) => {
      'user_type': userType,
      'gross_income': 42000000.0,
      'age': 34,
      'military_months': 18,
      'dependents': 2,
      'disabled_dependent_count': 1,
      'children_count_total': 2,
      'children_count_credit': 2,
      'newborn_count': 1,
      'newborn_year': DateTime.now().year,
      'occupation_code': '940306',
      'prior_year_income': 30000000.0,
      'property_value': 50000000.0,
      'monthly_rent': 600000.0,
      'yellow_umbrella': 3000000.0,
      'monthly_income': 3500000.0,
      'decided_tax': 1200000.0,
      'paid_tax': 900000.0,
      'expense_target': 2000000.0,
      'wedding_year': 2025,
      'sme_start_year': DateTime.now().year - 1,
      'pay_day': 25,
      'data_mode': 'manual',
      'is_monthly_rent': true,
      'owns_house': false,
      'owns_car': true,
      'is_married': true,
      'is_spouse_dependent': true,
      'has_spouse_disability': true,
      'has_self_disability': true,
      'has_elderly_70plus': true,
      'is_female_head': false,
      'is_single_parent': true,
      'is_sme_employee': true,
      'type_identified': true,
      'pension_enrolled': true,
      'health_enrolled': true,
      'employment_enrolled': true,
      'industrial_accident_enrolled': true,
      'is_new_business': false,
      'has_multiple_businesses': false,
    };

/// 최근 3개월치 수입·지출. 자릿수가 큰 값을 일부러 써서 긴 금액 문구가 그려지게 한다.
Future<void> seedLedger(String userType) async {
  final now = DateTime.now();
  final incomeType = userType == '프리랜서' ? '사업소득' : '급여';
  for (int back = 0; back < 3; back++) {
    final d = DateTime(now.year, now.month - back, 1);
    await dbService.insertIncomeEntry(IncomeEntry(
        id: 'sd-inc-$back', date: d, amount: 4500000, memo: '',
        incomeType: incomeType, userType: userType));
    if (userType != '직장인') {
      await dbService.insertIncomeEntry(IncomeEntry(
          id: 'sd-oth-$back', date: d, amount: 700000, memo: '',
          incomeType: '기타소득', userType: userType));
    }
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

/// 프로필 + 가계부를 심은 새 InMemory DB.
Future<void> seedRealisticUser(String userType) async {
  dbService = InMemoryDatabaseHelper();
  await dbService.initDatabase();
  await dbService.saveProfile(filledProfile(userType));
  await seedLedger(userType);
}
