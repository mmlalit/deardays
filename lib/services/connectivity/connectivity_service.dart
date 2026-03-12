import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Monitors network connectivity by periodically checking reachability.
///
/// On Windows desktop, `connectivity_plus` is unreliable so we use a simple
/// periodic HTTP HEAD check instead.
class ConnectivityService {
  ConnectivityService._internal();

  static final ConnectivityService _instance = ConnectivityService._internal();
  static ConnectivityService get instance => _instance;
  factory ConnectivityService() => _instance;

  final _controller = StreamController<bool>.broadcast();
  Timer? _pollTimer;
  bool _isOnline = true;
  bool _initialized = false;

  static const _pollInterval = Duration(seconds: 30);
  static const _checkTimeout = Duration(seconds: 5);

  /// Whether the device is currently online.
  bool get isOnline => _isOnline;

  /// Stream of connectivity changes.
  Stream<bool> get onlineStatus => _controller.stream;

  /// Initialize the service and start polling.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Initial check
    await _check();

    // Start periodic polling
    _pollTimer = Timer.periodic(_pollInterval, (_) => _check());

    if (kDebugMode) {
      debugPrint('[ConnectivityService] Initialized. Online: $_isOnline');
    }
  }

  /// Force an immediate connectivity check.
  Future<bool> checkNow() => _check();

  Future<bool> _check() async {
    final wasOnline = _isOnline;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(_checkTimeout);
      _isOnline = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      _isOnline = false;
    } on TimeoutException catch (_) {
      _isOnline = false;
    } catch (_) {
      _isOnline = false;
    }

    if (_isOnline != wasOnline) {
      _controller.add(_isOnline);
      if (kDebugMode) {
        debugPrint('[ConnectivityService] Status changed: $_isOnline');
      }
    }
    return _isOnline;
  }

  /// Stop polling. Call on app shutdown if needed.
  void dispose() {
    _pollTimer?.cancel();
    _controller.close();
  }
}
