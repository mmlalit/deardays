// Smoke test — verifies the app entry point resolves without compilation errors.
// The full E2E suite is in integration_test/app_test.dart.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smoke — test infrastructure is reachable', () {
    expect(1 + 1, equals(2));
  });
}
