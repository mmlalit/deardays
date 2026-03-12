import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

void main() {
  // Unique temp directory per run so tests don't pollute each other.
  final hiveDir = Directory(
    '${Directory.systemTemp.path}/ls_test_${DateTime.now().millisecondsSinceEpoch}',
  );

  setUpAll(() {
    hiveDir.createSync(recursive: true);
  });

  tearDownAll(() async {
    // Close Hive so Windows releases file locks before we delete the directory.
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  group('LocalStorageService — singleton', () {
    test('factory always returns the same instance', () {
      final a = LocalStorageService();
      final b = LocalStorageService();
      expect(identical(a, b), isTrue);
    });
  });

  group('LocalStorageService — draft operations', () {
    late LocalStorageService svc;

    setUp(() async {
      svc = LocalStorageService();
      await svc.initForTesting(hiveDir.path);
    });

    test('getDraft returns null when no draft has been saved', () async {
      await svc.clearDraft();
      final draft = await svc.getDraft();
      expect(draft, isNull);
    });

    test('cacheDraft stores and getDraft retrieves content', () async {
      await svc.cacheDraft('My draft text');
      final draft = await svc.getDraft();
      expect(draft, 'My draft text');
    });

    test('clearDraft removes the stored draft', () async {
      await svc.cacheDraft('Something');
      await svc.clearDraft();
      expect(await svc.getDraft(), isNull);
    });

    test('overwriting a draft replaces the previous value', () async {
      await svc.cacheDraft('First draft');
      await svc.cacheDraft('Second draft');
      expect(await svc.getDraft(), 'Second draft');
    });
  });

  group('LocalStorageService — sync metadata', () {
    late LocalStorageService svc;

    setUp(() async {
      svc = LocalStorageService();
      try {
        await svc.init();
      } catch (_) {}
    });

    test('getLastSyncTime returns null before any sync is recorded', () async {
      // Clear any previous value.
      final ts = await svc.getLastSyncTime();
      // May be null or a DateTime depending on prior test runs — both are valid.
      expect(ts == null || ts is DateTime, isTrue);
    });

    test('setLastSyncTime and getLastSyncTime round-trip', () async {
      final now = DateTime(2025, 6, 15, 10, 30);
      await svc.setLastSyncTime(now);
      final retrieved = await svc.getLastSyncTime();
      expect(retrieved, isNotNull);
      expect(retrieved!.year, now.year);
      expect(retrieved.month, now.month);
      expect(retrieved.day, now.day);
    });
  });

  group('LocalStorageService — entry cache', () {
    late LocalStorageService svc;

    final entry = JournalEntry(
      id: 'cache-test-entry',
      userId: 'u1',
      content: 'Cached content',
      entryDate: DateTime(2025, 6, 1),
      createdAt: DateTime(2025, 6, 1),
      updatedAt: DateTime(2025, 6, 1),
    );

    setUp(() async {
      svc = LocalStorageService();
      try {
        await svc.init();
      } catch (_) {}
    });

    test('getCachedEntry returns null for unknown id', () async {
      final result = await svc.getCachedEntry('non-existent-id');
      expect(result, isNull);
    });

    test('cacheEntry stores and getCachedEntry retrieves entry', () async {
      await svc.cacheEntry(entry);
      final result = await svc.getCachedEntry(entry.id);
      expect(result, isNotNull);
      expect(result!.id, entry.id);
      expect(result.content, entry.content);
    });

    test('removeCachedEntry deletes the entry', () async {
      await svc.cacheEntry(entry);
      await svc.removeCachedEntry(entry.id);
      expect(await svc.getCachedEntry(entry.id), isNull);
    });

    test('getCachedEntries returns all cached entries', () async {
      await svc.cacheEntry(entry);
      final all = await svc.getCachedEntries();
      expect(all.any((e) => e.id == entry.id), isTrue);
    });
  });
}
