// Render-verified matrix for the offline props W1 (ENG-41091) adds to
// [CometChatMessageList] and [CometChatMessageListStyle] (PROP5).
//
// The bloc is injected through the public `messageListBloc` seam with its
// list-local notice stream registered, so a notice can be pushed and the rendered
// SnackBar asserted. No SDK initialisation is required.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_list_offline_reads.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_errors.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMessageListBloc extends MockBloc<MessageListEvent, MessageListState>
    implements MessageListBloc {}

final _alice = User(uid: 'u1', name: 'Alice');
final _bob = User(uid: 'u2', name: 'Bob');

TextMessage _text(String body) => TextMessage(
  id: 1,
  text: body,
  sender: _alice,
  receiver: _bob,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);

MockMessageListBloc _mock(Stream<OfflineNotice> notices) {
  final msgs = <BaseMessage>[_text('hello world')];
  final state = MessageListState(
    status: MessageListStatus.loaded,
    messages: msgs,
    loggedInUser: _alice,
  );
  final bloc = MockMessageListBloc();
  whenListen(bloc, Stream<MessageListState>.value(state), initialState: state);
  when(() => bloc.operationsStream).thenAnswer(
    (_) => Stream<MessageOperation>.fromIterable([
      MessageOperation.set(msgs, animated: false),
    ]),
  );
  registerOfflineNotices(bloc, notices);
  when(() => bloc.findMessageIndex(any())).thenReturn(null);
  when(
    () => bloc.getReceiptNotifierForMessage(any()),
  ).thenReturn(ValueNotifier(MessageReceiptStatus.sent));
  when(
    () => bloc.getThreadReplyCountNotifier(any()),
  ).thenReturn(ValueNotifier<int>(0));
  when(() => bloc.initializeThreadReplyCount(any(), any())).thenAnswer((_) {});
  when(() => bloc.notifyMessageChanged(any())).thenAnswer((_) {});
  return bloc;
}

/// A bloc whose states the test pushes, starting at [initial].
MockMessageListBloc _mockStates(
  Stream<MessageListState> states,
  MessageListState initial,
) {
  final bloc = MockMessageListBloc();
  whenListen(bloc, states, initialState: initial);
  when(
    () => bloc.operationsStream,
  ).thenAnswer((_) => const Stream<MessageOperation>.empty());
  registerOfflineNotices(bloc, const Stream<OfflineNotice>.empty());
  when(() => bloc.findMessageIndex(any())).thenReturn(null);
  when(
    () => bloc.getReceiptNotifierForMessage(any()),
  ).thenReturn(ValueNotifier(MessageReceiptStatus.sent));
  when(
    () => bloc.getThreadReplyCountNotifier(any()),
  ).thenReturn(ValueNotifier<int>(0));
  when(() => bloc.initializeThreadReplyCount(any(), any())).thenAnswer((_) {});
  when(() => bloc.notifyMessageChanged(any())).thenAnswer((_) {});
  return bloc;
}

/// Counts conversation-starter panels the list asks for (each one mounts the
/// starter view, which sends one `getConversationStarter` request).
class _StarterPanels with CometChatUIEventListener {
  int count = 0;

  @override
  void showPanel(
    Map<String, dynamic>? id,
    CustomUIPosition uiPosition,
    WidgetBuilder child,
  ) {
    if (uiPosition == CustomUIPosition.messageListBottom) count++;
  }
}

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(_text('fallback'));
    registerFallbackValue(
      const LoadMessages(conversationWith: 'u2', conversationType: 'user'),
    );
  });

  group('CometChatMessageList offline props', () {
    testWidgets('hideOfflineNotices: false shows a pushed notice', (
      tester,
    ) async {
      final notices = StreamController<OfflineNotice>.broadcast();
      addTearDown(notices.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(notices.stream),
              hideOfflineNotices: false,
            ),
          ),
        ),
      );
      await _settle(tester);
      notices.add(const QueueFull());
      await _settle(tester, 4);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('hideOfflineNotices: true suppresses a pushed notice', (
      tester,
    ) async {
      final notices = StreamController<OfflineNotice>.broadcast();
      addTearDown(notices.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(notices.stream),
              hideOfflineNotices: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      notices.add(const QueueFull());
      await _settle(tester, 4);
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
        hub.postNotice(const QueueFull()); // no sink attached: queued

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _bob,
                messageListBloc: _mock(const Stream<OfflineNotice>.empty()),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await _settle(tester, 4);
        expect(tester.takeException(), isNull);
        expect(find.byType(SnackBar), findsOneWidget);

        // Delivered once: a second list taking the queue gets nothing.
        hub.attachNoticeSink((_) => fail('queued notice delivered twice'));
      },
    );
  });

  group('conversation starters on an offline empty open', () {
    const loading = MessageListState(status: MessageListStatus.loading);
    const empty = MessageListState(status: MessageListStatus.empty);

    late _StarterPanels panels;
    late StreamController<MessageListState> states;
    late MockMessageListBloc bloc;
    late int empties;

    setUp(() {
      panels = _StarterPanels();
      CometChatUIEvents.addUiListener('starter-panels-spy', panels);
      states = StreamController<MessageListState>.broadcast();
      bloc = _mockStates(states.stream, loading);
      empties = 0;
    });

    tearDown(() async {
      CometChatUIEvents.removeUiListener('starter-panels-spy');
      CometChat.debugSetOfflineEnabledOverride(null);
      await states.close();
    });

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: bloc,
              enableConversationStarters: true,
              onEmpty: () => empties++,
            ),
          ),
        ),
      );
      await _settle(tester, 2);
    }

    /// The reads code's offline empty open: "Connect to load more" is up
    /// when the list turns empty.
    Future<MessageListReadsView> openOfflineEmpty(WidgetTester tester) async {
      CometChat.debugSetOfflineEnabledOverride(true);
      await open(tester);
      final view = messageListReadsViewOf(bloc);
      view.connectToLoadMore.value = true;
      states.add(empty);
      await _settle(tester, 2);
      return view;
    }

    /// The reconnect read: the footer comes down and its server page lands.
    Future<void> connect(WidgetTester tester, MessageListReadsView view) async {
      view.connectToLoadMore.value = false;
      view.serverReads.value++;
      await _settle(tester, 2);
    }

    testWidgets('offline and empty: onEmpty fires, no starter request; once '
        'connected and still empty, one request', (tester) async {
      final view = await openOfflineEmpty(tester);
      expect(empties, 1);
      expect(panels.count, 0);

      await connect(tester, view);
      expect(panels.count, 1);
      // A later server read asks for nothing more.
      view.serverReads.value++;
      await _settle(tester, 2);
      expect(panels.count, 1);
    });

    testWidgets('offline and empty, then rows before the reconnect read: no '
        'starter request', (tester) async {
      final view = await openOfflineEmpty(tester);
      final rows = MessageListState(
        status: MessageListStatus.loaded,
        messages: [_text('hello')],
        loggedInUser: _alice,
      );
      when(() => bloc.state).thenReturn(rows);
      states.add(rows);
      await _settle(tester, 2);
      await connect(tester, view);
      expect(panels.count, 0);
    });

    testWidgets('online empty open: one request at once, as today', (
      tester,
    ) async {
      CometChat.debugSetOfflineEnabledOverride(true);
      await open(tester);
      states.add(empty);
      await _settle(tester, 2);
      expect(empties, 1);
      expect(panels.count, 1);
    });

    testWidgets('offline off: one request at once, as today', (tester) async {
      CometChat.debugSetOfflineEnabledOverride(false);
      await open(tester);
      states.add(empty);
      await _settle(tester, 2);
      expect(empties, 1);
      expect(panels.count, 1);
    });
  });

  group('CometChatMessageListStyle offline tokens', () {
    // The rows these tokens paint (failed/unsent rows, media placeholder) are
    // built by W4/W5; until then this asserts the list builds with them and
    // that the theme merge/lerp paths carry every token.
    testWidgets('offline tokens reach the list and survive merge and lerp', (
      tester,
    ) async {
      const tint = Color(0xFF112233);
      const icon = Color(0xFF445566);
      const notSent = TextStyle(fontSize: 13);
      const placeholder = TextStyle(fontSize: 11);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(const Stream<OfflineNotice>.empty()),
              style: const CometChatMessageListStyle(
                failedRowTint: tint,
                failedIconColor: icon,
                notSentTextStyle: notSent,
                mediaPlaceholderStyle: placeholder,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);

      final style = tester
          .widget<CometChatMessageList>(find.byType(CometChatMessageList))
          .style!;
      final merged = const CometChatMessageListStyle().merge(style);
      expect(merged.failedRowTint, tint);
      expect(merged.failedIconColor, icon);
      expect(merged.notSentTextStyle, notSent);
      expect(merged.mediaPlaceholderStyle, placeholder);

      final lerped = const CometChatMessageListStyle().lerp(style, 1.0);
      expect(lerped.failedRowTint, tint);
      expect(lerped.failedIconColor, icon);
      expect(lerped.notSentTextStyle?.fontSize, 13);
      expect(lerped.mediaPlaceholderStyle?.fontSize, 11);
    });
  });

  group('D84: the offline state, the error view and onError', () {
    const offlineError = MessageListState(
      status: MessageListStatus.error,
      errorMessage: 'ERR_CONNECTION',
    );

    setUp(() => CometChat.debugSetOfflineEnabledOverride(true));
    tearDown(() => CometChat.debugSetOfflineEnabledOverride(null));

    Future<List<Exception>> open(
      WidgetTester tester,
      MockMessageListBloc bloc, {
      WidgetBuilder? errorView,
    }) async {
      final errors = <Exception>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: bloc,
              errorStateView: errorView,
              onError: errors.add,
            ),
          ),
        ),
      );
      await _settle(tester, 2);
      return errors;
    }

    testWidgets('(4) nothing shown: the app error view, and onError', (
      tester,
    ) async {
      final bloc = _mockStates(
        Stream<MessageListState>.value(offlineError),
        const MessageListState(status: MessageListStatus.loading),
      );
      final errors = await open(
        tester,
        bloc,
        errorView: (_) => const Text('app error view'),
      );
      expect(find.text('app error view'), findsOneWidget);
      expect(errors, hasLength(1));
    });

    testWidgets('(4) nothing shown, no app view: the kit error view, and '
        'onError', (tester) async {
      final bloc = _mockStates(
        Stream<MessageListState>.value(offlineError),
        const MessageListState(status: MessageListStatus.loading),
      );
      final errors = await open(tester, bloc);
      expect(
        find.text(TranslationsEn().somethingWentWrongError),
        findsOneWidget,
      );
      expect(find.text(TranslationsEn().connectToLoadMessages), findsNothing);
      expect(errors, hasLength(1));
    });

    testWidgets('(3) offline, nothing shown: "Connect to load messages" with '
        'no Retry, and onError once', (tester) async {
      final bloc = _mockStates(
        Stream<MessageListState>.value(offlineError),
        const MessageListState(status: MessageListStatus.loading),
      );
      messageListReadsViewOf(bloc).showsOfflineState = true;
      final errors = await open(tester, bloc);
      expect(find.text(TranslationsEn().connectToLoadMessages), findsOneWidget);
      expect(find.text(TranslationsEn().retry), findsNothing);
      expect(find.text(TranslationsEn().somethingWentWrongError), findsNothing);
      expect(errors, hasLength(1));
    });

    testWidgets('(3) offline, nothing shown, with an app error view: that '
        'view instead, and onError once', (tester) async {
      final bloc = _mockStates(
        Stream<MessageListState>.value(offlineError),
        const MessageListState(status: MessageListStatus.loading),
      );
      messageListReadsViewOf(bloc).showsOfflineState = true;
      final errors = await open(
        tester,
        bloc,
        errorView: (_) => const Text('app error view'),
      );
      expect(find.text('app error view'), findsOneWidget);
      expect(find.text(TranslationsEn().connectToLoadMessages), findsNothing);
      expect(errors, hasLength(1));
    });

    testWidgets('(5) a real error over rows kept reaches onError', (
      tester,
    ) async {
      final bloc = _mock(const Stream<OfflineNotice>.empty());
      final errors = await open(tester, bloc);
      expect(errors, isEmpty);
      OfflineListErrors.report(
        bloc,
        CometChatException('ERR_TOO_MANY_REQUESTS', 'x', 'x'),
      );
      expect(errors, hasLength(1));
      expect(find.text(TranslationsEn().somethingWentWrongError), findsNothing);
    });
  });
}
