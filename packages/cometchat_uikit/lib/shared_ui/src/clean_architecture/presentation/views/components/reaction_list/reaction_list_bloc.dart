import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import "../../../../clean_architecture.dart";
import '../../../../../../../src/chat_sdk_listeners.dart';
import '../../../../../offline/message_list_offline_reads.dart'
    show isNotConnectedError;
import '../../../../../offline/offline_gate.dart';
import '../../../../../offline/offline_hub_event.dart';
import '../../../../../offline/offline_list_reset.dart';
import '../../../../../offline/reaction_list_offline.dart';
import '../../../../../offline/two_phase.dart';

// Events
abstract class ReactionListEvent extends Equatable {
  const ReactionListEvent();

  @override
  List<Object?> get props => [];
}

class InitializeReactionList extends ReactionListEvent {
  const InitializeReactionList();
}

class FetchReactions extends ReactionListEvent {
  final String reaction;

  const FetchReactions({this.reaction = ReactionConstants.allReactions});

  @override
  List<Object?> get props => [reaction];
}

class UpdateSelectedReaction extends ReactionListEvent {
  final String reaction;

  const UpdateSelectedReaction(this.reaction);

  @override
  List<Object?> get props => [reaction];
}

/// Removes the logged-in user's own reaction from the list.
///
/// Named `RemoveOwnReaction` rather than `RemoveReaction` because the message
/// list declares an event by the latter name, and the collision was previously
/// worked around with a `show` clause on this file's export — which took every
/// other event in this family off the public surface with it. ENG-39101.
class RemoveOwnReaction extends ReactionListEvent {
  final Reaction reaction;

  const RemoveOwnReaction(this.reaction);

  @override
  List<Object?> get props => [reaction];
}

class ReactionAdded extends ReactionListEvent {
  final Reaction reaction;

  const ReactionAdded(this.reaction);

  @override
  List<Object?> get props => [reaction];
}

class ReactionRemoved extends ReactionListEvent {
  final Reaction reaction;

  const ReactionRemoved(this.reaction);

  @override
  List<Object?> get props => [reaction];
}

// States
abstract class ReactionListState extends Equatable {
  const ReactionListState();

  @override
  List<Object?> get props => [];
}

class ReactionListInitial extends ReactionListState {
  const ReactionListInitial();
}

class ReactionListLoading extends ReactionListState {
  final Map<String, List<Reaction>> messageReactions;
  final String selectedReaction;

  const ReactionListLoading({
    required this.messageReactions,
    required this.selectedReaction,
  });

  @override
  List<Object?> get props => [messageReactions, selectedReaction];
}

class ReactionListLoaded extends ReactionListState {
  final Map<String, List<Reaction>> messageReactions;
  final String selectedReaction;
  final int totalReactions;
  final bool canFetchMore;

  const ReactionListLoaded({
    required this.messageReactions,
    required this.selectedReaction,
    required this.totalReactions,
    required this.canFetchMore,
  });

  // Computed properties
  List<Reaction> get reactionData {
    List<Reaction> usersWhoReacted = [];
    if (messageReactions.containsKey(selectedReaction)) {
      usersWhoReacted = messageReactions[selectedReaction]!.cast<Reaction>();
    } else if (selectedReaction == ReactionConstants.allReactions) {
      messageReactions.forEach((key, value) {
        usersWhoReacted.addAll(value.cast<Reaction>());
      });
    }
    return usersWhoReacted;
  }

  int getReactionCount(String reaction) {
    if (messageReactions.containsKey(reaction)) {
      return messageReactions[reaction]!.length;
    } else {
      return totalReactions;
    }
  }

  bool get isEmpty => messageReactions.isEmpty;

  @override
  List<Object?> get props => [
    messageReactions,
    selectedReaction,
    totalReactions,
    canFetchMore,
  ];

  ReactionListLoaded copyWith({
    Map<String, List<Reaction>>? messageReactions,
    String? selectedReaction,
    int? totalReactions,
    bool? canFetchMore,
  }) {
    return ReactionListLoaded(
      messageReactions: messageReactions ?? this.messageReactions,
      selectedReaction: selectedReaction ?? this.selectedReaction,
      totalReactions: totalReactions ?? this.totalReactions,
      canFetchMore: canFetchMore ?? this.canFetchMore,
    );
  }
}

class ReactionListError extends ReactionListState {
  final CometChatException error;
  final Map<String, List<Reaction>> messageReactions;
  final String selectedReaction;

  const ReactionListError({
    required this.error,
    required this.messageReactions,
    required this.selectedReaction,
  });

  @override
  List<Object?> get props => [error, messageReactions, selectedReaction];
}

// BLoC
class ReactionListBloc extends Bloc<ReactionListEvent, ReactionListState>
    with CometChatMessageEventListener {
  final int messageId;
  final ReactionsRequestBuilder? reactionsRequestBuilder;
  final BaseMessage? messageObject;
  final String initialSelectedReaction;

  final Map<String, ReactionsRequest> _reactionsRequests = {};
  final Map<String, bool> _hasMoreReactions = {};
  late String _eventListenerKey;

  ReactionListBloc({
    required this.messageId,
    this.reactionsRequestBuilder,
    this.messageObject,
    this.initialSelectedReaction = ReactionConstants.allReactions,
  }) : super(const ReactionListInitial()) {
    _eventListenerKey =
        "${DateTime.now().microsecondsSinceEpoch}_ReactionListBloc";
    CometChatMessageEvents.addMessagesListener(_eventListenerKey, this);

    on<InitializeReactionList>(_onInitialize);
    on<FetchReactions>(_onFetchReactions);
    on<UpdateSelectedReaction>(_onUpdateSelectedReaction);
    on<RemoveOwnReaction>(_onRemoveReaction);
    on<ReactionAdded>(_onReactionAdded);
    on<ReactionRemoved>(_onReactionRemoved);

    // Session end and cache reset (G8): offline on only.
    on<_OfflineListReset>(_onOfflineListReset);
    _offlineResetSub = OfflineListReset.listen(
      isClosed: () => isClosed,
      onReset: (event) {
        // Bump now so reads in flight stop writing at once.
        _listGen++;
        add(_OfflineListReset(event));
      },
    );

    // With offline on, the offline state ("Connect to load reactions") reads
    // again once on reconnect (D84 (8)).
    if (OfflineGate.isOn()) {
      _listensForConnect = true;
      ChatSdkListeners.addConnectionListener(
        _eventListenerKey,
        _ReactionListConnectionListener(_onConnected),
      );
    }
  }

  bool _listensForConnect = false;

  /// The list generation (G8). Bumped on a session end or cache reset; a
  /// read started under an older one drops its result.
  int _listGen = 0;

  StreamSubscription<OfflineHubEvent>? _offlineResetSub;

  /// Session end or cache reset (G8): clears the reactions and their SDK
  /// requests before the next frame. A session end leaves the list empty
  /// until it is next asked to load; a cache reset reloads once from page
  /// one (a failure over rows already keeps them, with no error).
  void _onOfflineListReset(
    _OfflineListReset event,
    Emitter<ReactionListState> emit,
  ) {
    final hubEvent = event.event;
    if (OfflineListReset.isStale(hubEvent)) return;
    _reactionsRequests.clear();
    _hasMoreReactions.clear();
    emit(const ReactionListInitial());
    if (hubEvent is CacheReset) add(const InitializeReactionList());
  }

  void _onConnected() {
    final s = state;
    if (isClosed || s is! ReactionListError || !isNotConnectedError(s.error)) {
      return;
    }
    add(const InitializeReactionList());
  }

  Future<void> _onInitialize(
    InitializeReactionList event,
    Emitter<ReactionListState> emit,
  ) async {
    emit(
      ReactionListLoading(
        messageReactions: const {},
        selectedReaction: initialSelectedReaction,
      ),
    );

    final gen = _listGen;
    _createReactionsRequest();
    await _fetchReactionsInternal(ReactionConstants.allReactions, emit);
    // A session end or cache reset cleared the list meanwhile.
    if (gen != _listGen) return;

    if (initialSelectedReaction != ReactionConstants.allReactions) {
      _createReactionsRequest(initialSelectedReaction);
      await _fetchReactionsInternal(initialSelectedReaction, emit);
    }
  }

  Future<void> _onFetchReactions(
    FetchReactions event,
    Emitter<ReactionListState> emit,
  ) async {
    await _fetchReactionsInternal(event.reaction, emit);
  }

  Future<void> _onUpdateSelectedReaction(
    UpdateSelectedReaction event,
    Emitter<ReactionListState> emit,
  ) async {
    if (state is ReactionListLoaded) {
      final currentState = state as ReactionListLoaded;

      if (!_reactionsRequests.containsKey(event.reaction)) {
        _createReactionsRequest(event.reaction);
      }

      emit(currentState.copyWith(selectedReaction: event.reaction));
    }
  }

  Future<void> _onRemoveReaction(
    RemoveOwnReaction event,
    Emitter<ReactionListState> emit,
  ) async {
    if (state is! ReactionListLoaded) return;

    final currentState = state as ReactionListLoaded;
    final updatedReactions = Map<String, List<Reaction>>.from(
      currentState.messageReactions,
    );

    // Optimistically remove from UI
    updatedReactions[event.reaction.reaction!]?.removeWhere(
      (element) =>
          event.reaction.uid == element.uid && event.reaction.id == element.id,
    );

    int newTotal = currentState.totalReactions - 1;
    String newSelectedReaction = currentState.selectedReaction;

    if (updatedReactions[event.reaction.reaction!]?.isEmpty ?? false) {
      updatedReactions.remove(event.reaction.reaction!);
      newSelectedReaction = ReactionConstants.allReactions;
    }

    emit(
      currentState.copyWith(
        messageReactions: updatedReactions,
        totalReactions: newTotal,
        selectedReaction: newSelectedReaction,
      ),
    );

    // Make API call
    unawaited(
      CometChat.removeReaction(
        event.reaction.messageId!,
        event.reaction.reaction!,
        onSuccess: (reactedMessage) {
          if (messageObject != null) {
            CometChatMessageEvents.ccMessageEdited(
              messageObject!..reactions = reactedMessage.reactions,
              MessageEditStatus.success,
            );
          }
        },
        onError: (exception) {
          // Revert on error
          add(ReactionAdded(event.reaction));
        },
      ),
    );
  }

  Future<void> _onReactionAdded(
    ReactionAdded event,
    Emitter<ReactionListState> emit,
  ) async {
    if (state is! ReactionListLoaded) return;

    final currentState = state as ReactionListLoaded;
    final updatedReactions = Map<String, List<Reaction>>.from(
      currentState.messageReactions,
    );
    int newTotal = currentState.totalReactions;

    if (updatedReactions.containsKey(event.reaction.reaction)) {
      final existingIndex = updatedReactions[event.reaction.reaction!]
          ?.indexWhere(
            (element) =>
                element.reaction == event.reaction.reaction &&
                element.reactedBy?.uid == event.reaction.reactedBy?.uid,
          );
      if (existingIndex == -1) {
        updatedReactions[event.reaction.reaction!]?.add(event.reaction);
        newTotal++;
      }
    } else {
      updatedReactions[event.reaction.reaction!] = [event.reaction];
      newTotal++;
    }

    emit(
      currentState.copyWith(
        messageReactions: updatedReactions,
        totalReactions: newTotal,
      ),
    );
  }

  Future<void> _onReactionRemoved(
    ReactionRemoved event,
    Emitter<ReactionListState> emit,
  ) async {
    if (state is! ReactionListLoaded) return;

    final currentState = state as ReactionListLoaded;
    final updatedReactions = Map<String, List<Reaction>>.from(
      currentState.messageReactions,
    );

    updatedReactions[event.reaction.reaction!]?.removeWhere(
      (element) =>
          event.reaction.uid == element.uid && event.reaction.id == element.id,
    );

    int newTotal = currentState.totalReactions - 1;
    String newSelectedReaction = currentState.selectedReaction;

    if (updatedReactions[event.reaction.reaction!]?.isEmpty ?? false) {
      updatedReactions.remove(event.reaction.reaction!);
      newSelectedReaction = ReactionConstants.allReactions;
    }

    emit(
      currentState.copyWith(
        messageReactions: updatedReactions,
        totalReactions: newTotal,
        selectedReaction: newSelectedReaction,
      ),
    );
  }

  void _createReactionsRequest([
    String reaction = ReactionConstants.allReactions,
  ]) {
    ReactionsRequestBuilder? requestBuilder =
        reactionsRequestBuilder ?? ReactionsRequestBuilder();

    requestBuilder.messageId = messageId;
    if (reaction != ReactionConstants.allReactions) {
      requestBuilder.reaction = reaction;
    }
    _reactionsRequests[reaction] = requestBuilder.build();
    _hasMoreReactions[reaction] = true;
  }

  Future<void> _fetchReactionsInternal(
    String reaction,
    Emitter<ReactionListState> emit,
  ) async {
    if (!_reactionsRequests.containsKey(reaction)) return;

    final currentState = state;
    final currentReactions = currentState is ReactionListLoaded
        ? currentState.messageReactions
        : currentState is ReactionListLoading
        ? currentState.messageReactions
        : <String, List<Reaction>>{};
    final currentSelectedReaction = currentState is ReactionListLoaded
        ? currentState.selectedReaction
        : currentState is ReactionListLoading
        ? currentState.selectedReaction
        : initialSelectedReaction;

    final request = _reactionsRequests[reaction];
    if (request == null) return;
    final gen = _listGen;

    if (OfflineGate.isOn()) {
      return _fetchReactionsTwoPhase(
        reaction,
        request,
        currentReactions,
        currentSelectedReaction,
        emit,
        gen: gen,
      );
    }

    final completer = Completer<void>();

    unawaited(
      request.fetchPrevious(
        onSuccess: (messageReactionsList) {
          // A session end or cache reset cleared the list meanwhile.
          if (gen != _listGen) {
            completer.complete();
            return;
          }
          if (messageReactionsList.isEmpty) {
            _hasMoreReactions[reaction] = false;
            // Emit loaded state so UI transitions out of loading
            if (!emit.isDone) {
              emit(
                ReactionListLoaded(
                  messageReactions: currentReactions,
                  selectedReaction: currentSelectedReaction,
                  totalReactions: currentState is ReactionListLoaded
                      ? currentState.totalReactions
                      : 0,
                  canFetchMore: false,
                ),
              );
            }
          } else {
            _hasMoreReactions[reaction] = true;

            final updatedReactions = Map<String, List<Reaction>>.from(
              currentReactions,
            );
            int totalCount = currentState is ReactionListLoaded
                ? currentState.totalReactions
                : 0;

            for (Reaction messageReaction in messageReactionsList) {
              if (updatedReactions.containsKey(messageReaction.reaction)) {
                final existingIndex =
                    updatedReactions[messageReaction.reaction!]?.indexWhere(
                      (element) =>
                          element.reaction == messageReaction.reaction &&
                          element.reactedBy?.uid ==
                              messageReaction.reactedBy?.uid,
                    );
                if (existingIndex == -1) {
                  updatedReactions[messageReaction.reaction!]?.add(
                    messageReaction,
                  );
                  totalCount++;
                }
              } else {
                updatedReactions[messageReaction.reaction!] = [messageReaction];
                totalCount++;
              }
            }

            if (!emit.isDone) {
              emit(
                ReactionListLoaded(
                  messageReactions: updatedReactions,
                  selectedReaction: currentSelectedReaction,
                  totalReactions: totalCount,
                  canFetchMore:
                      _hasMoreReactions[currentSelectedReaction] ?? false,
                ),
              );
            }
          }
          completer.complete();
        },
        onError: (exception) {
          if (!emit.isDone && gen == _listGen) {
            emit(
              ReactionListError(
                error: exception,
                messageReactions: currentReactions,
                selectedReaction: currentSelectedReaction,
              ),
            );
          }
          completer.complete();
        },
      ),
    );

    await completer.future;
  }

  /// Offline on (W7): the cached page at once, then the server page in its
  /// place; a page adds only reactions not already shown. A server error after
  /// rows are shown keeps them and shows no error; an empty cached page never
  /// ends the list, only an empty server page does.
  Future<void> _fetchReactionsTwoPhase(
    String reaction,
    ReactionsRequest request,
    Map<String, List<Reaction>> before,
    String selected,
    Emitter<ReactionListState> emit, {
    required int gen,
  }) async {
    void show(Map<String, List<Reaction>> rows) {
      if (emit.isDone) return;
      emit(
        ReactionListLoaded(
          messageReactions: rows,
          selectedReaction: selected,
          totalReactions: ReactionListOffline.total(rows),
          canFetchMore: _hasMoreReactions[selected] ?? false,
        ),
      );
    }

    var shown = before;
    await for (final result in ReactionListOffline.fetch(request)) {
      if (isClosed || emit.isDone || gen != _listGen) return;
      switch (result) {
        case Cached(:final rows):
          shown = ReactionListOffline.merge(before, rows);
          show(shown);
        case Server(:final rows):
          _hasMoreReactions[reaction] = rows.isNotEmpty;
          show(ReactionListOffline.merge(before, rows));
        case PhaseError(:final error):
          if (shown.isNotEmpty) {
            show(shown);
          } else {
            emit(
              ReactionListError(
                error: error,
                messageReactions: shown,
                selectedReaction: selected,
              ),
            );
          }
      }
    }
  }

  @override
  void onMessageReactionAdded(ReactionEvent reactionEvent) {
    if (reactionEvent.reaction != null) {
      add(ReactionAdded(reactionEvent.reaction!));
    }
  }

  @override
  void onMessageReactionRemoved(ReactionEvent reactionEvent) {
    if (reactionEvent.reaction != null) {
      add(ReactionRemoved(reactionEvent.reaction!));
    }
  }

  @override
  Future<void> close() {
    _offlineResetSub?.cancel();
    CometChatMessageEvents.removeMessagesListener(_eventListenerKey);
    if (_listensForConnect) {
      ChatSdkListeners.removeConnectionListener(_eventListenerKey);
    }
    return super.close();
  }
}

/// A current-gen session end or cache reset from the offline hub (G8).
class _OfflineListReset extends ReactionListEvent {
  const _OfflineListReset(this.event);

  final OfflineHubEvent event;

  @override
  List<Object?> get props => [event];
}

class _ReactionListConnectionListener with ConnectionListener {
  _ReactionListConnectionListener(this._onConnected);

  final void Function() _onConnected;

  @override
  void onConnected() => _onConnected();
}
