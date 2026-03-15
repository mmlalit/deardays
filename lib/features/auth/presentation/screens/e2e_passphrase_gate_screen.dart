import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/services/encryption/encryption_service.dart';

/// Full-screen gate shown after login when the user has E2E encryption enabled.
/// Derives the in-memory key from the entered passphrase + stored salt.
/// [onUnlocked] is called on success; [onForgot] when the user taps
/// "I forgot my passphrase".
class E2EPassphraseGateScreen extends StatefulWidget {
  final String e2eSalt;
  final VoidCallback onUnlocked;
  final VoidCallback onForgot;

  const E2EPassphraseGateScreen({
    super.key,
    required this.e2eSalt,
    required this.onUnlocked,
    required this.onForgot,
  });

  @override
  State<E2EPassphraseGateScreen> createState() =>
      _E2EPassphraseGateScreenState();
}

class _E2EPassphraseGateScreenState extends State<E2EPassphraseGateScreen> {
  final _controller = TextEditingController();
  bool _visible = false;
  bool _loading = false;
  bool _wrongPassphrase = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final passphrase = _controller.text.trim();
    if (passphrase.isEmpty) return;

    setState(() {
      _loading = true;
      _wrongPassphrase = false;
    });

    try {
      final enc = EncryptionService();
      final key = await enc.deriveKey(passphrase, widget.e2eSalt);

      // Verify the key by attempting to decrypt the most recent entry.
      // If there are no entries yet, any passphrase is accepted.
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId != null) {
        final rows = await client
            .from('journal_entries')
            .select('content, is_client_encrypted')
            .eq('user_id', userId)
            .eq('is_client_encrypted', true)
            .order('created_at', ascending: false)
            .limit(1);

        final list = rows as List<dynamic>;
        if (list.isNotEmpty) {
          final ciphertext = list.first['content'] as String?;
          if (ciphertext != null && ciphertext.isNotEmpty) {
            // Will throw EncryptionException if the key is wrong.
            enc.decryptText(ciphertext, key);
          }
        }
      }

      enc.setKey(key);
      if (mounted) widget.onUnlocked();
    } on EncryptionException {
      if (mounted) {
        setState(() {
          _loading = false;
          _wrongPassphrase = true;
        });
      }
    } catch (_) {
      // Network error or no entries — accept and proceed.
      final enc = EncryptionService();
      final key = await enc.deriveKey(_controller.text.trim(), widget.e2eSalt);
      enc.setKey(key);
      if (mounted) widget.onUnlocked();
    }
  }

  void _showForgotWarning(AppPalette colors) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'No way to recover',
          style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary),
        ),
        content: Text(
          'There is no way to recover your encrypted entries without your '
          'passphrase.\n\n'
          'You can disable E2E encryption, which will delete all '
          'encrypted entries. Your account stays active for new entries.',
          style: GoogleFonts.manrope(
              fontSize: 14, height: 1.5, color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Try Again',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onForgot();
            },
            child: Text(
              'Delete encrypted entries',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Lock icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.accent.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded, size: 36, color: colors.accent),
              ),
              const SizedBox(height: 24),

              Text(
                'Enter your encryption\npassphrase',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Required to unlock your journal on this device.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                    fontSize: 14, height: 1.5, color: colors.textSecondary),
              ),
              const SizedBox(height: 36),

              // Passphrase field
              TextField(
                controller: _controller,
                obscureText: !_visible,
                autofocus: true,
                onSubmitted: (_) => _unlock(),
                style: GoogleFonts.manrope(
                    fontSize: 16, color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Your passphrase',
                  hintStyle: GoogleFonts.manrope(color: colors.textMuted),
                  errorText:
                      _wrongPassphrase ? 'Incorrect passphrase' : null,
                  errorStyle: GoogleFonts.manrope(
                      fontSize: 12, color: AppColors.error),
                  filled: true,
                  fillColor: colors.card,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
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
                    borderSide:
                        BorderSide(color: colors.accent, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.error),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _visible = !_visible),
                    icon: Icon(
                      _visible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Unlock button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _loading ? null : _unlock,
                  child: _loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withAlpha(200),
                          ),
                        )
                      : Text(
                          'Unlock',
                          style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                ),
              ),

              const Spacer(),

              // Forgot link
              TextButton(
                onPressed: () => _showForgotWarning(colors),
                child: Text(
                  'I forgot my passphrase',
                  style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: colors.textMuted,
                      decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
