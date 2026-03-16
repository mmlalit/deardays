import 'package:hive_flutter/hive_flutter.dart';

import 'package:deardays/features/story/data/models/story_node.dart';
import 'package:deardays/services/storage/local_storage_service.dart';

/// Persists [StoryNode] objects in a Hive box.
///
/// Box name: `'story_nodes'`
/// Keys follow StoryNode.weekKey / monthKey / yearKey / lifetimeKey conventions.
class StoryNodeRepository {
  static const _boxName = 'story_nodes';

  static Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }
    try {
      final cipher = LocalStorageService.instance.cipher;
      return await Hive.openBox<String>(_boxName, encryptionCipher: cipher);
    } catch (_) {
      return await Hive.openBox<String>(_boxName);
    }
  }

  /// Returns the stored node for [key], or null if not found.
  Future<StoryNode?> get(String key) async {
    final box = await _openBox();
    final raw = box.get(key);
    if (raw == null) return null;
    try {
      return StoryNode.fromHive(raw);
    } catch (_) {
      return null;
    }
  }

  /// Persists [node] using [node.id] as the key.
  Future<void> save(StoryNode node) async {
    final box = await _openBox();
    await box.put(node.id, node.toHive());
  }

  /// Returns all stored nodes of [level], sorted by periodStart ascending.
  Future<List<StoryNode>> getAll(StoryLevelType level) async {
    final box = await _openBox();
    final nodes = <StoryNode>[];
    for (final key in box.keys.cast<String>()) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        final node = StoryNode.fromHive(raw);
        if (node.level == level) nodes.add(node);
      } catch (_) {}
    }
    nodes.sort((a, b) => a.periodStart.compareTo(b.periodStart));
    return nodes;
  }

  /// Clears [node.generatedStory] and [node.generatedAt], forcing regeneration.
  Future<StoryNode> invalidate(String key) async {
    final node = await get(key);
    if (node == null) return Future.error('Node $key not found');
    final cleared = node.cleared();
    await save(cleared);
    return cleared;
  }

  /// Deletes a node entirely.
  Future<void> delete(String key) async {
    final box = await _openBox();
    await box.delete(key);
  }

  /// Returns all node keys of any level.
  Future<List<String>> allKeys() async {
    final box = await _openBox();
    return box.keys.cast<String>().toList();
  }
}
