import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/features/book/data/models/book.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-create default book based on user's organization preference
    _ensureDefaultBook();
  }

  Future<void> _ensureDefaultBook() async {
    try {
      final profile = await ref.read(profileProvider.future);
      final organization = profile?.bookOrganization ?? 'yearly';
      final repo = ref.read(bookRepositoryProvider);
      await repo.ensureDefaultBook(organization);
      ref.invalidate(booksProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: booksAsync.when(
                data: (books) => books.isEmpty
                    ? _buildEmptyState(context)
                    : _buildBookList(context, books),
                loading: () => _buildSkeletonList(),
                error: (_, __) => _buildEmptyState(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Center(
        child: Text(
          'My Books',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBookList(BuildContext context, List<Book> books) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildBookListTile(context, books[index]),
    );
  }

  Widget _buildBookListTile(BuildContext context, Book book) {
    final color = _parseColor(book.coverColor);
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.accent.withAlpha(13)),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withAlpha(200)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
              child: Center(
                child: Icon(Icons.auto_stories, color: Colors.white.withAlpha(200), size: 22),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateRange(book),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textMuted, size: 20),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => _buildSkeletonTile(),
    );
  }

  Widget _buildSkeletonTile() {
    final colors = AppColors.of(context);
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.accent.withAlpha(13)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonBox(width: 140, height: 14),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 90, height: 11),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.accent.withAlpha(30), colors.accentFaint],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 40,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your books will appear here',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start journaling and your entries will\nautomatically be organized into books.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: Text(
                'Start Writing',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.bg,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateRange(Book book) {
    final start = '${_shortMonth(book.startDate.month)} ${book.startDate.year}';
    if (book.endDate == null) return '$start - Present';
    final end = '${_shortMonth(book.endDate!.month)} ${book.endDate!.year}';
    if (start == end) return start;
    return '$start - $end';
  }

  String _shortMonth(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    if (hexCode.length == 6) {
      return Color(int.parse('FF$hexCode', radix: 16));
    }
    return AppColors.of(context).accent;
  }
}
