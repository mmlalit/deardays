import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Monitors network connectivity using platform-native APIs (connectivity_plus)
/// with a fallback reachability check against the app's own Supabase endpoint.
///
/// Previous implementation polled google.com every 30s which:
/// - Fails in China (Google is blocked)
/// - Wastes battery with unnecessary network calls
/// - Could get rate-limited at scale
///
/// New approach:
/// 1. Platform events from connectivity_plus (instant, zero-cost)
/// 2. On state change, verify actual reachability with a DNS lookup
///    against the configured Supabase host (not google.com)
/// 3. Periodic fallback check every 60s (reduced from 30s) as a safety net
class ConnectivityService {
  ConnectivityService._internal();

  static final ConnectivityService _instance = ConnectivityService._internal();
  static ConnectivityService get instance => _instance;
  factory ConnectivityService() => _instance;

  final _controller = StreamController<bool>.broadcast();
  Timer? _fallbackTimer;
  StreamSubscription<List<ConnectivityResult>>? _platformSub;
  bool _isOnline = true;
  bool _initialized = false;
  final _rng = Random();

  /// Base fallback poll interval — actual interval adds ±25% jitter to
  /// prevent thundering-herd DNS spikes at scale.
  static const _fallbackBaseSeconds = 60;
  // Increased from 5s to 8s to reduce false-offline detection on slow networks.
  // TODO: Implement EMA-based adaptive timeout in v2.
  static const _checkTimeout = Duration(seconds: 8);

  // ignore: prefer_const_declarations

  /// The host to check for actual internet reachability.
  /// Uses the app's own Supabase domain so it works in every country.
  static const String _reachabilityHost = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Extract hostname from URL for DNS lookup.
  String get _host {
    const raw = _reachabilityHost;
    if (raw.startsWith('https://')) return raw.substring(8).split('/').first;
    if (raw.startsWith('http://')) return raw.substring(7).split('/').first;
    return raw.split('/').first;
  }

  /// Whether the device is currently online.
  bool get isOnline => _isOnline;

  /// Stream of connectivity changes.
  Stream<bool> get onlineStatus => _controller.stream;

  /// Initialize the service using platform-native connectivity detection.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Trust platform connectivity first — prevents false "offline" on slow DNS.
    final platformResults = await Connectivity().checkConnectivity();
    final platformSaysOnline = platformResults.any((r) => r != ConnectivityResult.none);
    if (platformSaysOnline) {
      _setOnline(true);
      _check(); // verify with DNS in background (non-blocking)
    } else {
      _setOnline(false);
    }

    // Listen for platform connectivity events (instant, no polling)
    _platformSub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        _setOnline(true); // trust platform immediately
        _check(); // verify in background
      } else {
        _setOnline(false);
      }
    });

    // Fallback check with jitter to prevent thundering-herd at scale
    _scheduleFallback();

    if (kDebugMode) {
      debugPrint('[ConnectivityService] Initialized (platform-native). Online: $_isOnline');
    }
  }

  /// Schedule the next fallback check with ±25% jitter.
  void _scheduleFallback() {
    final jitter = (_fallbackBaseSeconds * 0.25 * (2 * _rng.nextDouble() - 1)).round();
    final seconds = _fallbackBaseSeconds + jitter; // 45–75s
    _fallbackTimer = Timer(Duration(seconds: seconds), () async {
      await _check();
      _scheduleFallback();
    });
  }

  /// Force an immediate connectivity check.
  Future<bool> checkNow() => _check();

  Future<bool> _check() async {
    // No Supabase URL configured (dev/demo mode) — assume online.
    if (_host.isEmpty) {
      _setOnline(true);
      return true;
    }

    try {
      final result = await InternetAddress.lookup(_host)
          .timeout(_checkTimeout);
      _setOnline(result.isNotEmpty && result.first.rawAddress.isNotEmpty);
    } on SocketException catch (_) {
      _setOnline(false);
    } on TimeoutException catch (_) {
      // DNS timeout doesn't necessarily mean offline — could be slow network.
      // Don't flip to offline on timeout alone, only on explicit failure.
      if (kDebugMode) {
        debugPrint('[ConnectivityService] DNS timeout for $_host — keeping current state: $_isOnline');
      }
    } catch (_) {
      _setOnline(false);
    }
    return _isOnline;
  }

  void _setOnline(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _controller.add(_isOnline);
      if (kDebugMode) {
        debugPrint('[ConnectivityService] Status changed: $_isOnline');
      }
    }
  }

  /// Stop monitoring. Call on app shutdown if needed.
  void dispose() {
    _fallbackTimer?.cancel();
    _platformSub?.cancel();
    _controller.close();
  }
}
