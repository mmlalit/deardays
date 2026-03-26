import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dd_logo.dart';
import 'package:deardays/services/auth/auth_service.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/core/utils/password_validator.dart';
import 'package:deardays/features/auth/presentation/screens/pin_screen.dart';
import 'package:deardays/features/auth/presentation/screens/pattern_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _secureStorage = SecureStorageService();
  final _localAuth = LocalAuthentication();

  bool _obscurePassword = true;
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _showEmailForm = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _lockMethod = 'none';

  // Rate-limiting
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  // Consent (signup only)
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
        try {
          await Supabase.instance.client.auth.refreshSession();
        } catch (e) {
          debugPrint('[LoginScreen] refreshSession error: $e');
        }
        if (mounted) widget.onLogin();
      } else {
        if (mounted) {
          _showError('Session expired. Please log in with email and password.');
        }
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
      MaterialPageRoute(
        builder: (_) => PinScreen(mode: PinMode.verify, onSuccess: () {}),
      ),
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
      MaterialPageRoute(
        builder: (_) =>
            PatternScreen(mode: PatternMode.verify, onSuccess: () {}),
      ),
    );
    if (result == true && mounted) widget.onLogin();
  }

  Future<void> _handleEmailAuth() async {
    // Rate-limit check
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
      if (pwError != null) {
        _showError(pwError);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        final response = await _authService.signUpWithEmail(
          email,
          password,
          displayName: _nameController.text.trim(),
          consentGivenAt: DateTime.now().toUtc(),
          healthConsentGivenAt:
              _healthConsentGiven ? DateTime.now().toUtc() : null,
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
      if (mounted) {
        setState(_recordFailedAttempt);
        _showError(e.message);
      }
    } catch (e) {
      debugPrint('[LoginScreen] Login error: $e');
      if (mounted) {
        setState(_recordFailedAttempt);
        _showError('Login failed. Please try again.');
      }
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

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email address first.');
      return;
    }

    try {
      await _authService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: AppColors.of(context).textPrimary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('[LoginScreen] _handleForgotPassword error: $e');
      if (mounted) {
        _showError('Failed to send reset email. Please try again.');
      }
    }
  }

  void _recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      // 30-minute lockout matches PIN/Pattern lockout duration.
      _lockoutUntil = DateTime.now().add(const Duration(minutes: 30));
      _failedAttempts = 0;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offset = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: _showEmailForm
            ? Stack(
                key: const ValueKey('email'),
                children: [
                  _GradientBackground(colors: colors),
                  SafeArea(child: _buildEmailStep()),
                ],
              )
            : _buildSocialStep(key: const ValueKey('social')),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 1: Full-bleed hero + bottom card
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSocialStep({Key? key}) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;
    final heroHeight = size.height * 0.52;

    return SizedBox.expand(
      key: key,
      child: Stack(
        children: [
          // ── Hero gradient background ──────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: _LoginHeroBg(),
          ),

          // ── Full scroll content ───────────────────────────────────────
          SingleChildScrollView(
            child: Column(
              children: [
                // Hero section — logo + app name
                SizedBox(
                  height: heroHeight,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const DdLogoWhite(size: 64)
                            .animate()
                            .fadeIn(duration: 700.ms, curve: Curves.easeOut)
                            .scale(
                              begin: const Offset(0.7, 0.7),
                              end: const Offset(1, 1),
                              duration: 700.ms,
                              curve: Curves.easeOutBack,
                            ),
                        const SizedBox(height: 12),
                        Text(
                          'DearDays',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(
                              begin: 0.12,
                              end: 0,
                              delay: 200.ms,
                              duration: 500.ms,
                              curve: Curves.easeOut,
                            ),
                        const SizedBox(height: 8),
                        Text(
                          'Your life, your story.',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withAlpha(210),
                            height: 1.5,
                          ),
                        ).animate().fadeIn(delay: 350.ms, duration: 500.ms),
                      ],
                    ),
                  ),
                ),

                // ── Bottom card — overlaps hero by 28px so rounded corners show ──
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(18),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Returning-user quick-unlock
                      if (_isReturningUser) ...[
                        _buildQuickUnlockHero(colors),
                        const SizedBox(height: 24),
                        _buildDivider(colors, 'OR SIGN IN WITH'),
                        const SizedBox(height: 20),
                      ],

                      // Social buttons
                      _buildSocialButtons(colors),

                      const SizedBox(height: 24),

                      // Trust badges
                      _buildTrustBadges(colors),

                      const SizedBox(height: 20),

                      // Terms
                      Center(
                        child: Text(
                          'By continuing, you agree to our Terms of\nService and Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            // Hardcoded to pass WCAG AA 4.5:1 on #F9F7F3 bg (ratio ~6.0)
                            color: const Color(0xFF595550),
                            height: 1.5,
                          ),
                        ),
                      ),

                      if (_isLoading) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ), // Transform.translate
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick-unlock hero for returning users ──

  Widget _buildQuickUnlockHero(AppPalette colors) {
    IconData unlockIcon;
    String unlockLabel;
    VoidCallback? unlockAction;

    if (_biometricAvailable && _biometricEnabled) {
      unlockIcon = Icons.fingerprint;
      unlockLabel = 'Tap to unlock';
      unlockAction = _isLoading ? null : _handleBiometricLogin;
    } else if (_lockMethod == 'pin') {
      unlockIcon = Icons.dialpad_rounded;
      unlockLabel = 'Enter PIN to unlock';
      unlockAction = _isLoading ? null : _handlePinLogin;
    } else {
      unlockIcon = Icons.pattern_rounded;
      unlockLabel = 'Draw pattern to unlock';
      unlockAction = _isLoading ? null : _handlePatternLogin;
    }

    return Column(
      children: [
        // Large unlock button
        GestureDetector(
          onTap: unlockAction,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.accent, colors.accentLight],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withAlpha(60),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(unlockIcon, size: 40, color: Colors.white),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(
              delay: 1500.ms,
              duration: 1800.ms,
              color: Colors.white.withAlpha(40),
            ),
        const SizedBox(height: 14),
        Text(
          'Welcome back!',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          unlockLabel,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideY(
          begin: 0.2,
          end: 0,
          delay: 400.ms,
          duration: 500.ms,
          curve: Curves.easeOut,
        );
  }

  // ── Social buttons ──

  Widget _buildSocialButtons(AppPalette colors) {
    return Column(
      children: [
        // Continue with Google — full width
        _FullWidthAuthButton(
          onPressed: _isLoading ? null : _handleGoogleSignIn,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/google_logo.png', width: 20, height: 20,
                  errorBuilder: (_, __, ___) => Icon(Icons.g_mobiledata_rounded, size: 22, color: colors.textPrimary)),
              const SizedBox(width: 10),
              Text('Continue with Google',
                  style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary)),
            ],
          ),
          bgColor: colors.card,
          borderColor: colors.border,
        ),
        const SizedBox(height: 12),
        // Continue with Apple — full width
        _FullWidthAuthButton(
          onPressed: _isLoading ? null : _handleAppleSignIn,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.apple, size: 22, color: colors.textPrimary),
              const SizedBox(width: 10),
              Text('Continue with Apple',
                  style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary)),
            ],
          ),
          bgColor: colors.card,
          borderColor: colors.border,
        ),
        const SizedBox(height: 12),
        // Continue with Email — full width, accent
        _FullWidthAuthButton(
          onPressed: _isLoading ? null : () => setState(() => _showEmailForm = true),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mail_outline_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Text('Continue with Email',
                  style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          bgColor: colors.accent,
          borderColor: Colors.transparent,
        ),
      ],
    )
        .animate()
        .fadeIn(
          delay: _isReturningUser ? 600.ms : 500.ms,
          duration: 500.ms,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          delay: _isReturningUser ? 600.ms : 500.ms,
          duration: 500.ms,
          curve: Curves.easeOut,
        );
  }

  // ── Trust badges ──

  Widget _buildTrustBadges(AppPalette colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TrustBadge(
          icon: Icons.lock_outline_rounded,
          label: 'Encrypted',
          colors: colors,
        ),
        const SizedBox(width: 12),
        _TrustBadge(
          icon: Icons.card_giftcard_rounded,
          label: '7-day free trial',
          colors: colors,
          highlighted: true,
        ),
        const SizedBox(width: 12),
        _TrustBadge(
          icon: Icons.credit_card_off_rounded,
          label: 'No card needed',
          colors: colors,
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 700.ms, duration: 500.ms);
  }

  // ── Divider with text ──

  Widget _buildDivider(AppPalette colors, String text) {
    return Row(
      children: [
        Expanded(child: Divider(color: colors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 11,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 2: Email form (glassmorphic card)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEmailStep({Key? key}) {
    final colors = AppColors.of(context);

    return SingleChildScrollView(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Mini-hero strip ──────────────────────────────────────────────
          Stack(
            children: [
              // Gradient strip
              Container(
                width: double.infinity,
                height: 130,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const DdLogoWhite(size: 36),
                      const SizedBox(height: 6),
                      Text(
                        _isSignUp ? 'Start your journey' : 'Welcome back',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withAlpha(220),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Back button — top-left over strip
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 12),
                  child: GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => setState(() => _showEmailForm = false),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(30),
                        border: Border.all(color: Colors.white.withAlpha(60)),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Rest of form ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          const SizedBox(height: 24),

          // Heading
          Text(
            _isSignUp ? 'Create your\njournal' : 'Welcome\nback',
            style: GoogleFonts.playfairDisplay(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSignUp
                ? 'Start capturing your story today.'
                : 'Pick up where you left off.',
            style: GoogleFonts.manrope(
              fontSize: 15,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),

          // ── Glassmorphic form card ──
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.card.withAlpha(200),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.border.withAlpha(150),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.textPrimary.withAlpha(8),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name field (signup only)
                    if (_isSignUp) ...[
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        enabled: !_isLoading,
                        decoration: _inputDecoration(
                          label: 'Name',
                          hint: 'What should we call you? (optional)',
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email field
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      decoration: _inputDecoration(
                        label: 'Email',
                        hint: 'you@example.com',
                        prefixIcon: Icons.mail_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      decoration: _inputDecoration(
                        label: 'Password',
                        hint: _isSignUp
                            ? 'Create a password (${PasswordValidator.hint})'
                            : 'Enter your password',
                        prefixIcon: Icons.lock_outline_rounded,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              key: ValueKey(_obscurePassword),
                              color: colors.textMuted,
                              size: 20,
                            ),
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),

                    // Forgot password (login only)
                    if (!_isSignUp) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              _isLoading ? null : _handleForgotPassword,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot password?',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Health consent (signup only)
                    if (_isSignUp) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => setState(() =>
                                _healthConsentGiven = !_healthConsentGiven),
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
                                    : (v) => setState(() =>
                                        _healthConsentGiven = v ?? false),
                                activeColor: colors.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                side: BorderSide(
                                    color: colors.border, width: 1.5),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text.rich(
                                  TextSpan(
                                    text:
                                        'I consent to mood & health data processing ',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      color: colors.textSecondary,
                                    ),
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
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Primary CTA — gradient accent button ──
          SizedBox(
            width: double.infinity,
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
                onPressed: _isLoading ? null : _handleEmailAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isSignUp ? 'Create My Journal' : 'Log In',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Trial info (signup only)
          if (_isSignUp) ...[
            Center(
              child: Text(
                'By signing up, you agree to our Terms of Service\nand Privacy Policy. 7-day free trial, no card required.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  // Hardcoded to pass WCAG AA 4.5:1 on #F9F7F3 bg (ratio ~6.0)
                  color: const Color(0xFF595550),
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Toggle sign-up / sign-in
          Center(
            child: GestureDetector(
              onTap: _isLoading
                  ? null
                  : () => setState(() => _isSignUp = !_isSignUp),
              child: RichText(
                text: TextSpan(
                  text: _isSignUp
                      ? 'Already have an account? '
                      : "Don't have an account? ",
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: _isSignUp ? 'Log in' : 'Sign up',
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
              const SizedBox(height: 40),
            ],
          ),
        ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
  }) {
    final colors = AppColors.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ),
      floatingLabelStyle: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.accent,
      ),
      hintText: hint,
      hintStyle:
          GoogleFonts.manrope(color: colors.textMuted, fontSize: 14),
      prefixIcon:
          Icon(prefixIcon, size: 20, color: colors.textMuted),
      filled: true,
      fillColor: colors.bg.withAlpha(180),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Login Hero Background (indigo → pink, animated orbs)
// ═════════════════════════════════════════════════════════════════════════════

class _LoginHeroBg extends StatefulWidget {
  @override
  State<_LoginHeroBg> createState() => _LoginHeroBgState();
}

class _LoginHeroBgState extends State<_LoginHeroBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
          ),
        ),
        child: CustomPaint(
          painter: _LoginOrbsPainter(t: _anim.value),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _LoginOrbsPainter extends CustomPainter {
  final double t;
  _LoginOrbsPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    _orb(canvas, Offset(size.width * (0.82 + math.sin(t * math.pi) * 0.05),
        size.height * (0.15 + math.cos(t * math.pi) * 0.06)),
        size.width * 0.46);
    _orb(canvas, Offset(size.width * (0.1 + math.cos(t * math.pi) * 0.04),
        size.height * (0.7 + math.sin(t * math.pi) * 0.05)),
        size.width * 0.32);
    _orb(canvas, Offset(size.width * 0.5, size.height * 0.05),
        size.width * 0.18);
  }

  void _orb(Canvas canvas, Offset center, double radius) {
    final c = Colors.white.withAlpha(22);
    canvas.drawCircle(center, radius,
        Paint()..shader = RadialGradient(colors: [c, c.withAlpha(0)])
            .createShader(Rect.fromCircle(center: center, radius: radius)));
  }

  @override
  bool shouldRepaint(_LoginOrbsPainter old) => old.t != t;
}

// ═════════════════════════════════════════════════════════════════════════════
// Gradient Background (email step — subtle)
// ═════════════════════════════════════════════════════════════════════════════

class _GradientBackground extends StatelessWidget {
  final AppPalette colors;
  const _GradientBackground({required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.4, 1.0],
            colors: [
              colors.accent.withAlpha(25),
              colors.accentFaint,
              colors.bg,
            ],
          ),
        ),
        child: CustomPaint(
          painter: _OrbPainter(
            color1: colors.accent.withAlpha(18),
            color2: colors.accentLight.withAlpha(12),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final Color color1;
  final Color color2;

  _OrbPainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    // Top-right orb
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [color1, color1.withAlpha(0)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.1),
          radius: size.width * 0.5,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.1),
      size.width * 0.5,
      paint1,
    );

    // Bottom-left orb
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [color2, color2.withAlpha(0)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height * 0.55),
          radius: size.width * 0.45,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.55),
      size.width * 0.45,
      paint2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═════════════════════════════════════════════════════════════════════════════
// Social Icon Button (circular)
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// Full-width auth button (Google / Apple / Email)
// ═════════════════════════════════════════════════════════════════════════════

class _FullWidthAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color bgColor;
  final Color borderColor;

  const _FullWidthAuthButton({
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
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 8,
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

// ═════════════════════════════════════════════════════════════════════════════
// Trust Badge Pill
// ═════════════════════════════════════════════════════════════════════════════

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette colors;
  final bool highlighted;

  const _TrustBadge({
    required this.icon,
    required this.label,
    required this.colors,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.accent.withAlpha(15)
            : colors.card.withAlpha(180),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted
              ? colors.accent.withAlpha(40)
              : colors.border.withAlpha(100),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: highlighted ? colors.accent : colors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: highlighted ? colors.accent : colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
