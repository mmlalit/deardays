import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/draft_entry.dart';
import 'package:deardays/services/crash_reporting/crash_reporting_service.dart';

/// Local-first encrypted storage backed by Hive.
///
/// Journal entry content stored here is already encrypted at the application
/// layer — this service simply persists the encrypted payloads for offline
/// access and draft management.
class LocalStorageService {
  LocalStorageService._internal();

  static final LocalStorageService _instance = LocalStorageService._internal();

  /// Singleton accessor.
  static LocalStorageService get instance => _instance;

  factory LocalStorageService() => _instance;

  static const String _entriesBoxName = 'entries';
  static const String _draftsBoxName = 'drafts';
  static const String _syncMetaBoxName = 'sync_meta';

  static const String _hiveKeyAlias = 'deardays_hive_encryption_key';
  static const String _lastSyncKey = 'last_sync_time';

  Box<String>? _entriesBox;
  Box<String>? _draftsBox;
  Box<String>? _syncMetaBox;

  bool _initialized = false;

  /// The Hive encryption cipher, available after [init] completes.
  /// Other services that open their own Hive boxes should use this cipher
  /// so all local data is encrypted at rest.
  HiveAesCipher? _cipher;

  /// Returns the Hive encryption cipher for use by other services.
  /// Throws [StateError] if [init] has not been called.
  HiveAesCipher get cipher {
    if (_cipher == null) {
      throw StateError(
        'LocalStorageService has not been initialized. Call init() first.',
      );
    }
    return _cipher!;
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initializes Hive with the app directory and opens encrypted boxes.
  ///
  /// The Hive encryption key is generated once and persisted in
  /// `flutter_secure_storage` so it survives app restarts but is protected by
  /// the OS keychain (iOS Keychain / Android Keystore).
  ///
  /// Security note: On jailbroken/rooted devices, the OS keychain may be
  /// compromised, which would expose the Hive encryption key. This is a
  /// defense-in-depth layer only — the primary protection for sensitive
  /// content is E2E encryption (AES-256-GCM) with a user-derived key that
  /// is never persisted.
  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    final encryptionKey = await _getOrCreateEncryptionKey();
    _cipher = HiveAesCipher(encryptionKey);
    final cipher = _cipher!;

    _entriesBox = await _openBoxSafe<String>(_entriesBoxName, cipher);
    _draftsBox = await _openBoxSafe<String>(_draftsBoxName, cipher);
    _syncMetaBox = await _openBoxSafe<String>(_syncMetaBoxName, cipher);

    _initialized = true;
    if (kDebugMode) {
      debugPrint('[LocalStorageService] Initialized with encrypted boxes.');
    }
  }

  /// Opens a Hive box, recovering from corruption by deleting and recreating.
  /// On mobile, crashes during writes or full storage can corrupt a box file.
  /// Logs to Sentry when corruption is detected so we can monitor frequency.
  Future<Box<T>> _openBoxSafe<T>(String name, HiveAesCipher cipher) async {
    try {
      return await Hive.openBox<T>(name, encryptionCipher: cipher);
    } catch (e, st) {
      debugPrint('[LocalStorageService] Box "$name" corrupted, recreating: $e');
      try {
        CrashReportingService().recordError(
          e, st,
          reason: 'hive_box_corrupted_$name',
        );
      } catch (_) {}
      await Hive.deleteBoxFromDisk(name);
      return await Hive.openBox<T>(name, encryptionCipher: cipher);
    }
  }

  /// Initializes the service for unit tests using plain (unencrypted) Hive
  /// boxes in the given [hiveDir]. Does NOT use flutter_secure_storage.
  ///
  /// Call this instead of [init] in test `setUp` blocks.
  @visibleForTesting
  Future<void> initForTesting(String hiveDir) async {
    if (_initialized) {
      await Hive.close();
      _initialized = false;
    }
    Hive.init(hiveDir);
    // Delete boxes from disk so each test starts with clean state.
    await Hive.deleteBoxFromDisk(_entriesBoxName);
    await Hive.deleteBoxFromDisk(_draftsBoxName);
    await Hive.deleteBoxFromDisk(_syncMetaBoxName);
    _entriesBox  = await Hive.openBox<String>(_entriesBoxName);
    _draftsBox   = await Hive.openBox<String>(_draftsBoxName);
    _syncMetaBox = await Hive.openBox<String>(_syncMetaBoxName);
    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Journal entry cache
  // ---------------------------------------------------------------------------

  /// Stores a [JournalEntry] locally. The entry's content is assumed to
  /// already be encrypted at the application layer.
  Future<void> cacheEntry(JournalEntry entry) async {
    _ensureInitialized();
    // Identity function: content is already encrypted at app layer
    final json = jsonEncode(entry.toJson());
    await _entriesBox!.put(entry.id, json);
  }

  /// Retrieves a cached [JournalEntry] by its [id], or `null` if not found.
  Future<JournalEntry?> getCachedEntry(String id) async {
    _ensureInitialized();
    final json = _entriesBox!.get(id);
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return JournalEntry.fromJson(map);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocalStorageService] Failed to decode entry $id: $e');
      }
      return null;
    }
  }

  /// Returns all locally cached journal entries.
  /// Corrupt entries are logged and skipped (not deleted — allows manual recovery).
  Future<List<JournalEntry>> getCachedEntries() async {
    _ensureInitialized();
    final entries = <JournalEntry>[];
    var corruptCount = 0;
    for (final json in _entriesBox!.values) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        entries.add(JournalEntry.fromJson(map));
      } catch (e) {
        corruptCount++;
        if (kDebugMode) {
          debugPrint('[LocalStorageService] Skipping corrupt entry: $e');
        }
      }
    }
    if (corruptCount > 0) {
      debugPrint('[LocalStorageService] $corruptCount corrupt entries skipped');
    }
    return entries;
  }

  /// Removes a cached entry by [id].
  Future<void> removeCachedEntry(String id) async {
    _ensureInitialized();
    await _entriesBox!.delete(id);
  }

  // ---------------------------------------------------------------------------
  // Draft management
  // ---------------------------------------------------------------------------

  /// Upserts a draft (keyed by [draft.id]).
  Future<void> saveDraft(DraftEntry draft) async {
    _ensureInitialized();
    await _draftsBox!.put(draft.id, draft.toJsonString());
  }

  /// Returns all drafts sorted newest-first.
  Future<List<DraftEntry>> getDrafts() async {
    _ensureInitialized();
    final drafts = <DraftEntry>[];
    for (final raw in _draftsBox!.values) {
      try {
        drafts.add(DraftEntry.fromJsonString(raw));
      } catch (e) {
        if (kDebugMode) debugPrint('[LocalStorageService] Corrupt draft: $e');
      }
    }
    drafts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return drafts;
  }

  /// Deletes a single draft by [id].
  Future<void> deleteDraft(String id) async {
    _ensureInitialized();
    await _draftsBox!.delete(id);
  }

  // ---------------------------------------------------------------------------
  // Today's mood
  // ---------------------------------------------------------------------------

  /// Saves the mood selected today. Keyed by date so it auto-resets on a new day.
  Future<void> saveTodayMood(String mood) async {
    _ensureInitialized();
    final key = 'mood_${DateTime.now().toIso8601String().substring(0, 10)}';
    await _syncMetaBox!.put(key, mood);
  }

  /// Returns today's saved mood, or `null` if none was saved today.
  Future<String?> getTodayMood() async {
    _ensureInitialized();
    final key = 'mood_${DateTime.now().toIso8601String().substring(0, 10)}';
    return _syncMetaBox!.get(key);
  }

  // ---------------------------------------------------------------------------
  // Sync metadata
  // ---------------------------------------------------------------------------

  /// Persists the last successful sync timestamp.
  Future<void> setLastSyncTime(DateTime time) async {
    _ensureInitialized();
    await _syncMetaBox!.put(_lastSyncKey, time.toIso8601String());
  }

  /// Returns the last successful sync timestamp, or `null` if the app has
  /// never synced.
  Future<DateTime?> getLastSyncTime() async {
    _ensureInitialized();
    final value = _syncMetaBox!.get(_lastSyncKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Wipes all local data. Call on user logout.
  Future<void> clearAll() async {
    _ensureInitialized();
    await _entriesBox!.clear();
    await _draftsBox!.clear();
    await _syncMetaBox!.clear();
    if (kDebugMode) {
      debugPrint('[LocalStorageService] All local data cleared.');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'LocalStorageService has not been initialized. Call init() first.',
      );
    }
  }

  /// Retrieves the Hive encryption key from secure storage, or generates and
  /// stores a new one if this is the first launch.
  Future<List<int>> _getOrCreateEncryptionKey() async {
    const secureStorage = FlutterSecureStorage();

    try {
      final existing = await secureStorage.read(key: _hiveKeyAlias);
      if (existing != null) {
        return base64Url.decode(existing);
      }
    } catch (e) {
      // BadPaddingException: Android keystore key changed (e.g. debug vs release
      // signing, or app reinstall with different certificate). Delete the corrupt
      // entry and generate a fresh key. Local cached data will be lost but the
      // app won't hang on startup.
      debugPrint('[LocalStorageService] SecureStorage read failed ($e) — resetting key');
      try {
        await secureStorage.delete(key: _hiveKeyAlias);
      } catch (_) {}
      // Also delete existing Hive boxes since they were encrypted with the old key
      try {
        await Hive.deleteBoxFromDisk(_entriesBoxName);
        await Hive.deleteBoxFromDisk(_draftsBoxName);
        await Hive.deleteBoxFromDisk(_syncMetaBoxName);
      } catch (_) {}
    }

    final key = Hive.generateSecureKey();
    await secureStorage.write(
      key: _hiveKeyAlias,
      value: base64UrlEncode(key),
    );
    return key;
  }
}
