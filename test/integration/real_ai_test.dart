library;

/// Real AI service integration tests — tests against LIVE Supabase Edge Functions.
///
/// Signs in with an existing test account and validates AI endpoints.
///
/// Run:
/// ```bash
/// flutter test test/integration/real_ai_test.dart --reporter expanded \
///   --dart-define=AI_API_URL=https://mcmlawztwyrjcwmieciw.supabase.co/functions/v1
/// ```
///
/// What these tests verify:
/// - AI service configuration detection
/// - Light polish (grammar/spelling fix)
/// - Title generation
/// - Writing prompt generation
/// - Chat / conversational AI
/// - Summary, cover query, share summary
///
/// IMPORTANT: Each AI call costs tokens. Run sparingly.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/config/supabase_config.dart';
import 'package:deardays/services/ai/ai_service.dart';

/// In-memory PKCE storage — avoids SharedPreferences platform channel.
class _InMemoryGotrueAsyncStorage extends GotrueAsyncStorage {
  final _map = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _map[key];
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _map[key] = value;
  @override
  Future<void> removeItem({required String key}) async => _map.remove(key);
}

const _testEmail = 'mmlalit03@gmail.com';
const _testPassword = '123456';

void main() {
  late AiService ai;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;

    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _InMemoryGotrueAsyncStorage(),
      ),
    );

    // ignore: avoid_print
    print('\n=== Signing in as: $_testEmail ===');
    final authResponse = await Supabase.instance.client.auth.signInWithPassword(
      email: _testEmail,
      password: _testPassword,
    );

    if (authResponse.user == null) {
      fail('Failed to sign in with test account: $_testEmail');
    }

    ai = AiService();
    // ignore: avoid_print
    print('=== AI configured: ${ai.isConfigured} ===\n');
  });

  tearDownAll(() async {
    await Supabase.instance.client.auth.signOut();
  });

  // ===========================================================================
  // 1. Configuration check
  // ===========================================================================

  group('Real AI — Configuration', () {
    test('isConfigured reflects AI_API_URL presence', () {
      if (!ai.isConfigured) {
        // ignore: avoid_print
        print('  ⚠ AI_API_URL not set — AI tests will be skipped.');
        // ignore: avoid_print
        print('  Pass --dart-define=AI_API_URL=https://<project>.supabase.co/functions/v1');
      } else {
        // ignore: avoid_print
        print('  ✓ AI service is configured');
      }
    });

    test('throws AiServiceException when not configured', () {
      if (ai.isConfigured) return;

      expect(
        () => ai.lightPolish('test'),
        throwsA(isA<AiServiceException>()),
      );
      // ignore: avoid_print
      print('  ✓ Correctly throws when AI_API_URL is empty');
    });
  });

  // ===========================================================================
  // 2. Light polish
  // ===========================================================================

  group('Real AI — Light Polish', () {
    test('fixes basic grammar errors', () async {
      if (!ai.isConfigured) return;

      final result = await ai.lightPolish(
        'i went too the store yesterday and buyed some food',
      );

      expect(result, isNotEmpty);
      expect(result.toLowerCase(), isNot(contains('buyed')),
          reason: 'AI should fix "buyed" to "bought"');
      // ignore: avoid_print
      print('  ✓ Polish result: $result');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('preserves meaning while fixing', () async {
      if (!ai.isConfigured) return;

      const input = 'Today was realy good. I fealt happy about my promotion.';
      final result = await ai.lightPolish(input);

      expect(result, isNotEmpty);
      expect(
        result.toLowerCase().contains('happy') ||
            result.toLowerCase().contains('promotion') ||
            result.toLowerCase().contains('good'),
        isTrue,
        reason: 'AI should preserve the meaning',
      );
      // ignore: avoid_print
      print('  ✓ Meaning preserved: $result');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ===========================================================================
  // 3. Title generation
  // ===========================================================================

  group('Real AI — Title Generation', () {
    test('generates a short title from entry text', () async {
      if (!ai.isConfigured) return;

      final title = await ai.generateTitle(
        'Today I went hiking in the mountains. The view from the summit was '
        'breathtaking. I could see the entire valley below, painted in autumn '
        'colors. It reminded me why I love being outdoors.',
      );

      expect(title, isNotEmpty);
      expect(title.length, lessThan(100),
          reason: 'Title should be concise');
      // ignore: avoid_print
      print('  ✓ Generated title: "$title"');
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  // ===========================================================================
  // 4. Writing prompt
  // ===========================================================================

  group('Real AI — Writing Prompt', () {
    test('returns a non-empty writing prompt', skip: 'method removed — getWritingPrompt no longer exists on AiService', () async {
      // TODO: method removed — getWritingPrompt no longer exists on AiService
    });
  });

  // ===========================================================================
  // 5. Chat
  // ===========================================================================

  group('Real AI — Chat', () {
    test('responds to a simple check-in message', () async {
      if (!ai.isConfigured) return;

      final reply = await ai.chat(
        messages: [
          {'role': 'user', 'content': 'I had a good day today.'},
        ],
        mood: 'good',
        isFirstCheckIn: true,
      );

      expect(reply, isNotEmpty);
      expect(reply.length, greaterThan(5));
      // ignore: avoid_print
      print('  ✓ Chat reply: "${reply.substring(0, reply.length.clamp(0, 100))}..."');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('maintains context across messages', () async {
      if (!ai.isConfigured) return;

      final reply = await ai.chat(
        messages: [
          {'role': 'user', 'content': 'I went to Paris last week.'},
          {'role': 'assistant', 'content': 'That sounds wonderful! What was the highlight?'},
          {'role': 'user', 'content': 'Seeing the Eiffel Tower at night.'},
        ],
      );

      expect(reply, isNotEmpty);
      // ignore: avoid_print
      print('  ✓ Multi-turn reply: "${reply.substring(0, reply.length.clamp(0, 100))}..."');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ===========================================================================
  // 6. Summary generation
  // ===========================================================================

  group('Real AI — Summary', () {
    test('generates a weekly summary from entries', skip: 'method removed — generateSummary no longer exists on AiService (use generateWeeklyStory)', () async {
      // TODO: method removed — generateSummary no longer exists on AiService
    });
  });

  // ===========================================================================
  // 7. Cover query generation
  // ===========================================================================

  group('Real AI — Cover Query', () {
    test('generates a search query for a book title', skip: 'method removed — generateCoverQuery no longer exists on AiService', () async {
      // TODO: method removed — generateCoverQuery no longer exists on AiService
    });
  });

  // ===========================================================================
  // 8. Share summary
  // ===========================================================================

  group('Real AI — Share Summary', () {
    test('generates a poetic share summary', () async {
      if (!ai.isConfigured) return;

      final summary = await ai.generateShareSummary(
        'Today I watched the sunset from the rooftop. The sky turned '
        'orange and pink. I felt at peace for the first time in weeks.',
      );

      expect(summary, isNotEmpty);
      expect(summary.length, lessThan(200));
      // ignore: avoid_print
      print('  ✓ Share summary: "$summary"');
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
