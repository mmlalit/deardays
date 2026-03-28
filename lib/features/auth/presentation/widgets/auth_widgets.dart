import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';

// ── Borderless form field ────────────────────────────────────────────────────

class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final String? error;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const AuthField({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.error,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasError = error != null && error!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.bg.withAlpha(180),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? AppColors.error.withAlpha(120) : colors.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 18,
                  color: hasError ? AppColors.error : colors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  style: GoogleFonts.manrope(
                      fontSize: 14, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: GoogleFonts.manrope(
                        fontSize: 14, color: colors.textMuted.withAlpha(150)),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              if (suffix != null) suffix!,
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              error!,
              style: GoogleFonts.manrope(
                  fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}

// ── Social sign-in button ────────────────────────────────────────────────────

class AuthSocialButton extends StatelessWidget {
  final String label;
  final String iconPath; // 'google' or 'apple'
  final VoidCallback onTap;
  final bool isLoading;

  const AuthSocialButton({
    super.key,
    required this.label,
    required this.iconPath,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconPath == 'google')
              _googleIcon()
            else
              Icon(Icons.apple_rounded, size: 20, color: colors.textPrimary),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _googleIcon() {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    // Simplified Google "G" as colored arcs
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(r, r), radius: r),
        -0.4, 2.0, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(r, r), radius: r),
        1.6, 1.2, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(r, r), radius: r),
        2.8, 1.0, true, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(r, r), radius: r),
        3.8, 1.6, true, paint);
    // Center white circle
    paint.color = Colors.white;
    canvas.drawCircle(Offset(r, r), r * 0.55, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Primary gradient CTA button ──────────────────────────────────────────────

class AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const AuthButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedOpacity(
        opacity: onTap != null ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.accent, colors.accentLight],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withAlpha(60),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Divider with label ───────────────────────────────────────────────────────

class AuthDivider extends StatelessWidget {
  final String label;
  const AuthDivider({super.key, this.label = 'or continue with email'});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: colors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: colors.textMuted.withAlpha(150),
            ),
          ),
        ),
        Expanded(child: Divider(color: colors.border)),
      ],
    );
  }
}

// ── Error banner ─────────────────────────────────────────────────────────────

class AuthErrorBanner extends StatelessWidget {
  final String? message;
  const AuthErrorBanner({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16,
              color: AppColors.error.withAlpha(180)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message!,
              style: GoogleFonts.manrope(
                  fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}