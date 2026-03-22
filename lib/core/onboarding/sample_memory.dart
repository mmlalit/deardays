import 'package:flutter/material.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// Builds a sample JournalEntry to pre-populate the app for new users.
/// Tagged with '__sample__' so it can be auto-deleted when the first real
/// memory is saved.
JournalEntry buildSampleMemory({
  required String userId,
  String? chapterId,
}) {
  final now = DateTime.now();
  return JournalEntry(
    id: 'sample-onboarding-001',
    userId: userId,
    content: "I just downloaded DearDays and I'm figuring out how it works. "
        "Not sure what to write yet — but I'm starting, and that feels like enough.",
    rawContent:
        "I just downloaded DearDays and I'm figuring out how it works. "
        "Not sure what to write yet — but I'm starting, and that feels like enough.",
    polishedContent:
        'The first entry is always the hardest. '
        'I opened DearDays today, unsure what to say — '
        "but beginnings don't need to be perfect. They just need to begin.",
    mood: 'good',
    entryDate: now,
    entryTime: TimeOfDay.fromDateTime(now),
    isAiPolished: true,
    tags: const ['__sample__', 'beginnings'],
    wordCount: 28,
    chapterId: chapterId,
    createdAt: now,
    updatedAt: now,
  );
}

/// Returns true if the given entry is a seeded sample memory.
bool isSampleEntry(JournalEntry entry) {
  return entry.tags.contains('__sample__') ||
      entry.id == 'sample-onboarding-001';
}
