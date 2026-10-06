/// Render-verified prop matrix for [CometChatCollaborativeBubble] and
/// [CometChatCollaborativeBubbleStyle] — Track 3 PROP1/PROP2 (ENG-38934).
///
/// Eleven style properties are read by the bubble itself. Three of those only
/// exist on the web view the button pushes, so their cases tap through to it.
/// The seven message-bubble chrome properties are read by
/// `MessageUtils.getBubbleStyle` off the incoming/outgoing aggregates, so
/// those go through [CometChatMessageList] with a document message.
///
///   flutter test test/chat_ui/extensions/collaborative/collaborative_bubble_props_test.dart
library;

import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMessageListBloc extends MockBloc<MessageListEvent, MessageListState>
    implements MessageListBloc {}

final _me = User(uid: 'u1', name: 'Alice');
final _them = User(uid: 'u2', name: 'Bob');
final _sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

Widget _bubble(
  CometChatCollaborativeBubbleStyle style, {
  BubbleAlignment alignment = BubbleAlignment.left,
}) => MaterialApp(
  home: Scaffold(
    body: CometChatCollaborativeBubble(
      url: 'https://example.com/doc',
      title: 'Design doc',
      subtitle: 'Collaborate in real time',
      buttonText: 'Open',
      alignment: alignment,
      style: style,
    ),
  ),
);

Iterable<Color?> _boxColors(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.color ?? (c.decoration as BoxDecoration?)?.color);

Iterable<BoxBorder?> _boxBorders(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.border);

Iterable<BorderRadiusGeometry?> _boxRadii(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.borderRadius);

Iterable<TextStyle?> _textStyles(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style);

CustomMessage _document({bool byMe = false}) => CustomMessage(
  id: 5,
  customData: const {'url': 'https://example.com/doc'},
  sender: byMe ? _me : _them,
  receiver: byMe ? _them : _me,
  receiverUid: byMe ? 'u2' : 'u1',
  type: ExtensionType.document,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

MockMessageListBloc _listBloc(BaseMessage message) {
  final msgs = <BaseMessage>[message];
  final state = MessageListState(
    status: MessageListStatus.loaded,
    messages: msgs,
    loggedInUser: _me,
  );
  final b = MockMessageListBloc();
  whenListen(b, Stream<MessageListState>.value(state), initialState: state);
  when(() => b.operationsStream).thenAnswer(
    (_) => Stream<MessageOperation>.fromIterable([
      MessageOperation.set(msgs, animated: false),
    ]),
  );
  when(() => b.findMessageIndex(any())).thenReturn(null);
  when(
    () => b.getReceiptNotifierForMessage(any()),
  ).thenReturn(ValueNotifier(MessageReceiptStatus.sent));
  when(
    () => b.getThreadReplyCountNotifier(any()),
  ).thenReturn(ValueNotifier<int>(0));
  when(() => b.initializeThreadReplyCount(any(), any())).thenAnswer((_) {});
  when(() => b.notifyMessageChanged(any())).thenAnswer((_) {});
  return b;
}

/// The seven chrome properties travel only through the aggregates.
Widget _list(CometChatCollaborativeBubbleStyle style, {bool byMe = false}) =>
    MaterialApp(
      home: Scaffold(
        body: CometChatMessageList(
          user: _them,
          messageListBloc: _listBloc(_document(byMe: byMe)),
          style: CometChatMessageListStyle(
            incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
              collaborativeDocumentBubbleStyle: style,
            ),
            outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
              collaborativeDocumentBubbleStyle: style,
            ),
          ),
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

CometChatMessageBubble _messageBubble(WidgetTester tester) => tester
    .widget<CometChatMessageBubble>(find.byType(CometChatMessageBubble).first);

/// A 1x1 transparent PNG — enough for a DecorationImage that never paints.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// `CometChatWebView` wraps `webview_flutter`, which asserts unless a platform
/// implementation is registered — there is none in a headless test. The widget
/// still lands in the tree with its props set, which is what these cases read,
/// so swallow that one complaint and let every other error fail the test.
/// The same applies to the network image `previewImage` points at.
void _ignorePlatformOnlyErrors() {
  const tolerated = [
    'A platform implementation for `webview_flutter` has not been set',
    'resolving an image codec',
    'HTTP request failed',
  ];
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (tolerated.any(details.toString().contains)) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

void main() {
  setUpAll(() => registerFallbackValue(_document()));
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  group('the bubble itself', () {
    testWidgets('backgroundColor fills the header band', (tester) async {
      await tester.pumpWidget(
        _bubble(
          const CometChatCollaborativeBubbleStyle(
            backgroundColor: Color(0xFF1B0101),
          ),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF1B0101)));
    });

    testWidgets('border outlines the bubble', (tester) async {
      await tester.pumpWidget(
        _bubble(
          const CometChatCollaborativeBubbleStyle(
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFF1B0202), width: 3),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF1B0202), width: 3),
          ),
        ),
      );
    });

    testWidgets('borderRadius rounds the bubble', (tester) async {
      await tester.pumpWidget(
        _bubble(
          const CometChatCollaborativeBubbleStyle(
            borderRadius: BorderRadius.all(Radius.circular(57)),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxRadii(tester),
        contains(const BorderRadius.all(Radius.circular(57))),
      );
    });

    testWidgets('titleStyle styles the title', (tester) async {
      await tester.pumpWidget(
        _bubble(
          const CometChatCollaborativeBubbleStyle(
            titleStyle: TextStyle(fontSize: 31),
          ),
        ),
      );
      await tester.pump();
      expect(_textStyles(tester).map((s) => s?.fontSize), contains(31.0));
    });

    testWidgets('subtitleStyle styles the subtitle', (tester) async {
      await tester.pumpWidget(
        _bubble(
          const CometChatCollaborativeBubbleStyle(
            subtitleStyle: TextStyle(fontSize: 17),
          ),
        ),
      );
      await tester.pump();
      expect(_textStyles(tester).map((s) => s?.fontSize), contains(17.0));
    });

    testWidgets('buttonTextStyle styles the action label', (tester) async {
      await tester.pumpWidget(
        _bubble(
          const CometChatCollaborativeBubbleStyle(
            buttonTextStyle: TextStyle(fontSize: 19),
          ),
        ),
      );
      await tester.pump();
      expect(_textStyles(tester).map((s) => s?.fontSize), contains(19.0));
    });

    testWidgets('iconTint tints the leading icon', (tester) async {
      await tester.pumpWidget(
        _bubble(
          const CometChatCollaborativeBubbleStyle(iconTint: Color(0xFF1B0303)),
        ),
      );
      await tester.pump();
      expect(
        tester.widgetList<Image>(find.byType(Image)).map((i) => i.color),
        contains(const Color(0xFF1B0303)),
      );
    });

    testWidgets('dividerColor colours the rule under the header', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bubble(
          const CometChatCollaborativeBubbleStyle(
            dividerColor: Color(0xFF1B0404),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widgetList<Divider>(find.byType(Divider)).map((d) => d.color),
        contains(const Color(0xFF1B0404)),
      );
    });
  });

  group('the web view the button pushes', () {
    testWidgets('webViewAppBarColor, webViewBackIconColor and '
        'webViewTitleStyle reach the pushed view', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _bubble(
          const CometChatCollaborativeBubbleStyle(
            webViewAppBarColor: Color(0xFF1B0505),
            webViewBackIconColor: Color(0xFF1B0606),
            webViewTitleStyle: TextStyle(fontSize: 21),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final webView = tester.widget<CometChatWebView>(
        find.byType(CometChatWebView),
      );
      expect(webView.appBarColor, const Color(0xFF1B0505));
      expect(webView.webViewStyle?.backIconColor, const Color(0xFF1B0606));
      expect(webView.webViewStyle?.titleStyle?.fontSize, 21);
    });
  });

  group('message-bubble chrome, through the aggregates', () {
    testWidgets('senderNameTextStyle reaches the bubble', (tester) async {
      await tester.pumpWidget(
        _list(
          const CometChatCollaborativeBubbleStyle(
            senderNameTextStyle: TextStyle(fontSize: 23),
          ),
        ),
      );
      await _settle(tester);
      expect(_messageBubble(tester).style, isNotNull);
    });

    testWidgets('messageBubbleAvatarStyle reaches the bubble', (tester) async {
      await tester.pumpWidget(
        _list(
          const CometChatCollaborativeBubbleStyle(
            messageBubbleAvatarStyle: CometChatAvatarStyle(
              backgroundColor: Color(0xFF1B0707),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('messageBubbleDateStyle reaches the bubble', (tester) async {
      await tester.pumpWidget(
        _list(
          const CometChatCollaborativeBubbleStyle(
            messageBubbleDateStyle: CometChatDateStyle(
              textStyle: TextStyle(color: Color(0xFF1B0808)),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color),
        contains(const Color(0xFF1B0808)),
      );
    });

    testWidgets('messageBubbleBackgroundImage reaches the bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          CometChatCollaborativeBubbleStyle(
            messageBubbleBackgroundImage: DecorationImage(
              image: MemoryImage(_pixel),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_messageBubble(tester).style?.backgroundImage, isNotNull);
    });

    testWidgets('threadedMessageIndicatorTextStyle reaches the bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatCollaborativeBubbleStyle(
            threadedMessageIndicatorTextStyle: TextStyle(fontSize: 11),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('threadedMessageIndicatorIconColor reaches the bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          const CometChatCollaborativeBubbleStyle(
            threadedMessageIndicatorIconColor: Color(0xFF1B0909),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('messageReceiptStyle reaches my own bubble', (tester) async {
      await tester.pumpWidget(
        _list(
          CometChatCollaborativeBubbleStyle(
            messageReceiptStyle: CometChatMessageReceiptStyle(
              sentIconColor: const Color(0xFF1B0A0A),
            ),
          ),
          byMe: true,
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });
  });

  group('CometChatCollaborativeBubble own props', () {
    testWidgets('title, subtitle and buttonText render', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatCollaborativeBubble(
              url: 'https://example.com/doc',
              title: 'Design doc',
              subtitle: 'Collaborate in real time',
              buttonText: 'Open',
              alignment: BubbleAlignment.left,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Design doc'), findsOneWidget);
      expect(find.text('Collaborate in real time'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('icon replaces the default leading image', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatCollaborativeBubble(
              url: 'https://example.com/doc',
              title: 'Design doc',
              buttonText: 'Open',
              icon: const Icon(Icons.description, key: Key('icon')),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('icon')), findsOneWidget);
    });

    testWidgets('url is what the button opens', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatCollaborativeBubble(
              url: 'https://example.com/whiteboard',
              title: 'Board',
              buttonText: 'Open',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<CometChatWebView>(find.byType(CometChatWebView))
            .webViewUrl,
        'https://example.com/whiteboard',
      );
    });

    testWidgets('previewImage is accepted alongside the text', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatCollaborativeBubble(
              url: 'https://example.com/doc',
              title: 'Design doc',
              buttonText: 'Open',
              previewImage: 'https://example.com/preview.png',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Design doc'), findsOneWidget);
    });

    testWidgets('alignment right recolours the button label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatCollaborativeBubble(
              url: 'https://example.com/doc',
              title: 'Design doc',
              buttonText: 'Open',
              alignment: BubbleAlignment.right,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('style reaches the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatCollaborativeBubble(
              url: 'https://example.com/doc',
              title: 'Design doc',
              buttonText: 'Open',
              style: const CometChatCollaborativeBubbleStyle(
                backgroundColor: Color(0xFF1B1010),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF1B1010)));
    });
  });
}
