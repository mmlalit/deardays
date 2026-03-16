import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/share/data/models/share_card_config.dart';

/// Displays a share card preview at [config.platform.displayWidth × displayHeight]
/// on screen, while the inner RepaintBoundary renders at
/// [config.platform.renderWidth × renderHeight] (360×H logical px).
/// At pixelRatio 3.0 → 1080px output.
class ShareCardPreview extends StatelessWidget {
  final ShareCardConfig config;
  final JournalEntry entry;
  final GlobalKey repaintKey;

  const ShareCardPreview({
    super.key,
    required this.config,
    required this.entry,
    required this.repaintKey,
  });

  String get _moodEmoji {
    switch (entry.mood) {
      case 'great':
        return '🌟';
      case 'good':
        return '😊';
      case 'okay':
        return '😌';
      case 'low':
        return '😔';
      case 'tough':
        return '💪';
      default:
        return '✨';
    }
  }

  String get _dateStr => DateFormat('MMMM d, yyyy').format(entry.entryDate);

  @override
  Widget build(BuildContext context) {
    final platform = config.platform;
    return SizedBox(
      width: platform.displayWidth,
      height: platform.displayHeight,
      child: FittedBox(
        fit: BoxFit.fill,
        child: RepaintBoundary(
          key: repaintKey,
          child: SizedBox(
            width: platform.renderWidth,
            height: platform.renderHeight,
            child: _buildCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    switch (config.style) {
      case CardStyle.minimal:
        return _MinimalCard(config: config, entry: entry, moodEmoji: _moodEmoji, dateStr: _dateStr);
      case CardStyle.scrapbook:
        return _ScrapbookCard(config: config, entry: entry, moodEmoji: _moodEmoji, dateStr: _dateStr);
      case CardStyle.dark:
        return _DarkCard(config: config, entry: entry, moodEmoji: _moodEmoji, dateStr: _dateStr);
      case CardStyle.classic:
        return _ClassicCard(config: config, entry: entry, moodEmoji: _moodEmoji, dateStr: _dateStr);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _dearDaysWatermark({required Color color, double fontSize = 14}) {
  return Positioned(
    right: 22,
    bottom: 18,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '✦ ',
          style: TextStyle(fontSize: fontSize * 0.7, color: color),
        ),
        Text(
          'deardays',
          style: GoogleFonts.newsreader(
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    ),
  );
}

double _bodyFontSize(SharePlatform platform) {
  switch (platform) {
    case SharePlatform.instagram:
      return 22;
    case SharePlatform.whatsapp:
      return 20;
    case SharePlatform.memoryCard:
      return 20;
  }
}

double _hPadding(SharePlatform platform) {
  switch (platform) {
    case SharePlatform.instagram:
      return 40;
    case SharePlatform.whatsapp:
      return 36;
    case SharePlatform.memoryCard:
      return 36;
  }
}

/// Displays a photo from either a network URL or a local file path.
Widget _photoImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
  int? memCacheWidth,
}) {
  if (url.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      alignment: alignment,
      memCacheWidth: memCacheWidth,
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    );
  }
  return Image.file(File(url), fit: fit, alignment: alignment);
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal — full-bleed photo + gradient overlay; clean white text
// ─────────────────────────────────────────────────────────────────────────────

class _MinimalCard extends StatelessWidget {
  final ShareCardConfig config;
  final JournalEntry entry;
  final String moodEmoji;
  final String dateStr;

  const _MinimalCard({
    required this.config,
    required this.entry,
    required this.moodEmoji,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    final platform = config.platform;

    return Container(
      color: const Color(0xFF1A1410),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed photo background
          if (config.photoUrl != null)
            _photoImage(config.photoUrl!, memCacheWidth: 1080, alignment: config.photoAlignment)
          else
            _buildFallbackBg(),

          // Dark gradient overlay — bottom heavy
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x44000000),
                  Color(0xCC000000),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // Mood badge top-right
          if (config.showMood && entry.mood != null)
            Positioned(
              top: 28,
              right: 28,
              child: Text(moodEmoji, style: const TextStyle(fontSize: 30)),
            ),

          // Centered quote text
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _hPadding(platform)),
              child: Text(
                config.displayText,
                style: GoogleFonts.newsreader(
                  fontSize: _bodyFontSize(platform),
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.65,
                  shadows: [
                    const Shadow(
                      color: Color(0x88000000),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: platform == SharePlatform.whatsapp ? 6 : 9,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Bottom: date + location
          Positioned(
            left: 28,
            right: 56,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (config.showDate)
                  Text(
                    dateStr.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(180),
                      letterSpacing: 1.5,
                    ),
                  ),
                if (config.showLocation && entry.locationName != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.locationName!,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: Colors.white.withAlpha(140),
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // DearDays watermark
          _dearDaysWatermark(color: Colors.white.withAlpha(120)),
        ],
      ),
    );
  }

  Widget _buildFallbackBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C1810), Color(0xFF1A0E0A)],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scrapbook — warm cream paper, polaroid-style content card, rubber stamp branding
// ─────────────────────────────────────────────────────────────────────────────

class _ScrapbookCard extends StatelessWidget {
  final ShareCardConfig config;
  final JournalEntry entry;
  final String moodEmoji;
  final String dateStr;

  const _ScrapbookCard({
    required this.config,
    required this.entry,
    required this.moodEmoji,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    final platform = config.platform;
    const bgColor = Color(0xFFF2EAD8);
    const caramel = Color(0xFFC49A6C);
    const inkDark = Color(0xFF3A2E24);
    const inkMid = Color(0xFF7A6A58);

    return Container(
      color: bgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle paper texture dots (decorative)
          Positioned.fill(
            child: CustomPaint(painter: _PaperNoisePainter()),
          ),

          // Top decorative bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(height: 6, color: caramel),
          ),
          // Bottom decorative bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(height: 6, color: caramel),
          ),

          // Main content — polaroid card
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _hPadding(platform) - 10,
                vertical: 28,
              ),
              child: Transform.rotate(
                angle: -0.015, // very slight tilt
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3A2E24).withAlpha(40),
                        blurRadius: 20,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Photo strip (if available)
                      if (config.photoUrl != null)
                        SizedBox(
                          height: platform == SharePlatform.instagram ? 160 : 100,
                          child: _photoImage(config.photoUrl!, memCacheWidth: 720, alignment: config.photoAlignment),
                        ),

                      // Text content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.displayText,
                              style: GoogleFonts.newsreader(
                                fontSize: _bodyFontSize(platform) - 2,
                                fontWeight: FontWeight.w400,
                                fontStyle: FontStyle.italic,
                                color: inkDark,
                                height: 1.7,
                              ),
                              maxLines: config.photoUrl != null ? 5 : 10,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (config.showDate) ...[
                              const SizedBox(height: 14),
                              Container(height: 1, color: const Color(0xFFE0D8C8)),
                              const SizedBox(height: 10),
                              Text(
                                dateStr,
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: inkMid,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Mood emoji top-right
          if (config.showMood && entry.mood != null)
            Positioned(
              top: 20,
              right: 20,
              child: Text(moodEmoji, style: const TextStyle(fontSize: 26)),
            ),

          // Rubber stamp "deardays" — rotated, bottom-left
          Positioned(
            left: 18,
            bottom: 18,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: caramel.withAlpha(160), width: 1.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  'deardays',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: caramel.withAlpha(160),
                    letterSpacing: 2.5,
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

/// Paints subtle noise dots to simulate paper texture.
class _PaperNoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x0A3A2E24);

    // Deterministic "noise" — fixed offsets to simulate paper texture
    const dots = [
      Offset(0.12, 0.07), Offset(0.45, 0.13), Offset(0.78, 0.09),
      Offset(0.23, 0.31), Offset(0.67, 0.28), Offset(0.89, 0.35),
      Offset(0.05, 0.52), Offset(0.38, 0.48), Offset(0.72, 0.55),
      Offset(0.15, 0.71), Offset(0.50, 0.68), Offset(0.84, 0.74),
      Offset(0.30, 0.88), Offset(0.60, 0.92), Offset(0.92, 0.85),
    ];
    for (final d in dots) {
      canvas.drawCircle(Offset(d.dx * size.width, d.dy * size.height), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(_PaperNoisePainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark — near-black, gold accents, elegant serif; gold "deardays" signature
// ─────────────────────────────────────────────────────────────────────────────

class _DarkCard extends StatelessWidget {
  final ShareCardConfig config;
  final JournalEntry entry;
  final String moodEmoji;
  final String dateStr;

  const _DarkCard({
    required this.config,
    required this.entry,
    required this.moodEmoji,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    final platform = config.platform;
    const bg = Color(0xFF0D0D0D);
    const cream = Color(0xFFE8E0D5);
    const gold = Color(0xFFD4AF37);
    const mutedGray = Color(0xFF666666);

    return Container(
      color: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle background glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    gold.withAlpha(12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Photo background (dark overlay if photo exists)
          if (config.photoUrl != null)
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xD00D0D0D),
                  BlendMode.srcOver,
                ),
                child: _photoImage(config.photoUrl!, memCacheWidth: 1080, alignment: config.photoAlignment),
              ),
            ),

          // Mood emoji top-right
          if (config.showMood && entry.mood != null)
            Positioned(
              top: 28,
              right: 28,
              child: Text(moodEmoji, style: const TextStyle(fontSize: 28)),
            ),

          // Centered content
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _hPadding(platform)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gold line above
                  Container(
                    height: 1,
                    width: 60,
                    color: gold.withAlpha(160),
                  ),
                  const SizedBox(height: 22),

                  Text(
                    config.displayText,
                    style: GoogleFonts.newsreader(
                      fontSize: _bodyFontSize(platform),
                      fontWeight: FontWeight.w400,
                      color: cream,
                      height: 1.75,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: platform == SharePlatform.whatsapp ? 6 : 9,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 22),
                  // Gold line below
                  Container(
                    height: 1,
                    width: 60,
                    color: gold.withAlpha(160),
                  ),
                ],
              ),
            ),
          ),

          // Bottom: date
          Positioned(
            left: 0, right: 0,
            bottom: 40,
            child: Column(
              children: [
                if (config.showDate)
                  Text(
                    dateStr,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: mutedGray,
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (config.showLocation && entry.locationName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.locationName!,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: mutedGray.withAlpha(160),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Gold "deardays" signature bottom-right
          Positioned(
            right: 22,
            bottom: 18,
            child: Text(
              '✦ deardays',
              style: GoogleFonts.newsreader(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: gold.withAlpha(160),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Classic Card — white editorial card, photo top half, clean typography
// ─────────────────────────────────────────────────────────────────────────────

class _ClassicCard extends StatelessWidget {
  final ShareCardConfig config;
  final JournalEntry entry;
  final String moodEmoji;
  final String dateStr;

  const _ClassicCard({
    required this.config,
    required this.entry,
    required this.moodEmoji,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    final platform = config.platform;
    const bg = Color(0xFFFFFFFF);
    const inkDark = Color(0xFF1A1A1A);
    const inkMid = Color(0xFF555555);
    const inkLight = Color(0xFF999999);

    final hasPhoto = config.photoUrl != null;
    // Photo gets 40% of height; text gets 60%
    final totalH = platform.renderHeight;
    final photoH = hasPhoto ? totalH * 0.40 : 0.0;

    return Container(
      color: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo area
              if (hasPhoto)
                SizedBox(
                  height: photoH,
                  child: _photoImage(config.photoUrl!, memCacheWidth: 1080, alignment: config.photoAlignment),
                ),

              // Text content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _hPadding(platform),
                    hasPhoto ? 28 : 60,
                    _hPadding(platform),
                    60,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Opening quote mark
                      Text(
                        '"',
                        style: GoogleFonts.newsreader(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: inkLight.withAlpha(100),
                          height: 0.6,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Flexible(
                        child: Text(
                          config.displayText,
                          style: GoogleFonts.newsreader(
                            fontSize: hasPhoto
                                ? _bodyFontSize(platform) - 2
                                : _bodyFontSize(platform),
                            fontWeight: FontWeight.w400,
                            color: inkDark,
                            height: 1.7,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: hasPhoto ? 5 : 9,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Thin divider
                      Container(
                        height: 1,
                        width: 48,
                        color: const Color(0xFFE0E0E0),
                      ),

                      const SizedBox(height: 14),

                      // Date + mood row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (config.showMood && entry.mood != null) ...[
                            Text(
                              moodEmoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (config.showDate)
                            Text(
                              dateStr,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: inkMid,
                                letterSpacing: 0.5,
                              ),
                            ),
                        ],
                      ),

                      if (config.showLocation && entry.locationName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.locationName!,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: inkLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // DearDays wordmark — bottom center
          Positioned(
            left: 0, right: 0,
            bottom: 18,
            child: Center(
              child: Text(
                'deardays',
                style: GoogleFonts.newsreader(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: inkLight.withAlpha(140),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
