import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/db_helper.dart';

/// **오류가 나면 기기 안에 남는가.**
///
/// 앱은 크래시 리포팅 도구를 쓰지 않는다(INTERNET 권한이 없다). 대신 `main.dart`가
/// `FlutterError.onError`와 `runZonedGuarded`에서 `insertErrorLog`를 부르고,
/// 설정 화면의 "오류 기록 내보내기"가 사용자 손으로 그것을 꺼낸다.
///
/// 이 검사는 그 통로의 양 끝을 본다 — 넣으면 나오는가, 그리고 무한정 쌓이지 않는가.
void main() {
  test('오류를 넣으면 최신순으로 다시 나온다', () async {
    final db = InMemoryDatabaseHelper();

    await db.insertErrorLog('첫 번째 예외', 'stack A');
    await db.insertErrorLog('두 번째 예외', 'stack B');

    final logs = await db.getErrorLogs();
    expect(logs.length, 2);
    expect(logs.first['message'], '두 번째 예외');
    expect(logs.first['stack_trace'], 'stack B');
    expect(logs.first['occurred_at'], isNotNull);
  });

  test('100건을 넘으면 오래된 것부터 버린다', () async {
    final db = InMemoryDatabaseHelper();

    for (var i = 1; i <= 120; i++) {
      await db.insertErrorLog('예외 $i', 'stack $i');
    }

    final logs = await db.getErrorLogs();
    expect(logs.length, 100, reason: '기기 저장소를 무한정 먹으면 안 된다');
    expect(logs.first['message'], '예외 120');
    expect(logs.last['message'], '예외 21');
  });
}
