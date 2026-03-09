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
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/checkin/data/models/chat_message.dart';
import 'package:deardays/features/checkin/data/models/conversation_section.dart';
import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
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

  // Save conversation to book
  bool _isSummarizing = false;
  final _aiService = AiService();

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

  Future<void> _saveConversationToBook() async {
    final state = ref.read(checkInProvider);
    // Collect all user messages across all sections
    final userMessages = state.allMessages
        .where((m) => m.isUser)
        .map((m) => m.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (userMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to save yet.')),
      );
      return;
    }

    setState(() => _isSummarizing = true);

    try {
      // Join user messages into a single readable text
      final rawText = userMessages.join('\n\n');
      // Light-polish to fix grammar and flow
      String cleanedText;
      try {
        cleanedText = await _aiService.lightPolish(rawText);
      } catch (_) {
        cleanedText = rawText; // Fallback to unpolished
      }

      if (!mounted) return;
      setState(() => _isSummarizing = false);

      // Navigate to Review & Save
      context.push('/review', extra: ReviewData(
        rawText: cleanedText,
        mood: state.currentMood,
        isVoice: false,
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _isSummarizing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to prepare entry. Try again.')),
        );
      }
    }
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

    final textColor = AppColors.of(context).textPrimary;
    final todayEntryAsync = ref.watch(todayEntryProvider);
    final todayJournalEntry = todayEntryAsync.valueOrNull;
    final profile = ref.watch(profileProvider).valueOrNull;
    final firstName = profile?.displayName?.split(' ').first ?? '';
    final streakAsync = ref.watch(streakProvider);
    final streak = streakAsync.valueOrNull;

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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "Good evening, Rahul" — subtle greeting
                        Row(
                          children: [
                            Text(
                              '$greeting${firstName.isNotEmpty ? ', $firstName' : ''}',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.of(context).textSecondary,
                              ),
                            ),
                            if (streak != null && streak.currentStreak > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.of(context).accentFaint,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🔥', style: TextStyle(fontSize: 10)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${streak.currentStreak}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.of(context).accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Top-right icons: notification bell + settings gear
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TopIconButton(
                        icon: Icons.notifications_outlined,
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _TopIconButton(
                        icon: Icons.settings_outlined,
                        onTap: () => context.push('/settings'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // -- Hero Headline ------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Text(
                'What happened\ntoday?',
                style: GoogleFonts.manrope(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // -- Daily Spark --------------------------------------------------
            _buildDailySparkCard(),

            // -- Today's Journal Entry (from Supabase) ------------------------
            if (todayEntryAsync.isLoading)
              _buildJournalEntrySkeleton()
            else if (todayJournalEntry != null)
              _buildJournalEntryCard(todayJournalEntry),

            // -- One card per check-in section today --------------------------
            ...state.sections.map((section) => _buildSectionCard(section)),

            // -- Record CTA (always visible) ----------------------------------
            _buildRecordCTA(),

            // -- Recent Memories ----------------------------------------------
            _buildRecentMemories(),
          ],
        ),
      ),
    );
  }

  // -- Daily Spark Card -------------------------------------------------------

  static const List<String> _sparkPrompts = [
    '"What made you smile today?"',
    '"What\'s one thing you\'re proud of?"',
    '"Who made your day better?"',
    '"What surprised you today?"',
    '"What will you remember about today?"',
  ];

  Widget _buildDailySparkCard() {
    final colors = AppColors.of(context);
    final today = DateTime.now();
    final promptIndex = today.day % _sparkPrompts.length;
    final prompt = _sparkPrompts[promptIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: colors.accentFaint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY SPARK',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    prompt,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.auto_awesome_rounded,
              size: 32,
              color: colors.accent.withAlpha(50),
            ),
          ],
        ),
      ),
    );
  }

  // -- Record CTA (mic button) ----------------------------------------------

  Widget _buildRecordCTA() {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            // Outer glow ring
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withAlpha(15),
              ),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.push('/record');
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent,
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent.withAlpha(80),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mic_rounded, size: 34, color: Colors.white),
                        const SizedBox(height: 2),
                        Text(
                          'RECORD',
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to start your evening reflection',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            // Write instead pill
            GestureDetector(
              onTap: () => context.push('/write'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: colors.accentFaint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note_rounded, size: 15, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Write instead',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
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

  // -- One card per check-in section ----------------------------------------

  Widget _buildSectionCard(ConversationSection section) {
    final colors = AppColors.of(context);
    final moodLabel = section.mood ?? '';
    final moodColor = moodLabel.isNotEmpty ? _moodColorForLabel(moodLabel) : colors.accent;
    final timeStr = DateFormat('h:mm a').format(section.startTime);
    // Green accent for check-in conversations
    const accentBar = Color(0xFF2D8F5E);

    // Last user message preview
    final lastUserMsg = section.messages.lastWhere((m) => m.isUser, orElse: () => section.messages.isNotEmpty ? section.messages.last : ChatMessage(id: '', text: '', isUser: false, timestamp: section.startTime));
    final preview = lastUserMsg.text;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: _PressableCard(
        onTap: () => setState(() => _showChat = true),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12, offset: const Offset(0, 2)),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20, top: -20,
                child: Icon(Icons.chat_bubble_rounded, size: 80, color: accentBar.withAlpha(15)),
              ),
              Positioned(
                left: -10, bottom: -10,
                child: Icon(Icons.chat_bubble_outline_rounded, size: 60, color: accentBar.withAlpha(12)),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar — green for check-in
                  Container(width: 4, color: accentBar),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentBar.withAlpha(20),
                              border: Border.all(color: accentBar.withAlpha(60), width: 1.5),
                            ),
                            child: Icon(Icons.chat_bubble_rounded, size: 20, color: accentBar),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(
                                    "Today's Check-in",
                                    style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary),
                                  ),
                                  if (moodLabel.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    _pill(
                                      child: Text(moodLabel, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: moodColor)),
                                      color: moodColor.withAlpha(26),
                                    ),
                                  ],
                                ]),
                                const SizedBox(height: 4),
                                Text(
                                  preview.isNotEmpty ? preview : timeStr,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(fontSize: 13, color: colors.textSecondary, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 22, color: accentBar.withAlpha(150)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Journal Entry Card (saved entries from Supabase) --------------------

  Widget _buildJournalEntryCard(JournalEntry entry) {
    final colors = AppColors.of(context);
    final isPolished = entry.isAiPolished && entry.polishedContent != null;
    final displayText = entry.polishedContent ?? entry.content;
    final moodColor = entry.mood != null ? _moodColorForLabel(entry.mood!) : colors.accent;
    final IconData entryIcon = entry.hasVoice
        ? Icons.mic_rounded
        : isPolished
            ? Icons.auto_fix_high_rounded
            : Icons.edit_note_rounded;

    // Build badge list
    final badges = <Widget>[];
    if (isPolished) {
      badges.add(_pill(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_fix_high, size: 10, color: colors.accent),
          const SizedBox(width: 3),
          Text('AI', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: colors.accent)),
        ]),
        color: colors.accent.withAlpha(26),
      ));
    }
    if (entry.mood != null) {
      badges.add(_pill(
        child: Text(entry.mood!, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: moodColor)),
        color: moodColor.withAlpha(26),
      ));
    }

    // Blue accent for journal entries
    const accentBar = Color(0xFF3B82F6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: _PressableCard(
        onTap: () => setState(() => _showChat = true),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12, offset: const Offset(0, 2)),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20, top: -20,
                child: Icon(Icons.edit_note_rounded, size: 80, color: accentBar.withAlpha(15)),
              ),
              Positioned(
                left: -10, bottom: -10,
                child: Icon(entryIcon, size: 60, color: accentBar.withAlpha(12)),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar — blue for journal entries
                  Container(width: 4, color: accentBar),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentBar.withAlpha(20),
                              border: Border.all(color: accentBar.withAlpha(60), width: 1.5),
                            ),
                            child: Icon(entryIcon, size: 20, color: accentBar),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(
                                    "Today's Entry",
                                    style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary),
                                  ),
                                  for (final b in badges) ...[const SizedBox(width: 6), b],
                                ]),
                                const SizedBox(height: 4),
                                Text(
                                  displayText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(fontSize: 13, color: colors.textSecondary, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 22, color: accentBar.withAlpha(150)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({required Widget child, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: child,
    );
  }

  // -- Skeleton loaders -----------------------------------------------------

  Widget _buildJournalEntrySkeleton() {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 80, height: 11),
                    const SizedBox(height: 10),
                    SkeletonBox(width: double.infinity, height: 13),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 200, height: 13),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnThisDaySkeleton() {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SkeletonBox(width: 100, height: 11),
                        const Spacer(),
                        SkeletonBox(width: 60, height: 22, borderRadius: 11),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SkeletonBox(width: double.infinity, height: 13),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 160, height: 13),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Recent Memories -------------------------------------------------------

  Widget _buildRecentMemories() {
    final colors = AppColors.of(context);
    final entriesAsync = ref.watch(timelineEntriesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Memories',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/timeline'),
                child: Text(
                  'View All',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Entries list
          if (entriesAsync.isLoading)
            _buildMemorySkeleton()
          else if (entriesAsync.valueOrNull == null || entriesAsync.valueOrNull!.isEmpty)
            _buildNoMemoriesYet(colors)
          else ...[
            for (int i = 0; i < entriesAsync.value!.take(5).length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: i == 0
                    ? _buildMemoryHeroCard(entriesAsync.value![i], colors)
                    : _buildMemoryRowCard(entriesAsync.value![i], colors),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemoryHeroCard(JournalEntry entry, AppPalette colors) {
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final dateLabel = _dateLabel(entry.entryDate);

    return _PressableCard(
      onTap: () => setState(() => _showChat = true),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image banner / gradient banner
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.accent,
                    colors.accentLight,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Decorative icon overlay
                  Positioned(
                    right: -16,
                    bottom: -16,
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 100,
                      color: Colors.white.withAlpha(20),
                    ),
                  ),
                  // Date chip
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        dateLabel.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // Voice/AI badge
                  if (entry.hasVoice || entry.isAiPolished)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(220),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              entry.hasVoice ? Icons.mic_rounded : Icons.auto_fix_high,
                              size: 11,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              entry.hasVoice ? 'Voice' : 'AI',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    excerpt,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: colors.textSecondary,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.mood != null) ...[
                    const SizedBox(height: 10),
                    _pill(
                      child: Text(
                        entry.mood!,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _moodColorForLabel(entry.mood!),
                        ),
                      ),
                      color: _moodColorForLabel(entry.mood!).withAlpha(26),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryRowCard(JournalEntry entry, AppPalette colors) {
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final dateLabel = _dateLabel(entry.entryDate);

    return _PressableCard(
      onTap: () => setState(() => _showChat = true),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            // Left thumbnail
            Container(
              width: 72,
              height: 72,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.accent.withAlpha(40),
                    colors.accentLight.withAlpha(60),
                  ],
                ),
              ),
              child: Icon(
                entry.hasVoice ? Icons.mic_rounded : Icons.edit_note_rounded,
                size: 28,
                color: colors.accent,
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(width: 6),
                        Text(
                          dateLabel,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      excerpt,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.mood != null) ...[
                      const SizedBox(height: 6),
                      _pill(
                        child: Text(
                          entry.mood!,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _moodColorForLabel(entry.mood!),
                          ),
                        ),
                        color: _moodColorForLabel(entry.mood!).withAlpha(26),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMemoriesYet(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.accentFaint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_stories_outlined, size: 40, color: colors.accent.withAlpha(100)),
          const SizedBox(height: 12),
          Text(
            'Your memories will appear here',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap Record to capture your first moment.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemorySkeleton() {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: colors.border,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 96,
          decoration: BoxDecoration(
            color: colors.border,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ],
    );
  }

  String _extractTitle(JournalEntry entry) {
    if (entry.polishedContent != null && entry.polishedContent!.isNotEmpty) {
      final lines = entry.polishedContent!.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isNotEmpty && lines.first.length < 80) return lines.first.trim();
    }
    final words = entry.content.split(' ');
    return words.take(6).join(' ') + (words.length > 6 ? '...' : '');
  }

  String _extractExcerpt(JournalEntry entry) {
    final text = entry.polishedContent ?? entry.content;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final body = lines.length > 1 ? lines.skip(1).join(' ') : text;
    return body.length > 100 ? '${body.substring(0, 100)}...' : body;
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(entryDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMM d').format(date);
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
    final textColor = AppColors.of(context).textPrimary;
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
                  color: AppColors.of(context).accent,
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
            // Add to Book button
            if (isToday)
              GestureDetector(
                onTap: _isSummarizing ? null : _saveConversationToBook,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isSummarizing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_stories, size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              'Add to Book',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            const SizedBox(width: 8),
            // Chat history button
            GestureDetector(
              onTap: _showChatHistory,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.of(context).accent.withAlpha(20),
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.of(context).accent,
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
                    color: AppColors.of(context).accent.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _moodIcon(state.currentMood!),
                        size: 16,
                        color: AppColors.of(context).accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        state.currentMood!,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.of(context).accent,
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
    final textColor = AppColors.of(context).textPrimary;
    final subtextColor = AppColors.of(context).textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const Spacer(),
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: AppColors.of(context).accent.withAlpha(64),
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
                      color: AppColors.of(context).accent.withAlpha(38),
                    ),
                  ),
                  child: Text(
                    prompt,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.of(context).textSecondary,
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
                color: AppColors.of(context).textMuted,
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
    final bubbleBg = AppColors.of(context).card;
    final bubbleText = AppColors.of(context).textPrimary;
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
                color: AppColors.of(context).accent.withAlpha(31),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 14,
                color: AppColors.of(context).accent,
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
                      color: isUser ? AppColors.of(context).accent : bubbleBg,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      border: isUser
                          ? null
                          : Border.all(
                              color: AppColors.of(context).accent.withAlpha(20)),
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
                                      : AppColors.of(context).textMuted,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Voice',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    color: isUser
                                        ? Colors.white.withAlpha(178)
                                        : AppColors.of(context).textMuted,
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
                        color: AppColors.of(context).textMuted,
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
    final barColor = AppColors.of(context).card;
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
                  Icon(Icons.edit, size: 14, color: AppColors.of(context).accent),
                  const SizedBox(width: 6),
                  Text(
                    'Editing message',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.of(context).textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelEditing,
                    child:
                        Icon(Icons.close, size: 16, color: AppColors.of(context).textMuted),
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
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.of(context).accent.withAlpha(26)),
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
                  color: AppColors.of(context).accent.withAlpha(20),
                ),
                child: Icon(
                  Icons.mic,
                  size: 18,
                  color: AppColors.of(context).accent,
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
                color: AppColors.of(context).textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 15,
                  color: AppColors.of(context).textMuted,
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
                    ? AppColors.of(context).accent.withAlpha(76)
                    : AppColors.of(context).accent,
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
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.of(context).accent.withAlpha(26)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.of(context).accent),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Transcribing...',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.of(context).textSecondary,
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
                color: AppColors.of(context).textPrimary,
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
                          color: AppColors.of(context).accent.withAlpha(31),
                        ),
                        child:
                            Icon(mood.icon, size: 26, color: AppColors.of(context).accent),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mood.label,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.of(context).textSecondary,
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

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).card,
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
                      style: GoogleFonts.manrope(fontSize: 14, color: AppColors.of(context).textSecondary),
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

                    final textColor = AppColors.of(context).textPrimary;

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
                                color: AppColors.of(context).textMuted.withAlpha(76),
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
                              color: AppColors.of(context).textMuted,
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
                                        color: AppColors.of(context).textSecondary,
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
                                            color: AppColors.of(context).accent.withAlpha(20),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${date.day}',
                                              style: GoogleFonts.manrope(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.of(context).accent,
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
                                            color: AppColors.of(context).textMuted,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.chevron_right,
                                          size: 20,
                                          color: AppColors.of(context).textMuted,
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
              ? AppColors.of(context).accent.withAlpha(20)
              : AppColors.of(context).textMuted.withAlpha(13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.of(context).accent),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: enabled ? AppColors.of(context).accent : AppColors.of(context).textMuted,
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
        return AppColors.of(context).accent;
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

/// Small icon button for the home screen top bar.
class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.accentFaint,
          border: Border.all(color: colors.border),
        ),
        child: Icon(icon, size: 20, color: colors.textSecondary),
      ),
    );
  }
}

/// A card that scales down slightly on press for tactile feedback.
class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableCard({required this.child, required this.onTap});

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}
