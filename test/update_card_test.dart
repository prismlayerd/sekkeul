import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data_vintage.dart';
import 'package:secul/core/update_service.dart';
import 'package:secul/ui/components/update_card.dart';

/// 업데이트 카드는 Play가 있는 실기기에서만 뜬다. 로컬에서 눈으로 볼 수 없으므로
/// 상태별로 직접 그려서 문구와 레이아웃을 확인한다.
void main() {
  String plain(WidgetTester t) {
    final b = StringBuffer();
    for (final w in t.allWidgets) {
      if (w is Text) {
        b.write((w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll('⁠', ''));
        b.write('\n');
      }
    }
    return b.toString();
  }

  Future<void> pump(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(375, 812);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));
    await t.pump();
  }

  tearDown(() => updateService.reset());

  testWidgets('업데이트가 없으면 아무것도 그리지 않는다', (t) async {
    updateService.debugSet(UpdateState.none);
    await pump(t, const UpdateCard());
    expect(find.byType(Text), findsNothing,
        reason: '홈에 빈 자리를 남기면 안 된다');
  });

  testWidgets('받을 수 있을 때 이유와 기준 시점을 말한다', (t) async {
    updateService.debugSet(UpdateState.flexible);
    await pump(t, const UpdateCard());
    final text = plain(t);
    // Google 대화상자는 "업데이트 사용 가능"이라고만 한다. 이유는 우리가 말한다.
    expect(text, contains('세법·복지 기준이 바뀐 버전이 있어요'));
    expect(text, contains(DataVintage.label),
        reason: '지금 보는 값이 언제 것인지 함께 알려야 한다');
    expect(text, contains('지금 받기'));
  });

  testWidgets('다 받으면 재시작을 권한다', (t) async {
    updateService.debugSet(UpdateState.readyToInstall);
    await pump(t, const UpdateCard());
    final text = plain(t);
    expect(text, contains('새 버전을 받았어요'));
    expect(text, contains('다시 시작하기'));
  });

  testWidgets('좁은 화면에서 넘치지 않는다', (t) async {
    // 라벨이 길어 Row가 넘쳤던 전례가 있다(연말정산 공제 내역행).
    for (final s in [UpdateState.flexible, UpdateState.downloading,
                     UpdateState.readyToInstall]) {
      updateService.debugSet(s);
      await pump(t, const UpdateCard());
      expect(t.takeException(), isNull, reason: '$s 상태에서 레이아웃이 깨진다');
    }
  });

}
