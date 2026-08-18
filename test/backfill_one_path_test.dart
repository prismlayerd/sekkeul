import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/ui/screens/home_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/ko_finder.dart';
import 'support/screen_registry.dart';

/// **채우라는 말은 한 번만 나온다.**
///
/// 소급 입력 화면이 둘이다. 직장인·N잡러는 카드 공제 때문에 다섯 갈래가 필요해
/// 전용 화면([CardBackfillScreen])을 쓰고, 프리랜서는 카드 공제 대상이 아니라
/// 매출·경비를 받는 옛 화면을 쓴다.
///
/// 두 배너가 같이 뜨면 사용자는 무엇을 채워야 하는지 모른다. 유형마다 **하나만**
/// 떠야 한다.
void main() {
  final year = DateTime.now().year;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  Future<void> pumpHome(WidgetTester t, String type) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await seedRealisticUser(type);
    // 연중에 깐 사람 — 씨더가 켜 둔 '다 채웠음'을 지운다.
    await dbService.setAppState('backfill_done_$year', '');
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    ));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('직장인에게는 옛 배너가 안 뜬다', (t) async {
    await pumpHome(t, '직장인');
    expect(findKo('매출과 경비를 채우면'), findsNothing,
        reason: '직장인에게 프리랜서용 소급 입력을 권하고 있다');
    expect(findKo('기록이 없어 아직 계산할 수 없어요'), findsWidgets,
        reason: '직장인에게는 카드 다섯 갈래 쪽으로 안내해야 한다');
  });

  testWidgets('프리랜서에게는 카드 문턱 얘기가 안 나온다', (t) async {
    await pumpHome(t, '프리랜서');
    // 카드 공제는 근로소득자 전용이다(조특법 §126의2).
    expect(findKo('카드 공제 문턱'), findsNothing,
        reason: '프리랜서에게 받을 수 없는 공제를 보여주고 있다');
  });
}
