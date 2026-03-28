import 'package:hive_flutter/hive_flutter.dart';
import 'package:deardays/services/storage/local_storage_service.dart';

/// Persists user-chosen "featured memory" overrides for reflection cards.
///
/// Keys follow the pattern:
///   monthly week card  → "m_{year}_{month:02}_w{weekOfMonth}"
///                         e.g. "m_2026_03_w2"
///   yearly month tile  → "y_{year}_m{month:02}"
///                         e.g. "y_2026_m03"
///
/// Values are entry IDs (UUID strings).
///
/// Uses the same Hive encryption cipher as [LocalStorageService] so
/// overrides are encrypted at rest alongside the rest of local data.
class ReflectionOverrideRepository {
  ReflectionOverrideRepository._internal();
  static final ReflectionOverrideRepository _instance =
      ReflectionOverrideRepository._internal();
  factory ReflectionOverrideRepository() => _instance;

  static const _boxName = 'reflection_overrides';
  Box<String>? _box;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(
      _boxName,
      encryptionCipher: LocalStorageService().cipher,
    );
  }

  Box<String> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('ReflectionOverrideRepository not initialized. Call init() first.');
    }
    return _box!;
  }

  // ── Key builders ───────────────────────────────────────────────────────────

  static String monthlyKey(int year, int month, int weekOfMonth) =>
      'm_${year}_${month.toString().padLeft(2, '0')}_w$weekOfMonth';

  static String yearlyKey(int year, int month) =>
      'y_${year}_m${month.toString().padLeft(2, '0')}';

  // ── Read / write ───────────────────────────────────────────────────────────

  /// Returns the overridden entry ID for [key], or null if no override set.
  String? get(String key) => _safeBox.get(key);

  /// Saves [entryId] as the override for [key].
  Future<void> set(String key, String entryId) =>
      _safeBox.put(key, entryId);

  /// Removes the override for [key] (reverts to algorithmic selection).
  Future<void> clear(String key) => _safeBox.delete(key);
}
