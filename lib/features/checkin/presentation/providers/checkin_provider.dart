import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/features/checkin/data/models/chat_message.dart';
import 'package:deardays/features/checkin/data/models/conversation_section.dart';
import 'package:deardays/features/checkin/data/repositories/checkin_repository.dart';
import 'package:deardays/services/ai/ai_service.dart';
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
  final String? error;
  final DateTime loadedDate;

  CheckInState({
    this.currentMood,
    this.sections = const [],
    this.isFirstCheckInToday = true,
    this.isLoading = false,
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
    String? error,
    DateTime? loadedDate,
  }) {
    return CheckInState(
      currentMood: currentMood ?? this.currentMood,
      sections: sections ?? this.sections,
      isFirstCheckInToday: isFirstCheckInToday ?? this.isFirstCheckInToday,
      isLoading: isLoading ?? this.isLoading,
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
  final String? language;
  final CheckInRepository? repository;
  static const _uuid = Uuid();
  static const _boxName = 'checkin_conversations';

  /// Opens the checkin conversations Hive box with encryption.
  static Future<Box> _openBox() async {
    try {
      final cipher = LocalStorageService.instance.cipher;
      return await Hive.openBox(_boxName, encryptionCipher: cipher);
    } catch (_) {
      // Fallback for tests where LocalStorageService isn't initialized.
      return await _openBox();
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
      } catch (_) {
        // Network unavailable — stay empty, no crash
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
    repository?.upsertConversation(_todayKey, data).catchError((_) {});
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
      } catch (_) {}

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

  static Future<List<DateTime>> getAvailableDates() async {
    final box = await _openBox();
    final keys = box.keys.cast<String>().toList();
    final dates = <DateTime>[];
    for (final key in keys) {
      try {
        dates.add(DateTime.parse(key));
      } catch (_) {}
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

    // Build conversation history for AI
    final activeMessages = state.activeSection?.messages ?? [];
    final history = activeMessages.map((m) {
      return {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      };
    }).toList();

    try {
      final reply = await _aiService.chat(
        messages: history,
        mood: state.currentMood,
        isFirstCheckIn: state.sections.length == 1,
        language: language,
      );
      _addAiMessage(reply);
      state = state.copyWith(isLoading: false);
      await _persist();
    } catch (e) {
      _addAiMessage('I hear you. Tell me more about that.');
      state = state.copyWith(isLoading: false);
      await _persist();
    }
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

  void _addAiMessage(String text) {
    final msg = ChatMessage(
      id: _uuid.v4(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
    _addMessageToActiveSection(msg);
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
    final basePrompt = _moodPromptMap[mood.toLowerCase()] ??
        'The user is feeling $mood today. Respond warmly and ask them to share more.';

    final langInstruction = language != null && language != 'English'
        ? " The user's preferred language is $language. Default to $language, but if the user writes in a different language, respond in that language instead."
        : ' Respond in the same language the user writes in.';

    return _aiService.chat(
      messages: [
        {'role': 'system', 'content': basePrompt + langInstruction},
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

  static const _moodPromptMap = {
    'great':
        "The user is feeling great today. Respond with enthusiasm and ask them to share what's making their day wonderful. Keep it short and warm.",
    'good':
        'The user is feeling good today. Respond positively and ask them to share the good things. Keep it conversational and brief.',
    'okay':
        "The user is feeling okay today. Be gently curious, ask what's on their mind. Keep it warm and non-pushy.",
    'low':
        'The user is feeling low today. Be empathetic and caring. Ask what happened in a gentle way. Keep it short and supportive.',
    'tough':
        "The user is having a tough day. Be deeply empathetic. Let them know you're there for them and gently ask if they want to share. Keep it brief and caring.",
    'skipped':
        "The user skipped mood selection. Be casual and open. Simply ask them what's on their mind or how their day is going. Keep it brief and friendly.",
  };
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
        } catch (_) {}
      }
    }
  } catch (_) {}

  hiveDates.sort((a, b) => b.compareTo(a)); // newest first
  return hiveDates;
});
