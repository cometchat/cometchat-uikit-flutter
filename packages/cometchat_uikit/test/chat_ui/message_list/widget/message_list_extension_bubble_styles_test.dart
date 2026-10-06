/// Per-direction extension bubble styles reach the extension bubbles
/// (ENG-38688).
///
/// [CometChatIncomingMessageBubbleStyle] and
/// [CometChatOutgoingMessageBubbleStyle] each carry a polls, sticker,
/// collaborative document, collaborative whiteboard and link preview style.
/// The surrounding message bubble has always taken its chrome (background,
/// border, radius) from them; these cases pin down that the fields the
/// extension bubble itself paints — question text, sticker background, card
/// title, link-preview card — reach it too, on the side the message is on,
/// with [AdditionalConfigurations] able to override them.
///
/// Every case pumps the real [CometChatMessageList] and asserts on the
/// extension bubble it built, or on a widget that bubble painted.
///
///   flutter test test/chat_ui/message_list/widget/message_list_extension_bubble_styles_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class MockMessageListBloc extends MockBloc<MessageListEvent, MessageListState>
    implements MessageListBloc {}

final _me = User(uid: 'u1', name: 'Alice');
final _them = User(uid: 'u2', name: 'Bob');
final _sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

/// The border an inner extension bubble gets: the surrounding message
/// bubble draws the direction style's border, so the content must not.
final _erasedBorder = Border.all(color: Colors.transparent, width: 0);

CustomMessage _custom(
  String type, {
  required bool byMe,
  int id = 3,
  Map<String, dynamic> customData = const {'k': 'v'},
}) => CustomMessage(
  id: id,
  customData: customData,
  sender: byMe ? _me : _them,
  receiver: byMe ? _them : _me,
  receiverUid: byMe ? 'u2' : 'u1',
  type: type,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

CustomMessage _poll({required bool byMe, int id = 3}) => _custom(
  ExtensionType.extensionPoll,
  byMe: byMe,
  id: id,
  customData: const {
    'question': 'Lunch?',
    'options': ['Pizza', 'Salad'],
  },
);

CustomMessage _sticker({required bool byMe}) => _custom(
  ExtensionType.sticker,
  byMe: byMe,
  customData: const {'sticker_url': 'https://example.com/sticker.png'},
);

/// A text message carrying a link-preview extension result, so the default
/// text template wraps it in a [CometChatLinkPreviewBubble].
TextMessage _linkText({required bool byMe}) => TextMessage(
  id: 5,
  text: 'see https://example.com',
  sender: byMe ? _me : _them,
  receiver: byMe ? _them : _me,
  receiverUid: byMe ? 'u2' : 'u1',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
  metadata: {
    '@injected': {
      'extensions': {
        ExtensionConstants.linkPreview: {
          'links': [
            {'url': 'https://example.com', 'title': 'Example'},
          ],
        },
      },
    },
  },
);

MockMessageListBloc _mock(List<BaseMessage> msgs) {
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

CometChatPollsBubble _pollsBubble(WidgetTester tester) =>
    tester.widget<CometChatPollsBubble>(find.byType(CometChatPollsBubble));

CometChatCollaborativeBubble _collabBubble(WidgetTester tester) =>
    tester.widget<CometChatCollaborativeBubble>(
      find.byType(CometChatCollaborativeBubble),
    );

CometChatLinkPreviewBubble _linkBubble(WidgetTester tester) =>
    tester.widget<CometChatLinkPreviewBubble>(
      find.byType(CometChatLinkPreviewBubble),
    );

/// The colour of the first rendered [Text] reading [data].
Color? _textColor(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data).first).style?.color;

void main() {
  setUpAll(() => registerFallbackValue(_poll(byMe: true)));

  // MessageUtils.getBubbleStyle picks the outer chrome's side off this
  // static, so it has to match the bloc's logged-in user.
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  group('polls', () {
    testWidgets('my poll paints its question with the outgoing '
        'pollsBubbleStyle, and the border is drawn once', (tester) async {
      const border = Border.fromBorderSide(
        BorderSide(color: Color(0xFFA10001), width: 3),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([_poll(byMe: true)]),
              style: const CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  pollsBubbleStyle: CometChatPollsBubbleStyle(
                    questionTextStyle: TextStyle(color: Color(0xFFA10002)),
                    border: border,
                  ),
                ),
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  pollsBubbleStyle: CometChatPollsBubbleStyle(
                    questionTextStyle: TextStyle(color: Color(0xFFA10003)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(_textColor(tester, 'Lunch?'), const Color(0xFFA10002));
      expect(
        _pollsBubble(tester).style?.questionTextStyle?.color,
        const Color(0xFFA10002),
      );
      // The message bubble around it draws the border; the poll does not.
      expect(_pollsBubble(tester).style?.border, _erasedBorder);
      expect(
        tester
            .widget<CometChatMessageBubble>(find.byType(CometChatMessageBubble))
            .style
            ?.border,
        border,
      );
    });

    testWidgets('someone else\'s poll takes the incoming pollsBubbleStyle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([_poll(byMe: false)]),
              style: const CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  pollsBubbleStyle: CometChatPollsBubbleStyle(
                    questionTextStyle: TextStyle(color: Color(0xFFA20001)),
                  ),
                ),
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  pollsBubbleStyle: CometChatPollsBubbleStyle(
                    questionTextStyle: TextStyle(color: Color(0xFFA20002)),
                    pollOptionsBackgroundColor: Color(0xFFA20003),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(_textColor(tester, 'Lunch?'), const Color(0xFFA20002));
      expect(
        _pollsBubble(tester).style?.pollOptionsBackgroundColor,
        const Color(0xFFA20003),
      );
    });

    testWidgets('AdditionalConfigurations.pollsBubbleStyle wins over the '
        'direction style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([_poll(byMe: true)]),
              additionalConfigurations: AdditionalConfigurations(
                pollsBubbleStyle: const CometChatPollsBubbleStyle(
                  questionTextStyle: TextStyle(color: Color(0xFFA30001)),
                ),
              ),
              style: const CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  pollsBubbleStyle: CometChatPollsBubbleStyle(
                    questionTextStyle: TextStyle(color: Color(0xFFA30002)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(_textColor(tester, 'Lunch?'), const Color(0xFFA30001));
      expect(
        _pollsBubble(tester).style?.questionTextStyle?.color,
        const Color(0xFFA30001),
      );
    });

    testWidgets('an app-supplied configuration shared by every row is not '
        'written to — each row gets its own side', (tester) async {
      final shared = AdditionalConfigurations();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([
                _poll(byMe: false, id: 3),
                _poll(byMe: true, id: 4),
              ]),
              additionalConfigurations: shared,
              style: const CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  pollsBubbleStyle: CometChatPollsBubbleStyle(
                    questionTextStyle: TextStyle(color: Color(0xFFA40001)),
                  ),
                ),
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  pollsBubbleStyle: CometChatPollsBubbleStyle(
                    questionTextStyle: TextStyle(color: Color(0xFFA40002)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      final colors = tester
          .widgetList<CometChatPollsBubble>(find.byType(CometChatPollsBubble))
          .map((b) => b.style?.questionTextStyle?.color)
          .toSet();
      expect(colors, {const Color(0xFFA40001), const Color(0xFFA40002)});
      expect(shared.pollsBubbleStyle, isNull);
    });

    testWidgets('with no style set, the poll gets no style from the list', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([_poll(byMe: true)]),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(_pollsBubble(tester).style, isNull);
    });
  });

  group('stickers', () {
    testWidgets('my sticker paints the outgoing stickerBubbleStyle', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _them,
                messageListBloc: _mock([_sticker(byMe: true)]),
                style: const CometChatMessageListStyle(
                  outgoingMessageBubbleStyle:
                      CometChatOutgoingMessageBubbleStyle(
                        stickerBubbleStyle: CometChatStickerBubbleStyle(
                          backgroundColor: Color(0xFFB10001),
                        ),
                      ),
                  incomingMessageBubbleStyle:
                      CometChatIncomingMessageBubbleStyle(
                        stickerBubbleStyle: CometChatStickerBubbleStyle(
                          backgroundColor: Color(0xFFB10002),
                        ),
                      ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);

        final sticker = tester.widget<CometChatStickerBubble>(
          find.byType(CometChatStickerBubble),
        );
        expect(sticker.style?.backgroundColor, const Color(0xFFB10001));
        expect(sticker.style?.border, _erasedBorder);
        final painted = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(CometChatStickerBubble),
                matching: find.byType(Container),
              ),
            )
            .map((c) => (c.decoration as BoxDecoration?)?.color);
        expect(painted, contains(const Color(0xFFB10001)));
      });
    });

    testWidgets('someone else\'s sticker takes the incoming style', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _them,
                messageListBloc: _mock([_sticker(byMe: false)]),
                style: const CometChatMessageListStyle(
                  incomingMessageBubbleStyle:
                      CometChatIncomingMessageBubbleStyle(
                        stickerBubbleStyle: CometChatStickerBubbleStyle(
                          backgroundColor: Color(0xFFB20001),
                        ),
                      ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);

        expect(
          tester
              .widget<CometChatStickerBubble>(
                find.byType(CometChatStickerBubble),
              )
              .style
              ?.backgroundColor,
          const Color(0xFFB20001),
        );
      });
    });

    testWidgets('AdditionalConfigurations.stickerBubbleStyle wins', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _them,
                messageListBloc: _mock([_sticker(byMe: true)]),
                additionalConfigurations: AdditionalConfigurations(
                  stickerBubbleStyle: const CometChatStickerBubbleStyle(
                    backgroundColor: Color(0xFFB30001),
                  ),
                ),
                style: const CometChatMessageListStyle(
                  outgoingMessageBubbleStyle:
                      CometChatOutgoingMessageBubbleStyle(
                        stickerBubbleStyle: CometChatStickerBubbleStyle(
                          backgroundColor: Color(0xFFB30002),
                        ),
                      ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);

        final painted = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(CometChatStickerBubble),
                matching: find.byType(Container),
              ),
            )
            .map((c) => (c.decoration as BoxDecoration?)?.color);
        expect(painted, contains(const Color(0xFFB30001)));
        expect(painted, isNot(contains(const Color(0xFFB30002))));
      });
    });
  });

  group('collaborative document', () {
    testWidgets('my document card titles itself with the outgoing style', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([
                _custom(ExtensionType.document, byMe: true),
              ]),
              style: const CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  collaborativeDocumentBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        titleStyle: TextStyle(color: Color(0xFFC10001)),
                      ),
                ),
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  collaborativeDocumentBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        titleStyle: TextStyle(color: Color(0xFFC10002)),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      final title = _collabBubble(tester).title!;
      expect(_textColor(tester, title), const Color(0xFFC10001));
      expect(_collabBubble(tester).style?.border, _erasedBorder);
    });

    testWidgets('someone else\'s document card takes the incoming style', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([
                _custom(ExtensionType.document, byMe: false),
              ]),
              style: const CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  collaborativeDocumentBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        dividerColor: Color(0xFFC20001),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(
        tester
            .widget<Divider>(
              find.descendant(
                of: find.byType(CometChatCollaborativeBubble),
                matching: find.byType(Divider),
              ),
            )
            .color,
        const Color(0xFFC20001),
      );
    });

    testWidgets('AdditionalConfigurations.collaborativeDocumentBubbleStyle '
        'wins', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([
                _custom(ExtensionType.document, byMe: true),
              ]),
              additionalConfigurations: AdditionalConfigurations(
                collaborativeDocumentBubbleStyle:
                    const CometChatCollaborativeBubbleStyle(
                      titleStyle: TextStyle(color: Color(0xFFC30001)),
                    ),
              ),
              style: const CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  collaborativeDocumentBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        titleStyle: TextStyle(color: Color(0xFFC30002)),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      final title = _collabBubble(tester).title!;
      expect(_textColor(tester, title), const Color(0xFFC30001));
    });
  });

  group('collaborative whiteboard', () {
    testWidgets('my whiteboard card titles itself with the outgoing style', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([
                _custom(ExtensionType.whiteboard, byMe: true),
              ]),
              style: const CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  collaborativeWhiteboardBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        titleStyle: TextStyle(color: Color(0xFFD10001)),
                      ),
                ),
                // The document style must not leak onto a whiteboard.
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  collaborativeWhiteboardBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        titleStyle: TextStyle(color: Color(0xFFD10002)),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      final title = _collabBubble(tester).title!;
      expect(_textColor(tester, title), const Color(0xFFD10001));
      expect(_collabBubble(tester).style?.border, _erasedBorder);
    });

    testWidgets('someone else\'s whiteboard card takes the incoming style', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([
                _custom(ExtensionType.whiteboard, byMe: false),
              ]),
              style: const CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  collaborativeDocumentBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        titleStyle: TextStyle(color: Color(0xFFD20001)),
                      ),
                  collaborativeWhiteboardBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        titleStyle: TextStyle(color: Color(0xFFD20002)),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      final title = _collabBubble(tester).title!;
      expect(_textColor(tester, title), const Color(0xFFD20002));
    });

    testWidgets('AdditionalConfigurations.collaborativeWhiteboardBubbleStyle '
        'wins', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([
                _custom(ExtensionType.whiteboard, byMe: false),
              ]),
              additionalConfigurations: AdditionalConfigurations(
                collaborativeWhiteboardBubbleStyle:
                    const CometChatCollaborativeBubbleStyle(
                      titleStyle: TextStyle(color: Color(0xFFD30001)),
                    ),
              ),
              style: const CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  collaborativeWhiteboardBubbleStyle:
                      CometChatCollaborativeBubbleStyle(
                        titleStyle: TextStyle(color: Color(0xFFD30002)),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      final title = _collabBubble(tester).title!;
      expect(_textColor(tester, title), const Color(0xFFD30001));
    });
  });

  group('link preview', () {
    testWidgets('my link preview card takes the outgoing '
        'linkPreviewBubbleStyle, border included', (tester) async {
      const border = Border.fromBorderSide(
        BorderSide(color: Color(0xFFE10002), width: 2),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([_linkText(byMe: true)]),
              style: const CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  linkPreviewBubbleStyle: CometChatLinkPreviewBubbleStyle(
                    titleStyle: TextStyle(color: Color(0xFFE10001)),
                    border: border,
                  ),
                ),
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  linkPreviewBubbleStyle: CometChatLinkPreviewBubbleStyle(
                    titleStyle: TextStyle(color: Color(0xFFE10003)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(_textColor(tester, 'Example'), const Color(0xFFE10001));
      // The card sits inside the text bubble rather than being the bubble,
      // so its own border is kept.
      expect(_linkBubble(tester).style?.border, border);
    });

    testWidgets('someone else\'s link preview takes the incoming style', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([_linkText(byMe: false)]),
              style: const CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  linkPreviewBubbleStyle: CometChatLinkPreviewBubbleStyle(
                    backgroundColor: Color(0xFFE20001),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(
        tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(CometChatLinkPreviewBubble),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((d) => (d.decoration as BoxDecoration).color),
        contains(const Color(0xFFE20001)),
      );
    });

    testWidgets('AdditionalConfigurations.linkPreviewBubbleStyle wins', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([_linkText(byMe: true)]),
              additionalConfigurations: AdditionalConfigurations(
                linkPreviewBubbleStyle: const CometChatLinkPreviewBubbleStyle(
                  titleStyle: TextStyle(color: Color(0xFFE30001)),
                ),
              ),
              style: const CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  linkPreviewBubbleStyle: CometChatLinkPreviewBubbleStyle(
                    titleStyle: TextStyle(color: Color(0xFFE30002)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(_textColor(tester, 'Example'), const Color(0xFFE30001));
    });
  });

  group('long-press preview', () {
    testWidgets('the message-action overlay renders the poll with the same '
        'direction style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _mock([_poll(byMe: true)]),
              style: const CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  pollsBubbleStyle: CometChatPollsBubbleStyle(
                    questionTextStyle: TextStyle(color: Color(0xFFF10001)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      final longPress = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onLongPress != null,
      );
      tester.widget<GestureDetector>(longPress.first).onLongPress!();
      await _settle(tester);

      final bubbles = tester.widgetList<CometChatPollsBubble>(
        find.byType(CometChatPollsBubble),
      );
      // The row in the list plus its copy in the overlay.
      expect(bubbles.length, greaterThanOrEqualTo(2));
      for (final bubble in bubbles) {
        expect(bubble.style?.questionTextStyle?.color, const Color(0xFFF10001));
      }
    });
  });
}
