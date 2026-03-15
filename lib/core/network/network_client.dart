import 'package:flutter/foundation.dart';

import 'package:deardays/core/network/circuit_breaker.dart';

/// Wrapper around Supabase client that adds circuit breaker protection.
///
/// All database operations should go through this client instead of calling
/// Supabase directly. This prevents cascading failures when Supabase is
/// temporarily unavailable.
///
/// Usage:
/// ```dart
/// final client = NetworkClient();
/// final entries = await client.query(() =>
///   Supabase.instance.client.from('journal_entries').select()
/// );
/// ```
class NetworkClient {
  NetworkClient._internal();
  static final NetworkClient _instance = NetworkClient._internal();
  factory NetworkClient() => _instance;

  /// Circuit breaker for Supabase REST API calls.
  final supabaseBreaker = CircuitBreaker(
    name: 'supabase',
    failureThreshold: 5,
    cooldownDuration: const Duration(seconds: 60),
  );

  /// Circuit breaker for AI Edge Function calls (separate from DB).
  final aiBreaker = CircuitBreaker(
    name: 'ai',
    failureThreshold: 3,
    cooldownDuration: const Duration(seconds: 30),
  );

  /// Execute a Supabase query through the circuit breaker.
  Future<T> query<T>(Future<T> Function() operation) {
    return supabaseBreaker.execute(operation);
  }

  /// Execute an AI API call through the circuit breaker.
  Future<T> aiCall<T>(Future<T> Function() operation) {
    return aiBreaker.execute(operation);
  }

  /// Whether the Supabase service is currently available.
  bool get isSupabaseAvailable =>
      supabaseBreaker.state != CircuitState.open;

  /// Whether the AI service is currently available.
  bool get isAiAvailable =>
      aiBreaker.state != CircuitState.open;

  /// Reset all circuit breakers (e.g., on manual retry).
  void resetAll() {
    supabaseBreaker.reset();
    aiBreaker.reset();
    if (kDebugMode) {
      debugPrint('[NetworkClient] All circuit breakers reset.');
    }
  }

  void dispose() {
    supabaseBreaker.dispose();
    aiBreaker.dispose();
  }
}
