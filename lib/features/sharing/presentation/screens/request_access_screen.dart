import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';
import 'package:deardays/features/sharing/presentation/providers/sharing_provider.dart';
import 'package:deardays/features/sharing/presentation/screens/waiting_approval_screen.dart';

class RequestAccessScreen extends ConsumerStatefulWidget {
  final String token;
  const RequestAccessScreen({super.key, required this.token});

  @override
  ConsumerState<RequestAccessScreen> createState() => _RequestAccessScreenState();
}

class _RequestAccessScreenState extends ConsumerState<RequestAccessScreen> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  MemoryShare? _share;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShare();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _loadShare() async {
    try {
      final share = await ref
          .read(sharingRepositoryProvider)
          .getShareByToken(widget.token);
      if (!mounted) return;
      setState(() {
        _share = share;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; });
    }
  }

  Future<void> _submitRequest() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _nameFocus.requestFocus();
      return;
    }
    if (_share == null) return;

    setState(() { _submitting = true; });

    final userId = Supabase.instance.client.auth.currentUser?.id;
    final ok = await ref.read(shareActionsProvider.notifier).requestAccess(
      shareId: _share!.id,
      recipientName: name,
      recipientId: userId,
    );

    if (!mounted) return;
    setState(() { _submitting = false; });

    if (ok) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => WaitingApprovalScreen(
          share: _share!,
          recipientName: name,
        ),
      ));
    } else {
      setState(() { _error = 'Something went wrong. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : _buildContent(colors),
    );
  }

  Widget _buildContent(AppPalette colors) {
    if (_share == null) return _buildInvalidToken(colors);

    switch (_share!.status) {
      case ShareStatus.revoked:
        return _buildRevoked(colors);
      case ShareStatus.expired:
        return _buildExpired(colors);
      case ShareStatus.approved:
        // Already approved — go straight to memory
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/home');
        });
        return const SizedBox.shrink();
      default:
        return _buildRequestForm(colors);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Main form — blurred preview + name input
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRequestForm(AppPalette colors) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 32),

            // ── Blurred memory card ──
            _buildBlurredCard(colors),
            const SizedBox(height: 32),

            // ── Headline ──
            Text(
              "You've been invited to\nview a private memory",
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Enter your name so the owner\nknows who's requesting access.",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // ── Name field ──
            TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Your name',
                hintStyle: GoogleFonts.manrope(color: colors.textMuted),
                filled: true,
                fillColor: colors.card,
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14,
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: GoogleFonts.manrope(fontSize: 13, color: Colors.red),
              ),
            ],
            const SizedBox(height: 20),

            // ── Request button ──
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submitRequest,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : Text(
                        'Request to View',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Privacy note ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: colors.textMuted),
                const SizedBox(width: 5),
                Text(
                  'Only the owner can see your request',
                  style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurredCard(AppPalette colors) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent.withAlpha(60),
            colors.accent.withAlpha(30),
          ],
        ),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Blurred lines — simulate blurred text
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _blurLine(colors, 0.6, 14),
                const SizedBox(height: 8),
                _blurLine(colors, 0.9, 20),
                const SizedBox(height: 6),
                _blurLine(colors, 0.7, 14),
              ],
            ),
          ),
          // Lock overlay
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.card.withAlpha(220),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(Icons.lock_rounded, color: colors.accent, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blurLine(AppPalette colors, double widthFactor, double height) =>
      FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: colors.accent.withAlpha(40),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Error states
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStateScreen(AppPalette colors, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/home'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  side: BorderSide(color: colors.border),
                ),
                child: Text(
                  'Start your DearDays',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvalidToken(AppPalette colors) => _buildStateScreen(
        colors,
        icon: Icons.link_off_rounded,
        iconColor: colors.textMuted,
        title: 'This link is no longer valid',
        subtitle: 'The memory may have been removed\nor the link has expired.',
      );

  Widget _buildRevoked(AppPalette colors) => _buildStateScreen(
        colors,
        icon: Icons.lock_rounded,
        iconColor: colors.accent,
        title: 'This memory is private',
        subtitle: 'The owner has kept this\nmemory private.',
      );

  Widget _buildExpired(AppPalette colors) => _buildStateScreen(
        colors,
        icon: Icons.hourglass_empty_rounded,
        iconColor: colors.textMuted,
        title: 'This link has expired',
        subtitle: 'Ask the owner to share\nthe memory with you again.',
      );
}
