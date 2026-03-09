import 'dart:async';
import 'dart:math';

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
  const MemoryDetailScreen({super.key, required this.entry});

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
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
                        style: GoogleFonts.manrope(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.25,
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
                      const SizedBox(height: 48),
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
        height: 280,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildGradientBanner(colors),
      );
    }
    return _buildGradientBanner(colors);
  }

  Widget _buildGradientBanner(AppPalette colors) {
    return Container(
      height: 280,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _TopBarButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => context.pop(),
              translucent: hasPhoto,
              colors: colors,
            ),
            const Spacer(),
            _TopBarButton(
              icon: Icons.ios_share_rounded,
              onTap: () {},
              translucent: hasPhoto,
              colors: colors,
            ),
            const SizedBox(width: 8),
            _TopBarButton(
              icon: Icons.more_horiz_rounded,
              onTap: () => _showMoreSheet(colors),
              translucent: hasPhoto,
              colors: colors,
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
        color: colors.accentFaint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          // Play / Pause button
          GestureDetector(
            onTap: _playerReady ? _togglePlay : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Waveform + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Voice Recording',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      displayTime,
                      style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Decorative waveform bars
                Row(
                  children: List.generate(24, (i) {
                    final h = (4.0 + sin(i * 0.9) * 6.0 + (i % 4 == 0 ? 4.0 : 0.0)).abs().clamp(3.0, 16.0);
                    final filled = progress > 0 && (i / 24) < progress;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: filled ? colors.accent : colors.accent.withAlpha(55),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                    minHeight: 2,
                  ),
                ),
              ],
            ),
          ),
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
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              p,
              style: GoogleFonts.merriweather(
                fontSize: 16,
                color: colors.textPrimary,
                height: 1.85,
                fontWeight: FontWeight.w300,
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
          style: GoogleFonts.merriweather(
            fontSize: 62,
            fontWeight: FontWeight.w700,
            color: colors.accent,
            height: 0.82,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            rest,
            style: GoogleFonts.merriweather(
              fontSize: 16,
              color: colors.textPrimary,
              height: 1.85,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockquote(String text, AppPalette colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.accent, width: 3)),
        color: colors.accentFaint,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Text(
        '"$text"',
        style: GoogleFonts.merriweather(
          fontSize: 15,
          fontStyle: FontStyle.italic,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: colors.accentFaint,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: colors.accent),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
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
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => HapticFeedback.mediumImpact(),
            icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
            label: Text(
              'Edit Memory',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => context.pop(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back_rounded, size: 14, color: colors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Back to Timeline',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ],
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
                onTap: () => Navigator.pop(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: Text(
                  'Delete Memory',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: Colors.red),
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
              style: GoogleFonts.manrope(color: Colors.red, fontWeight: FontWeight.w700),
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

// ─────────────────────────────────────────────────────────────────────────────
// Transparent top bar button
// ─────────────────────────────────────────────────────────────────────────────

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool translucent;
  final AppPalette colors;

  const _TopBarButton({
    required this.icon,
    required this.onTap,
    required this.translucent,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: translucent ? Colors.white.withAlpha(210) : colors.accentFaint,
          border: Border.all(
            color: translucent ? Colors.transparent : colors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: translucent ? Colors.black87 : colors.textPrimary,
        ),
      ),
    );
  }
}
