import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';

enum PatternMode { setup, verify }

class PatternScreen extends StatefulWidget {
  final PatternMode mode;
  final VoidCallback? onSuccess;

  const PatternScreen({
    super.key,
    required this.mode,
    this.onSuccess,
  });

  @override
  State<PatternScreen> createState() => _PatternScreenState();
}

class _PatternScreenState extends State<PatternScreen> {
  final _secureStorage = SecureStorageService();
  final List<int> _selectedDots = [];
  String? _firstPattern;
  bool _isConfirmStep = false;
  String _title = '';
  String _subtitle = '';
  bool _hasError = false;
  int _attempts = 0;
  int? _activeDot;

  // Timed lockout state
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;
  int _lockoutSecondsRemaining = 0;

  // Grid layout
  static const int _gridSize = 3;
  static const double _dotRadius = 28;
  static const double _gridSpacing = 80;

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
    if (widget.mode == PatternMode.setup) {
      if (!_isConfirmStep) {
        _title = 'Create Pattern';
        _subtitle = 'Connect at least 4 dots';
      } else {
        _title = 'Confirm Pattern';
        _subtitle = 'Draw your pattern again';
      }
    } else {
      _title = 'Draw Pattern';
      _subtitle = 'Unlock with your pattern';
    }
  }

  Future<String> _hashPattern(List<int> pattern) {
    return _secureStorage.hashPattern(pattern);
  }

  Offset _dotCenter(int index) {
    final row = index ~/ _gridSize;
    final col = index % _gridSize;
    const totalWidth = (_gridSize - 1) * _gridSpacing;
    final startX = -totalWidth / 2;
    final startY = -totalWidth / 2;
    return Offset(
      startX + col * _gridSpacing,
      startY + row * _gridSpacing,
    );
  }

  void _onDotSelected(int index) {
    if (_selectedDots.contains(index)) return;
    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _selectedDots.add(index);
      _activeDot = index;
    });
  }

  Future<void> _onPatternComplete() async {
    if (_selectedDots.length < 4) {
      setState(() {
        _hasError = true;
        _subtitle = 'Connect at least 4 dots';
        _selectedDots.clear();
        _activeDot = null;
      });
      return;
    }

    if (widget.mode == PatternMode.setup) {
      if (!_isConfirmStep) {
        _firstPattern = _selectedDots.join('-');
        setState(() {
          _selectedDots.clear();
          _activeDot = null;
          _isConfirmStep = true;
          _updateTitle();
        });
      } else {
        final currentPattern = _selectedDots.join('-');
        if (currentPattern == _firstPattern) {
          await _secureStorage.savePatternHash(await _hashPattern(_selectedDots));
          await _secureStorage.saveLockMethod('pattern');
          if (mounted) {
            widget.onSuccess?.call();
            Navigator.of(context).pop(true);
          }
        } else {
          setState(() {
            _hasError = true;
            _selectedDots.clear();
            _activeDot = null;
            _isConfirmStep = false;
            _firstPattern = null;
            _subtitle = 'Patterns didn\'t match. Try again.';
          });
        }
      }
    } else {
      // Verify mode
      final storedHash = await _secureStorage.getPatternHash();
      final enteredHash = await _hashPattern(_selectedDots);
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
          setState(() {
            _selectedDots.clear();
            _activeDot = null;
          });
        } else {
          setState(() {
            _hasError = true;
            _selectedDots.clear();
            _activeDot = null;
            _subtitle = _attempts >= 3
                ? 'Too many attempts. Use email login below.'
                : 'Wrong pattern. Try again.';
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
                Icons.pattern,
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
            const Spacer(flex: 1),

            // Pattern grid (disabled during lockout)
            IgnorePointer(
              ignoring: _isLockedOut,
              child: Opacity(
                opacity: _isLockedOut ? 0.4 : 1.0,
                child: _buildPatternGrid(),
              ),
            ),
            const SizedBox(height: 16),

            // Email login fallback
            if (widget.mode == PatternMode.verify &&
                (_attempts >= 3 || _isLockedOut))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
              ),

            // Reset / Confirm buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedDots.clear();
                          _activeDot = null;
                          _hasError = false;
                          _updateTitle();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.of(context).textSecondary,
                        side: BorderSide(color: AppColors.of(context).border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Reset',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedDots.length >= 4 ? _onPatternComplete : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.textPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.of(context).accent.withAlpha(80),
                        disabledForegroundColor: colors.textSecondary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Confirm',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternGrid() {
    return SizedBox(
      width: (_gridSize - 1) * _gridSpacing + _dotRadius * 2 + 32,
      height: (_gridSize - 1) * _gridSpacing + _dotRadius * 2 + 32,
      child: GestureDetector(
        onPanUpdate: (details) {
          const center = Offset(
            ((_gridSize - 1) * _gridSpacing + _dotRadius * 2 + 32) / 2,
            ((_gridSize - 1) * _gridSpacing + _dotRadius * 2 + 32) / 2,
          );
          for (int i = 0; i < _gridSize * _gridSize; i++) {
            final dotPos = _dotCenter(i) + center;
            if ((details.localPosition - dotPos).distance < _dotRadius + 10) {
              _onDotSelected(i);
              break;
            }
          }
        },
        onPanEnd: (_) {
          if (_selectedDots.length >= 4) {
            _onPatternComplete();
          } else if (_selectedDots.isNotEmpty) {
            setState(() {
              _hasError = true;
              _subtitle = 'Connect at least 4 dots';
              _selectedDots.clear();
              _activeDot = null;
            });
          }
        },
        child: CustomPaint(
          painter: _PatternPainter(
            selectedDots: _selectedDots,
            gridSize: _gridSize,
            gridSpacing: _gridSpacing,
            dotRadius: _dotRadius,
            hasError: _hasError,
            primaryColor: AppColors.of(context).accent,
            errorColor: AppColors.error,
            borderColor: AppColors.of(context).border,
          ),
          child: Container(),
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final List<int> selectedDots;
  final int gridSize;
  final double gridSpacing;
  final double dotRadius;
  final bool hasError;
  final Color primaryColor;
  final Color errorColor;
  final Color borderColor;

  _PatternPainter({
    required this.selectedDots,
    required this.gridSize,
    required this.gridSpacing,
    required this.dotRadius,
    required this.hasError,
    required this.primaryColor,
    required this.errorColor,
    required this.borderColor,
  });

  Offset _dotCenter(int index, Size size) {
    final row = index ~/ gridSize;
    final col = index % gridSize;
    final totalWidth = (gridSize - 1) * gridSpacing;
    final startX = (size.width - totalWidth) / 2;
    final startY = (size.height - totalWidth) / 2;
    return Offset(
      startX + col * gridSpacing,
      startY + row * gridSpacing,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lineColor = hasError ? errorColor : primaryColor;
    final dotColor = hasError ? errorColor : primaryColor;

    // Draw connecting lines
    if (selectedDots.length > 1) {
      final linePaint = Paint()
        ..color = lineColor.withAlpha(128)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < selectedDots.length - 1; i++) {
        canvas.drawLine(
          _dotCenter(selectedDots[i], size),
          _dotCenter(selectedDots[i + 1], size),
          linePaint,
        );
      }
    }

    // Draw dots
    for (int i = 0; i < gridSize * gridSize; i++) {
      final center = _dotCenter(i, size);
      final isSelected = selectedDots.contains(i);

      // Outer ring
      final outerPaint = Paint()
        ..color = isSelected ? dotColor : borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, dotRadius / 2 + 6, outerPaint);

      // Inner dot
      final innerPaint = Paint()
        ..color = isSelected ? dotColor : borderColor;
      canvas.drawCircle(center, isSelected ? 8 : 5, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.selectedDots != selectedDots ||
        oldDelegate.hasError != hasError;
  }
}
