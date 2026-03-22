import 'dart:convert';

enum DraftType { text, review }

/// A saved-but-not-submitted journal entry draft.
///
/// [DraftType.text]   — user wrote in TextEntryScreen and left.
/// [DraftType.review] — AI processing completed; user left ReviewSaveScreen.
class DraftEntry {
  final String id;
  final DraftType type;
  final String rawText;
  final DateTime savedAt;
  final DateTime entryDate;

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'rawText': rawText,
        'savedAt': savedAt.toIso8601String(),
        'entryDate': entryDate.toIso8601String(),
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
}
