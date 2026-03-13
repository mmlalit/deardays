import 'package:flutter/foundation.dart';

import 'package:deardays/features/journal/data/repositories/journal_repository.dart';
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

  bool _initialized = false;
  BackupStatus _status = BackupStatus.idle;
  BackupStatus get status => _status;

  DateTime? _lastBackupTime;
  DateTime? get lastBackupTime => _lastBackupTime;

  int _backedUpCount = 0;
  int get backedUpCount => _backedUpCount;

  /// Initializes the backup service.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('[BackupService] Initialized.');
  }

  /// Performs a full cloud backup of all journal entries.
  ///
  /// Returns the number of entries backed up.
  Future<int> performBackup({
    required JournalRepository repository,
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
        debugPrint('[BackupService] No entries to backup.');
        return 0;
      }

      // Sync each cached entry to the cloud
      int synced = 0;
      for (final entry in cachedEntries) {
        try {
          final existing = await repository.getEntry(entry.id);
          if (existing == null) {
            await repository.createEntry(entry);
          } else if (entry.updatedAt.isAfter(existing.updatedAt)) {
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
    required JournalRepository repository,
    required LocalStorageService localStorage,
  }) async {
    if (_status == BackupStatus.inProgress) {
      throw BackupException('Operation already in progress');
    }

    _status = BackupStatus.inProgress;
    debugPrint('[BackupService] Starting restore...');

    try {
      // Fetch all entries from cloud
      final cloudEntries = await repository.getEntries(limit: 1000);

      if (cloudEntries.isEmpty) {
        _status = BackupStatus.completed;
        debugPrint('[BackupService] No entries to restore.');
        return 0;
      }

      // Cache each entry locally
      int restored = 0;
      for (final entry in cloudEntries) {
        try {
          await localStorage.cacheEntry(entry);
          restored++;
        } catch (e) {
          debugPrint(
              '[BackupService] Failed to cache entry ${entry.id}: $e');
        }
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
