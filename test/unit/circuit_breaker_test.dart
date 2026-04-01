library;

/// Tests for CircuitBreaker state transitions.
///
/// Verifies:
/// - Closed → Open after N failures
/// - Open rejects immediately with CircuitOpenException
/// - Open → HalfOpen after cooldown
/// - HalfOpen → Closed on success
/// - HalfOpen → Open on failure
/// - Reset returns to closed
/// - executeWithFallback returns fallback when open
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/core/network/circuit_breaker.dart';

void main() {
  late CircuitBreaker breaker;

  setUp(() {
    breaker = CircuitBreaker(
      name: 'test',
      failureThreshold: 3,
      cooldownDuration: const Duration(milliseconds: 100),
      halfOpenTimeout: const Duration(seconds: 5),
    );
  });

  tearDown(() {
    breaker.dispose();
  });

  group('CircuitBreaker state transitions', () {
    test('starts in closed state', () {
      expect(breaker.state, CircuitState.closed);
      expect(breaker.failureCount, 0);
    });

    test('stays closed when operations succeed', () async {
      await breaker.execute(() async => 'ok');
      await breaker.execute(() async => 'ok');
      expect(breaker.state, CircuitState.closed);
      expect(breaker.failureCount, 0);
    });

    test('increments failure count on failure', () async {
      try {
        await breaker.execute(() async => throw Exception('fail'));
      } catch (_) {}
      expect(breaker.failureCount, 1);
      expect(breaker.state, CircuitState.closed);
    });

    test('opens after reaching failure threshold', () async {
      for (var i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }
      expect(breaker.state, CircuitState.open);
      expect(breaker.failureCount, 3);
    });

    test('rejects immediately when open', () async {
      // Trip the breaker
      for (var i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }
      expect(breaker.state, CircuitState.open);

      // Next call should throw CircuitOpenException without executing
      var operationCalled = false;
      try {
        await breaker.execute(() async {
          operationCalled = true;
          return 'ok';
        });
        fail('Should have thrown');
      } on CircuitOpenException catch (e) {
        expect(e.name, 'test');
        expect(e.failureCount, 3);
        expect(e.retryIn.inMilliseconds, greaterThan(0));
      }
      expect(operationCalled, false);
    });

    test('transitions to half-open after cooldown', () async {
      // Trip the breaker
      for (var i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }
      expect(breaker.state, CircuitState.open);

      // Wait for cooldown
      await Future.delayed(const Duration(milliseconds: 150));

      // Next call should go through (half-open test)
      final result = await breaker.execute(() async => 'recovered');
      expect(result, 'recovered');
      expect(breaker.state, CircuitState.closed);
    });

    test('returns to open if half-open test fails', () async {
      // Trip the breaker
      for (var i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      // Wait for cooldown
      await Future.delayed(const Duration(milliseconds: 150));

      // Half-open test fails
      try {
        await breaker.execute(() async => throw Exception('still failing'));
      } catch (_) {}

      expect(breaker.state, CircuitState.open);
    });

    test('success resets failure count', () async {
      // 2 failures (below threshold)
      for (var i = 0; i < 2; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }
      expect(breaker.failureCount, 2);

      // Success resets
      await breaker.execute(() async => 'ok');
      expect(breaker.failureCount, 0);
      expect(breaker.state, CircuitState.closed);
    });

    test('reset() returns to closed state', () async {
      // Trip the breaker
      for (var i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }
      expect(breaker.state, CircuitState.open);

      breaker.reset();
      expect(breaker.state, CircuitState.closed);
      expect(breaker.failureCount, 0);
    });

    test('stateChanges stream emits transitions', () async {
      final states = <CircuitState>[];
      breaker.stateChanges.listen(states.add);

      // Trip to open
      for (var i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      // Wait for cooldown + recover
      await Future.delayed(const Duration(milliseconds: 150));
      await breaker.execute(() async => 'ok');

      // Allow stream events to propagate
      await Future.delayed(Duration.zero);

      expect(states, [CircuitState.open, CircuitState.halfOpen, CircuitState.closed]);
    });
  });

  group('executeWithFallback', () {
    test('returns result when circuit is closed', () async {
      final result = await breaker.executeWithFallback(
        () async => 'real-data',
        'fallback-data',
      );
      expect(result, 'real-data');
    });

    test('returns fallback when circuit is open', () async {
      // Trip the breaker
      for (var i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      final result = await breaker.executeWithFallback(
        () async => 'real-data',
        'fallback-data',
      );
      expect(result, 'fallback-data');
    });

    test('returns fallback with typed data', () async {
      // Trip the breaker
      for (var i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      final result = await breaker.executeWithFallback<List<String>>(
        () async => ['a', 'b'],
        [],
      );
      expect(result, isEmpty);
    });
  });

  group('CircuitOpenException', () {
    test('toString includes name and failure count', () {
      final exception = CircuitOpenException(
        name: 'supabase',
        failureCount: 5,
        reopensAt: DateTime.now().add(const Duration(seconds: 30)),
      );
      expect(exception.toString(), contains('supabase'));
      expect(exception.toString(), contains('5 failures'));
    });

    test('retryIn returns positive duration', () {
      final exception = CircuitOpenException(
        name: 'test',
        failureCount: 3,
        reopensAt: DateTime.now().add(const Duration(seconds: 10)),
      );
      expect(exception.retryIn.inSeconds, greaterThan(0));
    });
  });
}
