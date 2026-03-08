import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/repositories/journal_repository.dart';
import 'package:deardays/services/encryption/encryption_service.dart';
import 'package:deardays/services/media/media_service.dart';

class OnThisDayScreen extends StatefulWidget {
  const OnThisDayScreen({super.key});

  @override
  State<OnThisDayScreen> createState() => _OnThisDayScreenState();
}

class _OnThisDayScreenState extends State<OnThisDayScreen> {
  late final JournalRepository _repository = JournalRepository(
    client: Supabase.instance.client,
    encryption: EncryptionService(),
  );

  late final MediaService _mediaService = MediaService(
    client: Supabase.instance.client,
  );

  List<JournalEntry>? _entries;
  bool _isLoading = true;
  String? _error;

  // Cache signed photo URLs by entry ID
  final Map<String, String> _photoUrls = {};

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await _repository.getOnThisDay();
      if (!mounted) return;

      // Pre-fetch photo URLs for entries that have photos.
      // The RPC doesn't join entry_media, so we query media separately.
      final entriesWithPhotos = entries.where((e) => e.hasPhoto).toList();
      if (entriesWithPhotos.isNotEmpty) {
        try {
          final mediaRows = await Supabase.instance.client
              .from('entry_media')
              .select()
              .inFilter('entry_id', entriesWithPhotos.map((e) => e.id).toList())
              .eq('media_type', 'photo');

          for (final row in (mediaRows as List<dynamic>)) {
            final map = row as Map<String, dynamic>;
            final entryId = map['entry_id'] as String;
            final storagePath = map['storage_path'] as String;
            if (!_photoUrls.containsKey(entryId)) {
              try {
                final url = await _mediaService.getSignedUrl(storagePath);
                _photoUrls[entryId] = url;
              } catch (_) {}
            }
          }
        } catch (_) {
          // Media fetch failed — entries still show with placeholder
        }
      }

      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Calculates "X years ago" label from an entry date.
  String _yearsAgoLabel(DateTime entryDate) {
    final now = DateTime.now();
    final years = now.year - entryDate.year;
    if (years == 1) return '1 year ago today';
    return '$years years ago today';
  }

  /// Maps mood string to a display name and icon.
  ({String label, IconData icon}) _moodDisplay(String? mood) {
    switch (mood?.toLowerCase()) {
      case 'great':
        return (label: 'Great', icon: Icons.sentiment_very_satisfied);
      case 'good':
        return (label: 'Good', icon: Icons.sentiment_satisfied);
      case 'okay':
        return (label: 'Okay', icon: Icons.sentiment_neutral);
      case 'low':
        return (label: 'Low', icon: Icons.sentiment_dissatisfied);
      case 'tough':
        return (label: 'Tough', icon: Icons.sentiment_very_dissatisfied);
      default:
        return (label: mood ?? 'Reflective', icon: Icons.filter_drama);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_entries == null || _entries!.isEmpty) {
      return _buildEmptyState();
    }

    final colors = AppColors.of(context);
    return RefreshIndicator(
      onRefresh: _loadEntries,
      color: colors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [
            const SizedBox(height: 8),
            for (int i = 0; i < _entries!.length; i++) ...[
              _buildSectionDivider(_yearsAgoLabel(_entries![i].entryDate)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMemoryCard(context, _entries![i]),
              ),
              const SizedBox(height: 32),
            ],
            _buildBottomPrompt(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // Loading state — shimmer placeholders
  // ────────────────────────────────────────────

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildShimmerDivider(),
          const SizedBox(height: 16),
          _buildShimmerCard(),
          const SizedBox(height: 32),
          _buildShimmerDivider(),
          const SizedBox(height: 16),
          _buildShimmerCard(),
        ],
      ),
    );
  }

  Widget _buildShimmerDivider() {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: colors.accent.withAlpha(26))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: 140,
            height: 14,
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(26),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: colors.accent.withAlpha(26))),
      ],
    );
  }

  Widget _buildShimmerCard() {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withAlpha(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo placeholder
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(color: colors.border),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location shimmer
                Container(
                  width: 160,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(26),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 16),
                // Text shimmer lines
                for (int i = 0; i < 4; i++) ...[
                  Container(
                    width: i == 3 ? 180 : double.infinity,
                    height: 14,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: colors.border.withAlpha(128),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Button shimmer
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.accent.withAlpha(38)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // Error state
  // ────────────────────────────────────────────

  Widget _buildErrorState() {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: colors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Couldn\u2019t load memories',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadEntries,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                'Retry',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.accent,
                side: BorderSide(color: colors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // Empty state — no memories on this date
  // ────────────────────────────────────────────

  Widget _buildEmptyState() {
    final colors = AppColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 56,
              color: colors.accent.withAlpha(153),
            ),
            const SizedBox(height: 20),
            Text(
              'No memories on this day yet',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep writing \u2014 future you will love\nlooking back.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.5,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // Header — frosted glass, back + title + calendar
  // ────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final colors = AppColors.of(context);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: colors.accent.withAlpha(26)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, size: 24),
                      color: colors.textPrimary,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'ON THIS DAY',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      onPressed: () {
                        // TODO: date picker for browsing other dates
                      },
                      icon: const Icon(Icons.calendar_month, size: 24),
                      color: colors.textPrimary,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Revisiting your favorite chapters',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // Section divider — lines on both sides
  // ────────────────────────────────────────────

  Widget _buildSectionDivider(String text) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: colors.accent.withAlpha(51),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              text.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: colors.accent.withAlpha(204),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: colors.accent.withAlpha(51),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // Memory card — photo + year badge + content
  // ────────────────────────────────────────────

  Widget _buildMemoryCard(BuildContext context, JournalEntry entry) {
    final colors = AppColors.of(context);

    final year = entry.entryDate.year.toString();
    final location = entry.locationName?.toUpperCase();
    final moodInfo = _moodDisplay(entry.mood);
    final photoUrl = _photoUrls[entry.id];

    // Truncate content for preview (first ~200 chars)
    final previewText = entry.content.length > 250
        ? '${entry.content.substring(0, 250)}\u2026'
        : entry.content;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withAlpha(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo area — 4:3 aspect, year badge overlay
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: photoUrl != null
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _photoPlaceholder(),
                      )
                    : _photoPlaceholder(),
              ),
              // Year badge — top-left
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(9999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    year,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content area
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location + mood row
                Row(
                  children: [
                    if (location != null) ...[
                      Icon(Icons.location_on, size: 16, color: colors.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: colors.accent,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (entry.mood != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent.withAlpha(26),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(moodInfo.icon, size: 14, color: colors.accent),
                            const SizedBox(width: 5),
                            Text(
                              moodInfo.label,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quote text — serif italic
                Text(
                  '\u201C$previewText\u201D',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                    color: colors.textPrimary.withAlpha(230),
                  ),
                ),
                const SizedBox(height: 16),

                // Read Full Entry button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => _showFullEntry(context, entry),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.accent.withAlpha(76)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Read Full Entry',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
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

  Widget _photoPlaceholder() {
    final colors = AppColors.of(context);
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: colors.textMuted.withAlpha(128),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // Full entry bottom sheet
  // ────────────────────────────────────────────

  void _showFullEntry(BuildContext context, JournalEntry entry) {
    final year = entry.entryDate.year.toString();
    final location = entry.locationName?.toUpperCase();
    final moodInfo = _moodDisplay(entry.mood);
    final colors = AppColors.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final sheetColors = AppColors.of(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: ListView(
              controller: controller,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sheetColors.textMuted.withAlpha(76),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Year + location + mood row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: sheetColors.accent,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        year,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (location != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.location_on, size: 14, color: sheetColors.accent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: sheetColors.accent,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (entry.mood != null) ...[
                      Icon(moodInfo.icon, size: 14, color: sheetColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        moodInfo.label,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: sheetColors.accent,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // Full entry text
                Text(
                  '\u201C${entry.content}\u201D',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    height: 1.7,
                    color: sheetColors.textPrimary,
                  ),
                ),

                // Show raw/original text if entry was AI polished
                if (entry.isAiPolished && entry.rawContent != null) ...[
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sheetColors.accent.withAlpha(26)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MY ORIGINAL WORDS',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: sheetColors.accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          entry.rawContent!,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            height: 1.6,
                            color: sheetColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Entry metadata
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: sheetColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      _formatEntryDate(entry),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: sheetColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    if (entry.wordCount > 0)
                      Text(
                        '${entry.wordCount} words',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: sheetColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatEntryDate(JournalEntry entry) {
    final date = entry.entryDate;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final timeStr = entry.entryTime != null
        ? ' at ${entry.entryTime!.hour.toString().padLeft(2, '0')}:${entry.entryTime!.minute.toString().padLeft(2, '0')}'
        : '';
    return '${months[date.month - 1]} ${date.day}, ${date.year}$timeStr';
  }

  // ────────────────────────────────────────────
  // Bottom prompt — sparkle + dashed border
  // ────────────────────────────────────────────

  Widget _buildBottomPrompt() {
    final colors = AppColors.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        decoration: BoxDecoration(
          color: colors.accent.withAlpha(13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.accent.withAlpha(102)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 36,
              color: colors.accent,
            ),
            const SizedBox(height: 10),
            Text(
              'That\u2019s all the memories for today.\nMake a new one?',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.5,
                color: colors.textPrimary.withAlpha(153),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
