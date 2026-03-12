import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:deardays/features/checkin/data/models/chat_message.dart';
import 'package:deardays/features/checkin/data/models/conversation_section.dart';

ChatMessage makeMsg(String id, String text, {bool isUser = true}) =>
    ChatMessage(
      id: id,
      text: text,
      isUser: isUser,
      timestamp: DateTime(2025, 1, 1),
    );

ConversationSection makeSection(String id, List<ChatMessage> messages,
        {String? mood}) =>
    ConversationSection(
      id: id,
      startTime: DateTime(2025, 1, 1),
      mood: mood,
      messages: messages,
    );

void main() {
  group('CheckInState — defaults', () {
    test('initial state has no mood and isFirstCheckInToday = true', () {
      final state = CheckInState();
      expect(state.currentMood, isNull);
      expect(state.isFirstCheckInToday, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.sections, isEmpty);
    });

    test('loadedDate defaults to today', () {
      final before = DateTime.now();
      final state = CheckInState();
      final after = DateTime.now();
      expect(state.loadedDate.millisecondsSinceEpoch,
          greaterThanOrEqualTo(before.millisecondsSinceEpoch - 1000));
      expect(state.loadedDate.millisecondsSinceEpoch,
          lessThanOrEqualTo(after.millisecondsSinceEpoch + 1000));
    });
  });

  group('CheckInState — copyWith', () {
    test('updates currentMood', () {
      final state = CheckInState().copyWith(currentMood: 'great');
      expect(state.currentMood, 'great');
    });

    test('updates isLoading', () {
      final state = CheckInState().copyWith(isLoading: true);
      expect(state.isLoading, isTrue);
    });

    test('updates isFirstCheckInToday to false', () {
      final state = CheckInState().copyWith(isFirstCheckInToday: false);
      expect(state.isFirstCheckInToday, isFalse);
    });

    test('clears error when null passed', () {
      final withError = CheckInState().copyWith(error: 'oops');
      final cleared = withError.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('preserves unchanged fields', () {
      final original = CheckInState(
        currentMood: 'good',
        isFirstCheckInToday: false,
      );
      final updated = original.copyWith(isLoading: true);
      expect(updated.currentMood, 'good');
      expect(updated.isFirstCheckInToday, isFalse);
      expect(updated.isLoading, isTrue);
    });
  });

  group('CheckInState — allMessages', () {
    test('returns empty list when sections is empty', () {
      expect(CheckInState().allMessages, isEmpty);
    });

    test('returns messages from a single section', () {
      final section = makeSection('s1', [makeMsg('m1', 'Hello')]);
      final state = CheckInState(sections: [section]);
      expect(state.allMessages.length, 1);
      expect(state.allMessages.first.text, 'Hello');
    });

    test('flattens messages across multiple sections', () {
      final s1 = makeSection('s1', [makeMsg('m1', 'First')]);
      final s2 = makeSection('s2', [
        makeMsg('m2', 'Second'),
        makeMsg('m3', 'Third', isUser: false),
      ]);
      final state = CheckInState(sections: [s1, s2]);
      expect(state.allMessages.length, 3);
      expect(state.allMessages.map((m) => m.text).toList(),
          ['First', 'Second', 'Third']);
    });
  });

  group('CheckInState — activeSection', () {
    test('returns null when sections is empty', () {
      expect(CheckInState().activeSection, isNull);
    });

    test('returns the last section', () {
      final s1 = makeSection('s1', []);
      final s2 = makeSection('s2', [], mood: 'great');
      final state = CheckInState(sections: [s1, s2]);
      expect(state.activeSection?.id, 's2');
      expect(state.activeSection?.mood, 'great');
    });
  });

  group('CheckInState — isViewingToday', () {
    test('returns true when loadedDate is today', () {
      final state = CheckInState(loadedDate: DateTime.now());
      expect(state.isViewingToday, isTrue);
    });

    test('returns false when loadedDate is yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final state = CheckInState(loadedDate: yesterday);
      expect(state.isViewingToday, isFalse);
    });
  });

  group('ConversationSection — copyWith', () {
    test('updates messages without mutating original', () {
      final original = makeSection('s1', []);
      final updated = original.copyWith(messages: [makeMsg('m1', 'Hi')]);
      expect(updated.messages.length, 1);
      expect(original.messages, isEmpty);
    });

    test('updates mood', () {
      final section = makeSection('s1', [], mood: 'okay');
      expect(section.copyWith(mood: 'great').mood, 'great');
    });
  });

  group('ChatMessage — constructor', () {
    test('stores fields correctly', () {
      final ts = DateTime(2025, 6, 1, 9, 0);
      final msg = ChatMessage(
        id: 'msg-1',
        text: 'Good morning',
        isUser: false,
        timestamp: ts,
        isVoice: true,
      );
      expect(msg.id, 'msg-1');
      expect(msg.text, 'Good morning');
      expect(msg.isUser, isFalse);
      expect(msg.isVoice, isTrue);
      expect(msg.timestamp, ts);
    });

    test('isVoice defaults to false', () {
      expect(makeMsg('x', 'hi').isVoice, isFalse);
    });
  });

  group('ChatMessage — JSON round-trip', () {
    test('toJson / fromJson preserves all fields', () {
      final original = ChatMessage(
        id: 'msg-1',
        text: 'Hello',
        isUser: true,
        timestamp: DateTime(2025, 6, 1, 12, 0),
      );
      final restored = ChatMessage.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.text, original.text);
      expect(restored.isUser, original.isUser);
      expect(restored.isVoice, original.isVoice);
    });
  });
}
