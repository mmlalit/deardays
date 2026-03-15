import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/settings/presentation/screens/e2e_migration_screen.dart';
import 'package:deardays/services/encryption/encryption_service.dart';

/// Passphrase setup screen for opt-in E2E encryption.
///
/// Used for both initial setup ([isChangingPassphrase] = false) and
/// passphrase changes ([isChangingPassphrase] = true).
class SetE2EPassphraseScreen extends ConsumerStatefulWidget {
  final bool isChangingPassphrase;

  const SetE2EPassphraseScreen({super.key, this.isChangingPassphrase = false});

  @override
  ConsumerState<SetE2EPassphraseScreen> createState() =>
      _SetE2EPassphraseScreenState();
}

class _SetE2EPassphraseScreenState
    extends ConsumerState<SetE2EPassphraseScreen> {
  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showPassphrase = false;
  bool _showConfirm = false;
  bool _consentChecked = false;
  String _passphrase = '';
  String _confirm = '';

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Derived state
  // ---------------------------------------------------------------------------

  int get _strength {
    final p = _passphrase;
    if (p.isEmpty) return 0;
    int score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    return score; // 0–5
  }

  String get _strengthLabel {
    switch (_strength) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return 'Very Strong';
    }
  }

  Color _strengthColor(AppPalette colors) {
    switch (_strength) {
      case 0:
      case 1:
        return AppColors.error;
      case 2:
        return const Color(0xFFF59E0B);
      case 3:
        return const Color(0xFF10B981);
      default:
        return colors.accent;
    }
  }

  bool get _passphraseMatches =>
      _passphrase.isNotEmpty && _passphrase == _confirm;

  bool get _canSubmit =>
      _passphrase.length >= 8 && _passphraseMatches && _consentChecked;

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit(AppPalette colors) async {
    if (!_canSubmit) return;

    final enc = EncryptionService();
    final salt = enc.generateSalt();
    final key = await enc.deriveKey(_passphrase, salt);
    enc.setKey(key);

    final consentAt = DateTime.now().toUtc();

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => E2EMigrationScreen(
          salt: salt,
          consentAt: consentAt,
          isDisabling: false,
          isChangingPassphrase: widget.isChangingPassphrase,
          onComplete: () {
            // Pop back past this screen to the E2E info screen (or settings).
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: colors.textPrimary),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isChangingPassphrase
                        ? 'Change Passphrase'
                        : 'Create Passphrase',
                    style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This is separate from your login password. '
                      'Write it down somewhere safe — it cannot be recovered.',
                      style: GoogleFonts.manrope(
                          fontSize: 14,
                          height: 1.6,
                          color: colors.textSecondary),
                    ),
                    const SizedBox(height: 28),

                    // Passphrase field
                    _FieldLabel(label: 'Passphrase', colors: colors),
                    const SizedBox(height: 6),
                    _PassphraseField(
                      controller: _passphraseController,
                      visible: _showPassphrase,
                      colors: colors,
                      hint: 'At least 8 characters',
                      onToggleVisibility: () =>
                          setState(() => _showPassphrase = !_showPassphrase),
                      onChanged: (v) => setState(() => _passphrase = v),
                    ),
                    const SizedBox(height: 8),

                    // Strength bar (only when something typed)
                    if (_passphrase.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _strength / 5,
                                minHeight: 5,
                                backgroundColor: colors.border,
                                valueColor: AlwaysStoppedAnimation(
                                    _strengthColor(colors)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _strengthLabel,
                            style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _strengthColor(colors)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 16),

                    // Confirm field
                    _FieldLabel(label: 'Confirm passphrase', colors: colors),
                    const SizedBox(height: 6),
                    _PassphraseField(
                      controller: _confirmController,
                      visible: _showConfirm,
                      colors: colors,
                      hint: 'Re-enter your passphrase',
                      onToggleVisibility: () =>
                          setState(() => _showConfirm = !_showConfirm),
                      onChanged: (v) => setState(() => _confirm = v),
                      errorText: _confirm.isNotEmpty && !_passphraseMatches
                          ? 'Passphrases do not match'
                          : null,
                    ),

                    const SizedBox(height: 32),

                    // Consent checkbox
                    GestureDetector(
                      onTap: () =>
                          setState(() => _consentChecked = !_consentChecked),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _consentChecked
                              ? colors.accent.withAlpha(12)
                              : colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _consentChecked
                                ? colors.accent.withAlpha(100)
                                : colors.border,
                            width: _consentChecked ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _consentChecked
                                    ? colors.accent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _consentChecked
                                      ? colors.accent
                                      : colors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: _consentChecked
                                  ? const Icon(Icons.check_rounded,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'I understand that if I forget this passphrase, '
                                'my entries cannot be recovered — not even by '
                                'DearDays support.',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _canSubmit
                              ? colors.accent
                              : colors.border,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _canSubmit ? () => _submit(colors) : null,
                        child: Text(
                          widget.isChangingPassphrase
                              ? 'Update Passphrase'
                              : 'Enable Encryption',
                          style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _canSubmit
                                  ? Colors.white
                                  : colors.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small field widgets
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  final String label;
  final AppPalette colors;
  const _FieldLabel({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary),
    );
  }
}

class _PassphraseField extends StatelessWidget {
  final TextEditingController controller;
  final bool visible;
  final AppPalette colors;
  final String hint;
  final VoidCallback onToggleVisibility;
  final ValueChanged<String> onChanged;
  final String? errorText;

  const _PassphraseField({
    required this.controller,
    required this.visible,
    required this.colors,
    required this.hint,
    required this.onToggleVisibility,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      onChanged: onChanged,
      style: GoogleFonts.manrope(fontSize: 15, color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
        errorText: errorText,
        errorStyle:
            GoogleFonts.manrope(fontSize: 12, color: AppColors.error),
        filled: true,
        fillColor: colors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: colors.textMuted,
          ),
        ),
      ),
    );
  }
}
