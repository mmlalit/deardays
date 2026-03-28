import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/utils/password_validator.dart';
import 'package:deardays/services/auth/auth_service.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/features/auth/presentation/widgets/auth_shell.dart';
import 'package:deardays/features/auth/presentation/widgets/auth_widgets.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onLogin;

  const SignupScreen({super.key, required this.onLogin});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  final _secureStorage = SecureStorageService();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _healthConsentGiven = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _globalError;

  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  @override
  void initState() {
    super.initState();
    _loadLockoutState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Business logic (preserved) ──────────────────────────────────────────────

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
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && mounted) {
        setState(() { _failedAttempts = 0; _lockoutUntil = null; });
        widget.onLogin();
      }
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
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && mounted) {
        setState(() { _failedAttempts = 0; _lockoutUntil = null; });
        widget.onLogin();
      }
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
    _persistLockoutState();
  }

  Future<void> _loadLockoutState() async {
    try {
      final attemptsStr = await _secureStorage.read('signup_failed_attempts');
      final lockoutStr = await _secureStorage.read('signup_lockout_until');
      if (mounted) {
        setState(() {
          _failedAttempts = int.tryParse(attemptsStr ?? '') ?? 0;
          if (lockoutStr != null) {
            final parsed = DateTime.tryParse(lockoutStr);
            if (parsed != null && parsed.isAfter(DateTime.now())) {
              _lockoutUntil = parsed;
            } else {
              _lockoutUntil = null;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[SignupScreen] _loadLockoutState error: $e');
    }
  }

  Future<void> _persistLockoutState() async {
    try {
      await _secureStorage.write(
          'signup_failed_attempts', _failedAttempts.toString());
      if (_lockoutUntil != null) {
        await _secureStorage.write(
            'signup_lockout_until', _lockoutUntil!.toIso8601String());
      } else {
        await _secureStorage.delete('signup_lockout_until');
      }
    } catch (e) {
      debugPrint('[SignupScreen] _persistLockoutState error: $e');
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final pw = _passwordController.text;
    final strength = _passwordStrength(pw);
    final confirm = _confirmController.text;
    final matches = confirm.isNotEmpty && confirm == pw;

    return AuthShell(
      title: 'Start your\nstory.',
      subtitle: 'Every great life deserves a journal.',
      onBack: () => Navigator.pop(context),
      cardContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Social buttons ──
          Row(
            children: [
              Expanded(
                child: AuthSocialButton(
                  label: 'Google',
                  iconPath: 'google',
                  onTap: _handleGoogleSignIn,
                  isLoading: _isLoading,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AuthSocialButton(
                  label: 'Apple',
                  iconPath: 'apple',
                  onTap: _handleAppleSignIn,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const AuthDivider(label: 'or sign up with email'),
          const SizedBox(height: 24),

          AuthErrorBanner(message: _globalError),
          if (_globalError != null) const SizedBox(height: 16),

          // ── Name field ──
          AuthField(
            controller: _nameController,
            placeholder: 'What should we call you? (optional)',
            icon: Icons.person_outline_rounded,
            error: _nameError,
            onChanged: (_) => setState(() => _nameError = null),
          ),
          const SizedBox(height: 14),

          // ── Email field ──
          AuthField(
            controller: _emailController,
            placeholder: 'you@example.com',
            icon: Icons.mail_outline_rounded,
            error: _emailError,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() => _emailError = null),
          ),
          const SizedBox(height: 14),

          // ── Password field + strength meter ──
          AuthField(
            controller: _passwordController,
            placeholder: PasswordValidator.hint,
            icon: Icons.lock_outline_rounded,
            error: _passwordError,
            obscure: _obscurePassword,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: colors.textMuted,
              ),
            ),
            onChanged: (_) => setState(() => _passwordError = null),
          ),
          if (pw.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PasswordStrengthBar(strength: strength),
          ],
          const SizedBox(height: 14),

          // ── Confirm password field ──
          AuthField(
            controller: _confirmController,
            placeholder: 'Re-enter your password',
            icon: Icons.lock_outline_rounded,
            error: _confirmError,
            obscure: _obscureConfirm,
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (confirm.isNotEmpty)
                  Icon(
                    matches ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 18,
                    color: matches ? AppColors.success : AppColors.error,
                  ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  child: Icon(
                    _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
            onChanged: (_) => setState(() => _confirmError = null),
          ),
          const SizedBox(height: 16),

          // ── Health consent ──
          GestureDetector(
            onTap: _isLoading
                ? null
                : () => setState(() => _healthConsentGiven = !_healthConsentGiven),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20, height: 20,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _healthConsentGiven ? colors.accent : colors.border,
                      width: 1.5,
                    ),
                    color: _healthConsentGiven ? colors.accent : Colors.transparent,
                  ),
                  child: _healthConsentGiven
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
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
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── CTA ──
          AuthButton(
            label: 'Create My Journal',
            onTap: _isLoading ? null : _handleSignup,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),

          // ── Terms disclaimer ──
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
                  style: GoogleFonts.manrope(fontSize: 14, color: colors.textSecondary),
                  children: [
                    TextSpan(
                      text: 'Log in \u2192',
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
    );
  }
}

// ── Password strength bar (4 levels) ─────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final int strength; // 0–4
  const _PasswordStrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    final labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    final barColors = [
      Colors.transparent,
      AppColors.error,
      AppColors.moodOkay,
      AppColors.moodGood,
      AppColors.success,
    ];
    final label = strength > 0 ? labels[strength] : '';
    final color = barColors[strength.clamp(0, 4)];

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
