// ENG-41552: item E (a jump to a message never mixes in a page fetched for
// the window it replaced).

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The SDK exports none of these; they are the only seam a message fetch has.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/messages/message_repository.dart'
    as sdk;
import 'package:flutter_test/flutter_test.dart';

final _bob = User(uid: 'bob', name: 'Bob');

TextMessage _msg(int id, {User? sender}) => TextMessage(
  id: id,
  text: 'm$id',
  sender: sender ?? _bob,
  receiverUid: 'me',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + id * 1000),
);

List<TextMessage> _range(int from, int to) => [
  for (var i = from; i <= to; i++) _msg(i),
];

class _Repo extends Fake implements MessageListRepository {
  @override
  Future<Result<List<BaseMessage>>> getMessages({
    required String conversationWith,
    required String conversationType,
    int limit = 30,
    int? parentMessageId,
    List<String>? types,
    List<String>? categories,
    bool hideReplies = true,
    bool withParent = true,
  }) async => Success(_range(101, 130));

  @override
  Future<Result<Conversation>> getConversation({
    required String conversationWith,
    required String conversationType,
  }) async => const Failure(message: 'not needed');
}

/// Answers each page fetch from a queue, so a test decides when it lands.
class _Pages {
  final List<Completer<Result<List<BaseMessage>>>> older = [];
  final List<Completer<Result<List<BaseMessage>>>> newer = [];
}

class _Older extends LoadOlderMessagesUseCase {
  _Older(this.pages) : super(_Repo());
  final _Pages pages;

  @override
  Future<Result<List<BaseMessage>>> call({required MessagesRequest request}) {
    final c = Completer<Result<List<BaseMessage>>>();
    pages.older.add(c);
    return c.future;
  }
}

class _Newer extends LoadNewerMessagesUseCase {
  _Newer(this.pages) : super(_Repo());
  final _Pages pages;

  @override
  Future<Result<List<BaseMessage>>> call({required MessagesRequest request}) {
    final c = Completer<Result<List<BaseMessage>>>();
    pages.newer.add(c);
    return c.future;
  }
}

/// `CometChat.getMessageDetails` answers with message [id].
class _FakeMessages extends Fake implements sdk.MessageRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getMessageDetails) {
      final id = int.parse(invocation.positionalArguments.first as String);
      return Future<BaseMessage>.value(_msg(id));
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeSdk extends Fake implements sdk.SdkClient {
  @override
  final sdk.MessageRepository messages = _FakeMessages();

  @override
  Future<void> dispose() async {}
}

List<int> _ids(MessageListState s) => s.messages.map((m) => m.id).toList();

void main() {
  setUp(() => CometChat.debugSetOfflineEnabledOverride(false));
  tearDown(() => CometChat.debugSetOfflineEnabledOverride(null));

  MessageListBloc makeBloc({_Pages? pages}) => MessageListBloc(
    disableSDKListeners: true,
    disableReceipts: true,
    hideReplies: true,
    user: _bob,
    getMessagesUseCase: GetMessagesUseCase(_Repo()),
    loadOlderMessagesUseCase: pages == null ? null : _Older(pages),
    loadNewerMessagesUseCase: pages == null ? null : _Newer(pages),
  );

  group('E: jump to message (offline off)', () {
    setUp(() async {
      await sdk.SdkRegistry.clear();
      sdk.SdkRegistry.register(_FakeSdk());
    });
    tearDown(sdk.SdkRegistry.clear);

    Future<(MessageListBloc, _Pages)> loaded() async {
      final pages = _Pages();
      final bloc = makeBloc(pages: pages);
      addTearDown(bloc.close);
      bloc.add(
        const LoadMessages(conversationWith: 'bob', conversationType: 'user'),
      );
      await pumpEventQueue();
      expect(_ids(bloc.state), _range(101, 130).map((m) => m.id));
      expect(bloc.state.hasMoreOlder, isTrue);
      return (bloc, pages);
    }

    test('an older page in flight lands after the jump: it is dropped and '
        'paging works again', () async {
      final (bloc, pages) = await loaded();
      bloc.add(const LoadOlderMessages());
      await pumpEventQueue();
      expect(bloc.state.isLoadingOlder, isTrue);
      final stale = pages.older.single;

      bloc.add(const JumpToMessage(messageId: 500));
      await pumpEventQueue();
      pages.newer.single.complete(Success([_msg(501)]));
      await pumpEventQueue();
      expect(_ids(bloc.state), [500, 501]);
      expect(bloc.state.isLoadingOlder, isFalse);
      // A scroll during the jump does not page from the old window.
      bloc.add(const LoadOlderMessages());
      await pumpEventQueue();
      expect(pages.older, hasLength(2)); // only the jump's own older read
      final jumped = [..._range(470, 499).map((m) => m.id), 500, 501];
      pages.older[1].complete(Success(_range(470, 499)));
      await pumpEventQueue();
      expect(_ids(bloc.state), jumped);

      // The stale page (for the window before the jump) lands now.
      stale.complete(Success(_range(71, 100)));
      await pumpEventQueue();
      expect(_ids(bloc.state), jumped);
      expect(bloc.state.isLoadingOlder, isFalse);

      // Paging continues from the jumped window.
      bloc.add(const LoadOlderMessages());
      await pumpEventQueue();
      expect(pages.older, hasLength(3));
      pages.older[2].complete(Success([_msg(469)]));
      await pumpEventQueue();
      expect(_ids(bloc.state), [469, ...jumped]);
    });

    test('a later jump supersedes an earlier one still running', () async {
      final (bloc, pages) = await loaded();
      bloc.add(const JumpToMessage(messageId: 500));
      await pumpEventQueue();
      bloc.add(const JumpToMessage(messageId: 800));
      await pumpEventQueue();
      expect(pages.newer, hasLength(2));
      pages.newer[1].complete(Success([_msg(801)]));
      await pumpEventQueue();
      pages.newer[0].complete(Success([_msg(501)]));
      await pumpEventQueue();
      expect(_ids(bloc.state), [800, 801]);
      expect(pages.older, hasLength(1)); // the first jump stopped
      pages.older.single.complete(Success([_msg(799)]));
      await pumpEventQueue();
      expect(_ids(bloc.state), [799, 800, 801]);
    });
  });
}
