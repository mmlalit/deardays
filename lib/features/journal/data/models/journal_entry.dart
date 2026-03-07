import 'package:flutter/material.dart';

import 'package:deardays/features/journal/data/models/entry_media.dart';

class JournalEntry {
  final String id;
  final String userId;
  final String content; // decrypted narrative
  final String? rawContent; // decrypted original text/transcript
  final String? mood; // great, good, okay, low, tough
  final DateTime entryDate;
  final TimeOfDay? entryTime;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final bool hasPhoto;
  final bool hasVoice;
  final bool isAiPolished;
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<EntryMedia> media;

  const JournalEntry({
    required this.id,
    required this.userId,
    required this.content,
    this.rawContent,
    this.mood,
    required this.entryDate,
    this.entryTime,
    this.locationName,
    this.latitude,
    this.longitude,
    this.hasPhoto = false,
    this.hasVoice = false,
    this.isAiPolished = false,
    this.wordCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.media = const [],
  });

  JournalEntry copyWith({
    String? id,
    String? userId,
    String? content,
    String? rawContent,
    String? mood,
    DateTime? entryDate,
    TimeOfDay? entryTime,
    String? locationName,
    double? latitude,
    double? longitude,
    bool? hasPhoto,
    bool? hasVoice,
    bool? isAiPolished,
    int? wordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<EntryMedia>? media,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      rawContent: rawContent ?? this.rawContent,
      mood: mood ?? this.mood,
      entryDate: entryDate ?? this.entryDate,
      entryTime: entryTime ?? this.entryTime,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hasPhoto: hasPhoto ?? this.hasPhoto,
      hasVoice: hasVoice ?? this.hasVoice,
      isAiPolished: isAiPolished ?? this.isAiPolished,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      media: media ?? this.media,
    );
  }

  /// Serializes to JSON, encrypting content fields with the provided function.
  Map<String, dynamic> toJson(String Function(String plaintext) encryptFn) {
    return {
      'id': id,
      'user_id': userId,
      'content': encryptFn(content),
      'raw_content': rawContent != null ? encryptFn(rawContent!) : null,
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Deserializes from JSON, decrypting content fields with the provided function.
  factory JournalEntry.fromJson(
    Map<String, dynamic> json,
    String Function(String ciphertext) decryptFn,
  ) {
    return JournalEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: decryptFn(json['content'] as String),
      rawContent: json['raw_content'] != null
          ? decryptFn(json['raw_content'] as String)
          : null,
      mood: json['mood'] as String?,
      entryDate: DateTime.parse(json['entry_date'] as String),
      entryTime: _parseTimeOfDay(json['entry_time'] as String?),
      locationName: json['location_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      hasPhoto: (json['has_photo'] as bool?) ?? false,
      hasVoice: (json['has_voice'] as bool?) ?? false,
      isAiPolished: (json['is_ai_polished'] as bool?) ?? false,
      wordCount: (json['word_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      media: (json['entry_media'] as List<dynamic>?)
              ?.map((e) => EntryMedia.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Converts to a map suitable for Supabase insert/update.
  /// Encrypts content and rawContent before returning.
  Map<String, dynamic> toSupabaseMap(
    String Function(String plaintext) encryptFn,
  ) {
    return {
      'id': id,
      'user_id': userId,
      'content': encryptFn(content),
      'raw_content': rawContent != null ? encryptFn(rawContent!) : null,
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Creates a JournalEntry from a Supabase row map.
  /// Decrypts content and rawContent after reading.
  factory JournalEntry.fromSupabaseMap(
    Map<String, dynamic> map,
    String Function(String ciphertext) decryptFn,
  ) {
    return JournalEntry(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      content: decryptFn(map['content'] as String),
      rawContent: map['raw_content'] != null
          ? decryptFn(map['raw_content'] as String)
          : null,
      mood: map['mood'] as String?,
      entryDate: DateTime.parse(map['entry_date'] as String),
      entryTime: _parseTimeOfDay(map['entry_time'] as String?),
      locationName: map['location_name'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      hasPhoto: (map['has_photo'] as bool?) ?? false,
      hasVoice: (map['has_voice'] as bool?) ?? false,
      isAiPolished: (map['is_ai_polished'] as bool?) ?? false,
      wordCount: (map['word_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      media: (map['entry_media'] as List<dynamic>?)
              ?.map((e) => EntryMedia.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  static TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  @override
  String toString() {
    return 'JournalEntry(id: $id, entryDate: $entryDate, mood: $mood, wordCount: $wordCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
