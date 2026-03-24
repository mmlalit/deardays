// Model: MemoryShare + SharedMemoryItem
// Represents one share token and its lifecycle.

import 'package:flutter/foundation.dart';

enum ShareStatus {
  pending,
  approved,
  denied,
  revoked,
  expired;

  static ShareStatus fromString(String s) => ShareStatus.values.firstWhere(
        (e) => e.name == s,
        orElse: () {
          debugPrint('[MemoryShare] Unknown share status: "$s" — defaulting to pending');
          return ShareStatus.pending;
        },
      );
}

class MemoryShare {
  final String id;
  final String token;
  final String memoryId;
  final String sharerId;
  final String? recipientId;
  final String? recipientName;
  final String? memoryTitle;
  final ShareStatus status;
  final DateTime createdAt;
  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final DateTime? revokedAt;
  final DateTime expiresAt;
  final int viewCount;
  final DateTime? lastViewedAt;

  const MemoryShare({
    required this.id,
    required this.token,
    required this.memoryId,
    required this.sharerId,
    this.recipientId,
    this.recipientName,
    this.memoryTitle,
    required this.status,
    required this.createdAt,
    this.requestedAt,
    this.approvedAt,
    this.revokedAt,
    required this.expiresAt,
    this.viewCount = 0,
    this.lastViewedAt,
  });

  bool get isActive    => status == ShareStatus.approved;
  bool get isPending   => status == ShareStatus.pending && recipientName != null;
  bool get isUnclaimed => status == ShareStatus.pending && recipientName == null;

  factory MemoryShare.fromMap(Map<String, dynamic> map) => MemoryShare(
        id:            map['id']            as String,
        token:         map['token']         as String,
        memoryId:      map['memory_id']     as String,
        sharerId:      map['sharer_id']     as String,
        recipientId:   map['recipient_id']  as String?,
        recipientName: map['recipient_name'] as String?,
        memoryTitle:   map['memory_title']  as String?,
        status:        ShareStatus.fromString(map['status'] as String),
        createdAt:     DateTime.parse(map['created_at'] as String),
        requestedAt:   _parseDate(map['requested_at']),
        approvedAt:    _parseDate(map['approved_at']),
        revokedAt:     _parseDate(map['revoked_at']),
        expiresAt:     DateTime.parse(map['expires_at'] as String),
        viewCount:     (map['view_count'] as int?) ?? 0,
        lastViewedAt:  _parseDate(map['last_viewed_at']),
      );

  static DateTime? _parseDate(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
}

// ─────────────────────────────────────────────────────────────────────────────
// SharedMemoryItem — used by "Shared with me" screen
// Combines share metadata + memory details + sharer name
// ─────────────────────────────────────────────────────────────────────────────

class SharedMemoryItem {
  final MemoryShare share;
  final String memoryTitle;
  final String memoryExcerpt;
  final String? memoryMood;
  final DateTime memoryDate;
  final String? sharerName;

  const SharedMemoryItem({
    required this.share,
    required this.memoryTitle,
    required this.memoryExcerpt,
    required this.memoryDate,
    this.memoryMood,
    this.sharerName,
  });

  factory SharedMemoryItem.fromMap(Map<String, dynamic> map) {
    final entry = map['journal_entries'] as Map<String, dynamic>? ?? {};
    final profile = map['profiles'] as Map<String, dynamic>? ?? {};
    final rawContent = (entry['polished_content'] as String?)
        ?? (entry['content'] as String?)
        ?? '';
    return SharedMemoryItem(
      share:         MemoryShare.fromMap(map),
      memoryTitle:   (entry['title'] as String?) ?? 'Untitled Memory',
      memoryExcerpt: rawContent.length > 120
          ? '${rawContent.substring(0, 120)}…'
          : rawContent,
      memoryDate:    entry['entry_date'] != null
          ? DateTime.parse(entry['entry_date'] as String)
          : DateTime.now(),
      memoryMood:    entry['mood'] as String?,
      sharerName:    profile['display_name'] as String?,
    );
  }
}
