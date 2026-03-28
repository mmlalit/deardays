import 'dart:convert';

/// [DraftType.text]    — user wrote in TextEntryScreen and left.
/// [DraftType.review]  — AI processing completed; user left ReviewSaveScreen.
/// [DraftType.voice]   — user abandoned a recording with a transcript.
/// [DraftType.checkin] — user left a check-in chat without saving as memory.
enum DraftType { text, review, voice, checkin }

/// A saved-but-not-submitted journal entry draft.
class DraftEntry {
  final String id;
  final DraftType type;
  final String rawText;
  final DateTime savedAt;
  final DateTime entryDate;
  final String? userId;

  // Review-stage extras (null for text drafts)
  final String? cleanedText;
  final String? polishedText;
  final String? generatedTitle;
  final String? mood;
  final String? locationName;
  final String? attachedPhotoPath;
  final bool isVoice;

  const DraftEntry({
    required this.id,
    required this.type,
    required this.rawText,
    required this.savedAt,
    required this.entryDate,
    this.userId,
    this.cleanedText,
    this.polishedText,
    this.generatedTitle,
    this.mood,
    this.locationName,
    this.attachedPhotoPath,
    this.isVoice = false,
  });

  /// Short preview of content for the history list.
  String get preview {
    final text = (cleanedText ?? rawText).trim();
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  int get wordCount {
    final text = rawText.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  // ── Hive JSON (camelCase, backward-compatible) ────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'rawText': rawText,
        'savedAt': savedAt.toIso8601String(),
        'entryDate': entryDate.toIso8601String(),
        'userId': userId,
        'cleanedText': cleanedText,
        'polishedText': polishedText,
        'generatedTitle': generatedTitle,
        'mood': mood,
        'locationName': locationName,
        'attachedPhotoPath': attachedPhotoPath,
        'isVoice': isVoice,
      };

  factory DraftEntry.fromJson(Map<String, dynamic> json) => DraftEntry(
        id: json['id'] as String,
        type: DraftType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => DraftType.text,
        ),
        rawText: json['rawText'] as String,
        savedAt: DateTime.parse(json['savedAt'] as String),
        entryDate: DateTime.parse(json['entryDate'] as String),
        userId: json['userId'] as String?,
        cleanedText: json['cleanedText'] as String?,
        polishedText: json['polishedText'] as String?,
        generatedTitle: json['generatedTitle'] as String?,
        mood: json['mood'] as String?,
        locationName: json['locationName'] as String?,
        attachedPhotoPath: json['attachedPhotoPath'] as String?,
        isVoice: json['isVoice'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  factory DraftEntry.fromJsonString(String s) =>
      DraftEntry.fromJson(jsonDecode(s) as Map<String, dynamic>);

  // ── Supabase (snake_case) ─────────────────────────────────────────────

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'user_id': userId,
        'type': type.name,
        'raw_text': rawText,
        'saved_at': savedAt.toIso8601String(),
        'entry_date': entryDate.toIso8601String(),
        'cleaned_text': cleanedText,
        'polished_text': polishedText,
        'generated_title': generatedTitle,
        'mood': mood,
        'location_name': locationName,
        'attached_photo_path': attachedPhotoPath,
        'is_voice': isVoice,
        // updated_at omitted — let the DB default/trigger handle it.
      };

  factory DraftEntry.fromSupabaseMap(Map<String, dynamic> map) => DraftEntry(
        id: map['id'] as String,
        type: DraftType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => DraftType.text,
        ),
        rawText: map['raw_text'] as String,
        savedAt: DateTime.parse(map['saved_at'] as String),
        entryDate: DateTime.parse(map['entry_date'] as String),
        userId: map['user_id'] as String?,
        cleanedText: map['cleaned_text'] as String?,
        polishedText: map['polished_text'] as String?,
        generatedTitle: map['generated_title'] as String?,
        mood: map['mood'] as String?,
        locationName: map['location_name'] as String?,
        attachedPhotoPath: map['attached_photo_path'] as String?,
        isVoice: map['is_voice'] as bool? ?? false,
      );
}
