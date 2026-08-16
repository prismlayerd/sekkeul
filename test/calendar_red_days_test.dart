import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/kr_holidays.dart';
import 'package:secul/ui/screens/expense_calendar_screen.dart';
import 'package:secul/ui/theme/app_theme.dart';

import 'support/screen_registry.dart';

/// **빨간날은 붉고, 그 색은 달력 밖으로 안 나간다.**
///
/// 이 앱은 흑백이다. 그 규율을 딱 한 곳에서만 굽혔다 — 종이 달력의 빨간날은
/// 배울 필요가 없는 관습이라서다. 굽힌 자리가 하나로 남는지 붙잡는다.
void main() {
  testWidgets('일요일과 공휴일 숫자만 붉다', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    dbService = InMemoryDatabaseHelper();
    await dbService.initDatabase();

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const ExpenseCalendarScreen(),
    ));
    await t.pumpAndSettle();

    /// 화면에 그려진 '17' 같은 날짜 숫자의 색.
    Color colorOfDay(int day) {
      final texts = t
          .widgetList<Text>(find.text('$day'))
          .where((w) => w.style?.color != null)
          .toList();
      expect(texts, isNotEmpty, reason: '$day일 칸을 못 찾았다');
      return texts.first.style!.color!;
    }

    final red = AppTheme.lightHoliday;
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;

    // 이번 달에서 처음 만나는 일요일·평일을 각각 하나씩 본다.
    // (1~12일은 다른 달의 꼬리 칸과 숫자가 겹치지 않는다 — 이 달력은
    //  앞뒤 달을 흐리게 채우지 않고 빈 칸으로 둔다.)
    int? sunday, weekday;
    for (var d = 1; d <= days && (sunday == null || weekday == null); d++) {
      final date = DateTime(now.year, now.month, d);
      final holiday = KrHolidays.isHoliday(date);
      if (date.weekday == DateTime.sunday) {
        sunday ??= d;
      } else if (date.weekday != DateTime.saturday && !holiday) {
        weekday ??= d;
      }
    }

    expect(colorOfDay(sunday!), red, reason: '일요일이 안 붉다');
    expect(colorOfDay(weekday!), isNot(red), reason: '평일까지 붉어졌다');
  });

  test('붉은색은 달력 뷰 밖으로 안 나간다', () {
    // 여기서 새는 순간 "흑백 영수증"이라는 문장이 거짓말이 된다.
    const allowed = 'lib/ui/screens/expense_calendar_screen.dart';
    final offenders = <String>[];
    for (final f in Directory('lib/ui')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final rel = f.path.replaceAll(r'\', '/');
      if (rel.endsWith('theme/app_theme.dart') || rel.endsWith(allowed)) continue;
      final src = f.readAsStringSync();
      for (final m in RegExp(r'\b(holiday\(context\)|lightHoliday|darkHoliday)\b')
          .allMatches(src)) {
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        offenders.add('$rel:$line — ${m.group(0)}');
      }
    }
    expect(offenders, isEmpty,
        reason: '빨간날 색은 달력 뷰 전용입니다.\n${offenders.join('\n')}');
  });
}
