import 'dart:async';

import 'package:flutter/foundation.dart';

/// Circuit breaker states.
enum CircuitState { closed, open, halfOpen }

/// Prevents cascading failures by cutting off requests to a failing service.
///
/// When a service starts failing, the circuit breaker "opens" and immediately
/// rejects all requests for a cooldown period. This:
/// - Prevents the thundering herd problem (all users retrying simultaneously)
/// - Gives the failing service time to recover
/// - Lets the app gracefully degrade to offline mode
///
/// State machine:
/// ```
/// CLOSED (normal) ──[failures >= threshold]──> OPEN (rejecting)
///     ^                                            │
///     │                                     [cooldown expires]
///     │                                            v
///     └──────────[success]──────────── HALF-OPEN (testing)
///                                          │
///                                     [failure]
///                                          │
///                                          v
///                                       OPEN
/// ```
///
/// Usage:
/// ```dart
/// final breaker = CircuitBreaker(name: 'supabase');
///
/// try {
///   final result = await breaker.execute(() => supabase.from('entries').select());
/// } on CircuitOpenException {
///   // Service is down — show offline UI
/// }
/// ```
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration cooldownDuration;
  final Duration halfOpenTimeout;

  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.cooldownDuration = const Duration(seconds: 60),
    this.halfOpenTimeout = const Duration(seconds: 10),
  });

  CircuitState _state = CircuitState.closed;
  CircuitState get state => _state;

  int _failureCount = 0;
  int get failureCount => _failureCount;

  DateTime? _openedAt;
  DateTime? _lastFailureAt;
  DateTime? get lastFailureAt => _lastFailureAt;

  final _stateController = StreamController<CircuitState>.broadcast();

  /// Stream of state changes for UI updates.
  Stream<CircuitState> get stateChanges => _stateController.stream;

  /// Execute an operation through the circuit breaker.
  ///
  /// - In CLOSED state: execute normally, track failures.
  /// - In OPEN state: reject immediately with [CircuitOpenException].
  /// - In HALF-OPEN state: allow one request to test if the service recovered.
  Future<T> execute<T>(Future<T> Function() operation) async {
    switch (_state) {
      case CircuitState.open:
        if (_shouldTransitionToHalfOpen()) {
          _transitionTo(CircuitState.halfOpen);
          return _tryOperation(operation);
        }
        throw CircuitOpenException(
          name: name,
          failureCount: _failureCount,
          reopensAt: _openedAt!.add(cooldownDuration),
        );

      case CircuitState.halfOpen:
        return _tryOperation(operation);

      case CircuitState.closed:
        return _tryOperation(operation);
    }
  }

  Future<T> _tryOperation<T>(Future<T> Function() operation) async {
    try {
      final result = await operation().timeout(halfOpenTimeout);
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    _failureCount = 0;
    if (_state != CircuitState.closed) {
      _transitionTo(CircuitState.closed);
    }
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureAt = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _transitionTo(CircuitState.open);
    }
  }

  bool _shouldTransitionToHalfOpen() {
    if (_openedAt == null) return false;
    return DateTime.now().difference(_openedAt!) >= cooldownDuration;
  }

  void _transitionTo(CircuitState newState) {
    if (_state == newState) return;
    final oldState = _state;
    _state = newState;

    if (newState == CircuitState.open) {
      _openedAt = DateTime.now();
    }

    _stateController.add(newState);

    if (kDebugMode) {
      debugPrint(
        '[CircuitBreaker:$name] ${oldState.name} → ${newState.name} '
        '(failures: $_failureCount)',
      );
    }
  }

  /// Execute an operation, returning [fallback] if the circuit is open.
  /// This prevents UI from showing raw errors when the service is down.
  Future<T> executeWithFallback<T>(
    Future<T> Function() operation,
    T fallback,
  ) async {
    try {
      return await execute(operation);
    } on CircuitOpenException {
      if (kDebugMode) {
        debugPrint('[CircuitBreaker:$name] Circuit open — using fallback');
      }
      return fallback;
    }
  }

  /// Reset the circuit breaker to closed state (e.g., on manual retry).
  void reset() {
    _failureCount = 0;
    _openedAt = null;
    _lastFailureAt = null;
    _transitionTo(CircuitState.closed);
  }

  void dispose() {
    _stateController.close();
  }
}

/// Thrown when the circuit breaker is open (service is down).
class CircuitOpenException implements Exception {
  final String name;
  final int failureCount;
  final DateTime reopensAt;

  const CircuitOpenException({
    required this.name,
    required this.failureCount,
    required this.reopensAt,
  });

  Duration get retryIn => reopensAt.difference(DateTime.now());

  @override
  String toString() =>
      'CircuitOpenException: $name is unavailable '
      '($failureCount failures, retry in ${retryIn.inSeconds}s)';
}
