import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/entry_media.dart';

class MemoryDetailScreen extends ConsumerStatefulWidget {
  final JournalEntry entry;
  // Optional — when provided enables swipe-between-memories PageView
  final List<JournalEntry>? allEntries;
  final int? initialIndex;

  const MemoryDetailScreen({
    super.key,
    required this.entry,
    this.allEntries,
    this.initialIndex,
  });

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<JournalEntry> _entries;

  @override
  void initState() {
    super.initState();
    final all = widget.allEntries;
    if (all != null && all.isNotEmpty) {
      _entries = all;
      _currentIndex = widget.initialIndex?.clamp(0, all.length - 1) ?? 0;
    } else {
      _entries = [widget.entry];
      _currentIndex = 0;
    }
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _multiPage => _entries.length > 1;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (!_multiPage) {
      // Single entry — no PageView overhead
      return _EntryPage(entry: widget.entry);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _entries.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => _EntryPage(entry: _entries[i]),
          ),

          // Left arrow
          if (_currentIndex > 0)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: Container(
                    width: 30,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colors.textPrimary.withAlpha(30),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(8),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 24,
                      color: colors.textPrimary.withAlpha(160),
                    ),
                  ),
                ),
              ),
            ),

          // Right arrow
          if (_currentIndex < _entries.length - 1)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: Container(
                    width: 30,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colors.textPrimary.withAlpha(30),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(8),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: colors.textPrimary.withAlpha(160),
                    ),
                  ),
                ),
              ),
            ),

          // Page indicator at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: _entries.length <= 10
                ? _buildDotIndicator(colors)
                : _buildTextIndicator(colors),
          ),
        ],
      ),
    );
  }

  Widget _buildDotIndicator(AppPalette colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_entries.length, (i) {
        final isActive = i == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? colors.accent : colors.border,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildTextIndicator(AppPalette colors) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: colors.card.withAlpha(220),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          '${_currentIndex + 1} of ${_entries.length}',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single entry page — extracted so PageView can reuse it cleanly
// ─────────────────────────────────────────────────────────────────────────────

class _EntryPage extends ConsumerStatefulWidget {
  final JournalEntry entry;
  const _EntryPage({required this.entry});

  @override
  ConsumerState<_EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends ConsumerState<_EntryPage> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playerReady = false;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  void initState() {
    super.initState();
    if (widget.entry.hasVoice) {
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    try {
      final voiceMedia = widget.entry.media.where((m) => m.mediaType == 'voice').toList();
      if (voiceMedia.isEmpty) return;
      final mediaService = ref.read(mediaServiceProvider);
      final url = mediaService.getPublicUrl(voiceMedia.first.storagePath);
      await _player.setUrl(url);
      if (mounted) {
        setState(() {
          _duration = _player.duration ?? Duration.zero;
          _playerReady = true;
        });
      }
      _positionSub = _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });
      _playerStateSub = _player.playerStateStream.listen((state) {
        if (mounted) setState(() => _isPlaying = state.playing);
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          if (mounted) setState(() => _isPlaying = false);
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _shareEntry() {
    context.push('/share-card', extra: widget.entry);
  }

  Future<void> _togglePlay() async {
    HapticFeedback.lightImpact();
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final entry = widget.entry;
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
    final displayText = entry.polishedContent ?? entry.content;
    final hasPhoto = photoMedia.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          // Scrollable content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner (photo or gradient)
                _buildBanner(photoMedia, colors),

                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        _extractTitle(entry),
                        style: GoogleFonts.newsreader(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Date + location row
                      _buildMetaRow(entry, colors),
                      const SizedBox(height: 24),

                      // Voice player
                      if (entry.hasVoice) ...[
                        _buildVoicePlayer(colors),
                        const SizedBox(height: 28),
                      ],

                      // Body text with drop cap
                      _buildBody(displayText, colors),
                      const SizedBox(height: 32),

                      // Tags
                      _buildTagsRow(entry, colors),
                      const SizedBox(height: 40),

                      // Actions
                      _buildActions(colors),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Transparent top bar (always on top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(hasPhoto, colors),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Banner
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBanner(List<EntryMedia> photoMedia, AppPalette colors) {
    if (photoMedia.isNotEmpty) {
      final mediaService = ref.read(mediaServiceProvider);
      final url = mediaService.getPublicUrl(photoMedia.first.storagePath);
      return Image.network(
        url,
        height: 320,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildGradientBanner(colors),
      );
    }
    return _buildGradientBanner(colors);
  }

  Widget _buildGradientBanner(AppPalette colors) {
    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accent, colors.accentLight],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 72,
          color: Colors.white.withAlpha(180),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Top Bar (transparent overlay)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTopBar(bool hasPhoto, AppPalette colors) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Back — plain icon (no circle bg)
            GestureDetector(
              onTap: () => context.pop(),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 24,
                  color: hasPhoto ? Colors.white : colors.textPrimary,
                ),
              ),
            ),
            const Spacer(),
            // Share button — accent/10 circle
            GestureDetector(
              onTap: _shareEntry,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasPhoto ? Colors.white.withAlpha(230) : colors.accent.withAlpha(25),
                ),
                child: Icon(Icons.ios_share_rounded, size: 20, color: colors.accent),
              ),
            ),
            const SizedBox(width: 8),
            // More button — accent/10 circle
            GestureDetector(
              onTap: () => _showMoreSheet(colors),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasPhoto ? Colors.white.withAlpha(230) : colors.accent.withAlpha(25),
                ),
                child: Icon(Icons.more_horiz_rounded, size: 20, color: colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Meta row (date + location)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMetaRow(JournalEntry entry, AppPalette colors) {
    final dateStr = DateFormat('MMMM d, yyyy').format(entry.entryDate);
    return Row(
      children: [
        Icon(Icons.calendar_today_outlined, size: 13, color: colors.accent),
        const SizedBox(width: 5),
        Text(
          dateStr,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.accent,
          ),
        ),
        if (entry.locationName != null) ...[
          Text(' · ', style: GoogleFonts.manrope(fontSize: 13, color: colors.textMuted)),
          Icon(Icons.location_on_outlined, size: 13, color: colors.accent),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              entry.locationName!,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Voice Player
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildVoicePlayer(AppPalette colors) {
    final progress = (_playerReady && _duration.inMilliseconds > 0)
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final displayTime = _isPlaying
        ? _formatDuration(_position)
        : _formatDuration(_playerReady ? _duration : Duration.zero);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withAlpha(25)),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Play / Pause button — 48px circle
          GestureDetector(
            onTap: _playerReady ? _togglePlay : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent,
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withAlpha(70),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Label + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Voice Recording',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      displayTime,
                      style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar — 6px height
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Equalizer icon on right
          Icon(Icons.equalizer_rounded, size: 22, color: colors.textMuted),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Body text with drop cap
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody(String text, AppPalette colors) {
    if (text.isEmpty) return const SizedBox.shrink();

    final paragraphs = text.split('\n').where((p) => p.trim().isNotEmpty).toList();
    if (paragraphs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First paragraph with drop cap
        _buildDropCapParagraph(paragraphs.first, colors),

        // Remaining paragraphs
        ...paragraphs.skip(1).take(paragraphs.length > 3 ? paragraphs.length - 2 : paragraphs.length - 1).map((p) =>
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              p,
              style: GoogleFonts.newsreader(
                fontSize: 18,
                color: colors.textPrimary,
                height: 1.8,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),

        // Blockquote from last paragraph if AI polished
        if (widget.entry.isAiPolished && paragraphs.length > 2) ...[
          const SizedBox(height: 24),
          _buildBlockquote(paragraphs.last, colors),
        ],
      ],
    );
  }

  Widget _buildDropCapParagraph(String text, AppPalette colors) {
    if (text.isEmpty) return const SizedBox.shrink();
    final dropChar = text[0];
    final rest = text.length > 1 ? text.substring(1) : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dropChar,
          style: GoogleFonts.newsreader(
            fontSize: 68,
            fontWeight: FontWeight.w700,
            color: colors.accent,
            height: 0.82,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            rest,
            style: GoogleFonts.newsreader(
              fontSize: 18,
              color: colors.textPrimary,
              height: 1.8,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockquote(String text, AppPalette colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colors.accent.withAlpha(50), width: 4),
        ),
      ),
      child: Text(
        '"$text"',
        style: GoogleFonts.newsreader(
          fontSize: 17,
          color: colors.textSecondary,
          height: 1.7,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tags row
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTagsRow(JournalEntry entry, AppPalette colors) {
    final tags = <(String, IconData)>[];

    if (entry.mood != null) tags.add((_moodLabel(entry.mood!), Icons.favorite_rounded));
    if (entry.locationName != null) tags.add((entry.locationName!, Icons.location_on_outlined));
    if (entry.hasVoice) tags.add(('Voice', Icons.mic_rounded));
    if (entry.isAiPolished) tags.add(('AI Story', Icons.auto_fix_high_rounded));

    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        final (label, icon) = tag;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colors.accent.withAlpha(25),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: colors.accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildActions(AppPalette colors) {
    return Column(
      children: [
        // Edit Memory — full-width accent, rounded-xl
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => HapticFeedback.mediumImpact(),
            icon: const Icon(Icons.edit_rounded, size: 20, color: Colors.white),
            label: Text(
              'Edit Memory',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: colors.accent.withAlpha(70),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Back to Timeline — full-width cardBg button
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_back_rounded, size: 18, color: colors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Back to Timeline',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // More sheet
  // ─────────────────────────────────────────────────────────────────────────

  void _showMoreSheet(AppPalette colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(
                  'Share Memory',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _shareEntry();
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: Text(
                  'Delete Memory',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(colors);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(AppPalette colors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.bg,
        title: Text(
          'Delete Memory?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: colors.textPrimary),
        ),
        content: Text(
          'This memory will be permanently deleted and cannot be undone.',
          style: GoogleFonts.manrope(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.manrope(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: Text(
              'Delete',
              style: GoogleFonts.manrope(color: AppColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _extractTitle(JournalEntry entry) {
    final lines = entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Untitled Memory';
    final first = lines.first.trim();
    if (first.length < 80 && lines.length > 1) return first;
    return entry.content.length > 60 ? '${entry.content.substring(0, 60)}...' : entry.content;
  }

  String _moodLabel(String mood) {
    switch (mood) {
      case 'great': return 'Joy';
      case 'good': return 'Happy';
      case 'okay': return 'Reflective';
      case 'low': return 'Sad';
      case 'tough': return 'Resilient';
      default: return mood;
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
