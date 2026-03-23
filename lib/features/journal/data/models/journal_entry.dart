import 'package:flutter/material.dart';

import 'package:deardays/features/journal/data/models/entry_media.dart';

class JournalEntry {
  final String id;
  final String userId;
  final String content; // light-polished text (grammar/spelling fixed)
  final String? rawContent; // decrypted original text/transcript
  final String? polishedContent; // AI literary narrative for Book view
  final String? mood; // great, good, okay, low, tough
  final DateTime entryDate;
  final TimeOfDay? entryTime;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final bool hasPhoto;
  final bool hasVoice;
  final bool isAiPolished;
  final bool isMilestone;
  final String? milestoneType;
  final int wordCount;
  final String promptVersion; // tracks which AI prompt version processed this entry
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? chapterId;
  final List<EntryMedia> media;

  // AI-generated semantic metadata (populated asynchronously by ai-tag function)
  final double? sentimentScore;    // -1.0 to 1.0
  final String? emotion;           // primary emotion label
  final List<String> tags;         // topic tags
  final List<String> people;       // people mentioned
  final List<String> activities;   // activities described
  final List<String> extractedLocations; // locations from text
  final List<String> topics;       // abstract themes
  final bool tagsGenerated;        // true once ai-tag has run

  const JournalEntry({
    required this.id,
    required this.userId,
    required this.content,
    this.rawContent,
    this.polishedContent,
    this.mood,
    required this.entryDate,
    this.entryTime,
    this.locationName,
    this.latitude,
    this.longitude,
    this.hasPhoto = false,
    this.hasVoice = false,
    this.isAiPolished = false,
    this.isMilestone = false,
    this.milestoneType,
    this.wordCount = 0,
    this.promptVersion = 'v1',
    this.chapterId,
    required this.createdAt,
    required this.updatedAt,
    this.media = const [],
    this.sentimentScore,
    this.emotion,
    this.tags = const [],
    this.people = const [],
    this.activities = const [],
    this.extractedLocations = const [],
    this.topics = const [],
    this.tagsGenerated = false,
  });

  JournalEntry copyWith({
    String? id,
    String? userId,
    String? content,
    String? rawContent,
    String? polishedContent,
    String? mood,
    DateTime? entryDate,
    TimeOfDay? entryTime,
    String? locationName,
    double? latitude,
    double? longitude,
    bool? hasPhoto,
    bool? hasVoice,
    bool? isAiPolished,
    bool? isMilestone,
    String? milestoneType,
    int? wordCount,
    String? promptVersion,
    String? chapterId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<EntryMedia>? media,
    double? sentimentScore,
    String? emotion,
    List<String>? tags,
    List<String>? people,
    List<String>? activities,
    List<String>? extractedLocations,
    List<String>? topics,
    bool? tagsGenerated,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      rawContent: rawContent ?? this.rawContent,
      polishedContent: polishedContent ?? this.polishedContent,
      mood: mood ?? this.mood,
      entryDate: entryDate ?? this.entryDate,
      entryTime: entryTime ?? this.entryTime,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hasPhoto: hasPhoto ?? this.hasPhoto,
      hasVoice: hasVoice ?? this.hasVoice,
      isAiPolished: isAiPolished ?? this.isAiPolished,
      isMilestone: isMilestone ?? this.isMilestone,
      milestoneType: milestoneType ?? this.milestoneType,
      wordCount: wordCount ?? this.wordCount,
      promptVersion: promptVersion ?? this.promptVersion,
      chapterId: chapterId ?? this.chapterId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      media: media ?? this.media,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      emotion: emotion ?? this.emotion,
      tags: tags ?? this.tags,
      people: people ?? this.people,
      activities: activities ?? this.activities,
      extractedLocations: extractedLocations ?? this.extractedLocations,
      topics: topics ?? this.topics,
      tagsGenerated: tagsGenerated ?? this.tagsGenerated,
    );
  }

  /// Serializes to JSON for storage/transport.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'encrypted_content': content,
      'encrypted_raw_content': rawContent,
      'polished_content': polishedContent,
      'mood': mood,
      'entry_date': entryDate.toIso8601String(),
      'entry_time': entryTime != null
          ? '${entryTime!.hour.toString().padLeft(2, '0')}:${entryTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'has_photo': hasPhoto,
      'has_voice': hasVoice,
      'is_ai_polished': isAiPolished,
      'is_milestone': isMilestone,
      'milestone_type': milestoneType,
      'word_count': wordCount,
      'prompt_version': promptVersion,
      'chapter_id': chapterId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (media.isNotEmpty)
        'entry_media': media.map((m) => m.toMap()).toList(),
    };
  }

  /// Deserializes from JSON.
  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['encrypted_content'] as String,
      rawContent: json['encrypted_raw_content'] as String?,
      polishedContent: json['polished_content'] as String?,
      mood: json['mood'] as String?,
      entryDate: DateTime.parse(json['entry_date'] as String),
      entryTime: _parseTimeOfDay(json['entry_time'] as String?),
      locationName: json['location_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      hasPhoto: (json['has_photo'] as bool?) ?? false,
      hasVoice: (json['has_voice'] as bool?) ?? false,
      isAiPolished: (json['is_ai_polished'] as bool?) ?? false,
      isMilestone: (json['is_milestone'] as bool?) ?? false,
      milestoneType: json['milestone_type'] as String?,
      wordCount: (json['word_count'] as num?)?.toInt() ?? 0,
      promptVersion: json['prompt_version'] as String? ?? 'v1',
      chapterId: json['chapter_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      media: (json['entry_media'] as List<dynamic>?)
              ?.map((e) => EntryMedia.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Converts to a map suitable for Supabase insert/update.
  /// Uses actual DB table column names (not decrypted-view aliases).
  /// Only includes columns that exist on the raw `journal_entries` table.
  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'content': content,
      'raw_content': rawContent,
      'polished_content': polishedContent,
      'mood': mood,
      'entry_date': entryDate.toIso8601String(),
      'entry_time': entryTime != null
          ? '${entryTime!.hour.toString().padLeft(2, '0')}:${entryTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'has_photo': hasPhoto,
      'has_voice': hasVoice,
      'is_ai_polished': isAiPolished,
      'word_count': wordCount,
      'chapter_id': chapterId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (tags.isNotEmpty) map['tags'] = tags;
    // Remove null values so Supabase uses DB defaults
    map.removeWhere((_, v) => v == null);
    return map;
  }

  /// Creates a JournalEntry from a Supabase row map.
  /// Supports both raw table columns (`content`) and view aliases (`encrypted_content`).
  factory JournalEntry.fromSupabaseMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      content: (map['content'] ?? map['encrypted_content']) as String,
      rawContent: (map['raw_content'] ?? map['encrypted_raw_content']) as String?,
      polishedContent: map['polished_content'] as String?,
      mood: map['mood'] as String?,
      entryDate: DateTime.parse(map['entry_date'] as String),
      entryTime: _parseTimeOfDay(map['entry_time'] as String?),
      locationName: map['location_name'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      hasPhoto: (map['has_photo'] as bool?) ?? false,
      hasVoice: (map['has_voice'] as bool?) ?? false,
      isAiPolished: (map['is_ai_polished'] as bool?) ?? false,
      isMilestone: (map['is_milestone'] as bool?) ?? false,
      milestoneType: map['milestone_type'] as String?,
      wordCount: (map['word_count'] as num?)?.toInt() ?? 0,
      promptVersion: map['prompt_version'] as String? ?? 'v1',
      chapterId: map['chapter_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      media: (map['entry_media'] as List<dynamic>?)
              ?.map((e) => EntryMedia.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      sentimentScore: (map['sentiment_score'] as num?)?.toDouble(),
      emotion: map['emotion'] as String?,
      tags: _parseStringList(map['tags']),
      people: _parseStringList(map['people']),
      activities: _parseStringList(map['activities']),
      extractedLocations: _parseStringList(map['extracted_locations']),
      topics: _parseStringList(map['topics']),
      tagsGenerated: (map['tags_generated'] as bool?) ?? false,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  static TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  @override
  String toString() {
    return 'JournalEntry(id: $id, entryDate: $entryDate, mood: $mood, wordCount: $wordCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalEntry && other.id == id && other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => id.hashCode;
}
