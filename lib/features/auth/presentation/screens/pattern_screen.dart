import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Grid layout
  static const int _gridSize = 3;
  static const double _dotRadius = 28;
  static const double _gridSpacing = 80;

  @override
  void initState() {
    super.initState();
    _updateTitle();
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

  static String _hashPattern(List<int> pattern) {
    final str = pattern.join('-');
    return sha256.convert(utf8.encode('deardays_pattern_$str')).toString();
  }

  Offset _dotCenter(int index) {
    final row = index ~/ _gridSize;
    final col = index % _gridSize;
    final totalWidth = (_gridSize - 1) * _gridSpacing;
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
          await _secureStorage.savePatternHash(_hashPattern(_selectedDots));
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
      if (storedHash != null && _hashPattern(_selectedDots) == storedHash) {
        if (mounted) {
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
        }
      } else {
        _attempts++;
        setState(() {
          _hasError = true;
          _selectedDots.clear();
          _activeDot = null;
          _subtitle = _attempts >= 3
              ? 'Too many attempts. Use email login.'
              : 'Wrong pattern. Try again.';
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
              _subtitle,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: _hasError ? Colors.red.shade600 : AppColors.of(context).textSecondary,
              ),
            ),
            const Spacer(flex: 1),

            // Pattern grid
            _buildPatternGrid(),
            const SizedBox(height: 32),

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
                        backgroundColor: AppColors.of(context).accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.of(context).accent.withAlpha(80),
                        disabledForegroundColor: Colors.white54,
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
          final center = Offset(
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

  _PatternPainter({
    required this.selectedDots,
    required this.gridSize,
    required this.gridSpacing,
    required this.dotRadius,
    required this.hasError,
    required this.primaryColor,
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
    final lineColor = hasError ? Colors.red.shade400 : primaryColor;
    final dotColor = hasError ? Colors.red.shade400 : primaryColor;

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
        ..color = isSelected ? dotColor : const Color(0xFFD0D0D0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, dotRadius / 2 + 6, outerPaint);

      // Inner dot
      final innerPaint = Paint()
        ..color = isSelected ? dotColor : const Color(0xFFD0D0D0);
      canvas.drawCircle(center, isSelected ? 8 : 5, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.selectedDots != selectedDots ||
        oldDelegate.hasError != hasError;
  }
}
