/// Value semantics of the composer's BLoC events.
///
/// Every event is an [Equatable], and what each one puts in `props` decides
/// whether two of them are the same event — which is what `distinct`,
/// `bloc_test` expectations and any event de-duplication downstream rely on.
/// These tests pin each event's identity payload, including the fields that
/// are deliberately left OUT of it.
///
///   flutter test test/chat_ui/message_composer/message_composer_event_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

User _user(String uid) => User(uid: uid, name: uid);
Group _group(String guid) => Group(guid: guid, name: guid, type: 'public');
TextMessage _text(String body) => TextMessage(
  text: body,
  receiverUid: 'bob',
  receiverType: 'user',
  type: CometChatMessageType.text,
);

void main() {
  group('events with no payload are interchangeable', () {
    test('each singleton event equals another of its own type only', () {
      const events = <MessageComposerEvent>[
        ClearComposer(),
        ClearEditMessage(),
        ClearReplyMessage(),
        StartTyping(),
        EndTyping(),
        ClearComposeText(),
        InitializeComposer(),
        StartAudioRecording(),
        CancelAudioRecording(),
        UnlockBottomPadding(),
        RequestComposerFocus(),
      ];

      for (final e in events) {
        expect(e.props, isEmpty, reason: '${e.runtimeType} carries no payload');
      }
      expect(const ClearComposer(), const ClearComposer());
      expect(const StartTyping(), isNot(const EndTyping()));
      expect(
        const ClearEditMessage(),
        isNot(const ClearReplyMessage()),
        reason: 'two payload-free events are still different events',
      );
    });
  });

  group('conversation and text events', () {
    test('ComposerSetUser is keyed by the user INSTANCE', () {
      final a = _user('a');
      expect(ComposerSetUser(a), ComposerSetUser(a));
      expect(ComposerSetUser(a), isNot(ComposerSetUser(_user('b'))));
      // The SDK's User is not an Equatable, so two reads of the same user are
      // two different events — re-fetching the user re-fires the setup.
      expect(ComposerSetUser(a), isNot(ComposerSetUser(_user('a'))));
      expect(ComposerSetUser(a).user.uid, 'a');
    });

    test('ComposerSetGroup is keyed by the group INSTANCE', () {
      final g = _group('g1');
      expect(ComposerSetGroup(g), ComposerSetGroup(g));
      expect(ComposerSetGroup(g), isNot(ComposerSetGroup(_group('g2'))));
      expect(ComposerSetGroup(g), isNot(ComposerSetGroup(_group('g1'))));
    });

    test('UpdateComposeText is keyed by the text', () {
      expect(const UpdateComposeText('hi'), const UpdateComposeText('hi'));
      expect(
        const UpdateComposeText('hi'),
        isNot(const UpdateComposeText('ho')),
      );
    });

    test('ComposeMessageReceived is keyed by text AND source id', () {
      expect(
        const ComposeMessageReceived(text: 'hi', id: {'k': 1}),
        const ComposeMessageReceived(text: 'hi', id: {'k': 1}),
      );
      expect(
        const ComposeMessageReceived(text: 'hi', id: {'k': 1}),
        isNot(const ComposeMessageReceived(text: 'hi', id: {'k': 2})),
      );
      expect(const ComposeMessageReceived(text: 'hi').id, isNull);
    });
  });

  group('send events', () {
    test('SendTextMessage is keyed by metadata and the processed message', () {
      const plain = SendTextMessage();
      expect(plain.metadata, isNull);
      expect(plain.processedMessage, isNull);
      expect(plain, const SendTextMessage());
      expect(
        const SendTextMessage(metadata: {'a': 1}),
        isNot(const SendTextMessage(metadata: {'a': 2})),
      );

      final processed = _text('hi');
      expect(
        SendTextMessage(processedMessage: processed),
        SendTextMessage(processedMessage: processed),
      );
      expect(
        SendTextMessage(processedMessage: processed),
        isNot(const SendTextMessage()),
      );
    });

    test('SendMediaMessage is keyed by every upload field', () {
      const base = SendMediaMessage(path: '/a.png', messageType: 'image');
      expect(
        base,
        const SendMediaMessage(path: '/a.png', messageType: 'image'),
      );
      expect(
        base,
        isNot(const SendMediaMessage(path: '/b.png', messageType: 'image')),
      );
      expect(
        base,
        isNot(const SendMediaMessage(path: '/a.png', messageType: 'file')),
      );
      expect(
        base,
        isNot(
          const SendMediaMessage(
            path: '/a.png',
            messageType: 'image',
            fileName: 'a.png',
          ),
        ),
        reason: 'the web-upload fields are part of the identity',
      );
      expect(
        const SendMediaMessage(
          path: '/a.png',
          messageType: 'image',
          fileBytes: [1, 2],
        ),
        isNot(
          const SendMediaMessage(
            path: '/a.png',
            messageType: 'image',
            fileBytes: [1, 3],
          ),
        ),
      );
      expect(base.fileBytes, isNull);
      expect(base.metadata, isNull);
    });

    test('SendCustomMessage is keyed by its data and type', () {
      const poll = SendCustomMessage(
        customData: {'q': 'tea?'},
        type: 'extension_poll',
      );
      expect(
        poll,
        const SendCustomMessage(
          customData: {'q': 'tea?'},
          type: 'extension_poll',
        ),
      );
      expect(
        poll,
        isNot(
          const SendCustomMessage(
            customData: {'q': 'tea?'},
            type: 'extension_sticker',
          ),
        ),
      );
    });

    test('SubmitAudioRecording is keyed by path, bytes and name', () {
      const a = SubmitAudioRecording('/tmp/voice.m4a');
      expect(a, const SubmitAudioRecording('/tmp/voice.m4a'));
      expect(a, isNot(const SubmitAudioRecording('/tmp/other.m4a')));
      expect(
        a,
        isNot(
          const SubmitAudioRecording('/tmp/voice.m4a', fileName: 'voice.m4a'),
        ),
      );
      expect(a.fileBytes, isNull);
      expect(a.fileName, isNull);
    });
  });

  group('edit and reply events', () {
    test('SetEditMessage and EditTextMessage are keyed by the message', () {
      final m = _text('hi');
      expect(SetEditMessage(m), SetEditMessage(m));
      expect(SetEditMessage(m), isNot(SetEditMessage(_text('ho'))));

      expect(
        EditTextMessage(processedMessage: m),
        EditTextMessage(processedMessage: m),
      );
      expect(const EditTextMessage().processedMessage, isNull);
    });

    test('SetReplyMessage is keyed by the message', () {
      final m = _text('hi');
      expect(SetReplyMessage(m), SetReplyMessage(m));
      expect(SetReplyMessage(m), isNot(SetReplyMessage(_text('ho'))));
    });

    test('MessageEditedExternally is keyed by the message', () {
      final m = _text('hi');
      expect(MessageEditedExternally(m), MessageEditedExternally(m));
      expect(
        MessageEditedExternally(m),
        isNot(MessageEditedExternally(_text('ho'))),
      );
    });

    test('an edit event and a reply event never collide', () {
      final m = _text('hi');
      expect(SetEditMessage(m), isNot(SetReplyMessage(m)));
    });
  });

  group('panel events', () {
    Widget builderA(BuildContext _) => const SizedBox();
    Widget builderB(BuildContext _) => const Placeholder();

    test('ShowPanel is keyed by id and position — NOT by the builder', () {
      final a = ShowPanel(
        id: const {'composerId': 1},
        position: CustomUIPosition.composerTop,
        builder: builderA,
      );
      final b = ShowPanel(
        id: const {'composerId': 1},
        position: CustomUIPosition.composerTop,
        builder: builderB,
      );
      // Two panels for the same slot are the same event even though they would
      // render different widgets — the slot, not the content, is the identity.
      expect(a, b);
      expect(a.builder, isNot(same(b.builder)));

      expect(
        a,
        isNot(
          ShowPanel(
            id: const {'composerId': 2},
            position: CustomUIPosition.composerTop,
            builder: builderA,
          ),
        ),
      );
      expect(
        a,
        isNot(
          ShowPanel(
            id: const {'composerId': 1},
            position: CustomUIPosition.composerBottom,
            builder: builderA,
          ),
        ),
      );
    });

    test('HidePanel is keyed by id and position', () {
      const a = HidePanel(
        id: {'composerId': 1},
        position: CustomUIPosition.composerTop,
      );
      expect(
        a,
        const HidePanel(
          id: {'composerId': 1},
          position: CustomUIPosition.composerTop,
        ),
      );
      expect(
        a,
        isNot(
          const HidePanel(
            id: {'composerId': 1},
            position: CustomUIPosition.composerBottom,
          ),
        ),
      );
      expect(
        const HidePanel(position: CustomUIPosition.composerTop).id,
        isNull,
      );
    });

    test('showing and hiding the same slot are different events', () {
      expect(
        ShowPanel(position: CustomUIPosition.composerTop, builder: builderA),
        isNot(const HidePanel(position: CustomUIPosition.composerTop)),
      );
    });
  });

  group('state-sync events', () {
    test('SetStreamingState is keyed by the flag', () {
      expect(
        const SetStreamingState(isStreaming: true),
        const SetStreamingState(isStreaming: true),
      );
      expect(
        const SetStreamingState(isStreaming: true),
        isNot(const SetStreamingState(isStreaming: false)),
      );
    });

    test('UserBlockedStatusChanged is keyed by user AND flag', () {
      final a = _user('a');
      expect(
        UserBlockedStatusChanged(user: a, isBlocked: true),
        UserBlockedStatusChanged(user: a, isBlocked: true),
      );
      expect(
        UserBlockedStatusChanged(user: a, isBlocked: true),
        isNot(UserBlockedStatusChanged(user: a, isBlocked: false)),
        reason: 'block and unblock must not be de-duplicated into one',
      );
    });

    test('LockBottomPadding is keyed by the height', () {
      expect(const LockBottomPadding(280), const LockBottomPadding(280));
      expect(const LockBottomPadding(280), isNot(const LockBottomPadding(300)));
    });

    test('UpdateParentMessageId is keyed by the thread parent', () {
      expect(const UpdateParentMessageId(42), const UpdateParentMessageId(42));
      expect(
        const UpdateParentMessageId(42),
        isNot(const UpdateParentMessageId(43)),
      );
      expect(const UpdateParentMessageId(42).parentMessageId, 42);
    });
  });
}
