class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isVoice;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isVoice = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'is_user': isUser,
        'timestamp': timestamp.toIso8601String(),
        'is_voice': isVoice,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        text: json['text'] as String,
        isUser: json['is_user'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isVoice: (json['is_voice'] as bool?) ?? false,
      );
}
