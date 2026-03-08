import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/ai_badge.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/checkin/data/models/chat_message.dart';
import 'package:deardays/features/checkin/data/models/conversation_section.dart';
import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/services/ai/ai_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  String? _editingMessageId;
  String? _editingSectionId;

  // Voice recording state
  bool _isRecording = false;
  bool _isTranscribing = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  AudioRecorder? _audioRecorder;
  String? _recordingPath;

  // Whether the user tapped "Write instead" to show the chat view
  bool _showChat = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    try {
      _audioRecorder?.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkInProvider);

    // Scroll to bottom when new messages arrive (chat mode)
    ref.listen(checkInProvider, (prev, next) {
      if (_showChat &&
          prev != null &&
          next.sections.isNotEmpty &&
          (prev.allMessages.length != next.allMessages.length)) {
        _scrollToBottom();
      }
    });

    // If user is in chat mode (tapped Write instead or has messages)
    if (_showChat) {
      return _buildChatView(state);
    }

    // Dashboard mode — the default scrollable home
    return _buildDashboard(state);
  }

  // =========================================================================
  // DASHBOARD VIEW (matches mockup)
  // =========================================================================

  Widget _buildDashboard(CheckInState state) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final dateStr = DateFormat('MMMM d, yyyy').format(now).toUpperCase();
    final hasCheckInEntry = state.allMessages.isNotEmpty;
    final todayEntryAsync = ref.watch(todayEntryProvider);
    final todayJournalEntry = todayEntryAsync.valueOrNull;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Header -------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateStr,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                      // Profile avatar
                      GestureDetector(
                        onTap: _showChatHistory,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withAlpha(51),
                            border: Border.all(
                              color: AppColors.primary.withAlpha(26),
                            ),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 22,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$greeting, there',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // -- Mood Selector ------------------------------------------------
            _buildMoodSection(state),

            // -- Today's Journal Entry (from Supabase) ------------------------
            if (todayJournalEntry != null)
              _buildJournalEntryCard(todayJournalEntry),

            // -- Record CTA or Today's Check-in Entry -------------------------
            if (hasCheckInEntry)
              _buildTodayEntryCard(state)
            else if (todayJournalEntry == null)
              _buildRecordCTA(),

            // -- On This Day --------------------------------------------------
            _buildOnThisDay(),
          ],
        ),
      ),
    );
  }

  // -- Mood Section (inline card) -------------------------------------------

  Widget _buildMoodSection(CheckInState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final cardColor = isDark ? AppColors.cardDark : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling?',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(26)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _moods.map((mood) {
                final isSelected =
                    state.currentMood?.toLowerCase() == mood.label.toLowerCase();
                final moodColor = _moodColorForLabel(mood.label);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (state.currentMood == null) {
                      ref.read(checkInProvider.notifier).selectMood(mood.label);
                    } else {
                      ref.read(checkInProvider.notifier).redoMood(mood.label);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? moodColor.withAlpha(40)
                              : moodColor.withAlpha(20),
                          border: isSelected
                              ? Border.all(color: moodColor, width: 2)
                              : null,
                        ),
                        child: Icon(
                          mood.icon,
                          size: 24,
                          color: isSelected
                              ? moodColor
                              : moodColor.withAlpha(180),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mood.label,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? moodColor
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // -- Record CTA (mic button) ----------------------------------------------

  Widget _buildRecordCTA() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            // Mic button
            GestureDetector(
              onTap: () => context.push('/record'),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(102),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Record your day',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => context.push('/write'),
              child: Text(
                'Write instead',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Today's Entry Card ---------------------------------------------------

  Widget _buildTodayEntryCard(CheckInState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    final lastUserMessage = state.allMessages
        .where((m) => m.isUser)
        .toList();
    if (lastUserMessage.isEmpty) return _buildRecordCTA();

    final latestMsg = lastUserMessage.last;
    final timeStr = state.sections.isNotEmpty
        ? DateFormat('h:mm a').format(state.sections.last.startTime)
        : '';
    final moodLabel = state.currentMood ?? '';
    final moodColor = moodLabel.isNotEmpty ? _moodColorForLabel(moodLabel) : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: GestureDetector(
        onTap: () => setState(() => _showChat = true),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withAlpha(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colorful icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [moodColor.withAlpha(180), moodColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chat_bubble_rounded, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Today's Check-in",
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        if (moodLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: moodColor.withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              moodLabel,
                              style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: moodColor),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      latestMsg.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: textColor.withAlpha(178),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (timeStr.isNotEmpty) ...[
                          Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(timeStr, style: GoogleFonts.manrope(fontSize: 11, color: AppColors.textMuted)),
                        ],
                        const Spacer(),
                        Text(
                          'Tap to continue',
                          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Journal Entry Card (saved entries from Supabase) --------------------

  Widget _buildJournalEntryCard(JournalEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    final timeStr = entry.entryTime != null
        ? '${entry.entryTime!.hourOfPeriod == 0 ? 12 : entry.entryTime!.hourOfPeriod}:${entry.entryTime!.minute.toString().padLeft(2, '0')} ${entry.entryTime!.period == DayPeriod.am ? 'AM' : 'PM'}'
        : '';
    final displayText = entry.polishedContent ?? entry.content;
    final isPolished = entry.isAiPolished && entry.polishedContent != null;
    final moodColor = entry.mood != null ? _moodColorForLabel(entry.mood!) : AppColors.primary;

    // Pick a colorful icon based on entry type
    final IconData entryIcon = entry.hasVoice
        ? Icons.mic_rounded
        : isPolished
            ? Icons.auto_fix_high_rounded
            : Icons.edit_note_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: GestureDetector(
        onTap: () => setState(() => _showChat = true),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withAlpha(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colorful icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [moodColor.withAlpha(180), moodColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entryIcon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Today's Entry",
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        if (isPolished) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_fix_high, size: 10, color: AppColors.primary),
                                const SizedBox(width: 3),
                                Text('AI', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ],
                        if (entry.mood != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: moodColor.withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              entry.mood!,
                              style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: moodColor),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: textColor.withAlpha(178),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (timeStr.isNotEmpty) ...[
                          Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(timeStr, style: GoogleFonts.manrope(fontSize: 11, color: AppColors.textMuted)),
                        ],
                        if (entry.locationName != null) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.location_on, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              entry.locationName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          'Saved to Book',
                          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- On This Day ----------------------------------------------------------

  Widget _buildOnThisDay() {
    // Check if there's a conversation from ~1 year ago
    final datesAsync = ref.watch(availableDatesProvider);
    final dates = datesAsync.valueOrNull ?? [];
    final now = DateTime.now();
    final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtextColor = isDark ? Colors.white70 : AppColors.textSecondary;

    DateTime? matchDate;
    for (final d in dates) {
      if (d.year == oneYearAgo.year &&
          d.month == oneYearAgo.month &&
          d.day == oneYearAgo.day) {
        matchDate = d;
        break;
      }
    }

    // Always show the section (with placeholder if no data)
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: GestureDetector(
        onTap: () => context.push('/on-this-day'),
        child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withAlpha(51)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ON THIS DAY',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        matchDate != null ? '1 Year Ago' : '',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Placeholder image
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(51),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.auto_stories,
                          size: 24,
                          color: AppColors.primary.withAlpha(178),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          matchDate != null
                              ? '"Your memories from this day last year..."'
                              : '"Start journaling to build your On This Day memories"',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            color: subtextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Decorative history icon
            Positioned(
              right: -16,
              bottom: -16,
              child: Icon(
                Icons.history,
                size: 96,
                color: AppColors.primary.withAlpha(26),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // =========================================================================
  // CHAT VIEW (existing conversation UI)
  // =========================================================================

  Widget _buildChatView(CheckInState state) {
    final isToday = state.isViewingToday;

    return Column(
      children: [
        // Chat top bar
        _buildChatTopBar(state),
        // Messages
        Expanded(
          child: state.allMessages.isEmpty
              ? _buildEmptyState()
              : _buildConversation(state),
        ),
        // Input bar
        if (isToday && (state.currentMood != null || !state.isFirstCheckInToday))
          _buildInputBar(state),
      ],
    );
  }

  Widget _buildChatTopBar(CheckInState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final isToday = state.isViewingToday;
    final dateLabel = isToday
        ? 'Today'
        : DateFormat('EEEE, MMM d').format(state.loadedDate);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (!isToday) {
                  ref.read(checkInProvider.notifier).goBackToToday();
                }
                setState(() => _showChat = false);
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.arrow_back_ios,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                dateLabel,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            // Chat history button
            GestureDetector(
              onTap: _showChatHistory,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(20),
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Mood pill (tap to change)
            if (state.currentMood != null)
              GestureDetector(
                onTap: _showMoodPicker,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _moodIcon(state.currentMood!),
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        state.currentMood!,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
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

  // -- Conversation Area --------------------------------------------------

  Widget _buildConversation(CheckInState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.sections.length,
      itemBuilder: (context, sectionIndex) {
        final section = state.sections[sectionIndex];
        return _buildSection(section, sectionIndex);
      },
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subtextColor = isDark ? Colors.white70 : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const Spacer(),
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: AppColors.primary.withAlpha(64),
          ),
          const SizedBox(height: 16),
          Text(
            'What\'s on your mind?',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type below or try a prompt to get started',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _promptSuggestions.map((prompt) {
              return GestureDetector(
                onTap: () {
                  _textController.text = prompt;
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withAlpha(38),
                    ),
                  ),
                  child: Text(
                    prompt,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  static const _promptSuggestions = [
    'What made me smile today',
    'Something I learned',
    'A challenge I faced',
    'I\'m grateful for...',
    'How I\'m really feeling',
  ];

  Widget _buildSection(ConversationSection section, int sectionIndex) {
    final timeStr = DateFormat('h:mm a').format(section.startTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionIndex > 0) const SizedBox(height: 16),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              timeStr,
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
        ...section.messages
            .map((msg) => _buildMessageBubble(msg, section.id)),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message, String sectionId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleBg = isDark ? AppColors.cardDark : Colors.white;
    final bubbleText = isDark ? Colors.white : AppColors.textPrimary;
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withAlpha(31),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress:
                      isUser ? () => _startEditing(sectionId, message) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : bubbleBg,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      border: isUser
                          ? null
                          : Border.all(
                              color: AppColors.primary.withAlpha(20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.isVoice)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic,
                                  size: 12,
                                  color: isUser
                                      ? Colors.white.withAlpha(178)
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Voice',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    color: isUser
                                        ? Colors.white.withAlpha(178)
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          message.text,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            color:
                                isUser ? Colors.white : bubbleText,
                            height: 1.45,
                          ),
                        ),
                        if (!isUser) ...[
                          const SizedBox(height: 4),
                          const AiBadge.compact(),
                        ],
                      ],
                    ),
                  ),
                ),
                if (isUser)
                  GestureDetector(
                    onTap: () => _startEditing(sectionId, message),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // -- Input Bar ----------------------------------------------------------

  Widget _buildInputBar(CheckInState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? AppColors.cardDark : Colors.white;
    final isEditing = _editingMessageId != null;

    return Container(
      padding: const EdgeInsets.only(
        left: 14,
        right: 8,
        top: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: barColor,
        border: Border(
          top: BorderSide(color: Colors.black.withAlpha(13)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Editing message',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelEditing,
                    child:
                        Icon(Icons.close, size: 16, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          _isRecording
              ? _buildRecordingBar()
              : _isTranscribing
                  ? _buildTranscribingBar()
                  : _buildTextInputBar(state),
        ],
      ),
    );
  }

  Widget _buildTextInputBar(CheckInState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withAlpha(26)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          if (!kIsWeb)
            GestureDetector(
              onTap: () => context.push('/record'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(20),
                ),
                child: Icon(
                  Icons.mic,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (!kIsWeb) const SizedBox(width: 8),
          if (kIsWeb) const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _textController,
              style: GoogleFonts.manrope(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 15,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          GestureDetector(
            onTap: state.isLoading ? null : _handleSend,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state.isLoading
                    ? AppColors.primary.withAlpha(76)
                    : AppColors.primary,
              ),
              child: state.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward,
                      size: 18,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withAlpha(51)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatRecordingTime(),
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Recording...',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Colors.red.shade400,
              ),
            ),
          ),
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withAlpha(26),
              ),
              child: Icon(Icons.close, size: 18, color: Colors.red.shade700),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(Icons.stop, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscribingBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withAlpha(26)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Transcribing...',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // -- Voice Recording ---------------------------------------------------

  Future<void> _startRecording() async {
    if (kIsWeb) return;

    try {
      _audioRecorder ??= AudioRecorder();
      if (await _audioRecorder!.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder!.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _showChat = true; // Switch to chat view for recording UI
          _recordingPath = path;
          _recordingSeconds = 0;
        });

        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_isRecording) {
            setState(() => _recordingSeconds++);
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Microphone permission is required.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Recording not available: ${e.toString().length > 50 ? e.toString().substring(0, 50) : e}')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder?.stop();
      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });

      if (path == null) return;

      setState(() => _isTranscribing = true);
      try {
        final aiService = AiService();
        final transcription = await aiService.transcribeAudio(path);
        if (transcription.isNotEmpty && mounted) {
          _textController.text = transcription;
        }
      } catch (_) {
        if (mounted) {
          ref.read(checkInProvider.notifier).sendMessage(
                'Voice entry (${_formatRecordingTime()})',
                isVoice: true,
              );
        }
      } finally {
        if (mounted) setState(() => _isTranscribing = false);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
      });
    }
  }

  void _cancelRecording() {
    _recordingTimer?.cancel();
    _audioRecorder?.stop();
    setState(() {
      _isRecording = false;
      _recordingPath = null;
      _recordingSeconds = 0;
    });
  }

  String _formatRecordingTime() {
    final m = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // -- Actions ----------------------------------------------------------

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final state = ref.read(checkInProvider);

    if (state.sections.isEmpty ||
        (state.activeSection?.messages.isEmpty ?? true)) {
      if (state.sections.isEmpty) {
        ref.read(checkInProvider.notifier).startReturnConversation();
      }
    }

    if (_editingMessageId != null && _editingSectionId != null) {
      ref.read(checkInProvider.notifier).editMessage(
            _editingSectionId!,
            _editingMessageId!,
            text,
          );
      _cancelEditing();
    } else {
      ref.read(checkInProvider.notifier).sendMessage(text);
    }

    _textController.clear();
  }

  void _startEditing(String sectionId, ChatMessage message) {
    setState(() {
      _editingMessageId = message.id;
      _editingSectionId = sectionId;
      _textController.text = message.text;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _editingSectionId = null;
      _textController.clear();
    });
  }

  void _showMoodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Change your mood',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _moods.map((mood) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(checkInProvider.notifier).redoMood(mood.label);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withAlpha(31),
                        ),
                        child:
                            Icon(mood.icon, size: 26, color: AppColors.primary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mood.label,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 12),
          ],
        ),
      ),
    );
  }

  // -- Chat History -----------------------------------------------------

  void _showChatHistory() {
    // Invalidate to force a fresh read from Hive
    ref.invalidate(availableDatesProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (ctx, watchRef, _) {
            final datesAsync = watchRef.watch(availableDatesProvider);
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final yesterday = today.subtract(const Duration(days: 1));

            return DraggableScrollableSheet(
              initialChildSize: 0.55,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, scrollController) {
                return datesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                    child: Text(
                      'Failed to load conversations',
                      style: GoogleFonts.manrope(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                  data: (dates) {
                    final thisWeekDates = dates.where((d) {
                      final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
                      return diff >= 0 && diff < 7;
                    }).toList();
                    final thisMonthDates = dates.where((d) {
                      return d.year == now.year && d.month == now.month;
                    }).toList();

                    final textColor = isDark ? Colors.white : AppColors.textPrimary;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.textMuted.withAlpha(76),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chat History',
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _historyChip(
                                'Today',
                                onTap: () {
                                  Navigator.pop(ctx);
                                  ref.read(checkInProvider.notifier).goBackToToday();
                                  setState(() => _showChat = true);
                                },
                              ),
                              if (dates.any((d) =>
                                  d.year == yesterday.year &&
                                  d.month == yesterday.month &&
                                  d.day == yesterday.day))
                                _historyChip(
                                  'Yesterday',
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    ref
                                        .read(checkInProvider.notifier)
                                        .loadDataForDate(yesterday);
                                    setState(() => _showChat = true);
                                  },
                                ),
                              _historyChip(
                                'This Week (${thisWeekDates.length})',
                                enabled: thisWeekDates.length > 1,
                              ),
                              _historyChip(
                                'This Month (${thisMonthDates.length})',
                                enabled: thisMonthDates.length > 1,
                              ),
                              _historyChip(
                                'Pick Date',
                                icon: Icons.calendar_month,
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: now,
                                    firstDate: DateTime(2020),
                                    lastDate: now,
                                  );
                                  if (picked != null) {
                                    ref
                                        .read(checkInProvider.notifier)
                                        .loadDataForDate(picked);
                                    setState(() => _showChat = true);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'ALL CONVERSATIONS',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: dates.isEmpty
                                ? Center(
                                    child: Text(
                                      'No conversations yet',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    itemCount: dates.length,
                                    itemBuilder: (_, index) {
                                      final date = dates[index];
                                      final isToday = date.year == today.year &&
                                          date.month == today.month &&
                                          date.day == today.day;
                                      final isYesterday =
                                          date.year == yesterday.year &&
                                              date.month == yesterday.month &&
                                              date.day == yesterday.day;

                                      String label;
                                      if (isToday) {
                                        label = 'Today';
                                      } else if (isYesterday) {
                                        label = 'Yesterday';
                                      } else {
                                        label = DateFormat('EEEE, MMM d, yyyy')
                                            .format(date);
                                      }

                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withAlpha(20),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${date.day}',
                                              style: GoogleFonts.manrope(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          label,
                                          style: GoogleFonts.manrope(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: textColor,
                                          ),
                                        ),
                                        subtitle: Text(
                                          DateFormat('MMMM yyyy').format(date),
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.chevron_right,
                                          size: 20,
                                          color: AppColors.textMuted,
                                        ),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          if (isToday) {
                                            ref
                                                .read(checkInProvider.notifier)
                                                .goBackToToday();
                                          } else {
                                            ref
                                                .read(checkInProvider.notifier)
                                                .loadDataForDate(date);
                                          }
                                          setState(() => _showChat = true);
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _historyChip(
    String label, {
    IconData? icon,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withAlpha(20)
              : AppColors.textMuted.withAlpha(13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: enabled ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Mood helpers -----------------------------------------------------

  Color _moodColorForLabel(String label) {
    switch (label.toLowerCase()) {
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
        return AppColors.primary;
    }
  }

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

  static const List<_MoodOption> _moods = [
    _MoodOption('Great', Icons.sentiment_very_satisfied),
    _MoodOption('Good', Icons.sentiment_satisfied),
    _MoodOption('Okay', Icons.sentiment_neutral),
    _MoodOption('Low', Icons.sentiment_dissatisfied),
    _MoodOption('Tough', Icons.sentiment_very_dissatisfied),
  ];
}

class _MoodOption {
  final String label;
  final IconData icon;

  const _MoodOption(this.label, this.icon);
}
