import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/services/backup/backup_service.dart';

void main() {
  group('BackupService', () {
    late BackupService service;

    setUp(() {
      service = BackupService();
      service.reset();
    });

    test('is a singleton', () {
      final a = BackupService();
      final b = BackupService();
      expect(identical(a, b), isTrue);
    });

    group('getBackupInfo', () {
      test('returns idle status initially', () {
        final info = service.getBackupInfo();
        expect(info.status, BackupStatus.idle);
        expect(info.lastBackupTime, isNull);
        expect(info.backedUpCount, 0);
      });
    });

    group('reset', () {
      test('resets status to idle', () {
        service.reset();
        final info = service.getBackupInfo();
        expect(info.status, BackupStatus.idle);
      });
    });

    group('BackupInfo', () {
      test('default constructor has correct defaults', () {
        const info = BackupInfo();
        expect(info.lastBackupTime, isNull);
        expect(info.backedUpCount, 0);
        expect(info.status, BackupStatus.idle);
      });

      test('constructor accepts all parameters', () {
        final now = DateTime.now();
        final info = BackupInfo(
          lastBackupTime: now,
          backedUpCount: 42,
          status: BackupStatus.completed,
        );
        expect(info.lastBackupTime, now);
        expect(info.backedUpCount, 42);
        expect(info.status, BackupStatus.completed);
      });
    });

    group('BackupException', () {
      test('toString includes message', () {
        final e = BackupException('test message');
        expect(e.toString(), contains('test message'));
        expect(e.message, 'test message');
      });
    });

    group('BackupStatus', () {
      test('has all expected values', () {
        expect(BackupStatus.values, hasLength(4));
        expect(BackupStatus.values, contains(BackupStatus.idle));
        expect(BackupStatus.values, contains(BackupStatus.inProgress));
        expect(BackupStatus.values, contains(BackupStatus.completed));
        expect(BackupStatus.values, contains(BackupStatus.failed));
      });
    });
  });
}
