import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final profileAsync = ref.watch(profileProvider);
    final entriesAsync = ref.watch(timelineEntriesProvider);

    final user = Supabase.instance.client.auth.currentUser;
    final displayName = profileAsync.valueOrNull?.displayName ??
        user?.userMetadata?['display_name'] as String? ??
        user?.email?.split('@').first ??
        'there';
    final entries = entriesAsync.valueOrNull ?? [];
    final isFirstTimeUser = entries.isEmpty;

    return Scaffold(
      backgroundColor: colors.bg,
      floatingActionButton: isFirstTimeUser
          ? _buildFloatingMicButton(context, colors)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ─────────────────────────────────────────────
                    _buildHeader(context, displayName, colors),
                    const SizedBox(height: 20),

                    // ── Greeting ────────────────────────────────────────────
                    _buildGreeting(context, displayName, colors),
                    const SizedBox(height: 24),

                    // ── Daily Spark card ────────────────────────────────────
                    _buildDailySparkCard(ref, colors),
                    const SizedBox(height: 28),

                    // ── 3-button action row ─────────────────────────────────
                    _buildActionRow(context, colors),
                    const SizedBox(height: 32),

                    // ── Recent Memories header ──────────────────────────────
                    _buildSectionHeader(context, colors),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Recent Memory cards ─────────────────────────────────────────
            entriesAsync.when(
              data: (data) => data.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildEmptyState(context, colors),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            if (i == 0) return _buildHeroCard(context, data.first, colors);
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _buildCompactCard(context, data[i], colors),
                            );
                          },
                          childCount: data.length.clamp(0, 5),
                        ),
                      ),
                    ),
              loading: () => SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                      child: _buildCardSkeleton(i == 0, colors),
                    ),
                    childCount: 3,
                  ),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, String displayName, AppPalette colors) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accentFaint,
                border: Border.all(color: colors.accent.withAlpha(50)),
              ),
              clipBehavior: Clip.hardEdge,
              child: avatarUrl != null
                  ? Image.network(avatarUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(initials,
                          style: GoogleFonts.manrope(
                            fontSize: 16, fontWeight: FontWeight.w700, color: colors.accent,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(initials,
                        style: GoogleFonts.manrope(
                          fontSize: 16, fontWeight: FontWeight.w700, color: colors.accent,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),

          // App name
          Text(
            'Aura',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.accent,
              letterSpacing: -0.3,
            ),
          ),

          const Spacer(),

          // Notification bell
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.card,
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(color: colors.textPrimary.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(Icons.notifications_outlined, size: 20, color: colors.textSecondary),
          ),
          const SizedBox(width: 8),

          // Settings
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.card,
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(color: colors.textPrimary.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Icon(Icons.settings_outlined, size: 20, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Greeting
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGreeting(BuildContext context, String name, AppPalette colors) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final firstName = name.split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $firstName',
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'What happened\ntoday?',
          style: GoogleFonts.newsreader(
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Daily Spark Card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDailySparkCard(WidgetRef ref, AppPalette colors) {
    // Fallback prompts when AI is unavailable
    const fallbackPrompts = [
      '"What made you smile today?"',
      '"Who did you think about today?"',
      '"What are you grateful for?"',
      '"What challenged you today?"',
      '"Describe one moment from today."',
      '"What did you learn today?"',
      '"Who made a difference in your day?"',
    ];

    final aiPrompt = ref.watch(writingPromptProvider).valueOrNull;
    final prompt = aiPrompt != null
        ? '"$aiPrompt"'
        : fallbackPrompts[DateTime.now().day % fallbackPrompts.length];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.accent.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withAlpha(26)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAILY SPARK',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: colors.accent,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                prompt,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: colors.textPrimary,
                  height: 1.35,
                ),
              ),
            ],
          ),
          Positioned(
            right: -8,
            bottom: -12,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 64,
              color: colors.accent.withAlpha(25),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Floating mic button for first-time users
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFloatingMicButton(BuildContext context, AppPalette colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 70),
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/record');
        },
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        icon: const Icon(Icons.mic_rounded, size: 24),
        label: Text(
          'Record your first memory',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3-button action row: Speak | Write | Chat AI
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildActionRow(BuildContext context, AppPalette colors) {
    final actions = [
      (Icons.mic_rounded, 'Speak', () {
        HapticFeedback.mediumImpact();
        context.push('/record');
      }),
      (Icons.edit_note_rounded, 'Write', () {
        HapticFeedback.mediumImpact();
        context.push('/write');
      }),
      (Icons.smart_toy_outlined, 'Chat AI', () {
        HapticFeedback.mediumImpact();
        context.push('/checkin');
      }),
    ];

    return Row(
      children: actions.map((action) {
        final (icon, label, onTap) = action;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: action == actions.first ? 0 : 6,
              right: action == actions.last ? 0 : 6,
            ),
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                      boxShadow: [
                        BoxShadow(
                          color: colors.textPrimary.withAlpha(10),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 30, color: colors.accent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext context, AppPalette colors) {
    return Row(
      children: [
        Text(
          'Recent Memories',
          style: GoogleFonts.newsreader(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => context.go('/timeline'),
          child: Text(
            'View All',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hero card (first entry — full-width image on top)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeroCard(BuildContext context, JournalEntry entry, AppPalette colors) {
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final dateLabel = _dateLabel(entry.entryDate);
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();

    return GestureDetector(
      onTap: () => context.push('/memory', extra: entry),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(color: colors.textPrimary.withAlpha(12), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image banner (160px)
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: photoMedia.isNotEmpty
                      ? _NetworkImage(url: _getPhotoUrl(context, photoMedia.first.storagePath))
                      : _GradientBanner(colors: colors),
                ),
                // Date chip overlay
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.card.withAlpha(230),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dateLabel.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                // AI badge
                if (entry.isAiPolished)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_fix_high_rounded, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('AI', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Text content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    excerpt,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: colors.textSecondary,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Compact card (horizontal: 1/3 image | text + tags)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCompactCard(BuildContext context, JournalEntry entry, AppPalette colors) {
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final dateStr = DateFormat('MMM d').format(entry.entryDate);
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
    final (tagLabel, tagColor) = _tagInfo(entry);

    return GestureDetector(
      onTap: () => context.push('/memory', extra: entry),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(color: colors.textPrimary.withAlpha(8), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left image (1/3 width)
            SizedBox(
              width: 110,
              height: 110,
              child: photoMedia.isNotEmpty
                  ? _NetworkImage(url: _getPhotoUrl(context, photoMedia.first.storagePath))
                  : _GradientBanner(colors: colors),
            ),
            // Right content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: colors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      excerpt,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: colors.textSecondary,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Tags row
                    Wrap(
                      spacing: 6,
                      children: [
                        if (tagLabel != null)
                          _Tag(label: tagLabel, color: tagColor, colors: colors),
                        if (entry.mood != null)
                          _Tag(
                            label: _moodLabel(entry.mood!),
                            color: colors.accent.withAlpha(180),
                            colors: colors,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Skeleton loaders
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCardSkeleton(bool isHero, AppPalette colors) {
    if (isHero) {
      return Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: double.infinity, height: 160, borderRadius: 0),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 200, height: 14, borderRadius: 7),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 280, height: 12, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          SkeletonBox(width: 110, height: 110, borderRadius: 0),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 160, height: 12, borderRadius: 6),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 120, height: 11, borderRadius: 5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, AppPalette colors) {
    return Column(
      children: [
        // Prompt banner
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.push('/record');
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.accent.withAlpha(30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record your first memory',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Just talk for 30 seconds — we\'ll do the rest.',
                        style: GoogleFonts.manrope(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: colors.textMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // "Example" label
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'EXAMPLES',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: colors.accent,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Your memories will look like this',
              style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Sample hero card
        _buildSampleHeroCard(context, colors),
        const SizedBox(height: 12),

        // Sample compact cards
        _buildSampleCompactCard(
          context,
          colors,
          title: 'Coffee with an old friend',
          excerpt: 'Ran into Maya at the farmer\'s market. We talked for an hour about everything and nothing...',
          date: 'Yesterday',
          mood: 'good',
          tag: 'Friends',
          tagColor: AppColors.purple,
          imageUrl: 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=400&h=400&fit=crop',
        ),
        const SizedBox(height: 12),
        _buildSampleCompactCard(
          context,
          colors,
          title: 'Morning run breakthrough',
          excerpt: 'Finally hit 5K without stopping. The sunrise over the park made it even more special...',
          date: '2 days ago',
          mood: 'great',
          tag: 'Wellness',
          tagColor: AppColors.emerald,
          imageUrl: 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=400&h=400&fit=crop',
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSampleHeroCard(BuildContext context, AppPalette colors) {
    return Opacity(
      opacity: 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(color: colors.textPrimary.withAlpha(12), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo banner
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.network(
                    'https://images.unsplash.com/photo-1606791405792-1004f1718d0c?w=600&h=400&fit=crop',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF8A65), Color(0xFFFF5722)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Date chip
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.card.withAlpha(230),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'TODAY',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                // Example badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.textPrimary.withAlpha(140),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'EXAMPLE',
                      style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sunday dinner at Mom\'s',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The whole family gathered for the first time in months. Dad made his famous lasagna and we laughed until our sides hurt...',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: colors.textSecondary,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      _Tag(label: 'Family', color: AppColors.rose, colors: colors),
                      _Tag(label: 'Gratitude', color: colors.accent.withAlpha(180), colors: colors),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleCompactCard(
    BuildContext context,
    AppPalette colors, {
    required String title,
    required String excerpt,
    required String date,
    required String mood,
    required String tag,
    required Color tagColor,
    required String imageUrl,
  }) {
    return Opacity(
      opacity: 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(color: colors.textPrimary.withAlpha(8), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _GradientBanner(colors: colors),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              date,
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                color: colors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          excerpt,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: colors.textSecondary,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            _Tag(label: tag, color: tagColor, colors: colors),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Example badge
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(100),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'EXAMPLE',
                  style: GoogleFonts.manrope(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _getPhotoUrl(BuildContext context, String storagePath) {
    // Get from MediaService via Supabase storage public URL
    final supabase = Supabase.instance.client;
    return supabase.storage.from('media').getPublicUrl(storagePath);
  }

  String _extractTitle(JournalEntry entry) {
    final lines = entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Untitled Memory';
    final first = lines.first.trim();
    if (first.length < 80 && lines.length > 1) return first;
    return entry.content.length > 50 ? '${entry.content.substring(0, 50)}...' : entry.content;
  }

  String _extractExcerpt(JournalEntry entry) {
    final lines = entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    final first = lines.first.trim();
    final isTitle = first.length < 80 && lines.length > 1;
    final body = isTitle ? lines.skip(1).join(' ') : entry.content;
    return body.length > 100 ? '${body.substring(0, 100)}...' : body;
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(DateTime(date.year, date.month, date.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d').format(date);
  }

  (String?, Color) _tagInfo(JournalEntry entry) {
    final text = entry.content.toLowerCase();
    if (text.contains('travel') || text.contains('trip') || text.contains('vacation'))
      return ('Travel', AppColors.orange);
    if (text.contains('work') || text.contains('job') || text.contains('career'))
      return ('Career', AppColors.blue);
    if (text.contains('family') || text.contains('mom') || text.contains('dad') || text.contains('daughter') || text.contains('son'))
      return ('Family', AppColors.rose);
    if (text.contains('friend') || text.contains('reunion'))
      return ('Friends', AppColors.purple);
    return (null, Colors.transparent);
  }

  String _moodLabel(String mood) {
    switch (mood) {
      case 'great': return 'Gratitude';
      case 'good': return 'Social';
      case 'okay': return 'Calm';
      case 'low': return 'Personal';
      case 'tough': return 'Growth';
      default: return mood;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkImage extends StatelessWidget {
  final String url;
  const _NetworkImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _GradientBanner(colors: colors),
    );
  }
}

class _GradientBanner extends StatelessWidget {
  final AppPalette colors;
  const _GradientBanner({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accent, colors.accentLight],
        ),
      ),
      child: Center(
        child: Icon(Icons.auto_stories_rounded, size: 40, color: Colors.white.withAlpha(160)),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final AppPalette colors;
  const _Tag({required this.label, required this.color, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
