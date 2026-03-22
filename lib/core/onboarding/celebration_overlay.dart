import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';

/// Full-screen celebration overlay shown when the user saves their first memory.
/// Auto-dismisses after [duration], or on tap.
class CelebrationOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final Duration duration;

  const CelebrationOverlay({
    super.key,
    required this.onDismiss,
    this.duration = const Duration(milliseconds: 2500),
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    Future.delayed(widget.duration, () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        onTap: _dismiss,
        child: Container(
          color: colors.bg.withAlpha(240),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✨', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 20),
                Text(
                  'You did it.',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Your first memory is saved forever.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      color: colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Tap anywhere to continue',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
