import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/services/storage/secure_storage_service.dart';

void main() {
  group('SecureStorageService', () {
    test('is a singleton', () {
      final a = SecureStorageService();
      final b = SecureStorageService();
      expect(identical(a, b), isTrue);
    });

    test('can be instantiated', () {
      expect(SecureStorageService(), isA<SecureStorageService>());
    });

    // Note: Most SecureStorageService methods require platform channels
    // (FlutterSecureStorage) which are not available in unit tests.
    // Integration tests cover the actual read/write behavior.
    // Here we test what we can without platform channels.
  });
}
