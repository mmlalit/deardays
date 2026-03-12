import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// Arguments for the `/memory` route, enabling swipe-between-memories.
///
/// Backward-compatible: the router still accepts a bare [JournalEntry] as
/// `extra` (legacy callers); when [MemoryDetailArgs] is passed, the
/// [MemoryDetailScreen] shows a [PageView] so users can swipe between entries.
class MemoryDetailArgs {
  final JournalEntry entry;
  final List<JournalEntry> allEntries;
  final int initialIndex;

  const MemoryDetailArgs({
    required this.entry,
    required this.allEntries,
    required this.initialIndex,
  });
}
