import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/draft_entry.dart';

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
  /// the OS keychain.
  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    final encryptionKey = await _getOrCreateEncryptionKey();
    _cipher = HiveAesCipher(encryptionKey);
    final cipher = _cipher!;

    _entriesBox = await Hive.openBox<String>(
      _entriesBoxName,
      encryptionCipher: cipher,
    );
    _draftsBox = await Hive.openBox<String>(
      _draftsBoxName,
      encryptionCipher: cipher,
    );
    _syncMetaBox = await Hive.openBox<String>(
      _syncMetaBoxName,
      encryptionCipher: cipher,
    );

    _initialized = true;
    if (kDebugMode) {
      debugPrint('[LocalStorageService] Initialized with encrypted boxes.');
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
  Future<List<JournalEntry>> getCachedEntries() async {
    _ensureInitialized();
    final entries = <JournalEntry>[];
    for (final json in _entriesBox!.values) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        entries.add(JournalEntry.fromJson(map));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[LocalStorageService] Skipping corrupt entry: $e');
        }
      }
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
    final existing = await secureStorage.read(key: _hiveKeyAlias);

    if (existing != null) {
      return base64Url.decode(existing);
    }

    final key = Hive.generateSecureKey();
    await secureStorage.write(
      key: _hiveKeyAlias,
      value: base64UrlEncode(key),
    );
    return key;
  }
}
