import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';

enum PinMode { setup, confirm, verify }

class PinScreen extends StatefulWidget {
  final PinMode mode;
  final VoidCallback? onSuccess;

  const PinScreen({
    super.key,
    required this.mode,
    this.onSuccess,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _secureStorage = SecureStorageService();
  String _enteredPin = '';
  String? _firstPin; // used during setup for confirmation
  bool _isConfirmStep = false;
  String _title = '';
  String _subtitle = '';
  bool _hasError = false;
  int _attempts = 0;

  // Timed lockout state — replaces permanent lockout.
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;
  int _lockoutSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _updateTitle();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  bool get _isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  void _startLockout() {
    _lockoutUntil = DateTime.now().add(const Duration(minutes: 30));
    _lockoutSecondsRemaining = 30 * 60;
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        t.cancel();
        setState(() { _lockoutUntil = null; _lockoutSecondsRemaining = 0; _attempts = 0; });
      } else {
        setState(() => _lockoutSecondsRemaining = remaining);
      }
    });
    setState(() {});
  }

  String get _lockoutMessage {
    final m = _lockoutSecondsRemaining ~/ 60;
    final s = _lockoutSecondsRemaining % 60;
    return 'Too many attempts. Try again in $m:${s.toString().padLeft(2, '0')}';
  }

  void _updateTitle() {
    if (widget.mode == PinMode.setup) {
      if (!_isConfirmStep) {
        _title = 'Create PIN';
        _subtitle = 'Enter a 4-digit PIN';
      } else {
        _title = 'Confirm PIN';
        _subtitle = 'Re-enter your PIN';
      }
    } else {
      _title = 'Enter PIN';
      _subtitle = 'Unlock with your 4-digit PIN';
    }
  }

  Future<String> _hashPin(String pin) {
    return _secureStorage.hashPin(pin);
  }

  void _onDigitPressed(int digit) {
    if (_enteredPin.length >= 4) return;

    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _enteredPin += digit.toString();
    });

    if (_enteredPin.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), _handlePinComplete);
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _handlePinComplete() async {
    if (widget.mode == PinMode.setup || widget.mode == PinMode.confirm) {
      if (!_isConfirmStep) {
        // First entry — ask to confirm
        _firstPin = _enteredPin;
        setState(() {
          _enteredPin = '';
          _isConfirmStep = true;
          _updateTitle();
        });
      } else {
        // Confirm step — check match
        if (_enteredPin == _firstPin) {
          await _secureStorage.savePinHash(await _hashPin(_enteredPin));
          await _secureStorage.saveLockMethod('pin');
          if (mounted) {
            widget.onSuccess?.call();
            Navigator.of(context).pop(true);
          }
        } else {
          setState(() {
            _hasError = true;
            _enteredPin = '';
            _isConfirmStep = false;
            _firstPin = null;
            _subtitle = 'PINs didn\'t match. Try again.';
          });
        }
      }
    } else {
      // Verify mode
      final storedHash = await _secureStorage.getPinHash();
      final enteredHash = await _hashPin(_enteredPin);
      if (storedHash != null && enteredHash == storedHash) {
        if (mounted) {
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
        }
      } else {
        HapticFeedback.vibrate();
        _attempts++;
        if (_attempts >= 5) {
          _startLockout();
        } else {
          setState(() {
            _hasError = true;
            _enteredPin = '';
            _subtitle = _attempts >= 3
                ? 'Too many attempts. Use email login below.'
                : 'Wrong PIN. Try again.';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Icon(Icons.close, size: 24, color: colors.textMuted),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const Spacer(flex: 2),

            // Lock icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.of(context).accent.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 28,
                color: AppColors.of(context).accent,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              _title,
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.of(context).textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLockedOut ? _lockoutMessage : _subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: (_hasError || _isLockedOut)
                    ? AppColors.error
                    : colors.textSecondary,
              ),
            ),
            const SizedBox(height: 36),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _enteredPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasError
                        ? AppColors.error
                        : filled
                            ? AppColors.of(context).accent
                            : Colors.transparent,
                    border: Border.all(
                      color: _hasError
                          ? AppColors.error
                          : filled
                              ? AppColors.of(context).accent
                              : AppColors.of(context).border,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const Spacer(flex: 1),

            // Number pad (disabled during lockout)
            IgnorePointer(
              ignoring: _isLockedOut,
              child: Opacity(
                opacity: _isLockedOut ? 0.4 : 1.0,
                child: _buildNumberPad(),
              ),
            ),
            const SizedBox(height: 16),

            // Email login fallback (shown after 3 wrong attempts or during lockout)
            if (widget.mode == PinMode.verify &&
                (_attempts >= 3 || _isLockedOut))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'Use email login instead',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppColors.of(context).accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          for (int row = 0; row < 4; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (row < 3)
                    for (int col = 0; col < 3; col++)
                      _buildDigitButton(row * 3 + col + 1),
                  if (row == 3) ...[
                    const SizedBox(width: 72, height: 72),
                    _buildDigitButton(0),
                    _buildBackspaceButton(),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDigitButton(int digit) {
    return GestureDetector(
      onTap: () => _onDigitPressed(digit),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.of(context).card,
          border: Border.all(color: AppColors.of(context).border),
        ),
        alignment: Alignment.center,
        child: Text(
          '$digit',
          style: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: AppColors.of(context).textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return GestureDetector(
      onTap: _onBackspace,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Icon(
          Icons.backspace_outlined,
          size: 24,
          color: AppColors.of(context).textMuted,
        ),
      ),
    );
  }
}
