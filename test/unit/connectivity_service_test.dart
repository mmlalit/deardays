import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/services/connectivity/connectivity_service.dart';

void main() {
  group('ConnectivityService', () {
    test('is a singleton', () {
      final a = ConnectivityService();
      final b = ConnectivityService();
      expect(identical(a, b), isTrue);
    });

    test('instance accessor returns same instance', () {
      expect(identical(ConnectivityService.instance, ConnectivityService()),
          isTrue);
    });

    test('isOnline defaults to true', () {
      // Before init, the default value is true
      expect(ConnectivityService().isOnline, isTrue);
    });

    test('onlineStatus returns a broadcast stream', () {
      final stream = ConnectivityService().onlineStatus;
      expect(stream, isA<Stream<bool>>());
      // Should be a broadcast stream (multiple listeners)
      expect(stream.isBroadcast, isTrue);
    });

    test('checkNow returns true when no Supabase URL configured (dev/demo mode)', () async {
      // In tests, SUPABASE_URL is not injected via --dart-define, so
      // _reachabilityHost defaults to '' and _check() skips DNS lookup.
      final result = await ConnectivityService().checkNow();
      expect(result, isTrue);
    });

    test('isOnline stays true after checkNow with no host configured', () async {
      await ConnectivityService().checkNow();
      expect(ConnectivityService().isOnline, isTrue);
    });
  });
}
