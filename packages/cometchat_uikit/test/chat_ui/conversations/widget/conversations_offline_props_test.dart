// Render-verified matrix for the offline prop W1 (ENG-41091) adds to
// [CometChatConversations] (PROP5): `hideOfflineNotices`.
//
// The bloc is injected through the public `conversationsBloc` seam with its
// list-local notice stream registered, so a notice can be pushed and the rendered
// SnackBar asserted.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {
  @override
  // ignore: must_call_super
  void add(ConversationsEvent event) {}
}

MockConversationsBloc _bloc(Stream<OfflineNotice> notices) {
  final bloc = MockConversationsBloc();
  const emptyState = ConversationsEmpty();
  when(() => bloc.state).thenReturn(emptyState);
  whenListen(bloc, Stream.fromIterable([emptyState]), initialState: emptyState);
  registerOfflineNotices(bloc, notices);
  return bloc;
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

void main() {
  group('CometChatConversations offline props', () {
    testWidgets('hideOfflineNotices: false shows a pushed notice', (
      tester,
    ) async {
      final notices = StreamController<OfflineNotice>.broadcast();
      addTearDown(notices.close);
      await tester.pumpWidget(
        _wrap(
          CometChatConversations(
            conversationsBloc: _bloc(notices.stream),
            hideOfflineNotices: false,
          ),
        ),
      );
      await tester.pump();
      notices.add(const UnsentLost(2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text("2 unsent messages couldn't be recovered"),
        findsOneWidget,
      );
    });

    testWidgets('hideOfflineNotices: true suppresses a pushed notice', (
      tester,
    ) async {
      final notices = StreamController<OfflineNotice>.broadcast();
      addTearDown(notices.close);
      await tester.pumpWidget(
        _wrap(
          CometChatConversations(
            conversationsBloc: _bloc(notices.stream),
            hideOfflineNotices: true,
          ),
        ),
      );
      await tester.pump();
      notices.add(const UnsentLost(2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'a hub notice queued with no list mounted shows once after mount',
      (tester) async {
        final hub = OfflineHub.instance;
        hub.debugReset();
        CometChat.debugSetOfflineEnabledOverride(true);
        addTearDown(() {
          CometChat.debugSetOfflineEnabledOverride(null);
          hub.debugReset();
        });
        hub.postNotice(const UnsentLost(3)); // no sink attached: queued

        await tester.pumpWidget(
          _wrap(
            CometChatConversations(
              conversationsBloc: _bloc(const Stream<OfflineNotice>.empty()),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(
          find.text("3 unsent messages couldn't be recovered"),
          findsOneWidget,
        );

        // Delivered once: a second list taking the queue gets nothing.
        hub.attachNoticeSink((_) => fail('queued notice delivered twice'));
      },
    );
  });
}
