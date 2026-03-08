import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/ai_badge.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';
import 'package:deardays/features/checkin/data/models/chat_message.dart';
import 'package:deardays/features/checkin/data/models/conversation_section.dart';
import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';

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
    _MoodOption(
        'Tough', Icons.sentiment_very_dissatisfied, AppColors.moodTough),
  ];

  static const _promptSuggestions = [
    'What made me smile today',
    'Something I learned',
    'A challenge I faced',
    'I\'m grateful for...',
    'How I\'m really feeling',
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

    ref.listen(checkInProvider, (prev, next) {
      if (prev != null &&
          next.sections.isNotEmpty &&
          (prev.allMessages.length != next.allMessages.length)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(state),
      body: Column(
        children: [
          Expanded(
            child: state.currentMood == null && state.isFirstCheckInToday
                ? _buildMoodSelection()
                : _buildChatView(state),
          ),
          if (state.currentMood != null || !state.isFirstCheckInToday)
            _buildInputBar(state),
        ],
      ),
    );
  }

  // -- App Bar ----------------------------------------------------------

  PreferredSizeWidget _buildAppBar(CheckInState state) {
    final sessionCount = state.sections.length;

    return DearDaysHeader.appBar(
      context: context,
      title: 'Check-in',
      actions: [
        if (state.currentMood != null && state.currentMood != 'skipped')
          GestureDetector(
            onTap: () => _showMoodPicker(),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _moodColor(state.currentMood!).withAlpha(31),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _moodIcon(state.currentMood!),
                    size: 16,
                    color: _moodColor(state.currentMood!),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    state.currentMood!,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _moodColor(state.currentMood!),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // -- Mood Selection ---------------------------------------------------

  Widget _buildMoodSelection() {
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
                color: AppColors.of(context).textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap to share your mood',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppColors.of(context).textSecondary,
              ),
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
                            colors: [
                              mood.color.withAlpha(60),
                              mood.color.withAlpha(25),
                            ],
                          ),
                          border: Border.all(color: mood.color.withAlpha(80), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: mood.color.withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
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
              onTap: () =>
                  ref.read(checkInProvider.notifier).selectMood('skipped'),
              child: Text(
                'Skip for now',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.of(context).textMuted,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.of(context).textMuted.withAlpha(102),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Chat View --------------------------------------------------------

  Widget _buildChatView(CheckInState state) {
    final hasMessages = state.allMessages.isNotEmpty;

    return hasMessages
        ? ListView.builder(
            controller: _scrollController,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: state.sections.length,
            itemBuilder: (context, sectionIndex) {
              final section = state.sections[sectionIndex];
              return _buildSection(section, sectionIndex);
            },
          )
        : _buildPromptSuggestions();
  }

  Widget _buildPromptSuggestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not sure what to write?',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try one of these prompts to get started',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
                    borderRadius: BorderRadius.circular(12),
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
        ],
      ),
    );
  }

  Widget _buildSection(ConversationSection section, int sectionIndex) {
    final timeStr = DateFormat('h:mm a').format(section.startTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionIndex > 0) const SizedBox(height: 20),
        Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.of(context).accent.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: AppColors.of(context).textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.of(context).textMuted,
                  ),
                ),
                if (section.mood != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    _moodIcon(section.mood!),
                    size: 12,
                    color: _moodColor(section.mood!),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    section.mood!,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _moodColor(section.mood!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...section.messages
            .map((msg) => _buildMessageBubble(msg, section.id)),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message, String sectionId) {
    final isUser = message.isUser;
    final timeStr = DateFormat('h:mm a').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.of(context).accent.withAlpha(38),
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
            child: GestureDetector(
              onLongPress: isUser
                  ? () => _startEditing(sectionId, message)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? AppColors.of(context).accent : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: isUser
                      ? null
                      : Border.all(
                          color: AppColors.of(context).accent.withAlpha(26),
                        ),
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
                            isUser ? Colors.white : AppColors.of(context).textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isUser) ...[
                          const AiBadge.compact(),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          timeStr,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: isUser
                                ? Colors.white.withAlpha(153)
                                : AppColors.of(context).textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // -- Input Bar --------------------------------------------------------

  Widget _buildInputBar(CheckInState state) {
    final isEditing = _editingMessageId != null;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.of(context).accent.withAlpha(26)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
                    child: Icon(Icons.close,
                        size: 16, color: AppColors.of(context).textMuted),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _handleVoiceRecord(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.of(context).accent.withAlpha(26),
                  ),
                  child: Icon(
                    Icons.mic,
                    size: 18,
                    color: AppColors.of(context).accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    color: AppColors.of(context).textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: isEditing
                        ? 'Edit your message...'
                        : 'Type a message...',
                    hintStyle: GoogleFonts.manrope(
                      fontSize: 15,
                      color: AppColors.of(context).textMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8),
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          size: 16,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -- Actions ----------------------------------------------------------

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
                color: AppColors.of(context).textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _moods.map((mood) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(checkInProvider.notifier)
                        .redoMood(mood.label);
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
                        child:
                            Icon(mood.icon, size: 26, color: mood.color),
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
            SizedBox(
                height: MediaQuery.of(context).padding.bottom + 12),
          ],
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
        return AppColors.of(context).textSecondary;
    }
  }
}

class _MoodOption {
  final String label;
  final IconData icon;
  final Color color;

  const _MoodOption(this.label, this.icon, this.color);
}
