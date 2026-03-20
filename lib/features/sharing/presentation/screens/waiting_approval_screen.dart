import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';
import 'package:deardays/features/sharing/presentation/providers/sharing_provider.dart';

class WaitingApprovalScreen extends ConsumerStatefulWidget {
  final MemoryShare share;
  final String recipientName;

  const WaitingApprovalScreen({
    super.key,
    required this.share,
    required this.recipientName,
  });

  @override
  ConsumerState<WaitingApprovalScreen> createState() =>
      _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState
    extends ConsumerState<WaitingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _listenForApproval();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Watch Supabase Realtime for status change
  void _listenForApproval() {
    final repo = ref.read(sharingRepositoryProvider);
    repo.watchShare(widget.share.id).listen((rows) {
      if (!mounted || rows.isEmpty) return;
      final status = ShareStatus.fromString(rows.first['status'] as String);
      if (status == ShareStatus.approved) {
        _onApproved();
      } else if (status == ShareStatus.denied) {
        _onDenied();
      }
    });
  }

  void _onApproved() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => _ApprovedScreen(share: widget.share),
    ));
  }

  void _onDenied() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => _DeniedScreen(),
    ));
  }

  Future<void> _cancelRequest() async {
    // Reset the share back to unclaimed
    await ref.read(sharingRepositoryProvider).requestAccess(
      shareId: widget.share.id,
      recipientName: '',
    );
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Pulsing hourglass ──
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    color: colors.accent,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Request sent',
                style: GoogleFonts.newsreader(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "You'll get a notification the\nmoment they approve.",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  color: colors.textSecondary,
                  height: 1.55,
                ),
              ),

              const Spacer(flex: 2),

              // ── Divider ──
              Divider(color: colors.border),
              const SizedBox(height: 20),

              // ── Soft CTA ──
              Text(
                'While you wait…',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/home'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    'Start capturing your own memories',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              GestureDetector(
                onTap: _cancelRequest,
                child: Text(
                  'Cancel request',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: colors.textMuted,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Approved screen — shown when Sarah says yes
// ─────────────────────────────────────────────────────────────────────────────

class _ApprovedScreen extends StatelessWidget {
  final MemoryShare share;
  const _ApprovedScreen({required this.share});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.green, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                "You're in!",
                style: GoogleFonts.newsreader(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your request was approved.\nTap below to view the memory.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/shared-with-me'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    'View Memory',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Denied screen — shown when Sarah says no (dignified, no "rejected" language)
// ─────────────────────────────────────────────────────────────────────────────

class _DeniedScreen extends StatelessWidget {
  const _DeniedScreen();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colors.accent.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded, color: colors.accent, size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                'This memory is private',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'The owner has kept this\nmemory private.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.55,
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
                    'Start your own DearDays',
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
      ),
    );
  }
}
