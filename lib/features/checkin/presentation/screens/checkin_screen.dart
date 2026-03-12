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

  static const _moods = [
    _MoodOption('Great', Icons.sentiment_very_satisfied, AppColors.moodGreat),
    _MoodOption('Good', Icons.sentiment_satisfied, AppColors.moodGood),
    _MoodOption('Okay', Icons.sentiment_neutral, AppColors.moodOkay),
    _MoodOption('Low', Icons.sentiment_dissatisfied, AppColors.moodLow),
    _MoodOption('Tough', Icons.sentiment_very_dissatisfied, AppColors.moodTough),
  ];

  static const _promptChips = [
    (Icons.sentiment_satisfied_rounded, 'Something that made you smile'),
    (Icons.group_rounded, 'Someone you met today'),
    (Icons.psychology_rounded, 'Something I learned'),
    (Icons.emoji_events_rounded, 'A challenge I faced'),
    (Icons.favorite_rounded, "I'm grateful for..."),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: colors.bg,
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
                color: colors.cardBg,
              ),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: colors.textPrimary),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Chat with AI',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'YOUR AI MEMORY COMPANION',
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: colors.accent,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showMoodPicker(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.more_horiz_rounded, size: 22, color: colors.textPrimary),
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

    return hasMessages
        ? ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: state.sections.length,
            itemBuilder: (context, sectionIndex) {
              return _buildSection(state.sections[sectionIndex], sectionIndex, colors);
            },
          )
        : _buildPromptSuggestions(colors);
  }

  Widget _buildPromptSuggestions(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _promptChips.map((chip) {
          return GestureDetector(
            onTap: () => _textController.text = chip.$2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: colors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(chip.$1, size: 14, color: colors.accent),
                  const SizedBox(width: 6),
                  Text(
                    chip.$2,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSection(ConversationSection section, int sectionIndex, AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionIndex > 0) const SizedBox(height: 24),
        ...section.messages.map((msg) => _buildMessageBubble(msg, section.id, colors)),
      ],
    );
  }

  // ── Message Bubble ────────────────────────────────────────────────────────

  Widget _buildMessageBubble(ChatMessage message, String sectionId, AppPalette colors) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withAlpha(25),
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 15, color: colors.accent),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble + sender label
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: isUser ? 0 : 4,
                    right: isUser ? 4 : 0,
                    bottom: 4,
                  ),
                  child: Text(
                    isUser ? 'You' : 'Aura AI',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                    ),
                  ),
                ),
                GestureDetector(
                  onLongPress: isUser ? () => _startEditing(sectionId, message) : null,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                          color: colors.textPrimary.withAlpha(isUser ? 20 : 8),
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
              ],
            ),
          ),

          // User avatar
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent,
              ),
              child: const Icon(Icons.person_rounded, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  // ── Input Bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar(CheckInState state, AppPalette colors) {
    final isEditing = _editingMessageId != null;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom > 0 ? 8 : 12),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Editing banner
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 14, color: colors.accent),
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
                    child: Icon(Icons.close, size: 16, color: colors.textMuted),
                  ),
                ],
              ),
            ),

          // Text input + send button
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: colors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: isEditing ? 'Edit your message...' : 'Type a memory...',
                            hintStyle: GoogleFonts.manrope(
                              fontSize: 14,
                              color: colors.textMuted,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.mic_rounded, size: 20, color: colors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: state.isLoading ? null : _handleSend,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: state.isLoading
                        ? colors.accent.withAlpha(80)
                        : colors.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withAlpha(60),
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

          const SizedBox(height: 10),

          // Generate Memory Journal button
          GestureDetector(
            onTap: () => _generateMemoryJournal(state),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: colors.textPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Generate Memory Journal',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
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
