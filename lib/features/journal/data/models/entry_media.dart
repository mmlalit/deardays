class EntryMedia {
  final String id;
  final String entryId;
  final String userId;
  final String mediaType; // photo, voice
  final String storagePath;
  final String? encryptedMetadata;
  final int sortOrder;
  final DateTime createdAt;

  const EntryMedia({
    required this.id,
    required this.entryId,
    required this.userId,
    required this.mediaType,
    required this.storagePath,
    this.encryptedMetadata,
    this.sortOrder = 0,
    required this.createdAt,
  });

  EntryMedia copyWith({
    String? id,
    String? entryId,
    String? userId,
    String? mediaType,
    String? storagePath,
    String? encryptedMetadata,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return EntryMedia(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      userId: userId ?? this.userId,
      mediaType: mediaType ?? this.mediaType,
      storagePath: storagePath ?? this.storagePath,
      encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entry_id': entryId,
      'user_id': userId,
      'media_type': mediaType,
      'storage_path': storagePath,
      'encrypted_metadata': encryptedMetadata,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory EntryMedia.fromMap(Map<String, dynamic> map) {
    return EntryMedia(
      id: map['id'] as String,
      entryId: map['entry_id'] as String,
      userId: map['user_id'] as String,
      mediaType: map['media_type'] as String,
      storagePath: map['storage_path'] as String,
      encryptedMetadata: map['encrypted_metadata'] as String?,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  String toString() {
    return 'EntryMedia(id: $id, entryId: $entryId, mediaType: $mediaType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EntryMedia && other.id == id && other.storagePath == storagePath;
  }

  @override
  int get hashCode => id.hashCode;
}
