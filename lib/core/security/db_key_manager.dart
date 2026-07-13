import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SQLCipher DB 암호화 키 — Android Keystore/iOS Keychain 백엔드(flutter_secure_storage)에
/// 기기 내부에서만 생성·보관. 서버 전송 없음.
class DbKeyManager {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'sekkeul_db_key_v1';

  static Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) return existing;
    final key = _generateRandomKey();
    await _storage.write(key: _keyName, value: key);
    return key;
  }

  static String _generateRandomKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }
}
