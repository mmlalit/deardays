import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/services/analytics/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    late AnalyticsService service;

    setUp(() {
      service = AnalyticsService();
      service.clear();
    });

    test('is a singleton', () {
      final a = AnalyticsService();
      final b = AnalyticsService();
      expect(identical(a, b), isTrue);
    });

    group('track', () {
      test('records events', () {
        service.track('test_event', properties: {'key': 'value'});

        expect(service.events, hasLength(1));
        expect(service.events.first.name, 'test_event');
        expect(service.events.first.properties['key'], 'value');
      });

      test('includes user ID after identify', () {
        service.identify('user-123');
        service.track('test_event');

        // Last event (after the identify event itself)
        final event = service.events.last;
        expect(event.userId, 'user-123');
      });

      test('user ID is null after reset', () {
        service.identify('user-123');
        service.reset();
        service.track('test_event');

        final event = service.events.last;
        expect(event.userId, isNull);
      });
    });

    group('identify', () {
      test('tracks user_identified event', () {
        service.identify('user-456');

        expect(service.events.any((e) => e.name == AnalyticsEvent.userIdentified), isTrue);
      });

      test('sets user properties', () {
        service.identify('user-456', properties: {'plan': 'premium'});

        expect(service.userProperties['plan'], 'premium');
      });
    });

    group('setUserProperty', () {
      test('persists across events', () {
        service.setUserProperty('theme', 'dark');
        service.track('test_event');

        expect(service.events.last.properties['theme'], 'dark');
      });
    });

    group('trackScreen', () {
      test('records screen_view event', () {
        service.trackScreen('home');

        expect(service.events.last.name, AnalyticsEvent.screenView);
        expect(service.events.last.properties['screen'], 'home');
      });
    });

    group('timed events', () {
      test('tracks duration for timed events', () async {
        service.startTimedEvent('loading');
        await Future.delayed(const Duration(milliseconds: 50));
        service.endTimedEvent('loading', properties: {'source': 'api'});

        final event =
            service.events.firstWhere((e) => e.name == 'loading');
        expect(event.properties.containsKey('duration_ms'), isTrue);
        expect(int.parse(event.properties['duration_ms']!), greaterThan(0));
        expect(event.properties['source'], 'api');
      });

      test('does nothing if timed event was not started', () {
        service.endTimedEvent('nonexistent');

        expect(service.events.where((e) => e.name == 'nonexistent'), isEmpty);
      });
    });

    group('clear', () {
      test('clears all events', () {
        service.track('event1');
        service.track('event2');
        service.clear();

        expect(service.events, isEmpty);
      });
    });

    group('TrackedEvent', () {
      test('toJson serializes correctly', () {
        final event = TrackedEvent(
          name: 'test',
          userId: 'u1',
          properties: {'k': 'v'},
          timestamp: DateTime(2026, 3, 13),
        );

        final json = event.toJson();
        expect(json['name'], 'test');
        expect(json['user_id'], 'u1');
        expect(json['properties'], {'k': 'v'});
      });
    });

    group('AnalyticsEvent constants', () {
      test('all event names are non-empty strings', () {
        final events = [
          AnalyticsEvent.userIdentified,
          AnalyticsEvent.entryCreated,
          AnalyticsEvent.voiceRecorded,
          AnalyticsEvent.aiPolishUsed,
          AnalyticsEvent.bookGenerated,
          AnalyticsEvent.shareCardCreated,
          AnalyticsEvent.streakMilestone,
          AnalyticsEvent.searchPerformed,
          AnalyticsEvent.paywallShown,
          AnalyticsEvent.backupStarted,
          AnalyticsEvent.screenView,
        ];

        for (final event in events) {
          expect(event, isNotEmpty);
        }
      });
    });
  });
}
