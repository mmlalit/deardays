import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/services/encryption/encryption_service.dart';

/// End-to-end test simulating the full auth + journal entry flow.
///
/// This tests the core encryption pipeline without requiring Supabase:
/// 1. User signs up -> salt generated
/// 2. Key derived from password + salt
/// 3. Journal entry encrypted with derived key
/// 4. Entry stored (simulated)
/// 5. Entry retrieved and decrypted
/// 6. Logout clears key
/// 7. Re-login re-derives key and decrypts again
void main() {
  late EncryptionService encryption;

  setUp(() {
    encryption = EncryptionService();
    encryption.clearKey();
  });

  group('E2E: Sign Up -> Write Entry -> Logout -> Login -> Read Entry', () {
    test('full flow works correctly', () async {
      // === STEP 1: Sign Up ===
      // Server generates a salt (simulated)
      final salt = encryption.generateSalt();
      const password = 'MySecureP@ssw0rd!';

      // === STEP 2: Derive encryption key ===
      final key = await encryption.deriveKey(password, salt);
      encryption.setKey(key);
      expect(encryption.currentKey, isNotNull);

      // === STEP 3: Write a journal entry ===
      const journalEntry = '''
March 7, 2026

The morning light crept through the curtains in that gentle way it does
when spring is just beginning to remember itself. I sat by the window
with my coffee, watching the world slowly wake up.

Mood: Grateful
Location: Home
''';

      final encryptedContent = encryption.encryptText(journalEntry, key);
      expect(encryptedContent, isNot(equals(journalEntry)));
      expect(encryptedContent.contains('morning'), isFalse);
      expect(encryptedContent.contains('coffee'), isFalse);

      // Also encrypt the raw voice transcript
      const voiceTranscript = 'Today was really nice, I had coffee by the window...';
      final encryptedVoice = encryption.encryptText(voiceTranscript, key);

      // === STEP 4: Simulate storing to DB ===
      // (In real app, these go to Supabase journal_entries table)
      final storedEntry = {
        'encrypted_content': encryptedContent,
        'encrypted_raw_content': encryptedVoice,
        'mood': 'great',
        'entry_date': '2026-03-07',
        'has_voice': true,
      };

      // === STEP 5: Read back and decrypt ===
      final decryptedContent = encryption.decryptText(
        storedEntry['encrypted_content'] as String,
        key,
      );
      expect(decryptedContent, equals(journalEntry));

      final decryptedVoice = encryption.decryptText(
        storedEntry['encrypted_raw_content'] as String,
        key,
      );
      expect(decryptedVoice, equals(voiceTranscript));

      // === STEP 6: Logout — key wiped ===
      encryption.clearKey();
      expect(encryption.currentKey, isNull);

      // Cannot decrypt without key
      expect(
        () => encryption.decryptText(encryptedContent, 'invalid-key'),
        throwsA(anything),
      );

      // === STEP 7: Re-login — re-derive key from same password + salt ===
      final reLoginKey = await encryption.deriveKey(password, salt);
      encryption.setKey(reLoginKey);

      // Key should be identical to original
      expect(reLoginKey, equals(key));

      // Decrypt stored entry again
      final reDecrypted = encryption.decryptText(encryptedContent, reLoginKey);
      expect(reDecrypted, equals(journalEntry));
    });

    test('wrong password cannot decrypt entries', () async {
      final salt = encryption.generateSalt();
      final correctKey = await encryption.deriveKey('correctPassword', salt);

      const entry = 'My secret thoughts about the day.';
      final encrypted = encryption.encryptText(entry, correctKey);

      // Attacker tries with wrong password
      final wrongKey = await encryption.deriveKey('wrongPassword', salt);
      expect(wrongKey, isNot(equals(correctKey)));

      expect(
        () => encryption.decryptText(encrypted, wrongKey),
        throwsA(isA<EncryptionException>()),
      );
    });

    test('multiple entries with same key all decrypt correctly', () async {
      final salt = encryption.generateSalt();
      final key = await encryption.deriveKey('testPassword', salt);

      final entries = List.generate(10, (i) => 'Journal entry #$i: Today was day $i.');
      final encrypted = entries.map((e) => encryption.encryptText(e, key)).toList();

      // All ciphertexts should be unique (random IV)
      expect(encrypted.toSet().length, equals(10));

      // All should decrypt correctly
      for (int i = 0; i < entries.length; i++) {
        final decrypted = encryption.decryptText(encrypted[i], key);
        expect(decrypted, equals(entries[i]));
      }
    });
  });
}
