// W7 (ENG-41130): the pinned and saved panels read in two rounds when offline
// is on (PR #23 README §3.9, BEH-PIN-02 / BEH-SAVE-02). Each page: cached copy
// at once, then the server page in its place, in server order; "load more"
// never repeats a message; a server error keeps the rows shown. Offline off
// keeps today's read (the two-phase read is never used).

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/pinned_messages_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/saved_messages_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';
import 'package:cometchat_chat_uikit/src/chat_sdk_listeners.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BaseMessage _m(int id) => BaseMessage(
  id: id,
  muid: 'm$id',
  receiverUid: 'bob',
  type: 'text',
  receiverType: 'user',
);

final _offline = CometChatException(
  'ERROR_NOT_CONNECTED',
  'offline',
  'offline',
);

typedef _Read =
    Future<void> Function(
      MessagesRequest request, {
      required int pageSize,
      required bool Function() isActive,
      required OfflinePanelRows onRows,
    });

class _Report {
  _Report(this.rows, this.done, this.failed, this.notConnected);
  final List<int> rows;
  final bool done;
  final bool failed;
  final bool notConnected;
  @override
  String toString() =>
      '$rows done=$done failed=$failed notConnected=$notConnected';
}

void main() {
  final panels =
      <
        String,
        (
          _Read,
          void Function(
            Stream<TwoPhaseResult<BaseMessage>> Function(MessagesRequest)?,
          ),
        )
      >{
        'pinned': (
          PinnedMessagesOffline.readAll,
          (f) => PinnedMessagesOffline.debugFetchOverride = f,
        ),
        'saved': (
          SavedMessagesOffline.readAll,
          (f) => SavedMessagesOffline.debugFetchOverride = f,
        ),
      };

  for (final MapEntry(key: name, value: (read, setOverride))
      in panels.entries) {
    group('$name panel', () {
      late List<List<TwoPhaseResult<BaseMessage>>> script;
      var reads = 0;

      setUp(() {
        reads = 0;
        setOverride((_) {
          final r = script[reads < script.length ? reads : script.length - 1];
          reads++;
          return Stream.fromIterable(r);
        });
      });
      tearDown(() => setOverride(null));

      Future<List<_Report>> run({int pageSize = 2}) async {
        final reports = <_Report>[];
        await read(
          (MessagesRequestBuilder()..pinned = true).build(),
          pageSize: pageSize,
          isActive: () => true,
          onRows:
              (rows, {required done, required failed, required notConnected}) =>
                  reports.add(
                    _Report(
                      [for (final m in rows) m.id],
                      done,
                      failed,
                      notConnected,
                    ),
                  ),
        );
        return reports;
      }

      test('cached page at once, then the server page in its place', () async {
        script = [
          [
            Cached([_m(1), _m(9)]),
            Server([_m(3), _m(1)]),
          ],
          [
            const Cached([]),
            Server([_m(5)]),
          ],
        ];
        final reports = await run();
        expect(reports.first.rows, [1, 9]);
        expect(reports[1].rows, [3, 1], reason: 'server order replaces');
        expect(reports.last.rows, [3, 1, 5]);
        expect(reports.last.done, isTrue);
      });

      test('load more never repeats; a page adding nothing ends it', () async {
        script = [
          [
            Server([_m(1), _m(2)]),
          ],
          [
            Server([_m(2), _m(3)]),
          ],
          // Re-delivery past the last page.
          [
            Server([_m(2), _m(3)]),
          ],
        ];
        final reports = await run();
        expect(reports.last.rows, [1, 2, 3]);
        expect(reports.last.done, isTrue);
        expect(reads, 3);
      });

      test('a server error after cached rows keeps them, no failure', () async {
        script = [
          [
            Cached([_m(1)]),
            PhaseError(_offline),
          ],
        ];
        final reports = await run();
        expect(reports.last.rows, [1]);
        expect(reports.last.done, isTrue);
        expect(reports.last.failed, isFalse);
      });

      test('an empty cached page then an error is today\'s failure', () async {
        script = [
          [const Cached([]), PhaseError(_offline)],
        ];
        final reports = await run();
        expect(reports.single.rows, isEmpty);
        expect(reports.single.failed, isTrue);
      });

      test(
        'D84 (3): a failure because the device is offline is marked, so '
        'the panel shows its offline state and reads again on reconnect',
        () async {
          script = [
            [PhaseError(CometChatException('ERR_CONNECTION', 'x', 'x'))],
          ];
          final reports = await run();
          expect(reports.single.failed, isTrue);
          expect(reports.single.notConnected, isTrue);
        },
      );

      test('D84 (4): any other failure is not marked', () async {
        script = [
          [PhaseError(CometChatException('ERR_TOO_MANY_REQUESTS', 'x', 'x'))],
        ];
        final reports = await run();
        expect(reports.single.failed, isTrue);
        expect(reports.single.notConnected, isFalse);
      });

      test('stops once the panel is gone', () async {
        script = [
          [
            Server([_m(1), _m(2)]),
          ],
        ];
        var calls = 0;
        await read(
          (MessagesRequestBuilder()..pinned = true).build(),
          pageSize: 2,
          isActive: () => calls++ == 0,
          onRows:
              (_, {required done, required failed, required notConnected}) {},
        );
        expect(reads, 1);
      });
    });
  }

  group('D84 offline state and reconnect', () {
    final listeners = <String, ConnectionListener>{};

    setUp(() {
      listeners.clear();
      ChatSdkListeners.debugAddConnectionListener = (id, l) =>
          listeners[id] = l;
      ChatSdkListeners.debugRemoveConnectionListener = listeners.remove;
    });

    tearDown(() {
      ChatSdkListeners.debugReset();
      PinnedMessagesOffline.debugFetchOverride = null;
      SavedMessagesOffline.debugFetchOverride = null;
      CometChat.debugSetOfflineEnabledOverride(null);
    });

    final panels = <String, Widget Function()>{
      'pinned': () => CometChatPinnedMessages(
        user: User(uid: 'bob', name: 'bob'),
      ),
      'saved': () => const CometChatSavedMessages(),
    };

    for (final MapEntry(key: name, value: build) in panels.entries) {
      Future<int Function()> pump(
        WidgetTester tester,
        List<List<TwoPhaseResult<BaseMessage>>> script,
      ) async {
        var reads = 0;
        Stream<TwoPhaseResult<BaseMessage>> read(MessagesRequest _) {
          final r = script[reads < script.length ? reads : script.length - 1];
          reads++;
          return Stream.fromIterable(r);
        }

        PinnedMessagesOffline.debugFetchOverride = read;
        SavedMessagesOffline.debugFetchOverride = read;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: build(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        return () => reads;
      }

      testWidgets('ON $name: offline with nothing to show is "Connect to load '
          'messages" with no Retry, and reads again once on reconnect', (
        tester,
      ) async {
        CometChat.debugSetOfflineEnabledOverride(true);
        final reads = await pump(tester, [
          [PhaseError(CometChatException('ERR_CONNECTION', 'x', 'x'))],
          [const Cached([]), const Server([])],
        ]);
        expect(
          find.text(TranslationsEn().connectToLoadMessages),
          findsOneWidget,
        );
        expect(find.text(TranslationsEn().oops), findsNothing);
        expect(find.text(TranslationsEn().retry), findsNothing);
        expect(reads(), 1);

        listeners.values.single.onConnected();
        await tester.pump(const Duration(milliseconds: 50));
        listeners.values.single.onConnected();
        await tester.pump(const Duration(milliseconds: 50));
        expect(reads(), 2);
        expect(find.text(TranslationsEn().connectToLoadMessages), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(listeners, isEmpty);
      });

      testWidgets('ON $name: a server error (not offline) is the error view '
          'and is not read again', (tester) async {
        CometChat.debugSetOfflineEnabledOverride(true);
        final reads = await pump(tester, [
          [PhaseError(CometChatException('ERR_TOO_MANY_REQUESTS', 'x', 'x'))],
        ]);
        expect(find.text(TranslationsEn().oops), findsOneWidget);
        expect(find.text(TranslationsEn().connectToLoadMessages), findsNothing);
        listeners.values.single.onConnected();
        await tester.pump(const Duration(milliseconds: 50));
        expect(reads(), 1);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('OFF $name: no connection listener, as today', (
        tester,
      ) async {
        CometChat.debugSetOfflineEnabledOverride(false);
        await pump(tester, [
          [const Server([])],
        ]);
        expect(listeners, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  testWidgets('OFF: the panels never use the two-phase read', (tester) async {
    CometChat.debugSetOfflineEnabledOverride(false);
    var reads = 0;
    Stream<TwoPhaseResult<BaseMessage>> count(MessagesRequest _) {
      reads++;
      return const Stream.empty();
    }

    PinnedMessagesOffline.debugFetchOverride = count;
    SavedMessagesOffline.debugFetchOverride = count;
    addTearDown(() {
      PinnedMessagesOffline.debugFetchOverride = null;
      SavedMessagesOffline.debugFetchOverride = null;
      CometChat.debugSetOfflineEnabledOverride(null);
    });

    for (final panel in [
      CometChatPinnedMessages(
        user: User(uid: 'bob', name: 'bob'),
      ),
      const CometChatSavedMessages(),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: panel,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(reads, 0);
  });
}
