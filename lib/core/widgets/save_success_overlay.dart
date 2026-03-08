import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';

/// Beautiful post-save confirmation overlay.
///
/// Shows a "Saved to your book" confirmation with a green checkmark,
/// then auto-redirects to the home/today view after a short delay.
class SaveSuccessOverlay {
  /// Shows the overlay and returns after auto-dismiss.
  /// [onDismiss] is called when the overlay finishes (after redirect delay).
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onDismiss,
    Duration displayDuration = const Duration(milliseconds: 1800),
  }) async {
    final overlayState = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _SaveSuccessWidget(
        onFinished: () {
          entry.remove();
          onDismiss?.call();
        },
        displayDuration: displayDuration,
      ),
    );

    overlayState.insert(entry);
  }
}

class _SaveSuccessWidget extends StatefulWidget {
  final VoidCallback onFinished;
  final Duration displayDuration;

  const _SaveSuccessWidget({
    required this.onFinished,
    required this.displayDuration,
  });

  @override
  State<_SaveSuccessWidget> createState() => _SaveSuccessWidgetState();
}

class _SaveSuccessWidgetState extends State<_SaveSuccessWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleIn;
  late Animation<double> _checkScale;
  Timer? _dismissTimer;
  bool _showRedirect = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleIn = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();

    // Show "Returning to Today view..." after a short delay
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showRedirect = true);
    });

    // Auto-dismiss
    _dismissTimer = Timer(widget.displayDuration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onFinished());
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Material(
        color: Colors.black.withAlpha(90),
        child: Center(
          child: ScaleTransition(
            scale: _scaleIn,
            child: Container(
              width: 280,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Green checkmark circle
                  ScaleTransition(
                    scale: _checkScale,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.withAlpha(26),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 40,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // "Saved to your book" text
                  Text(
                    'Saved to your book',
                    style: GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Redirect indicator
                  AnimatedOpacity(
                    opacity: _showRedirect ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withAlpha(26),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.home_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Returning to Today view...',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
