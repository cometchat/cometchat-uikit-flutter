import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/bloc/message_composer_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/bloc/message_composer_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/domain/repositories/message_composer_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/domain/usecases/edit_message_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/domain/usecases/send_custom_message_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/domain/usecases/send_media_message_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/domain/usecases/send_text_message_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/domain/usecases/typing_usecases.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/enums.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

/// UI events reach *every* mounted composer, so each handler has to decide
/// whether an event is addressed to its conversation. `ccMessageEdited` checked
/// only `parentMessageId` — which is 0 for every main-conversation composer — so
/// editing a message in one chat pulled that text into another chat's composer
/// and overwrote whatever draft was sitting there. These tests pin the routing.
class MockMessageComposerRepository extends Mock
    implements MessageComposerRepository {}

class FakeUser extends Fake implements User {
  FakeUser({String uid = 'alice'}) : _uid = uid;
  final String _uid;
  @override
  String get uid => _uid;
  @override
  String get name => _uid;
  @override
  bool get blockedByMe => false;
  @override
  bool get hasBlockedMe => false;
}

class FakeGroup extends Fake implements Group {
  FakeGroup({String guid = 'team'}) : _guid = guid;
  final String _guid;
  @override
  String get guid => _guid;
  @override
  String get name => _guid;
}

/// A text message with controllable addressing.
class RoutedTextMessage extends Fake implements TextMessage {
  RoutedTextMessage({
    required this.receiverUid,
    required this.receiverType,
    this.text = 'edited elsewhere',
    this.sender,
    this.parentMessageId = 0,
  });

  @override
  final String receiverUid;
  @override
  final String receiverType;
  @override
  final String text;
  @override
  final User? sender;
  @override
  final int parentMessageId;
  @override
  int get id => 99;
  @override
  String get muid => 'muid_99';
  @override
  String get type => 'text';
  @override
  String get category => 'message';
  @override
  Map<String, dynamic>? get metadata => null;
}

class FakeBuildContext extends Fake implements BuildContext {}

void main() {
  late MockMessageComposerRepository repo;

  setUpAll(() {
    registerFallbackValue(
      RoutedTextMessage(receiverUid: 'x', receiverType: 'user'),
    );
  });

  setUp(() {
    repo = MockMessageComposerRepository();
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(FakeUser()));
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

  MessageComposerBloc makeBloc({User? user, Group? group}) =>
      MessageComposerBloc(
        context: FakeBuildContext(),
        user: user,
        group: group,
        sendTextMessageUseCase: SendTextMessageUseCase(repo),
        sendMediaMessageUseCase: SendMediaMessageUseCase(repo),
        sendCustomMessageUseCase: SendCustomMessageUseCase(repo),
        editMessageUseCase: EditMessageUseCase(repo),
        startTypingUseCase: StartTypingUseCase(repo),
        endTypingUseCase: EndTypingUseCase(repo),
        getLoggedInUserUseCase: GetMessageComposerLoggedInUserUseCase(repo),
        disableTypingEvents: true,
      );

  /// Let the bloc drain the events queued by the call under test.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('ccMessageEdited routing', () {
    test('ignores an edit raised in a different 1:1 conversation', () async {
      final bloc = makeBloc(user: FakeUser(uid: 'alice'));
      await settle();

      // An edit in the chat with bob, while this composer is bound to alice.
      bloc.ccMessageEdited(
        RoutedTextMessage(
          receiverUid: 'bob',
          receiverType: 'user',
          sender: FakeUser(uid: 'bob'),
        ),
        MessageEditStatus.inProgress,
      );
      await settle();

      expect(bloc.state.composeText, '');
      expect(bloc.state.editMessage, isNull);
      expect(bloc.state.status, isNot(MessageComposerStatus.editing));

      await bloc.close();
    });

    test('ignores an edit raised in a group while bound to a 1:1', () async {
      final bloc = makeBloc(user: FakeUser(uid: 'alice'));
      await settle();

      bloc.ccMessageEdited(
        RoutedTextMessage(
          receiverUid: 'team',
          receiverType: 'group',
          // Sent by the very peer this composer is bound to — must still not
          // match, because it is a group message.
          sender: FakeUser(uid: 'alice'),
        ),
        MessageEditStatus.inProgress,
      );
      await settle();

      expect(bloc.state.composeText, '');
      expect(bloc.state.editMessage, isNull);

      await bloc.close();
    });

    test('accepts an edit for its own conversation', () async {
      final bloc = makeBloc(user: FakeUser(uid: 'alice'));
      await settle();

      bloc.ccMessageEdited(
        RoutedTextMessage(
          receiverUid: 'alice',
          receiverType: 'user',
          text: 'mine to edit',
        ),
        MessageEditStatus.inProgress,
      );
      await settle();

      expect(bloc.state.composeText, 'mine to edit');
      expect(bloc.state.status, MessageComposerStatus.editing);

      await bloc.close();
    });

    test(
      'accepts an incoming 1:1 edit addressed to the logged-in user',
      () async {
        // Incoming messages carry the logged-in user as receiverUid; the peer is
        // the sender. The composer for that peer must still match.
        final bloc = makeBloc(user: FakeUser(uid: 'alice'));
        await settle();

        bloc.ccMessageEdited(
          RoutedTextMessage(
            receiverUid: 'me',
            receiverType: 'user',
            sender: FakeUser(uid: 'alice'),
            text: 'from alice',
          ),
          MessageEditStatus.inProgress,
        );
        await settle();

        expect(bloc.state.composeText, 'from alice');

        await bloc.close();
      },
    );

    test('accepts an edit for its own group', () async {
      final bloc = makeBloc(group: FakeGroup(guid: 'team'));
      await settle();

      bloc.ccMessageEdited(
        RoutedTextMessage(
          receiverUid: 'team',
          receiverType: 'group',
          text: 'group edit',
        ),
        MessageEditStatus.inProgress,
      );
      await settle();

      expect(bloc.state.composeText, 'group edit');

      await bloc.close();
    });
  });

  group('ccReplyToMessage routing', () {
    test('ignores a group message merely sent by the 1:1 peer', () async {
      final bloc = makeBloc(user: FakeUser(uid: 'alice'));
      await settle();

      bloc.ccReplyToMessage(
        RoutedTextMessage(
          receiverUid: 'team',
          receiverType: 'group',
          sender: FakeUser(uid: 'alice'),
        ),
      );
      await settle();

      expect(bloc.state.replyMessage, isNull);

      await bloc.close();
    });

    test('accepts a reply for its own conversation', () async {
      final bloc = makeBloc(user: FakeUser(uid: 'alice'));
      await settle();

      bloc.ccReplyToMessage(
        RoutedTextMessage(receiverUid: 'alice', receiverType: 'user'),
      );
      await settle();

      expect(bloc.state.replyMessage, isNotNull);

      await bloc.close();
    });
  });
}
