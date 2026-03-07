import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/checkin/data/models/chat_message.dart';
import 'package:deardays/features/checkin/data/models/conversation_section.dart';
import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';
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

    // Scroll to bottom when new messages arrive
    ref.listen(checkInProvider, (prev, next) {
      if (prev != null &&
          next.sections.isNotEmpty &&
          (prev.allMessages.length != next.allMessages.length)) {
        _scrollToBottom();
      }
    });

    final isToday = state.isViewingToday;

    return Column(
      children: [
        // Top bar
        _buildTopBar(state),
        // Main content
        Expanded(
          child: isToday && state.currentMood == null && state.isFirstCheckInToday
              ? _buildMoodSelection()
              : _buildConversation(state),
        ),
        // Input bar (only for today)
        if (isToday && (state.currentMood != null || !state.isFirstCheckInToday))
          _buildInputBar(state),
      ],
    );
  }

  // -- Top Bar ----------------------------------------------------------

  Widget _buildTopBar(CheckInState state) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    // Show date label if viewing a past date
    final isToday = state.isViewingToday;
    final dateLabel = isToday
        ? greeting
        : DateFormat('EEEE, MMM d').format(state.loadedDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          if (!isToday)
            GestureDetector(
              onTap: () => ref.read(checkInProvider.notifier).goBackToToday(),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.arrow_back_ios,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ),
          Expanded(
            child: Text(
              dateLabel,
              style: GoogleFonts.playfairDisplay(
                fontSize: isToday ? 22 : 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
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
                  color: _moodColor(state.currentMood!).withAlpha(26),
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
                      style: GoogleFonts.inter(
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
      ),
    );
  }

  // -- Mood Selection (first visit of the day) --------------------------

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
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap to share your mood',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _moods.map((mood) {
                return GestureDetector(
                  onTap: () =>
                      ref.read(checkInProvider.notifier).selectMood(mood.label),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mood.color.withAlpha(31),
                        ),
                        child: Icon(mood.icon, size: 30, color: mood.color),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mood.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
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
                  ref.read(checkInProvider.notifier).selectMood('Okay'),
              child: Text(
                'Skip for now',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textMuted.withAlpha(102),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Conversation Area ------------------------------------------------

  Widget _buildConversation(CheckInState state) {
    final hasMessages = state.allMessages.isNotEmpty;

    if (!hasMessages) {
      return _buildEmptyState();
    }

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
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type below or try a prompt to get started',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
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
                    style: GoogleFonts.inter(
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

  Widget _buildSection(ConversationSection section, int sectionIndex) {
    final timeStr = DateFormat('h:mm a').format(section.startTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionIndex > 0) const SizedBox(height: 16),
        // Time divider
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              timeStr,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
        // Messages
        ...section.messages
            .map((msg) => _buildMessageBubble(msg, section.id)),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message, String sectionId) {
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
                      color: isUser ? AppColors.primary : Colors.white,
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
                                  style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color:
                                isUser ? Colors.white : AppColors.textPrimary,
                            height: 1.45,
                          ),
                        ),
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

  // -- Input Bar --------------------------------------------------------

  Widget _buildInputBar(CheckInState state) {
    final isEditing = _editingMessageId != null;

    return Container(
      padding: const EdgeInsets.only(
        left: 14,
        right: 8,
        top: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.primary,
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

  // -- Input bar variants ------------------------------------------------

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
          // Mic button (hidden on web)
          if (!kIsWeb)
            GestureDetector(
              onTap: _startRecording,
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
          // Text input
          Expanded(
            child: TextField(
              controller: _textController,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: GoogleFonts.inter(
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
          // Send button
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
          // Red pulsing dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 10),
          // Timer
          Text(
            _formatRecordingTime(),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(width: 12),
          // Waveform hint
          Expanded(
            child: Text(
              'Recording...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.red.shade400,
              ),
            ),
          ),
          // Cancel button
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
          // Stop button
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
            style: GoogleFonts.inter(
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

      // Try to transcribe
      setState(() => _isTranscribing = true);
      try {
        final aiService = AiService();
        final transcription = await aiService.transcribeAudio(path);
        if (transcription.isNotEmpty && mounted) {
          _textController.text = transcription;
        }
      } catch (_) {
        // Transcription failed — send as voice entry
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

    // If no active section yet (e.g. user skipped mood or it's a return visit),
    // start a conversation section first
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
              style: GoogleFonts.inter(
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
                          color: mood.color.withAlpha(31),
                        ),
                        child:
                            Icon(mood.icon, size: 26, color: mood.color),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mood.label,
                        style: GoogleFonts.inter(
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
    final datesAsync = ref.read(availableDatesProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final dates = datesAsync.valueOrNull ?? [];
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));

        // Group dates into quick filters
        final thisWeekDates = dates.where((d) {
          final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
          return diff >= 0 && diff < 7;
        }).toList();
        final thisMonthDates = dates.where((d) {
          return d.year == now.year && d.month == now.month;
        }).toList();

        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
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
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quick filters
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _historyChip(
                        'Today',
                        onTap: () {
                          Navigator.pop(ctx);
                          ref.read(checkInProvider.notifier).goBackToToday();
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
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ALL CONVERSATIONS',
                    style: GoogleFonts.inter(
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
                              style: GoogleFonts.inter(
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
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${date.day}',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  label,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  DateFormat('MMMM yyyy').format(date),
                                  style: GoogleFonts.inter(
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
              style: GoogleFonts.inter(
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
