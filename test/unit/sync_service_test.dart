import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/services/sync/sync_service.dart';

void main() {
  group('SyncService', () {
    test('is a singleton', () {
      final a = SyncService();
      final b = SyncService();
      expect(identical(a, b), isTrue);
    });

    test('instance accessor returns same instance', () {
      expect(identical(SyncService.instance, SyncService()), isTrue);
    });

    test('initial status is synced', () {
      expect(SyncService().status, SyncStatus.synced);
    });

    test('statusStream returns a broadcast stream', () {
      final stream = SyncService().statusStream;
      expect(stream, isA<Stream<SyncStatus>>());
      expect(stream.isBroadcast, isTrue);
    });

    test('onSyncComplete callback is null by default', () {
      expect(SyncService().onSyncComplete, isNull);
    });

    test('onSyncComplete can be set', () {
      var called = false;
      SyncService().onSyncComplete = (_) => called = true;
      SyncService().onSyncComplete!([]);
      expect(called, isTrue);
      // Clean up
      SyncService().onSyncComplete = null;
    });
  });

  group('SyncStatus', () {
    test('has all expected values', () {
      expect(SyncStatus.values, hasLength(5));
      expect(SyncStatus.values, contains(SyncStatus.synced));
      expect(SyncStatus.values, contains(SyncStatus.pending));
      expect(SyncStatus.values, contains(SyncStatus.syncing));
      expect(SyncStatus.values, contains(SyncStatus.error));
    });
  });
}
