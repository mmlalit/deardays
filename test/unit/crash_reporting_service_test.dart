import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/services/crash_reporting/crash_reporting_service.dart';

void main() {
  group('CrashReportingService', () {
    late CrashReportingService service;

    setUp(() {
      service = CrashReportingService();
      service.clear();
    });

    test('is a singleton', () {
      final a = CrashReportingService();
      final b = CrashReportingService();
      expect(identical(a, b), isTrue);
    });

    group('recordError', () {
      test('stores error reports', () {
        service.recordError(
          Exception('test error'),
          StackTrace.current,
          reason: 'unit test',
        );

        expect(service.reports, hasLength(1));
        expect(service.reports.first.error, contains('test error'));
        expect(service.reports.first.reason, 'unit test');
      });

      test('includes user ID when set', () {
        service.setUser('user-123');
        service.recordError(Exception('err'), StackTrace.current);

        expect(service.reports.first.userId, 'user-123');
      });

      test('user ID is null after clearUser', () {
        service.setUser('user-123');
        service.clearUser();
        service.recordError(Exception('err'), StackTrace.current);

        expect(service.reports.first.userId, isNull);
      });

      test('includes extras when provided', () {
        service.recordError(
          Exception('err'),
          StackTrace.current,
          extras: {'screen': 'home'},
        );

        expect(service.reports.first.extras['screen'], 'home');
      });
    });

    group('breadcrumbs', () {
      test('adds breadcrumbs', () {
        service.addBreadcrumb('navigated', data: {'screen': 'home'});

        expect(service.breadcrumbs, hasLength(1));
        expect(service.breadcrumbs.first.message, 'navigated');
        expect(service.breadcrumbs.first.data['screen'], 'home');
      });

      test('limits breadcrumbs to max 50', () {
        for (int i = 0; i < 60; i++) {
          service.addBreadcrumb('crumb $i');
        }

        expect(service.breadcrumbs, hasLength(50));
        // First breadcrumb should be crumb 10 (0-9 evicted)
        expect(service.breadcrumbs.first.message, 'crumb 10');
      });

      test('breadcrumbs are included in error reports', () {
        service.addBreadcrumb('step 1');
        service.addBreadcrumb('step 2');
        service.recordError(Exception('err'), StackTrace.current);

        expect(service.reports.first.breadcrumbs, hasLength(2));
      });
    });

    group('setUser', () {
      test('adds breadcrumb when user is identified', () {
        service.setUser('user-456', context: {'plan': 'premium'});

        expect(service.breadcrumbs, isNotEmpty);
        expect(service.breadcrumbs.last.message, 'User identified');
      });
    });

    group('clear', () {
      test('clears reports and breadcrumbs', () {
        service.addBreadcrumb('test');
        service.recordError(Exception('err'), StackTrace.current);

        service.clear();

        expect(service.reports, isEmpty);
        expect(service.breadcrumbs, isEmpty);
      });
    });

    group('Breadcrumb', () {
      test('toJson serializes correctly', () {
        final crumb = Breadcrumb(
          message: 'test',
          timestamp: DateTime(2026, 3, 13),
          data: {'key': 'value'},
        );

        final json = crumb.toJson();
        expect(json['message'], 'test');
        expect(json['data'], {'key': 'value'});
      });
    });

    group('CrashReport', () {
      test('toJson serializes correctly', () {
        final report = CrashReport(
          error: 'test error',
          stackTrace: 'stack here',
          reason: 'test',
          userId: 'u1',
          timestamp: DateTime(2026, 3, 13),
        );

        final json = report.toJson();
        expect(json['error'], 'test error');
        expect(json['reason'], 'test');
        expect(json['user_id'], 'u1');
      });
    });
  });
}
