// MessageListSeamContext (W1 §2.9): a seam can write the rows shown from its
// own file the way today's load paths do — integrator hooks run, index maps
// stay correct — and can build a read and reset the list with no triggering
// event (W2 refreshNewestWindow, W5 cache reset).

import 'dart:async';

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/repositories/message_list_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/domain/usecases/get_messages_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/utils/message_operation.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_list_seam_context.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo extends Fake implements MessageListRepository {
  _Repo(this.rows);
  final List<BaseMessage> rows;

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
  }) async => Success(rows);

  @override
  Future<Result<Conversation>> getConversation({
    required String conversationWith,
    required String conversationType,
  }) async => const Failure(message: 'not needed');
}

/// Records the integrator hooks.
class _HookedBloc extends MessageListBloc {
  _HookedBloc(MessageListRepository repo)
    : super(
        disableSDKListeners: true,
        disableReceipts: true,
        hideReplies: false,
        user: User(uid: 'bob', name: 'Bob'),
        getMessagesUseCase: GetMessagesUseCase(repo),
      );

  final List<List<int>> before = [];
  final List<List<int>> after = [];

  @override
  List<BaseMessage>? onBeforeMessagesSet(List<BaseMessage> messages) {
    before.add(messages.map((m) => m.id).toList());
    return messages;
  }

  @override
  void onAfterMessagesSet(List<BaseMessage> messages) {
    after.add(messages.map((m) => m.id).toList());
  }
}

TextMessage _text(int id) => TextMessage(
  id: id,
  muid: 'mu$id',
  text: 'm$id',
  sender: User(uid: 'bob', name: 'Bob'),
  receiverUid: 'alice',
  type: 'text',
  receiverType: 'user',
  sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + id),
);

/// Runs [body] through the bloc's seam host and waits for it.
Future<void> _run(
  MessageListBloc bloc,
  FutureOr<void> Function(MessageListSeamContext ctx) body,
) async {
  final done = Completer<void>();
  messageListSeamHostOf(bloc)!.run((ctx) async {
    await body(ctx);
    done.complete();
  });
  await done.future;
  await pumpEventQueue();
}

void main() {
  setUp(() {
    OfflineHub.instance.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
  });
  tearDown(() => CometChat.debugSetOfflineEnabledOverride(null));

  Future<_HookedBloc> loaded() async {
    final bloc = _HookedBloc(_Repo([_text(1), _text(3)]));
    addTearDown(bloc.close);
    bloc.add(
      const LoadMessages(conversationWith: 'bob', conversationType: 'user'),
    );
    await pumpEventQueue();
    expect(bloc.state.messages.map((m) => m.id), [1, 3]);
    return bloc;
  }

  test('a seam write runs the integrator hooks and keeps findMessageIndex '
      'correct', () async {
    final bloc = await loaded();
    expect(bloc.findMessageIndex(3), 1); // maps built, not dirty
    final ops = <MessageOperation>[];
    final sub = bloc.operationsStream.listen(ops.add);
    addTearDown(sub.cancel);

    await _run(bloc, (ctx) {
      final merged = [...ctx.state.messages]..insert(1, _text(2));
      final rows = ctx.onBeforeMessagesSet(merged)!;
      ctx.markIndexMapsDirty();
      ctx.emit(ctx.state.copyWith(messages: rows));
      ctx.addOperation(MessageOperation.set(rows, animated: false));
      ctx.onAfterMessagesSet(rows);
      expect(ctx.findMessageIndex(3), 2);
      expect(ctx.findMessageIndexByMuid('mu2'), 1);
    });

    expect(bloc.before, [
      [1, 3],
      [1, 2, 3],
    ]);
    expect(bloc.after, [
      [1, 3],
      [1, 2, 3],
    ]);
    expect(bloc.findMessageIndex(1), 0);
    expect(bloc.findMessageIndex(2), 1);
    expect(bloc.findMessageIndex(3), 2);
    expect(ops.single.messages!.map((m) => m.id), [1, 2, 3]);
  });

  test('builds an unanchored request from the list config', () async {
    final bloc = await loaded();
    await _run(bloc, (ctx) {
      final b = ctx.newMessagesRequestBuilder();
      expect(b.uid, 'bob');
      expect(b.limit, 30);
      expect(b.hideReplies, isFalse); // the bloc's hideReplies
      expect(ctx.hideReplies, isFalse);
      expect(ctx.conversationWith, 'bob');
      expect(ctx.conversationType, 'user');
      expect(ctx.disableReceipts, isTrue);

      ctx.initializeCursors(oldestMessageId: 1, newestMessageId: 3);
      expect(ctx.olderRequest, isNotNull);
      expect(ctx.newerRequest, isNotNull);
    });
  });

  test('resetList bumps the generation and clears the rows', () async {
    final bloc = await loaded();
    await _run(bloc, (ctx) {
      final fresh = ctx.resetList();
      expect(ctx.isStale, isTrue);
      expect(fresh.isStale, isFalse);
      expect(fresh.listGen, ctx.opGen + 1);
      expect(fresh.state.messages, isEmpty);
      expect(fresh.state.status, MessageListStatus.empty);
      expect(fresh.findMessageIndex(1), isNull);
      expect(fresh.olderRequest, isNull);
    });
  });

  test('consumeSkipNextUnreadDetection returns and clears the flag', () async {
    final bloc = await loaded();
    bloc.add(const ResetUnreadState());
    await pumpEventQueue();
    await _run(bloc, (ctx) {
      expect(ctx.consumeSkipNextUnreadDetection(), isTrue);
      expect(ctx.consumeSkipNextUnreadDetection(), isFalse);
    });
  });
}
