import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/checkin/data/models/conversation_section.dart';
import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _checkInTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowCheckIn();
    });
  }

  void _maybeShowCheckIn() {
    if (_checkInTriggered) return;
    _checkInTriggered = true;

    final state = ref.read(checkInProvider);

    if (state.isFirstCheckInToday && state.currentMood == null) {
      context.push('/checkin');
    } else {
      ref.read(checkInProvider.notifier).startReturnConversation();
      context.push('/checkin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkInState = ref.watch(checkInProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildStreakBadge(),
          const SizedBox(height: 24),
          _buildMoodSelector(checkInState),
          const SizedBox(height: 28),
          _buildActionButtons(),
          const SizedBox(height: 28),
          _buildTodayEntry(checkInState),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // -- Header -----------------------------------------------------------

  Widget _buildHeader() {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d').format(now);
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    // Get user's first name or initial
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final name = user?.userMetadata?['display_name'] as String? ??
        user?.userMetadata?['full_name'] as String? ??
        '';
    final initial = name.isNotEmpty
        ? name[0].toUpperCase()
        : email.isNotEmpty
            ? email[0].toUpperCase()
            : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                greeting,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withAlpha(38),
            border: Border.all(
              color: AppColors.primary.withAlpha(76),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -- Streak Badge -----------------------------------------------------

  Widget _buildStreakBadge() {
    final streakAsync = ref.watch(streakProvider);

    return streakAsync.when(
      data: (streak) {
        final current = streak?.currentStreak ?? 0;
        if (current == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.moodOkay.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department,
                size: 18,
                color: AppColors.moodOkay,
              ),
              const SizedBox(width: 6),
              Text(
                '$current day streak',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.moodOkay.withAlpha(204),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // -- Mood Selector ----------------------------------------------------

  Widget _buildMoodSelector(CheckInState checkInState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'How are you feeling?',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (checkInState.currentMood != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/checkin'),
                child: Text(
                  'Talk more',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary.withAlpha(102),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_moods.length, (index) {
            final mood = _moods[index];
            final isSelected = checkInState.currentMood?.toLowerCase() ==
                mood.label.toLowerCase();

            return GestureDetector(
              onTap: () {
                if (checkInState.currentMood == null) {
                  ref.read(checkInProvider.notifier).selectMood(mood.label);
                  context.push('/checkin');
                } else if (!isSelected) {
                  ref.read(checkInProvider.notifier).redoMood(mood.label);
                  context.push('/checkin');
                } else {
                  context.push('/checkin');
                }
              },
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? mood.color
                          : AppColors.primary.withAlpha(20),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: mood.color.withAlpha(76),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      mood.icon,
                      size: 26,
                      color: isSelected
                          ? Colors.white
                          : AppColors.primary.withAlpha(153),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mood.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? mood.color
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  // -- Action Buttons (Talk + Write, equal prominence) -------------------

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Talk button
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/checkin'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(64),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic, size: 22, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Talk',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Write button
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/write'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withAlpha(76),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Write',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -- Today's Entry ----------------------------------------------------

  Widget _buildTodayEntry(CheckInState checkInState) {
    final sections = checkInState.sections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'TODAY\'S ENTRY',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
            if (sections.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${sections.length}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (sections.isEmpty)
          _buildEmptyEntryCard()
        else
          ...sections
              .asMap()
              .entries
              .map((e) => _buildConversationCard(e.value, e.key)),
      ],
    );
  }

  Widget _buildEmptyEntryCard() {
    return GestureDetector(
      onTap: () => context.push('/checkin'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withAlpha(26),
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 32,
                color: AppColors.primary.withAlpha(102),
              ),
              const SizedBox(height: 10),
              Text(
                'Start a conversation about your day',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCard(ConversationSection section, int index) {
    final timeStr = DateFormat('h:mm a').format(section.startTime);
    final userMessages =
        section.messages.where((m) => m.isUser).toList();
    final preview = userMessages.isNotEmpty
        ? userMessages.map((m) => m.text).join(' ')
        : 'Conversation started';

    return Padding(
      padding: EdgeInsets.only(bottom: index < 100 ? 10 : 0),
      child: GestureDetector(
        onTap: () => context.push('/checkin'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withAlpha(26),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (section.mood != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _moodColor(section.mood!).withAlpha(31),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _moodIcon(section.mood!),
                            size: 14,
                            color: _moodColor(section.mood!),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            section.mood!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _moodColor(section.mood!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    timeStr,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                preview,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (section.messages.length > 2) ...[
                const SizedBox(height: 6),
                Text(
                  '${section.messages.length} messages',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // -- Mood helpers -----------------------------------------------------

  IconData _moodIcon(String mood) {
    switch (mood.toLowerCase()) {
      case 'great':
        return Icons.sentiment_very_satisfied;
      case 'good':
        return Icons.sentiment_satisfied;
      case 'okay':
        return Icons.sentiment_neutral;
      case 'low':
        return Icons.sentiment_dissatisfied;
      case 'tough':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }

  Color _moodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'great':
        return AppColors.moodGreat;
      case 'good':
        return AppColors.moodGood;
      case 'okay':
        return AppColors.moodOkay;
      case 'low':
        return AppColors.moodLow;
      case 'tough':
        return AppColors.moodTough;
      default:
        return AppColors.textSecondary;
    }
  }

  static const List<_MoodOption> _moods = [
    _MoodOption('Great', Icons.sentiment_very_satisfied, AppColors.moodGreat),
    _MoodOption('Good', Icons.sentiment_satisfied, AppColors.moodGood),
    _MoodOption('Okay', Icons.sentiment_neutral, AppColors.moodOkay),
    _MoodOption('Low', Icons.sentiment_dissatisfied, AppColors.moodLow),
    _MoodOption(
        'Tough', Icons.sentiment_very_dissatisfied, AppColors.moodTough),
  ];
}

class _MoodOption {
  final String label;
  final IconData icon;
  final Color color;

  const _MoodOption(this.label, this.icon, this.color);
}
