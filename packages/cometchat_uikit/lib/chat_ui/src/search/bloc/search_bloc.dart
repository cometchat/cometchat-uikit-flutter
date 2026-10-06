import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// BLoC for managing conversation + message search state.
///
/// Handles debounced text search, filter chip toggling with filter groups,
/// paginated conversation and message results, and request versioning
/// to discard stale responses.
///
/// Uses SDK-level filtering (searchKeyword, unread, attachmentTypes, hasLinks)
/// for server-side performance instead of client-side filtering.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final User? user;
  final Group? group;
  final SearchScope initialScope;
  final ConversationsRequestBuilder? conversationsRequestBuilder;
  final MessagesRequestBuilder? messagesRequestBuilder;

  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  int _conversationRequestVersion = 0;
  int _messageRequestVersion = 0;

  ConversationsRequest? _conversationsRequest;
  MessagesRequest? _messagesRequest;

  bool _isFetchingConversations = false;
  bool _isFetchingMessages = false;

  static const int _defaultLimit = 3;
  static const int _filteredLimit = 30;

  // Filter definitions
  final List<SearchFilter> allFilters;
  static const Set<int> _conversationFilterGroups = {1};
  static const Set<int> _messageFilterGroups = {2, 3, 4};

  static const List<SearchFilter> defaultFilters = [
    SearchFilter(
      label: 'Unread',
      group: 1,
      icon: Icons.mark_email_unread_outlined,
    ),
    SearchFilter(label: 'Groups', group: 1, icon: Icons.people_outline),
    SearchFilter(label: 'Photos', group: 2, icon: Icons.photo_outlined),
    SearchFilter(label: 'Videos', group: 2, icon: Icons.videocam_outlined),
    SearchFilter(label: 'Audio', group: 3, icon: Icons.audiotrack_outlined),
    SearchFilter(
      label: 'Documents',
      group: 3,
      icon: Icons.insert_drive_file_outlined,
    ),
    SearchFilter(label: 'Links', group: 4, icon: Icons.link),
  ];

  SearchBloc({
    this.user,
    this.group,
    this.initialScope = SearchScope.both,
    this.conversationsRequestBuilder,
    this.messagesRequestBuilder,
    List<SearchFilter>? searchFilters,
    List<SearchScope>? searchScopes,
  }) : allFilters = _resolveAllowedFilters(
         searchFilters,
         searchScopes,
         initialScope,
       ),
       super(
         SearchState(
           scope: initialScope,
           showConversations: initialScope != SearchScope.messages,
           showMessages: initialScope != SearchScope.conversations,
           visibleFilters: _resolveAllowedFilters(
             searchFilters,
             searchScopes,
             initialScope,
           ),
         ),
       ) {
    on<SearchTextChanged>(_onSearchTextChanged);
    on<SearchFilterToggled>(_onFilterToggled);
    on<LoadMoreConversationResults>(_onLoadMoreConversations);
    on<LoadMoreMessageResults>(_onLoadMoreMessages);
    on<ClearSearch>(_onClearSearch);
    on<RefreshCurrentSearch>(_onRefreshCurrentSearch);
    on<ConversationsResultReceived>(_onConversationsResult);
    on<ConversationsErrorReceived>(_onConversationsError);
    on<MessagesResultReceived>(_onMessagesResult);
    on<MessagesErrorReceived>(_onMessagesError);
  }

  /// Selects which filter chips to expose based on the scope.
  ///
  /// Mirrors the v5 sample_app `getAllowedLabels()` rule:
  /// - messages-only       → drop conversation-only chips (Unread, Groups)
  /// - conversations-only  → keep only conversation chips (Unread, Groups)
  /// - both / unspecified  → keep all chips
  ///
  /// Caller-provided `searchFilters` take precedence — if the caller supplies
  /// an explicit list, we trust it and don't re-filter.
  static List<SearchFilter> _resolveAllowedFilters(
    List<SearchFilter>? searchFilters,
    List<SearchScope>? searchScopes,
    SearchScope initialScope,
  ) {
    final base = searchFilters ?? defaultFilters;
    if (searchFilters != null) return base;

    // Derive effective scope: explicit searchScopes override initialScope.
    final bool allowConversations;
    final bool allowMessages;
    if (searchScopes != null && searchScopes.isNotEmpty) {
      allowConversations = searchScopes.contains(SearchScope.conversations);
      allowMessages = searchScopes.contains(SearchScope.messages);
    } else {
      allowConversations = initialScope != SearchScope.messages;
      allowMessages = initialScope != SearchScope.conversations;
    }

    return base.where((f) {
      final isConversationChip = _conversationFilterGroups.contains(f.group);
      final isMessageChip = _messageFilterGroups.contains(f.group);
      if (isConversationChip && !allowConversations) return false;
      if (isMessageChip && !allowMessages) return false;
      return true;
    }).toList();
  }

  // ============================================================
  // Event Handlers
  // ============================================================

  void _onSearchTextChanged(
    SearchTextChanged event,
    Emitter<SearchState> emit,
  ) {
    final text = event.text.trim();
    emit(state.copyWith(searchText: text));

    _debounceTimer?.cancel();

    // No text AND no filters → reset to initial
    if (text.isEmpty && state.selectedFilters.isEmpty) {
      _conversationRequestVersion++;
      _messageRequestVersion++;
      emit(
        state.copyWith(
          searchText: '',
          conversationsStatus: SearchStatus.initial,
          conversations: const [],
          hasMoreConversations: false,
          messagesStatus: SearchStatus.initial,
          messages: const [],
          hasMoreMessages: false,
          clearError: true,
        ),
      );
      return;
    }

    // Has text or has filters → trigger search
    _invalidateAndShowLoading(emit);
    _debounceTimer = Timer(_debounceDuration, () {
      _handleSearchAndFilters();
    });
  }

  void _onFilterToggled(SearchFilterToggled event, Emitter<SearchState> emit) {
    final label = event.label;
    final currentSelected = Set<String>.from(state.selectedFilters);
    final tappedFilter = allFilters.firstWhere((f) => f.label == label);
    final tappedGroup = tappedFilter.group;

    if (currentSelected.contains(label)) {
      currentSelected.remove(label);
    } else {
      // Remove filters from other groups — only one group active at a time
      currentSelected.removeWhere((selected) {
        final f = allFilters.firstWhere((f) => f.label == selected);
        return f.group != tappedGroup;
      });
      currentSelected.add(label);
    }

    List<SearchFilter> visible;
    if (currentSelected.isEmpty) {
      visible = allFilters;
    } else {
      // Show only same-group filters, with tapped filter moved to front
      final sameGroup = allFilters
          .where((f) => f.group == tappedGroup)
          .toList();
      final tappedIndex = sameGroup.indexWhere((f) => f.label == label);
      if (tappedIndex > 0) {
        final tapped = sameGroup.removeAt(tappedIndex);
        sameGroup.insert(0, tapped);
      }
      visible = sameGroup;
    }

    bool showConv = state.scope != SearchScope.messages;
    bool showMsg = state.scope != SearchScope.conversations;

    if (currentSelected.isNotEmpty) {
      if (_conversationFilterGroups.contains(tappedGroup)) {
        // Only activate the conversations section if the widget isn't locked
        // to messages-only (e.g., searchIn: [SearchScope.messages]).
        if (state.scope != SearchScope.messages) {
          showConv = true;
          showMsg = false;
        }
      } else if (_messageFilterGroups.contains(tappedGroup)) {
        if (state.scope != SearchScope.conversations) {
          showConv = false;
          showMsg = true;
        }
      }
    } else {
      showConv = state.scope != SearchScope.messages;
      showMsg = state.scope != SearchScope.conversations;
    }

    emit(
      state.copyWith(
        selectedFilters: currentSelected,
        visibleFilters: visible,
        showConversations: showConv,
        showMessages: showMsg,
      ),
    );

    _debounceTimer?.cancel();

    // No filters AND no text → reset to initial
    if (currentSelected.isEmpty && state.searchText.isEmpty) {
      _conversationRequestVersion++;
      _messageRequestVersion++;
      emit(
        state.copyWith(
          conversationsStatus: SearchStatus.initial,
          conversations: const [],
          hasMoreConversations: false,
          messagesStatus: SearchStatus.initial,
          messages: const [],
          hasMoreMessages: false,
          clearError: true,
        ),
      );
      return;
    }

    // Clear stale results and show loading, then search immediately
    _invalidateAndShowLoading(emit);
    _handleSearchAndFilters();
  }

  /// Invalidates in-flight requests and emits loading for active sections.
  void _invalidateAndShowLoading(Emitter<SearchState> emit) {
    _conversationRequestVersion++;
    _messageRequestVersion++;
    _isFetchingConversations = false;
    _isFetchingMessages = false;

    if (state.showConversations) {
      emit(
        state.copyWith(
          conversationsStatus: SearchStatus.loading,
          conversations: const [],
          hasMoreConversations: false,
        ),
      );
    }
    if (state.showMessages) {
      emit(
        state.copyWith(
          messagesStatus: SearchStatus.loading,
          messages: const [],
          hasMoreMessages: false,
        ),
      );
    }
  }

  void _onLoadMoreConversations(
    LoadMoreConversationResults event,
    Emitter<SearchState> emit,
  ) {
    if (_isFetchingConversations || !state.hasMoreConversations) return;
    _fetchConversations(_conversationRequestVersion, append: true);
  }

  void _onLoadMoreMessages(
    LoadMoreMessageResults event,
    Emitter<SearchState> emit,
  ) {
    if (_isFetchingMessages || !state.hasMoreMessages) return;
    _fetchMessages(_messageRequestVersion, append: true);
  }

  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    _debounceTimer?.cancel();
    _conversationRequestVersion++;
    _messageRequestVersion++;
    emit(
      SearchState(
        scope: initialScope,
        showConversations: initialScope != SearchScope.messages,
        showMessages: initialScope != SearchScope.conversations,
        visibleFilters: allFilters,
      ),
    );
  }

  /// Re-trigger the current search with existing text and filters.
  /// Called when returning from a conversation to refresh stale results
  /// (e.g., unread filter should exclude now-read chats).
  void _onRefreshCurrentSearch(
    RefreshCurrentSearch event,
    Emitter<SearchState> emit,
  ) {
    final text = state.searchText;
    final filters = state.selectedFilters;

    // Nothing to refresh if no active search
    if (text.isEmpty && filters.isEmpty) return;

    // Show loading and re-fetch
    _invalidateAndShowLoading(emit);
    _handleSearchAndFilters();
  }

  // ============================================================
  // Internal result event handlers
  // ============================================================

  void _onConversationsResult(
    ConversationsResultReceived event,
    Emitter<SearchState> emit,
  ) {
    final list = event.append
        ? [...state.conversations, ...event.conversations]
        : event.conversations;
    emit(
      state.copyWith(
        conversationsStatus: list.isEmpty
            ? SearchStatus.empty
            : SearchStatus.loaded,
        conversations: list,
        hasMoreConversations: event.hasMore,
      ),
    );
  }

  void _onConversationsError(
    ConversationsErrorReceived event,
    Emitter<SearchState> emit,
  ) {
    emit(
      state.copyWith(
        conversationsStatus: SearchStatus.error,
        errorMessage: event.message,
      ),
    );
  }

  void _onMessagesResult(
    MessagesResultReceived event,
    Emitter<SearchState> emit,
  ) {
    final list = event.append
        ? [...state.messages, ...event.messages]
        : event.messages;
    emit(
      state.copyWith(
        messagesStatus: list.isEmpty ? SearchStatus.empty : SearchStatus.loaded,
        messages: list,
        hasMoreMessages: event.hasMore,
      ),
    );
  }

  void _onMessagesError(
    MessagesErrorReceived event,
    Emitter<SearchState> emit,
  ) {
    emit(
      state.copyWith(
        messagesStatus: SearchStatus.error,
        errorMessage: event.message,
      ),
    );
  }

  // ============================================================
  // Search Execution — unified entry point
  // ============================================================

  /// Central search method called by both text changes and filter toggles.
  /// Determines which sections to search based on current state.
  void _handleSearchAndFilters() {
    final text = state.searchText;
    final filters = state.selectedFilters;

    // Nothing to search
    if (text.isEmpty && filters.isEmpty) return;

    if (state.showConversations) {
      _searchConversations(text, filters);
    }
    if (state.showMessages) {
      _searchMessages(text, filters);
    }
  }

  /// Builds a fresh ConversationsRequest using SDK-level filtering:
  /// - `searchKeyword` for server-side text search
  /// - `unread` flag for unread-only filter
  /// - `conversationType` for groups-only filter
  void _searchConversations(String text, Set<String> filters) {
    _conversationRequestVersion++;
    final version = _conversationRequestVersion;

    // Always create a fresh builder to avoid stale state from previous searches
    final builder = ConversationsRequestBuilder();

    // Copy over any user-provided settings
    if (conversationsRequestBuilder != null) {
      builder.withUserAndGroupTags =
          conversationsRequestBuilder!.withUserAndGroupTags;
      builder.withTags = conversationsRequestBuilder!.withTags;
      builder.tags = conversationsRequestBuilder!.tags;
      builder.includeBlockedUsers =
          conversationsRequestBuilder!.includeBlockedUsers;
      builder.withBlockedInfo = conversationsRequestBuilder!.withBlockedInfo;
      builder.userTags = conversationsRequestBuilder!.userTags;
      builder.groupTags = conversationsRequestBuilder!.groupTags;
    }

    builder.limit = filters.isNotEmpty ? _filteredLimit : _defaultLimit;

    // SDK-level text search
    if (text.isNotEmpty) {
      builder.searchKeyword = text;
    }

    // SDK-level unread filter
    if (filters.contains('Unread')) {
      builder.unread = true;
    }

    // SDK-level group type filter
    if (filters.contains('Groups')) {
      builder.conversationType = ConversationType.group;
    }

    _conversationsRequest = builder.build();
    _isFetchingConversations = false;
    _fetchConversations(version, append: false);
  }

  Future<void> _fetchConversations(int version, {required bool append}) async {
    if (_isFetchingConversations) return;
    _isFetchingConversations = true;

    try {
      final completer = Completer<List<Conversation>>();
      unawaited(
        _conversationsRequest!.fetchNext(
          onSuccess: (List<Conversation> conversations) {
            if (!completer.isCompleted) completer.complete(conversations);
          },
          onError: (CometChatException e) {
            if (!completer.isCompleted) completer.completeError(e);
          },
        ),
      );

      final results = await completer.future;
      if (version != _conversationRequestVersion || isClosed) return;

      final limit = state.selectedFilters.isNotEmpty
          ? _filteredLimit
          : _defaultLimit;
      add(
        ConversationsResultReceived(
          conversations: results,
          hasMore: results.length >= limit,
          append: append,
        ),
      );
    } catch (e) {
      if (version != _conversationRequestVersion || isClosed) return;
      add(ConversationsErrorReceived(e.toString()));
    } finally {
      _isFetchingConversations = false;
    }
  }

  /// Builds a fresh MessagesRequest using SDK-level filtering:
  /// - `searchKeyword` for server-side text search
  /// - `attachmentTypes` for Photos/Videos/Audio/Documents (server-side)
  /// - `hasLinks` flag for links filter (server-side)
  void _searchMessages(String text, Set<String> filters) {
    _messageRequestVersion++;
    final version = _messageRequestVersion;

    // Count how many attachment filters are active
    final attachmentFilterLabels = <String>[];
    if (filters.contains('Photos')) attachmentFilterLabels.add('Photos');
    if (filters.contains('Videos')) attachmentFilterLabels.add('Videos');
    if (filters.contains('Audio')) attachmentFilterLabels.add('Audio');
    if (filters.contains('Documents')) attachmentFilterLabels.add('Documents');

    // Server only supports ONE attachmentType per request.
    // When multiple attachment filters are selected, fire separate requests
    // and merge results client-side.
    if (attachmentFilterLabels.length > 1) {
      _searchMessagesMultiFilter(
        text,
        filters,
        attachmentFilterLabels,
        version,
      );
      return;
    }

    // Single filter or no attachment filters — use normal single request path
    final builder = _buildMessagesRequest(text, filters);

    _messagesRequest = builder.build();
    _isFetchingMessages = false;
    _fetchMessages(version, append: false);
  }

  /// Builds a MessagesRequestBuilder with common settings.
  MessagesRequestBuilder _buildMessagesRequest(
    String text,
    Set<String> filters,
  ) {
    final builder = MessagesRequestBuilder();

    if (messagesRequestBuilder != null) {
      builder.uid = messagesRequestBuilder!.uid;
      builder.guid = messagesRequestBuilder!.guid;
      builder.categories = messagesRequestBuilder!.categories;
      builder.types = messagesRequestBuilder!.types;
    }

    builder.limit = filters.isNotEmpty ? _filteredLimit : _defaultLimit;

    if (text.isNotEmpty) {
      builder.searchKeyword = text;
    }

    if (user != null) {
      builder.uid = user!.uid;
    } else if (group != null) {
      builder.guid = group!.guid;
    }

    if (messagesRequestBuilder == null && filters.isEmpty) {
      // Include the card category/type so card messages are searchable. The
      // categories must be set explicitly — otherwise the SDK defaults to the
      // `message` category and card messages are excluded.
      builder.categories = [
        MessageCategoryConstants.message,
        MessageCategoryConstants.card,
      ];
      builder.types = [
        MessageTypeConstants.text,
        MessageTypeConstants.image,
        MessageTypeConstants.video,
        MessageTypeConstants.audio,
        MessageTypeConstants.file,
        MessageTypeConstants.card,
      ];
    }

    _applyMessageFilters(builder, filters);
    return builder;
  }

  /// Fires separate requests per attachment filter and merges results.
  /// The CometChat server only supports one attachmentType per request.
  void _searchMessagesMultiFilter(
    String text,
    Set<String> allFilters,
    List<String> attachmentFilterLabels,
    int version,
  ) async {
    _isFetchingMessages = true;

    try {
      final allResults = <BaseMessage>[];
      final seenIds = <int>{};

      for (final filterLabel in attachmentFilterLabels) {
        if (version != _messageRequestVersion || isClosed) return;

        // Build a request with just this one attachment filter
        final singleFilter = <String>{filterLabel};
        // Also include Links if it was selected
        if (allFilters.contains('Links')) singleFilter.add('Links');

        final builder = _buildMessagesRequest(text, singleFilter);

        final request = builder.build();
        final completer = Completer<List<BaseMessage>>();
        unawaited(
          request.fetchPrevious(
            onSuccess: (List<BaseMessage> messages) {
              if (!completer.isCompleted) completer.complete(messages);
            },
            onError: (CometChatException e) {
              if (!completer.isCompleted) completer.completeError(e);
            },
          ),
        );

        final results = await completer.future;

        for (final msg in results) {
          if (!seenIds.contains(msg.id)) {
            seenIds.add(msg.id);
            allResults.add(msg);
          }
        }
      }

      if (version != _messageRequestVersion || isClosed) return;

      // Sort merged results by sentAt descending (newest first)
      allResults.sort((a, b) {
        final aTime = a.sentAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.sentAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

      add(
        MessagesResultReceived(
          messages: allResults,
          hasMore: false, // Pagination not supported for merged results
          append: false,
        ),
      );
    } catch (e) {
      if (version != _messageRequestVersion || isClosed) return;
      add(MessagesErrorReceived(e.toString()));
    } finally {
      _isFetchingMessages = false;
    }
  }

  /// Applies SDK-native filter properties based on selected filter chips.
  /// Uses `attachmentTypes` for media filters and `hasLinks` for link filter.
  void _applyMessageFilters(
    MessagesRequestBuilder builder,
    Set<String> filters,
  ) {
    if (filters.isEmpty) return;

    final attachmentTypes = <String>[];
    if (filters.contains('Photos')) {
      attachmentTypes.add(AttachmentType.IMAGE.value);
    }
    if (filters.contains('Videos')) {
      attachmentTypes.add(AttachmentType.VIDEO.value);
    }
    if (filters.contains('Audio')) {
      attachmentTypes.add(AttachmentType.AUDIO.value);
    }
    if (filters.contains('Documents')) {
      attachmentTypes.add(AttachmentType.FILE.value);
    }
    if (attachmentTypes.isNotEmpty) {
      builder.attachmentTypes = attachmentTypes;
    }

    if (filters.contains('Links')) {
      builder.hasLinks = true;
    }
  }

  Future<void> _fetchMessages(int version, {required bool append}) async {
    if (_isFetchingMessages) return;
    _isFetchingMessages = true;

    try {
      final completer = Completer<List<BaseMessage>>();
      unawaited(
        _messagesRequest!.fetchPrevious(
          onSuccess: (List<BaseMessage> messages) {
            if (!completer.isCompleted) completer.complete(messages);
          },
          onError: (CometChatException e) {
            if (!completer.isCompleted) completer.completeError(e);
          },
        ),
      );

      final results = await completer.future;
      if (version != _messageRequestVersion || isClosed) return;

      final reversed = results.reversed.toList();
      final limit = state.selectedFilters.isNotEmpty
          ? _filteredLimit
          : _defaultLimit;
      add(
        MessagesResultReceived(
          messages: reversed,
          hasMore: results.length >= limit,
          append: append,
        ),
      );
    } catch (e) {
      if (version != _messageRequestVersion || isClosed) return;
      add(MessagesErrorReceived(e.toString()));
    } finally {
      _isFetchingMessages = false;
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
