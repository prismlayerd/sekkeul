import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';
import 'package:secul/main.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// **준비가 실패해도 화면은 떠야 한다.**
///
/// `main()`은 알림 준비 → DB 열기 → 테마 읽기를 거친 뒤 `runApp`을 부른다.
/// 예전엔 이 셋 중 하나가 던지면 `runApp`에 닿지 못해 앱이 통째로 안 떴다 —
/// 기기마다 흰 화면이 되던 자리이고, DB가 안 열렸으니 오류 기록조차 안 남았다.
///
/// 이 검사는 **DB가 죽은 상태에서도 앱이 그려지는지** 본다.
void main() {
  // 예약 알림 경로가 tz.local에서 터지면 시작 검사가 아니라 환경을 보게 된다.
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  testWidgets('DB가 죽어 있어도 앱 화면은 뜬다', (tester) async {
    final db = InMemoryDatabaseHelper();
    await db.close(); // 준비 실패 흉내 — 모든 읽기가 빈 값을 돌려준다
    dbService = db;

    // 이 검사가 보는 건 "그려지느냐" 하나다. 알림 플러그인 미초기화나
    // 기존 ListTile 경고까지 여기서 잡으면 시작 검사가 아니라 다른 걸 보게 된다.
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(const SeculApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
