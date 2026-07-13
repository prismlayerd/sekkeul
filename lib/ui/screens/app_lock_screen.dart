import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../core/security/app_lock_service.dart';

/// S-3 앱 잠금 화면 — 재개(resumed) 시 전체 화면으로 덮어 인증을 요구한다.
/// 바텀시트 금지 원칙에 따라 PIN 입력도 같은 화면 내 인라인으로 둔다.
class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _biometricAvailable = false;
  bool _checking = true;
  String _pinInput = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final canBio = await appLockService.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = canBio;
      _checking = false;
    });
    if (canBio) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final ok = await appLockService.authenticateWithBiometrics();
    if (ok && mounted) widget.onUnlocked();
  }

  Future<void> _submitPin() async {
    final ok = await appLockService.verifyPin(_pinInput);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = 'PIN이 일치하지 않아요';
        _pinInput = '';
      });
    }
  }

  void _onKeyTap(String digit) {
    if (_pinInput.length >= 6) return;
    setState(() {
      _error = null;
      _pinInput += digit;
    });
    if (_pinInput.length >= 4) _submitPin();
  }

  void _onBackspace() {
    if (_pinInput.isEmpty) return;
    setState(() => _pinInput = _pinInput.substring(0, _pinInput.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final bg = AppTheme.backgroundColor(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: _checking
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 44, color: ink),
                      const SizedBox(height: 16),
                      Text('세끌 잠금', style: AppTheme.serif(28, ink)),
                      const SizedBox(height: 8),
                      Text('PIN을 입력하세요', style: AppTheme.sans(13, sub)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) {
                          final filled = i < _pinInput.length;
                          return Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? AppTheme.accentColor(context) : Colors.transparent,
                              border: Border.all(color: AppTheme.lineStrong(context), width: 1),
                            ),
                          );
                        }),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: AppTheme.sans(12, AppTheme.colorDanger)),
                      ],
                      const SizedBox(height: 28),
                      _buildKeypad(ink, sub),
                      if (_biometricAvailable) ...[
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _tryBiometric,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fingerprint_rounded, size: 18, color: AppTheme.accentColor(context)),
                              const SizedBox(width: 8),
                              Text('생체 인증으로 잠금 해제',
                                  style: AppTheme.sans(13, AppTheme.accentColor(context), weight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildKeypad(Color ink, Color sub) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) return const SizedBox(width: 56, height: 56);
              return GestureDetector(
                onTap: () => key == '⌫' ? _onBackspace() : _onKeyTap(key),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: key == '⌫'
                        ? Icon(Icons.backspace_outlined, size: 20, color: sub)
                        : Text(key, style: AppTheme.serif(22, ink)),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
