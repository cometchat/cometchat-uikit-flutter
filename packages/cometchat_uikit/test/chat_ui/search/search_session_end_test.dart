/// Search results on session end and cache reset (G8, ENG-41569).
///
/// A message search with one filter chip and no keyword reads in two phases
/// with offline on, through `SearchOffline.debugFetchOverride`; offline off
/// reads through a fake SDK client. The hub is driven the way a logout
/// produces it: offline on during the session, the SDK then reports offline
/// off, and only then do the logout signals arrive.
///
///   flutter test test/chat_ui/search/search_session_end_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_errors.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/search_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
import 'package:cometchat_sdk/src/domain/repositories/conversations/conversation_repository.dart'
    as sdk;
import 'package:cometchat_sdk/src/domain/repositories/messages/message_repository.dart'
    as sdk;
import 'package:flutter_test/flutter_test.dart';

int _sdkCalls = 0;

class _FakeMessageRepository extends Fake implements sdk.MessageRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #getUserMessages ||
        name == #getGroupMessages ||
        name == #getMessages) {
      _sdkCalls++;
      return Future<sdk.MessagesResult>.sync(
        () => sdk.MessagesResult(messages: [_text(1)], hasMore: false),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

/// A keyword search reads conversations through `fetchNext`; the answer
/// waits for [_conversationsHold] when one is set.
Completer<void>? _conversationsHold;

class _FakeConversationRepository extends Fake
    implements sdk.ConversationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getConversations) {
      return Future<sdk.ConversationsResult>(() async {
        await _conversationsHold?.future;
        return sdk.ConversationsResult(
          conversations: [
            Conversation(
              conversationId: 'alice_user_bob',
              conversationType: 'user',
              conversationWith: User(uid: 'bob', name: 'bob'),
            ),
          ],
          hasMore: false,
          totalPages: 1,
          currentPage: 1,
        );
      });
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  @override
  final sdk.MessageRepository messages = _FakeMessageRepository();

  @override
  final sdk.ConversationRepository conversations =
      _FakeConversationRepository();

  @override
  Future<void> dispose() async {}
}

TextMessage _text(int id) => TextMessage(
  id: id,
  text: 'm$id',
  sender: User(uid: 'u1', name: 'u1'),
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
)..sentAt = DateTime.utc(2026, 1, 1, 0, 0, id);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

final _hub = OfflineHub.instance;

void _logout() {
  CometChat.debugSetOfflineEnabledOverride(false);
  _hub.onKitLogout();
  _hub.debugLogout();
}

void _cacheReset() =>
    _hub.debugCacheReset(OfflineCacheResetReason.encryptionChanged, 0);

List<int> _ids(SearchBloc bloc) => [for (final m in bloc.state.messages) m.id];

/// The reads the bloc made, and what each one answers.
final _requests = <MessagesRequest>[];
final _answers = <Stream<TwoPhaseResult<BaseMessage>>>[];

Stream<TwoPhaseResult<BaseMessage>> _phases(
  List<TwoPhaseResult<BaseMessage>> events,
) => Stream<TwoPhaseResult<BaseMessage>>.fromIterable(events);

Future<SearchBloc> _photoSearch() async {
  final bloc = SearchBloc(initialScope: SearchScope.messages);
  bloc.add(const SearchFilterToggled('Photos'));
  await _settle();
  return bloc;
}

void main() {
  setUp(() async {
    _sdkCalls = 0;
    _conversationsHold = null;
    _requests.clear();
    _answers.clear();
    SearchOffline.debugFetchOverride = (request) {
      _requests.add(request);
      return _answers.removeAt(0);
    };
    await sdk.SdkRegistry.clear();
    sdk.SdkRegistry.register(_FakeSdkClient());
    _hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    _hub.debugLoginSuccess('alice'); // offline on during this session
  });

  tearDown(() async {
    SearchOffline.debugFetchOverride = null;
    CometChat.debugSetOfflineEnabledOverride(null);
    await sdk.SdkRegistry.clear();
  });

  test('sessionEnded clears rows and resets paging', () async {
    _answers.add(
      _phases([
        Server([_text(1), _text(2)]),
      ]),
    );
    final bloc = await _photoSearch();
    addTearDown(bloc.close);
    expect(_ids(bloc), [2, 1]);

    _logout();
    await _settle();

    expect(bloc.state.messages, isEmpty);
    expect(bloc.state.messagesStatus, SearchStatus.initial);
    expect(bloc.state.hasMoreMessages, isFalse);

    // The next user's search reads page one from a fresh request.
    CometChat.debugSetOfflineEnabledOverride(true);
    _hub.debugLoginSuccess('bob');
    _answers.add(
      _phases([
        Server([_text(3)]),
      ]),
    );
    bloc.add(const RefreshCurrentSearch());
    await _settle();
    expect(_requests, hasLength(2));
    expect(identical(_requests[0], _requests[1]), isFalse);
    expect(_ids(bloc), [3]);
  });

  test('sessionEnded drops the result of a read in flight', () async {
    final pending = StreamController<TwoPhaseResult<BaseMessage>>();
    _answers.add(pending.stream);
    final bloc = await _photoSearch();
    addTearDown(bloc.close);

    _logout();
    await _settle();
    pending.add(Server([_text(1)]));
    await pending.close();
    await _settle();

    expect(bloc.state.messages, isEmpty);
    expect(bloc.state.messagesStatus, SearchStatus.initial);
  });

  test('sessionEnded clears conversation results and drops a read in '
      'flight', () async {
    final bloc = SearchBloc(initialScope: SearchScope.conversations);
    addTearDown(bloc.close);
    bloc.add(const SearchTextChanged('bob'));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _settle();
    expect(bloc.state.conversations, hasLength(1));

    _logout();
    await _settle();
    expect(bloc.state.conversations, isEmpty);
    expect(bloc.state.conversationsStatus, SearchStatus.initial);

    // A read started under the next user, then that session ends too.
    CometChat.debugSetOfflineEnabledOverride(true);
    _hub.debugLoginSuccess('carol');
    final hold = _conversationsHold = Completer<void>();
    bloc.add(const RefreshCurrentSearch());
    await _settle();
    _logout();
    await _settle();
    hold.complete();
    await _settle();
    expect(bloc.state.conversations, isEmpty);
    expect(bloc.state.conversationsStatus, SearchStatus.initial);
  });

  test('stale event is ignored', () async {
    _answers.add(
      _phases([
        Server([_text(1)]),
      ]),
    );
    final bloc = await _photoSearch();
    addTearDown(bloc.close);

    // Published, then the session ends before it is delivered: it belongs to
    // the old session, so it must not search again.
    _cacheReset();
    _logout();
    await _settle();

    expect(_requests, hasLength(1));
    expect(bloc.state.messages, isEmpty);
  });

  test('cacheReset clears then reloads once', () async {
    _answers.add(
      _phases([
        Server([_text(1)]),
      ]),
    );
    final bloc = await _photoSearch();
    addTearDown(bloc.close);
    final states = <SearchState>[];
    final sub = bloc.stream.listen(states.add);
    addTearDown(sub.cancel);

    _answers.add(
      _phases([
        Server([_text(2)]),
      ]),
    );
    _cacheReset();
    await _settle();

    expect(states.first.messages, isEmpty);
    expect(_requests, hasLength(2));
    expect(_ids(bloc), [2]);
  });

  test('cacheReset reload failure over rows is quiet', () async {
    _answers.add(
      _phases([
        Server([_text(1)]),
      ]),
    );
    final bloc = await _photoSearch();
    addTearDown(bloc.close);
    final errors = <CometChatException>[];
    void sink(CometChatException e) => errors.add(e);
    OfflineListErrors.listen(bloc, sink);
    addTearDown(() => OfflineListErrors.cancel(bloc, sink));

    _answers.add(
      _phases([
        Cached([_text(5)]),
        PhaseError(CometChatException('ERR_INTERNAL_SERVER', 'x', 'x')),
      ]),
    );
    _cacheReset();
    await _settle();

    expect(_ids(bloc), [5]);
    expect(errors, isEmpty);
  });

  test('offline off: no change', () async {
    _hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(false);
    _hub.debugLoginSuccess('alice');
    final bloc = await _photoSearch();
    addTearDown(bloc.close);
    expect(_ids(bloc), [1]);

    _cacheReset();
    _hub.onKitLogout();
    _hub.debugLogout();
    await _settle();

    expect(_ids(bloc), [1]);
    expect(_sdkCalls, 1);
  });

  test('close cancels the hub subscription', () async {
    final bloc = SearchBloc();
    expect(_hub.debugHasListeners, isTrue);
    await bloc.close();
    expect(_hub.debugHasListeners, isFalse);
  });
}
