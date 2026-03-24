import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dd_logo.dart';
import 'package:deardays/services/auth/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? prefillEmail;

  const ForgotPasswordScreen({super.key, this.prefillEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _sent = false;
  String? _emailError;
  String? _globalError;

  // Resend cooldown
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    if (widget.prefillEmail != null) {
      _emailController.text = widget.prefillEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  bool _validateEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required.');
      return false;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _emailError = 'Enter a valid email address.');
      return false;
    }
    setState(() => _emailError = null);
    return true;
  }

  Future<void> _handleSend() async {
    if (!_validateEmail()) return;

    final email = _emailController.text.trim();
    setState(() { _isLoading = true; _globalError = null; });
    try {
      await _authService.resetPassword(email);
      if (mounted) {
        setState(() { _sent = true; });
        _startCooldown();
      }
    } catch (e) {
      debugPrint('[ForgotPasswordScreen] error: $e');
      if (mounted) {
        setState(() => _globalError = 'Failed to send reset email. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          _GradientBg(colors: colors),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(colors),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                    child: _sent ? _buildSuccessState(colors) : _buildFormState(colors),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppPalette colors) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 120,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const DdLogoWhite(size: 32),
              const SizedBox(height: 6),
              Text(
                'Reset your password',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withAlpha(220),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          left: 12,
          child: GestureDetector(
            onTap: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(30),
                border: Border.all(color: Colors.white.withAlpha(60)),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormState(AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Forgot your\npassword?',
          style: GoogleFonts.playfairDisplay(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "No worries — we'll send a reset link to your email.",
          style: GoogleFonts.manrope(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 32),

        if (_globalError != null) ...[
          _ErrorBanner(message: _globalError!),
          const SizedBox(height: 16),
        ],

        // Email field
        _buildEmailField(colors),
        const SizedBox(height: 16),

        // Security note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.accent.withAlpha(12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.accent.withAlpha(40)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: colors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The link expires in 60 minutes and can only be used once.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: colors.accent,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Send button
        _buildSendButton(colors),
        const SizedBox(height: 20),

        Center(
          child: GestureDetector(
            onTap: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Text(
              'Back to login',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.successLight,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 36,
              color: AppColors.success,
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: 400.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 300.ms),
        ),
        const SizedBox(height: 24),
        Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'We sent a password reset link to:\n${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: colors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        // Resend button
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: (_resendCooldown > 0 || _isLoading) ? null : _handleSend,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.accent,
              side: BorderSide(color: colors.accent.withAlpha(100)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
                  )
                : Text(
                    _resendCooldown > 0
                        ? 'Resend in ${_resendCooldown}s'
                        : 'Resend email',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.accent, colors.accentLight],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: Text(
                'Back to login',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Center(
          child: Text(
            "Didn't receive the email? Check your spam folder.",
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: colors.textMuted,
              height: 1.5,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0, duration: 400.ms);
  }

  Widget _buildEmailField(AppPalette colors) {
    final hasError = _emailError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _emailController,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() => _emailError = null),
          decoration: InputDecoration(
            labelText: 'Email address',
            labelStyle: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: hasError ? AppColors.error : colors.textSecondary,
            ),
            floatingLabelStyle: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hasError ? AppColors.error : colors.accent,
            ),
            hintText: 'you@example.com',
            hintStyle: GoogleFonts.manrope(color: colors.textMuted, fontSize: 14),
            prefixIcon: Icon(
              Icons.mail_outline_rounded,
              size: 20,
              color: hasError ? AppColors.error : colors.textMuted,
            ),
            filled: true,
            fillColor: colors.bg.withAlpha(180),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: hasError ? AppColors.error : colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : colors.border,
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : colors.accent,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 13, color: AppColors.error),
              const SizedBox(width: 4),
              Text(
                _emailError!,
                style: GoogleFonts.manrope(fontSize: 12, color: AppColors.error),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSendButton(AppPalette colors) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isLoading
                ? [colors.accent.withAlpha(128), colors.accentLight.withAlpha(128)]
                : [colors.accent, colors.accentLight],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.accent.withAlpha(60),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleSend,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  'Send Reset Link',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.manrope(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0, duration: 200.ms);
  }
}

class _GradientBg extends StatelessWidget {
  final AppPalette colors;
  const _GradientBg({required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.4, 1.0],
            colors: [colors.accent.withAlpha(20), colors.accentFaint, colors.bg],
          ),
        ),
      ),
    );
  }
}