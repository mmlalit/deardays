import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:deardays/services/ai/ai_credit_service.dart';

void main() {
  group('AiCreditService', () {
    late AiCreditService service;

    setUpAll(() async {
      Hive.init('${DateTime.now().millisecondsSinceEpoch}_credit_test');
    });

    setUp(() async {
      service = AiCreditService();
      await service.initForTesting();
      service.reset();
    });

    test('is a singleton', () {
      final a = AiCreditService();
      final b = AiCreditService();
      expect(identical(a, b), isTrue);
    });

    group('tier management', () {
      test('defaults to free tier', () {
        expect(service.currentTier, 'free');
      });

      test('can change tier', () {
        service.currentTier = 'premium';
        expect(service.currentTier, 'premium');
      });

      test('limits reflect current tier', () {
        expect(service.limits.polish, 5); // free tier
        service.currentTier = 'premium';
        expect(service.limits.polish, 100);
        service.currentTier = 'ultra';
        expect(service.limits.polish, -1); // unlimited
      });
    });

    group('credit checks', () {
      test('canUse returns true when credits available', () {
        expect(service.canUse(AiOperation.polish), isTrue);
      });

      test('remaining returns correct count', () {
        expect(service.remaining(AiOperation.polish), 5); // free tier limit
      });

      test('consume decrements credits', () {
        service.consume(AiOperation.polish);
        expect(service.remaining(AiOperation.polish), 4);
        expect(service.polishUsed, 1);
      });

      test('consume returns false when no credits left', () {
        // Use all 5 free polish credits
        for (int i = 0; i < 5; i++) {
          expect(service.consume(AiOperation.polish), isTrue);
        }
        expect(service.consume(AiOperation.polish), isFalse);
        expect(service.canUse(AiOperation.polish), isFalse);
      });

      test('unlimited tier always has credits', () {
        service.currentTier = 'ultra';
        for (int i = 0; i < 100; i++) {
          expect(service.consume(AiOperation.polish), isTrue);
        }
        expect(service.canUse(AiOperation.polish), isTrue);
      });

      test('premium tier has higher limits', () {
        service.currentTier = 'premium';
        expect(service.remaining(AiOperation.polish), 100);
        // summary is unlimited for premium
        expect(service.canUse(AiOperation.summary), isTrue);
        expect(service.remaining(AiOperation.summary), 999);
      });
    });

    group('usage tracking', () {
      test('tracks each operation separately', () {
        service.consume(AiOperation.polish);
        service.consume(AiOperation.polish);
        service.consume(AiOperation.chat);

        expect(service.polishUsed, 2);
        expect(service.chatUsed, 1);
        expect(service.summaryUsed, 0);
      });

      test('getUsageSummary returns all operations', () {
        service.consume(AiOperation.polish);
        final summary = service.getUsageSummary();

        expect(summary.length, AiOperation.values.length);
        expect(summary['polish']!.used, 1);
        expect(summary['polish']!.limit, 5);
        expect(summary['chat']!.used, 0);
      });
    });

    group('reset', () {
      test('resets all counters and tier', () {
        service.currentTier = 'premium';
        service.consume(AiOperation.polish);
        service.consume(AiOperation.chat);

        service.reset();

        expect(service.currentTier, 'free');
        expect(service.polishUsed, 0);
        expect(service.chatUsed, 0);
      });
    });

    group('CreditUsage', () {
      test('hasCredits is true when under limit', () {
        const usage = CreditUsage(used: 3, limit: 5);
        expect(usage.hasCredits, isTrue);
        expect(usage.remaining, 2);
        expect(usage.isUnlimited, isFalse);
      });

      test('hasCredits is false when at limit', () {
        const usage = CreditUsage(used: 5, limit: 5);
        expect(usage.hasCredits, isFalse);
        expect(usage.remaining, 0);
      });

      test('unlimited usage always has credits', () {
        const usage = CreditUsage(used: 1000, limit: -1);
        expect(usage.hasCredits, isTrue);
        expect(usage.isUnlimited, isTrue);
        expect(usage.remaining, 999);
      });

      test('usagePercent is correct', () {
        const usage = CreditUsage(used: 3, limit: 10);
        expect(usage.usagePercent, closeTo(0.3, 0.01));
      });

      test('toString formats correctly', () {
        const limited = CreditUsage(used: 3, limit: 5);
        expect(limited.toString(), '3/5');
        const unlimited = CreditUsage(used: 10, limit: -1);
        expect(unlimited.toString(), '10/∞');
      });
    });

    group('CreditLimits', () {
      test('tier limits exist for all tiers', () {
        expect(AiCreditService.tierLimits.containsKey('free'), isTrue);
        expect(AiCreditService.tierLimits.containsKey('premium'), isTrue);
        expect(AiCreditService.tierLimits.containsKey('ultra'), isTrue);
      });
    });
  });
}
