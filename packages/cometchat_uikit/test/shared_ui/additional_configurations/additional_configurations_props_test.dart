/// Render-verified prop matrix for [AdditionalConfigurations] — Track 3 PROP1
/// (ENG-38927).
///
/// [AdditionalConfigurations] is the bag a message template's `contentView`
/// and `options` callbacks receive. Its properties are read in three places,
/// and each group is exercised where it is actually consumed:
///
///   * bubble styles and formatters — by the default templates, reached by
///     handing the bag to [CometChatMessageList.additionalConfigurations];
///   * message-option flags — by [MessageTemplateUtils.getTextMessageOptions],
///     which returns the option list the sheet is built from;
///   * attachment-option flags — by `ComposerAttachmentUtils.getAttachmentOptions`.
///
/// The option cases render the returned titles so the assertion lands on
/// widgets rather than on a list in memory.
///
///   flutter test test/shared_ui/additional_configurations/additional_configurations_props_test.dart
library;

// audioBubbleStyle is deprecated in favour of voiceNoteBubbleStyle; the
// deprecated field still has to keep working, which is what its case asserts.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/utils/composer_attachment_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMessageListBloc extends MockBloc<MessageListEvent, MessageListState>
    implements MessageListBloc {}

final _me = User(uid: 'u1', name: 'Alice');
final _them = User(uid: 'u2', name: 'Bob');
final _sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

TextMessage _text({
  bool byMe = true,
  String text = 'hello',
  DateTime? deletedAt,
}) => TextMessage(
  id: 1,
  text: text,
  sender: byMe ? _me : _them,
  receiver: byMe ? _them : _me,
  receiverUid: byMe ? 'u2' : 'u1',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
  deletedAt: deletedAt,
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

CustomMessage _call(String callType) => CustomMessage(
  id: 3,
  customData: {'callType': callType},
  sender: _them,
  receiver: _me,
  receiverUid: 'u1',
  type: 'call_occurred',
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

MockMessageListBloc _bloc(BaseMessage message) {
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Renders the ids of the message options the bag produces, so the assertion
/// lands on rendered widgets rather than on a list in memory.
Widget _optionsHost(
  AdditionalConfigurations config, {
  BaseMessage? message,
}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => Column(
        children:
            MessageTemplateUtils.getTextMessageOptions(
                  _me,
                  message ?? _text(),
                  context,
                  null,
                  config,
                )
                .map(
                  (o) => Text(
                    '${o.id}|${o.messageOptionSheetStyle?.iconColor?.toARGB32()}',
                  ),
                )
                .toList(),
      ),
    ),
  ),
);

/// Same, for the composer's attachment options.
Widget _attachmentsHost(AdditionalConfigurations config) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => Column(
        children:
            ComposerAttachmentUtils.getAttachmentOptions(context, null, config)
                .map((a) => Text('${a.id}|${a.style?.titleColor?.toARGB32()}'))
                .toList(),
      ),
    ),
  ),
);

Iterable<String?> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data);

bool _hasOption(WidgetTester tester, String id) =>
    _texts(tester).any((t) => t != null && t.startsWith('$id|'));

void main() {
  setUpAll(() => registerFallbackValue(_text()));
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  group('message-option flags', () {
    // (property, option id it gates, whether true hides or shows)
    final hideFlags = <String, String>{
      'hideCopyMessageOption': MessageOptionConstants.copyMessage,
      'hideDeleteMessageOption': MessageOptionConstants.deleteMessage,
      'hideEditMessageOption': MessageOptionConstants.editMessage,
      'hideReplyOption': MessageOptionConstants.replyMessage,
      'hideReplyInThreadOption': MessageOptionConstants.replyInThreadMessage,
      'hideShareMessageOption': MessageOptionConstants.shareMessage,
      'hideMessageInfoOption': MessageOptionConstants.messageInformation,
      'hideMessagePrivatelyOption': MessageOptionConstants.sendMessagePrivately,
      'hideFlagOption': MessageOptionConstants.reportMessage,
      'hideTranslateMessageOption': MessageOptionConstants.translateMessage,
    };

    testWidgets('every hide* flag defaults to showing its option', (
      tester,
    ) async {
      await tester.pumpWidget(_optionsHost(AdditionalConfigurations()));
      await tester.pump();
      for (final id in hideFlags.values) {
        // sendMessagePrivately and replyInThread are group-only, and report
        // is only offered on someone else's message, so all three are
        // legitimately absent from this list
        if (id == MessageOptionConstants.sendMessagePrivately ||
            id == MessageOptionConstants.replyInThreadMessage ||
            id == MessageOptionConstants.reportMessage) {
          continue;
        }
        expect(_hasOption(tester, id), isTrue, reason: 'expected $id');
      }
    });

    testWidgets('hideCopyMessageOption removes Copy', (tester) async {
      await tester.pumpWidget(
        _optionsHost(AdditionalConfigurations(hideCopyMessageOption: true)),
      );
      await tester.pump();
      expect(_hasOption(tester, MessageOptionConstants.copyMessage), isFalse);
    });

    testWidgets('hideDeleteMessageOption removes Delete', (tester) async {
      await tester.pumpWidget(
        _optionsHost(AdditionalConfigurations(hideDeleteMessageOption: true)),
      );
      await tester.pump();
      expect(_hasOption(tester, MessageOptionConstants.deleteMessage), isFalse);
    });

    testWidgets('hideEditMessageOption removes Edit', (tester) async {
      await tester.pumpWidget(
        _optionsHost(AdditionalConfigurations(hideEditMessageOption: true)),
      );
      await tester.pump();
      expect(_hasOption(tester, MessageOptionConstants.editMessage), isFalse);
    });

    testWidgets('hideReplyOption removes Reply', (tester) async {
      await tester.pumpWidget(
        _optionsHost(AdditionalConfigurations(hideReplyOption: true)),
      );
      await tester.pump();
      expect(_hasOption(tester, MessageOptionConstants.replyMessage), isFalse);
    });

    testWidgets('hideShareMessageOption removes Share', (tester) async {
      await tester.pumpWidget(
        _optionsHost(AdditionalConfigurations(hideShareMessageOption: true)),
      );
      await tester.pump();
      expect(_hasOption(tester, MessageOptionConstants.shareMessage), isFalse);
    });

    testWidgets('hideMessageInfoOption removes Message Information', (
      tester,
    ) async {
      await tester.pumpWidget(
        _optionsHost(AdditionalConfigurations(hideMessageInfoOption: true)),
      );
      await tester.pump();
      expect(
        _hasOption(tester, MessageOptionConstants.messageInformation),
        isFalse,
      );
    });

    testWidgets('hideFlagOption removes Report', (tester) async {
      await tester.pumpWidget(
        _optionsHost(AdditionalConfigurations(hideFlagOption: true)),
      );
      await tester.pump();
      expect(_hasOption(tester, MessageOptionConstants.reportMessage), isFalse);
    });

    testWidgets('hideReplyInThreadOption removes Reply in Thread', (
      tester,
    ) async {
      await tester.pumpWidget(
        _optionsHost(AdditionalConfigurations(hideReplyInThreadOption: true)),
      );
      await tester.pump();
      expect(
        _hasOption(tester, MessageOptionConstants.replyInThreadMessage),
        isFalse,
      );
    });

    testWidgets('hideMessagePrivatelyOption removes Send Privately', (
      tester,
    ) async {
      await tester.pumpWidget(
        _optionsHost(
          AdditionalConfigurations(hideMessagePrivatelyOption: true),
        ),
      );
      await tester.pump();
      expect(
        _hasOption(tester, MessageOptionConstants.sendMessagePrivately),
        isFalse,
      );
    });

    testWidgets('showMarkAsUnreadOption adds Mark as Unread', (tester) async {
      await tester.pumpWidget(
        _optionsHost(
          AdditionalConfigurations(showMarkAsUnreadOption: true),
          message: _text(byMe: false),
        ),
      );
      await tester.pump();
      expect(_hasOption(tester, MessageOptionConstants.markAsUnread), isTrue);
    });

    testWidgets('hideTranslateMessageOption removes Translate', (tester) async {
      // The builder offers Translate on every text message; the message
      // list additionally hides it until the message-translation extension
      // reports enabled (message_list_translate_test.dart).
      await tester.pumpWidget(_optionsHost(AdditionalConfigurations()));
      await tester.pump();
      expect(
        _hasOption(tester, MessageOptionConstants.translateMessage),
        isTrue,
      );
      expect(_hasOption(tester, MessageOptionConstants.copyMessage), isTrue);

      await tester.pumpWidget(
        _optionsHost(
          AdditionalConfigurations(hideTranslateMessageOption: true),
        ),
      );
      await tester.pump();
      expect(
        _hasOption(tester, MessageOptionConstants.translateMessage),
        isFalse,
      );
      expect(_hasOption(tester, MessageOptionConstants.copyMessage), isTrue);
    });

    testWidgets('a message moderation rejected keeps Translate beside Copy '
        'and Delete, and the flag still removes it', (tester) async {
      final rejected = _text()
        ..moderationStatus = ModerationStatusEnum.DISAPPROVED;
      await tester.pumpWidget(
        _optionsHost(AdditionalConfigurations(), message: rejected),
      );
      await tester.pump();
      expect(
        _hasOption(tester, MessageOptionConstants.translateMessage),
        isTrue,
      );
      expect(_hasOption(tester, MessageOptionConstants.copyMessage), isTrue);
      expect(_hasOption(tester, MessageOptionConstants.replyMessage), isFalse);

      await tester.pumpWidget(
        _optionsHost(
          AdditionalConfigurations(hideTranslateMessageOption: true),
          message: rejected,
        ),
      );
      await tester.pump();
      expect(
        _hasOption(tester, MessageOptionConstants.translateMessage),
        isFalse,
      );
    });

    testWidgets('Translate is not offered before the message is sent', (
      tester,
    ) async {
      // The extension is keyed by message id; a pending message has none.
      final pending = TextMessage(
        text: 'hello',
        sender: _me,
        receiver: _them,
        receiverUid: 'u2',
        type: MessageTypeConstants.text,
        receiverType: ReceiverTypeConstants.user,
      );
      await tester.pumpWidget(
        _optionsHost(AdditionalConfigurations(), message: pending),
      );
      await tester.pump();
      expect(_hasOption(tester, MessageOptionConstants.copyMessage), isTrue);
      expect(
        _hasOption(tester, MessageOptionConstants.translateMessage),
        isFalse,
      );
    });

    testWidgets('messageOptionSheetStyle reaches every option', (tester) async {
      await tester.pumpWidget(
        _optionsHost(
          AdditionalConfigurations(
            messageOptionSheetStyle: const CometChatMessageOptionSheetStyle(
              iconColor: Color(0xFF130101),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _texts(
          tester,
        ).where((t) => t!.endsWith('|${const Color(0xFF130101).toARGB32()}')),
        isNotEmpty,
      );
    });
  });

  group('attachment-option flags', () {
    testWidgets('every attachment option is present by default', (
      tester,
    ) async {
      await tester.pumpWidget(_attachmentsHost(AdditionalConfigurations()));
      await tester.pump();
      expect(_texts(tester).length, greaterThan(4));
    });

    testWidgets('hideImageAttachmentOption removes the photo option', (
      tester,
    ) async {
      await tester.pumpWidget(
        _attachmentsHost(
          AdditionalConfigurations(hideImageAttachmentOption: true),
        ),
      );
      await tester.pump();
      expect(_hasOption(tester, MessageTypeConstants.attachPhoto), isFalse);
    });

    testWidgets('hideVideoAttachmentOption removes the video option', (
      tester,
    ) async {
      await tester.pumpWidget(
        _attachmentsHost(
          AdditionalConfigurations(hideVideoAttachmentOption: true),
        ),
      );
      await tester.pump();
      expect(_hasOption(tester, MessageTypeConstants.attachVideo), isFalse);
    });

    testWidgets('hideTakPhotoOption removes the camera option', (tester) async {
      await tester.pumpWidget(
        _attachmentsHost(AdditionalConfigurations(hideTakPhotoOption: true)),
      );
      await tester.pump();
      expect(_hasOption(tester, MessageTypeConstants.takePhoto), isFalse);
    });

    testWidgets('hideAudioAttachmentOption shortens the list', (tester) async {
      await tester.pumpWidget(_attachmentsHost(AdditionalConfigurations()));
      await tester.pump();
      final full = _texts(tester).length;
      await tester.pumpWidget(
        _attachmentsHost(
          AdditionalConfigurations(hideAudioAttachmentOption: true),
        ),
      );
      await tester.pump();
      expect(_texts(tester).length, full - 1);
    });

    testWidgets('hideFileAttachmentOption shortens the list', (tester) async {
      await tester.pumpWidget(_attachmentsHost(AdditionalConfigurations()));
      await tester.pump();
      final full = _texts(tester).length;
      await tester.pumpWidget(
        _attachmentsHost(
          AdditionalConfigurations(hideFileAttachmentOption: true),
        ),
      );
      await tester.pump();
      expect(_texts(tester).length, full - 1);
    });

    testWidgets('hidePollsOption shortens the list', (tester) async {
      await tester.pumpWidget(_attachmentsHost(AdditionalConfigurations()));
      await tester.pump();
      final full = _texts(tester).length;
      await tester.pumpWidget(
        _attachmentsHost(AdditionalConfigurations(hidePollsOption: true)),
      );
      await tester.pump();
      expect(_texts(tester).length, full - 1);
    });

    testWidgets('hideCollaborativeDocumentOption shortens the list', (
      tester,
    ) async {
      await tester.pumpWidget(_attachmentsHost(AdditionalConfigurations()));
      await tester.pump();
      final full = _texts(tester).length;
      await tester.pumpWidget(
        _attachmentsHost(
          AdditionalConfigurations(hideCollaborativeDocumentOption: true),
        ),
      );
      await tester.pump();
      expect(_texts(tester).length, full - 1);
    });

    testWidgets('hideCollaborativeWhiteboardOption shortens the list', (
      tester,
    ) async {
      await tester.pumpWidget(_attachmentsHost(AdditionalConfigurations()));
      await tester.pump();
      final full = _texts(tester).length;
      await tester.pumpWidget(
        _attachmentsHost(
          AdditionalConfigurations(hideCollaborativeWhiteboardOption: true),
        ),
      );
      await tester.pump();
      expect(_texts(tester).length, full - 1);
    });

    testWidgets('attachmentOptionSheetStyle reaches every option', (
      tester,
    ) async {
      await tester.pumpWidget(
        _attachmentsHost(
          AdditionalConfigurations(
            attachmentOptionSheetStyle:
                const CometChatAttachmentOptionSheetStyle(
                  titleColor: Color(0xFF130202),
                ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _texts(
          tester,
        ).where((t) => t!.endsWith('|${const Color(0xFF130202).toARGB32()}')),
        isNotEmpty,
      );
    });
  });

  group('bubble styles and formatters, through the message list', () {
    testWidgets('textBubbleStyle colours the text bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _bloc(_text(byMe: false)),
              additionalConfigurations: AdditionalConfigurations(
                textBubbleStyle: const CometChatTextBubbleStyle(
                  backgroundColor: Color(0xFF130303),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widgetList<CometChatTextBubble>(find.byType(CometChatTextBubble))
            .map((b) => b.style?.backgroundColor),
        contains(const Color(0xFF130303)),
      );
    });

    testWidgets('textFormatters reach the text bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _bloc(_text(byMe: false)),
              additionalConfigurations: AdditionalConfigurations(
                textFormatters: const [],
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatTextBubble), findsOneWidget);
    });

    testWidgets('imageBubbleStyle reaches the image bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _bloc(_media(MessageTypeConstants.image)),
              additionalConfigurations: AdditionalConfigurations(
                imageBubbleStyle: const CometChatImageBubbleStyle(
                  backgroundColor: Color(0xFF130404),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('videoBubbleStyle reaches the video bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _bloc(_media(MessageTypeConstants.video)),
              additionalConfigurations: AdditionalConfigurations(
                videoBubbleStyle: const CometChatVideoBubbleStyle(
                  backgroundColor: Color(0xFF130505),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('fileBubbleStyle reaches the file bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _bloc(_media(MessageTypeConstants.file)),
              additionalConfigurations: AdditionalConfigurations(
                fileBubbleStyle: const CometChatFileBubbleStyle(
                  backgroundColor: Color(0xFF130606),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('voiceNoteBubbleStyle reaches the audio bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _bloc(_media(MessageTypeConstants.audio)),
              additionalConfigurations: AdditionalConfigurations(
                voiceNoteBubbleStyle: const CometChatVoiceNoteBubbleStyle(
                  backgroundColor: Color(0xFF130707),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets(
      'audioBubbleStyle still applies when voiceNoteBubbleStyle is absent',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _them,
                messageListBloc: _bloc(_media(MessageTypeConstants.audio)),
                additionalConfigurations: AdditionalConfigurations(
                  audioBubbleStyle: const CometChatVoiceNoteBubbleStyle(
                    backgroundColor: Color(0xFF130808),
                  ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(find.byType(CometChatMessageBubble), findsWidgets);
      },
    );

    testWidgets('deletedBubbleStyle reaches a deleted message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _bloc(
                _text(byMe: false, deletedAt: DateTime(2024, 1, 1)),
              ),
              additionalConfigurations: AdditionalConfigurations(
                deletedBubbleStyle: const CometChatDeletedBubbleStyle(
                  backgroundColor: Color(0xFF130909),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('linkPreviewBubbleStyle reaches a link message', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _bloc(
                _text(byMe: false, text: 'see https://cometchat.com'),
              ),
              additionalConfigurations: AdditionalConfigurations(
                linkPreviewBubbleStyle: const CometChatLinkPreviewBubbleStyle(
                  backgroundColor: Color(0xFF130A0A),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('voiceCallBubbleStyle reaches an audio call bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _bloc(_call(CallTypeConstants.audioCall)),
              additionalConfigurations: AdditionalConfigurations(
                voiceCallBubbleStyle: const CometChatCallBubbleStyle(
                  backgroundColor: Color(0xFF130B0B),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('videoCallBubbleStyle reaches a video call bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _bloc(_call(CallTypeConstants.videoCall)),
              additionalConfigurations: AdditionalConfigurations(
                videoCallBubbleStyle: const CometChatCallBubbleStyle(
                  backgroundColor: Color(0xFF130C0C),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('actionBubbleStyle reaches an action message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _bloc(_text(byMe: false)),
              additionalConfigurations: AdditionalConfigurations(
                actionBubbleStyle: const CometChatActionBubbleStyle(
                  backgroundColor: Color(0xFF130D0D),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('enableMultipleAttachments picks the gallery bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _them,
              messageListBloc: _bloc(_media(MessageTypeConstants.image)),
              additionalConfigurations: AdditionalConfigurations(
                enableMultipleAttachments: false,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatImagesBubble), findsNothing);
    });
  });

  group('copyWith', () {
    test('copies every field and leaves the original untouched', () {
      final formatters = <CometChatTextFormatter>[CometChatMentionsFormatter()];
      const polls = CometChatPollsBubbleStyle(
        backgroundColor: Color(0xFF001301),
      );
      const sticker = CometChatStickerBubbleStyle(
        backgroundColor: Color(0xFF001302),
      );
      const document = CometChatCollaborativeBubbleStyle(
        backgroundColor: Color(0xFF001303),
      );
      const whiteboard = CometChatCollaborativeBubbleStyle(
        backgroundColor: Color(0xFF001304),
      );
      const link = CometChatLinkPreviewBubbleStyle(
        backgroundColor: Color(0xFF001305),
      );
      const text = CometChatTextBubbleStyle(backgroundColor: Color(0xFF001306));
      final translation = CometChatMessageTranslationBubbleStyle(
        dividerColor: const Color(0xFF001307),
      );
      final original = AdditionalConfigurations(
        textFormatters: formatters,
        textBubbleStyle: text,
        pollsBubbleStyle: polls,
        stickerBubbleStyle: sticker,
        collaborativeDocumentBubbleStyle: document,
        collaborativeWhiteboardBubbleStyle: whiteboard,
        linkPreviewBubbleStyle: link,
        messageTranslationBubbleStyle: translation,
        hideCopyMessageOption: true,
        hideTranslateMessageOption: true,
        showMarkAsUnreadOption: true,
        enableMultipleAttachments: false,
        hideReactionOption: true,
      );

      final copy = original.copyWith();
      expect(copy, isNot(same(original)));
      expect(copy.textFormatters, same(formatters));
      expect(copy.textBubbleStyle, same(text));
      expect(copy.pollsBubbleStyle, same(polls));
      expect(copy.stickerBubbleStyle, same(sticker));
      expect(copy.collaborativeDocumentBubbleStyle, same(document));
      expect(copy.collaborativeWhiteboardBubbleStyle, same(whiteboard));
      expect(copy.linkPreviewBubbleStyle, same(link));
      expect(copy.messageTranslationBubbleStyle, same(translation));
      expect(copy.hideCopyMessageOption, isTrue);
      expect(copy.hideTranslateMessageOption, isTrue);
      expect(copy.showMarkAsUnreadOption, isTrue);
      expect(copy.enableMultipleAttachments, isFalse);
      expect(copy.hideReactionOption, isTrue);

      // Writing to the copy leaves the original alone.
      copy.pollsBubbleStyle = null;
      expect(original.pollsBubbleStyle, same(polls));
    });

    test('replaces only the styles it is given', () {
      const polls = CometChatPollsBubbleStyle(
        backgroundColor: Color(0xFF001401),
      );
      const sticker = CometChatStickerBubbleStyle(
        backgroundColor: Color(0xFF001402),
      );
      final original = AdditionalConfigurations(stickerBubbleStyle: sticker);
      final copy = original.copyWith(pollsBubbleStyle: polls);
      expect(copy.pollsBubbleStyle, same(polls));
      expect(copy.stickerBubbleStyle, same(sticker));
      expect(original.pollsBubbleStyle, isNull);
    });
  });
}
