import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';
import 'package:deardays/features/sharing/presentation/providers/sharing_provider.dart';

class SharedWithMeScreen extends ConsumerWidget {
  const SharedWithMeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final itemsAsync = ref.watch(sharedWithMeProvider);

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
          'Shared with me',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: itemsAsync.when(
        data: (items) => items.isEmpty
            ? _buildEmpty(colors)
            : _buildList(context, ref, colors, items),
        loading: () => Center(child: CircularProgressIndicator(color: colors.accent)),
        error: (_, __) => Center(
          child: Text('Could not load', style: GoogleFonts.manrope(color: colors.textMuted)),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, AppPalette colors, List<SharedMemoryItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _SharedMemoryCard(item: items[i], colors: colors),
    );
  }

  Widget _buildEmpty(AppPalette colors) {
    return Padding(
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
            child: Icon(Icons.inbox_rounded, color: colors.accent, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'No memories shared with you yet',
            style: GoogleFonts.newsreader(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'When someone shares a memory\nwith you, it will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared memory card
// ─────────────────────────────────────────────────────────────────────────────

class _SharedMemoryCard extends ConsumerStatefulWidget {
  final SharedMemoryItem item;
  final AppPalette colors;
  const _SharedMemoryCard({required this.item, required this.colors});

  @override
  ConsumerState<_SharedMemoryCard> createState() => _SharedMemoryCardState();
}

class _SharedMemoryCardState extends ConsumerState<_SharedMemoryCard> {
  bool _expanded = false;
  final _commentController = TextEditingController();
  bool _showCommentField = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _isRevoked => widget.item.share.status == ShareStatus.revoked;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final item = widget.item;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isRevoked ? colors.border.withAlpha(80) : colors.border,
        ),
        boxShadow: _isRevoked
            ? []
            : [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 16, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: sharer name + date ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _isRevoked
                        ? colors.textMuted.withAlpha(20)
                        : colors.accent.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (item.sharerName?.isNotEmpty == true ? item.sharerName![0] : '?').toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _isRevoked ? colors.textMuted : colors.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.sharerName ?? 'Someone',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isRevoked ? colors.textMuted : colors.textPrimary,
                        ),
                      ),
                      Text(
                        DateFormat('MMMM d, yyyy').format(item.memoryDate),
                        style: GoogleFonts.manrope(fontSize: 10, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (_isRevoked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.border.withAlpha(80),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Private',
                      style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: colors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Memory title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              item.memoryTitle,
              style: GoogleFonts.newsreader(
                fontSize: _isRevoked ? 15 : 18,
                fontWeight: FontWeight.w700,
                color: _isRevoked ? colors.textMuted : colors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Story excerpt (blurred if revoked) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _isRevoked
                ? _buildRevokedState(colors)
                : _buildStoryExcerpt(colors, item),
          ),
          const SizedBox(height: 14),

          if (!_isRevoked) ...[
            Divider(color: colors.border, height: 1),
            // ── Actions: comment ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _showCommentField = !_showCommentField),
                    icon: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: colors.textSecondary),
                    label: Text(
                      'Leave a comment',
                      style: GoogleFonts.manrope(fontSize: 12, color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            if (_showCommentField)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: GoogleFonts.manrope(fontSize: 13, color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Write a comment…',
                          hintStyle: GoogleFonts.manrope(fontSize: 13, color: colors.textMuted),
                          filled: true,
                          fillColor: colors.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(color: colors.accent, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        // TODO: persist comment to Supabase in Phase 2
                        setState(() {
                          _showCommentField = false;
                          _commentController.clear();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Comment sent!',
                              style: GoogleFonts.manrope(color: Colors.white),
                            ),
                            backgroundColor: colors.accent,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
          ] else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildStoryExcerpt(AppPalette colors, SharedMemoryItem item) {
    final full = item.memoryExcerpt;
    final short = full.length > 120 ? '${full.substring(0, 120)}…' : full;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _expanded ? full : short,
            style: GoogleFonts.newsreader(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.65,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (full.length > 120)
            Text(
              _expanded ? 'Show less' : 'Read more',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRevokedState(AppPalette colors) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.border.withAlpha(60),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_rounded, size: 16, color: colors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'The owner has made this memory private.',
                style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted, height: 1.4),
              ),
            ),
          ],
        ),
      );
}
