import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/features/checkin/data/models/chat_message.dart';
import 'package:deardays/features/checkin/data/models/conversation_section.dart';
import 'package:deardays/features/checkin/data/repositories/checkin_repository.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/services/ai/ai_stream_service.dart';
import 'package:deardays/services/ai/ai_prompts.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/core/providers/locale_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class CheckInState {
  final String? currentMood;
  final List<ConversationSection> sections;
  final bool isFirstCheckInToday;
  final bool isLoading;
  final bool isStreaming;
  final String? error;
  final DateTime loadedDate;

  CheckInState({
    this.currentMood,
    this.sections = const [],
    this.isFirstCheckInToday = true,
    this.isLoading = false,
    this.isStreaming = false,
    this.error,
    DateTime? loadedDate,
  }) : loadedDate = loadedDate ?? DateTime.now();

  bool get isViewingToday {
    final now = DateTime.now();
    return loadedDate.year == now.year &&
        loadedDate.month == now.month &&
        loadedDate.day == now.day;
  }

  CheckInState copyWith({
    String? currentMood,
    List<ConversationSection>? sections,
    bool? isFirstCheckInToday,
    bool? isLoading,
    bool? isStreaming,
    String? error,
    DateTime? loadedDate,
  }) {
    return CheckInState(
      currentMood: currentMood ?? this.currentMood,
      sections: sections ?? this.sections,
      isFirstCheckInToday: isFirstCheckInToday ?? this.isFirstCheckInToday,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error,
      loadedDate: loadedDate ?? this.loadedDate,
    );
  }

  /// The currently active conversation section (last one).
  ConversationSection? get activeSection =>
      sections.isEmpty ? null : sections.last;

  /// All messages across all sections, for display.
  List<ChatMessage> get allMessages =>
      sections.expand((s) => s.messages).toList();
}

// ---------------------------------------------------------------------------
// Return-visit greetings
// ---------------------------------------------------------------------------

const _returnGreetings = [
  "What's up?",
  'Hey, back again!',
  "How's the rest of your day going?",
  "Welcome back! What's on your mind?",
  'Hey there! Anything new?',
  'Good to see you again! How are things?',
  "Back so soon? Tell me what's happening.",
  "Hi again! What's going on?",
  "How's everything since we last talked?",
  'Hey! What have you been up to?',
];

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class CheckInNotifier extends StateNotifier<CheckInState> {
  CheckInNotifier(this._aiService, {this.language, this.repository, bool loadData = true})
      : super(CheckInState()) {
    if (loadData) _loadTodayData();
  }

  final AiService _aiService;
  final _streamService = AiStreamService();
  final String? language;
  final CheckInRepository? repository;
  static const _uuid = Uuid();
  static const _boxName = 'checkin_conversations';

  /// Opens the checkin conversations Hive box with encryption.
  static Future<Box> _openBox() async {
    try {
      final cipher = LocalStorageService.instance.cipher;
      return await Hive.openBox(_boxName, encryptionCipher: cipher);
    } catch (e) {
      // Fallback for tests where LocalStorageService isn't initialized.
      debugPrint('[CheckInNotifier] Falling back to unencrypted Hive box: $e');
      return await Hive.openBox(_boxName);
    }
  }

  static String dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String get _todayKey => dateKey(DateTime.now());

  // ── Persistence ──────────────────────────────────────────────────────

  Future<void> _loadTodayData() async {
    final box = await _openBox();
    final raw = box.get(_todayKey);

    if (raw != null) {
      // Hive hit — load locally
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      _applyData(data);
    } else {
      // Hive miss — try Supabase (e.g. fresh install / new device)
      try {
        final remote = await repository?.getConversation(_todayKey);
        if (remote != null) {
          // Write to Hive so future reads are instant
          await box.put(_todayKey, jsonEncode({
            'mood': remote['mood'],
            'sections': remote['sections'],
          }));
          _applyData({
            'mood': remote['mood'],
            'sections': remote['sections'],
          });
        }
      } catch (e) {
        // Network unavailable — stay empty, no crash
        debugPrint('[CheckInNotifier] Error: $e');
      }
    }
  }

  void _applyData(Map<String, dynamic> data) {
    final sections = (data['sections'] as List<dynamic>)
        .map((s) => ConversationSection.fromJson(s as Map<String, dynamic>))
        .toList();
    state = state.copyWith(
      currentMood: data['mood'] as String?,
      sections: sections,
      isFirstCheckInToday: false,
    );
  }

  Future<void> _persist() async {
    final box = await _openBox();
    final data = {
      'mood': state.currentMood,
      'sections': state.sections.map((s) => s.toJson()).toList(),
    };
    await box.put(_todayKey, jsonEncode(data));

    // Background sync to Supabase — don't await, don't block UI
    repository?.upsertConversation(_todayKey, data).catchError((Object e) { debugPrint('[CheckInNotifier] Cloud sync failed: $e'); });
  }

  // ── Load data for a specific date ───────────────────────────────────

  Future<void> loadDataForDate(DateTime date) async {
    final key = dateKey(date);
    final box = await _openBox();
    final raw = box.get(key);

    if (raw != null) {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final sections = (data['sections'] as List<dynamic>)
          .map((s) => ConversationSection.fromJson(s as Map<String, dynamic>))
          .toList();

      state = CheckInState(
        currentMood: data['mood'] as String?,
        sections: sections,
        isFirstCheckInToday: false,
        loadedDate: date,
      );
    } else {
      // Hive miss — try Supabase fallback
      try {
        final remote = await repository?.getConversation(key);
        if (remote != null) {
          await box.put(key, jsonEncode({
            'mood': remote['mood'],
            'sections': remote['sections'],
          }));
          final sections = (remote['sections'] as List<dynamic>)
              .map((s) => ConversationSection.fromJson(s as Map<String, dynamic>))
              .toList();
          state = CheckInState(
            currentMood: remote['mood'] as String?,
            sections: sections,
            isFirstCheckInToday: false,
            loadedDate: date,
          );
          return;
        }
      } catch (e) { debugPrint('[CheckInNotifier] Error: $e'); }

      state = CheckInState(
        isFirstCheckInToday: true,
        loadedDate: date,
      );
    }
  }

  Future<void> goBackToToday() async {
    state = CheckInState();
    await _loadTodayData();
  }

  /// Resets in-memory state to empty without touching Hive — used so the
  /// chat screen always opens fresh while history remains accessible.
  void startFresh() {
    state = CheckInState();
  }

  static Future<List<DateTime>> getAvailableDates() async {
    final box = await _openBox();
    final keys = box.keys.cast<String>().toList();
    final dates = <DateTime>[];
    for (final key in keys) {
      try {
        dates.add(DateTime.parse(key));
      } catch (e) { debugPrint('[CheckInNotifier] Error: $e'); }
    }
    dates.sort((a, b) => b.compareTo(a)); // newest first
    return dates;
  }

  // ── Mood selection ───────────────────────────────────────────────────

  Future<void> selectMood(String mood) async {
    state = state.copyWith(currentMood: mood, isLoading: true, error: null);

    // Start a new conversation section
    final section = ConversationSection(
      id: _uuid.v4(),
      startTime: DateTime.now(),
      mood: mood,
    );

    final updatedSections = [...state.sections, section];
    state = state.copyWith(sections: updatedSections);

    // Generate AI response based on mood
    try {
      final aiReply = await _getAiMoodResponse(mood);
      _addAiMessage(aiReply);
      state = state.copyWith(isLoading: false, isFirstCheckInToday: false);
      await _persist();
    } catch (e) {
      // Fallback to local response if AI fails
      final fallback = _getFallbackMoodResponse(mood);
      _addAiMessage(fallback);
      state = state.copyWith(isLoading: false, isFirstCheckInToday: false);
      await _persist();
    }
  }

  // ── Re-do mood ──────────────────────────────────────────────────────

  Future<void> redoMood(String newMood) async {
    state = state.copyWith(currentMood: newMood, isLoading: true, error: null);

    // Create a new section for the mood change
    final section = ConversationSection(
      id: _uuid.v4(),
      startTime: DateTime.now(),
      mood: newMood,
    );

    final updatedSections = [...state.sections, section];
    state = state.copyWith(sections: updatedSections);

    try {
      final aiReply = await _getAiMoodResponse(newMood);
      _addAiMessage(aiReply);
      state = state.copyWith(isLoading: false);
      await _persist();
    } catch (e) {
      final fallback = _getFallbackMoodResponse(newMood);
      _addAiMessage(fallback);
      state = state.copyWith(isLoading: false);
      await _persist();
    }
  }

  // ── Start return conversation ────────────────────────────────────────

  Future<void> startReturnConversation() async {
    final section = ConversationSection(
      id: _uuid.v4(),
      startTime: DateTime.now(),
      mood: state.currentMood,
    );

    final updatedSections = [...state.sections, section];
    state = state.copyWith(sections: updatedSections);

    final greeting =
        _returnGreetings[Random().nextInt(_returnGreetings.length)];
    _addAiMessage(greeting);
    await _persist();
  }

  // ── Send user message ───────────────────────────────────────────────

  Future<void> sendMessage(String text, {bool isVoice = false}) async {
    if (text.trim().isEmpty) return;

    // Auto-create a section if none exists (chat opened without mood selection)
    if (state.sections.isEmpty) {
      final section = ConversationSection(
        id: _uuid.v4(),
        startTime: DateTime.now(),
        mood: state.currentMood,
      );
      state = state.copyWith(sections: [section]);
    }

    // Add user message
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
      isVoice: isVoice,
    );
    _addMessageToActiveSection(userMsg);
    state = state.copyWith(isLoading: true, error: null);

    // Build conversation history — cap at last 8 messages to reduce TTFB
    final activeMessages = state.activeSection?.messages ?? [];
    final recent = activeMessages.length > 8
        ? activeMessages.sublist(activeMessages.length - 8)
        : activeMessages;
    final history = recent
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

    // Place empty AI message immediately — will fill token-by-token
    final aiMsgId = _uuid.v4();
    _addAiMessage('', id: aiMsgId);

    // Collect all chunks — Supabase buffers SSE so they arrive together
    final buffer = StringBuffer();
    try {
      await for (final chunk in _streamService.streamChat(
        messages: history,
        mood: state.currentMood,
        isFirstCheckIn: state.sections.length == 1,
        language: language,
      )) {
        buffer.write(chunk);
      }
    } catch (e) {
      debugPrint('[CheckInNotifier] Stream error: $e');
    }

    // Reveal word-by-word regardless of how fast the network delivered it
    final fullText = buffer.isEmpty
        ? 'I hear you. Tell me more about that.'
        : buffer.toString();
    await _animateTextReveal(aiMsgId, fullText);

    state = state.copyWith(isLoading: false, isStreaming: false);
    await _persist();
  }

  // ── Edit a message ──────────────────────────────────────────────────

  Future<void> editMessage(String sectionId, String messageId, String newText) async {
    final updatedSections = state.sections.map((section) {
      if (section.id != sectionId) return section;

      final updatedMessages = section.messages.map((msg) {
        if (msg.id != messageId) return msg;
        return ChatMessage(
          id: msg.id,
          text: newText,
          isUser: msg.isUser,
          timestamp: msg.timestamp,
          isVoice: msg.isVoice,
        );
      }).toList();

      return section.copyWith(messages: updatedMessages);
    }).toList();

    state = state.copyWith(sections: updatedSections);
    await _persist();
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  /// Reveals [fullText] word by word, giving the ChatGPT typing effect.
  Future<void> _animateTextReveal(String messageId, String fullText) async {
    if (fullText.isEmpty) return;
    state = state.copyWith(isLoading: false, isStreaming: true);
    final words = fullText.split(' ');
    final buf = StringBuffer();
    for (int i = 0; i < words.length; i++) {
      if (i > 0) buf.write(' ');
      buf.write(words[i]);
      _updateStreamingMessage(messageId, buf.toString());
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  void _addAiMessage(String text, {String? id}) {
    final msg = ChatMessage(
      id: id ?? _uuid.v4(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
    _addMessageToActiveSection(msg);
  }

  /// Replaces the text of an existing message in-place (used during streaming).
  void _updateStreamingMessage(String messageId, String newText) {
    if (state.sections.isEmpty) return;
    final updatedSections = [...state.sections];
    final lastSection = updatedSections.last;
    final updatedMessages = lastSection.messages.map((msg) {
      if (msg.id != messageId) return msg;
      return ChatMessage(
        id: msg.id,
        text: newText,
        isUser: msg.isUser,
        timestamp: msg.timestamp,
        isVoice: msg.isVoice,
      );
    }).toList();
    updatedSections[updatedSections.length - 1] =
        lastSection.copyWith(messages: updatedMessages);
    state = state.copyWith(sections: updatedSections);
  }

  void _addMessageToActiveSection(ChatMessage msg) {
    if (state.sections.isEmpty) return;

    final updatedSections = [...state.sections];
    final lastSection = updatedSections.last;
    updatedSections[updatedSections.length - 1] = lastSection.copyWith(
      messages: [...lastSection.messages, msg],
    );

    state = state.copyWith(sections: updatedSections);
  }

  Future<String> _getAiMoodResponse(String mood) async {
    final systemPrompt = AiPrompts.moodChat(mood, language: language);

    return _aiService.chat(
      messages: [
        {'role': 'system', 'content': systemPrompt},
      ],
      mood: mood,
      isFirstCheckIn: true,
      language: language,
    );
  }

  String _getFallbackMoodResponse(String mood) {
    switch (mood.toLowerCase()) {
      case 'great':
        return "That's amazing! What's making your day so great?";
      case 'good':
        return 'Nice to hear! What good things happened today?';
      case 'okay':
        return "Fair enough. Want to talk about what's on your mind?";
      case 'low':
        return "I'm sorry you're feeling low. What happened?";
      case 'tough':
        return "That sounds hard. I'm here for you. Want to share what's going on?";
      case 'skipped':
        return "No worries! Just tell me about your day whenever you're ready.";
      default:
        return 'Thanks for sharing. Tell me more about your day.';
    }
  }

  // Mood prompts are now unified in AiPrompts.moodChat()
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final checkInProvider =
    StateNotifierProvider<CheckInNotifier, CheckInState>((ref) {
  final language = ref.watch(localeProvider).languageName;
  final repository = ref.watch(checkInRepositoryProvider);
  return CheckInNotifier(AiService(), language: language, repository: repository);
});

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  return CheckInRepository(client: Supabase.instance.client);
});

final availableDatesProvider = FutureProvider<List<DateTime>>((ref) async {
  // Re-read whenever checkInProvider changes (new entries saved)
  ref.watch(checkInProvider);

  // Merge Hive local dates with Supabase remote dates
  final hiveDates = await CheckInNotifier.getAvailableDates();
  final hiveKeys = hiveDates.map(CheckInNotifier.dateKey).toSet();

  try {
    final repository = ref.read(checkInRepositoryProvider);
    final remoteKeys = await repository.getAvailableDateKeys();
    for (final key in remoteKeys) {
      if (!hiveKeys.contains(key)) {
        try {
          hiveDates.add(DateTime.parse(key));
        } catch (e) { debugPrint('[CheckInNotifier] Error: $e'); }
      }
    }
  } catch (e) { debugPrint('[CheckInNotifier] Error: $e'); }

  hiveDates.sort((a, b) => b.compareTo(a)); // newest first
  return hiveDates;
});
