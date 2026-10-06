/// [MessageComposerBloc] — the paths `message_composer_bloc_test.dart` leaves
/// out: the send/edit failure and custom-handler branches, caption editing of
/// a media message, the panel/padding plumbing, and every kit-event listener
/// callback the bloc mixes in.
///
/// The listeners are plain UI-event maps ([CometChatMessageEvents],
/// [CometChatUIEvents], [CometChatUserEvents],
/// [CometChatStreamCallBackEvents]), so each callback is driven end to end by
/// firing the corresponding static. Real SDK model objects are used
/// throughout, because half of what is asserted here is which fields survive a
/// clone or a metadata merge.
///
/// Not covered, and not coverable in a VM test: the `kIsWeb` voice-note upload
/// branch and `_uploadRecordingBytes`.
///
///   flutter test test/chat_ui/message_composer/message_composer_bloc_paths_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/enums.dart'
    as core_enums;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements MessageComposerRepository {}

class FakeContext extends Fake implements BuildContext {}

class FakeBaseMessage extends Fake implements BaseMessage {}

/// Records every kit message event, so an assertion can name the exact
/// sequence a send or edit announced.
class EventRecorder with CometChatMessageEventListener {
  final List<(BaseMessage, core_enums.MessageStatus)> sent = [];
  final List<(BaseMessage, MessageEditStatus)> edited = [];

  @override
  void ccMessageSent(BaseMessage message, core_enums.MessageStatus status) =>
      sent.add((message, status));

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) =>
      edited.add((message, status));
}

const _me = 'me';
const _peer = 'peer';

User user([String uid = _peer]) => User(uid: uid, name: 'User $uid');

Group chatGroup([String guid = 'team']) =>
    Group(guid: guid, name: 'Team', type: 'public');

TextMessage text({
  int id = 0,
  String body = 'hello',
  String muid = '',
  String receiverUid = _peer,
  String receiverType = ReceiverTypeConstants.user,
  int parentMessageId = 0,
  User? sender,
  Map<String, dynamic>? metadata,
}) => TextMessage(
  id: id,
  muid: muid,
  text: body,
  sender: sender,
  receiverUid: receiverUid,
  receiverType: receiverType,
  type: MessageTypeConstants.text,
  category: CometChatMessageCategory.message,
  parentMessageId: parentMessageId,
  metadata: metadata,
);

MediaMessage media({
  int id = 0,
  String? caption,
  String muid = '',
  String receiverUid = _peer,
  int parentMessageId = 0,
  Map<String, dynamic>? metadata,
}) => MediaMessage(
  id: id,
  muid: muid,
  caption: caption,
  receiverUid: receiverUid,
  receiverType: ReceiverTypeConstants.user,
  type: MessageTypeConstants.image,
  category: CometChatMessageCategory.message,
  parentMessageId: parentMessageId,
  metadata: metadata,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRepo repo;
  late EventRecorder recorder;

  setUpAll(() {
    registerFallbackValue(FakeBaseMessage());
    registerFallbackValue(text());
    registerFallbackValue(media());
    registerFallbackValue(
      CustomMessage(
        receiverUid: _peer,
        type: 'x',
        customData: const {},
        receiverType: ReceiverTypeConstants.user,
      ),
    );
  });

  setUp(() {
    repo = MockRepo();
    recorder = EventRecorder();
    CometChatMessageEvents.addMessagesListener('composer_paths', recorder);
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(user(_me)));
    when(
      () => repo.startTyping(
        receiverUid: any(named: 'receiverUid'),
        receiverType: any(named: 'receiverType'),
      ),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.endTyping(
        receiverUid: any(named: 'receiverUid'),
        receiverType: any(named: 'receiverType'),
      ),
    ).thenAnswer((_) async => const Success(null));
  });

  tearDown(() {
    CometChatMessageEvents.removeMessagesListener('composer_paths');
  });

  MessageComposerBloc makeBloc({
    User? asUser,
    Group? asGroup,
    int parentMessageId = 0,
    Function(BuildContext, BaseMessage, PreviewMessageMode?)? onSendButtonTap,
    OnError? errorCallback,
  }) => MessageComposerBloc(
    context: FakeContext(),
    user: asGroup == null ? (asUser ?? user()) : null,
    group: asGroup,
    parentMessageId: parentMessageId,
    onSendButtonTap: onSendButtonTap,
    errorCallback: errorCallback,
    sendTextMessageUseCase: SendTextMessageUseCase(repo),
    sendMediaMessageUseCase: SendMediaMessageUseCase(repo),
    sendCustomMessageUseCase: SendCustomMessageUseCase(repo),
    editMessageUseCase: EditMessageUseCase(repo),
    startTypingUseCase: StartTypingUseCase(repo),
    endTypingUseCase: EndTypingUseCase(repo),
    getLoggedInUserUseCase: GetMessageComposerLoggedInUserUseCase(repo),
    disableTypingEvents: true,
  );

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  /// A bloc whose InitializeComposer has already resolved.
  Future<MessageComposerBloc> ready({
    User? asUser,
    Group? asGroup,
    int parentMessageId = 0,
    Function(BuildContext, BaseMessage, PreviewMessageMode?)? onSendButtonTap,
    OnError? errorCallback,
  }) async {
    final bloc = makeBloc(
      asUser: asUser,
      asGroup: asGroup,
      parentMessageId: parentMessageId,
      onSendButtonTap: onSendButtonTap,
      errorCallback: errorCallback,
    );
    await settle();
    recorder.sent.clear();
    recorder.edited.clear();
    return bloc;
  }

  // =========================================================================
  // cloneMediaWithCaption
  // =========================================================================

  group('cloneMediaWithCaption', () {
    test('changes only the caption and copies the metadata map', () {
      final attachment = Attachment('u', 'n', 'png', 'image/png', 12);
      final quoted = text(id: 5, body: 'quoted');
      final original = MediaMessage(
        id: 11,
        muid: 'muid_11',
        sender: user(_me),
        receiver: user(),
        receiverUid: _peer,
        receiverType: ReceiverTypeConstants.user,
        type: MessageTypeConstants.image,
        category: CometChatMessageCategory.message,
        caption: 'before',
        attachment: attachment,
        attachments: [attachment],
        file: '/tmp/a.png',
        files: const ['/tmp/a.png'],
        tags: const ['t'],
        metadata: {'localPath': '/tmp/a.png'},
        sentAt: DateTime.utc(2026, 1, 1),
        deliveredAt: DateTime.utc(2026, 1, 2),
        readAt: DateTime.utc(2026, 1, 3),
        readByMeAt: DateTime.utc(2026, 1, 4),
        deliveredToMeAt: DateTime.utc(2026, 1, 5),
        editedAt: DateTime.utc(2026, 1, 6),
        editedBy: _me,
        updatedAt: DateTime.utc(2026, 1, 7),
        conversationId: 'user_peer',
        parentMessageId: 3,
        replyCount: 2,
        mentionedUsers: [user('mentioned')],
        hasMentionedMe: true,
        reactions: [ReactionCount(reaction: '👍', count: 1)],
        quotedMessage: quoted,
        quotedMessageId: 5,
      );

      final clone = MessageComposerBloc.cloneMediaWithCaption(
        original,
        'after',
      );

      expect(identical(clone, original), isFalse, reason: 'must be a copy');
      expect(clone.caption, 'after');
      expect(original.caption, 'before', reason: 'the original is untouched');

      expect(clone.id, 11);
      expect(clone.muid, 'muid_11');
      expect(clone.sender?.uid, _me);
      expect(clone.receiver, same(original.receiver));
      expect(clone.receiverUid, _peer);
      expect(clone.receiverType, ReceiverTypeConstants.user);
      expect(clone.type, MessageTypeConstants.image);
      expect(clone.category, CometChatMessageCategory.message);
      expect(clone.attachment, same(attachment));
      expect(clone.attachments, original.attachments);
      expect(clone.file, '/tmp/a.png');
      expect(clone.files, original.files);
      expect(clone.tags, original.tags);
      expect(clone.sentAt, DateTime.utc(2026, 1, 1));
      expect(clone.deliveredAt, DateTime.utc(2026, 1, 2));
      expect(clone.readAt, DateTime.utc(2026, 1, 3));
      expect(clone.readByMeAt, DateTime.utc(2026, 1, 4));
      expect(clone.deliveredToMeAt, DateTime.utc(2026, 1, 5));
      expect(clone.editedAt, DateTime.utc(2026, 1, 6));
      expect(clone.editedBy, _me);
      expect(clone.updatedAt, DateTime.utc(2026, 1, 7));
      expect(clone.conversationId, 'user_peer');
      expect(clone.parentMessageId, 3);
      expect(clone.replyCount, 2);
      expect(clone.mentionedUsers.single.uid, 'mentioned');
      expect(clone.hasMentionedMe, isTrue);
      expect(clone.reactions.single.reaction, '👍');
      expect(clone.quotedMessage, same(quoted));
      expect(clone.quotedMessageId, 5);

      // The metadata map is copied, not shared — otherwise a later error
      // stamp on the clone would leak back onto the original.
      expect(clone.metadata, original.metadata);
      expect(identical(clone.metadata, original.metadata), isFalse);
      clone.metadata!['error'] = 'x';
      expect(original.metadata!.containsKey('error'), isFalse);
    });

    test('a null metadata map stays null', () {
      final clone = MessageComposerBloc.cloneMediaWithCaption(
        media(caption: 'a'),
        'b',
      );
      expect(clone.metadata, isNull);
    });
  });

  // =========================================================================
  // InitializeComposer
  // =========================================================================

  test('a failed logged-in-user lookup leaves the composer usable', () async {
    when(() => repo.getLoggedInUser()).thenAnswer(
      (_) async => const Failure(message: 'no session', code: 'NO_SESSION'),
    );

    final bloc = makeBloc();
    await settle();

    expect(bloc.state.loggedInUser, isNull);
    expect(bloc.state.status, MessageComposerStatus.idle);
    await bloc.close();
  });

  // =========================================================================
  // SendTextMessage
  // =========================================================================

  group('SendTextMessage', () {
    test(
      'a processed message is sent as-is with the event metadata merged',
      () async {
        final processed = text(body: 'processed', metadata: {'a': 1, 'b': 1});
        when(
          () => repo.sendTextMessage(any()),
        ).thenAnswer((_) async => Success(processed));

        final bloc = await ready();
        bloc.add(
          SendTextMessage(
            processedMessage: processed,
            metadata: const {'b': 2, 'c': 3},
          ),
        );
        await settle();

        expect(processed.metadata, {
          'a': 1,
          'b': 2,
          'c': 3,
        }, reason: 'event metadata wins on conflict');
        final captured = verify(
          () => repo.sendTextMessage(captureAny()),
        ).captured.single;
        expect(captured, same(processed));
        await bloc.close();
      },
    );

    test('a custom send handler takes over and nothing is sent', () async {
      final handled = <(BaseMessage, PreviewMessageMode?)>[];
      final bloc = await ready(
        onSendButtonTap: (_, message, mode) => handled.add((message, mode)),
      );

      bloc.add(const UpdateComposeText('hi there'));
      await settle();
      bloc.add(const SendTextMessage());
      await settle();

      expect(handled, hasLength(1));
      expect((handled.single.$1 as TextMessage).text, 'hi there');
      expect(handled.single.$2, PreviewMessageMode.none);
      expect(bloc.state.status, MessageComposerStatus.idle);
      expect(recorder.sent, isEmpty, reason: 'the kit bus is not involved');
      verifyNever(() => repo.sendTextMessage(any()));
      await bloc.close();
    });

    test(
      'a failure stamps the error into existing metadata and reports it',
      () async {
        final errors = <Exception>[];
        when(() => repo.sendTextMessage(any())).thenAnswer(
          (_) async => const Failure(message: 'offline', code: 'NET'),
        );

        final bloc = await ready(errorCallback: errors.add);
        bloc.add(const UpdateComposeText('hi'));
        await settle();
        // Not `const`: see the FINDING below — a const metadata map crashes the
        // failure handler, which writes the error into the map in place.
        bloc.add(SendTextMessage(metadata: {'kept': true}));
        await settle();

        expect(bloc.state.status, MessageComposerStatus.error);
        expect(bloc.state.errorMessage, 'offline');
        expect((errors.single as CometChatException).code, 'NET');

        final failed = recorder.sent.last;
        expect(failed.$2, core_enums.MessageStatus.error);
        expect((failed.$1 as TextMessage).metadata, {
          'kept': true,
          'error': 'offline',
        });
        await bloc.close();
      },
    );

    test('a failure with no metadata creates the map', () async {
      when(
        () => repo.sendTextMessage(any()),
      ).thenAnswer((_) async => const Failure(message: 'offline'));

      final bloc = await ready();
      bloc.add(const UpdateComposeText('hi'));
      await settle();
      bloc.add(const SendTextMessage());
      await settle();

      expect(recorder.sent.last.$1.metadata, {'error': 'offline'});
      await bloc.close();
    });

    test('an unmodifiable metadata map crashes the failure handler', () async {
      // FINDING: `_onSendTextMessage` (and the media/custom/edit handlers,
      // which repeat the same three lines) writes the failure message into
      // `message.metadata` IN PLACE. `SendTextMessage(metadata: const {...})`
      // is a perfectly ordinary call — the event's constructor is const — but
      // a const map is unmodifiable, so the failure path throws
      // "Cannot modify unmodifiable map" out of the event handler instead of
      // emitting the error state. The composer is then wedged in `sending`.
      // The fix would be to copy the map rather than mutate it. Pinning the
      // current behaviour.
      when(
        () => repo.sendTextMessage(any()),
      ).thenAnswer((_) async => const Failure(message: 'offline'));

      final caught = <Object>[];
      late MessageComposerBloc bloc;

      // The bloc's event pipeline runs in the zone it was constructed in, so
      // the rethrown handler error only reaches a guard that wraps the
      // construction too.
      await runZonedGuarded(() async {
        bloc = makeBloc();
        await settle();
        bloc.add(const UpdateComposeText('hi'));
        await settle();
        bloc.add(const SendTextMessage(metadata: {'kept': true}));
        await settle();
      }, (error, _) => caught.add(error));

      expect(caught, hasLength(1));
      expect(caught.single, isUnsupportedError);
      expect(
        bloc.state.status,
        MessageComposerStatus.sending,
        reason: 'the error state is never reached',
      );
      await bloc.close();
    });

    test('a sent message with no muid inherits the local one', () async {
      when(() => repo.sendTextMessage(any())).thenAnswer(
        (invocation) async => Success(text(id: 99, body: 'hi', muid: '')),
      );

      final bloc = await ready();
      bloc.add(const UpdateComposeText('hi'));
      await settle();
      bloc.add(const SendTextMessage());
      await settle();

      final sent = recorder.sent.last;
      expect(sent.$2, core_enums.MessageStatus.sent);
      expect(
        sent.$1.muid,
        isNotEmpty,
        reason: 'the list matches the pending row by muid',
      );
      expect(bloc.state.status, MessageComposerStatus.success);
      await bloc.close();
    });

    test('a reply is quoted, and the reply preview is dismissed', () async {
      when(() => repo.sendTextMessage(any())).thenAnswer(
        (invocation) async =>
            Success(invocation.positionalArguments[0] as TextMessage),
      );

      final bloc = await ready();
      bloc.add(SetReplyMessage(text(id: 42, body: 'parent')));
      await settle();
      expect(bloc.state.isReplyMode, isTrue);

      bloc.add(const UpdateComposeText('answer'));
      await settle();
      bloc.add(const SendTextMessage());
      await settle();

      final captured =
          verify(() => repo.sendTextMessage(captureAny())).captured.single
              as TextMessage;
      expect(captured.quotedMessage?.id, 42);
      expect(captured.quotedMessageId, 42);
      expect(bloc.state.isReplyMode, isFalse);
      await bloc.close();
    });

    test('a reply to an unsent message carries no quoted id', () async {
      when(() => repo.sendTextMessage(any())).thenAnswer(
        (invocation) async =>
            Success(invocation.positionalArguments[0] as TextMessage),
      );

      final bloc = await ready();
      bloc.add(SetReplyMessage(text(body: 'not yet sent')));
      await settle();
      bloc.add(const UpdateComposeText('answer'));
      await settle();
      bloc.add(const SendTextMessage());
      await settle();

      final captured =
          verify(() => repo.sendTextMessage(captureAny())).captured.single
              as TextMessage;
      expect(captured.quotedMessage, isNotNull);
      expect(captured.quotedMessageId, 0);
      await bloc.close();
    });
  });

  // =========================================================================
  // The send sound
  // =========================================================================

  group('the send sound', () {
    const channel = MethodChannel('cometchat_chat_uikit');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      when(() => repo.sendTextMessage(any())).thenAnswer(
        (invocation) async =>
            Success(invocation.positionalArguments[0] as TextMessage),
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<void> sendOne(MessageComposerBloc bloc) async {
      bloc.add(const UpdateComposeText('hi'));
      await settle();
      bloc.add(const SendTextMessage());
      await settle();
    }

    test('a custom sound is played from the caller package', () async {
      final bloc = MessageComposerBloc(
        context: FakeContext(),
        user: user(),
        customSoundForMessage: 'assets/ping.wav',
        customSoundForMessagePackage: 'my_app',
        sendTextMessageUseCase: SendTextMessageUseCase(repo),
        sendMediaMessageUseCase: SendMediaMessageUseCase(repo),
        sendCustomMessageUseCase: SendCustomMessageUseCase(repo),
        editMessageUseCase: EditMessageUseCase(repo),
        startTypingUseCase: StartTypingUseCase(repo),
        endTypingUseCase: EndTypingUseCase(repo),
        getLoggedInUserUseCase: GetMessageComposerLoggedInUserUseCase(repo),
        disableTypingEvents: true,
      );
      await settle();
      await sendOne(bloc);

      final call = calls.single;
      expect(call.method, 'playCustomSound');
      final args = call.arguments as Map<Object?, Object?>;
      expect(args['assetAudioPath'], 'assets/ping.wav');
      expect(args['package'], 'my_app');
      await bloc.close();
    });

    test('silencing the composer plays nothing', () async {
      final bloc = MessageComposerBloc(
        context: FakeContext(),
        user: user(),
        disableSoundForMessages: true,
        sendTextMessageUseCase: SendTextMessageUseCase(repo),
        sendMediaMessageUseCase: SendMediaMessageUseCase(repo),
        sendCustomMessageUseCase: SendCustomMessageUseCase(repo),
        editMessageUseCase: EditMessageUseCase(repo),
        startTypingUseCase: StartTypingUseCase(repo),
        endTypingUseCase: EndTypingUseCase(repo),
        getLoggedInUserUseCase: GetMessageComposerLoggedInUserUseCase(repo),
        disableTypingEvents: true,
      );
      await settle();
      await sendOne(bloc);

      expect(calls, isEmpty);
      await bloc.close();
    });
  });

  // =========================================================================
  // SendMediaMessage
  // =========================================================================

  group('SendMediaMessage', () {
    test('a failure stamps the error and reports it', () async {
      final errors = <Exception>[];
      when(() => repo.sendMediaMessage(any())).thenAnswer(
        (_) async => const Failure(message: 'upload failed', code: 'UP'),
      );

      final bloc = await ready(errorCallback: errors.add);
      bloc.add(
        SendMediaMessage(
          path: '/tmp/a.png',
          messageType: MessageTypeConstants.image,
          metadata: {'localPath': '/tmp/a.png'},
        ),
      );
      await settle();

      expect(bloc.state.status, MessageComposerStatus.error);
      expect(bloc.state.errorMessage, 'upload failed');
      expect((errors.single as CometChatException).code, 'UP');
      expect(recorder.sent.last.$1.metadata, {
        'localPath': '/tmp/a.png',
        'error': 'upload failed',
      });
      await bloc.close();
    });

    test('a failure with no metadata creates the map', () async {
      when(
        () => repo.sendMediaMessage(any()),
      ).thenAnswer((_) async => const Failure(message: 'upload failed'));

      final bloc = await ready();
      bloc.add(
        const SendMediaMessage(
          path: '/tmp/a.png',
          messageType: MessageTypeConstants.image,
        ),
      );
      await settle();

      expect(recorder.sent.last.$1.metadata, {'error': 'upload failed'});
      await bloc.close();
    });

    test('a success keeps the local path, muid and local metadata', () async {
      when(
        () => repo.sendMediaMessage(any()),
      ).thenAnswer((_) async => Success(media(id: 77, muid: '')));

      final bloc = await ready();
      bloc.add(
        const SendMediaMessage(
          path: '/tmp/a.png',
          messageType: MessageTypeConstants.image,
          metadata: {'localPath': '/tmp/a.png', 'voiceNote': true},
        ),
      );
      await settle();

      final sent = recorder.sent.last.$1 as MediaMessage;
      expect(sent.file, '/tmp/a.png');
      expect(sent.muid, isNotEmpty);
      expect(sent.metadata, {'localPath': '/tmp/a.png', 'voiceNote': true});
      expect(bloc.state.status, MessageComposerStatus.success);
      await bloc.close();
    });

    test('a server echo wins over the local metadata on a key clash', () async {
      when(() => repo.sendMediaMessage(any())).thenAnswer(
        (_) async => Success(
          media(id: 77, muid: 'server', metadata: {'localPath': 'server'}),
        ),
      );

      final bloc = await ready();
      bloc.add(
        const SendMediaMessage(
          path: '/tmp/a.png',
          messageType: MessageTypeConstants.image,
          metadata: {'localPath': '/tmp/a.png', 'voiceNote': true},
        ),
      );
      await settle();

      expect(recorder.sent.last.$1.metadata, {
        'localPath': 'server',
        'voiceNote': true,
      });
      await bloc.close();
    });

    test('a media reply is quoted and the preview is dismissed', () async {
      when(() => repo.sendMediaMessage(any())).thenAnswer(
        (invocation) async =>
            Success(invocation.positionalArguments[0] as MediaMessage),
      );

      final bloc = await ready();
      bloc.add(SetReplyMessage(text(id: 8, body: 'parent')));
      await settle();
      bloc.add(
        const SendMediaMessage(
          path: '/tmp/a.png',
          messageType: MessageTypeConstants.image,
        ),
      );
      await settle();

      final captured =
          verify(() => repo.sendMediaMessage(captureAny())).captured.single
              as MediaMessage;
      expect(captured.quotedMessageId, 8);
      expect(bloc.state.isReplyMode, isFalse);
      await bloc.close();
    });
  });

  // =========================================================================
  // SendCustomMessage
  // =========================================================================

  group('SendCustomMessage', () {
    test('a custom reply is quoted', () async {
      when(() => repo.sendCustomMessage(any())).thenAnswer(
        (invocation) async =>
            Success(invocation.positionalArguments[0] as CustomMessage),
      );

      final bloc = await ready();
      bloc.add(SetReplyMessage(text(id: 6, body: 'parent')));
      await settle();
      bloc.add(
        const SendCustomMessage(type: 'poll', customData: {'q': 'why?'}),
      );
      await settle();

      final captured =
          verify(() => repo.sendCustomMessage(captureAny())).captured.single
              as CustomMessage;
      expect(captured.quotedMessageId, 6);
      expect(captured.customData, {'q': 'why?'});
      expect(bloc.state.isReplyMode, isFalse);
      await bloc.close();
    });

    test('a failure stamps the error and reports it', () async {
      final errors = <Exception>[];
      when(() => repo.sendCustomMessage(any())).thenAnswer(
        (_) async => const Failure(message: 'rejected', code: 'CUSTOM_ERR'),
      );

      final bloc = await ready(errorCallback: errors.add);
      bloc.add(const SendCustomMessage(type: 'poll', customData: {}));
      await settle();

      expect(bloc.state.status, MessageComposerStatus.error);
      expect(bloc.state.errorMessage, 'rejected');
      expect((errors.single as CometChatException).code, 'CUSTOM_ERR');
      expect(recorder.sent.last.$1.metadata, {'error': 'rejected'});
      await bloc.close();
    });

    test('a sent custom message with no muid inherits the local one', () async {
      when(() => repo.sendCustomMessage(any())).thenAnswer(
        (_) async => Success(
          CustomMessage(
            id: 5,
            receiverUid: _peer,
            type: 'poll',
            customData: const {},
            receiverType: ReceiverTypeConstants.user,
          ),
        ),
      );

      final bloc = await ready();
      bloc.add(const SendCustomMessage(type: 'poll', customData: {}));
      await settle();

      expect(recorder.sent.last.$1.muid, isNotEmpty);
      expect(bloc.state.status, MessageComposerStatus.success);
      await bloc.close();
    });
  });

  // =========================================================================
  // Editing
  // =========================================================================

  group('editing', () {
    test('SetEditMessage on a media message loads its caption', () async {
      final bloc = await ready();

      bloc.add(SetEditMessage(media(id: 3, caption: 'a caption')));
      await settle();

      expect(bloc.state.status, MessageComposerStatus.editing);
      expect(bloc.state.composeText, 'a caption');
      await bloc.close();
    });

    test('SetEditMessage on an unsupported kind loads nothing', () async {
      final bloc = await ready();

      bloc.add(
        SetEditMessage(
          CustomMessage(
            id: 4,
            receiverUid: _peer,
            type: 'poll',
            customData: const {},
            receiverType: ReceiverTypeConstants.user,
          ),
        ),
      );
      await settle();

      expect(bloc.state.composeText, '');
      expect(bloc.state.isEditMode, isTrue);
      await bloc.close();
    });

    test('an edit with nothing in edit mode is inert', () async {
      final bloc = await ready();

      bloc.add(const EditTextMessage());
      await settle();

      expect(bloc.state.status, MessageComposerStatus.idle);
      verifyNever(() => repo.editMessage(any()));
      await bloc.close();
    });

    test('an unchanged text edit is inert', () async {
      final bloc = await ready();

      bloc.add(SetEditMessage(text(id: 3, body: 'same')));
      await settle();
      bloc.add(const EditTextMessage());
      await settle();

      verifyNever(() => repo.editMessage(any()));
      expect(bloc.state.isEditMode, isTrue, reason: 'still editing');
      await bloc.close();
    });

    test('a caption edit is refused when there was no caption', () async {
      final bloc = await ready();

      bloc.add(SetEditMessage(media(id: 3)));
      await settle();
      bloc.add(const UpdateComposeText('new caption'));
      await settle();
      bloc.add(const EditTextMessage());
      await settle();

      verifyNever(() => repo.editMessage(any()));
      await bloc.close();
    });

    test('a caption edit is refused when the new caption is empty', () async {
      final bloc = await ready();

      bloc.add(SetEditMessage(media(id: 3, caption: 'before')));
      await settle();
      bloc.add(const UpdateComposeText('   '));
      await settle();
      bloc.add(const EditTextMessage());
      await settle();

      verifyNever(() => repo.editMessage(any()));
      await bloc.close();
    });

    test('an unchanged caption edit is inert', () async {
      final bloc = await ready();

      bloc.add(SetEditMessage(media(id: 3, caption: 'before')));
      await settle();
      bloc.add(const EditTextMessage());
      await settle();

      verifyNever(() => repo.editMessage(any()));
      await bloc.close();
    });

    test(
      'a caption edit sends a clone, optimistically then reconciled',
      () async {
        when(() => repo.editMessage(any())).thenAnswer(
          (invocation) async =>
              Success(invocation.positionalArguments[0] as BaseMessage),
        );

        final original = media(id: 3, caption: 'before');
        final bloc = await ready();

        bloc.add(SetEditMessage(original));
        await settle();
        bloc.add(const UpdateComposeText('after'));
        await settle();
        bloc.add(const EditTextMessage());
        await settle();

        final captured =
            verify(() => repo.editMessage(captureAny())).captured.single
                as MediaMessage;
        expect(captured.caption, 'after');
        expect(identical(captured, original), isFalse);
        expect(original.caption, 'before');

        // Optimistic announce first, then the server's echo.
        expect(recorder.edited, hasLength(2));
        expect(recorder.edited.first.$2, MessageEditStatus.success);
        expect(recorder.edited.first.$1.editedAt, isNotNull);
        expect(bloc.state.status, MessageComposerStatus.success);
        expect(bloc.state.isEditMode, isFalse);
        await bloc.close();
      },
    );

    test('a failed edit restores the original in the list', () async {
      final errors = <Exception>[];
      when(
        () => repo.editMessage(any()),
      ).thenAnswer((_) async => const Failure(message: 'edit rejected'));

      final original = text(id: 3, body: 'before');
      final bloc = await ready(errorCallback: errors.add);

      bloc.add(SetEditMessage(original));
      await settle();
      bloc.add(const UpdateComposeText('after'));
      await settle();
      bloc.add(const EditTextMessage());
      await settle();

      expect(recorder.edited, hasLength(2));
      expect(
        recorder.edited.last.$1,
        same(original),
        reason: 'the optimistic edit must be rolled back',
      );
      expect(recorder.sent.last.$2, core_enums.MessageStatus.error);
      expect(recorder.sent.last.$1.metadata, {'error': 'edit rejected'});
      expect((errors.single as CometChatException).code, 'EDIT_ERROR');
      expect(bloc.state.status, MessageComposerStatus.error);
      await bloc.close();
    });

    test(
      'a failed edit keeps the metadata the message already carried',
      () async {
        when(
          () => repo.editMessage(any()),
        ).thenAnswer((_) async => const Failure(message: 'edit rejected'));

        // The rebuilt edit copies the original's metadata, so the failure path
        // takes the "map already exists" arm.
        final original = text(id: 3, body: 'before', metadata: {'kept': true});
        final bloc = await ready();

        bloc.add(SetEditMessage(original));
        await settle();
        bloc.add(const UpdateComposeText('after'));
        await settle();
        bloc.add(const EditTextMessage());
        await settle();

        expect(recorder.sent.last.$1.metadata, {
          'kept': true,
          'error': 'edit rejected',
        });
        await bloc.close();
      },
    );

    test('a custom send handler takes over the edit too', () async {
      final handled = <(BaseMessage, PreviewMessageMode?)>[];
      final bloc = await ready(
        onSendButtonTap: (_, message, mode) => handled.add((message, mode)),
      );

      bloc.add(SetEditMessage(text(id: 3, body: 'before')));
      await settle();
      bloc.add(const UpdateComposeText('after'));
      await settle();
      bloc.add(const EditTextMessage());
      await settle();

      expect(handled.single.$2, PreviewMessageMode.edit);
      expect((handled.single.$1 as TextMessage).text, 'after');
      expect(bloc.state.status, MessageComposerStatus.idle);
      verifyNever(() => repo.editMessage(any()));
      await bloc.close();
    });

    test('a pre-processed edit skips the rebuild', () async {
      when(() => repo.editMessage(any())).thenAnswer(
        (invocation) async =>
            Success(invocation.positionalArguments[0] as BaseMessage),
      );

      final processed = text(id: 3, body: 'processed');
      final bloc = await ready();

      bloc.add(SetEditMessage(text(id: 3, body: 'before')));
      await settle();
      bloc.add(EditTextMessage(processedMessage: processed));
      await settle();

      expect(
        verify(() => repo.editMessage(captureAny())).captured.single,
        same(processed),
      );
      await bloc.close();
    });
  });

  // =========================================================================
  // Panels and padding
  // =========================================================================

  group('panels', () {
    Widget panel(BuildContext _) => const SizedBox(width: 7);

    test('each position fills and clears its own slot', () async {
      final bloc = await ready();

      for (final position in [
        CustomUIPosition.composerTop,
        CustomUIPosition.composerBottom,
        CustomUIPosition.composerPreview,
      ]) {
        bloc.add(ShowPanel(id: null, position: position, builder: panel));
        await settle();
      }

      expect(bloc.state.headerPanel, isNotNull);
      expect(bloc.state.footerPanel, isNotNull);
      expect(bloc.state.previewPanel, isNotNull);

      bloc.add(
        ShowPanel(
          id: null,
          position: CustomUIPosition.messageListTop,
          builder: panel,
        ),
      );
      await settle();

      bloc.add(
        const HidePanel(id: null, position: CustomUIPosition.composerTop),
      );
      await settle();
      expect(bloc.state.headerPanel, isNull);
      expect(bloc.state.footerPanel, isNotNull);

      bloc.add(
        const HidePanel(id: null, position: CustomUIPosition.composerPreview),
      );
      await settle();
      expect(bloc.state.previewPanel, isNull);
      await bloc.close();
    });

    test('hiding the footer also drops the locked padding', () async {
      final bloc = await ready();

      bloc.add(
        ShowPanel(
          id: null,
          position: CustomUIPosition.composerBottom,
          builder: panel,
        ),
      );
      bloc.add(const LockBottomPadding(120));
      await settle();
      expect(bloc.state.lockedBottomPadding, 120);

      bloc.add(
        const HidePanel(id: null, position: CustomUIPosition.composerBottom),
      );
      await settle();

      expect(bloc.state.footerPanel, isNull);
      expect(bloc.state.lockedBottomPadding, isNull);
      await bloc.close();
    });

    test('a panel addressed to another composer is ignored', () async {
      final bloc = await ready();
      final otherId = {'uid': 'somebody_else', 'parentMessageId': 0};

      bloc.add(
        ShowPanel(
          id: otherId,
          position: CustomUIPosition.composerTop,
          builder: panel,
        ),
      );
      await settle();
      expect(bloc.state.headerPanel, isNull);

      bloc.add(
        ShowPanel(
          id: null,
          position: CustomUIPosition.composerTop,
          builder: panel,
        ),
      );
      await settle();
      expect(bloc.state.headerPanel, isNotNull);

      bloc.add(HidePanel(id: otherId, position: CustomUIPosition.composerTop));
      await settle();
      expect(
        bloc.state.headerPanel,
        isNotNull,
        reason: 'another composer cannot close my panel',
      );
      await bloc.close();
    });

    test('unlockBottomPadding clears it', () async {
      final bloc = await ready();

      bloc.add(const LockBottomPadding(64));
      await settle();
      expect(bloc.state.lockedBottomPadding, 64);

      bloc.add(const UnlockBottomPadding());
      await settle();
      expect(bloc.state.lockedBottomPadding, isNull);
      await bloc.close();
    });
  });

  // =========================================================================
  // Thread rebinding
  // =========================================================================

  group('UpdateParentMessageId', () {
    test('rewrites the parent id and the composer id together', () async {
      final bloc = await ready(asUser: user('agent'));
      final before = bloc.state.composerId;

      bloc.add(const UpdateParentMessageId(55));
      await settle();

      expect(bloc.state.parentMessageId, 55);
      expect(bloc.state.composerId, isNot(before));
      expect(bloc.state.composerId['parentMessageId'], 55);
      await bloc.close();
    });

    test(
      'ccAgentChatThreadResolved rebinds only the matching composer',
      () async {
        final mine = await ready(asUser: user('agent'));
        final other = await ready(asUser: user('someone'));

        CometChatUIEvents.ccAgentChatThreadResolved(
          receiverId: 'agent',
          parentMessageId: 77,
        );
        await settle();

        expect(mine.state.parentMessageId, 77);
        expect(other.state.parentMessageId, 0);

        await mine.close();
        await other.close();
      },
    );

    test('a group composer ignores agent thread resolution', () async {
      final bloc = await ready(asGroup: chatGroup());

      CometChatUIEvents.ccAgentChatThreadResolved(
        receiverId: 'team',
        parentMessageId: 77,
      );
      await settle();

      expect(bloc.state.parentMessageId, 0);
      await bloc.close();
    });
  });

  // =========================================================================
  // Kit-event listener callbacks
  // =========================================================================

  group('kit event listeners', () {
    test('an external edit-in-progress loads the message to edit', () async {
      final bloc = await ready();

      CometChatMessageEvents.ccMessageEdited(
        text(id: 9, body: 'edit me'),
        MessageEditStatus.inProgress,
      );
      await settle();

      expect(bloc.state.isEditMode, isTrue);
      expect(bloc.state.composeText, 'edit me');
      await bloc.close();
    });

    test('an external edit of a media message loads its caption', () async {
      final bloc = await ready();

      CometChatMessageEvents.ccMessageEdited(
        media(id: 9, caption: 'cap'),
        MessageEditStatus.inProgress,
      );
      await settle();

      expect(bloc.state.composeText, 'cap');
      await bloc.close();
    });

    test('an external edit of another kind loads empty text', () async {
      final bloc = await ready();

      CometChatMessageEvents.ccMessageEdited(
        CustomMessage(
          id: 9,
          receiverUid: _peer,
          type: 'poll',
          customData: const {},
          receiverType: ReceiverTypeConstants.user,
        ),
        MessageEditStatus.inProgress,
      );
      await settle();

      expect(bloc.state.isEditMode, isTrue);
      expect(bloc.state.composeText, '');
      await bloc.close();
    });

    test('an edit for another conversation is ignored', () async {
      final bloc = await ready();

      CometChatMessageEvents.ccMessageEdited(
        text(id: 9, body: 'not mine', receiverUid: 'elsewhere'),
        MessageEditStatus.inProgress,
      );
      await settle();

      expect(bloc.state.isEditMode, isFalse);
      await bloc.close();
    });

    test('a completed edit is not loaded back into the composer', () async {
      final bloc = await ready();

      CometChatMessageEvents.ccMessageEdited(
        text(id: 9, body: 'done'),
        MessageEditStatus.success,
      );
      await settle();

      expect(bloc.state.isEditMode, isFalse);
      await bloc.close();
    });

    test('ccReplyToMessage arms reply mode for this thread only', () async {
      final bloc = await ready();

      CometChatMessageEvents.ccReplyToMessage(
        text(id: 9, body: 'in a thread', parentMessageId: 5),
      );
      await settle();
      expect(bloc.state.isReplyMode, isFalse, reason: 'wrong thread');

      CometChatMessageEvents.ccReplyToMessage(text(id: 9, body: 'reply me'));
      await settle();
      expect(bloc.state.replyMessage?.id, 9);
      await bloc.close();
    });

    test('an incoming 1:1 message matches by sender, not receiver', () async {
      final bloc = await ready();

      CometChatMessageEvents.ccReplyToMessage(
        text(id: 9, body: 'incoming', receiverUid: _me, sender: user(_peer)),
      );
      await settle();

      expect(bloc.state.replyMessage?.id, 9);
      await bloc.close();
    });

    test('a group composer matches by guid', () async {
      final bloc = await ready(asGroup: chatGroup());

      CometChatMessageEvents.ccReplyToMessage(
        text(
          id: 9,
          body: 'in the group',
          receiverUid: 'team',
          receiverType: ReceiverTypeConstants.group,
        ),
      );
      await settle();

      expect(bloc.state.replyMessage?.id, 9);
      await bloc.close();
    });

    test('any send in this conversation dismisses the reply preview', () async {
      for (final status in core_enums.MessageStatus.values) {
        final bloc = await ready();
        bloc.add(SetReplyMessage(text(id: 9, body: 'parent')));
        await settle();
        expect(bloc.state.isReplyMode, isTrue);

        CometChatMessageEvents.ccMessageSent(
          text(id: 10, body: 'from an extension'),
          status,
        );
        await settle();

        expect(bloc.state.isReplyMode, isFalse, reason: '$status');
        await bloc.close();
      }
    });

    test('a send in another conversation leaves the preview up', () async {
      final bloc = await ready();
      bloc.add(SetReplyMessage(text(id: 9, body: 'parent')));
      await settle();

      CometChatMessageEvents.ccMessageSent(
        text(id: 10, body: 'elsewhere', receiverUid: 'elsewhere'),
        core_enums.MessageStatus.sent,
      );
      await settle();

      expect(bloc.state.isReplyMode, isTrue);
      await bloc.close();
    });

    test('ccComposeMessage fills the composer', () async {
      final bloc = await ready();

      CometChatUIEvents.ccComposeMessage(
        'drafted elsewhere',
        MessageEditStatus.inProgress,
      );
      await settle();

      expect(bloc.state.composeText, 'drafted elsewhere');
      await bloc.close();
    });

    test('the streaming callbacks drive isActiveStreaming', () async {
      final bloc = await ready();

      CometChatStreamCallBackEvents.ccStreamInProgress(true);
      await settle();
      expect(bloc.state.isActiveStreaming, isTrue);

      CometChatStreamCallBackEvents.ccStreamCompleted(false);
      await settle();
      expect(
        bloc.state.isActiveStreaming,
        isTrue,
        reason: 'a false completion is not a completion',
      );

      CometChatStreamCallBackEvents.ccStreamCompleted(true);
      await settle();
      expect(bloc.state.isActiveStreaming, isFalse);

      CometChatStreamCallBackEvents.ccStreamInProgress(true);
      await settle();
      CometChatStreamCallBackEvents.ccStreamInterrupted(false);
      await settle();
      expect(bloc.state.isActiveStreaming, isTrue);

      CometChatStreamCallBackEvents.ccStreamInterrupted(true);
      await settle();
      expect(bloc.state.isActiveStreaming, isFalse);
      await bloc.close();
    });

    test('showPanel and hidePanel arrive through the UI event bus', () async {
      final bloc = await ready();

      CometChatUIEvents.showPanel(
        null,
        CustomUIPosition.composerTop,
        (_) => const SizedBox(),
      );
      await settle();
      expect(bloc.state.headerPanel, isNotNull);

      CometChatUIEvents.hidePanel(null, CustomUIPosition.composerTop);
      await settle();
      expect(bloc.state.headerPanel, isNull);
      await bloc.close();
    });

    test(
      'lock/unlock bottom padding arrive through the UI event bus',
      () async {
        final bloc = await ready();

        CometChatUIEvents.lockBottomPadding(null, 88);
        await settle();
        expect(bloc.state.lockedBottomPadding, 88);

        CometChatUIEvents.unlockBottomPadding(null);
        await settle();
        expect(bloc.state.lockedBottomPadding, isNull);

        // Addressed to somebody else: ignored on both sides.
        final otherId = {'uid': 'somebody_else', 'parentMessageId': 0};
        CometChatUIEvents.lockBottomPadding(otherId, 99);
        await settle();
        expect(bloc.state.lockedBottomPadding, isNull);

        CometChatUIEvents.lockBottomPadding(null, 12);
        await settle();
        CometChatUIEvents.unlockBottomPadding(otherId);
        await settle();
        expect(bloc.state.lockedBottomPadding, 12);
        await bloc.close();
      },
    );

    test(
      'requestComposerFocus calls the widget hook, once addressed',
      () async {
        var focused = 0;
        final bloc = await ready();
        bloc.onFocusRequested = () => focused++;

        CometChatUIEvents.requestComposerFocus({
          'uid': 'somebody_else',
          'parentMessageId': 0,
        });
        expect(focused, 0);

        CometChatUIEvents.requestComposerFocus(null);
        expect(focused, 1);
        await bloc.close();
      },
    );

    test('block and unblock update the user the composer holds', () async {
      final bloc = await ready();
      expect(bloc.state.userIsNotBlocked, isTrue);

      CometChatUserEvents.ccUserBlocked(
        User(uid: _peer, name: 'Peer', blockedByMe: true),
      );
      await settle();
      expect(bloc.state.userIsNotBlocked, isFalse);

      CometChatUserEvents.ccUserUnblocked(User(uid: _peer, name: 'Peer'));
      await settle();
      expect(bloc.state.userIsNotBlocked, isTrue);

      // Another user's block must not touch this composer.
      CometChatUserEvents.ccUserBlocked(
        User(uid: 'stranger', name: 'S', blockedByMe: true),
      );
      await settle();
      expect(bloc.state.userIsNotBlocked, isTrue);
      await bloc.close();
    });

    test('close() deregisters from every bus', () async {
      final before = CometChatMessageEvents.messagesListener.length;
      final bloc = await ready();
      expect(CometChatMessageEvents.messagesListener.length, before + 1);

      await bloc.close();
      expect(CometChatMessageEvents.messagesListener.length, before);

      // Nothing must reach the closed bloc.
      expect(
        () => CometChatUIEvents.ccComposeMessage(
          'late',
          MessageEditStatus.inProgress,
        ),
        returnsNormally,
      );
    });
  });
}
