// Addressing for the UI event bus.
//
// The bug these pin: the composer's own check compared `parentMessageId` only
// when BOTH maps carried the key, and the parent-conversation composer omits
// it — so nothing that distinguished a conversation from a thread on it was
// ever compared, and a sticker keyboard or mention list raised in a thread
// opened in the parent conversation beside it too. The message list had the
// mirror-image bug: it never read `parentMessageId` at all.

import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/utils/ui_event_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('uiEventTargets — thread vs conversation', () {
    // The regression itself, in both directions.
    test('a thread panel does not target the parent conversation', () {
      expect(
        uiEventTargets(
          {'parentMessageId': 42, 'uid': 'U'},
          {'uid': 'U'},
          nullTargetsAll: true,
        ),
        isFalse,
      );
    });

    test('a conversation panel does not target a thread on it', () {
      expect(
        uiEventTargets(
          {'uid': 'U'},
          {'parentMessageId': 42, 'uid': 'U'},
          nullTargetsAll: true,
        ),
        isFalse,
      );
    });

    test(
      'two different threads on one conversation do not target each other',
      () {
        expect(
          uiEventTargets(
            {'parentMessageId': 42, 'uid': 'U'},
            {'parentMessageId': 43, 'uid': 'U'},
            nullTargetsAll: true,
          ),
          isFalse,
        );
      },
    );

    test('the same thread targets itself', () {
      expect(
        uiEventTargets(
          {'parentMessageId': 42, 'uid': 'U'},
          {'parentMessageId': 42, 'uid': 'U'},
          nullTargetsAll: true,
        ),
        isTrue,
      );
    });

    test('the same conversation targets itself', () {
      expect(
        uiEventTargets({'uid': 'U'}, {'uid': 'U'}, nullTargetsAll: true),
        isTrue,
      );
    });

    test('an explicit parentMessageId of 0 equals an absent one', () {
      expect(
        uiEventTargets(
          {'parentMessageId': 0, 'uid': 'U'},
          {'uid': 'U'},
          nullTargetsAll: true,
        ),
        isTrue,
      );
    });

    test('a numeric string parentMessageId is read as its number', () {
      expect(
        uiEventTargets(
          {'parentMessageId': '42', 'uid': 'U'},
          {'parentMessageId': 42, 'uid': 'U'},
          nullTargetsAll: true,
        ),
        isTrue,
      );
    });

    test('an unparseable parentMessageId falls back to the conversation', () {
      expect(uiEventThreadOf({'parentMessageId': 'nope'}), 0);
      expect(uiEventThreadOf({'parentMessageId': null}), 0);
      expect(uiEventThreadOf(const {}), 0);
    });
  });

  group('uiEventTargets — conversations', () {
    test('different users do not target each other', () {
      expect(
        uiEventTargets({'uid': 'A'}, {'uid': 'B'}, nullTargetsAll: true),
        isFalse,
      );
    });

    test('a group and a user with the same id are different conversations', () {
      expect(
        uiEventTargets({'guid': 'X'}, {'uid': 'X'}, nullTargetsAll: true),
        isFalse,
      );
    });

    test('keys unrelated to addressing are ignored', () {
      // AI panels carry an `extension` key alongside the address.
      expect(
        uiEventTargets(
          {'uid': 'U', 'extension': 'smart-replies'},
          {'uid': 'U'},
          nullTargetsAll: true,
        ),
        isTrue,
      );
    });

    test('an id naming no conversation still obeys the thread check', () {
      expect(
        uiEventTargets(
          {'parentMessageId': 42},
          {'parentMessageId': 42, 'uid': 'U'},
          nullTargetsAll: true,
        ),
        isTrue,
      );
      expect(
        uiEventTargets(
          {'parentMessageId': 42},
          {'uid': 'U'},
          nullTargetsAll: true,
        ),
        isFalse,
      );
    });

    test('an empty id string names no conversation', () {
      expect(uiEventConversationOf({'uid': ''}), isNull);
      expect(uiEventConversationOf(const {}), isNull);
      expect(uiEventConversationOf({'guid': 'G'}), 'guid:G');
      expect(uiEventConversationOf({'uid': 'U'}), 'uid:U');
    });

    test(
      'a malformed id carrying both keys resolves the same on both sides',
      () {
        // The AI views used to publish guid AND uid set to the same value.
        const malformed = {'uid': 'X', 'guid': 'X'};
        expect(uiEventConversationOf(malformed), 'guid:X');
        expect(
          uiEventTargets(malformed, malformed, nullTargetsAll: true),
          isTrue,
        );
      },
    );
  });

  group('uiEventTargets — null handling', () {
    test('an unaddressed event follows nullTargetsAll', () {
      expect(uiEventTargets(null, {'uid': 'U'}, nullTargetsAll: true), isTrue);
      expect(
        uiEventTargets(null, {'uid': 'U'}, nullTargetsAll: false),
        isFalse,
      );
    });

    test('a component with no id is targeted by nothing addressed', () {
      expect(uiEventTargets({'uid': 'U'}, null, nullTargetsAll: true), isFalse);
    });
  });

  group('buildUiEventId', () {
    test('omits parentMessageId when it is 0', () {
      expect(buildUiEventId(uid: 'U'), {'uid': 'U'});
      expect(buildUiEventId(uid: 'U', parentMessageId: 0), {'uid': 'U'});
    });

    test('includes parentMessageId when it names a thread', () {
      expect(buildUiEventId(uid: 'U', parentMessageId: 42), {
        'parentMessageId': 42,
        'uid': 'U',
      });
    });

    test('prefers a group over a user and never publishes both', () {
      final id = buildUiEventId(uid: 'U', guid: 'G');
      expect(id.containsKey('uid'), isFalse);
      expect(id['guid'], 'G');
    });

    test('an empty or absent name is not published', () {
      expect(buildUiEventId(uid: '', guid: ''), isEmpty);
      expect(buildUiEventId(), isEmpty);
    });

    test('round-trips through the matcher', () {
      final parent = buildUiEventId(uid: 'U');
      final thread = buildUiEventId(uid: 'U', parentMessageId: 42);
      expect(uiEventTargets(thread, parent, nullTargetsAll: true), isFalse);
      expect(uiEventTargets(thread, thread, nullTargetsAll: true), isTrue);
      expect(uiEventTargets(parent, parent, nullTargetsAll: true), isTrue);
    });
  });
}
