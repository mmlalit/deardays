import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/services/auth/auth_service.dart';

import '../widgets/auth_shell.dart';
import '../widgets/auth_widgets.dart';

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
    return AuthShell(
      title: _sent ? 'Check your\ninbox.' : 'No worries.',
      subtitle: _sent ? 'We sent you a reset link.' : "We'll help you get back in.",
      onBack: () => Navigator.pop(context),
      cardContent: _sent ? _buildSuccessState() : _buildFormState(),
    );
  }

  Widget _buildFormState() {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthErrorBanner(message: _globalError),
        if (_globalError != null) const SizedBox(height: 16),

        AuthField(
          controller: _emailController,
          placeholder: 'you@example.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          error: _emailError,
          onChanged: (_) => setState(() => _emailError = null),
        ),
        const SizedBox(height: 16),

        // Info note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.accent.withAlpha(12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.accent.withAlpha(40)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: colors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "We'll send a password reset link. It expires in 1 hour.",
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

        AuthButton(
          label: 'Send Reset Link',
          onTap: _isLoading ? null : _handleSend,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 20),

        Center(
          child: GestureDetector(
            onTap: _isLoading ? null : () => Navigator.pop(context),
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

  Widget _buildSuccessState() {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success icon
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

        // Heading
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

        // Subtitle
        Text(
          'We sent a reset link to\n${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: colors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        // Resend button (outline style)
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: (_resendCooldown > 0 || _isLoading) ? null : _handleSend,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.accent,
              side: BorderSide(color: colors.accent.withAlpha(100)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
                  )
                : Text(
                    _resendCooldown > 0
                        ? 'Resend (${_resendCooldown}s)'
                        : 'Resend',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        AuthButton(
          label: 'Back to Login',
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: 20),

        // Helper text
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
}