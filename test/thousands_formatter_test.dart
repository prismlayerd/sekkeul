import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/ui/components/amount_field.dart';

/// 금액칸 천 단위 콤마.
///
/// 종전 방식(onChanged에서 컨트롤러를 통째로 덮어쓰기)은 커서가 늘 맨 뒤로 튀어서
/// 중간 숫자를 고칠 수 없었다. 포매터로 옮기면서 커서를 지켜야 한다 — 그 회귀를 잡는다.
void main() {
  const f = ThousandsFormatter();

  TextEditingValue type(String before, String after, {int? caret}) => f.formatEditUpdate(
        TextEditingValue(text: before),
        TextEditingValue(
          text: after,
          selection: TextSelection.collapsed(offset: caret ?? after.length),
        ),
      );

  test('세 자리마다 콤마가 붙는다', () {
    expect(type('', '1000').text, '1,000');
    expect(type('', '1234567').text, '1,234,567');
    expect(type('', '100').text, '100');
  });

  test('숫자가 아닌 글자는 버린다', () {
    expect(type('', '1,0a0b0').text, '1,000');
  });

  test('빈 값은 빈 값으로 둔다 — 0을 강제로 넣지 않는다', () {
    expect(type('1,000', '').text, '');
  });

  test('맨 뒤에 이어 칠 때 커서가 끝에 남는다', () {
    final v = type('1,000', '1,0000');
    expect(v.text, '10,000');
    expect(v.selection.baseOffset, v.text.length);
  });

  test('중간을 고쳐도 커서가 그 자리에 남는다', () {
    // "1,234"에서 앞자리 뒤(1 다음)에 9를 넣어 "19,234" — 커서는 9 뒤여야 한다.
    final v = type('1,234', '19,234', caret: 2);
    expect(v.text, '19,234');
    // 커서 앞의 숫자는 '1','9' 두 개 → 콤마 앞자리인 offset 2
    expect(v.selection.baseOffset, 2);
  });

  test('앞자리를 지워도 커서가 앞쪽에 남는다', () {
    // "12,345"에서 맨 앞 1을 지워 "2,345" — 커서는 맨 앞이어야 한다.
    final v = type('12,345', '2,345', caret: 0);
    expect(v.text, '2,345');
    expect(v.selection.baseOffset, 0);
  });
}
