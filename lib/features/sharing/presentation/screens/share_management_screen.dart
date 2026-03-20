import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';
import 'package:deardays/features/sharing/presentation/providers/sharing_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShareManagementScreen
// Sarah sees who has access to a specific memory and can stop sharing.
// ─────────────────────────────────────────────────────────────────────────────

class ShareManagementScreen extends ConsumerWidget {
  final String memoryId;
  final String memoryTitle;

  const ShareManagementScreen({
    super.key,
    required this.memoryId,
    required this.memoryTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final sharesAsync = ref.watch(sharesForMemoryProvider(memoryId));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Who can see this',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: sharesAsync.when(
        data: (shares) => _buildList(context, ref, colors, shares),
        loading: () => Center(child: CircularProgressIndicator(color: colors.accent)),
        error: (_, __) => Center(
          child: Text('Could not load', style: GoogleFonts.manrope(color: colors.textMuted)),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, AppPalette colors, List<MemoryShare> shares) {
    final active  = shares.where((s) => s.status == ShareStatus.approved).toList();
    final pending = shares.where((s) => s.isPending).toList();
    final denied  = shares.where((s) => s.status == ShareStatus.denied || s.status == ShareStatus.revoked).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // Memory title context
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.accent.withAlpha(15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_stories_rounded, color: colors.accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  memoryTitle,
                  style: GoogleFonts.newsreader(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (pending.isNotEmpty) ...[
          _sectionLabel(colors, 'Waiting for your approval', Colors.orange),
          const SizedBox(height: 8),
          ...pending.map((s) => _PendingCard(share: s, colors: colors)),
          const SizedBox(height: 24),
        ],

        if (active.isNotEmpty) ...[
          _sectionLabel(colors, 'Has access', Colors.green),
          const SizedBox(height: 8),
          ...active.map((s) => _ActiveCard(share: s, colors: colors, memoryId: memoryId, memoryTitle: memoryTitle)),
          const SizedBox(height: 24),
        ],

        if (denied.isNotEmpty) ...[
          _sectionLabel(colors, 'No access', colors.textMuted),
          const SizedBox(height: 8),
          ...denied.map((s) => _DeniedCard(share: s, colors: colors)),
          const SizedBox(height: 24),
        ],

        if (shares.isEmpty) _buildEmpty(colors),
      ],
    );
  }

  Widget _sectionLabel(AppPalette colors, String label, Color dotColor) => Row(
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );

  Widget _buildEmpty(AppPalette colors) => Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Column(
            children: [
              Icon(Icons.people_outline_rounded, size: 40, color: colors.textMuted.withAlpha(100)),
              const SizedBox(height: 12),
              Text(
                'No shares yet',
                style: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Card: Pending — requires Sarah's approval
// ─────────────────────────────────────────────────────────────────────────────

class _PendingCard extends ConsumerWidget {
  final MemoryShare share;
  final AppPalette colors;
  const _PendingCard({required this.share, required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(shareActionsProvider.notifier);
    final state   = ref.watch(shareActionsProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withAlpha(80)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(colors, share.recipientName ?? '?', Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      share.recipientName ?? 'Unknown',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (share.requestedAt != null)
                      Text(
                        'Requested ${_timeAgo(share.requestedAt!)}',
                        style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isLoading ? null : () async {
                    await actions.deny(share.id);
                    if (context.mounted) ref.invalidate(sharesForMemoryProvider(share.memoryId));
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Deny', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: state.isLoading ? null : () async {
                    await actions.approve(share.id);
                    if (context.mounted) ref.invalidate(sharesForMemoryProvider(share.memoryId));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: state.isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Approve', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card: Active — has access, can be revoked
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveCard extends ConsumerWidget {
  final MemoryShare share;
  final AppPalette colors;
  final String memoryId;
  final String memoryTitle;
  const _ActiveCard({required this.share, required this.colors, required this.memoryId, required this.memoryTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          _avatar(colors, share.recipientName ?? '?', Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  share.recipientName ?? 'Unknown',
                  style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
                Text(
                  share.viewCount > 0
                      ? 'Viewed ${share.viewCount} time${share.viewCount == 1 ? '' : 's'}'
                      : 'Not yet viewed',
                  style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _confirmRevoke(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Stop',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRevoke(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stop sharing with ${share.recipientName}?',
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '${share.recipientName} will no longer be able to view this memory. Their comment will remain visible to you.',
                style: GoogleFonts.manrope(fontSize: 13, color: colors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(shareActionsProvider.notifier).revoke(share.id);
                    if (context.mounted) ref.invalidate(sharesForMemoryProvider(memoryId));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text('Stop Sharing', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Keep Sharing', style: GoogleFonts.manrope(color: colors.textSecondary)),
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
// Card: Denied / Revoked
// ─────────────────────────────────────────────────────────────────────────────

class _DeniedCard extends StatelessWidget {
  final MemoryShare share;
  final AppPalette colors;
  const _DeniedCard({required this.share, required this.colors});

  @override
  Widget build(BuildContext context) {
    final label = share.status == ShareStatus.revoked ? 'Access removed' : 'Denied';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _avatar(colors, share.recipientName ?? '?', colors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              share.recipientName ?? 'Unknown',
              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _avatar(AppPalette colors, String name, Color color) => Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24)   return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
