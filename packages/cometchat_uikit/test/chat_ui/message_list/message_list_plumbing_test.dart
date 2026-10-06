/// Message-list operations, states and the long tail —
/// Track 3 TEST3 / construction coverage (ENG-38684).
///
/// Twelve exported classes that no test had ever constructed. Most of them sit
/// under the message list: [MessageOperation], which is how the animated list
/// is told what changed, the two unread-count states, the search-results
/// state, one event and the local data-source exception. The rest are the
/// stragglers from other areas that do not justify a file of their own —
/// the audio-bubble state pair, the sticker model and [AIOptionsStyle].
///
/// [MessageOperation] earns most of the cases. It is a sealed-ish value with
/// five named constructors and seven fields, and each constructor fills a
/// different subset — so the interesting property is what each one leaves
/// null, because the animated list reads `index`, `oldMessage` and `animated`
/// off whichever one it is handed.
///
///   flutter test test/chat_ui/message_list/message_list_plumbing_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMessage extends Fake implements BaseMessage {
  _FakeMessage(this.id);
  @override
  final int id;
  @override
  String toString() => 'msg$id';
}

class _FakeEntity extends Fake implements MessageEntity {
  _FakeEntity(this.id);
  @override
  final String id;
}

void main() {
  // ===========================================================================
  group('MessageOperation', () {
    final a = _FakeMessage(1);
    final b = _FakeMessage(2);

    test('insert carries one message, an index, and animates by default', () {
      final op = MessageOperation.insert(a, 3);

      expect(op.type, MessageOperationType.insert);
      expect(op.message, same(a));
      expect(op.index, 3);
      expect(op.animated, isTrue);
      expect(op.messages, isNull);
      expect(op.oldMessage, isNull);
      expect(op.oldMessages, isNull);
    });

    test('insert can be told not to animate — a bulk prepend does that', () {
      expect(MessageOperation.insert(a, 0, animated: false).animated, isFalse);
    });

    test('insertAll carries the list and leaves the single slot empty', () {
      final op = MessageOperation.insertAll([a, b], 0);

      expect(op.type, MessageOperationType.insertAll);
      expect(op.messages, [a, b]);
      expect(op.message, isNull);
      expect(op.index, 0);
      expect(op.animated, isTrue);
    });

    test('update carries both sides and never animates', () {
      // The animation is suppressed deliberately: an in-place edit that
      // animated would look like a new message arriving.
      final op = MessageOperation.update(a, b, 5);

      expect(op.type, MessageOperationType.update);
      expect(op.oldMessage, same(a));
      expect(op.message, same(b));
      expect(op.index, 5);
      expect(op.animated, isFalse);
    });

    test('remove carries the message being removed and its index', () {
      final op = MessageOperation.remove(a, 2);

      expect(op.type, MessageOperationType.remove);
      expect(op.message, same(a));
      expect(op.index, 2);
      expect(op.animated, isTrue);
      expect(MessageOperation.remove(a, 2, animated: false).animated, isFalse);
    });

    test('set replaces the whole list and has no index', () {
      final op = MessageOperation.set([a, b]);

      expect(op.type, MessageOperationType.set);
      expect(op.messages, [a, b]);
      expect(op.index, isNull, reason: 'a wholesale replace has no position');
      expect(op.oldMessages, isNull);
    });

    test('set can carry the previous list, which is what a diff needs', () {
      final op = MessageOperation.set([b], oldMessages: [a], animated: false);

      expect(op.oldMessages, [a]);
      expect(op.messages, [b]);
      expect(op.animated, isFalse);
    });

    test('every constructor produces its own type, and the enum is fully '
        'used', () {
      final types = <MessageOperationType>{
        MessageOperation.insert(a, 0).type,
        MessageOperation.insertAll([a], 0).type,
        MessageOperation.update(a, b, 0).type,
        MessageOperation.remove(a, 0).type,
        MessageOperation.set([a]).type,
      };

      expect(types, MessageOperationType.values.toSet());
    });

    test(
      'toString names the type, index and animation but not the payload',
      () {
        final text = MessageOperation.insert(a, 3).toString();

        expect(text, contains('insert'));
        expect(text, contains('index: 3'));
        expect(text, contains('animated: true'));
      },
    );
  });

  // ===========================================================================
  group('unread-count states', () {
    test('a success carries the count and distinguishes by it', () {
      expect(const UnreadCountSuccess(3).count, 3);
      expect(const UnreadCountSuccess(3), const UnreadCountSuccess(3));
      expect(const UnreadCountSuccess(3), isNot(const UnreadCountSuccess(4)));
      expect(const UnreadCountSuccess(3).props, [3]);
    });

    test('zero is a real count, not an absence', () {
      // The badge hides at zero, so this state has to be distinguishable from
      // "not loaded yet" rather than collapsing into it.
      expect(const UnreadCountSuccess(0).count, 0);
      expect(const UnreadCountSuccess(0), isNot(const UnreadCountSuccess(1)));
    });

    test('an error carries its message and is never equal to a success', () {
      expect(const UnreadCountError('boom').message, 'boom');
      expect(const UnreadCountError('boom'), const UnreadCountError('boom'));
      expect(
        const UnreadCountError('boom'),
        isNot(const UnreadCountError('other')),
      );
      expect(
        const UnreadCountError('boom'),
        isNot(equals(const UnreadCountSuccess(0))),
      );
    });
  });

  // ===========================================================================
  group('MessageListSearchResults', () {
    test('carries the results, the query that produced them and emptiness', () {
      final state = MessageListSearchResults(
        searchResults: [_FakeEntity('m1')],
        query: 'hello',
        isEmpty: false,
      );

      expect(state.searchResults, hasLength(1));
      expect(state.query, 'hello');
      expect(state.isEmpty, isFalse);
    });

    test('the query is part of identity — the same results for a different '
        'query is a different state', () {
      final results = [_FakeEntity('m1')];

      expect(
        MessageListSearchResults(
          searchResults: results,
          query: 'a',
          isEmpty: false,
        ),
        isNot(
          MessageListSearchResults(
            searchResults: results,
            query: 'b',
            isEmpty: false,
          ),
        ),
      );
    });

    test('an empty result set still names the query it came from', () {
      const state = MessageListSearchResults(
        searchResults: [],
        query: 'nothing matches',
        isEmpty: true,
      );

      expect(state.isEmpty, isTrue);
      expect(state.query, 'nothing matches');
    });

    test('FIXED — its supertype is nameable from the barrel', () {
      // Two public classes were called MessageListState. The barrel exported
      // the concrete chat_ui bloc state, and the shared_ui base — the actual
      // supertype of this state — was hidden from the shared barrel to avoid
      // the clash, so it was reachable from neither. `MessageListState s =
      // searchResults;` did not compile and `state is MessageListState` was
      // always false.
      //
      // The base is now MessageListStateBase and the hide is gone.
      // ENG-39100.
      const state = MessageListSearchResults(
        searchResults: [],
        query: 'q',
        isEmpty: true,
      );

      final MessageListStateBase base = state;
      expect(base, same(state));
      expect(state, isA<MessageListStateBase>());

      // The concrete bloc state keeps the unqualified name, so no existing
      // call site changes meaning.
      expect(const MessageListState().status, MessageListStatus.initial);
    });
  });

  // ===========================================================================
  group('LoadLastAgentConversation', () {
    test('carries the conversation it is loading for', () {
      const event = LoadLastAgentConversation(conversationWith: 'u1');

      expect(event.conversationWith, 'u1');
      expect(event.props, ['u1']);
      expect(event, const LoadLastAgentConversation(conversationWith: 'u1'));
      expect(
        event,
        isNot(const LoadLastAgentConversation(conversationWith: 'u2')),
      );
    });
  });

  // ===========================================================================
  group('MessageListLocalDataSourceException', () {
    test('carries a message and optionally the cause', () {
      const e = MessageListLocalDataSourceException(message: 'no template');

      expect(e.message, 'no template');
      expect(e.originalException, isNull);
      expect(e, isA<Exception>());
      expect(e.toString(), contains('no template'));
    });

    test('wraps an original exception without losing it', () {
      final cause = Exception('cache miss');
      final e = MessageListLocalDataSourceException(
        message: 'lookup failed',
        originalException: cause,
      );

      expect(e.originalException, same(cause));
    });
  });

  // ===========================================================================
  group('AudioStateUpdate and AudioBubbleState', () {
    test('an update is a snapshot of one bubble at one moment', () {
      final update = AudioStateUpdate(
        id: 7,
        playState: PlayStates.playing,
        isInitializing: false,
        totalDuration: const Duration(seconds: 30),
        currentPosition: const Duration(seconds: 5),
      );

      expect(update.id, 7);
      expect(update.playState, PlayStates.playing);
      expect(update.isInitializing, isFalse);
      expect(update.totalDuration, const Duration(seconds: 30));
      expect(update.currentPosition, const Duration(seconds: 5));
    });

    test('a duration of null is the not-yet-loaded case', () {
      final update = AudioStateUpdate(
        id: 7,
        playState: PlayStates.init,
        isInitializing: true,
        totalDuration: null,
        currentPosition: Duration.zero,
      );

      expect(update.totalDuration, isNull);
      expect(update.isInitializing, isTrue);
      expect(update.playState, PlayStates.init);
    });

    test('a fresh bubble state starts at init, unstarted and unpositioned', () {
      final state = AudioBubbleState(
        id: 7,
        audioUrl: 'https://example.com/note.m4a',
        localPath: null,
      );

      expect(state.id, 7);
      expect(state.audioUrl, 'https://example.com/note.m4a');
      expect(state.localPath, isNull);
      expect(state.playState, PlayStates.init);
      expect(state.isInitializing, isFalse);
      expect(state.totalDuration, isNull);
      expect(state.currentPosition, Duration.zero);
      expect(state.controller, isNull);
      expect(state.stateStream, isNotNull);
    });

    test('localPath is mutable — the download fills it in later', () {
      final state = AudioBubbleState(id: 7, audioUrl: null, localPath: null)
        ..localPath = '/tmp/note.m4a';

      expect(state.localPath, '/tmp/note.m4a');
      expect(state.audioUrl, isNull, reason: 'a local-only note has no url');
    });

    test('PlayStates covers the four transitions the scrubber renders', () {
      expect(PlayStates.values, hasLength(4));
      expect(
        PlayStates.values,
        containsAll(<PlayStates>[
          PlayStates.init,
          PlayStates.playing,
          PlayStates.paused,
          PlayStates.stopped,
        ]),
      );
    });
  });

  // ===========================================================================
  group('Sticker', () {
    Map<String, dynamic> json() => <String, dynamic>{
      'id': 's1',
      'stickerOrder': '2',
      'stickerSetId': 'set1',
      'stickerUrl': 'https://example.com/s1.png',
      'stickerSetName': 'Smileys',
      'stickerSetOrder': '1',
      'stickerName': 'grin',
      'createdAt': '1700000000',
      'modifiedAt': '1700000001',
    };

    test('carries the sticker and its set', () {
      const sticker = Sticker(
        id: 's1',
        stickerOrder: 2,
        stickerSetId: 'set1',
        stickerUrl: 'https://example.com/s1.png',
        stickerSetName: 'Smileys',
        stickerSetOrder: 1,
        stickerName: 'grin',
      );

      expect(sticker.id, 's1');
      expect(sticker.stickerName, 'grin');
      expect(sticker.stickerSetName, 'Smileys');
      expect(sticker.createdAt, isNull);
      expect(sticker.modifiedAt, isNull);
    });

    test('fromJson parses the two orders out of strings', () {
      // Both order fields arrive as strings on the wire and are int.parse'd.
      final sticker = Sticker.fromJson(json());

      expect(sticker.stickerOrder, 2);
      expect(sticker.stickerSetOrder, 1);
      expect(sticker.stickerUrl, 'https://example.com/s1.png');
      expect(sticker.createdAt, '1700000000');
    });

    test('fromJson throws when an order is not a number', () {
      // Unguarded int.parse: a malformed payload takes down the whole sticker
      // keyboard rather than skipping one sticker.
      final bad = json()..['stickerOrder'] = 'not a number';

      expect(() => Sticker.fromJson(bad), throwsFormatException);
    });
  });

  // ===========================================================================
  group('AIOptionsStyle', () {
    // Every prop here is dead — cometchat_ai_option_sheet.dart declares
    // `aiOptionStyle` and never reads it (ENG-38977). These cases cover the
    // class's own plumbing so that wiring it up, or deleting it, is a visible
    // change rather than a silent one.
    test('is const-constructible with everything null', () {
      const style = AIOptionsStyle();

      expect(style.backgroundColor, isNull);
      expect(style.border, isNull);
      expect(style.borderRadius, isNull);
      expect(style.iconColor, isNull);
      expect(style.titleColor, isNull);
      expect(style.titleTextStyle, isNull);
    });

    test('copyWith replaces only what it is given', () {
      const base = AIOptionsStyle(
        backgroundColor: Color(0xFF111111),
        iconColor: Color(0xFF222222),
      );

      final copy = base.copyWith(iconColor: const Color(0xFF333333));

      expect(copy.backgroundColor, const Color(0xFF111111));
      expect(copy.iconColor, const Color(0xFF333333));
    });

    test('merge applies the other style on top', () {
      const base = AIOptionsStyle(backgroundColor: Color(0xFF111111));
      const other = AIOptionsStyle(titleColor: Color(0xFF444444));

      final merged = base.merge(other);

      expect(merged.backgroundColor, isNotNull);
      expect(merged.titleColor, const Color(0xFF444444));
      expect(base.merge(null), same(base));
    });

    test('of(context) returns a bare default and never reads the theme', () {
      // Documented here because it is the reason a theme extension for this
      // class can never take effect.
      expect(AIOptionsStyle.of(_NoContext()), isA<AIOptionsStyle>());
      expect(AIOptionsStyle.of(_NoContext()).backgroundColor, isNull);
    });

    testWidgets('lerp at the endpoints returns the endpoints', (tester) async {
      const a = AIOptionsStyle(backgroundColor: Color(0xFF000000));
      const b = AIOptionsStyle(backgroundColor: Color(0xFFFFFFFF));

      expect(a.lerp(b, 0).backgroundColor, a.backgroundColor);
      expect(a.lerp(b, 1).backgroundColor, b.backgroundColor);
      expect(a.lerp(null, 0.5), same(a));
    });
  });
}

/// `AIOptionsStyle.of` ignores its argument entirely, so this stands in for a
/// BuildContext without needing to pump anything — which is itself the point.
class _NoContext extends Fake implements BuildContext {}
