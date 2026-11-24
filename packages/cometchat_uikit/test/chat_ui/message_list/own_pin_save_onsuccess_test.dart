/// ENG-41485 / D-326 (G11): the logged-in user's own pin, unpin, save and
/// unsave update the bubble from `onSuccess`, never from an SDK listener echo.
///
/// SDK 5.1.2 dropped the own pin/save echo (BEH-FLAG-04), and the message list
/// only ever updated the row from that echo, so the pin icon stayed missing
/// until the list reloaded. Every kit screen that pins or saves a message fires
/// `ccMessagePinned/Unpinned/Saved/Unsaved` with the message `onSuccess`
/// returned: the message options (`_handlePinToggle` / `_handleSaveToggle`),
/// the pinned panel's unpin and the saved panel's unsave. The list bloc now
/// applies those kit events through its pin/save merge path, and the echo
/// that SDK 5.1.0/5.1.1 still send is a no-op once the row matches, with
/// offline on or off.
///
///   flutter test test/chat_ui/message_list/own_pin_save_onsuccess_test.dart
library;

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/repositories/message_list_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_newer_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/load_older_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_read_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/mark_as_unread_usecase.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatMessageEvents, CometChatUIKit;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessageListRepository {}

class _FakeMessagesRequest extends Fake implements MessagesRequest {}

class _FakeConversation extends Fake implements Conversation {
  @override
  String? get conversationId => 'user_peer';
  @override
  int get unreadMessageCount => 0;
  @override
  int? get lastReadMessageId => 3;
}

const _me = 'me';
const _peer = 'peer';
const _thread = 99;

final _meUser = User(uid: _me, name: 'Me');
final _peerUser = User(uid: _peer, name: 'Peer');

final _pinTime = DateTime.fromMillisecondsSinceEpoch(1700000100000);
final _saveTime = DateTime.fromMillisecondsSinceEpoch(1700000200000);

/// A text message as the SDK hands it back. [parentId] puts it in a thread.
TextMessage _msg(
  int id, {
  int parentId = 0,
  String text = 'hello',
  DateTime? pinnedAt,
  String? pinnedBy,
  DateTime? savedAt,
}) {
  final m = TextMessage(
    id: id,
    muid: 'muid_$id',
    text: text,
    sender: _peerUser,
    receiverUid: _me,
    type: 'text',
    receiverType: 'user',
    category: 'message',
    parentMessageId: parentId,
    sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + id * 1000),
  );
  m.pinnedAt = pinnedAt;
  m.pinnedBy = pinnedBy;
  m.savedAt = savedAt;
  return m;
}

/// The message `onSuccess` returns: a copy of the row with this action's
/// field set. A pin frame carries no save state and a save frame no pin state.
TextMessage _returned(
  int id, {
  int parentId = 0,
  bool pinned = false,
  bool saved = false,
  bool pinScope = true,
}) => _msg(
  id,
  parentId: parentId,
  pinnedAt: pinScope && pinned ? _pinTime : null,
  pinnedBy: pinScope && pinned ? _me : null,
  savedAt: !pinScope && saved ? _saveTime : null,
);

/// Registers the bloc's listeners: the kit's own message events are
/// registered with the SDK ones, so this must be on.
MessageListBloc _bloc(_MockRepo repo, {int parentId = 0}) => MessageListBloc(
  getMessagesUseCase: GetMessagesUseCase(repo),
  loadOlderMessagesUseCase: LoadOlderMessagesUseCase(repo),
  loadNewerMessagesUseCase: LoadNewerMessagesUseCase(repo),
  markAsReadUseCase: MarkAsReadUseCase(repo),
  markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
  markAsUnreadUseCase: MarkAsUnreadUseCase(repo),
  getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
  user: _peerUser,
  parentMessageId: parentId == 0 ? null : parentId,
  disableSDKListeners: false,
);

Future<void> _load(MessageListBloc bloc, {int parentId = 0}) async {
  bloc.add(
    LoadMessages(
      conversationWith: _peer,
      conversationType: 'user',
      parentMessageId: parentId == 0 ? null : parentId,
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 60));
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 40));

BaseMessage _row(MessageListBloc bloc, int id) =>
    bloc.state.messages.firstWhere((m) => m.id == id);

List<int> _ids(MessageListBloc bloc) =>
    bloc.state.messages.map((m) => m.id).toList();

void main() {
  late _MockRepo repo;

  void seed(List<BaseMessage> rows) {
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
    ).thenAnswer((_) async => Success(rows));
  }

  setUpAll(() {
    registerFallbackValue(_FakeMessagesRequest());
    registerFallbackValue(_FakeConversation());
    registerFallbackValue(_msg(0));
  });

  setUp(() {
    CometChatUIKit.loggedInUser = _meUser;
    repo = _MockRepo();
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(_meUser));
    when(
      () => repo.getConversation(
        conversationWith: any(named: 'conversationWith'),
        conversationType: any(named: 'conversationType'),
      ),
    ).thenAnswer((_) async => Success(_FakeConversation()));
    when(
      () => repo.markAsRead(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.markAsDelivered(any()),
    ).thenAnswer((_) async => const Success(null));
  });

  tearDown(() => CometChatUIKit.loggedInUser = null);

  group(
    'own action, no SDK echo (5.1.2): the bubble updates from onSuccess',
    () {
      test('pin shows the pin indicator immediately', () async {
        seed([_msg(1), _msg(2), _msg(3)]);
        final bloc = _bloc(repo);
        await _load(bloc);

        CometChatMessageEvents.ccMessagePinned(_returned(2, pinned: true));
        await _settle();

        expect(_row(bloc, 2).pinnedAt, isNotNull);
        expect(_row(bloc, 2).pinnedBy, _me);
        expect(_ids(bloc), [1, 2, 3], reason: 'no duplicate, no reordering');
        await bloc.close();
      });

      test('unpin clears the pin indicator and keeps the save mark', () async {
        seed([
          _msg(1),
          _msg(2, pinnedAt: _pinTime, pinnedBy: _me, savedAt: _saveTime),
        ]);
        final bloc = _bloc(repo);
        await _load(bloc);

        CometChatMessageEvents.ccMessageUnpinned(_returned(2, pinned: false));
        await _settle();

        expect(_row(bloc, 2).pinnedAt, isNull);
        expect(_row(bloc, 2).pinnedBy, isNull);
        expect(_row(bloc, 2).savedAt, _saveTime, reason: 'save mark kept');
        expect(_ids(bloc), [1, 2]);
        await bloc.close();
      });

      test('save shows the save indicator and keeps the pin mark', () async {
        seed([_msg(1, pinnedAt: _pinTime, pinnedBy: _peer), _msg(2)]);
        final bloc = _bloc(repo);
        await _load(bloc);

        CometChatMessageEvents.ccMessageSaved(
          _returned(1, saved: true, pinScope: false),
        );
        await _settle();

        expect(_row(bloc, 1).savedAt, isNotNull);
        expect(_row(bloc, 1).pinnedAt, _pinTime, reason: 'pin mark kept');
        expect(_row(bloc, 1).pinnedBy, _peer);
        expect(_ids(bloc), [1, 2]);
        await bloc.close();
      });

      test('unsave clears the save indicator', () async {
        seed([_msg(1, savedAt: _saveTime), _msg(2)]);
        final bloc = _bloc(repo);
        await _load(bloc);

        CometChatMessageEvents.ccMessageUnsaved(
          _returned(1, saved: false, pinScope: false),
        );
        await _settle();

        expect(_row(bloc, 1).savedAt, isNull);
        expect(_ids(bloc), [1, 2]);
        await bloc.close();
      });

      test('the other fields of the message are not changed', () async {
        seed([_msg(1)]);
        final bloc = _bloc(repo);
        await _load(bloc);

        CometChatMessageEvents.ccMessagePinned(_returned(1, pinned: true));
        await _settle();

        final row = _row(bloc, 1) as TextMessage;
        expect(row.text, 'hello');
        expect(row.id, 1);
        expect(row.sender?.uid, _peer);
        await bloc.close();
      });
    },
  );

  group('panel actions update the bubble in the message list', () {
    // cometchat_pinned_messages.dart (unpin) and cometchat_saved_messages.dart
    // (unsave) fire these kit events with the message onSuccess returned.
    test('unpin from the pinned panel clears the bubble pin', () async {
      seed([_msg(1, pinnedAt: _pinTime, pinnedBy: _peer), _msg(2)]);
      final bloc = _bloc(repo);
      await _load(bloc);

      CometChatMessageEvents.ccMessageUnpinned(_returned(1, pinned: false));
      await _settle();

      expect(_row(bloc, 1).pinnedAt, isNull);
      expect(_ids(bloc), [1, 2]);
      await bloc.close();
    });

    test('unsave from the saved panel clears the bubble bookmark', () async {
      seed([_msg(1), _msg(2, savedAt: _saveTime)]);
      final bloc = _bloc(repo);
      await _load(bloc);

      CometChatMessageEvents.ccMessageUnsaved(
        _returned(2, saved: false, pinScope: false),
      );
      await _settle();

      expect(_row(bloc, 2).savedAt, isNull);
      expect(_ids(bloc), [1, 2]);
      await bloc.close();
    });
  });

  group('SDK 5.1.0/5.1.1 echo after onSuccess is a no-op', () {
    for (final offline in [false, true]) {
      final mode = offline ? 'offline on' : 'offline off';

      test(
        'pin then its echo: state unchanged, nothing duplicated ($mode)',
        () async {
          CometChat.debugSetOfflineEnabledOverride(offline);
          addTearDown(() => CometChat.debugSetOfflineEnabledOverride(null));
          seed([_msg(1), _msg(2)]);
          final bloc = _bloc(repo);
          await _load(bloc);

          final applied = _returned(2, pinned: true);
          CometChatMessageEvents.ccMessagePinned(applied);
          await _settle();
          final before = _row(bloc, 2);

          // The SDK listener's onMessagePinned routes here
          // (_MessageListMessageListener → _handleMessagePinSaveChanged).
          bloc.add(
            MessagePinSaveChanged(_returned(2, pinned: true), isPinScope: true),
          );
          await _settle();

          expect(
            identical(_row(bloc, 2), before),
            isTrue,
            reason: 'echo skipped',
          );
          expect(_row(bloc, 2).pinnedAt, isNotNull);
          expect(_ids(bloc), [1, 2]);
          await bloc.close();
        },
      );

      test('save then its echo: state unchanged ($mode)', () async {
        CometChat.debugSetOfflineEnabledOverride(offline);
        addTearDown(() => CometChat.debugSetOfflineEnabledOverride(null));
        seed([_msg(1)]);
        final bloc = _bloc(repo);
        await _load(bloc);

        CometChatMessageEvents.ccMessageSaved(
          _returned(1, saved: true, pinScope: false),
        );
        await _settle();
        final before = _row(bloc, 1);

        bloc.add(
          MessagePinSaveChanged(
            _returned(1, saved: true, pinScope: false),
            isPinScope: false,
          ),
        );
        await _settle();

        expect(
          identical(_row(bloc, 1), before),
          isTrue,
          reason: 'echo skipped',
        );
        expect(_ids(bloc), [1]);
        await bloc.close();
      });
    }

    test('an echo that arrives before onSuccess is applied once', () async {
      // 5.1.x fires the same-device listener before onSuccess.
      seed([_msg(1)]);
      final bloc = _bloc(repo);
      await _load(bloc);

      bloc.add(
        MessagePinSaveChanged(_returned(1, pinned: true), isPinScope: true),
      );
      await _settle();
      final before = _row(bloc, 1);
      CometChatMessageEvents.ccMessagePinned(_returned(1, pinned: true));
      await _settle();

      expect(identical(_row(bloc, 1), before), isTrue);
      expect(_row(bloc, 1).pinnedAt, isNotNull);
      expect(_ids(bloc), [1]);
      await bloc.close();
    });
  });

  test('an error leaves the row unchanged', () async {
    seed([_msg(1)]);
    final bloc = _bloc(repo);
    await _load(bloc);
    final before = _row(bloc, 1);

    // The toggle fires the kit event only for a non-null result, and a failed
    // call (here: no SDK session) answers null and calls onError instead.
    CometChatException? error;
    final updated = await CometChat.pinMessage(1, onError: (e) => error = e);
    if (updated != null) CometChatMessageEvents.ccMessagePinned(updated);
    await _settle();

    expect(updated, isNull);
    expect(error, isNotNull, reason: 'the toast path runs');
    expect(identical(_row(bloc, 1), before), isTrue);
    expect(_row(bloc, 1).pinnedAt, isNull);
    await bloc.close();
  });

  test('thread list: own pin updates the reply bubble immediately', () async {
    seed([_msg(10, parentId: _thread), _msg(11, parentId: _thread)]);
    final bloc = _bloc(repo, parentId: _thread);
    await _load(bloc, parentId: _thread);

    CometChatMessageEvents.ccMessagePinned(
      _returned(11, parentId: _thread, pinned: true),
    );
    CometChatMessageEvents.ccMessageSaved(
      _returned(10, parentId: _thread, saved: true, pinScope: false),
    );
    await _settle();

    expect(_row(bloc, 11).pinnedAt, isNotNull);
    expect(_row(bloc, 10).savedAt, isNotNull);
    expect(_ids(bloc), [10, 11]);
    await bloc.close();
  });

  test("another user's pin (SDK listener) still updates the row", () async {
    seed([_msg(1), _msg(2, savedAt: _saveTime)]);
    final bloc = _bloc(repo);
    await _load(bloc);

    // _MessageListMessageListener.onMessagePinned →
    // onMessagePinSaveChangedCallback(message, true) → this event.
    final theirs = _msg(2, pinnedAt: _pinTime, pinnedBy: _peer);
    bloc.add(MessagePinSaveChanged(theirs, isPinScope: true));
    await _settle();

    expect(_row(bloc, 2).pinnedBy, _peer);
    expect(_row(bloc, 2).savedAt, _saveTime, reason: 'my save kept');
    expect(_ids(bloc), [1, 2]);
    await bloc.close();
  });

  test('a kit event for a message not in this list is ignored', () async {
    seed([_msg(1)]);
    final bloc = _bloc(repo);
    await _load(bloc);
    final before = _row(bloc, 1);

    CometChatMessageEvents.ccMessagePinned(_returned(777, pinned: true));
    await _settle();

    expect(_ids(bloc), [1]);
    expect(identical(_row(bloc, 1), before), isTrue);
    await bloc.close();
  });

  test('a closed list no longer applies kit pin/save events', () async {
    seed([_msg(1)]);
    final bloc = _bloc(repo);
    await _load(bloc);
    await bloc.close();

    expect(
      () => CometChatMessageEvents.ccMessagePinned(_returned(1, pinned: true)),
      returnsNormally,
    );
  });
}
