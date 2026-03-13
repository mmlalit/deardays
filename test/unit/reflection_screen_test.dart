import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/core/providers/app_providers.dart';

void main() {
  group('ReflectionPeriod', () {
    test('has all expected values', () {
      expect(ReflectionPeriod.values, hasLength(3));
      expect(ReflectionPeriod.values, contains(ReflectionPeriod.weekly));
      expect(ReflectionPeriod.values, contains(ReflectionPeriod.monthly));
      expect(ReflectionPeriod.values, contains(ReflectionPeriod.yearly));
    });

    test('name returns correct string', () {
      expect(ReflectionPeriod.weekly.name, 'weekly');
      expect(ReflectionPeriod.monthly.name, 'monthly');
      expect(ReflectionPeriod.yearly.name, 'yearly');
    });

    test('can be looked up by name', () {
      expect(
        ReflectionPeriod.values.firstWhere((p) => p.name == 'weekly'),
        ReflectionPeriod.weekly,
      );
      expect(
        ReflectionPeriod.values.firstWhere((p) => p.name == 'monthly'),
        ReflectionPeriod.monthly,
      );
      expect(
        ReflectionPeriod.values.firstWhere((p) => p.name == 'yearly'),
        ReflectionPeriod.yearly,
      );
    });

    test('fallback to weekly for unknown period', () {
      final period = ReflectionPeriod.values.firstWhere(
        (p) => p.name == 'quarterly',
        orElse: () => ReflectionPeriod.weekly,
      );
      expect(period, ReflectionPeriod.weekly);
    });
  });
}
