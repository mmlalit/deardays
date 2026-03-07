import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:deardays/features/checkin/data/models/chat_message.dart';
import 'package:deardays/features/checkin/data/models/conversation_section.dart';
import 'package:deardays/services/ai/ai_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class CheckInState {
  final String? currentMood;
  final List<ConversationSection> sections;
  final bool isFirstCheckInToday;
  final bool isLoading;
  final String? error;

  const CheckInState({
    this.currentMood,
    this.sections = const [],
    this.isFirstCheckInToday = true,
    this.isLoading = false,
    this.error,
  });

  CheckInState copyWith({
    String? currentMood,
    List<ConversationSection>? sections,
    bool? isFirstCheckInToday,
    bool? isLoading,
    String? error,
  }) {
    return CheckInState(
      currentMood: currentMood ?? this.currentMood,
      sections: sections ?? this.sections,
      isFirstCheckInToday: isFirstCheckInToday ?? this.isFirstCheckInToday,
      isLoading: isLoading ?? this.isLoading,
      error: error,
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
  "Hey, back again!",
  "How's the rest of your day going?",
  "Welcome back! What's on your mind?",
  "Hey there! Anything new?",
  "Good to see you again! How are things?",
  "Back so soon? Tell me what's happening.",
  "Hi again! What's going on?",
  "How's everything since we last talked?",
  "Hey! What have you been up to?",
];

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class CheckInNotifier extends StateNotifier<CheckInState> {
  CheckInNotifier(this._aiService) : super(const CheckInState()) {
    _loadTodayData();
  }

  final AiService _aiService;
  static const _uuid = Uuid();
  static const _boxName = 'checkin_conversations';

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Persistence ──────────────────────────────────────────────────────

  Future<void> _loadTodayData() async {
    final box = await Hive.openBox(_boxName);
    final raw = box.get(_todayKey);

    if (raw != null) {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final sections = (data['sections'] as List<dynamic>)
          .map((s) => ConversationSection.fromJson(s as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        currentMood: data['mood'] as String?,
        sections: sections,
        isFirstCheckInToday: false,
      );
    }
  }

  Future<void> _persist() async {
    final box = await Hive.openBox(_boxName);
    final data = {
      'mood': state.currentMood,
      'sections': state.sections.map((s) => s.toJson()).toList(),
    };
    await box.put(_todayKey, jsonEncode(data));
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
      );
      _addAiMessage(reply);
      state = state.copyWith(isLoading: false);
      await _persist();
    } catch (e) {
      _addAiMessage("I hear you. Tell me more about that.");
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
    final prompt = _moodPromptMap[mood.toLowerCase()] ??
        "The user is feeling $mood today. Respond warmly and ask them to share more.";

    return _aiService.chat(
      messages: [
        {'role': 'system', 'content': prompt},
      ],
      mood: mood,
      isFirstCheckIn: true,
    );
  }

  String _getFallbackMoodResponse(String mood) {
    switch (mood.toLowerCase()) {
      case 'great':
        return "That's amazing! What's making your day so great?";
      case 'good':
        return "Nice to hear! What good things happened today?";
      case 'okay':
        return "Fair enough. Want to talk about what's on your mind?";
      case 'low':
        return "I'm sorry you're feeling low. What happened?";
      case 'tough':
        return "That sounds hard. I'm here for you. Want to share what's going on?";
      default:
        return "Thanks for sharing. Tell me more about your day.";
    }
  }

  static const _moodPromptMap = {
    'great':
        "The user is feeling great today. Respond with enthusiasm and ask them to share what's making their day wonderful. Keep it short and warm.",
    'good':
        "The user is feeling good today. Respond positively and ask them to share the good things. Keep it conversational and brief.",
    'okay':
        "The user is feeling okay today. Be gently curious, ask what's on their mind. Keep it warm and non-pushy.",
    'low':
        "The user is feeling low today. Be empathetic and caring. Ask what happened in a gentle way. Keep it short and supportive.",
    'tough':
        "The user is having a tough day. Be deeply empathetic. Let them know you're there for them and gently ask if they want to share. Keep it brief and caring.",
  };
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final checkInProvider =
    StateNotifierProvider<CheckInNotifier, CheckInState>((ref) {
  return CheckInNotifier(AiService());
});
