import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/screens/onboarding_screen.dart';

/// 유형을 다시 잡으러 들어온 사람은 자기 유형이 체크된 채로 시작해야 한다 —
/// 매번 처음부터 자기 소득을 다시 찾게 하지 않는다.
void main() {
  testWidgets('현재 유형이 미리 체크돼 판정이 바로 떠 있다', (tester) async {
    for (final type in ['직장인', 'N잡러', '프리랜서']) {
      await tester.pumpWidget(MaterialApp(
        // 유형마다 키를 달리해야 화면이 새로 만들어진다(안 그러면 첫 유형 상태가 남는다).
        home: OnboardingScreen(key: ValueKey(type), returnResult: true, currentType: type),
      ));
      await tester.pumpAndSettle();
      expect(find.text(type), findsOneWidget, reason: '$type이 판정에 안 떠 있다');
    }
  });

  testWidgets('처음 오는 사람은 아무것도 안 골라진 채로 시작한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pumpAndSettle();
    for (final type in ['직장인', 'N잡러', '프리랜서']) {
      expect(find.text(type), findsNothing, reason: '고른 게 없는데 $type이 떴다');
    }
  });
}
