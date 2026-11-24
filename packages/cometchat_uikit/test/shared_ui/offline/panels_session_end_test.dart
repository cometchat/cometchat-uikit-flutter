/// Pinned and saved panels on session end and cache reset (G8, ENG-41569).
///
/// With offline on each panel reads through its two-phase seam (scripted
/// here). The hub is driven the way a logout produces it: offline on during
/// the session, the SDK then reports offline off, and only then do the logout
/// signals arrive.
///
///   flutter test test/shared_ui/offline/panels_session_end_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/pinned_messages_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/saved_messages_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TextMessage _m(int id) => TextMessage(
  id: id,
  text: 'row$id',
  sender: User(uid: 'bob', name: 'Bob'),
  receiverUid: 'alice',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
)..sentAt = DateTime.utc(2026, 1, 1, 0, 0, id);

final _hub = OfflineHub.instance;

void _logout() {
  CometChat.debugSetOfflineEnabledOverride(false);
  _hub.onKitLogout();
  _hub.debugLogout();
}

void _cacheReset() =>
    _hub.debugCacheReset(OfflineCacheResetReason.encryptionChanged, 0);

/// Each two-phase read answers with the next scripted stream.
final _answers = <Stream<TwoPhaseResult<BaseMessage>>>[];
int _reads = 0;

Stream<TwoPhaseResult<BaseMessage>> _phases(
  List<TwoPhaseResult<BaseMessage>> events,
) => Stream.fromIterable(events);

Stream<TwoPhaseResult<BaseMessage>> _read(MessagesRequest _) {
  _reads++;
  return _answers.removeAt(0);
}

Finder _row(int id) => find.textContaining('row$id', findRichText: true);

void main() {
  final panels = <String, Widget Function()>{
    'pinned': () => CometChatPinnedMessages(
      user: User(uid: 'bob', name: 'bob'),
    ),
    'saved': () => const CometChatSavedMessages(),
  };

  setUp(() {
    _reads = 0;
    _answers.clear();
    PinnedMessagesOffline.debugFetchOverride = _read;
    SavedMessagesOffline.debugFetchOverride = _read;
    _hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    _hub.debugLoginSuccess('alice'); // offline on during this session
  });

  tearDown(() {
    PinnedMessagesOffline.debugFetchOverride = null;
    SavedMessagesOffline.debugFetchOverride = null;
    CometChat.debugSetOfflineEnabledOverride(null);
  });

  for (final MapEntry(key: name, value: build) in panels.entries) {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: build(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    Future<void> settle(WidgetTester tester) =>
        tester.pump(const Duration(milliseconds: 50));

    group('$name panel', () {
      testWidgets('sessionEnded clears rows and resets paging', (tester) async {
        _answers.add(
          _phases([
            Server([_m(1)]),
          ]),
        );
        await pump(tester);
        expect(_row(1), findsOneWidget);

        _logout();
        await settle(tester);

        expect(_row(1), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // Nothing reads again until the panel is asked to.
        expect(_reads, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('sessionEnded drops the result of a read in flight', (
        tester,
      ) async {
        final pending = StreamController<TwoPhaseResult<BaseMessage>>();
        _answers.add(pending.stream);
        await pump(tester);

        _logout();
        await settle(tester);
        pending.add(Server([_m(1)]));
        await pending.close();
        await settle(tester);

        expect(_row(1), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('stale event is ignored', (tester) async {
        _answers.add(
          _phases([
            Server([_m(1)]),
          ]),
        );
        await pump(tester);

        // Published, then the session ends before it is delivered: it
        // belongs to the old session, so it must not read again.
        _cacheReset();
        _logout();
        await settle(tester);

        expect(_reads, 1);
        expect(_row(1), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('cacheReset clears then reloads once', (tester) async {
        final pending = StreamController<TwoPhaseResult<BaseMessage>>();
        _answers
          ..add(
            _phases([
              Server([_m(1)]),
            ]),
          )
          ..add(pending.stream);
        await pump(tester);
        expect(_row(1), findsOneWidget);

        _cacheReset();
        await settle(tester);
        // Cleared while the reload reads.
        expect(_row(1), findsNothing);
        expect(_reads, 2);

        pending.add(Server([_m(2)]));
        await pending.close();
        await settle(tester);
        expect(_row(2), findsOneWidget);
        expect(_reads, 2);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('cacheReset reload failure over rows is quiet', (
        tester,
      ) async {
        _answers
          ..add(
            _phases([
              Server([_m(1)]),
            ]),
          )
          ..add(
            _phases([
              Cached([_m(5)]),
              PhaseError(CometChatException('ERR_INTERNAL_SERVER', 'x', 'x')),
            ]),
          );
        await pump(tester);

        _cacheReset();
        await settle(tester);

        expect(_row(5), findsOneWidget);
        expect(find.text(TranslationsEn().oops), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('offline off: no change', (tester) async {
        _hub.debugReset();
        CometChat.debugSetOfflineEnabledOverride(false);
        _hub.debugLoginSuccess('alice');
        await pump(tester);
        final before = find.text(TranslationsEn().oops).evaluate().length;

        _cacheReset();
        _hub.onKitLogout();
        _hub.debugLogout();
        await settle(tester);

        expect(find.text(TranslationsEn().oops).evaluate().length, before);
        expect(_reads, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('close cancels the hub subscription', (tester) async {
        _answers.add(_phases([const Server([])]));
        await pump(tester);
        expect(_hub.debugHasListeners, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(_hub.debugHasListeners, isFalse);
      });
    });
  }
}
