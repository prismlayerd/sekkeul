import '../security/crypto_helper.dart';

/// S-2: 평문 DB → SQLCipher 암호화 DB 이전 시, 레거시 스키마(v1~v35)에서
/// 필드 단위로 CryptoHelper.encrypt() 되어 있던 컬럼들을 평문으로 복호화한다.
/// DB 파일 자체가 SQLCipher로 암호화되므로 필드 단위 암호화는 더 이상 필요 없다.
/// 암호화되지 않은 테이블/컬럼은 그대로 복사한다.
Map<String, Object?> decryptLegacyRowForTable(String table, Map<String, Object?> row) {
  final out = Map<String, Object?>.from(row);
  switch (table) {
    case 'expenses':
      out['amount'] = _safeDecrypt(row['amount']);
      out['content'] = _safeDecrypt(row['content']);
      out['category'] = _safeDecrypt(row['category']);
      out['payment_method'] = _safeDecrypt(row['payment_method']);
      break;
    case 'income_entries':
      out['amount'] = _safeDecrypt(row['amount']);
      out['memo'] = _safeDecrypt(row['memo']);
      out['income_type'] = _safeDecrypt(row['income_type']);
      break;
    case 'annual_records':
      out['payload'] = _safeDecrypt(row['payload']);
      break;
  }
  return out;
}

String? _safeDecrypt(Object? value) {
  if (value == null) return null;
  final s = value as String;
  if (s.isEmpty) return s;
  try {
    return CryptoHelper.decrypt(s);
  } catch (_) {
    return s; // 이미 평문이거나 손상된 값은 그대로 보존(데이터 유실 방지)
  }
}
