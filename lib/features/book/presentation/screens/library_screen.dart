import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/utils/chapter_visuals.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: booksAsync.when(
          data: (books) => _buildContent(context, books),
          loading: () => _buildLoadingContent(context),
          error: (_, __) => _buildContent(context, []),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Book> books) {
    final isDemoMode = ref.watch(demoModeProvider);
    final showSamples = books.isEmpty || isDemoMode;

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(child: _buildHeader(context)),
        // AI Insight Card
        SliverToBoxAdapter(child: _buildAiInsightCard(context, books.length)),
        // Section Title
        SliverToBoxAdapter(child: _buildSectionTitle(context)),
        // Book Grid — show sample chapters in demo mode or for first-time users
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.68,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (showSamples) {
                  return _buildSampleChapterCard(context, _sampleChapters[index]);
                }
                return _buildBookCard(context, books[index]);
              },
              childCount: showSamples ? _sampleChapters.length : books.length,
            ),
          ),
        ),
        // Create Chapter Button
        SliverToBoxAdapter(child: _buildCreateChapterButton(context)),
        // Bottom spacing for nav bar
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: colors.accent, size: 22),
          const SizedBox(width: 8),
          Text(
            'Chapters',
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.search, color: colors.textSecondary, size: 22),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_vert, color: colors.textSecondary, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsightCard(BuildContext context, int bookCount) {
    final isDemoMode = ref.watch(demoModeProvider);
    final memoryCount = isDemoMode ? 45 : bookCount * 8;
    final chapterCount = isDemoMode ? 6 : (bookCount > 0 ? bookCount : 6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B4FE8), Color(0xFF5B6CF9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + Title
            Row(
              children: [
                const Text('📖', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Text(
                  'My Life Book',
                  style: GoogleFonts.newsreader(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Subtitle
            Text(
              'Read your entire life story chapter by chapter in one place.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Colors.white.withAlpha(220),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            // Stats
            Text(
              '$memoryCount MEMORIES • $chapterCount CHAPTERS',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withAlpha(180),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 18),
            // Start Reading button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => context.push('/my-life-book'),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF3B4FE8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Start Reading',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B4FE8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Your Life Stories',
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          Text(
            'View all',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(BuildContext context, Book book) {
    final colors = AppColors.of(context);
    final visual = ChapterVisual.forTitle(book.title);
    // Use AI-generated cover query for subtitle when no custom subtitle exists
    final coverQuery = ref.watch(bookCoverQueryProvider(book.title)).valueOrNull;

    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.accent.withAlpha(13)),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(15),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image: user photo → stock photo → gradient fallback
            AspectRatio(
              aspectRatio: 1.0,
              child: _buildCoverImage(book, visual),
            ),
            // Info section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.newsreader(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitleForBook(book, aiCoverQuery: coverQuery),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.newsreader(
                        fontSize: 12,
                                                color: colors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.auto_stories, size: 14, color: colors.accent),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateRange(book),
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colors.textMuted,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
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

  /// 3-tier cover: user-uploaded → stock photo → gradient fallback.
  Widget _buildCoverImage(Book book, ChapterVisual visual) {
    final imageUrl = book.coverImageUrl ?? visual.stockImageUrl;
    if (imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildGradientCover(visual),
        errorWidget: (_, __, ___) => _buildGradientCover(visual),
      );
    }
    return _buildGradientCover(visual);
  }

  Widget _buildGradientCover(ChapterVisual visual) {
    return Container(
      decoration: BoxDecoration(gradient: visual.gradient),
      child: Center(
        child: Icon(
          visual.icon,
          color: Colors.white.withAlpha(180),
          size: 40,
        ),
      ),
    );
  }

  Widget _buildCreateChapterButton(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GestureDetector(
        onTap: () => _showCreateChapterDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.accent.withAlpha(50),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle, color: colors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Create Custom Chapter',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContent(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context)),
        SliverToBoxAdapter(child: _buildAiInsightCard(context, 0)),
        SliverToBoxAdapter(child: _buildSectionTitle(context)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.68,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, __) => _buildSkeletonCard(context),
              childCount: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonCard(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.accent.withAlpha(13)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(color: colors.border.withAlpha(80)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 100, height: 14),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 70, height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Default sample chapters shown to first-time users.
  static const _sampleChapters = [
    _SampleChapter('Family Life', 'The bonds that shape us'),
    _SampleChapter('Travel & Adventures', 'Exploring the unknown'),
    _SampleChapter('Career & Growth', 'Building a legacy'),
    _SampleChapter('Personal Wellness', 'Becoming your best self'),
    _SampleChapter('Love & Relationships', 'Hearts that hold us'),
  ];

  Widget _buildSampleChapterCard(BuildContext context, _SampleChapter sample) {
    final colors = AppColors.of(context);
    final visual = ChapterVisual.forTitle(sample.title);

    return Opacity(
      opacity: 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.accent.withAlpha(13)),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(15),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image from stock photos
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (visual.stockImageUrl != null)
                    CachedNetworkImage(
                      imageUrl: visual.stockImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildGradientCover(visual),
                      errorWidget: (_, __, ___) => _buildGradientCover(visual),
                    )
                  else
                    _buildGradientCover(visual),
                  // SAMPLE badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SAMPLE',
                        style: GoogleFonts.manrope(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sample.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.newsreader(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sample.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.newsreader(
                        fontSize: 12,
                                                color: colors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.auto_stories, size: 14, color: colors.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Start recording',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ],
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

  Future<void> _showCreateChapterDialog(BuildContext context) async {
    final colors = AppColors.of(context);
    final titleController = TextEditingController();
    File? selectedImage;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textMuted.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'New Chapter',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              // Cover image picker
              GestureDetector(
                onTap: () async {
                  final source = await showModalBottomSheet<ImageSource>(
                    context: ctx,
                    backgroundColor: colors.card,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (c) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(Icons.camera_alt,
                                color: colors.accent),
                            title: Text('Camera',
                                style: GoogleFonts.manrope(
                                    color: colors.textPrimary)),
                            onTap: () =>
                                Navigator.pop(c, ImageSource.camera),
                          ),
                          ListTile(
                            leading: Icon(Icons.photo_library,
                                color: colors.accent),
                            title: Text('Gallery',
                                style: GoogleFonts.manrope(
                                    color: colors.textPrimary)),
                            onTap: () =>
                                Navigator.pop(c, ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (source == null) return;
                  final picked = await ImagePicker().pickImage(
                    source: source,
                    maxWidth: 800,
                    maxHeight: 800,
                    imageQuality: 85,
                  );
                  if (picked != null) {
                    setSheetState(() => selectedImage = File(picked.path));
                  }
                },
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.accentFaint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.accent.withAlpha(40)),
                    image: selectedImage != null
                        ? DecorationImage(
                            image: FileImage(selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: colors.accent, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Add cover photo (optional)',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              // Title input
              TextField(
                controller: titleController,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Chapter title (e.g. My Travels)',
                  hintStyle: GoogleFonts.manrope(
                    fontSize: 16,
                    color: colors.textMuted,
                  ),
                  filled: true,
                  fillColor: colors.bg,
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
              // Create button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    Navigator.pop(ctx, {
                      'title': title,
                      'image': selectedImage,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.bg,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Create Chapter',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    final title = result['title'] as String;
    final image = result['image'] as File?;
    final now = DateTime.now();
    final repo = ref.read(bookRepositoryProvider);

    final book = await repo.createBook(Book(
      id: '',
      userId: '',
      title: title,
      startDate: now,
      createdAt: now,
      updatedAt: now,
    ));

    // Upload user photo if provided, then update book
    if (image != null) {
      try {
        final url = await repo.uploadCoverImage(book.id, image);
        await repo.updateBook(book.copyWith(coverImageUrl: url));
      } catch (_) {
        // Upload failed — book still created, falls back to stock/gradient
      }
    }

    ref.invalidate(booksProvider);
  }

  String _subtitleForBook(Book book, {String? aiCoverQuery}) {
    // Use AI-generated evocative phrase when available
    if (aiCoverQuery != null && aiCoverQuery.isNotEmpty) return aiCoverQuery;
    final lower = book.title.toLowerCase();
    if (lower.contains('family')) return 'The bonds that shape us';
    if (lower.contains('travel') || lower.contains('adventure')) return 'Exploring the unknown';
    if (lower.contains('career') || lower.contains('work')) return 'Building a legacy';
    if (lower.contains('growth') || lower.contains('self')) return 'Becoming your best self';
    if (lower.contains('love') || lower.contains('romance')) return 'Stories of the heart';
    if (lower.contains('friend')) return 'Shared moments & laughter';
    return _formatDateRange(book);
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
}

class _SampleChapter {
  final String title;
  final String subtitle;
  const _SampleChapter(this.title, this.subtitle);
}
