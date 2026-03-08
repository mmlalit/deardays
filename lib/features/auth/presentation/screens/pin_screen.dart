import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();
    _updateTitle();
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

  static String _hashPin(String pin) {
    return sha256.convert(utf8.encode('deardays_pin_$pin')).toString();
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
          await _secureStorage.savePinHash(_hashPin(_enteredPin));
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
      if (storedHash != null && _hashPin(_enteredPin) == storedHash) {
        if (mounted) {
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
        }
      } else {
        _attempts++;
        setState(() {
          _hasError = true;
          _enteredPin = '';
          _subtitle = _attempts >= 3
              ? 'Too many attempts. Use email login.'
              : 'Wrong PIN. Try again.';
        });

        if (_attempts >= 5 && mounted) {
          Navigator.of(context).pop(false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    child: const Icon(Icons.close, size: 24, color: Colors.black54),
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
                color: AppColors.primary.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              _title,
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitle,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: _hasError ? Colors.red.shade600 : AppColors.textSecondary,
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
                        ? Colors.red.shade400
                        : filled
                            ? AppColors.primary
                            : Colors.transparent,
                    border: Border.all(
                      color: _hasError
                          ? Colors.red.shade400
                          : filled
                              ? AppColors.primary
                              : AppColors.border,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const Spacer(flex: 1),

            // Number pad
            _buildNumberPad(),
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
          color: Colors.white,
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          '$digit',
          style: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return GestureDetector(
      onTap: _onBackspace,
      child: const SizedBox(
        width: 72,
        height: 72,
        child: Icon(
          Icons.backspace_outlined,
          size: 24,
          color: Colors.black54,
        ),
      ),
    );
  }
}
