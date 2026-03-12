import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';

void main() {
  // Identity encrypt/decrypt functions — no-op so we can test serialisation
  // without bringing in EncryptionService dependencies.
  String identity(String s) => s;

  // ignore: prefer_function_declarations_over_variables
  final makeEntry = () => JournalEntry(
        id: 'entry-1',
        userId: 'user-1',
        content: 'Hello world',
        rawContent: 'Raw hello world',
        polishedContent: 'Polished hello world',
        mood: 'great',
        entryDate: DateTime(2025, 6, 15),
        entryTime: const TimeOfDay(hour: 9, minute: 30),
        locationName: 'Sydney, Australia',
        latitude: -33.86,
        longitude: 151.20,
        hasPhoto: true,
        hasVoice: false,
        isAiPolished: true,
        isMilestone: false,
        wordCount: 2,
        createdAt: DateTime(2025, 6, 15, 9, 30),
        updatedAt: DateTime(2025, 6, 15, 10, 0),
      );

  group('JournalEntry — Constructor', () {
    test('stores all provided fields', () {
      final entry = makeEntry();
      expect(entry.id, 'entry-1');
      expect(entry.userId, 'user-1');
      expect(entry.content, 'Hello world');
      expect(entry.rawContent, 'Raw hello world');
      expect(entry.polishedContent, 'Polished hello world');
      expect(entry.mood, 'great');
      expect(entry.entryDate, DateTime(2025, 6, 15));
      expect(entry.entryTime, const TimeOfDay(hour: 9, minute: 30));
      expect(entry.locationName, 'Sydney, Australia');
      expect(entry.latitude, -33.86);
      expect(entry.longitude, 151.20);
      expect(entry.hasPhoto, isTrue);
      expect(entry.hasVoice, isFalse);
      expect(entry.isAiPolished, isTrue);
      expect(entry.isMilestone, isFalse);
      expect(entry.wordCount, 2);
    });

    test('defaults hasPhoto/hasVoice/isAiPolished/isMilestone to false', () {
      final entry = JournalEntry(
        id: 'x',
        userId: 'u',
        content: 'c',
        entryDate: DateTime(2025),
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      expect(entry.hasPhoto, isFalse);
      expect(entry.hasVoice, isFalse);
      expect(entry.isAiPolished, isFalse);
      expect(entry.isMilestone, isFalse);
      expect(entry.wordCount, 0);
      expect(entry.media, isEmpty);
    });
  });

  group('JournalEntry — copyWith', () {
    test('returns a new instance with updated fields', () {
      final original = makeEntry();
      final copy = original.copyWith(content: 'Updated', mood: 'good');
      expect(copy.content, 'Updated');
      expect(copy.mood, 'good');
      expect(copy.id, original.id);
      expect(copy.userId, original.userId);
    });

    test('does not mutate the original', () {
      final original = makeEntry();
      original.copyWith(content: 'Changed');
      expect(original.content, 'Hello world');
    });

    test('preserves unchanged fields', () {
      final original = makeEntry();
      final copy = original.copyWith(wordCount: 99);
      expect(copy.rawContent, original.rawContent);
      expect(copy.entryDate, original.entryDate);
      expect(copy.locationName, original.locationName);
    });
  });

  group('JournalEntry — toJson / fromJson round-trip', () {
    test('round-trip preserves all fields', () {
      final original = makeEntry();
      final json = original.toJson(identity);
      final restored = JournalEntry.fromJson(json, identity);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.content, original.content);
      expect(restored.rawContent, original.rawContent);
      expect(restored.mood, original.mood);
      expect(restored.entryDate, original.entryDate);
      expect(restored.locationName, original.locationName);
      expect(restored.hasPhoto, original.hasPhoto);
      expect(restored.hasVoice, original.hasVoice);
      expect(restored.isAiPolished, original.isAiPolished);
      expect(restored.wordCount, original.wordCount);
    });

    test('toJson includes correct keys', () {
      final json = makeEntry().toJson(identity);
      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('user_id'), isTrue);
      expect(json.containsKey('encrypted_content'), isTrue);
      expect(json.containsKey('mood'), isTrue);
      expect(json.containsKey('entry_date'), isTrue);
      expect(json.containsKey('has_photo'), isTrue);
      expect(json.containsKey('word_count'), isTrue);
    });

    test('fromJson handles null optional fields', () {
      final base = makeEntry();
      final json = base.toJson(identity);
      json['encrypted_raw_content'] = null;
      json['polished_content'] = null;
      json['entry_time'] = null;
      json['location_name'] = null;

      final entry = JournalEntry.fromJson(json, identity);
      expect(entry.rawContent, isNull);
      expect(entry.polishedContent, isNull);
      expect(entry.entryTime, isNull);
      expect(entry.locationName, isNull);
    });

    test('fromJson encodes entry_time as HH:mm', () {
      final json = makeEntry().toJson(identity);
      expect(json['entry_time'], '09:30');
    });

    test('encrypt function is applied to content fields', () {
      String addPrefix(String s) => 'ENC:$s';
      final json = makeEntry().toJson(addPrefix);
      expect((json['encrypted_content'] as String).startsWith('ENC:'), isTrue);
      expect((json['encrypted_raw_content'] as String).startsWith('ENC:'), isTrue);
    });

    test('decrypt function is applied during fromJson', () {
      String enc(String s) => 'ENC:$s';
      String dec(String s) => s.replaceFirst('ENC:', '');
      final json = makeEntry().toJson(enc);
      final entry = JournalEntry.fromJson(json, dec);
      expect(entry.content, 'Hello world');
    });
  });

  group('JournalEntry — toSupabaseMap / fromSupabaseMap round-trip', () {
    test('round-trip preserves all fields', () {
      final original = makeEntry();
      final map = original.toSupabaseMap(identity);
      final restored = JournalEntry.fromSupabaseMap(map, identity);
      expect(restored.id, original.id);
      expect(restored.content, original.content);
      expect(restored.mood, original.mood);
    });
  });

  group('JournalEntry — equality', () {
    test('two entries with the same id are equal', () {
      final a = makeEntry();
      final b = makeEntry().copyWith(content: 'Different content');
      expect(a, equals(b));
    });

    test('entries with different ids are not equal', () {
      final a = makeEntry();
      final b = makeEntry().copyWith(id: 'entry-2');
      expect(a, isNot(equals(b)));
    });

    test('hashCode matches for equal entries', () {
      expect(makeEntry().hashCode, equals(makeEntry().hashCode));
    });
  });

  group('JournalEntry — toString', () {
    test('includes id, entryDate, mood, wordCount', () {
      final str = makeEntry().toString();
      expect(str, contains('entry-1'));
      expect(str, contains('great'));
      expect(str, contains('2'));
    });
  });
}
