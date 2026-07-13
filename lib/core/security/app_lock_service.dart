import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../data/db_helper.dart';

/// S-3 앱 잠금 — 생체 인증(지문/Face ID) + PIN 폴백. 기본 off, 설정에서 켬.
/// 앱이 재개(resumed)될 때 잠금 화면이 인증을 요구한다.
class AppLockService {
  static const _storage = FlutterSecureStorage();
  static const _pinKey = 'sekkeul_app_lock_pin';
  static const _appStateKey = 'app_lock_enabled';

  final _localAuth = LocalAuthentication();

  Future<bool> isEnabled() async {
    final v = await dbService.getAppState(_appStateKey);
    return v == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    await dbService.setAppState(_appStateKey, enabled ? 'true' : 'false');
    if (!enabled) await _storage.delete(key: _pinKey);
  }

  Future<bool> hasPin() async {
    final v = await _storage.read(key: _pinKey);
    return v != null && v.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final saved = await _storage.read(key: _pinKey);
    return saved != null && saved == pin;
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: '세끌 잠금 해제',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}

final appLockService = AppLockService();
