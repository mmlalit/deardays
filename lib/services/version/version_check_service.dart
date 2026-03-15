import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Checks whether the running app version meets the minimum required version
/// stored in `remote_config`. When `needsUpdate` is true, the UI should show
/// a force-update dialog.
///
/// Version format: semver `major.minor.patch` (e.g. `1.2.3`).
class VersionCheckService {
  VersionCheckService._internal();

  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;

  /// Current app version — sourced from pubspec.yaml at compile time.
  static const String currentVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  String? _minVersion;
  bool _checked = false;

  /// Whether the app needs to be updated.
  bool get needsUpdate {
    if (_minVersion == null) return false;
    return _compareSemver(currentVersion, _minVersion!) < 0;
  }

  /// The minimum version required by the server, or null if not yet checked.
  String? get minVersion => _minVersion;

  /// Fetch the minimum required version from remote_config.
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> check() async {
    if (_checked) return;
    _checked = true;

    try {
      final result = await Supabase.instance.client
          .from('remote_config')
          .select('value')
          .eq('key', 'min_app_version')
          .eq('platform', 'flutter')
          .maybeSingle();

      if (result != null) {
        _minVersion = result['value'] as String?;
      }

      if (kDebugMode) {
        debugPrint(
          '[VersionCheck] current=$currentVersion min=$_minVersion needsUpdate=$needsUpdate',
        );
      }
    } catch (e) {
      // Non-fatal — if the check fails, allow the user to continue.
      if (kDebugMode) {
        debugPrint('[VersionCheck] Failed: $e');
      }
    }
  }

  /// Reset for re-checking (e.g. after app resume).
  void reset() {
    _checked = false;
    _minVersion = null;
  }

  /// Compare two semver strings. Returns negative if [a] < [b].
  static int _compareSemver(String a, String b) {
    final partsA = a.split('.').map(int.tryParse).toList();
    final partsB = b.split('.').map(int.tryParse).toList();

    for (var i = 0; i < 3; i++) {
      final va = (i < partsA.length ? partsA[i] : null) ?? 0;
      final vb = (i < partsB.length ? partsB[i] : null) ?? 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }
}
