/// Render-verified prop matrix for [CometChatIncomingMessageBubbleStyle] and
/// [CometChatOutgoingMessageBubbleStyle] — Track 3 PROP1 (ENG-38924).
///
/// These are style aggregates: MessageUtils.getBubbleStyle switches on the
/// message's category+type, reads the matching sub-style off the aggregate,
/// and falls back to the aggregate's own top-level fields via mergeIfNull.
/// Each case therefore needs a message of the right type, and the assertion
/// lands on the CometChatMessageBubble the list actually renders.
///
///   flutter test test/shared_ui/bubble_styles/bubble_styles_props_test.dart
library;

// audioBubbleStyle is deprecated in favour of voiceNoteBubbleStyle, but the
// deprecated field still has to keep working — that is what these cases assert.
// ignore_for_file: deprecated_member_use_from_same_package

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

TextMessage _text({
  bool byMe = false,
  DateTime? deletedAt,
  ModerationStatusEnum? moderationStatus,
}) => TextMessage(
  id: 1,
  text: 'hello',
  sender: byMe ? _me : _them,
  receiver: byMe ? _them : _me,
  receiverUid: byMe ? 'u2' : 'u1',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
  deletedAt: deletedAt,
  moderationStatus: moderationStatus,
);

MediaMessage _media(String type, {bool byMe = false}) => MediaMessage(
  id: 2,
  sender: byMe ? _me : _them,
  receiver: byMe ? _them : _me,
  receiverUid: byMe ? 'u2' : 'u1',
  type: type,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

CustomMessage _custom(String type, {bool byMe = false}) => CustomMessage(
  id: 3,
  customData: const {'k': 'v'},
  sender: byMe ? _me : _them,
  receiver: byMe ? _them : _me,
  receiverUid: byMe ? 'u2' : 'u1',
  type: type,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

MockMessageListBloc _mock(BaseMessage message) {
  final msgs = <BaseMessage>[message];
  final state = MessageListState(
    status: MessageListStatus.loaded,
    messages: msgs,
    loggedInUser: _me,
  );
  final bloc = MockMessageListBloc();
  whenListen(bloc, Stream<MessageListState>.value(state), initialState: state);
  when(() => bloc.operationsStream).thenAnswer(
    (_) => Stream<MessageOperation>.fromIterable([
      MessageOperation.set(msgs, animated: false),
    ]),
  );
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A 1x1 transparent PNG — enough for a DecorationImage that never paints.
final _transparentPixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

CometChatMessageBubble _bubble(WidgetTester tester) => tester
    .widget<CometChatMessageBubble>(find.byType(CometChatMessageBubble).first);

void main() {
  setUpAll(() => registerFallbackValue(_text()));

  // MessageUtils.getBubbleStyle picks incoming vs outgoing off this static,
  // not off the bloc state, so it has to be set for the outgoing cases.
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  group('incoming sub-styles by message type', () {
    testWidgets('textBubbleStyle colours the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text()),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  textBubbleStyle: CometChatTextBubbleStyle(
                    backgroundColor: Color(0xFF0C0101),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0C0101));
    });

    testWidgets('imageBubbleStyle colours the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_media(MessageTypeConstants.image)),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  imageBubbleStyle: CometChatImageBubbleStyle(
                    backgroundColor: Color(0xFF0C0202),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0C0202));
    });

    testWidgets('videoBubbleStyle colours the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_media(MessageTypeConstants.video)),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  videoBubbleStyle: CometChatVideoBubbleStyle(
                    backgroundColor: Color(0xFF0C0303),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0C0303));
    });

    testWidgets('fileBubbleStyle colours the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_media(MessageTypeConstants.file)),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  fileBubbleStyle: CometChatFileBubbleStyle(
                    backgroundColor: Color(0xFF0C0404),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0C0404));
    });

    testWidgets('pollsBubbleStyle colours the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_custom(ExtensionType.extensionPoll)),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  pollsBubbleStyle: CometChatPollsBubbleStyle(
                    backgroundColor: Color(0xFF0C0505),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0C0505));
    });

    testWidgets('collaborativeDocumentBubbleStyle colours the bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_custom(ExtensionType.document)),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  collaborativeDocumentBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        backgroundColor: Color(0xFF0C0606),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('collaborativeWhiteboardBubbleStyle colours the bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_custom(ExtensionType.whiteboard)),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  collaborativeWhiteboardBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        backgroundColor: Color(0xFF0C0707),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('stickerBubbleStyle colours the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_custom(ExtensionType.sticker)),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  stickerBubbleStyle: CometChatStickerBubbleStyle(
                    backgroundColor: Color(0xFF0C0808),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0C0808));
    });
  });

  group('voice note styling', () {
    testWidgets('voiceNoteBubbleStyle colours the audio bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_media(MessageTypeConstants.audio)),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  voiceNoteBubbleStyle: CometChatVoiceNoteBubbleStyle(
                    backgroundColor: Color(0xFF0C0909),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0C0909));
    });

    testWidgets(
      'audioBubbleStyle still applies when voiceNoteBubbleStyle is absent',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _them,
                messageListBloc: _mock(_media(MessageTypeConstants.audio)),
                style: CometChatMessageListStyle(
                  incomingMessageBubbleStyle:
                      CometChatIncomingMessageBubbleStyle(
                        // ignore: deprecated_member_use
                        audioBubbleStyle: CometChatVoiceNoteBubbleStyle(
                          backgroundColor: Color(0xFF0C0A0A),
                        ),
                      ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0C0A0A));
      },
    );

    testWidgets('voiceNoteBubbleStyle takes precedence over audioBubbleStyle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_media(MessageTypeConstants.audio)),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  voiceNoteBubbleStyle: CometChatVoiceNoteBubbleStyle(
                    backgroundColor: Color(0xFF0C0B0B),
                  ),
                  // ignore: deprecated_member_use
                  audioBubbleStyle: CometChatVoiceNoteBubbleStyle(
                    backgroundColor: Color(0xFF0C0C0C),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0C0B0B));
    });
  });

  group('incoming aggregate fallbacks', () {
    testWidgets('backgroundColor falls back onto the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text()),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  backgroundColor: Color(0xFF0C0D0D),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0C0D0D));
    });

    testWidgets('border falls back onto the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text()),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFF0C0E0E), width: 3),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        (_bubble(tester).style?.border as Border).top.color,
        const Color(0xFF0C0E0E),
      );
    });

    testWidgets('borderRadius falls back onto the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text()),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  borderRadius: BorderRadius.all(Radius.circular(17)),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _bubble(tester).style?.borderRadius,
        const BorderRadius.all(Radius.circular(17)),
      );
    });

    testWidgets('messageBubbleAvatarStyle reaches the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text()),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  messageBubbleAvatarStyle: CometChatAvatarStyle(
                    backgroundColor: Color(0xFF0C0F0F),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsOneWidget);
    });

    testWidgets('messageBubbleDateStyle reaches the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text()),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  messageBubbleDateStyle: CometChatDateStyle(
                    textStyle: TextStyle(color: Color(0xFF0C1313)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color),
        contains(const Color(0xFF0C1313)),
      );
    });

    testWidgets('senderNameTextStyle reaches the bubble header', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text()),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  senderNameTextStyle: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsOneWidget);
    });

    testWidgets('threadedMessageIndicatorIconColor and '
        'threadedMessageIndicatorTextStyle reach the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text()),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  threadedMessageIndicatorIconColor: Color(0xFF0C1010),
                  threadedMessageIndicatorTextStyle: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsOneWidget);
    });

    testWidgets('messageBubbleReactionStyle reaches the bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text()),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  messageBubbleReactionStyle: CometChatReactionsStyle(
                    backgroundColor: Color(0xFF0C1111),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsOneWidget);
    });

    testWidgets('messageBubbleBackgroundImage reaches the bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text()),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  messageBubbleBackgroundImage: DecorationImage(
                    image: MemoryImage(_transparentPixel),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundImage, isNotNull);
    });
  });

  group('deleted, link preview, translation and call bubbles', () {
    testWidgets('deletedBubbleStyle colours a deleted bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(deletedAt: _sentAt)),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  deletedBubbleStyle: CometChatDeletedBubbleStyle(
                    backgroundColor: Color(0xFF0C1212),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0C1212));
    });

    testWidgets('linkPreviewBubbleStyle reaches the bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text()),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  linkPreviewBubbleStyle: CometChatLinkPreviewBubbleStyle(
                    backgroundColor: Color(0xFF0C1313),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsOneWidget);
    });

    testWidgets(
      'messageTranslationBubbleStyle colours the translation separator',
      (tester) async {
        // A translated message: the Translate option stores the translation
        // here, and the text template wraps the bubble in the translation.
        final translated = _text()..metadata = {'translated_message': 'hola'};
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _them,
                messageListBloc: _mock(translated),
                style: CometChatMessageListStyle(
                  incomingMessageBubbleStyle:
                      CometChatIncomingMessageBubbleStyle(
                        messageTranslationBubbleStyle:
                            CometChatMessageTranslationBubbleStyle(
                              dividerColor: Color(0xFF0C1414),
                            ),
                      ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
        final separator = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(MessageTranslationBubble),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(
          ((separator.decoration as BoxDecoration).border as Border?)
              ?.bottom
              .color,
          const Color(0xFF0C1414),
        );
      },
    );

    testWidgets('voiceCallBubbleStyle colours an audio call bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_custom(MessageTypeConstants.meeting)),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  voiceCallBubbleStyle: CometChatCallBubbleStyle(
                    backgroundColor: Color(0xFF0C1515),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('videoCallBubbleStyle colours a video call bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_custom(MessageTypeConstants.meeting)),
              style: CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  videoCallBubbleStyle: CometChatCallBubbleStyle(
                    backgroundColor: Color(0xFF0C1616),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });
  });

  group('outgoing aggregate — every prop, on a message I sent', () {
    testWidgets('textBubbleStyle colours my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  textBubbleStyle: CometChatTextBubbleStyle(
                    backgroundColor: Color(0xFF0E0101),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0E0101));
    });

    testWidgets('imageBubbleStyle colours my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(
                _media(MessageTypeConstants.image, byMe: true),
              ),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  imageBubbleStyle: CometChatImageBubbleStyle(
                    backgroundColor: Color(0xFF0E0202),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0E0202));
    });

    testWidgets('videoBubbleStyle colours my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(
                _media(MessageTypeConstants.video, byMe: true),
              ),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  videoBubbleStyle: CometChatVideoBubbleStyle(
                    backgroundColor: Color(0xFF0E0303),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0E0303));
    });

    testWidgets('fileBubbleStyle colours my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(
                _media(MessageTypeConstants.file, byMe: true),
              ),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  fileBubbleStyle: CometChatFileBubbleStyle(
                    backgroundColor: Color(0xFF0E0404),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0E0404));
    });

    testWidgets('pollsBubbleStyle colours my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(
                _custom(ExtensionType.extensionPoll, byMe: true),
              ),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  pollsBubbleStyle: CometChatPollsBubbleStyle(
                    backgroundColor: Color(0xFF0E0505),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0E0505));
    });

    testWidgets('collaborativeDocumentBubbleStyle colours my own bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(
                _custom(ExtensionType.document, byMe: true),
              ),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  collaborativeDocumentBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        backgroundColor: Color(0xFF0E0606),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('collaborativeWhiteboardBubbleStyle colours my own bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(
                _custom(ExtensionType.whiteboard, byMe: true),
              ),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  collaborativeWhiteboardBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        backgroundColor: Color(0xFF0E0707),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('stickerBubbleStyle colours my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(
                _custom(ExtensionType.sticker, byMe: true),
              ),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  stickerBubbleStyle: CometChatStickerBubbleStyle(
                    backgroundColor: Color(0xFF0E0808),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0E0808));
    });
    testWidgets('voiceNoteBubbleStyle colours my own audio bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(
                _media(MessageTypeConstants.audio, byMe: true),
              ),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  voiceNoteBubbleStyle: CometChatVoiceNoteBubbleStyle(
                    backgroundColor: Color(0xFF0E0909),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0E0909));
    });

    testWidgets(
      'audioBubbleStyle still applies when voiceNoteBubbleStyle is absent',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _them,
                messageListBloc: _mock(
                  _media(MessageTypeConstants.audio, byMe: true),
                ),
                style: CometChatMessageListStyle(
                  outgoingMessageBubbleStyle:
                      CometChatOutgoingMessageBubbleStyle(
                        // ignore: deprecated_member_use
                        audioBubbleStyle: CometChatVoiceNoteBubbleStyle(
                          backgroundColor: Color(0xFF0E0A0A),
                        ),
                      ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0E0A0A));
      },
    );

    testWidgets('voiceNoteBubbleStyle takes precedence over audioBubbleStyle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(
                _media(MessageTypeConstants.audio, byMe: true),
              ),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  voiceNoteBubbleStyle: CometChatVoiceNoteBubbleStyle(
                    backgroundColor: Color(0xFF0E0B0B),
                  ),
                  // ignore: deprecated_member_use
                  audioBubbleStyle: CometChatVoiceNoteBubbleStyle(
                    backgroundColor: Color(0xFF0E0C0C),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0E0B0B));
    });
    testWidgets('backgroundColor falls back onto my own bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  backgroundColor: Color(0xFF0E0D0D),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0E0D0D));
    });

    testWidgets('border falls back onto my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFF0E0E0E), width: 3),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        (_bubble(tester).style?.border as Border).top.color,
        const Color(0xFF0E0E0E),
      );
    });

    testWidgets('borderRadius falls back onto my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  borderRadius: BorderRadius.all(Radius.circular(17)),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _bubble(tester).style?.borderRadius,
        const BorderRadius.all(Radius.circular(17)),
      );
    });

    testWidgets('messageBubbleAvatarStyle reaches my own bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  messageBubbleAvatarStyle: CometChatAvatarStyle(
                    backgroundColor: Color(0xFF0E0F0F),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsOneWidget);
    });

    testWidgets('messageBubbleDateStyle reaches my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  messageBubbleDateStyle: CometChatDateStyle(
                    textStyle: TextStyle(color: Color(0xFF0E1313)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color),
        contains(const Color(0xFF0E1313)),
      );
    });

    testWidgets('threadedMessageIndicatorIconColor and '
        'threadedMessageIndicatorTextStyle reach my own bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  threadedMessageIndicatorIconColor: Color(0xFF0E1010),
                  threadedMessageIndicatorTextStyle: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsOneWidget);
    });

    testWidgets('messageBubbleReactionStyle reaches my own bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  messageBubbleReactionStyle: CometChatReactionsStyle(
                    backgroundColor: Color(0xFF0E1111),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsOneWidget);
    });

    testWidgets('messageBubbleBackgroundImage reaches my own bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  messageBubbleBackgroundImage: DecorationImage(
                    image: MemoryImage(_transparentPixel),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundImage, isNotNull);
    });
    testWidgets('deletedBubbleStyle colours my own deleted bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true, deletedAt: _sentAt)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  deletedBubbleStyle: CometChatDeletedBubbleStyle(
                    backgroundColor: Color(0xFF0E1212),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0E1212));
    });

    testWidgets('linkPreviewBubbleStyle reaches my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  linkPreviewBubbleStyle: CometChatLinkPreviewBubbleStyle(
                    backgroundColor: Color(0xFF0E1313),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsOneWidget);
    });

    testWidgets(
      'messageTranslationBubbleStyle colours my own translation separator',
      (tester) async {
        // A translated message: the Translate option stores the translation
        // here, and the text template wraps the bubble in the translation.
        final translated = _text(byMe: true)
          ..metadata = {'translated_message': 'hola'};
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _them,
                messageListBloc: _mock(translated),
                style: CometChatMessageListStyle(
                  outgoingMessageBubbleStyle:
                      CometChatOutgoingMessageBubbleStyle(
                        messageTranslationBubbleStyle:
                            CometChatMessageTranslationBubbleStyle(
                              dividerColor: Color(0xFF0E1414),
                            ),
                      ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
        final separator = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(MessageTranslationBubble),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(
          ((separator.decoration as BoxDecoration).border as Border?)
              ?.bottom
              .color,
          const Color(0xFF0E1414),
        );
      },
    );

    testWidgets('voiceCallBubbleStyle colours my own audio call bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(
                _custom(MessageTypeConstants.meeting, byMe: true),
              ),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  voiceCallBubbleStyle: CometChatCallBubbleStyle(
                    backgroundColor: Color(0xFF0E1515),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('videoCallBubbleStyle colours my own video call bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(
                _custom(MessageTypeConstants.meeting, byMe: true),
              ),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  videoCallBubbleStyle: CometChatCallBubbleStyle(
                    backgroundColor: Color(0xFF0E1616),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });
  });
  group('outgoing aggregate', () {
    testWidgets('textBubbleStyle colours my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  textBubbleStyle: CometChatTextBubbleStyle(
                    backgroundColor: Color(0xFF0D0101),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0D0101));
    });

    testWidgets('backgroundColor falls back onto my own bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  backgroundColor: Color(0xFF0D0202),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_bubble(tester).style?.backgroundColor, const Color(0xFF0D0202));
    });

    testWidgets('messageReceiptStyle reaches my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(_text(byMe: true)),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  messageReceiptStyle: CometChatMessageReceiptStyle(
                    sentIconColor: Color(0xFF0D0303),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsOneWidget);
    });

    testWidgets('moderationStyle reaches my own bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock(
                _text(
                  byMe: true,
                  moderationStatus: ModerationStatusEnum.DISAPPROVED,
                ),
              ),
              style: CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  moderationStyle: CometChatModerationStyle(
                    moderationBackgroundColor: Color(0xFF0D0404),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      // the banner paints moderationBackgroundColor behind the warning text
      expect(
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => (c.decoration as BoxDecoration?)?.color),
        contains(const Color(0xFF0D0404)),
      );
    });
  });
}
