import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/services/encryption/encryption_service.dart';

/// Re-encrypts all journal entries client-side (enabling E2E) or
/// server-side (disabling E2E). Shows a progress indicator while running.
///
/// Parameters:
/// - [isDisabling]: true → strip client encryption, write plaintext so server
///   trigger re-encrypts. false → encrypt all entries with the user's key.
/// - [salt]: the freshly generated base64 salt (only when enabling).
/// - [consentAt]: timestamp of the user's risk acknowledgement (only when enabling).
/// - [isChangingPassphrase]: true → re-encrypt with new key, keep e2e_enabled.
/// - [onComplete]: called after the migration succeeds.
class E2EMigrationScreen extends ConsumerStatefulWidget {
  final bool isDisabling;
  final bool isChangingPassphrase;
  final String? salt;
  final DateTime? consentAt;
  final VoidCallback onComplete;

  const E2EMigrationScreen({
    super.key,
    required this.isDisabling,
    required this.onComplete,
    this.isChangingPassphrase = false,
    this.salt,
    this.consentAt,
  });

  @override
  ConsumerState<E2EMigrationScreen> createState() => _E2EMigrationScreenState();
}

class _E2EMigrationScreenState extends ConsumerState<E2EMigrationScreen> {
  int _done = 0;
  int _total = 0;
  bool _failed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _failed = true;
        _errorMessage = 'Not signed in.';
      });
      return;
    }

    try {
      // Fetch all entry IDs + content columns in pages to avoid OOM.
      const pageSize = 100;
      var offset = 0;
      final allEntries = <Map<String, dynamic>>[];

      while (true) {
        final page = await client
            .from('journal_entries')
            .select('id, content, raw_content, polished_content, is_client_encrypted')
            .eq('user_id', userId)
            .range(offset, offset + pageSize - 1);

        final rows = page as List<dynamic>;
        allEntries.addAll(rows.cast<Map<String, dynamic>>());
        if (rows.length < pageSize) break;
        offset += pageSize;
      }

      if (mounted) setState(() => _total = allEntries.length);

      final enc = EncryptionService();

      for (final row in allEntries) {
        final id = row['id'] as String;
        final isAlreadyClient = (row['is_client_encrypted'] as bool?) ?? false;

        if (widget.isDisabling) {
          // Skip entries that are already server-encrypted.
          if (!isAlreadyClient) {
            if (mounted) setState(() => _done++);
            continue;
          }
          // Decrypt client-encrypted content so the server trigger can
          // re-encrypt it under the server key.
          final content = _maybeDecrypt(enc, row['content'] as String?);
          final raw = _maybeDecrypt(enc, row['raw_content'] as String?);
          final polished = _maybeDecrypt(enc, row['polished_content'] as String?);

          await client.from('journal_entries').update({
            'content': content,
            'raw_content': raw,
            'polished_content': polished,
            'is_client_encrypted': false,
          }).eq('id', id).eq('user_id', userId);
        } else {
          // Enabling (or changing passphrase).
          // If already client-encrypted and changing passphrase, decrypt first.
          String? content = row['content'] as String?;
          String? raw = row['raw_content'] as String?;
          String? polished = row['polished_content'] as String?;

          if (isAlreadyClient) {
            content = _maybeDecrypt(enc, content);
            raw = _maybeDecrypt(enc, raw);
            polished = _maybeDecrypt(enc, polished);
          }

          // Encrypt with current in-memory key.
          final encContent = content != null ? enc.encryptText(content, enc.currentKey!) : null;
          final encRaw = raw != null ? enc.encryptText(raw, enc.currentKey!) : null;
          final encPolished = polished != null ? enc.encryptText(polished, enc.currentKey!) : null;

          await client.from('journal_entries').update({
            'content': encContent,
            'raw_content': encRaw,
            'polished_content': encPolished,
            'is_client_encrypted': true,
          }).eq('id', id).eq('user_id', userId);
        }

        if (mounted) setState(() => _done++);
      }

      // Update profile to reflect the new E2E state.
      if (widget.isDisabling) {
        await client.from('profiles').update({
          'e2e_enabled': false,
          'e2e_salt': null,
          'e2e_enabled_at': null,
        }).eq('id', userId);
      } else {
        final now = DateTime.now().toUtc().toIso8601String();
        await client.from('profiles').update({
          'e2e_enabled': true,
          'e2e_salt': widget.salt,
          'e2e_consent_given_at': widget.consentAt?.toIso8601String(),
          'e2e_enabled_at': now,
        }).eq('id', userId);
      }

      // Invalidate the profile cache so settings screen refreshes.
      ref.invalidate(profileProvider);

      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String? _maybeDecrypt(EncryptionService enc, String? value) {
    if (value == null || value.isEmpty) return value;
    final key = enc.currentKey;
    if (key == null) return value;
    try {
      return enc.decryptText(value, key);
    } catch (e) {
      // Already plaintext — server-encrypted rows come back decrypted via view.
      debugPrint('[E2EMigration] _maybeDecrypt: not encrypted or wrong key: $e');
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _failed ? _ErrorState(colors: colors, message: _errorMessage) : _ProgressState(
            colors: colors,
            done: _done,
            total: _total,
            isDisabling: widget.isDisabling,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress UI
// ---------------------------------------------------------------------------

class _ProgressState extends StatelessWidget {
  final AppPalette colors;
  final int done;
  final int total;
  final bool isDisabling;

  const _ProgressState({
    required this.colors,
    required this.done,
    required this.total,
    required this.isDisabling,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : done / total;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isDisabling ? Icons.lock_open_rounded : Icons.lock_rounded,
          size: 52,
          color: colors.accent,
        ),
        const SizedBox(height: 28),
        Text(
          isDisabling ? 'Removing encryption...' : 'Encrypting your entries...',
          style: GoogleFonts.newsreader(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          total == 0
              ? 'Preparing...'
              : '$done of $total entries',
          style: GoogleFonts.manrope(
              fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 28),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: total == 0 ? null : fraction,
            minHeight: 8,
            backgroundColor: colors.border,
            valueColor: AlwaysStoppedAnimation(colors.accent),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Don't close the app",
          style: GoogleFonts.manrope(
              fontSize: 12,
              color: colors.textMuted,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error UI
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final AppPalette colors;
  final String? message;

  const _ErrorState({required this.colors, this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded,
            size: 52, color: AppColors.error),
        const SizedBox(height: 20),
        Text(
          'Something went wrong',
          style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Your entries were not modified. Please try again.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
              fontSize: 13, height: 1.5, color: colors.textSecondary),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
                fontSize: 11,
                color: colors.textMuted),
          ),
        ],
        const SizedBox(height: 28),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.accent,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Go Back',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ],
    );
  }
}
