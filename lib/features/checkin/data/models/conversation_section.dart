import 'chat_message.dart';

class ConversationSection {
  final String id;
  final DateTime startTime;
  final String? mood;
  final List<ChatMessage> messages;

  const ConversationSection({
    required this.id,
    required this.startTime,
    this.mood,
    this.messages = const [],
  });

  ConversationSection copyWith({
    String? id,
    DateTime? startTime,
    String? mood,
    List<ChatMessage>? messages,
  }) {
    return ConversationSection(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      mood: mood ?? this.mood,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start_time': startTime.toIso8601String(),
        'mood': mood,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ConversationSection.fromJson(Map<String, dynamic> json) {
    return ConversationSection(
      id: json['id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      mood: json['mood'] as String?,
      messages: (json['messages'] as List<dynamic>)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
