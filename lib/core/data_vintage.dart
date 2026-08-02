import 'tax_engine/tax_year.dart';

/// **이 빌드의 세법·복지 데이터가 언제 원문과 대조된 것인가.**
///
/// 앱은 온디바이스라 갱신 경로가 앱 업데이트뿐이다. 사용자는 지금 보고 있는
/// 금액이 언제 값인지 알 방법이 없고, 실제로 낡아 있었다 — 53개 제도 중
/// 21개가 옛 고시 값이었다(2026-08-02 전수 대조).
///
/// 업데이트를 끝내 안 하는 사람에게도 최소한 **"이 값은 언제 것이다"**는
/// 전달돼야 한다. Play도 네트워크도 필요 없이 동작하는 마지막 방어선이다.
///
/// 갱신할 때: 혜택 카탈로그를 다시 대조하면 [checkedOn]을 그날로 올린다.
/// `test/data_vintage_test.dart`가 카탈로그의 확인일보다 뒤처지지 않는지 본다.
class DataVintage {
  const DataVintage._();

  /// 마지막으로 원문 대조를 끝낸 날 (YYYY-MM-DD).
  static const String checkedOn = '2026-08-02';

  /// 세법 계산의 기준 귀속연도.
  static int get taxYear => TaxYear.reference;

  /// "2026년 8월" — 사용자에게 보여줄 짧은 표기.
  static String get label {
    final p = checkedOn.split('-');
    return '${p[0]}년 ${int.parse(p[1])}월';
  }

  /// 고지 문구 한 줄. 계산기 하단과 업데이트 카드가 같은 문장을 쓴다.
  static String get sentence => '$taxYear년 귀속 세법 · 복지 금액은 $label 정부 원문 기준';
}
