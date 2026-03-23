import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:deardays/features/journal/presentation/widgets/version_history_sheet.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';
import 'package:deardays/features/sharing/presentation/providers/sharing_provider.dart';
import 'package:deardays/features/sharing/presentation/screens/share_management_screen.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _showSwipeHint = false;
  bool _showControls = true;
  Timer? _hideTimer;

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

    if (_entries.length > 1) {
      _showSwipeHint = true;
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _showSwipeHint = false);
      });
      _resetTimer();
    }
  }

  void _resetTimer() {
    _hideTimer?.cancel();
    if (!mounted) return;
    if (!_showControls) setState(() => _showControls = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
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
          // Main paged content — tap anywhere to show controls
          GestureDetector(
            onTap: _resetTimer,
            behavior: HitTestBehavior.translucent,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _entries.length,
              onPageChanged: (i) {
                setState(() => _currentIndex = i);
                _resetTimer();
              },
              itemBuilder: (_, i) => _EntryPage(entry: _entries[i]),
            ),
          ),

          // Bottom nav bar — slides up/down + fades
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: AnimatedSlide(
              offset: _showControls ? Offset.zero : const Offset(0, 1.5),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: _BottomNavBar(
                  entries: _entries,
                  currentIndex: _currentIndex,
                  onPrev: _currentIndex > 0
                      ? () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                      : null,
                  onNext: _currentIndex < _entries.length - 1
                      ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                      : null,
                ),
              ),
            ),
          ),

          // Swipe hint overlay — fades out after ~2.5s
          AnimatedOpacity(
            opacity: _showSwipeHint ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 600),
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.textPrimary.withAlpha(180),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left_rounded, size: 20, color: colors.bg),
                      const SizedBox(width: 6),
                      Text(
                        'Swipe to navigate',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.bg,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded, size: 20, color: colors.bg),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation bar — prev title | dots/counter | next title
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final List<JournalEntry> entries;
  final int currentIndex;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _BottomNavBar({
    required this.entries,
    required this.currentIndex,
    this.onPrev,
    this.onNext,
  });

  static final _fmt = DateFormat('MMM d');

  String _shortDate(JournalEntry e) => _fmt.format(e.entryDate);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasPrev = onPrev != null;
    final hasNext = onNext != null;
    final total = entries.length;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colors.textPrimary.withAlpha(200),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Prev button + date
          GestureDetector(
            onTap: onPrev,
            child: Container(
              constraints: const BoxConstraints(minWidth: 72, maxWidth: 110),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: hasPrev ? colors.bg : colors.bg.withAlpha(60),
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      hasPrev ? _shortDate(entries[currentIndex - 1]) : '',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasPrev ? colors.bg : colors.bg.withAlpha(60),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Centre: dots (≤10) or counter (>10)
          Expanded(
            child: Center(
              child: total <= 10
                  ? SizedBox(
                      height: 16,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(total, (i) {
                          final active = i == currentIndex;
                          return TweenAnimationBuilder<double>(
                            tween: Tween(end: active ? 14.0 : 5.0),
                            duration: const Duration(milliseconds: 200),
                            builder: (_, w, __) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              width: w,
                              height: 5,
                              decoration: BoxDecoration(
                                color: active ? colors.bg : colors.bg.withAlpha(80),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        }),
                      ),
                    )
                  : Text(
                      '${currentIndex + 1} / $total',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.bg,
                      ),
                    ),
            ),
          ),

          // Next date + button
          GestureDetector(
            onTap: onNext,
            child: Container(
              constraints: const BoxConstraints(minWidth: 72, maxWidth: 110),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      hasNext ? _shortDate(entries[currentIndex + 1]) : '',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasNext ? colors.bg : colors.bg.withAlpha(60),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: hasNext ? colors.bg : colors.bg.withAlpha(60),
                  ),
                ],
              ),
            ),
          ),
        ],
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
  static const _shareBaseUrl = 'https://deardays.app/share/';
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playerReady = false;
  bool _audioError = false;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration?>? _durationSub;

  // Toggle: true = AI Story, false = My Words (polished)
  bool _showAiStory = true;

  // Multi-photo banner
  int _photoIndex = 0;
  late final PageController _photoBannerController = PageController();

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
      final url = await mediaService.getSignedUrl(voiceMedia.first.storagePath);
      await _player.setUrl(url);
      if (mounted) setState(() => _playerReady = true);

      // Duration arrives asynchronously — listen for it
      _durationSub = _player.durationStream.listen((d) {
        if (d != null && mounted) setState(() => _duration = d);
      });
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
    } catch (e, st) {
      debugPrint('[MemoryDetail] AudioPlayer init failed: $e\n$st');
      if (mounted) setState(() => _audioError = true);
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _player.dispose();
    _photoBannerController.dispose();
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
    final aiStoryGloballyEnabled = ref.watch(aiStoryEnabledProvider);
    final hasAiStory = aiStoryGloballyEnabled &&
        entry.isAiPolished &&
        (entry.polishedContent?.isNotEmpty ?? false);
    final displayText = hasAiStory && _showAiStory
        ? entry.polishedContent!
        : entry.content;
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

                      // AI Story / My Words toggle — only shown when AI story exists
                      if (hasAiStory) ...[
                        _buildContentToggle(colors),
                        const SizedBox(height: 24),
                      ],

                      // Voice player
                      if (entry.hasVoice) ...[
                        _buildVoicePlayer(colors),
                        const SizedBox(height: 28),
                      ],

                      // Body text with drop cap
                      _buildBody(displayText, colors, isAiStory: hasAiStory && _showAiStory),
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
    if (photoMedia.isEmpty) return _buildGradientBanner(colors);

    final mediaService = ref.read(mediaServiceProvider);

    Widget photoWidget(String storagePath) {
      if (storagePath.startsWith('http')) {
        return _tappablePhoto(
          child: CachedNetworkImage(
            imageUrl: storagePath,
            height: 280,
            width: double.infinity,
            fit: BoxFit.cover,
            memCacheWidth: 800,
            memCacheHeight: 560,
            errorWidget: (_, __, ___) => _buildGradientBanner(colors),
          ),
          onTap: () => _openFullscreen(context, storagePath),
        );
      }
      return FutureBuilder<String>(
        future: mediaService.getSignedUrl(storagePath),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.hasError) return _buildGradientBanner(colors);
          return _tappablePhoto(
            child: CachedNetworkImage(
              imageUrl: snapshot.data!,
              height: 280,
              width: double.infinity,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              memCacheHeight: 560,
              errorWidget: (_, __, ___) => _buildGradientBanner(colors),
            ),
            onTap: () => _openFullscreen(context, snapshot.data!),
          );
        },
      );
    }

    if (photoMedia.length == 1) {
      return photoWidget(photoMedia.first.storagePath);
    }

    // Multiple photos — swipeable PageView with dot indicators
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          PageView.builder(
            controller: _photoBannerController,
            itemCount: photoMedia.length,
            onPageChanged: (i) => setState(() => _photoIndex = i),
            itemBuilder: (_, i) => photoWidget(photoMedia[i].storagePath),
          ),
          // Dot indicators
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(photoMedia.length, (i) {
                final active = i == _photoIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withAlpha(100),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tappablePhoto({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          child,
          // Expand hint icon
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreen(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullscreenPhotoViewer(imageUrl: imageUrl),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
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
    if (_audioError) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.textMuted, size: 20),
            const SizedBox(width: 8),
            Text('Audio unavailable', style: GoogleFonts.manrope(color: colors.textMuted, fontSize: 14)),
          ],
        ),
      );
    }
    final maxMs = _duration.inMilliseconds.toDouble();
    final posMs = _position.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: play button + label + loading indicator
          Row(
            children: [
              // Play / Pause button
              GestureDetector(
                onTap: _playerReady ? _togglePlay : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _playerReady ? colors.accent : colors.border,
                    boxShadow: _playerReady
                        ? [BoxShadow(color: colors.accent.withAlpha(60), blurRadius: 10, offset: const Offset(0, 3))]
                        : [],
                  ),
                  child: _playerReady
                      ? Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26)
                      : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mic_rounded, size: 12, color: colors.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Voice Recording',
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: GoogleFonts.manrope(fontSize: 11, color: colors.accent, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          ' / ${_formatDuration(_duration)}',
                          style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Waveform / equalizer icon — animated while playing
              Icon(
                _isPlaying ? Icons.graphic_eq_rounded : Icons.equalizer_rounded,
                size: 22,
                color: _isPlaying ? colors.accent : colors.textMuted,
              ),
            ],
          ),

          // Seekable slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: colors.accent,
              inactiveTrackColor: colors.border,
              thumbColor: colors.accent,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              overlayColor: colors.accent.withAlpha(20),
            ),
            child: Slider(
              value: posMs,
              min: 0,
              max: maxMs > 0 ? maxMs : 1.0,
              onChanged: _playerReady
                  ? (v) => _player.seek(Duration(milliseconds: v.round()))
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI Story / My Words toggle
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContentToggle(AppPalette colors) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: colors.accent.withAlpha(18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleSegment(
            label: '✨ AI Story',
            active: _showAiStory,
            colors: colors,
            onTap: () => setState(() => _showAiStory = true),
          ),
          _toggleSegment(
            label: 'My Words',
            active: !_showAiStory,
            colors: colors,
            onTap: () => setState(() => _showAiStory = false),
          ),
        ],
      ),
    );
  }

  Widget _toggleSegment({
    required String label,
    required bool active,
    required AppPalette colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? colors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : colors.textMuted,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Body text with drop cap
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody(String text, AppPalette colors, {bool isAiStory = false}) {
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

        // Blockquote from last paragraph if showing AI Story
        if (isAiStory && paragraphs.length > 2) ...[
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
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.push('/edit-memory', extra: widget.entry);
          },
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withAlpha(70),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_rounded, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Edit Memory',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
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
                leading: const Icon(Icons.history_rounded),
                title: Text('Version History',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  VersionHistorySheet.show(context, widget.entry);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              // ── Private share (new) ──
              ListTile(
                leading: Icon(Icons.lock_outline_rounded, color: colors.accent),
                title: Text('Share Privately',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: colors.textPrimary)),
                subtitle: Text('Requires your approval',
                    style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted)),
                onTap: () {
                  Navigator.pop(context);
                  _sharePrivately(colors);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              // ── Who can see this ──
              ListTile(
                leading: Icon(Icons.people_outline_rounded, color: colors.textSecondary),
                title: Text('Who can see this',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ShareManagementScreen(
                      memoryId: widget.entry.id,
                      memoryTitle: _extractTitle(widget.entry),
                    ),
                  ));
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: Text('Delete Memory',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.error)),
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

  Future<void> _sharePrivately(AppPalette colors) async {
    final entry = widget.entry;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colors.accent),
              const SizedBox(height: 16),
              Text('Creating share link…',
                  style: GoogleFonts.manrope(fontSize: 13, color: colors.textSecondary)),
            ],
          ),
        ),
      ),
    );

    MemoryShare? share;
    try {
      share = await ref
          .read(shareActionsProvider.notifier)
          .createShare(entry.id)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Share link timed out'),
          );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not create share link. Please try again.',
            style: GoogleFonts.manrope(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (share == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not create share link', style: GoogleFonts.manrope(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final link = '$_shareBaseUrl${share.token}';
    final title = _extractTitle(entry);

    await Share.share(
      "✨ I'd like to share \"$title\" with you on DearDays.\n\nTap to view: $link",
      subject: 'A private memory from DearDays',
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

  // Returns true if the text looks like base64-encoded/encrypted data
  bool _looksEncrypted(String text) {
    final t = text.replaceAll('\n', '').trim();
    if (t.length < 16) return false;
    // Encrypted content has no spaces and only base64 characters
    return !t.contains(' ') && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(t);
  }

  String _extractTitle(JournalEntry entry) {
    // Prefer raw transcript (decrypted original), then polished narrative
    final candidates = [
      entry.rawContent,
      entry.polishedContent,
      _looksEncrypted(entry.content) ? null : entry.content,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();

    if (candidates.isEmpty) {
      // All content is encrypted — show a meaningful fallback by type
      if (entry.hasVoice) return 'Voice Memory';
      if (entry.hasPhoto) return 'Photo Memory';
      return 'Untitled Memory';
    }

    final text = candidates.first;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Untitled Memory';
    final first = lines.first.trim();
    if (first.length < 80 && lines.length > 1) return first;
    return first.length > 60 ? '${first.substring(0, 60)}...' : first;
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

// ── Fullscreen photo viewer ────────────────────────────────────────────────────

class _FullscreenPhotoViewer extends StatelessWidget {
  final String imageUrl;
  const _FullscreenPhotoViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Pinch-to-zoom photo
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white38,
                  size: 64,
                ),
              ),
            ),
          ),
          // Close button
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(140),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
