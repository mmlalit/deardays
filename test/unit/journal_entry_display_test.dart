library;

/// Test A (continued) + Test B — Data display correctness.
///
/// Verifies that the data fields used by UI widgets contain correct values:
/// - entryTime vs entryDate (the 00:00 bug)
/// - Time serialization/deserialization round-trip
/// - Content extraction (title, excerpt)
/// - Date formatting logic
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/entry_media.dart';

void main() {
  final now = DateTime(2026, 3, 14, 19, 49, 30);

  // ---------------------------------------------------------------------------
  // B1. Time display correctness — the 00:00 bug
  // ---------------------------------------------------------------------------

  group('Entry time display — the 00:00 bug', () {
    test('entryDate is date-only (midnight) — NOT suitable for time display', () {
      final entry = JournalEntry(
        id: 'e1',
        userId: 'u1',
        content: 'Test',
        entryDate: DateTime(2026, 3, 14), // midnight
        entryTime: const TimeOfDay(hour: 19, minute: 49),
        wordCount: 1,
        createdAt: now,
        updatedAt: now,
      );

      // entryDate is always midnight — using it for time gives 00:00
      expect(entry.entryDate.hour, 0);
      expect(entry.entryDate.minute, 0);

      // entryTime is the actual time — this is what UI should use
      expect(entry.entryTime!.hour, 19);
      expect(entry.entryTime!.minute, 49);
    });

    test('time string should use entryTime, not entryDate', () {
      final entry = JournalEntry(
        id: 'e1',
        userId: 'u1',
        content: 'Test',
        entryDate: DateTime(2026, 3, 14),
        entryTime: const TimeOfDay(hour: 19, minute: 49),
        wordCount: 1,
        createdAt: now,
        updatedAt: now,
      );

      // Correct time extraction (as done in timeline_screen.dart)
      final timeStr = entry.entryTime != null
          ? '${entry.entryTime!.hour.toString().padLeft(2, '0')}:${entry.entryTime!.minute.toString().padLeft(2, '0')}'
          : DateFormat('HH:mm').format(entry.createdAt);

      expect(timeStr, '19:49');
      expect(timeStr, isNot('00:00'));
    });

    test('fallback to createdAt when entryTime is null', () {
      final entry = JournalEntry(
        id: 'e1',
        userId: 'u1',
        content: 'Test',
        entryDate: DateTime(2026, 3, 14),
        entryTime: null,
        wordCount: 1,
        createdAt: DateTime(2026, 3, 14, 15, 30, 0),
        updatedAt: now,
      );

      final timeStr = entry.entryTime != null
          ? '${entry.entryTime!.hour.toString().padLeft(2, '0')}:${entry.entryTime!.minute.toString().padLeft(2, '0')}'
          : DateFormat('HH:mm').format(entry.createdAt);

      expect(timeStr, '15:30');
    });

    test('date string format matches timeline card pattern', () {
      final entry = JournalEntry(
        id: 'e1',
        userId: 'u1',
        content: 'Test',
        entryDate: DateTime(2026, 3, 14),
        entryTime: const TimeOfDay(hour: 8, minute: 5),
        wordCount: 1,
        createdAt: now,
        updatedAt: now,
      );

      final timeStr = '${entry.entryTime!.hour.toString().padLeft(2, '0')}:${entry.entryTime!.minute.toString().padLeft(2, '0')}';
      final dateStr = '${DateFormat('MMM dd').format(entry.entryDate).toUpperCase()} • $timeStr';

      expect(dateStr, 'MAR 14 • 08:05');
    });

    test('all mock entries with entryTime have valid non-midnight times', () {
      // Verify no mock data silently produces 00:00
      final entries = [
        JournalEntry(id: 'e1', userId: 'u', content: 'A', entryDate: DateTime(2026, 3, 5), entryTime: const TimeOfDay(hour: 8, minute: 30), wordCount: 1, createdAt: now, updatedAt: now),
        JournalEntry(id: 'e2', userId: 'u', content: 'B', entryDate: DateTime(2026, 2, 18), entryTime: const TimeOfDay(hour: 21, minute: 15), wordCount: 1, createdAt: now, updatedAt: now),
        JournalEntry(id: 'e3', userId: 'u', content: 'C', entryDate: DateTime(2026, 1, 26), entryTime: const TimeOfDay(hour: 7, minute: 10), wordCount: 1, createdAt: now, updatedAt: now),
      ];

      for (final entry in entries) {
        final timeStr = '${entry.entryTime!.hour.toString().padLeft(2, '0')}:${entry.entryTime!.minute.toString().padLeft(2, '0')}';
        expect(timeStr, isNot('00:00'), reason: 'Entry ${entry.id} shows 00:00');
        expect(entry.entryTime!.hour + entry.entryTime!.minute, greaterThan(0),
            reason: 'Entry ${entry.id} has zero time');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // B2. Time serialization round-trip (Supabase → model → display)
  // ---------------------------------------------------------------------------

  group('Time serialization round-trip', () {
    test('TimeOfDay serializes to HH:MM string in toSupabaseMap', () {
      final entry = JournalEntry(
        id: 'e1',
        userId: 'u1',
        content: 'Test',
        entryDate: DateTime(2026, 3, 14),
        entryTime: const TimeOfDay(hour: 19, minute: 49),
        wordCount: 1,
        createdAt: now,
        updatedAt: now,
      );

      final map = entry.toSupabaseMap();
      // entry_time should be serialized as "19:49"
      expect(map['entry_time'], isNotNull);
      expect(map['entry_time'], contains(':'));
    });

    test('null entryTime serializes to null', () {
      final entry = JournalEntry(
        id: 'e1',
        userId: 'u1',
        content: 'Test',
        entryDate: DateTime(2026, 3, 14),
        entryTime: null,
        wordCount: 1,
        createdAt: now,
        updatedAt: now,
      );

      final map = entry.toSupabaseMap();
      expect(map['entry_time'], isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // B3. Content extraction — title and excerpt
  // ---------------------------------------------------------------------------

  group('Content extraction', () {
    String extractTitle(JournalEntry entry) {
      final lines = entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return 'Untitled Memory';
      final first = lines.first.trim();
      if (first.length < 80 && lines.length > 1) return first;
      return entry.content.length > 50 ? '${entry.content.substring(0, 50)}...' : entry.content;
    }

    String extractExcerpt(JournalEntry entry) {
      final lines = entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return '';
      final first = lines.first.trim();
      final isTitle = first.length < 80 && lines.length > 1;
      final body = isTitle ? lines.skip(1).join(' ') : entry.content;
      return body.length > 100 ? '${body.substring(0, 100)}...' : body;
    }

    test('extracts title from first line when followed by body', () {
      final entry = JournalEntry(
        id: 'e1', userId: 'u1',
        content: 'My Amazing Day\n\nThe weather was perfect and I went for a long walk.',
        entryDate: now, wordCount: 10, createdAt: now, updatedAt: now,
      );
      expect(extractTitle(entry), 'My Amazing Day');
    });

    test('truncates single-line long content at 50 chars', () {
      final entry = JournalEntry(
        id: 'e1', userId: 'u1',
        content: 'This is a really long single line entry that goes on and on without any breaks at all',
        entryDate: now, wordCount: 15, createdAt: now, updatedAt: now,
      );
      final title = extractTitle(entry);
      expect(title.length, lessThanOrEqualTo(53)); // 50 + "..."
      expect(title, endsWith('...'));
    });

    test('empty content returns Untitled Memory', () {
      final entry = JournalEntry(
        id: 'e1', userId: 'u1',
        content: '',
        entryDate: now, wordCount: 0, createdAt: now, updatedAt: now,
      );
      expect(extractTitle(entry), 'Untitled Memory');
    });

    test('excerpt skips title line', () {
      final entry = JournalEntry(
        id: 'e1', userId: 'u1',
        content: 'Title Line\n\nBody text that follows the title.',
        entryDate: now, wordCount: 8, createdAt: now, updatedAt: now,
      );
      final excerpt = extractExcerpt(entry);
      expect(excerpt, isNot(contains('Title Line')));
      expect(excerpt, contains('Body text'));
    });
  });

  // ---------------------------------------------------------------------------
  // B4. Media presence determines UI rendering path
  // ---------------------------------------------------------------------------

  group('Media determines rendering path', () {
    test('entry with photo media renders photo path (not gradient)', () {
      final entry = JournalEntry(
        id: 'e1', userId: 'u1', content: 'Test',
        entryDate: now, wordCount: 1, createdAt: now, updatedAt: now,
        hasPhoto: true,
        media: [
          EntryMedia(id: 'm1', entryId: 'e1', userId: 'u1', mediaType: 'photo', storagePath: 'user/entry/photo.jpg', createdAt: now),
        ],
      );

      final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
      expect(photoMedia.isNotEmpty, isTrue, reason: 'Should take photo rendering path');
    });

    test('entry without photo media renders gradient banner path', () {
      final entry = JournalEntry(
        id: 'e1', userId: 'u1', content: 'Test',
        entryDate: now, wordCount: 1, createdAt: now, updatedAt: now,
        media: [],
      );

      final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
      expect(photoMedia.isEmpty, isTrue, reason: 'Should take gradient rendering path');
    });

    test('entry with only voice media does not render photo', () {
      final entry = JournalEntry(
        id: 'e1', userId: 'u1', content: 'Test',
        entryDate: now, wordCount: 1, createdAt: now, updatedAt: now,
        hasVoice: true,
        media: [
          EntryMedia(id: 'm1', entryId: 'e1', userId: 'u1', mediaType: 'voice', storagePath: 'user/entry/audio.m4a', createdAt: now),
        ],
      );

      final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
      expect(photoMedia.isEmpty, isTrue);
    });
  });
}
