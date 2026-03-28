import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';

/// Shared auth layout: gradient hero with title/subtitle at top,
/// white card overlapping the hero from below.
///
/// Used by LoginScreen, SignupScreen, and ForgotPasswordScreen.
class AuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget cardContent;
  final VoidCallback? onBack;

  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cardContent,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          // ── Hero gradient (top ~42%) ────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.42,
            child: _HeroBackground(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button (only if provided)
                      if (onBack != null)
                        GestureDetector(
                          onTap: onBack,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withAlpha(25),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                size: 20, color: Colors.white),
                          ),
                        )
                      else
                        const SizedBox(height: 40),
                      const Spacer(),
                      // Logo
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 16, color: Colors.white.withAlpha(200)),
                          const SizedBox(width: 6),
                          Text(
                            'DearDays',
                            style: GoogleFonts.newsreader(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withAlpha(200),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Title
                      Text(
                        title,
                        style: GoogleFonts.newsreader(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      Text(
                        subtitle,
                        style: GoogleFonts.newsreader(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withAlpha(180),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Card (overlaps hero by ~40px) ──────────────────────────────
          Positioned.fill(
            top: MediaQuery.of(context).size.height * 0.42 - 40,
            child: Container(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 40,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                  child: cardContent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated hero gradient background with floating orbs ─────────────────────

class _HeroBackground extends StatefulWidget {
  final Widget child;
  const _HeroBackground({required this.child});

  @override
  State<_HeroBackground> createState() => _HeroBackgroundState();
}

class _HeroBackgroundState extends State<_HeroBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return CustomPaint(
          painter: _OrbPainter(progress: _ctrl.value),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6366F1), // indigo
                  Color(0xFF7C3AED), // violet
                  Color(0xFFEC4899), // pink
                ],
              ),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double progress;
  _OrbPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress * 2 * pi;
    final paint = Paint()..style = PaintingStyle.fill;

    // Orb 1 — large, top-right
    paint.color = Colors.white.withAlpha(15);
    canvas.drawCircle(
      Offset(
        size.width * 0.8 + sin(p) * 20,
        size.height * 0.25 + cos(p * 0.7) * 15,
      ),
      80,
      paint,
    );

    // Orb 2 — small, bottom-left
    paint.color = Colors.white.withAlpha(10);
    canvas.drawCircle(
      Offset(
        size.width * 0.15 + cos(p * 1.3) * 15,
        size.height * 0.7 + sin(p) * 10,
      ),
      50,
      paint,
    );

    // Orb 3 — medium, center
    paint.color = Colors.white.withAlpha(8);
    canvas.drawCircle(
      Offset(
        size.width * 0.5 + sin(p * 0.5) * 25,
        size.height * 0.5 + cos(p * 0.8) * 20,
      ),
      65,
      paint,
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.progress != progress;
}
