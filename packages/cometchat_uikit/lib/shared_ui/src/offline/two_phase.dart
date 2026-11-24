import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';

import '../../../chat_ui/src/conversations/data/datasources/conversations_remote_datasource.dart';
import '../../../chat_ui/src/message_list/data/datasources/message_list_remote_datasource.dart';

/// The result of one phase of a two-phase read (W1 §2.5, PR #23 §3.3).
///
/// A two-phase read emits a [Cached] event (the first paint, from the local
/// store), then a [Server] event (the authoritative page), or a [PhaseError].
/// The stream closes after its terminal ([Server] or [PhaseError]); a lone
/// [Cached] is never terminal. Internal to the kit (not exported).
sealed class TwoPhaseResult<T> {
  const TwoPhaseResult();
}

/// Rows served from the local cache (the first paint). Never ends the stream.
class Cached<T> extends TwoPhaseResult<T> {
  /// Creates a cached phase.
  const Cached(this.rows);

  /// The cached rows.
  final List<T> rows;
}

/// Rows served from the server. Terminal.
class Server<T> extends TwoPhaseResult<T> {
  /// Creates a server phase.
  const Server(this.rows);

  /// The server rows.
  final List<T> rows;
}

/// The read failed. Terminal.
class PhaseError<T> extends TwoPhaseResult<T> {
  /// Creates an error phase.
  const PhaseError(this.error);

  /// The read error.
  final CometChatException error;
}

/// A message-list read that reports both phases (W1 §2.5).
///
/// Resolve one with [messageListTwoPhaseFor]: a datasource that implements
/// this interface is used as is, the kit's own `MessageListRemoteDataSourceImpl`
/// gets the SDK-backed [SdkMessageListTwoPhase], and any other custom
/// datasource gets `null` and keeps today's single-phase path. The kit's
/// exported datasource classes do not implement it directly, so no internal
/// type appears in a public signature.
abstract interface class MessageListTwoPhaseDataSource {
  /// Reads the previous (older) page in two phases.
  Stream<TwoPhaseResult<BaseMessage>> fetchPreviousTwoPhase(
    MessagesRequest request,
  );

  /// Reads the next (newer) page in two phases.
  Stream<TwoPhaseResult<BaseMessage>> fetchNextTwoPhase(
    MessagesRequest request,
  );
}

/// A conversation-list read that reports both phases (W1 §2.5). Resolve one
/// with [conversationsTwoPhaseFor].
abstract interface class ConversationsTwoPhaseDataSource {
  /// Reads the next page of conversations in two phases.
  Stream<TwoPhaseResult<Conversation>> fetchNextTwoPhase(
    ConversationsRequest request,
  );
}

/// A single-conversation read that reports both phases: the cached
/// conversation first (when the device has it), then the server's
/// (D60, BEH-READ-29). Resolve one with [conversationTwoPhaseFor].
abstract interface class ConversationTwoPhaseDataSource {
  /// Reads the conversation with [conversationWith] in two phases. The rows
  /// of each phase hold the one conversation (a [Cached] phase only when it
  /// is cached).
  Stream<TwoPhaseResult<Conversation>> getConversationTwoPhase({
    required String conversationWith,
    required String conversationType,
  });
}

/// The kit's SDK-backed two-phase message reader: passes a
/// [MessageFetchListener] to the request so the cached page paints first.
class SdkMessageListTwoPhase implements MessageListTwoPhaseDataSource {
  /// Creates the reader.
  const SdkMessageListTwoPhase();

  @override
  Stream<TwoPhaseResult<BaseMessage>> fetchPreviousTwoPhase(
    MessagesRequest request,
  ) => messageFetchStream((l) => request.fetchPrevious(listener: l));

  @override
  Stream<TwoPhaseResult<BaseMessage>> fetchNextTwoPhase(
    MessagesRequest request,
  ) => messageFetchStream((l) => request.fetchNext(listener: l));
}

/// The kit's SDK-backed two-phase conversations reader.
class SdkConversationsTwoPhase implements ConversationsTwoPhaseDataSource {
  /// Creates the reader.
  const SdkConversationsTwoPhase();

  @override
  Stream<TwoPhaseResult<Conversation>> fetchNextTwoPhase(
    ConversationsRequest request,
  ) => conversationFetchStream((l) => request.fetchNext(listener: l));
}

/// The kit's SDK-backed two-phase conversation reader: passes a
/// [ConversationDetailsListener] to `CometChat.getConversation` so the cached
/// conversation arrives first.
class SdkConversationTwoPhase implements ConversationTwoPhaseDataSource {
  /// Creates the reader.
  const SdkConversationTwoPhase();

  @override
  Stream<TwoPhaseResult<Conversation>> getConversationTwoPhase({
    required String conversationWith,
    required String conversationType,
  }) {
    final controller = StreamController<TwoPhaseResult<Conversation>>();
    var closed = false;
    void terminal(TwoPhaseResult<Conversation> event) {
      if (closed) return;
      closed = true;
      controller.add(event);
      controller.close();
    }

    controller.onListen = () {
      CometChat.getConversation(
        conversationWith,
        conversationType,
        onSuccess: (c) => terminal(Server([c])),
        onError: (e) => terminal(PhaseError(e)),
        listener: _ConversationDetailsListenerAdapter((c) {
          if (!closed) controller.add(Cached([c]));
        }),
      );
    };
    return controller.stream;
  }
}

/// Resolves the two-phase reader for a message-list datasource, or `null` when
/// a custom datasource does not support it (today's single-phase path).
MessageListTwoPhaseDataSource? messageListTwoPhaseFor(Object? dataSource) {
  if (dataSource is MessageListTwoPhaseDataSource) return dataSource;
  if (dataSource is MessageListRemoteDataSourceImpl) {
    return const SdkMessageListTwoPhase();
  }
  return null;
}

/// Resolves the two-phase conversation reader for a message-list datasource,
/// or `null` when a custom datasource does not support it (today's
/// repository read).
ConversationTwoPhaseDataSource? conversationTwoPhaseFor(Object? dataSource) {
  if (dataSource is ConversationTwoPhaseDataSource) return dataSource;
  if (dataSource is MessageListRemoteDataSourceImpl) {
    return const SdkConversationTwoPhase();
  }
  return null;
}

/// Resolves the two-phase reader for a conversations datasource, or `null`.
ConversationsTwoPhaseDataSource? conversationsTwoPhaseFor(Object? dataSource) {
  if (dataSource is ConversationsTwoPhaseDataSource) return dataSource;
  if (dataSource is ConversationsRemoteDataSourceImpl) {
    return const SdkConversationsTwoPhase();
  }
  return null;
}

/// Bridges a one-shot `MessagesRequest.fetchPrevious`/`fetchNext` call that is
/// given a [MessageFetchListener] (`onCachedMessages` / `onServerMessages` /
/// `onError`) into a [TwoPhaseResult] stream (W1 §2.5). The stream closes after
/// the first terminal (server page or error).
Stream<TwoPhaseResult<BaseMessage>> messageFetchStream(
  void Function(MessageFetchListener listener) start,
) {
  final controller = StreamController<TwoPhaseResult<BaseMessage>>();
  var closed = false;
  void terminal(TwoPhaseResult<BaseMessage> event) {
    if (closed) return;
    closed = true;
    controller.add(event);
    controller.close();
  }

  controller.onListen = () {
    start(
      _MessageFetchListenerAdapter(
        onCached: (rows) {
          if (!closed) controller.add(Cached(rows));
        },
        onServer: (rows) => terminal(Server(rows)),
        onError: (e) => terminal(PhaseError(e)),
      ),
    );
  };
  return controller.stream;
}

/// As [messageFetchStream], for a conversations read given a
/// [ConversationFetchListener].
Stream<TwoPhaseResult<Conversation>> conversationFetchStream(
  void Function(ConversationFetchListener listener) start,
) {
  final controller = StreamController<TwoPhaseResult<Conversation>>();
  var closed = false;
  void terminal(TwoPhaseResult<Conversation> event) {
    if (closed) return;
    closed = true;
    controller.add(event);
    controller.close();
  }

  controller.onListen = () {
    start(
      _ConversationFetchListenerAdapter(
        onCached: (rows) {
          if (!closed) controller.add(Cached(rows));
        },
        onServer: (rows) => terminal(Server(rows)),
        onError: (e) => terminal(PhaseError(e)),
      ),
    );
  };
  return controller.stream;
}

class _MessageFetchListenerAdapter implements MessageFetchListener {
  _MessageFetchListenerAdapter({
    required this.onCached,
    required this.onServer,
    required void Function(CometChatException) onError,
  }) : _onError = onError;
  final void Function(List<BaseMessage>) onCached;
  final void Function(List<BaseMessage>) onServer;
  final void Function(CometChatException) _onError;

  @override
  void onCachedMessages(List<BaseMessage> messages) => onCached(messages);

  @override
  void onServerMessages(List<BaseMessage> messages) => onServer(messages);

  @override
  void onError(CometChatException e) => _onError(e);
}

class _ConversationFetchListenerAdapter implements ConversationFetchListener {
  _ConversationFetchListenerAdapter({
    required this.onCached,
    required this.onServer,
    required void Function(CometChatException) onError,
  }) : _onError = onError;
  final void Function(List<Conversation>) onCached;
  final void Function(List<Conversation>) onServer;
  final void Function(CometChatException) _onError;

  @override
  void onCachedConversations(List<Conversation> conversations) =>
      onCached(conversations);

  @override
  void onServerConversations(List<Conversation> conversations) =>
      onServer(conversations);

  @override
  void onError(CometChatException e) => _onError(e);
}

/// Delivers only the cached phase; the server phase and its error reach
/// [SdkConversationTwoPhase] through `onSuccess` / `onError`, which also carry
/// the errors the listener never sees.
class _ConversationDetailsListenerAdapter
    implements ConversationDetailsListener {
  _ConversationDetailsListenerAdapter(this._onCached);
  final void Function(Conversation) _onCached;

  @override
  void onCachedConversation(Conversation conversation) =>
      _onCached(conversation);

  @override
  void onServerConversation(Conversation conversation) {}

  @override
  void onError(CometChatException e) {}
}
