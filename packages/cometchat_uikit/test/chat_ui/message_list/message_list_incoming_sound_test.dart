/// The message list's incoming-message sound (ENG-38688).
///
/// The bloc migration dropped it: CometChatMessageList stored
/// customSoundForMessages and never read it, and handed
/// disableSoundForMessages to a bloc that never played anything. The
/// conversations list stays silent for the open conversation because the
/// message list is meant to play its own, so a message arriving in the open
/// chat made no sound at all.
///
/// Each case drives the real MessageListBloc against a mocked repository and
/// records what the kit asks the platform to play, on the channel SoundManager
/// uses. Reverting the fix leaves every "plays" case with an empty recording.
///
///   flutter test test/chat_ui/message_list/message_list_incoming_sound_test.dart
library;

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/repositories/message_list_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_newer_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_older_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_read_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_unread_usecase.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show
        CometChatUIKit,
        MessageCategoryConstants,
        MessageTypeConstants,
        ReceiverTypeConstants,
        UpdateSettingsConstant;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/src/sound_loop_owner.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessageListRepository {}

final _me = User(uid: 'me-snd', name: 'Me');
final _bob = User(uid: 'bob-snd', name: 'Bob');
final _carol = User(uid: 'carol-snd', name: 'Carol');

/// The kit's incoming-message sound, as the platform receives it off Android.
const _kIncoming = 'assets/sound/incoming_message.wav';
const _kCustom = 'sounds/ping_snd.mp3';

/// The platform channel SoundManager plays through.
const _channel = MethodChannel('cometchat_chat_uikit');

/// Sound paths the kit asked the platform to play, oldest first.
final _played = <String?>[];

/// The package each of those plays named, in the same order.
final _packages = <String?>[];

TextMessage _text(int id, {User? sender, String? to, int parentId = 0}) =>
    TextMessage(
      id: id,
      muid: 'muid-snd-$id',
      text: 'hello $id',
      sender: sender ?? _bob,
      receiverUid: to ?? _me.uid,
      type: MessageTypeConstants.text,
      receiverType: ReceiverTypeConstants.user,
      category: MessageCategoryConstants.message,
      sentAt: DateTime(2026, 3, 14, 9, 30),
    )..parentMessageId = parentId;

CustomMessage _custom(int id, {required bool countsAsUnread}) => CustomMessage(
  id: id,
  muid: 'muid-snd-$id',
  customData: const {'k': 'v'},
  sender: _bob,
  receiverUid: _me.uid,
  receiverType: ReceiverTypeConstants.user,
  type: 'custom_snd',
  category: MessageCategoryConstants.custom,
  sentAt: DateTime(2026, 3, 14, 9, 30),
  metadata: {
    if (countsAsUnread) UpdateSettingsConstant.incrementUnreadCount: true,
  },
);

/// A bloc for the 1:1 chat with Bob, loaded (empty) and listening.
Future<MessageListBloc> _loaded({
  bool disableSoundForMessages = false,
  String? customSoundForMessages,
  String? customSoundForMessagePackage,
  bool hideReplies = true,
}) async {
  final repo = _MockRepo();
  when(
    () => repo.getMessages(
      conversationWith: any(named: 'conversationWith'),
      conversationType: any(named: 'conversationType'),
      limit: any(named: 'limit'),
      parentMessageId: any(named: 'parentMessageId'),
      types: any(named: 'types'),
      categories: any(named: 'categories'),
      hideReplies: any(named: 'hideReplies'),
      withParent: any(named: 'withParent'),
    ),
  ).thenAnswer((_) async => const Success(<BaseMessage>[]));
  final bloc = MessageListBloc(
    getMessagesUseCase: GetMessagesUseCase(repo),
    loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
    loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
    markAsReadUseCase: MarkAsReadUseCase(repo),
    markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
    markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
    user: _bob,
    // No receipts: the bloc would otherwise mark each arrival read through
    // the repository, which is not what these cases are about.
    disableReceipts: true,
    disableSDKListeners: true,
    hideReplies: hideReplies,
    disableSoundForMessages: disableSoundForMessages,
    customSoundForMessages: customSoundForMessages,
    customSoundForMessagePackage: customSoundForMessagePackage,
    // Every type and category, as the widget passes them, so the filters
    // admit the custom message.
    types: [MessageTypeConstants.text, 'custom_snd'],
    categories: [
      MessageCategoryConstants.message,
      MessageCategoryConstants.custom,
    ],
  );
  bloc.add(LoadMessages(conversationWith: _bob.uid, conversationType: 'user'));
  await _drain();
  expect(bloc.state.status, isNot(MessageListStatus.initial));
  return bloc;
}

Future<void> _drain() => Future<void>.delayed(const Duration(milliseconds: 20));

Future<List<String?>> _receive(MessageListBloc bloc, BaseMessage m) async {
  _played.clear();
  _packages.clear();
  bloc.add(MessageReceived(m));
  await _drain();
  return [..._played];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _played.clear();
    CometChatUIKit.loggedInUser = _me;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'playCustomSound') {
            final args = call.arguments as Map;
            _played.add(args['assetAudioPath'] as String?);
            _packages.add(args['package'] as String?);
          }
          return null;
        });
  });

  tearDown(() {
    CometChatUIKit.loggedInUser = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('a message from the other person plays the incoming sound', () async {
    final bloc = await _loaded();
    expect(await _receive(bloc, _text(1)), [_kIncoming]);
    expect(bloc.state.messages.map((m) => m.id), [1]);
    await bloc.close();
  });

  test('P3-E39: a message while an incoming call rings plays no sound, and '
      'the next one after the ringing does (round 3, P3-C16)', () async {
    final bloc = await _loaded();
    final ringing = Object();
    incomingRingtoneLoop.take(ringing);
    addTearDown(incomingRingtoneLoop.reset);

    expect(await _receive(bloc, _text(1)), isEmpty);
    expect(bloc.state.messages.map((m) => m.id), [1]);

    incomingRingtoneLoop.release(ringing);
    expect(await _receive(bloc, _text(2)), [_kIncoming]);
    await bloc.close();
  });

  test('customSoundForMessages replaces the incoming sound', () async {
    final bloc = await _loaded(customSoundForMessages: _kCustom);
    expect(await _receive(bloc, _text(1)), [_kCustom]);
    await bloc.close();
  });

  test(
    'customSoundForMessagePackage names the package that holds it',
    () async {
      final bloc = await _loaded(
        customSoundForMessages: _kCustom,
        customSoundForMessagePackage: 'my_sounds_snd',
      );
      expect(await _receive(bloc, _text(1)), [_kCustom]);
      expect(_packages, ['my_sounds_snd']);
      await bloc.close();
    },
  );

  test(
    'disableSoundForMessages silences it, and the message still lands',
    () async {
      final bloc = await _loaded(disableSoundForMessages: true);
      expect(await _receive(bloc, _text(1)), isEmpty);
      expect(bloc.state.messages.map((m) => m.id), [1]);
      await bloc.close();
    },
  );

  test('my own message, sent from another device, is silent', () async {
    final bloc = await _loaded();
    expect(await _receive(bloc, _text(1, sender: _me, to: _bob.uid)), isEmpty);
    await bloc.close();
  });

  test('a message for another conversation is silent', () async {
    final bloc = await _loaded();
    expect(await _receive(bloc, _text(1, sender: _carol)), isEmpty);
    await bloc.close();
  });

  test('a custom message plays only when it counts as unread', () async {
    final bloc = await _loaded();
    expect(await _receive(bloc, _custom(1, countsAsUnread: false)), isEmpty);
    expect(await _receive(bloc, _custom(2, countsAsUnread: true)), [
      _kIncoming,
    ]);
    await bloc.close();
  });

  test('a duplicate delivery of the same message plays once', () async {
    final bloc = await _loaded();
    expect(await _receive(bloc, _text(1)), [_kIncoming]);
    expect(await _receive(bloc, _text(1)), isEmpty);
    await bloc.close();
  });

  test('a thread reply the main list only counts still plays', () async {
    final bloc = await _loaded(hideReplies: true);
    expect(await _receive(bloc, _text(2, parentId: 1)), [_kIncoming]);
    expect(bloc.state.messages, isEmpty);
    await bloc.close();
  });
}
