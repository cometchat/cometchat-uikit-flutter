import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';

import '../../../chat_ui/src/conversations/bloc/conversations_event.dart';
import '../../../chat_ui/src/conversations/bloc/conversations_state.dart';
import '../../../chat_ui/src/conversations/data/datasources/conversations_remote_datasource.dart';
import 'offline_notice.dart';

/// What the conversation-list seam (W3) may read and do without editing
/// `ConversationsBloc` (W1 §2.9). Internal to the kit.
///
/// Bound to the emitter of the handler that created it and to the list
/// generation at that moment; once [isStale], [emit] and [replaceRows] drop.
abstract interface class ConversationsSeamContext {
  /// The bloc's current state.
  ConversationsState get state;

  /// Emits through the running handler's emitter; dropped when [isStale].
  void emit(ConversationsState state);

  /// Replaces the rows the list holds (and its index map); dropped when
  /// [isStale].
  void replaceRows(List<Conversation> rows);

  /// The rows the list holds.
  List<Conversation> get rows;

  /// Dispatches an event to the bloc.
  void add(ConversationsEvent event);

  /// Shows a notice on this list (unless the widget hides notices).
  void postNotice(OfflineNotice notice);

  /// The list generation this context was created under.
  int get opGen;

  /// The list's current generation.
  int get listGen;

  /// Whether the list generation moved on since this context was created.
  bool get isStale;

  /// Whether the bloc is closed.
  bool get isClosed;

  /// An identity token for the list (the bloc), for per-list seam state kept
  /// in an `Expando` that the widget reads by its bloc. Never cast it.
  Object get owner;

  /// The logged-in user the list was loaded for.
  User? get loggedInUser;

  /// conversationId → row index.
  Map<String, int> get conversationIndexMap;

  /// The paging request (cursor) of the list.
  ConversationsRequest? get conversationsRequest;
  set conversationsRequest(ConversationsRequest? request);

  /// The caller-supplied request builder, or null for the plain unfiltered
  /// list (W3 reconciles the sync slice only for the plain list).
  ConversationsRequestBuilder? get requestBuilder;

  /// Rows per page.
  int get pageSize;

  /// The datasource behind the list when the kit's standard repository is in
  /// use (pass to `conversationsTwoPhaseFor`), else null.
  ConversationsRemoteDataSource? get remoteDataSource;
}

/// Gives the seam a way into the bloc from outside a handler: [run] queues
/// [body] on the bloc's event loop with a context bound to a live emitter.
abstract interface class ConversationsSeamHost {
  /// Queues [body] on the bloc's event loop with a context bound to a live emitter.
  void run(FutureOr<void> Function(ConversationsSeamContext ctx) body);

  /// Whether the bloc is closed.
  bool get isClosed;
}

final Expando<ConversationsSeamHost> _hosts = Expando('ConversationsSeamHost');

/// Registers [host] for [bloc]. Called by the bloc at construction.
void registerConversationsSeamHost(Object bloc, ConversationsSeamHost host) =>
    _hosts[bloc] = host;

/// The seam host of [bloc], or null (e.g. a test double).
ConversationsSeamHost? conversationsSeamHostOf(Object bloc) => _hosts[bloc];
