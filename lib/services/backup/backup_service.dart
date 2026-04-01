import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:deardays/core/domain/repositories/journal_repository_interface.dart';
import 'package:deardays/services/storage/local_storage_service.dart';

/// Backup and restore service for cloud-based journal data protection.
///
/// Handles:
/// - Full cloud backup of journal entries + metadata
/// - Restore from cloud on new device login
/// - Backup status tracking
/// - Incremental sync (only new/changed entries)
class BackupService {
  BackupService._internal();

  static final BackupService _instance = BackupService._internal();

  static BackupService get instance => _instance;

  factory BackupService() => _instance;

  static const String _boxName = 'backup_info';
  static const String _lastBackupKey = 'last_backup_time';
  static const String _backedUpCountKey = 'backed_up_count';

  bool _initialized = false;
  BackupStatus _status = BackupStatus.idle;
  BackupStatus get status => _status;

  DateTime? _lastBackupTime;
  DateTime? get lastBackupTime => _lastBackupTime;

  int _backedUpCount = 0;
  int get backedUpCount => _backedUpCount;

  /// Initializes the backup service and loads persisted metadata.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final box = await Hive.openBox<String>(_boxName);
      final savedTime = box.get(_lastBackupKey);
      if (savedTime != null) {
        _lastBackupTime = DateTime.tryParse(savedTime);
      }
      final savedCount = box.get(_backedUpCountKey);
      if (savedCount != null) {
        _backedUpCount = int.tryParse(savedCount) ?? 0;
      }
    } catch (e) {
      debugPrint('[BackupService] Failed to load backup metadata: $e');
    }
    _initialized = true;
    debugPrint('[BackupService] Initialized. Last backup: $_lastBackupTime, count: $_backedUpCount');
  }

  /// Persists backup metadata to Hive so it survives app restarts.
  Future<void> _persistMetadata() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      if (_lastBackupTime != null) {
        await box.put(_lastBackupKey, _lastBackupTime!.toIso8601String());
      }
      await box.put(_backedUpCountKey, _backedUpCount.toString());
    } catch (e) {
      debugPrint('[BackupService] Failed to persist backup metadata: $e');
    }
  }

  /// Performs a full cloud backup of all journal entries.
  ///
  /// Returns the number of entries backed up.
  Future<int> performBackup({
    required IJournalRepository repository,
    required LocalStorageService localStorage,
  }) async {
    if (_status == BackupStatus.inProgress) {
      throw BackupException('Backup already in progress');
    }

    _status = BackupStatus.inProgress;
    debugPrint('[BackupService] Starting backup...');

    try {
      // Get all local cached entries
      final cachedEntries = await localStorage.getCachedEntries();

      if (cachedEntries.isEmpty) {
        _status = BackupStatus.completed;
        _lastBackupTime = DateTime.now();
        await _persistMetadata();
        debugPrint('[BackupService] No entries to backup.');
        return 0;
      }

      // Batch-fetch existing cloud entries to avoid N+1 sequential queries.
      // Process in pages of 500 to avoid oversized payloads.
      final cloudMap = <String, DateTime>{};
      const pageSize = 500;
      for (var offset = 0; offset < cachedEntries.length; offset += pageSize) {
        final pageIds = cachedEntries
            .skip(offset)
            .take(pageSize)
            .map((e) => e.id)
            .toList();
        try {
          final existing = await repository.getEntries(
            limit: pageSize,
            offset: 0,
            ids: pageIds,
          );
          for (final e in existing) {
            cloudMap[e.id] = e.updatedAt;
          }
        } catch (e) {
          debugPrint('[BackupService] Batch fetch failed at offset $offset: $e');
        }
      }

      // Upsert only new or changed entries
      int synced = 0;
      for (final entry in cachedEntries) {
        try {
          final cloudUpdatedAt = cloudMap[entry.id];
          if (cloudUpdatedAt == null) {
            await repository.createEntry(entry);
          } else if (entry.updatedAt.isAfter(cloudUpdatedAt)) {
            await repository.updateEntry(entry);
          }
          synced++;
        } catch (e) {
          debugPrint('[BackupService] Failed to sync entry ${entry.id}: $e');
        }
      }

      _backedUpCount = synced;
      _status = BackupStatus.completed;
      _lastBackupTime = DateTime.now();
      await _persistMetadata();
      debugPrint('[BackupService] Backup completed: $synced entries synced.');
      return synced;
    } catch (e) {
      _status = BackupStatus.failed;
      debugPrint('[BackupService] Backup failed: $e');
      rethrow;
    }
  }

  /// Restores journal entries from the cloud to local storage.
  ///
  /// Returns the number of entries restored.
  Future<int> performRestore({
    required IJournalRepository repository,
    required LocalStorageService localStorage,
  }) async {
    if (_status == BackupStatus.inProgress) {
      throw BackupException('Operation already in progress');
    }

    _status = BackupStatus.inProgress;
    debugPrint('[BackupService] Starting restore...');

    try {
      // Paginated fetch from cloud (500 per page) to avoid OOM on large accounts.
      int restored = 0;
      const pageSize = 500;
      var offset = 0;
      bool hasMore = true;

      while (hasMore) {
        final page = await repository.getEntries(
          limit: pageSize,
          offset: offset,
        );

        if (page.isEmpty) {
          if (restored == 0) {
            _status = BackupStatus.completed;
            debugPrint('[BackupService] No entries to restore.');
            return 0;
          }
          break;
        }

        for (final entry in page) {
          try {
            await localStorage.cacheEntry(entry);
            restored++;
          } catch (e) {
            debugPrint(
                '[BackupService] Failed to cache entry ${entry.id}: $e');
          }
        }

        offset += page.length;
        hasMore = page.length >= pageSize;
      }

      _status = BackupStatus.completed;
      debugPrint('[BackupService] Restore completed: $restored entries.');
      return restored;
    } catch (e) {
      _status = BackupStatus.failed;
      debugPrint('[BackupService] Restore failed: $e');
      rethrow;
    }
  }

  /// Gets backup metadata (last backup time, entry count, etc.).
  BackupInfo getBackupInfo() {
    return BackupInfo(
      lastBackupTime: _lastBackupTime,
      backedUpCount: _backedUpCount,
      status: _status,
    );
  }

  /// Resets backup state.
  void reset() {
    _status = BackupStatus.idle;
    _lastBackupTime = null;
    _backedUpCount = 0;
  }
}

/// Backup operation status.
enum BackupStatus {
  idle,
  inProgress,
  completed,
  failed,
}

/// Backup metadata information.
class BackupInfo {
  final DateTime? lastBackupTime;
  final int backedUpCount;
  final BackupStatus status;

  const BackupInfo({
    this.lastBackupTime,
    this.backedUpCount = 0,
    this.status = BackupStatus.idle,
  });
}

/// Exception thrown by backup/restore operations.
class BackupException implements Exception {
  final String message;
  BackupException(this.message);

  @override
  String toString() => 'BackupException: $message';
}
