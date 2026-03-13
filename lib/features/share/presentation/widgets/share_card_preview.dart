import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/share/data/models/share_card_config.dart';

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
        return '\u{1F31F}'; // star
      case 'good':
        return '\u{1F60A}'; // smiling
      case 'okay':
        return '\u{1F60C}'; // relieved
      case 'low':
        return '\u{1F614}'; // pensive
      case 'tough':
        return '\u{1F4AA}'; // strong
      default:
        return '\u{2728}'; // sparkles
    }
  }

  String get _dateStr => DateFormat('MMMM d, yyyy').format(entry.entryDate);

  @override
  Widget build(BuildContext context) {
    final platform = config.platform;
    return RepaintBoundary(
      key: repaintKey,
      child: SizedBox(
        width: platform.previewWidth,
        height: platform.previewHeight,
        child: _buildCard(),
      ),
    );
  }

  Widget _buildCard() {
    switch (config.style) {
      case CardStyle.minimal:
        return _MinimalCard(
          config: config,
          entry: entry,
          moodEmoji: _moodEmoji,
          dateStr: _dateStr,
        );
      case CardStyle.vibrant:
        return _VibrantCard(
          config: config,
          entry: entry,
          moodEmoji: _moodEmoji,
          dateStr: _dateStr,
        );
      case CardStyle.dark:
        return _DarkCard(
          config: config,
          entry: entry,
          moodEmoji: _moodEmoji,
          dateStr: _dateStr,
        );
      case CardStyle.nature:
        return _NatureCard(
          config: config,
          entry: entry,
          moodEmoji: _moodEmoji,
          dateStr: _dateStr,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a watermark positioned at the bottom-right corner.
Widget _watermark(Color color) {
  return Positioned(
    right: 20,
    bottom: 14,
    child: Text(
      'deardays',
      style: GoogleFonts.newsreader(
        fontSize: 11,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    ),
  );
}

/// Builds the mood emoji in the top-right corner.
Widget _moodBadge(String emoji) {
  return Positioned(
    top: 28,
    right: 28,
    child: Text(emoji, style: const TextStyle(fontSize: 26)),
  );
}

/// Returns scaled font size based on platform aspect ratio.
/// Wider cards (Twitter) get slightly smaller text; tall cards (IG) get larger.
double _bodyFontSize(SharePlatform platform) {
  switch (platform) {
    case SharePlatform.instagram:
      return 18;
    case SharePlatform.whatsapp:
      return 17;
  }
}

/// Horizontal padding scaled per platform.
double _hPadding(SharePlatform platform) {
  switch (platform) {
    case SharePlatform.instagram:
      return 36;
    case SharePlatform.whatsapp:
      return 32;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal — white background, black text, thin border
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
    final w = platform.previewWidth;
    final h = platform.previewHeight;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
      ),
      child: Stack(
        children: [
          if (config.showMood && entry.mood != null) _moodBadge(moodEmoji),

          // Photo background with overlay (if available)
          if (config.photoUrl != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xCCFAFAF9),
                    BlendMode.srcOver,
                  ),
                  child: Image.network(
                    config.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

          // Centered text
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _hPadding(platform)),
              child: Text(
                config.displayText,
                style: GoogleFonts.newsreader(
                  fontSize: _bodyFontSize(platform),
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF1A1A1A),
                  height: 1.7,
                ),
                textAlign: TextAlign.center,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Bottom: date + location
          Positioned(
            left: 28,
            right: 28,
            bottom: 36,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (config.showDate)
                  Text(
                    dateStr,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                if (config.showLocation && entry.locationName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.locationName!,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFB0B0B0),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          _watermark(const Color(0xFFD0D0D0)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vibrant — gradient background (purple-to-pink), white text
// ─────────────────────────────────────────────────────────────────────────────

class _VibrantCard extends StatelessWidget {
  final ShareCardConfig config;
  final JournalEntry entry;
  final String moodEmoji;
  final String dateStr;

  const _VibrantCard({
    required this.config,
    required this.entry,
    required this.moodEmoji,
    required this.dateStr,
  });

  List<Color> get _gradientColors {
    switch (entry.mood) {
      case 'great':
        return const [Color(0xFF7C3AED), Color(0xFFF43F5E)];
      case 'good':
        return const [Color(0xFF6366F1), Color(0xFF06B6D4)];
      case 'okay':
        return const [Color(0xFFF59E0B), Color(0xFFF43F5E)];
      case 'low':
        return const [Color(0xFFF97316), Color(0xFFFDA172)];
      case 'tough':
        return const [Color(0xFFEF4444), Color(0xFFF43F5E)];
      default:
        return const [Color(0xFF7C3AED), Color(0xFFEC4899)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = config.platform;
    final w = platform.previewWidth;
    final h = platform.previewHeight;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          if (config.showMood && entry.mood != null) _moodBadge(moodEmoji),

          // Centered text
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _hPadding(platform)),
              child: Text(
                config.displayText,
                style: GoogleFonts.newsreader(
                  fontSize: _bodyFontSize(platform) + 1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.7,
                ),
                textAlign: TextAlign.center,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Frosted date pill
          if (config.showDate)
            Positioned(
              bottom: 56,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dateStr,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(220),
                    ),
                  ),
                ),
              ),
            ),

          // Location below date
          if (config.showLocation && entry.locationName != null)
            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  entry.locationName!,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
              ),
            ),

          _watermark(Colors.white.withAlpha(100)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark — charcoal background, light text, subtle glow
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
    final w = platform.previewWidth;
    final h = platform.previewHeight;
    const bgColor = Color(0xFF1A1A1A);
    const textColor = Color(0xFFE8E8E8);
    const accentDot = Color(0xFF4B7CF3);

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Subtle radial glow in center
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    accentDot.withAlpha(18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          if (config.showMood && entry.mood != null) _moodBadge(moodEmoji),

          // Centered text
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _hPadding(platform)),
              child: Text(
                config.displayText,
                style: GoogleFonts.newsreader(
                  fontSize: _bodyFontSize(platform),
                  fontWeight: FontWeight.w400,
                  color: textColor,
                  height: 1.7,
                ),
                textAlign: TextAlign.center,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Date with accent dot
          if (config.showDate)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: accentDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),

          // Location
          if (config.showLocation && entry.locationName != null)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  entry.locationName!,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF666666),
                  ),
                ),
              ),
            ),

          _watermark(const Color(0xFF444444)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nature — soft green/earth tones, serif font
// ─────────────────────────────────────────────────────────────────────────────

class _NatureCard extends StatelessWidget {
  final ShareCardConfig config;
  final JournalEntry entry;
  final String moodEmoji;
  final String dateStr;

  const _NatureCard({
    required this.config,
    required this.entry,
    required this.moodEmoji,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    final platform = config.platform;
    final w = platform.previewWidth;
    final h = platform.previewHeight;

    const bgTop = Color(0xFFF0F5ED); // soft sage
    const bgBottom = Color(0xFFE8DFD0); // warm sand
    const textColor = Color(0xFF2C3E2C); // deep forest
    const mutedColor = Color(0xFF6B7E6B);
    const leafAccent = Color(0xFF4A7C59);

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgTop, bgBottom],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Decorative leaf-like circle, top-left
          Positioned(
            top: -20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: leafAccent.withAlpha(15),
              ),
            ),
          ),

          // Another decorative circle, bottom-right
          Positioned(
            bottom: -30,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: leafAccent.withAlpha(12),
              ),
            ),
          ),

          if (config.showMood && entry.mood != null) _moodBadge(moodEmoji),

          // Centered text in serif
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _hPadding(platform)),
              child: Text(
                config.displayText,
                style: GoogleFonts.newsreader(
                  fontSize: _bodyFontSize(platform),
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: textColor,
                  height: 1.8,
                ),
                textAlign: TextAlign.center,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Small leaf divider above date
          if (config.showDate)
            Positioned(
              bottom: 64,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '\u{1F33F}', // herb/leaf emoji
                  style: TextStyle(
                    fontSize: 14,
                    color: leafAccent.withAlpha(180),
                  ),
                ),
              ),
            ),

          // Date
          if (config.showDate)
            Positioned(
              bottom: 44,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  dateStr,
                  style: GoogleFonts.newsreader(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: mutedColor,
                  ),
                ),
              ),
            ),

          // Location
          if (config.showLocation && entry.locationName != null)
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  entry.locationName!,
                  style: GoogleFonts.newsreader(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: mutedColor.withAlpha(180),
                  ),
                ),
              ),
            ),

          _watermark(mutedColor.withAlpha(120)),
        ],
      ),
    );
  }
}
