import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/checkin/data/models/chat_message.dart';
import 'package:deardays/features/checkin/data/models/conversation_section.dart';
import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  String? _editingMessageId;
  String? _editingSectionId;
  int _promptSeed = 0;

  static const _allPromptChips = [
    (Icons.sentiment_satisfied_rounded, 'Something that made you smile'),
    (Icons.group_rounded, 'Someone you met today'),
    (Icons.psychology_rounded, 'Something I learned'),
    (Icons.emoji_events_rounded, 'A challenge I faced'),
    (Icons.favorite_rounded, "I'm grateful for..."),
    (Icons.wb_sunny_rounded, 'How your morning started'),
    (Icons.restaurant_rounded, 'A meal you enjoyed'),
    (Icons.music_note_rounded, 'A song stuck in your head'),
    (Icons.local_florist_rounded, 'Something beautiful you saw'),
    (Icons.lightbulb_rounded, 'An idea that excited you'),
  ];

  List<(IconData, String)> get _visiblePromptChips {
    final rng = Random(_promptSeed);
    final shuffled = List<(IconData, String)>.from(_allPromptChips)..shuffle(rng);
    return shuffled.take(5).toList();
  }

  void _refreshPrompts() {
    HapticFeedback.selectionClick();
    setState(() => _promptSeed++);
  }

  static const _moods = [
    _MoodOption('Great', Icons.sentiment_very_satisfied, AppColors.moodGreat),
    _MoodOption('Good', Icons.sentiment_satisfied, AppColors.moodGood),
    _MoodOption('Okay', Icons.sentiment_neutral, AppColors.moodOkay),
    _MoodOption('Low', Icons.sentiment_dissatisfied, AppColors.moodLow),
    _MoodOption('Tough', Icons.sentiment_very_dissatisfied, AppColors.moodTough),
  ];


  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
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
    final colors = AppColors.of(context);

    ref.listen(checkInProvider, (prev, next) {
      if (prev != null &&
          next.sections.isNotEmpty &&
          (prev.allMessages.length != next.allMessages.length)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(state, colors),
            Expanded(
              child: state.currentMood == null && state.isFirstCheckInToday
                  ? _buildMoodSelection(colors)
                  : _buildChatView(state, colors),
            ),
            if (state.currentMood != null || !state.isFirstCheckInToday)
              _buildInputBar(state, colors),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(CheckInState state, AppPalette colors) {
    final moodLabel = state.currentMood;
    final hasMood = moodLabel != null && moodLabel != 'skipped';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent.withAlpha(18),
            colors.bg,
          ],
        ),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withAlpha(15),
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: colors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          // AI avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.accent, colors.accent.withAlpha(180)],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withAlpha(40),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aura',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: state.isLoading ? Colors.orange : const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      state.isLoading ? 'Thinking...' : 'Online',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.textMuted,
                      ),
                    ),
                    if (hasMood) ...[
                      const SizedBox(width: 8),
                      Icon(_moodIcon(moodLabel), size: 14, color: _moodColor(moodLabel)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showMoodPicker(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withAlpha(15),
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.tune_rounded, size: 20, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mood Selection ────────────────────────────────────────────────────────

  Widget _buildMoodSelection(AppPalette colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How are you\nfeeling today?',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap to share your mood',
              style: GoogleFonts.manrope(fontSize: 14, color: colors.textSecondary),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _moods.map((mood) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(checkInProvider.notifier).selectMood(mood.label);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [mood.color.withAlpha(60), mood.color.withAlpha(25)],
                          ),
                          border: Border.all(color: mood.color.withAlpha(80), width: 2),
                          boxShadow: [
                            BoxShadow(color: mood.color.withAlpha(40), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Icon(mood.icon, size: 30, color: mood.color),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mood.label,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: mood.color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => ref.read(checkInProvider.notifier).selectMood('skipped'),
              child: Text(
                'Skip for now',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: colors.textMuted,
                  decoration: TextDecoration.underline,
                  decorationColor: colors.textMuted.withAlpha(102),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat View ─────────────────────────────────────────────────────────────

  Widget _buildChatView(CheckInState state, AppPalette colors) {
    final hasMessages = state.allMessages.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.bg,
            colors.accent.withAlpha(6),
          ],
        ),
      ),
      child: hasMessages
          ? ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: state.sections.length,
              itemBuilder: (context, sectionIndex) {
                return _buildSection(state.sections[sectionIndex], sectionIndex, colors);
              },
            )
          : _buildPromptSuggestions(colors),
    );
  }

  Widget _buildPromptSuggestions(AppPalette colors) {
    final prompts = _visiblePromptChips;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Welcome illustration
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accent.withAlpha(30), colors.accent.withAlpha(12)],
                ),
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 32, color: colors.accent),
            ),
            const SizedBox(height: 16),
            Text(
              'Start a conversation',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tell me about your day or pick a prompt below',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            // Refresh button
            GestureDetector(
              onTap: _refreshPrompts,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: colors.accent.withAlpha(12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 15, color: colors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'More prompts',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Prompt cards in a vertical list
            ...prompts.map((chip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _textController.text = chip.$2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: colors.textPrimary.withAlpha(6),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.accent.withAlpha(18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(chip.$1, size: 17, color: colors.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          chip.$2,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 13, color: colors.textMuted),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ConversationSection section, int sectionIndex, AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionIndex > 0) ...[
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatSectionTime(section.startTime),
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: colors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...section.messages.map((msg) => _buildMessageBubble(msg, section.id, colors)),
      ],
    );
  }

  String _formatSectionTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // ── Message Bubble ────────────────────────────────────────────────────────

  Widget _buildMessageBubble(ChatMessage message, String sectionId, AppPalette colors) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accent, colors.accent.withAlpha(180)],
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: GestureDetector(
              onLongPress: isUser ? () => _startEditing(sectionId, message) : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? colors.accent : colors.card,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  border: isUser
                      ? null
                      : Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: (isUser ? colors.accent : colors.textPrimary).withAlpha(isUser ? 30 : 8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: isUser ? Colors.white : colors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),

          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Input Bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar(CheckInState state, AppPalette colors) {
    final isEditing = _editingMessageId != null;
    final hasMessages = state.allMessages.where((m) => m.isUser).isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Generate Memory Journal — compact pill, only when there are messages
          if (hasMessages && !isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _generateMemoryJournal(state),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.accent.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 14, color: colors.accent),
                      const SizedBox(width: 6),
                      Text(
                        'Generate Memory Journal',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Editing banner
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.edit_rounded, size: 14, color: colors.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Editing message',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelEditing,
                    child: Icon(Icons.close_rounded, size: 18, color: colors.textMuted),
                  ),
                ],
              ),
            ),

          // Text input + send button
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: colors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: isEditing ? 'Edit your message...' : 'Tell me about your day...',
                            hintStyle: GoogleFonts.manrope(
                              fontSize: 14,
                              color: colors.textMuted,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.fromLTRB(18, 12, 0, 12),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 4,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                      GestureDetector(
                        onTap: _handleVoiceRecord,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 14, 12),
                          child: Icon(Icons.mic_rounded, size: 20, color: colors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: state.isLoading ? null : _handleSend,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: state.isLoading
                          ? [colors.accent.withAlpha(80), colors.accent.withAlpha(60)]
                          : [colors.accent, colors.accent.withAlpha(200)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withAlpha(50),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: state.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();

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

  void _handleVoiceRecord() {
    context.push('/record').then((_) {});
  }

  void _generateMemoryJournal(CheckInState state) {
    final allText = state.allMessages
        .where((m) => m.isUser)
        .map((m) => m.text)
        .join('\n\n');

    if (allText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share some memories first!')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    context.push('/review', extra: ReviewData(rawText: allText, polishWithAI: true));
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
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Change your mood',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _moods.map((mood) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(checkInProvider.notifier).redoMood(mood.label);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mood.color.withAlpha(31),
                        ),
                        child: Icon(mood.icon, size: 26, color: mood.color),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mood.label,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
          ],
        ),
      ),
    );
  }

  // ── Mood helpers ──────────────────────────────────────────────────────────

  IconData _moodIcon(String mood) {
    switch (mood.toLowerCase()) {
      case 'great': return Icons.sentiment_very_satisfied;
      case 'good': return Icons.sentiment_satisfied;
      case 'okay': return Icons.sentiment_neutral;
      case 'low': return Icons.sentiment_dissatisfied;
      case 'tough': return Icons.sentiment_very_dissatisfied;
      default: return Icons.sentiment_neutral;
    }
  }

  Color _moodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'great': return AppColors.moodGreat;
      case 'good': return AppColors.moodGood;
      case 'okay': return AppColors.moodOkay;
      case 'low': return AppColors.moodLow;
      case 'tough': return AppColors.moodTough;
      default: return AppColors.of(context).textSecondary;
    }
  }
}

class _MoodOption {
  final String label;
  final IconData icon;
  final Color color;

  const _MoodOption(this.label, this.icon, this.color);
}
