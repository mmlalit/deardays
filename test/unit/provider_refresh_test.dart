library;

/// Test C — Provider-level tests for refresh behavior.
///
/// Verifies that:
/// - timelineEntriesProvider can be invalidated and re-emits
/// - todayEntryProvider can be invalidated and re-emits
/// - PostSaveData provider clears correctly
/// - Provider overrides work as expected
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/presentation/screens/post_save_screen.dart';

import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestEnv();

  final now = DateTime.now();

  JournalEntry makeEntry(String id, {String content = 'Test'}) {
    return JournalEntry(
      id: id,
      userId: 'test-user',
      content: content,
      entryDate: now,
      wordCount: 1,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ---------------------------------------------------------------------------
  // C1. timelineEntriesProvider refresh behavior
  // ---------------------------------------------------------------------------

  group('timelineEntriesProvider refresh', () {
    test('emits entries from override', () async {
      final entries = [makeEntry('e1'), makeEntry('e2')];
      final container = ProviderContainer(
        overrides: [
          timelineEntriesProvider.overrideWith((ref) => Stream.value(entries)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(timelineEntriesProvider.future);
      expect(result, hasLength(2));
      expect(result.first.id, 'e1');
    });

    test('emits empty list when no entries', () async {
      final container = ProviderContainer(
        overrides: [
          timelineEntriesProvider.overrideWith((ref) => Stream.value(<JournalEntry>[])),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(timelineEntriesProvider.future);
      expect(result, isEmpty);
    });

    test('invalidation triggers re-read', () async {
      var callCount = 0;
      final container = ProviderContainer(
        overrides: [
          timelineEntriesProvider.overrideWith((ref) {
            callCount++;
            return Stream.value([makeEntry('e-$callCount')]);
          }),
        ],
      );
      addTearDown(container.dispose);

      final result1 = await container.read(timelineEntriesProvider.future);
      expect(result1.first.id, 'e-1');

      container.invalidate(timelineEntriesProvider);

      final result2 = await container.read(timelineEntriesProvider.future);
      expect(result2.first.id, 'e-2');
      expect(callCount, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // C2. todayEntryProvider refresh behavior
  // ---------------------------------------------------------------------------

  group('todayEntryProvider refresh', () {
    test('emits null when no entry today', () async {
      final container = ProviderContainer(
        overrides: [
          todayEntryProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(todayEntryProvider.future);
      expect(result, isNull);
    });

    test('emits entry when override provides one', () async {
      final entry = makeEntry('today-1');
      final container = ProviderContainer(
        overrides: [
          todayEntryProvider.overrideWith((ref) => Stream.value(entry)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(todayEntryProvider.future);
      expect(result, isNotNull);
      expect(result!.id, 'today-1');
    });

    test('invalidation triggers re-read', () async {
      var callCount = 0;
      final container = ProviderContainer(
        overrides: [
          todayEntryProvider.overrideWith((ref) {
            callCount++;
            return Stream.value(
              callCount == 1 ? null : makeEntry('new-entry'),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final result1 = await container.read(todayEntryProvider.future);
      expect(result1, isNull);

      container.invalidate(todayEntryProvider);

      final result2 = await container.read(todayEntryProvider.future);
      expect(result2, isNotNull);
      expect(result2!.id, 'new-entry');
    });
  });

  // ---------------------------------------------------------------------------
  // C3. PostSaveData provider lifecycle
  // ---------------------------------------------------------------------------

  group('PostSaveData provider', () {
    test('starts as null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = container.read(postSaveDataProvider);
      expect(result, isNull);
    });

    test('can be set and read', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(postSaveDataProvider.notifier).state = const PostSaveData(
        entryId: 'e1',
        title: 'Test Title',
        content: 'Test content',
      );

      final result = container.read(postSaveDataProvider);
      expect(result, isNotNull);
      expect(result!.entryId, 'e1');
      expect(result.title, 'Test Title');
    });

    test('clearing sets back to null (simulates _finish())', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(postSaveDataProvider.notifier).state = const PostSaveData(
        entryId: 'e1',
        title: 'Test',
        content: 'Content',
      );
      expect(container.read(postSaveDataProvider), isNotNull);

      // This is what _finish() does
      container.read(postSaveDataProvider.notifier).state = null;
      expect(container.read(postSaveDataProvider), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // C4. authenticatedOverrides provide correct data shape
  // ---------------------------------------------------------------------------

  group('authenticatedOverrides correctness', () {
    test('default overrides provide empty entries', () async {
      final overrides = authenticatedOverrides();
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      final entries = await container.read(timelineEntriesProvider.future);
      expect(entries, isEmpty);
    });

    test('overrides with entries provide those entries', () async {
      final entries = [makeEntry('e1'), makeEntry('e2'), makeEntry('e3')];
      final overrides = authenticatedOverrides(entries: entries);
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      final result = await container.read(timelineEntriesProvider.future);
      expect(result, hasLength(3));
    });

    test('overrides provide mock profile by default', () async {
      final overrides = authenticatedOverrides();
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      final profile = await container.read(profileProvider.future);
      expect(profile, isNotNull);
      expect(profile!.displayName, 'Test User');
    });

    test('overrides provide mock streak by default', () async {
      final overrides = authenticatedOverrides();
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      final streak = await container.read(streakProvider.future);
      expect(streak, isNotNull);
      expect(streak!.currentStreak, 3);
    });

    test('custom entries appear in both timeline and on-this-day providers', () async {
      final entries = [makeEntry('e1')];
      final overrides = authenticatedOverrides(entries: entries);
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      final timeline = await container.read(timelineEntriesProvider.future);
      final onThisDay = await container.read(onThisDayProvider.future);

      expect(timeline, hasLength(1));
      expect(onThisDay, hasLength(1));
    });
  });
}
