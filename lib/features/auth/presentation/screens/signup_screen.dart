import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dd_logo.dart';
import 'package:deardays/core/utils/password_validator.dart';
import 'package:deardays/services/auth/auth_service.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onLogin;

  const SignupScreen({super.key, required this.onLogin});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _healthConsentGiven = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _globalError;

  // Rate-limiting
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  int _passwordStrength(String pw) {
    if (pw.isEmpty) return 0;
    int score = 0;
    if (pw.length >= 8) score++;
    if (pw.contains(RegExp(r'[A-Z]'))) score++;
    if (pw.contains(RegExp(r'[0-9]'))) score++;
    if (pw.length >= 12 && pw.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
      score++;
    }
    return score;
  }

  bool _validateFields() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    String? nameErr;
    String? emailErr;
    String? pwErr;
    String? confirmErr;

    if (email.isEmpty) {
      emailErr = 'Email is required.';
    } else if (!email.contains('@') || !email.contains('.')) {
      emailErr = 'Enter a valid email address.';
    }

    if (password.isEmpty) {
      pwErr = 'Password is required.';
    } else {
      pwErr = PasswordValidator.validate(password);
    }

    if (confirm.isEmpty) {
      confirmErr = 'Please confirm your password.';
    } else if (confirm != password) {
      confirmErr = 'Passwords do not match.';
    }

    setState(() {
      _nameError = nameErr;
      _emailError = emailErr;
      _passwordError = pwErr;
      _confirmError = confirmErr;
      _globalError = null;
    });

    return emailErr == null && pwErr == null && confirmErr == null;
  }

  Future<void> _handleSignup() async {
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      setState(() => _globalError = 'Too many failed attempts. Try again in ${remaining}s.');
      return;
    }

    if (!_validateFields()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() { _isLoading = true; _globalError = null; });
    try {
      final response = await _authService.signUpWithEmail(
        email,
        password,
        displayName: _nameController.text.trim(),
        consentGivenAt: DateTime.now().toUtc(),
        healthConsentGivenAt: _healthConsentGiven ? DateTime.now().toUtc() : null,
      );
      if (response.user != null && mounted) {
        setState(() { _failedAttempts = 0; _lockoutUntil = null; });
        widget.onLogin();
      }
    } on AuthException catch (e) {
      if (mounted) {
        _recordFailedAttempt();
        setState(() => _globalError = e.message);
      }
    } catch (e) {
      debugPrint('[SignupScreen] error: $e');
      if (mounted) {
        _recordFailedAttempt();
        setState(() => _globalError = 'Sign up failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() { _isLoading = true; _globalError = null; });
    try {
      await _authService.signInWithGoogle();
    } on AuthException catch (e) {
      if (mounted) setState(() => _globalError = e.message);
    } catch (e) {
      if (mounted) setState(() => _globalError = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() { _isLoading = true; _globalError = null; });
    try {
      await _authService.signInWithApple();
    } on AuthException catch (e) {
      if (mounted) setState(() => _globalError = e.message);
    } catch (e) {
      if (mounted) setState(() => _globalError = 'Apple sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      _lockoutUntil = DateTime.now().add(const Duration(minutes: 30));
      _failedAttempts = 0;
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
                  // ── Gradient header strip ──
                  _buildHeader(colors),

                  // ── Form content ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Start your\nstory',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create your journal and begin capturing life.',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Social buttons ──
                        _buildSocialButtons(colors),
                        const SizedBox(height: 20),
                        _buildDivider(colors, 'OR SIGN UP WITH EMAIL'),
                        const SizedBox(height: 20),

                        // ── Global error ──
                        if (_globalError != null) ...[
                          _ErrorBanner(message: _globalError!),
                          const SizedBox(height: 16),
                        ],

                        // ── Form fields ──
                        _buildForm(colors),
                        const SizedBox(height: 24),

                        // ── CTA ──
                        _buildCta(colors),
                        const SizedBox(height: 16),

                        // ── Terms ──
                        Center(
                          child: Text(
                            'By signing up, you agree to our Terms of Service\nand Privacy Policy. 7-day free trial, no card required.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: colors.textMuted,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Login link ──
                        Center(
                          child: GestureDetector(
                            onTap: _isLoading ? null : () => Navigator.of(context).pop(),
                            child: RichText(
                              text: TextSpan(
                                text: 'Already have an account? ',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  color: colors.textSecondary,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Log in',
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: colors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                'Create your journal',
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

  Widget _buildSocialButtons(AppPalette colors) {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            bgColor: colors.card,
            borderColor: colors.border,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/google_logo.png',
                  width: 18,
                  height: 18,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.g_mobiledata_rounded, size: 20, color: colors.textPrimary),
                ),
                const SizedBox(width: 8),
                Text(
                  'Google',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            onPressed: _isLoading ? null : _handleAppleSignIn,
            bgColor: colors.card,
            borderColor: colors.border,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apple, size: 20, color: colors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'Apple',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(AppPalette colors, String text) {
    return Row(
      children: [
        Expanded(child: Divider(color: colors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: colors.border, thickness: 1)),
      ],
    );
  }

  Widget _buildForm(AppPalette colors) {
    final pw = _passwordController.text;
    final strength = _passwordStrength(pw);
    final confirm = _confirmController.text;
    final matches = confirm.isNotEmpty && confirm == pw;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Name field
        _FormField(
          controller: _nameController,
          label: 'Full name',
          hint: 'What should we call you? (optional)',
          prefixIcon: Icons.person_outline_rounded,
          error: _nameError,
          enabled: !_isLoading,
          onChanged: (_) => setState(() => _nameError = null),
          colors: colors,
        ),
        const SizedBox(height: 14),

        // Email field
        _FormField(
          controller: _emailController,
          label: 'Email',
          hint: 'you@example.com',
          prefixIcon: Icons.mail_outline_rounded,
          error: _emailError,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() => _emailError = null),
          colors: colors,
        ),
        const SizedBox(height: 14),

        // Password field + strength meter
        _FormField(
          controller: _passwordController,
          label: 'Password',
          hint: PasswordValidator.hint,
          prefixIcon: Icons.lock_outline_rounded,
          error: _passwordError,
          enabled: !_isLoading,
          obscureText: _obscurePassword,
          onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
          onChanged: (_) => setState(() => _passwordError = null),
          colors: colors,
        ),
        if (pw.isNotEmpty) ...[
          const SizedBox(height: 8),
          _PasswordStrengthBar(strength: strength),
        ],
        const SizedBox(height: 14),

        // Confirm password field
        _FormField(
          controller: _confirmController,
          label: 'Confirm password',
          hint: 'Re-enter your password',
          prefixIcon: Icons.lock_outline_rounded,
          error: _confirmError,
          enabled: !_isLoading,
          obscureText: _obscureConfirm,
          onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
          suffixWidget: confirm.isNotEmpty
              ? Icon(
                  matches ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 18,
                  color: matches ? AppColors.success : AppColors.error,
                )
              : null,
          onChanged: (_) => setState(() => _confirmError = null),
          colors: colors,
        ),
        const SizedBox(height: 16),

        // Health consent
        GestureDetector(
          onTap: _isLoading
              ? null
              : () => setState(() => _healthConsentGiven = !_healthConsentGiven),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _healthConsentGiven,
                  onChanged: _isLoading
                      ? null
                      : (v) => setState(() => _healthConsentGiven = v ?? false),
                  activeColor: colors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  side: BorderSide(color: colors.border, width: 1.5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text.rich(
                    TextSpan(
                      text: 'I consent to mood & health data processing ',
                      style: GoogleFonts.manrope(fontSize: 13, color: colors.textSecondary),
                      children: [
                        TextSpan(
                          text: '(optional)',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCta(AppPalette colors) {
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
          onPressed: _isLoading ? null : _handleSignup,
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
                  'Create My Journal',
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
// Password strength bar (4 levels)
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final int strength; // 0–4

  const _PasswordStrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    final labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [
      Colors.transparent,
      AppColors.error,
      AppColors.moodOkay,
      AppColors.moodGood,
      AppColors.success,
    ];
    final label = strength > 0 ? labels[strength] : '';
    final color = colors[strength.clamp(0, 4)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final filled = i < strength;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: filled ? color : AppColors.of(context).border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable form field widget with inline error
// ─────────────────────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final String? error;
  final bool enabled;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final Widget? suffixWidget;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final AppPalette colors;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    required this.colors,
    this.error,
    this.enabled = true,
    this.obscureText = false,
    this.onToggleObscure,
    this.suffixWidget,
    this.keyboardType,
    this.onChanged,
  });

  Widget? _buildSuffix(AppPalette colors) {
    final eyeBtn = onToggleObscure != null
        ? IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
              color: colors.textMuted,
            ),
            onPressed: onToggleObscure,
          )
        : null;

    if (eyeBtn != null && suffixWidget != null) {
      // Show match indicator + eye button together
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: suffixWidget,
          ),
          eyeBtn,
        ],
      );
    }
    if (eyeBtn != null) return eyeBtn;
    if (suffixWidget != null) {
      return Padding(padding: const EdgeInsets.only(right: 12), child: suffixWidget);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
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
            hintText: hint,
            hintStyle: GoogleFonts.manrope(color: colors.textMuted, fontSize: 14),
            prefixIcon: Icon(
              prefixIcon,
              size: 20,
              color: hasError ? AppColors.error : colors.textMuted,
            ),
            suffixIcon: _buildSuffix(colors),
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
                error!,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Global error banner
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

// ─────────────────────────────────────────────────────────────────────────────
// Social button (half-width)
// ─────────────────────────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color bgColor;
  final Color borderColor;

  const _SocialButton({
    required this.onPressed,
    required this.child,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient orb background
// ─────────────────────────────────────────────────────────────────────────────

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
        child: CustomPaint(painter: _OrbPainter(colors: colors)),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final AppPalette colors;
  _OrbPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    _draw(canvas, Offset(size.width * 0.85, size.height * 0.08), size.width * 0.5,
        colors.accent.withAlpha(15));
    _draw(canvas, Offset(size.width * 0.15, size.height * 0.5), size.width * 0.45,
        colors.accentLight.withAlpha(10));
  }

  void _draw(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [color, color.withAlpha(0)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}