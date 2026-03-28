import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:deardays/features/journal/data/models/draft_entry.dart';
import 'package:deardays/features/journal/data/repositories/draft_repository.dart';
import 'package:deardays/services/storage/local_storage_service.dart';

/// Local-first draft sync: writes to Hive immediately, then fires-and-forgets
/// the Supabase upsert so drafts survive reinstalls and sync across devices.
class DraftSyncService {
  final LocalStorageService _local;
  final DraftRepository _remote;

  DraftSyncService({
    required LocalStorageService local,
    required DraftRepository remote,
  })  : _local = local,
        _remote = remote;

  /// Save locally, then fire-and-forget sync to Supabase.
  Future<void> saveDraft(DraftEntry draft) async {
    await _local.saveDraft(draft);
    unawaited(_remote.upsertDraft(draft).catchError((e) {
      debugPrint('[DraftSync] Remote upsert failed: $e');
    }));
  }

  /// Delete locally, then fire-and-forget delete from Supabase.
  Future<void> deleteDraft(String id) async {
    await _local.deleteDraft(id);
    unawaited(_remote.deleteDraft(id).catchError((e) {
      debugPrint('[DraftSync] Remote delete failed: $e');
    }));
  }

  /// Read drafts — local is always the source of truth for reads.
  Future<List<DraftEntry>> getDrafts() => _local.getDrafts();

  /// Pull remote drafts on login and merge with local (last-write-wins).
  Future<void> pullRemoteDrafts() async {
    try {
      final remoteDrafts = await _remote.getRemoteDrafts();
      if (remoteDrafts.isEmpty) return;

      final localDrafts = await _local.getDrafts();
      final localMap = {for (final d in localDrafts) d.id: d};

      for (final remote in remoteDrafts) {
        final local = localMap[remote.id];
        if (local == null || remote.savedAt.isAfter(local.savedAt)) {
          await _local.saveDraft(remote);
        }
      }
      debugPrint('[DraftSync] Pulled ${remoteDrafts.length} remote drafts');
    } catch (e) {
      debugPrint('[DraftSync] pullRemoteDrafts failed: $e');
    }
  }
}
