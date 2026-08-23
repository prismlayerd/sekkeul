import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/year_deductions.dart';
import 'package:secul/ui/screens/home_screen.dart';
import 'package:secul/ui/screens/home/missable_deduction_section.dart';
import 'package:secul/ui/screens/year_deduction_screen.dart';
import 'package:secul/ui/screens/year_end_tax_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **02에서 가는 길이 실제로 있는가.**
///
/// 「올해 쌓인 예상 환급」은 카드공제만 센 숫자다. 옆에 아무 말이 없으면 그게
/// 올해 받을 전부로 읽힌다. 예전에 이 목록은 04 세무 도구 → 「빠진 공제 항목
/// 찾기」 안에만 있었고 02에서 가는 길이 없었다.
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  testWidgets('04 절이 홈 1장에 있고, 02는 카드만 말한다', (t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const HomeScreen()));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }

    expect(find.byType(MissableDeductionSection), findsOneWidget);
    expect(findKo('놓치기 쉬운 공제'), findsWidgets);
    // 02의 링크는 04가 가져갔다 — 상시 입구가 둘이면 서로를 모른다.
    expect(findKo('카드 말고도 받을 게 더 있어요'), findsNothing);
  });

  testWidgets('프리랜서의 04는 장부 만들기다', (t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('프리랜서');
    await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const HomeScreen()));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }

    // 의료비·교육비·기부금·월세는 §59의4가 근로소득자 전용이라 남는 게 없다.
    expect(findKo('장부 만들기'), findsWidgets);
    expect(findKo('놓치기 쉬운 공제'), findsNothing);
  });

  testWidgets('화면이 프로필에 맞는 항목만 그린다', (t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    final p = await dbService.getProfile() ?? {};
    await dbService.saveProfile({
      ...p,
      'residence_type': '자가',
      'owns_house': true,
      'is_monthly_rent': false,
      'is_household_head': true,
    });

    await t.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const YearDeductionScreen()));
    await t.pumpAndSettle();

    expect(findKo('의료비'), findsWidgets);
    expect(findKo('월세액'), findsNothing, reason: '자가인 사람에게 월세 공제를 권하면 사고다');
    expect(findKo('전세대출 원리금'), findsNothing);
    expect(findKo('주택청약저축'), findsNothing);
  });

  testWidgets('연말정산 진단은 올해 것만, 공제 대상만 센다', (t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await seedRealisticUser('직장인');
    final year = DateTime.now().year;
    for (final e in [
      (DateTime(year, 3, 2), 1000000, '신용카드'),
      (DateTime(year - 1, 3, 2), 5000000, '신용카드'), // 작년 — 세면 안 된다
      (DateTime(year, 4, 2), 700000, '기타'),          // 영수증 없음 — 공제 대상 아님
    ]) {
      await dbService.insertExpense(ExpenseItem(
        id: 'x${e.$1.year}${e.$1.month}${e.$3}',
        date: e.$1,
        amount: e.$2,
        content: '',
        category: '기타',
        paymentMethod: e.$3,
        userType: '직장인',
      ));
    }

    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const YearEndTaxScreen(userType: '직장인')));
    await t.pumpAndSettle();

    final ctrls = t
        .widgetList<TextField>(find.byType(TextField))
        .map((w) => w.controller?.text ?? '')
        .toList();
    expect(ctrls.any((c) => c.contains('5,000,000') || c.contains('6,000,000')),
        isFalse,
        reason: '작년 지출이 올해 카드 사용액에 섞였다');
    expect(ctrls.any((c) => c.contains('700,000')), isFalse,
        reason: '「기타」 결제수단은 카드공제 대상이 아니다');
  });

  test('저장한 값은 그대로 돌아오고, 0원은 남지 않는다', () async {
    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();
    await YearDeductions.save(2026, {'medical': 1200000, 'education': 0});
    final back = await YearDeductions.load(2026);
    expect(back, {'medical': 1200000});
  });
}
