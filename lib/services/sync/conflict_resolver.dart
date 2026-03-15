import 'package:flutter/foundation.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// Strategy for resolving sync conflicts when the same entry is edited
/// on multiple devices while offline.
enum ConflictResolution {
  /// Keep the local (current device) version.
  keepLocal,

  /// Keep the remote (server) version.
  keepRemote,

  /// Merge non-conflicting fields automatically.
  autoMerge,
}

/// Result of a conflict check between local and remote versions of an entry.
class ConflictResult {
  final bool hasConflict;
  final ConflictResolution? suggestedResolution;
  final JournalEntry? mergedEntry;
  final String? conflictDescription;

  const ConflictResult({
    required this.hasConflict,
    this.suggestedResolution,
    this.mergedEntry,
    this.conflictDescription,
  });

  const ConflictResult.noConflict()
      : hasConflict = false,
        suggestedResolution = null,
        mergedEntry = null,
        conflictDescription = null;
}

/// Detects and resolves conflicts between local and remote versions of entries.
///
/// Uses `updated_at` timestamps to detect divergence. When both local and remote
/// have been modified since the last sync, a conflict exists.
///
/// Resolution strategy:
/// 1. If only metadata differs (mood, tags) — auto-merge (take most recent of each)
/// 2. If content differs — surface to user for manual resolution
/// 3. If only one side changed — no conflict, take the changed version
class ConflictResolver {
  /// Check if the local entry conflicts with the remote version.
  ///
  /// [local] is the version on this device.
  /// [remote] is the version fetched from the server.
  /// [lastSyncAt] is when this device last successfully synced.
  ConflictResult check({
    required JournalEntry local,
    required JournalEntry remote,
    required DateTime lastSyncAt,
  }) {
    // If timestamps match, no conflict
    if (local.updatedAt == remote.updatedAt) {
      return const ConflictResult.noConflict();
    }

    final localModified = local.updatedAt.isAfter(lastSyncAt);
    final remoteModified = remote.updatedAt.isAfter(lastSyncAt);

    // Only one side changed — no conflict
    if (!localModified) {
      return ConflictResult(
        hasConflict: false,
        suggestedResolution: ConflictResolution.keepRemote,
        mergedEntry: remote,
      );
    }
    if (!remoteModified) {
      return ConflictResult(
        hasConflict: false,
        suggestedResolution: ConflictResolution.keepLocal,
        mergedEntry: local,
      );
    }

    // Both sides changed — check if content actually differs
    if (local.content == remote.content) {
      // Only metadata changed — auto-merge by taking the most recent of each field
      final merged = _autoMerge(local, remote);
      return ConflictResult(
        hasConflict: false,
        suggestedResolution: ConflictResolution.autoMerge,
        mergedEntry: merged,
        conflictDescription: 'Metadata auto-merged (content unchanged)',
      );
    }

    // Content conflict — needs user resolution
    return ConflictResult(
      hasConflict: true,
      suggestedResolution: ConflictResolution.keepLocal,
      conflictDescription:
          'This entry was edited on another device. '
          'Local: ${_truncate(local.content, 50)} | '
          'Remote: ${_truncate(remote.content, 50)}',
    );
  }

  /// Auto-merge metadata fields by taking the most recently updated value.
  JournalEntry _autoMerge(JournalEntry local, JournalEntry remote) {
    final useLocal = local.updatedAt.isAfter(remote.updatedAt);
    return local.copyWith(
      mood: useLocal ? local.mood : (remote.mood ?? local.mood),
      locationName: useLocal ? local.locationName : (remote.locationName ?? local.locationName),
      polishedContent: useLocal ? local.polishedContent : (remote.polishedContent ?? local.polishedContent),
      updatedAt: useLocal ? local.updatedAt : remote.updatedAt,
    );
  }

  /// Resolve a conflict by applying the chosen strategy.
  JournalEntry resolve({
    required JournalEntry local,
    required JournalEntry remote,
    required ConflictResolution resolution,
  }) {
    switch (resolution) {
      case ConflictResolution.keepLocal:
        if (kDebugMode) {
          debugPrint('[ConflictResolver] Resolved: keeping local version of ${local.id}');
        }
        return local.copyWith(updatedAt: DateTime.now());
      case ConflictResolution.keepRemote:
        if (kDebugMode) {
          debugPrint('[ConflictResolver] Resolved: keeping remote version of ${remote.id}');
        }
        return remote;
      case ConflictResolution.autoMerge:
        if (kDebugMode) {
          debugPrint('[ConflictResolver] Resolved: auto-merging ${local.id}');
        }
        return _autoMerge(local, remote);
    }
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
