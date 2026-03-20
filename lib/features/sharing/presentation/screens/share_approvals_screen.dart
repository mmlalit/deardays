import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';
import 'package:deardays/features/sharing/presentation/providers/sharing_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShareApprovalsScreen
// Sarah sees ALL pending access requests across all her memories.
// ─────────────────────────────────────────────────────────────────────────────

class ShareApprovalsScreen extends ConsumerWidget {
  const ShareApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final pendingAsync = ref.watch(pendingShareRequestsProvider);

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
          'Waiting for approval',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: pendingAsync.when(
        data: (requests) => requests.isEmpty
            ? _buildEmpty(colors)
            : _buildList(context, ref, colors, requests),
        loading: () => Center(child: CircularProgressIndicator(color: colors.accent)),
        error: (_, __) => Center(
          child: Text('Could not load', style: GoogleFonts.manrope(color: colors.textMuted)),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    AppPalette colors,
    List<MemoryShare> requests,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        // Header context
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.pending_actions_rounded, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${requests.length} ${requests.length == 1 ? 'person wants' : 'people want'} to see your memories',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...requests.map((r) => _ApprovalCard(share: r, colors: colors)),
      ],
    );
  }

  Widget _buildEmpty(AppPalette colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.accent.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline_rounded, color: colors.accent, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'All caught up',
              style: GoogleFonts.newsreader(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No pending requests right now.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Approval card — one per pending request
// ─────────────────────────────────────────────────────────────────────────────

class _ApprovalCard extends ConsumerStatefulWidget {
  final MemoryShare share;
  final AppPalette colors;
  const _ApprovalCard({required this.share, required this.colors});

  @override
  ConsumerState<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<_ApprovalCard> {
  bool _done = false;
  bool? _approved;

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildOutcome(widget.colors);

    final colors = widget.colors;
    final share = widget.share;
    final actionsState = ref.watch(shareActionsProvider);
    final isLoading = actionsState.isLoading;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withAlpha(80)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 16, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Person + memory context
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(name: share.recipientName ?? '?', color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        share.recipientName ?? 'Someone',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'wants to see a memory',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (share.requestedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _timeAgo(share.requestedAt!),
                          style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Memory title pill
          if (share.memoryTitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.accent.withAlpha(12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_stories_rounded, size: 14, color: colors.accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        share.memoryTitle!,
                        style: GoogleFonts.newsreader(
                          fontSize: 13,
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
            ),

          Divider(color: colors.border, height: 1),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : () => _respond(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: Text(
                      'Deny',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isLoading ? null : () => _respond(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Approve',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _respond(bool approve) async {
    final actions = ref.read(shareActionsProvider.notifier);
    final ok = approve
        ? await actions.approve(widget.share.id)
        : await actions.deny(widget.share.id);
    if (ok && mounted) {
      setState(() {
        _done = true;
        _approved = approve;
      });
    }
  }

  Widget _buildOutcome(AppPalette colors) {
    final isApproved = _approved == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(
            isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isApproved ? Colors.green : colors.textMuted,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isApproved
                  ? '${widget.share.recipientName ?? 'They'} can now see the memory'
                  : '${widget.share.recipientName ?? 'They'} was denied access',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: isApproved ? colors.textPrimary : colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final Color color;
  const _Avatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      );
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return DateFormat('MMM d').format(dt);
}
