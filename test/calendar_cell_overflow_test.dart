import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/expense_item.dart';
import 'package:secul/core/data/income_entry.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/screen_registry.dart';

/// **달력 칸이 넘치지 않는다.**
///
/// 실기기에서 하루에 수익 + 결제수단 셋이 다 있는 날의 칸이 20픽셀 넘쳤다.
/// 넘침은 릴리스 빌드에서 빨간 줄 대신 **잘린 글자**로 나타나서, 금액이
/// 조용히 안 보인다. 가장 빽빽한 하루를 만들어 놓고 붙잡는다.
void main() {
  testWidgets('한 날에 수익·카드·체크·기타가 다 있어도 칸이 안 넘친다', (t) async {
    // 실기기에서 넘친 상황은 달력 아래 적립 카드가 펼쳐져 그리드가 눌린
    // 상태였다. 세로를 줄여 그 압박을 그대로 만든다.
    t.view.physicalSize = const Size(390, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();

    final day = DateTime.now();
    await dbService.insertIncomeEntry(IncomeEntry(
      id: 'i1',
      date: day,
      amount: 3500000,
      memo: '',
      incomeType: '급여',
      userType: '직장인',
    ));
    var n = 0;
    for (final pm in ['신용카드', '체크+현금', '기타']) {
      await dbService.insertExpense(ExpenseItem(
        id: 'e${n++}',
        date: day,
        amount: 238000,
        content: '',
        category: '기타',
        paymentMethod: pm,
        userType: '직장인',
      ));
    }

    final overflows = <String>[];
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exception.toString();
      if (s.contains('overflowed')) overflows.add(s.split('\n').first);
    };
    addTearDown(() => FlutterError.onError = prev);

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const ExpenseCalendarScreen(),
    ));
    await t.pumpAndSettle();

    expect(overflows, isEmpty,
        reason: '가장 빽빽한 날의 칸이 넘친다 — 릴리스에서는 금액이 잘려 안 보인다.\n'
            '${overflows.join('\n')}');

    // ── 확대(2단계) — 금액이 칸마다 한 줄씩 들어가는 상태 ──
    // 실기기에서 넘친 건 여기였다. 두 손가락을 벌려 실제 경로로 들어간다.
    final center = t.getCenter(find.byType(ExpenseCalendarScreen));
    final a = await t.startGesture(center - const Offset(30, 0));
    final b = await t.startGesture(center + const Offset(30, 0));
    await t.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 6; i++) {
      await a.moveBy(const Offset(-14, 0));
      await b.moveBy(const Offset(14, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await t.pumpAndSettle();

    expect(overflows, isEmpty,
        reason: '확대한 칸이 넘친다 — 금액 줄이 칸보다 크다.\n${overflows.join('\n')}');
  });
}
