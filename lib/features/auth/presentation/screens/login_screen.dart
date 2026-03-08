import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/services/auth/auth_service.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/features/auth/presentation/screens/pin_screen.dart';
import 'package:deardays/features/auth/presentation/screens/pattern_screen.dart';

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
  bool _isSignUp = true;
  bool _isLoading = false;
  bool _showEmailForm = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _lockMethod = 'none';

  // Consent (signup only)
  bool _healthConsentGiven = false;

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
    } catch (_) {}
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
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
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
        if (response.user != null && mounted) widget.onLogin();
      } else {
        final response = await _authService.signInWithEmail(email, password);
        if (response.user != null && mounted) widget.onLogin();
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } on AuthEncryptionException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Something went wrong. Please try again.');
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
      _showError('Enter your email first.');
      return;
    }
    try {
      await _authService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password reset email sent.'),
            backgroundColor: const Color(0xFF111111),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (mounted) _showError('Could not send reset email.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animation);
            return SlideTransition(position: offsetAnimation, child: child);
          },
          child: _showEmailForm
              ? _buildEmailStep(key: const ValueKey('email'))
              : _buildSocialStep(key: const ValueKey('social')),
        ),
      ),
    );
  }

  // ─── Step 1: Social login + branding ───

  Widget _buildSocialStep({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 60),

          // Warm gradient circle with icon
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.of(context).accentLight.withAlpha(100),
                    AppColors.of(context).accent.withAlpha(60),
                  ],
                ),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 36,
                color: AppColors.of(context).accent,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // App name
          Center(
            child: Text(
              'DearDays',
              style: GoogleFonts.manrope(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: AppColors.of(context).textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Tagline
          Center(
            child: Text(
              'Your life, your story.',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: AppColors.of(context).textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Continue with Apple
          _AppleButton(
            onPressed: _isLoading ? null : _handleAppleSignIn,
          ),
          const SizedBox(height: 12),

          // Continue with Google
          _GoogleButton(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
          ),
          const SizedBox(height: 12),

          // Continue with Email
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => setState(() => _showEmailForm = true),
              icon: Icon(Icons.mail_outline_rounded,
                  size: 20, color: AppColors.of(context).textPrimary),
              label: Text(
                'Continue with Email',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.of(context).textPrimary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.of(context).border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Inline terms
          Center(
            child: Text(
              'By continuing, you agree to our Terms of\nService and Privacy Policy.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.of(context).textMuted,
                height: 1.5,
              ),
            ),
          ),

          // Quick-unlock section for returning users
          if (_biometricAvailable && _biometricEnabled ||
              _lockMethod == 'pin' ||
              _lockMethod == 'pattern') ...[
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                    child: Divider(color: AppColors.of(context).border, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'WELCOME BACK',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.of(context).textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                    child: Divider(color: AppColors.of(context).border, thickness: 1)),
              ],
            ),
            const SizedBox(height: 16),
            if (_biometricAvailable && _biometricEnabled)
              _QuickUnlockButton(
                icon: Icons.fingerprint,
                label: 'Unlock with Face ID / Fingerprint',
                onPressed: _isLoading ? null : _handleBiometricLogin,
              ),
            if (_lockMethod == 'pin')
              _QuickUnlockButton(
                icon: Icons.dialpad_rounded,
                label: 'Unlock with PIN',
                onPressed: _isLoading ? null : _handlePinLogin,
              ),
            if (_lockMethod == 'pattern')
              _QuickUnlockButton(
                icon: Icons.pattern_rounded,
                label: 'Unlock with Pattern',
                onPressed: _isLoading ? null : _handlePatternLogin,
              ),
          ],

          if (_isLoading) ...[
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.of(context).accent,
                ),
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Step 2: Email form ───

  Widget _buildEmailStep({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() => _showEmailForm = false),
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppColors.of(context).textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(height: 24),

          // Heading
          Text(
            _isSignUp ? 'Create your journal' : 'Welcome back',
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isSignUp
                ? 'Start capturing your story today.'
                : 'Pick up where you left off.',
            style: GoogleFonts.manrope(
              fontSize: 15,
              color: AppColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Name field (signup only)
          if (_isSignUp) ...[
            _FieldLabel('What should we call you?'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              enabled: !_isLoading,
              decoration: _inputDecoration(
                hint: 'Your name (optional)',
                prefixIcon: Icons.person_outline_rounded,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Email field
          _FieldLabel('Email'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            decoration: _inputDecoration(
              hint: 'you@example.com',
              prefixIcon: Icons.mail_outline_rounded,
            ),
          ),
          const SizedBox(height: 20),

          // Password field
          _FieldLabel('Password'),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_isLoading,
            decoration: _inputDecoration(
              hint: _isSignUp ? 'Create a password' : 'Enter your password',
              prefixIcon: Icons.lock_outline_rounded,
            ).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.of(context).textMuted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),

          // Forgot password (sign-in only)
          if (!_isSignUp) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _isLoading ? null : _handleForgotPassword,
                child: Text(
                  'Forgot password?',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.of(context).accent,
                  ),
                ),
              ),
            ),
          ],

          // Health consent (signup only)
          if (_isSignUp) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _isLoading
                  ? null
                  : () =>
                      setState(() => _healthConsentGiven = !_healthConsentGiven),
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
                          : (v) => setState(
                              () => _healthConsentGiven = v ?? false),
                      activeColor: AppColors.of(context).accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(color: AppColors.of(context).border, width: 1.5),
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
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppColors.of(context).textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: '(optional)',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: AppColors.of(context).textMuted,
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

          const SizedBox(height: 28),

          // Primary CTA
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleEmailAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: AppColors.of(context).accent.withAlpha(128),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Inline terms / trial info
          if (_isSignUp) ...[
            Center(
              child: Text(
                'By signing up, you agree to our Terms of Service\nand Privacy Policy. 30-day free trial, no card required.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.of(context).textMuted,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

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
                    color: AppColors.of(context).textSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: _isSignUp ? 'Log in' : 'Sign up',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.of(context).accent,
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
    );
  }

  // ─── Helpers ───

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(color: AppColors.of(context).textMuted, fontSize: 14),
      prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.of(context).textMuted),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.of(context).border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.of(context).border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.of(context).accent, width: 2),
      ),
    );
  }
}

// ─── Field label ───

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.of(context).textPrimary,
      ),
    );
  }
}

// ─── Apple Sign In Button (follows Apple HIG) ───

class _AppleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _AppleButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.apple, size: 22, color: Colors.white),
        label: Text(
          'Continue with Apple',
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ─── Google Sign In Button ───

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GoogleButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Text(
          'G',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF4285F4),
          ),
        ),
        label: Text(
          'Continue with Google',
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.of(context).textPrimary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.of(context).border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ─── Quick unlock button for returning users ───

class _QuickUnlockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _QuickUnlockButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22, color: AppColors.of(context).accent),
        label: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.of(context).accent,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.of(context).accent,
          side: BorderSide(color: AppColors.of(context).accent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
