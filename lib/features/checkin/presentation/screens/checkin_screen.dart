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
  bool _isViewingHistory = false;
  DateTime? _viewingDate;

  static const _allPrompts = [
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

  List<(IconData, String)> get _visiblePrompts {
    final rng = Random(_promptSeed);
    final shuffled = List<(IconData, String)>.from(_allPrompts)..shuffle(rng);
    return shuffled.take(5).toList();
  }

  String get _formattedDate {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  String _formatHistoryDate(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  @override
  void initState() {
    super.initState();
    // Always open fresh — history is one tap away via the 🕐 button
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(checkInProvider.notifier).startFresh();
    });
  }

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

  Widget _iconBtn(IconData icon, AppPalette colors, VoidCallback onTap, {Color? iconColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.card,
          border: Border.all(color: colors.border),
        ),
        child: Icon(icon, size: 18, color: iconColor ?? colors.textSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkInProvider);
    final colors = AppColors.of(context);

    ref.listen(checkInProvider, (prev, next) {
      if (prev != null && next.allMessages.length != prev.allMessages.length) {
        _scrollToBottom();
      }
    });

    final userMsgCount = state.allMessages.where((m) => m.isUser).length;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colors),
            if (_isViewingHistory) _buildHistoryBanner(colors),
            Expanded(
              child: state.allMessages.isNotEmpty
                  ? _buildChatView(state, colors)
                  : _buildEmptyState(colors),
            ),
            _buildInputBar(state, colors),
            if (userMsgCount >= 2 && !_isViewingHistory)
              _buildSaveLink(state, colors),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          _iconBtn(Icons.arrow_back_rounded, colors, () => Navigator.of(context).maybePop()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  _formattedDate,
                  style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
                ),
              ],
            ),
          ),
          _iconBtn(Icons.history_rounded, colors, _showHistorySheet),
          const SizedBox(width: 8),
          _iconBtn(Icons.more_horiz_rounded, colors, _showOptionsMenu),
        ],
      ),
    );
  }

  // ── History banner ────────────────────────────────────────────────────────

  Widget _buildHistoryBanner(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.accent.withAlpha(12),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 14, color: colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Viewing ${_viewingDate != null ? _formatHistoryDate(_viewingDate!) : ''}',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
          GestureDetector(
            onTap: _returnToToday,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Back to today',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(AppPalette colors) {
    final prompts = _visiblePrompts;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 14, color: colors.accent),
              const SizedBox(width: 6),
              Text(
                "What's on your mind?",
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _promptSeed++);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 12, color: colors.accent),
                      const SizedBox(width: 4),
                      Text(
                        'More',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...prompts.map((chip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _sendPrompt(chip.$2),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: colors.accent.withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(chip.$1, size: 15, color: colors.accent),
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
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: colors.textMuted),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // ── Chat view ─────────────────────────────────────────────────────────────

  Widget _buildChatView(CheckInState state, AppPalette colors) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: state.sections.length,
      itemBuilder: (_, i) => _buildSection(state, state.sections[i], i, colors),
    );
  }

  Widget _buildSection(CheckInState state, ConversationSection section, int index, AppPalette colors) {
    final isLastSection = index == state.sections.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (index > 0) ...[
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                _formatSectionTime(section.startTime),
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ...section.messages.asMap().entries.map((entry) {
          final msgIndex = entry.key;
          final msg = entry.value;
          final isLastMsg = isLastSection && msgIndex == section.messages.length - 1;
          final isStreamingThis = isLastMsg && !msg.isUser && (state.isLoading || state.isStreaming);
          return _buildMessageBubble(
            msg, section.id, colors,
            showTypingDots: isStreamingThis && state.isLoading && msg.text.isEmpty,
            showCursor: isStreamingThis && state.isStreaming && msg.text.isNotEmpty,
          );
        }),
      ],
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    String sectionId,
    AppPalette colors, {
    bool showTypingDots = false,
    bool showCursor = false,
  }) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accent, colors.accent.withAlpha(180)],
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
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
                  border: isUser ? null : Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: (isUser ? colors.accent : colors.textPrimary)
                          .withAlpha(isUser ? 30 : 8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: showTypingDots
                    ? _TypingDots(color: colors.textSecondary)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              message.text,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: isUser ? Colors.white : colors.textPrimary,
                                height: 1.5,
                              ),
                            ),
                          ),
                          if (showCursor) ...[
                            const SizedBox(width: 2),
                            _BlinkingCursor(color: colors.textMuted),
                          ],
                        ],
                      ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar(CheckInState state, AppPalette colors) {
    final isEditing = _editingMessageId != null;
    final isDisabled = _isViewingHistory;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.edit_rounded, size: 13, color: colors.accent),
                  const SizedBox(width: 5),
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
                    child: Icon(Icons.close_rounded, size: 17, color: colors.textMuted),
                  ),
                ],
              ),
            ),
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
                  child: TextField(
                    controller: _textController,
                    enabled: !isDisabled,
                    style: GoogleFonts.manrope(fontSize: 14, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: isDisabled
                          ? 'Read-only'
                          : isEditing
                              ? 'Edit your message...'
                              : 'Type something...',
                      hintStyle: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!isDisabled)
                GestureDetector(
                  onTap: _handleVoiceRecord,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.card,
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(Icons.mic_rounded, size: 19, color: colors.textMuted),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: (state.isLoading || state.isStreaming || isDisabled) ? null : _handleSend,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: (state.isLoading || state.isStreaming || isDisabled)
                          ? [colors.accent.withAlpha(70), colors.accent.withAlpha(50)]
                          : [colors.accent, colors.accent.withAlpha(200)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withAlpha(40),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    state.isLoading ? Icons.more_horiz_rounded : Icons.send_rounded,
                    size: 19,
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

  Widget _buildSaveLink(CheckInState state, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _generateMemoryJournal(state),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 13, color: colors.accent.withAlpha(180)),
            const SizedBox(width: 6),
            Text(
              'Save as memory journal',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.accent.withAlpha(180),
                decoration: TextDecoration.underline,
                decorationColor: colors.accent.withAlpha(80),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _sendPrompt(String text) {
    HapticFeedback.lightImpact();
    ref.read(checkInProvider.notifier).sendMessage(text);
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();

    if (_editingMessageId != null && _editingSectionId != null) {
      ref.read(checkInProvider.notifier).editMessage(_editingSectionId!, _editingMessageId!, text);
      _cancelEditing();
    } else {
      ref.read(checkInProvider.notifier).sendMessage(text);
    }
    _textController.clear();
  }

  void _handleVoiceRecord() => context.push('/record');

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
    context.push('/processing', extra: ReviewData(rawText: allText));
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

  void _returnToToday() {
    setState(() {
      _isViewingHistory = false;
      _viewingDate = null;
    });
    ref.read(checkInProvider.notifier).startFresh();
  }

  String _formatSectionTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${time.day}/${time.month} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  // ── History sheet ─────────────────────────────────────────────────────────

  Future<void> _showHistorySheet() async {
    final dates = await CheckInNotifier.getAvailableDates();
    if (!mounted) return;
    final colors = AppColors.of(context);
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HistorySheet(
        dates: dates,
        formatDate: _formatHistoryDate,
        colors: colors,
        onDateSelected: (date) {
          Navigator.of(context).pop();
          setState(() {
            _isViewingHistory = true;
            _viewingDate = date;
          });
          ref.read(checkInProvider.notifier).loadDataForDate(date);
          _scrollToBottom();
        },
      ),
    );
  }

  // ── Options menu ──────────────────────────────────────────────────────────

  void _showOptionsMenu() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.refresh_rounded, color: colors.textSecondary),
              title: Text(
                'Start fresh',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Clear this session (history is saved)',
                style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(checkInProvider.notifier).startFresh();
                setState(() {
                  _isViewingHistory = false;
                  _viewingDate = null;
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── History sheet widget ──────────────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  final List<DateTime> dates;
  final String Function(DateTime) formatDate;
  final AppPalette colors;
  final void Function(DateTime) onDateSelected;

  const _HistorySheet({
    required this.dates,
    required this.formatDate,
    required this.colors,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.withAlpha(80),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Chat History',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.close_rounded, size: 22, color: colors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (dates.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No previous conversations yet.',
              style: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: dates.length,
              separatorBuilder: (_, __) => Divider(color: colors.border, height: 1),
              itemBuilder: (_, i) {
                final date = dates[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  title: Text(
                    formatDate(date),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.accent.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Load',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ),
                  onTap: () => onDateSelected(date),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Typing dots ───────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final phase = ((_controller.value - delay) % 1.0 + 1.0) % 1.0;
            final opacity = (phase < 0.5 ? phase * 2 : (1.0 - phase) * 2).clamp(0.2, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Blinking cursor ───────────────────────────────────────────────────────────

class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Opacity(
        opacity: _controller.value > 0.5 ? 1.0 : 0.0,
        child: Text(
          '▌',
          style: TextStyle(fontSize: 12, color: widget.color, height: 1.5),
        ),
      ),
    );
  }
}
