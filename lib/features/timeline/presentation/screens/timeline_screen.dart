import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Header(),
              const SizedBox(height: 20),
              const _SearchBar(),
              const SizedBox(height: 16),
              const _FilterChips(),
              const SizedBox(height: 20),
              const _LifeStatsCard(),
              const SizedBox(height: 24),
              const _OnThisDayCard(),
              const SizedBox(height: 24),
              Text(
                'RECENT ENTRIES',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const _TimelineEntry(
                date: 'MARCH 5, 2026',
                moodEmoji: '\u{1F60A}',
                preview:
                    'The morning light filtered through the curtains, casting warm golden patterns across the wooden floor...',
                hasPhoto: true,
              ),
              const _TimelineEntry(
                date: 'MARCH 3, 2026',
                moodEmoji: '\u{1F60C}',
                preview:
                    'We wandered through the old quarter, the cobblestone streets echoing with laughter and distant music...',
                hasPhoto: false,
              ),
              const _TimelineEntry(
                date: 'FEBRUARY 28, 2026',
                moodEmoji: '\u{2764}',
                preview:
                    'There is something profoundly peaceful about sitting by the fireplace with a cup of chamomile tea...',
                hasPhoto: true,
              ),
              const _TimelineEntry(
                date: 'FEBRUARY 25, 2026',
                moodEmoji: '\u{1F31F}',
                preview:
                    'Today marked a milestone I had been working toward for months. The feeling of accomplishment was...',
                hasPhoto: false,
              ),
              const _TimelineEntry(
                date: 'FEBRUARY 20, 2026',
                moodEmoji: '\u{1F343}',
                preview:
                    'A quiet afternoon in the garden, watching the butterflies dance between the lavender and rosemary...',
                hasPhoto: true,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 28),
        Text(
          'DearDays',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2D2D2D),
          ),
        ),
        Stack(
          children: [
            const Icon(Icons.notifications_none_rounded,
                color: Color(0xFF2D2D2D), size: 26),
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey.shade400, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Search keywords, dates, or moods',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'Keyword',
          icon: Icons.keyboard_arrow_down,
          iconAfter: true,
        ),
        const SizedBox(width: 10),
        _FilterChip(
          label: 'Date',
          icon: Icons.calendar_today_outlined,
        ),
        const SizedBox(width: 10),
        _FilterChip(
          label: 'Mood',
          icon: Icons.emoji_emotions_outlined,
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool iconAfter;

  const _FilterChip({
    required this.label,
    required this.icon,
    this.iconAfter = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 16, color: const Color(0xFF5A5A5A));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!iconAfter) ...[
            iconWidget,
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF5A5A5A),
            ),
          ),
          if (iconAfter) ...[
            const SizedBox(width: 4),
            iconWidget,
          ],
        ],
      ),
    );
  }
}

class _LifeStatsCard extends StatelessWidget {
  const _LifeStatsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIFE STATS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '247 entries  |  12 chapters',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.favorite, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                'Happiest month: June',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnThisDayCard extends StatelessWidget {
  const _OnThisDayCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Icon(Icons.star_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'ON THIS DAY \u2014 2023',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFE8DDD3),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The coastal breeze...',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The waves crashed gently against the shore as the sun began its descent, painting the sky in hues of amber and rose.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final String date;
  final String moodEmoji;
  final String preview;
  final bool hasPhoto;

  const _TimelineEntry({
    required this.date,
    required this.moodEmoji,
    required this.preview,
    this.hasPhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                moodEmoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF3A3A3A),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (hasPhoto) ...[
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFE8DDD3),
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=200',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
