import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/services/auth/auth_service.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/core/utils/password_validator.dart';
import 'package:deardays/features/auth/presentation/screens/pin_screen.dart';
import 'package:deardays/features/auth/presentation/screens/pattern_screen.dart';
import 'package:deardays/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:deardays/features/settings/presentation/screens/terms_screen.dart';
import 'package:deardays/features/settings/presentation/screens/privacy_screen.dart';

import '../widgets/auth_shell.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _secureStorage = SecureStorageService();
  final _localAuth = LocalAuthentication();

  bool _obscurePassword = true;
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _lockMethod = 'none';

  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  bool _healthConsentGiven = false;

  bool get _isReturningUser =>
      (_biometricAvailable && _biometricEnabled) ||
      _lockMethod == 'pin' ||
      _lockMethod == 'pattern';

  @override
  void initState() {
    super.initState();
    _checkLockOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Business logic (preserved) ──────────────────────────────────────────────

  Future<void> _checkLockOptions() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final biometricEnabled = await _secureStorage.getBiometricEnabled();
      final lockMethod = await _secureStorage.getLockMethod();
      if (mounted) {
        setState(() {
          _biometricAvailable = canCheck && isDeviceSupported;
          _biometricEnabled = biometricEnabled;
          _lockMethod = lockMethod;
        });
      }
    } catch (e) {
      debugPrint('[LoginScreen] _checkLockOptions error: $e');
    }
  }

  Future<void> _handleBiometricLogin() async {
    setState(() => _isLoading = true);
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock DearDays with biometrics',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (!authenticated) {
        if (mounted) _showError('Biometric authentication failed.');
        return;
      }
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try { await Supabase.instance.client.auth.refreshSession(); } catch (_) {}
        if (mounted) widget.onLogin();
      } else {
        if (mounted) _showError('Session expired. Please log in with email and password.');
      }
    } catch (e) {
      if (mounted) _showError('Biometric authentication not available.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePinLogin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showError('Session expired. Please log in with email and password.');
      return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PinScreen(mode: PinMode.verify, onSuccess: () {})),
    );
    if (result == true && mounted) widget.onLogin();
  }

  Future<void> _handlePatternLogin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showError('Session expired. Please log in with email and password.');
      return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PatternScreen(mode: PatternMode.verify, onSuccess: () {})),
    );
    if (result == true && mounted) widget.onLogin();
  }

  Future<void> _handleEmailAuth() async {
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      _showError('Too many failed attempts. Try again in ${remaining}s.');
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }
    if (_isSignUp) {
      final pwError = PasswordValidator.validate(password);
      if (pwError != null) { _showError(pwError); return; }
    }
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        final response = await _authService.signUpWithEmail(
          email, password,
          displayName: _nameController.text.trim(),
          consentGivenAt: DateTime.now().toUtc(),
          healthConsentGivenAt: _healthConsentGiven ? DateTime.now().toUtc() : null,
        );
        if (response.user != null && mounted) {
          setState(() { _failedAttempts = 0; _lockoutUntil = null; });
          widget.onLogin();
        }
      } else {
        final response = await _authService.signInWithEmail(email, password);
        if (response.user != null && mounted) {
          setState(() { _failedAttempts = 0; _lockoutUntil = null; });
          widget.onLogin();
        }
      }
    } on AuthException catch (e) {
      if (mounted) { setState(_recordFailedAttempt); _showError(e.message); }
    } catch (e) {
      debugPrint('[LoginScreen] Login error: $e');
      if (mounted) { setState(_recordFailedAttempt); _showError('Login failed. Please try again.'); }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithApple();
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Apple sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Google sign-in failed. Please try again.');
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: _isSignUp ? 'Start your\nstory.' : 'Welcome\nback.',
      subtitle: _isSignUp
          ? 'Every great life deserves a journal.'
          : 'Pick up where you left off.',
      cardContent: _buildCardContent(),
    );
  }

  Widget _buildCardContent() {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Quick unlock (returning user) ────────────────────────────────
        if (_isReturningUser && !_isSignUp) ...[
          _buildQuickUnlock(colors),
          const SizedBox(height: 20),
          const AuthDivider(label: 'or sign in with'),
          const SizedBox(height: 20),
        ],

        // ── Social buttons ───────────────────────────────────────────────
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

        AuthDivider(label: _isSignUp ? 'or sign up with email' : 'or continue with email'),
        const SizedBox(height: 24),

        // ── Name field (signup only) ─────────────────────────────────────
        if (_isSignUp) ...[
          AuthField(
            controller: _nameController,
            placeholder: 'Full name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
        ],

        // ── Email field ──────────────────────────────────────────────────
        AuthField(
          controller: _emailController,
          placeholder: 'Email address',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        // ── Password field ───────────────────────────────────────────────
        AuthField(
          controller: _passwordController,
          placeholder: 'Password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePassword,
          suffix: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18,
              color: colors.textMuted,
            ),
          ),
        ),

        // ── Forgot password (login only) ─────────────────────────────────
        if (!_isSignUp) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ForgotPasswordScreen(
                  prefillEmail: _emailController.text.trim().isNotEmpty
                      ? _emailController.text.trim()
                      : null,
                )),
              ),
              child: Text(
                'Forgot password?',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
          ),
        ],

        // ── Health consent (signup only) ──────────────────────────────────
        if (_isSignUp) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _healthConsentGiven = !_healthConsentGiven),
            child: Row(
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _healthConsentGiven ? colors.accent : colors.border, width: 1.5),
                    color: _healthConsentGiven ? colors.accent : Colors.transparent,
                  ),
                  child: _healthConsentGiven
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Allow mood tracking for AI insights',
                    style: GoogleFonts.manrope(fontSize: 13, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),

        // ── CTA ──────────────────────────────────────────────────────────
        AuthButton(
          label: _isSignUp ? 'Create Account' : 'Log In',
          onTap: _isLoading ? null : _handleEmailAuth,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 20),

        // ── Trust badges ─────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TrustBadge(icon: Icons.lock_outline, label: 'Encrypted', colors: colors),
            const SizedBox(width: 16),
            _TrustBadge(icon: Icons.card_giftcard_outlined, label: '7-day free', colors: colors),
            const SizedBox(width: 16),
            _TrustBadge(icon: Icons.credit_card_off_outlined, label: 'No card', colors: colors),
          ],
        ),
        const SizedBox(height: 24),

        // ── Toggle login / signup ────────────────────────────────────────
        Center(
          child: GestureDetector(
            onTap: () => setState(() {
              _isSignUp = !_isSignUp;
              _healthConsentGiven = false;
            }),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.manrope(fontSize: 13, color: colors.textSecondary),
                children: [
                  TextSpan(text: _isSignUp ? 'Already have an account? ' : "Don't have an account? "),
                  TextSpan(
                    text: _isSignUp ? 'Log in →' : 'Sign up →',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Terms / Privacy ──────────────────────────────────────────────
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              Text('By continuing, you agree to our ',
                  style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted)),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TermsScreen())),
                child: Text('Terms',
                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: colors.accent)),
              ),
              Text(' and ',
                  style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted)),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                child: Text('Privacy Policy',
                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: colors.accent)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickUnlock(AppPalette colors) {
    final String label;
    final IconData icon;
    final VoidCallback onTap;

    if (_biometricAvailable && _biometricEnabled) {
      label = 'Unlock with biometrics';
      icon = Icons.fingerprint_rounded;
      onTap = _handleBiometricLogin;
    } else if (_lockMethod == 'pin') {
      label = 'Unlock with PIN';
      icon = Icons.pin_outlined;
      onTap = _handlePinLogin;
    } else {
      label = 'Unlock with pattern';
      icon = Icons.pattern_rounded;
      onTap = _handlePatternLogin;
    }

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isLoading ? null : onTap,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [colors.accent, colors.accentLight],
                ),
                boxShadow: [
                  BoxShadow(color: colors.accent.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: _isLoading
                  ? const Center(child: SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
                  : Icon(icon, size: 32, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Trust badge ──────────────────────────────────────────────────────────────

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette colors;

  const _TrustBadge({required this.icon, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.textMuted),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: colors.textMuted)),
      ],
    );
  }
}