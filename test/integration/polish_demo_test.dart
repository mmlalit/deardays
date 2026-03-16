library;

/// Quick demo: send a spelling-mistake conversation to AI and print both
/// the light-polished version and the full narrative story.
///
/// Run:
///   flutter test test/integration/polish_demo_test.dart --reporter expanded \
///     --dart-define=AI_API_URL=https://mcmlawztwyrjcwmieciw.supabase.co/functions/v1

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/config/supabase_config.dart';
import 'package:deardays/services/ai/ai_service.dart';

class _InMemoryStorage extends GotrueAsyncStorage {
  final _map = <String, String>{};
  @override Future<String?> getItem({required String key}) async => _map[key];
  @override Future<void> setItem({required String key, required String value}) async => _map[key] = value;
  @override Future<void> removeItem({required String key}) async => _map.remove(key);
}

const _raw = '''
ast weak, our famly goed to the beach. It was so sunny and hot! My dad forgotted the sunscream, so he got very red like a lobster. Me and my brother bilt a huge sandcastel, but a big wave comed and wash it away. We laughted so hard! Later, we ated ice cream, but my sister droped her cone on the sand. She cried a littel, but mom bited her own ice cream in half to share. It was a verry fun day, even with the mistake. We did not want to go home, but the sun was downing. Best day ever!
''';

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
        pkceAsyncStorage: _InMemoryStorage(),
      ),
    );

    final authResponse = await Supabase.instance.client.auth.signInWithPassword(
      email: 'mmlalit03@gmail.com',
      password: '123456',
    );

    if (authResponse.user == null) {
      fail('Sign-in failed — check credentials or Supabase project.');
    }
    // ignore: avoid_print
    print('=== Signed in as: ${authResponse.user!.email} ===');
    // ignore: avoid_print
    print('=== Session token present: ${authResponse.session?.accessToken != null} ===');

    ai = AiService();
  });

  tearDownAll(() async {
    await Supabase.instance.client.auth.signOut();
  });

  test('light polish — fixes spelling, keeps voice', () async {
    if (!ai.isConfigured) {
      print('⚠ AI_API_URL not set — skipping');
      return;
    }

    print('\n══════════════════════════════════════════');
    print('ORIGINAL (with mistakes):');
    print('──────────────────────────────────────────');
    print(_raw.trim());

    // Cold start
    final t0cold = DateTime.now();
    await ai.lightPolish(_raw);
    final cold = DateTime.now().difference(t0cold).inMilliseconds;

    // Warm
    final t0 = DateTime.now();
    final polished = await ai.lightPolish(_raw);
    final ms = DateTime.now().difference(t0).inMilliseconds;

    print('\n══════════════════════════════════════════');
    print('LIGHT POLISH  ⏱ cold=${cold}ms  warm=${ms}ms');
    print('──────────────────────────────────────────');
    print(polished.trim());
    print('══════════════════════════════════════════\n');

    expect(polished, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('narrative polish — full memoir-style story', () async {
    if (!ai.isConfigured) {
      print('⚠ AI_API_URL not set — skipping');
      return;
    }

    // Cold start
    final t0cold = DateTime.now();
    await ai.polishNarrative(_raw, style: 'memoir');
    final cold = DateTime.now().difference(t0cold).inMilliseconds;

    // Warm
    final t0 = DateTime.now();
    final story = await ai.polishNarrative(_raw, style: 'memoir');
    final ms = DateTime.now().difference(t0).inMilliseconds;

    print('\n══════════════════════════════════════════');
    print('MEMOIR STORY  ⏱ cold=${cold}ms  warm=${ms}ms');
    print('──────────────────────────────────────────');
    print(story.trim());
    print('══════════════════════════════════════════\n');

    expect(story, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('chat — multi-turn check-in conversation', () async {
    if (!ai.isConfigured) {
      print('⚠ AI_API_URL not set — skipping');
      return;
    }

    final conversation = [
      {'role': 'user', 'content': 'I had a really tough day at work today.'},
      {'role': 'assistant', 'content': 'What made it feel tough?'},
      {'role': 'user', 'content': 'My boss kept changing requirements last minute and i had to redo everything twice. felt like nothing i do is ever good enuf.'},
    ];

    print('\n══════════════════════════════════════════');
    print('CONVERSATION:');
    print('──────────────────────────────────────────');
    for (final m in conversation) {
      print('${m['role']!.toUpperCase()}: ${m['content']}');
    }

    // Cold start
    final t0cold = DateTime.now();
    await ai.chat(messages: conversation, mood: 'tough');
    final cold = DateTime.now().difference(t0cold).inMilliseconds;

    // Warm
    final t0 = DateTime.now();
    final reply = await ai.chat(
      messages: conversation,
      mood: 'tough',
    );
    final ms = DateTime.now().difference(t0).inMilliseconds;

    print('\nAI REPLY  ⏱ cold=${cold}ms  warm=${ms}ms');
    print('──────────────────────────────────────────');
    print(reply.trim());
    print('══════════════════════════════════════════\n');

    expect(reply, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 40)));
}
