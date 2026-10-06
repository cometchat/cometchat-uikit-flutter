import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import '../conversations/utils/conversation_subtitle_utils.dart';
import '../../../shared_ui/src/clean_architecture/presentation/views/misc/message_preview_subtitle.dart';

/// Full-screen search widget for conversations and messages.
///
/// Supports text search with debounce, filter chips, dual-section results
/// (Conversations + Messages), "See More" pagination, and custom view slots.
class CometChatSearch extends StatefulWidget {
  const CometChatSearch({
    super.key,
    this.onBack,
    this.onConversationClicked,
    this.onMessageClicked,
    this.onEmpty,
    this.onError,
    this.onMessagesLoad,
    this.onConversationsLoad,
    this.searchFilters,
    this.searchIn,
    this.user,
    this.group,
    this.searchStyle,
    this.searchBackIcon,
    this.searchClearIcon,
    this.loadingStateView,
    this.emptyStateView,
    this.errorStateView,
    this.initialStateView,
    this.conversationItemView,
    this.conversationTitleView,
    this.conversationLeadingView,
    this.conversationSubtitleView,
    this.conversationTailView,
    this.usersStatusVisibility,
    this.receiptsVisibility,
    this.groupTypeVisibility,
    this.dateSeparatorFormatterCallback,
    this.timeSeparatorFormatterCallback,
    this.searchTextMessageView,
    this.searchImageMessageView,
    this.searchVideoMessageView,
    this.searchFileMessageView,
    this.searchAudioMessageView,
    this.conversationsRequestBuilder,
    this.messagesRequestBuilder,
    this.searchBloc,
  });

  final VoidCallback? onBack;
  final Function(Conversation conversation)? onConversationClicked;
  final Function(BaseMessage message)? onMessageClicked;
  final OnError? onError;
  final OnLoad<Conversation>? onConversationsLoad;
  final OnLoad<BaseMessage>? onMessagesLoad;
  final OnEmpty? onEmpty;
  final List<SearchFilter>? searchFilters;
  final List<SearchScope>? searchIn;
  final User? user;
  final Group? group;
  final CometChatSearchStyle? searchStyle;
  final Widget? searchBackIcon;
  final Widget? searchClearIcon;
  final WidgetBuilder? loadingStateView;
  final WidgetBuilder? emptyStateView;
  final WidgetBuilder? errorStateView;
  final WidgetBuilder? initialStateView;
  final Widget? Function(BuildContext, Conversation)? conversationItemView;
  final Widget? Function(BuildContext, Conversation)? conversationTitleView;
  final Widget? Function(BuildContext, Conversation)? conversationLeadingView;
  final Widget? Function(BuildContext, Conversation)? conversationSubtitleView;
  final Widget? Function(BuildContext, Conversation)? conversationTailView;
  final bool? usersStatusVisibility;
  final bool? receiptsVisibility;

  /// [searchBloc] injects the bloc instead of letting the component build
  /// one.
  ///
  /// Mirrors `CometChatUsers.usersBloc`, `CometChatGroups.groupsBloc` and
  /// `CometChatConversations.conversationsBloc`. Search was the only one of
  /// the four without the seam, and because every builder here passes
  /// `bloc: _searchBloc` explicitly, an ambient BlocProvider could not stand
  /// in for it either — which left most of this component's props impossible
  /// to render-verify. ENG-39114.
  ///
  /// An injected bloc is owned by the caller and is not closed on dispose.
  final SearchBloc? searchBloc;
  final bool? groupTypeVisibility;

  /// Labels the month separators in the message results, which default to
  /// "September, 2026". Only `otherDays` is used: it gets the send time of
  /// the first message under the separator, and null keeps the default.
  final DateTimeFormatterCallback? dateSeparatorFormatterCallback;
  final DateTimeFormatterCallback? timeSeparatorFormatterCallback;
  final Widget? Function(BuildContext, TextMessage)? searchTextMessageView;
  final Widget? Function(BuildContext, MediaMessage)? searchImageMessageView;
  final Widget? Function(BuildContext, MediaMessage)? searchVideoMessageView;
  final Widget? Function(BuildContext, MediaMessage)? searchFileMessageView;
  final Widget? Function(BuildContext, MediaMessage)? searchAudioMessageView;
  final ConversationsRequestBuilder? conversationsRequestBuilder;
  final MessagesRequestBuilder? messagesRequestBuilder;

  @override
  State<CometChatSearch> createState() => _CometChatSearchState();
}

class _CometChatSearchState extends State<CometChatSearch> {
  late final SearchBloc _searchBloc;
  bool _isExternalBloc = false;
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  // Theme caching
  late CometChatColorPalette colorPalette;
  late CometChatSpacing spacing;
  late CometChatTypography typography;
  late CometChatSearchStyle style;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;

  @override
  void initState() {
    super.initState();
    // Derive initial scope from searchIn (matches v5 sample_app behavior):
    //   [messages]       → SearchScope.messages
    //   [conversations]  → SearchScope.conversations
    //   both / null      → SearchScope.both
    SearchScope derivedScope;
    final scopes = widget.searchIn;
    if (scopes == null || scopes.isEmpty || scopes.length >= 2) {
      derivedScope = SearchScope.both;
    } else if (scopes.first == SearchScope.messages) {
      derivedScope = SearchScope.messages;
    } else {
      derivedScope = SearchScope.conversations;
    }
    if (widget.searchBloc != null) {
      _searchBloc = widget.searchBloc!;
      _isExternalBloc = true;
    } else {
      _searchBloc = SearchBloc(
        user: widget.user,
        group: widget.group,
        initialScope: derivedScope,
        conversationsRequestBuilder: widget.conversationsRequestBuilder,
        messagesRequestBuilder: widget.messagesRequestBuilder,
        searchFilters: widget.searchFilters,
        searchScopes: widget.searchIn,
      );
      _isExternalBloc = false;
    }
    _textController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (!_themeInitialized || brightnessChanged) {
      _cachedBrightness = currentBrightness;
      colorPalette = CometChatThemeHelper.getColorPalette(context);
      spacing = CometChatThemeHelper.getSpacing(context);
      typography = CometChatThemeHelper.getTypography(context);
      style = CometChatThemeHelper.getTheme<CometChatSearchStyle>(
        context: context,
        defaultTheme: CometChatSearchStyle.of,
      ).merge(widget.searchStyle);
      _themeInitialized = true;
    }
  }

  @override
  void dispose() {
    if (!_isExternalBloc) {
      _searchBloc.close();
    }
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Reports search state transitions to the caller's callbacks, once per
  /// entry into each status. ENG-39104: all four callbacks were declared,
  /// documented, and read nowhere under `lib/chat_ui/src/search/`.
  ///
  /// Search differs from the Users and Groups lists in carrying two
  /// independent result sets in one state, so each is tracked separately —
  /// messages arriving must not re-report conversations. `onEmpty` fires only
  /// when every list in scope has settled empty, which is the condition an
  /// integrator would show a "nothing found" affordance for.
  SearchStatus? _lastConversationsStatus;
  SearchStatus? _lastMessagesStatus;
  bool _reportedEmpty = false;
  bool _reportedError = false;

  void _reportSearchState(SearchState state) {
    final conversationsChanged =
        state.conversationsStatus != _lastConversationsStatus;
    final messagesChanged = state.messagesStatus != _lastMessagesStatus;
    _lastConversationsStatus = state.conversationsStatus;
    _lastMessagesStatus = state.messagesStatus;

    if (state.conversationsStatus == SearchStatus.error ||
        state.messagesStatus == SearchStatus.error) {
      if (!_reportedError) {
        _reportedError = true;
        widget.onError?.call(Exception(state.errorMessage ?? 'Search failed'));
      }
      return;
    }
    _reportedError = false;

    if (conversationsChanged &&
        state.conversationsStatus == SearchStatus.loaded &&
        state.conversations.isNotEmpty) {
      widget.onConversationsLoad?.call(state.conversations);
    }
    if (messagesChanged &&
        state.messagesStatus == SearchStatus.loaded &&
        state.messages.isNotEmpty) {
      widget.onMessagesLoad?.call(state.messages);
    }

    // Only the lists the current scope actually shows count toward empty.
    final conversationsSettledEmpty =
        !state.showConversations ||
        state.conversationsStatus == SearchStatus.empty;
    final messagesSettledEmpty =
        !state.showMessages || state.messagesStatus == SearchStatus.empty;

    if (conversationsSettledEmpty && messagesSettledEmpty) {
      if (!_reportedEmpty) {
        _reportedEmpty = true;
        widget.onEmpty?.call();
      }
    } else {
      _reportedEmpty = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SearchBloc, SearchState>(
      bloc: _searchBloc,
      listener: (context, state) => _reportSearchState(state),
      child: BlocProvider.value(
        value: _searchBloc,
        child: Scaffold(
          backgroundColor: style.backgroundColor ?? colorPalette.background1,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: spacing.padding3 ?? 0,
                horizontal: spacing.padding4 ?? 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  _buildFilterChips(),
                  Expanded(child: _buildResults()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Search Bar
  // ===========================================================================

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.padding3 ?? 0),
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        keyboardAppearance:
            CometChatThemeHelper.getBrightness(context) == Brightness.dark
            ? Brightness.dark
            : Brightness.light,
        onChanged: (val) => _searchBloc.add(SearchTextChanged(val)),
        style: TextStyle(
          color: style.searchTextColor ?? colorPalette.textPrimary,
          fontSize: typography.heading4?.regular?.fontSize,
          fontWeight: typography.heading4?.regular?.fontWeight,
          fontFamily: typography.heading4?.regular?.fontFamily,
        ).merge(style.searchTextStyle).copyWith(color: style.searchTextColor),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: spacing.padding3 ?? 0,
            vertical: spacing.padding2 ?? 0,
          ),
          hintText: (widget.user != null || widget.group != null)
              ? "${cc.Translations.of(context).search} in ${widget.user?.name ?? widget.group?.name ?? ""}"
              : cc.Translations.of(context).search,
          prefixIcon: Semantics(
            button: true,
            label: cc.Translations.of(context).back,
            child: GestureDetector(
              onTap: widget.onBack ?? () => Navigator.of(context).pop(),
              child:
                  widget.searchBackIcon ??
                  Icon(
                    Icons.arrow_back,
                    color:
                        style.searchBackIconColor ?? colorPalette.iconSecondary,
                    size: 24,
                  ),
            ),
          ),
          suffixIcon: BlocBuilder<SearchBloc, SearchState>(
            bloc: _searchBloc,
            buildWhen: (p, c) => p.searchText.isEmpty != c.searchText.isEmpty,
            builder: (context, state) {
              if (state.searchText.isEmpty) {
                return const SizedBox(width: 24);
              }
              return Semantics(
                button: true,
                label: cc.Translations.of(context).clearSearch,
                child: GestureDetector(
                  onTap: () {
                    _textController.clear();
                    _searchBloc.add(const SearchTextChanged(''));
                  },
                  child:
                      widget.searchClearIcon ??
                      Icon(
                        Icons.close,
                        color:
                            style.searchClearIconColor ??
                            colorPalette.iconSecondary,
                        size: 24,
                      ),
                ),
              );
            },
          ),
          hintStyle:
              TextStyle(
                    color:
                        style.searchPlaceHolderTextColor ??
                        colorPalette.textTertiary,
                    fontSize: typography.heading4?.regular?.fontSize,
                    fontWeight: typography.heading4?.regular?.fontWeight,
                    fontFamily: typography.heading4?.regular?.fontFamily,
                  )
                  .merge(style.searchPlaceHolderTextStyle)
                  .copyWith(color: style.searchPlaceHolderTextColor),
          focusedBorder: _searchBorder(),
          enabledBorder: _searchBorder(),
          border: _searchBorder(),
          fillColor: style.searchBackgroundColor ?? colorPalette.background3,
          filled: true,
        ),
      ),
    );
  }

  OutlineInputBorder _searchBorder() {
    return OutlineInputBorder(
      borderSide:
          style.searchBorder ??
          BorderSide(
            color: colorPalette.borderDark ?? Colors.transparent,
            width: 1,
          ),
      borderRadius:
          style.searchBorderRadius ??
          BorderRadius.circular(spacing.radiusMax ?? 0),
    );
  }

  // ===========================================================================
  // Filter Chips
  // ===========================================================================

  Widget _buildFilterChips() {
    return BlocBuilder<SearchBloc, SearchState>(
      bloc: _searchBloc,
      buildWhen: (p, c) =>
          p.visibleFilters != c.visibleFilters ||
          p.selectedFilters != c.selectedFilters,
      builder: (context, state) {
        if (state.visibleFilters.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.padding3 ?? 0),
          child: Wrap(
            spacing: spacing.padding2 ?? 0,
            runSpacing: spacing.padding2 ?? 0,
            children: state.visibleFilters.map((filter) {
              final isSelected = state.selectedFilters.contains(filter.label);
              return SearchFilterChip(
                label: filter.label,
                icon: filter.icon,
                isSelected: isSelected,
                onTap: () => _searchBloc.add(SearchFilterToggled(filter.label)),
                colorPalette: colorPalette,
                spacing: spacing,
                typography: typography,
                selectedColor: style.searchFilterChipSelectedBackgroundColor,
                unselectedColor: style.searchFilterChipBackgroundColor,
                selectedTextColor: style.searchFilterChipSelectedTextColor,
                unselectedTextColor: style.searchFilterChipTextColor,
                selectedBorder: style.searchFilterChipSelectedBorder,
                unSelectedBorder: style.searchFilterChipBorder,
                borderRadius: style.searchFilterChipBorderRadius,
                selectedTextStyle: style.searchFilterChipSelectedTextStyle,
                textStyle: style.searchFilterChipTextStyle,
                selectedIconColor: style.searchFilterSelectedIconColor,
                unselectedIconColor: style.searchFilterIconColor,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Results Area
  // ===========================================================================

  Widget _buildResults() {
    return BlocBuilder<SearchBloc, SearchState>(
      bloc: _searchBloc,
      builder: (context, state) {
        if (state.isInitial) {
          return widget.initialStateView?.call(context) ??
              const SizedBox.shrink();
        }

        if (state.bothActive && state.allLoading) {
          return widget.loadingStateView?.call(context) ?? _buildLoadingView();
        }

        if (state.bothActive && state.allEmpty) {
          return widget.emptyStateView?.call(context) ?? _buildEmptyView(state);
        }

        if (state.bothActive && state.allError) {
          return widget.errorStateView?.call(context) ?? _buildErrorView();
        }

        if (state.shouldShowNoResults()) {
          return widget.emptyStateView?.call(context) ?? _buildEmptyView(state);
        }

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (state.showConversations) ..._buildConversationsSlivers(state),
            if (state.showMessages) ..._buildMessagesSlivers(state),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // Conversations Section (Sliver-based for lazy rendering)
  // ===========================================================================

  List<Widget> _buildConversationsSlivers(SearchState state) {
    if (!state.bothActive &&
        state.conversationsStatus == SearchStatus.loading) {
      return [
        SliverFillRemaining(
          child: widget.loadingStateView?.call(context) ?? _buildLoadingView(),
        ),
      ];
    }

    if (!state.bothActive &&
        state.conversationsStatus != SearchStatus.loading &&
        state.conversations.isEmpty) {
      return [
        SliverFillRemaining(
          child: widget.emptyStateView?.call(context) ?? _buildEmptyView(state),
        ),
      ];
    }

    if (!state.bothActive && state.conversationsStatus == SearchStatus.error) {
      return [
        SliverFillRemaining(
          child: widget.errorStateView?.call(context) ?? _buildErrorView(),
        ),
      ];
    }

    if (state.conversations.isEmpty) return [];

    final itemCount = state.selectedFilters.isNotEmpty
        ? (state.hasMoreConversations
              ? state.conversations.length + 1
              : state.conversations.length)
        : state.conversations.length;

    return [
      SliverToBoxAdapter(
        child: _sectionHeader(cc.Translations.of(context).chats),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (state.selectedFilters.isNotEmpty &&
              index >= state.conversations.length) {
            _searchBloc.add(const LoadMoreConversationResults());
            return _buildSectionLoading();
          }
          return _buildConversationItem(state.conversations[index]);
        }, childCount: itemCount),
      ),
      if (state.selectedFilters.isEmpty &&
          state.conversations.isNotEmpty &&
          state.conversations.length >= 3 &&
          state.hasMoreConversations)
        SliverToBoxAdapter(
          child: _seeMoreButton(
            onTap: () => _searchBloc.add(const LoadMoreConversationResults()),
          ),
        ),
    ];
  }

  /// The tap behaviour every conversation row shares: report to the caller,
  /// then re-run the search once navigation has settled so results that are no
  /// longer matching (a now-read chat under the unread filter) drop out.
  Future<void> _handleConversationTap(Conversation conversation) async {
    widget.onConversationClicked?.call(conversation);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && !_searchBloc.isClosed) {
      _searchBloc.add(const RefreshCurrentSearch());
    }
  }

  Widget _buildConversationItem(Conversation conversation) {
    if (widget.conversationItemView != null) {
      final customView = widget.conversationItemView!(context, conversation);
      if (customView == null) return const SizedBox.shrink();
      // Wrapped rather than returned bare: the early return used to skip the
      // GestureDetector below, so supplying a custom row silently disabled
      // onConversationClicked. _buildMessageItem already wraps its own custom
      // view the same way, which is the precedent followed here.
      return GestureDetector(
        onTap: () => _handleConversationTap(conversation),
        child: customView,
      );
    }

    User? conversationWithUser;
    Group? conversationWithGroup;
    if (conversation.conversationWith is User) {
      conversationWithUser = conversation.conversationWith as User;
    } else {
      conversationWithGroup = conversation.conversationWith as Group;
    }

    final statusIndicatorUtils =
        StatusIndicatorUtils.getStatusIndicatorFromParams(
          context: context,
          isSelected: false,
          user: conversationWithUser,
          group: conversationWithGroup,
          onlineStatusIndicatorColor:
              style.statusIndicatorStyle?.backgroundColor ??
              colorPalette.success,
          privateGroupIcon: null,
          protectedGroupIcon: null,
          privateGroupIconBackground: null,
          protectedGroupIconBackground: null,
          usersStatusVisibility: widget.usersStatusVisibility ?? true,
          groupTypeVisibility: widget.groupTypeVisibility ?? true,
        );

    // Subtitle
    Widget? subtitle;
    if (widget.conversationSubtitleView != null) {
      subtitle = widget.conversationSubtitleView!(context, conversation);
    } else {
      subtitle = _getConversationSubtitle(conversation);
    }

    // Tail
    Widget? tail;
    if (widget.conversationTailView != null) {
      tail = widget.conversationTailView!(context, conversation);
    } else {
      tail = _getConversationTail(conversation);
    }

    return GestureDetector(
      onTap: () => _handleConversationTap(conversation),
      child: CometChatListItem(
        avatarHeight: 48,
        avatarWidth: 48,
        id: conversation.conversationId,
        avatarName: conversationWithUser?.name ?? conversationWithGroup?.name,
        avatarURL: conversationWithUser?.avatar ?? conversationWithGroup?.icon,
        title: conversationWithUser?.name ?? conversationWithGroup?.name,
        key: UniqueKey(),
        avatarStyle: style.avatarStyle ?? const CometChatAvatarStyle(),
        statusIndicatorColor: statusIndicatorUtils.statusIndicatorColor,
        statusIndicatorIcon: statusIndicatorUtils.icon,
        // The caller's statusIndicatorStyle is merged over the inline default
        // rather than ignored — it was declared and never read. ENG-39121.
        statusIndicatorStyle: CometChatStatusIndicatorStyle(
          border: Border.all(
            width: spacing.spacing ?? 0,
            color: colorPalette.background1 ?? Colors.transparent,
          ),
          backgroundColor: colorPalette.success,
        ).merge(style.statusIndicatorStyle),
        hideSeparator: true,
        contentPadding: EdgeInsets.zero,
        style: ListItemStyle(
          background:
              style.searchConversationItemBackgroundColor ??
              colorPalette.transparent,
          titleStyle:
              TextStyle(
                    overflow: TextOverflow.ellipsis,
                    fontSize: typography.heading4?.medium?.fontSize,
                    fontWeight: typography.heading4?.medium?.fontWeight,
                    fontFamily: typography.heading4?.medium?.fontFamily,
                    color:
                        style.searchConversationTitleTextColor ??
                        colorPalette.textPrimary,
                  )
                  .merge(style.searchConversationTitleTextStyle)
                  .copyWith(color: style.searchConversationTitleTextColor),
          padding: EdgeInsets.symmetric(vertical: spacing.padding3 ?? 0),
        ),
        subtitleView: subtitle,
        tailView: tail,
        leadingStateView: widget.conversationLeadingView != null
            ? widget.conversationLeadingView!(context, conversation)
            : null,
        titleView: widget.conversationTitleView != null
            ? widget.conversationTitleView!(context, conversation)
            : null,
      ),
    );
  }

  Widget _getConversationSubtitle(Conversation conversation) {
    final lastMessage = conversation.lastMessage;
    if (lastMessage == null) return const SizedBox.shrink();

    final subtitleStyle =
        TextStyle(
              overflow: TextOverflow.ellipsis,
              color:
                  style.searchConversationSubtitleTextColor ??
                  colorPalette.textSecondary,
              fontSize: typography.body?.regular?.fontSize,
              fontWeight: typography.body?.regular?.fontWeight,
              fontFamily: typography.body?.regular?.fontFamily,
            )
            .merge(style.searchConversationSubtitleTextStyle)
            .copyWith(color: style.searchConversationSubtitleTextColor);

    final body = ConversationSubtitleUtils.getConversationSubtitle(
      conversation,
      context,
      subtitleStyle,
      colorPalette.iconSecondary ?? Colors.grey,
    );

    final receipt = _buildConversationReceipt(conversation);
    if (receipt == null) return body;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        receipt,
        SizedBox(width: spacing.padding1 ?? 4),
        Expanded(child: body),
      ],
    );
  }

  /// The delivery receipt for a conversation row, or null when there is
  /// nothing to show.
  ///
  /// ENG-39113: `receiptsVisibility` was declared and read nowhere, because
  /// Search rendered no receipt at all. The gating mirrors
  /// `CometChatConversationListItem._shouldShowReceipt` so the two surfaces
  /// agree — a receipt belongs to an *outgoing* message, so it appears only
  /// when the last message was sent by the logged-in user.
  Widget? _buildConversationReceipt(Conversation conversation) {
    if (widget.receiptsVisibility == false) return null;

    final lastMessage = conversation.lastMessage;
    if (lastMessage == null) return null;
    if (lastMessage.deletedAt != null) return null;
    if (lastMessage.sender?.uid != CometChatUIKit.loggedInUser?.uid) {
      return null;
    }

    return CometChatReceipt(
      status: _receiptStatusOf(lastMessage),
      style: style.receiptStyle,
    );
  }

  /// Same ladder as `CometChatConversationListItem._getReceiptStatus`, mapped
  /// onto the shared `ReceiptStatus` enum rather than its private strings.
  ReceiptStatus _receiptStatusOf(BaseMessage message) {
    if (message.readAt != null && message.readAt!.millisecondsSinceEpoch > 0) {
      return ReceiptStatus.read;
    }
    if (message.deliveredAt != null &&
        message.deliveredAt!.millisecondsSinceEpoch > 0) {
      return ReceiptStatus.delivered;
    }
    if (message.sentAt != null && message.sentAt!.millisecondsSinceEpoch > 0) {
      return ReceiptStatus.sent;
    }
    return ReceiptStatus.waiting;
  }

  Widget _getConversationTail(Conversation conversation) {
    final lastMessage = conversation.lastMessage;
    final lastMessageTime = lastMessage?.updatedAt ?? lastMessage?.sentAt;
    final unreadCount = conversation.unreadMessageCount;

    return Padding(
      padding: EdgeInsets.only(left: spacing.padding2 ?? 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lastMessageTime != null)
            Flexible(
              child: CometChatDate(
                date: lastMessageTime,
                padding: const EdgeInsets.all(0),
                isTransparentBackground: true,
                style: _rowDateStyle(colorPalette.textSecondary),
                pattern: DateTimePattern.dayDateTimeFormat,
                dateTimeFormatterCallback:
                    widget.timeSeparatorFormatterCallback,
              ),
            ),
          const SizedBox(height: 6.5),
          if (unreadCount > 0)
            Flexible(
              child: CometChatBadge(
                count: unreadCount,
                height: 20,
                style: style.badgeStyle ?? const CometChatBadgeStyle(),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Messages Section (Sliver-based for lazy rendering)
  // ===========================================================================

  List<Widget> _buildMessagesSlivers(SearchState state) {
    if (!state.bothActive && state.messagesStatus == SearchStatus.loading) {
      return [
        SliverFillRemaining(
          child: widget.loadingStateView?.call(context) ?? _buildLoadingView(),
        ),
      ];
    }

    if (!state.bothActive &&
        state.messagesStatus != SearchStatus.loading &&
        state.messages.isEmpty) {
      return [
        SliverFillRemaining(
          child: widget.emptyStateView?.call(context) ?? _buildEmptyView(state),
        ),
      ];
    }

    if (!state.bothActive && state.messagesStatus == SearchStatus.error) {
      return [
        SliverFillRemaining(
          child: widget.errorStateView?.call(context) ?? _buildErrorView(),
        ),
      ];
    }

    if (state.messages.isEmpty) return [];

    final itemCount = state.selectedFilters.isNotEmpty
        ? (state.hasMoreMessages
              ? state.messages.length + 1
              : state.messages.length)
        : state.messages.length;

    return [
      SliverToBoxAdapter(
        child: _sectionHeader(cc.Translations.of(context).message),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (state.selectedFilters.isNotEmpty &&
              index >= state.messages.length) {
            _searchBloc.add(const LoadMoreMessageResults());
            return _buildSectionLoading();
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _getDateSeparator(index, state.messages),
              _buildMessageItem(state.messages[index], index, state),
            ],
          );
        }, childCount: itemCount),
      ),
      if (state.selectedFilters.isEmpty &&
          state.messages.isNotEmpty &&
          state.messages.length >= 3 &&
          state.hasMoreMessages)
        SliverToBoxAdapter(
          child: _seeMoreButton(
            onTap: () => _searchBloc.add(const LoadMoreMessageResults()),
          ),
        ),
    ];
  }

  Widget _buildMessageItem(BaseMessage message, int index, SearchState state) {
    if (message.deletedAt != null) return const SizedBox.shrink();

    // Check custom view slots by message type
    Widget? customView;
    if (message is TextMessage && widget.searchTextMessageView != null) {
      customView = widget.searchTextMessageView!(context, message);
    } else if (message is MediaMessage) {
      final type = message.type;
      if (type == MessageTypeConstants.image &&
          widget.searchImageMessageView != null) {
        customView = widget.searchImageMessageView!(context, message);
      } else if (type == MessageTypeConstants.video &&
          widget.searchVideoMessageView != null) {
        customView = widget.searchVideoMessageView!(context, message);
      } else if (type == MessageTypeConstants.file &&
          widget.searchFileMessageView != null) {
        customView = widget.searchFileMessageView!(context, message);
      } else if (type == MessageTypeConstants.audio &&
          widget.searchAudioMessageView != null) {
        customView = widget.searchAudioMessageView!(context, message);
      }
    }

    if (customView != null) {
      return GestureDetector(
        onTap: () => widget.onMessageClicked?.call(message),
        child: customView,
      );
    }

    // Route to type-specific layout matching legacy buildMessageTypeBubble
    return _buildMessageTypeBubble(message);
  }

  /// Routes each message to the correct visual layout based on message.type.
  /// Matches the legacy SearchUtils.buildMessageTypeBubble pattern.
  Widget _buildMessageTypeBubble(BaseMessage message) {
    final conversationTitle = _getConversationTitle(message);

    switch (message.type) {
      case MessageTypeConstants.text:
        final textMessage = message as TextMessage;
        // Resolve mention tags (<@uid:..>) to display names instead of showing
        // the raw id — matching the conversation-list subtitle behaviour.
        String textSubtitle = textMessage.text;
        if (textMessage.mentionedUsers.isNotEmpty) {
          textSubtitle = CometChatMentionsFormatter.getTextWithMentions(
            textSubtitle,
            textMessage.mentionedUsers,
          );
        }
        return _buildSearchItem(
          message: message,
          title: conversationTitle,
          subtitle: textSubtitle,
          richTextMessage: textMessage,
          trailing: _buildMessageDate(message),
        );

      case MessageTypeConstants.image:
        final mediaMsg = message as MediaMessage;
        return _buildSearchItem(
          message: message,
          title: conversationTitle,
          subtitlePrefix: _senderPrefix(message),
          subtitleIcon: Icons.image_outlined,
          subtitle: AttachmentUtils.previewSubtitleFor(mediaMsg, context),
          trailing: _mediaThumb(mediaMsg, isVideo: false),
        );

      case MessageTypeConstants.video:
        final mediaMsg = message as MediaMessage;
        return _buildSearchItem(
          message: message,
          title: conversationTitle,
          subtitlePrefix: _senderPrefix(message),
          subtitleIcon: Icons.videocam_outlined,
          subtitle: AttachmentUtils.previewSubtitleFor(mediaMsg, context),
          trailing: _mediaThumb(mediaMsg, isVideo: true),
        );

      case MessageTypeConstants.file:
        final mediaMsg = message as MediaMessage;
        return _buildSearchItem(
          message: message,
          title: conversationTitle,
          subtitlePrefix: _senderPrefix(message),
          subtitleIcon: Icons.description_outlined,
          subtitle: AttachmentUtils.previewSubtitleFor(mediaMsg, context),
          // The dedicated "document in search" icon (flattened so flutter_svg
          // renders it — the original nested-<svg>/<text> version came out
          // blank).
          leading: SvgPicture.asset(
            kAttachmentDocumentSearchIconAsset,
            width: 32,
            height: 32,
            package: kAttachmentIconPackage,
          ),
          trailing: _buildMessageDate(message),
        );

      case MessageTypeConstants.audio:
        final mediaMsg = message as MediaMessage;
        return _buildSearchItem(
          message: message,
          title: conversationTitle,
          subtitlePrefix: _senderPrefix(message),
          subtitleIcon: Icons.audiotrack_outlined,
          subtitle: AttachmentUtils.previewSubtitleFor(mediaMsg, context),
          leading: Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: colorPalette.buttonBackground,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.play_arrow,
                color: colorPalette.buttonIconColor,
                size: 20,
              ),
            ),
          ),
          trailing: _buildMessageDate(message),
        );

      case MessageTypeConstants.card:
        final cardMsg = message as CardMessage?;
        final cardText = cardMsg?.getText();
        return _buildSearchItem(
          message: message,
          title: conversationTitle,
          subtitle: cardText?.isNotEmpty == true
              ? cardText!
              : cc.Translations.of(context).cardMessage,
          trailing: _buildMessageDate(message),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// Returns the name of the **conversation** the [message] belongs to —
  /// used as the search row title.
  ///
  /// Rules:
  /// - Group message → the group name (from `message.receiver` as [Group]).
  /// - 1:1 message →
  ///   - If the logged-in user sent it, show the recipient (`message.receiver` as [User]).
  ///   - Otherwise, show the sender (the other person who messaged us).
  ///
  /// Falls back gracefully when the expected objects aren't populated:
  /// we use `receiverUid` / sender uid so the row never renders with a
  /// blank title.
  String _getConversationTitle(BaseMessage message) {
    if (message.receiverType == ReceiverTypeConstants.group) {
      final group = message.receiver;
      if (group is Group && group.name.isNotEmpty) {
        return group.name;
      }
      return message.receiverUid;
    }

    // 1:1 conversation — show the "other" party, not whichever side sent it.
    final loggedInUid = CometChatUIKit.loggedInUser?.uid;
    final senderUid = message.sender?.uid;
    final sentByMe = loggedInUid != null && senderUid == loggedInUid;

    if (sentByMe) {
      final receiver = message.receiver;
      if (receiver is User && receiver.name.isNotEmpty) {
        return receiver.name;
      }
      return message.receiverUid;
    }

    return message.sender?.name ?? message.sender?.uid ?? '';
  }

  /// "You:" for own messages, otherwise the sender's first name — the prefix
  /// before a media row's subtitle (reference design).
  String _senderPrefix(BaseMessage message) {
    final sender = message.sender;
    if (sender == null) return '';
    final loggedInUid = CometChatUIKit.loggedInUser?.uid;
    if (loggedInUid != null && sender.uid == loggedInUid) {
      return '${cc.Translations.of(context).you}:';
    }
    final name = sender.name.trim();
    if (name.isEmpty) return '';
    return '${name.split(' ').first}:';
  }

  /// Trailing thumbnail for an image/video search row — the message's first
  /// attachment as a landscape rounded thumb, with a "+N" scrim overlay when
  /// the message carries more attachments (reference design). Falls back to
  /// the date widget when there is nothing to preview.
  Widget _mediaThumb(MediaMessage msg, {required bool isVideo}) {
    final attachments = AttachmentUtils.attachmentsOf(msg);
    final first = attachments.isNotEmpty ? attachments.first : null;
    final url = first?.fileUrl;
    if (url == null || url.isEmpty) return _buildMessageDate(msg);

    final thumbnailUrl =
        ThumbnailExtractionUtil.thumbnailForIndex(msg.metadata, 0) ??
        ThumbnailExtractionUtil.extractFromMetadata(msg.metadata);
    final overflow = attachments.length - 1;

    final Widget preview = isVideo
        ? CometChatVideoBubble(
            videoUrl: url,
            thumbnailUrl: thumbnailUrl,
            width: 96,
            height: 64,
            colorPalette: colorPalette,
            spacing: spacing,
            // Server thumbnail generation fails for some video formats
            // (returns null / ERR_FILETYPE_NOT_SUPPORTED — e.g. iPhone .mov),
            // so extract the first frame client-side like the other UIKit
            // platforms do, with the standard media placeholder while it
            // loads / on failure. A small play chip sits on top (the bubble's
            // own 64px play icon is oversized for this 96×64 row).
            placeHolder: thumbnailUrl == null
                ? SizedBox.expand(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CometChatVideoFirstFrame(
                          key: ValueKey('cc_search_video_frame_$url'),
                          source: url,
                          fallback: const CometChatMediaPlaceholder(
                            glyphWidth: 28,
                          ),
                        ),
                        const Center(
                          child: CircleAvatar(
                            radius: 13,
                            backgroundColor: Colors.black45,
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          )
        : CometChatImageBubble(
            imageUrl: url,
            thumbnailUrl: thumbnailUrl,
            width: 96,
            height: 64,
            style: const CometChatImageBubbleStyle(
              borderRadius: BorderRadius.zero,
            ),
            colorPalette: colorPalette,
            spacing: spacing,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 96,
        height: 64,
        child: Stack(
          fit: StackFit.expand,
          children: [
            preview,
            // Same "+N" scrim idiom as the media grid's overflow cell.
            if (overflow > 0)
              IgnorePointer(
                child: Container(
                  alignment: Alignment.center,
                  color: Colors.black45,
                  child: Text(
                    '+$overflow',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The date style for a result row: the search's defaults underneath, the
  /// style's [CometChatSearchStyle.dateStyle] over them, and the search-specific
  /// date colour and text style over that. With no dateStyle this is exactly
  /// the style the rows always had.
  CometChatDateStyle _rowDateStyle(Color? defaultTextColor) {
    final base = CometChatDateStyle(
      backgroundColor: colorPalette.transparent,
      textStyle: TextStyle(
        color: defaultTextColor,
        fontSize: typography.caption1?.regular?.fontSize,
        fontWeight: typography.caption1?.regular?.fontWeight,
        fontFamily: typography.caption1?.regular?.fontFamily,
      ),
      border: Border.all(width: 0, color: Colors.transparent),
    ).merge(style.dateStyle);
    return base.copyWith(
      textStyle: (base.textStyle ?? const TextStyle())
          .copyWith(color: style.searchMessageDateTextColor)
          .merge(style.searchMessageDateTextStyle),
    );
  }

  /// Builds a CometChatDate widget for message trailing.
  Widget _buildMessageDate(BaseMessage message) {
    return CometChatDate(
      date: message.sentAt ?? DateTime.now(),
      padding: const EdgeInsets.all(0),
      isTransparentBackground: true,
      style: _rowDateStyle(colorPalette.textTertiary),
      pattern: DateTimePattern.dayDateFormat,
      dateTimeFormatterCallback: widget.timeSeparatorFormatterCallback,
    );
  }

  /// Builds a search result item row using the interstellar layout pattern.
  /// leading (optional icon) | title + subtitle | trailing (date or thumbnail)
  /// Builds the search preview with the SAME rich-text formatting the message
  /// list and conversation subtitles use — markdown, mentions, links — so a
  /// text result reads identically across surfaces (and cross-platform). Falls
  /// back to plain [subtitleStyle] text for non-text rows.
  Widget _buildSearchItem({
    required BaseMessage message,
    required String title,
    required String subtitle,
    String? subtitlePrefix,
    IconData? subtitleIcon,
    Widget? leading,
    Widget? trailing,
    // When set, the subtitle renders with rich-text formatting (markdown /
    // mentions / links) instead of the plain [subtitle] string.
    TextMessage? richTextMessage,
  }) {
    final titleStyle =
        TextStyle(
              color:
                  style.searchMessageSenderTextColor ??
                  colorPalette.textPrimary,
              fontSize: typography.heading4?.medium?.fontSize,
              fontWeight: typography.heading4?.medium?.fontWeight,
              fontFamily: typography.heading4?.medium?.fontFamily,
            )
            .merge(style.searchMessageSenderTextStyle)
            .copyWith(color: style.searchMessageSenderTextColor);

    final subtitleStyle =
        TextStyle(
              color:
                  style.searchMessagePreviewTextColor ??
                  colorPalette.textSecondary,
              fontSize: typography.body?.regular?.fontSize,
              fontWeight: typography.body?.regular?.fontWeight,
              fontFamily: typography.body?.regular?.fontFamily,
            )
            .merge(style.searchMessagePreviewTextStyle)
            .copyWith(color: style.searchMessagePreviewTextColor);

    return Semantics(
      button: true,
      label: Translations.of(context).messageFrom(title),
      child: GestureDetector(
        onTap: () => widget.onMessageClicked?.call(message),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: spacing.padding2 ?? 0),
          color: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null)
                Padding(
                  padding: EdgeInsets.only(right: spacing.padding3 ?? 0),
                  child: leading,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    const SizedBox(height: 2),
                    // Shared with the saved-messages list so both surfaces
                    // preview messages identically. Explicit values are
                    // passed through unchanged; the widget only derives what
                    // is omitted.
                    MessagePreviewSubtitle(
                      message: message,
                      textStyle: subtitleStyle,
                      iconColor: colorPalette.iconSecondary,
                      spacing: spacing.padding1 ?? 2,
                      prefix: subtitlePrefix ?? '',
                      icon: subtitleIcon,
                      text: subtitle,
                      richTextMessage: richTextMessage,
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: EdgeInsets.only(left: spacing.padding2 ?? 0),
                  child: trailing,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getDateSeparator(int index, List<BaseMessage> messages) {
    if (messages[index].deletedAt != null) {
      return const SizedBox(height: 0, width: 0);
    }
    // Show separator for first message or when month changes
    if (index == 0 ||
        !_isSameMonth(
          dt1: messages[index].sentAt,
          dt2: messages[index - 1].sentAt,
        )) {
      final date = messages[index].sentAt ?? DateTime.now();
      return Padding(
        padding: EdgeInsets.fromLTRB(0, spacing.padding2 ?? 0, 0, 0),
        child: CometChatDate(
          date: date,
          // The label is always resolved here. Handing CometChatDate the
          // formatter with no pattern made it format the separator as a time
          // of day, so month separators read like "3:45 pm".
          customDateString: _monthSeparatorLabel(date),
          padding: EdgeInsets.zero,
          style: CometChatDateStyle(
            backgroundColor: colorPalette.transparent,
            borderRadius: BorderRadius.zero,
            border: const Border.fromBorderSide(BorderSide.none),
            textStyle: TextStyle(
              fontSize: typography.caption1?.medium?.fontSize,
              fontWeight: typography.caption1?.medium?.fontWeight,
              fontFamily: typography.caption1?.medium?.fontFamily,
              letterSpacing: 0,
              color: colorPalette.textSecondary,
            ),
          ).merge(style.dateStyle),
        ),
      );
    }
    return const SizedBox(height: 0, width: 0);
  }

  bool _isSameMonth({DateTime? dt1, DateTime? dt2}) {
    if (dt1 == null || dt2 == null) return false;
    return dt1.year == dt2.year && dt1.month == dt2.month;
  }

  /// The text of the separator above each month's message results, such as
  /// "September, 2026".
  ///
  /// [widget.dateSeparatorFormatterCallback]'s `otherDays` can replace it: it
  /// is called with the send time of the first message listed under the
  /// separator, and returning null keeps the default.
  String _monthSeparatorLabel(DateTime date) {
    final defaultLabel = '${_monthName(date.month)}, ${date.year}';
    return widget.dateSeparatorFormatterCallback?.otherDays(
          date.millisecondsSinceEpoch,
        ) ??
        defaultLabel;
  }

  String _monthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month];
  }

  // ===========================================================================
  // Shared Helpers
  // ===========================================================================

  Widget _sectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.padding2 ?? 0),
      child: Text(
        title,
        style:
            TextStyle(
                  color:
                      style.sectionHeaderTextColor ??
                      colorPalette.textSecondary,
                  fontSize: typography.caption1?.medium?.fontSize,
                  fontWeight: typography.caption1?.medium?.fontWeight,
                  fontFamily: typography.caption1?.medium?.fontFamily,
                )
                .merge(style.sectionHeaderTextStyle)
                .copyWith(color: style.sectionHeaderTextColor),
      ),
    );
  }

  Widget _seeMoreButton({required VoidCallback onTap}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.padding2 ?? 0),
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          cc.Translations.of(context).more,
          style:
              TextStyle(
                    color: style.seeMoreTextColor ?? colorPalette.primary,
                    fontSize: typography.body?.medium?.fontSize,
                    fontWeight: typography.body?.medium?.fontWeight,
                    fontFamily: typography.body?.medium?.fontFamily,
                  )
                  .merge(style.seeMoreTextStyle)
                  .copyWith(color: style.seeMoreTextColor),
        ),
      ),
    );
  }

  // ===========================================================================
  // State Views
  // ===========================================================================

  Widget _buildLoadingView() {
    return CometChatShimmerEffect(
      colorPalette: colorPalette,
      child: ListView.builder(
        itemCount: 30,
        shrinkWrap: true,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.padding4 ?? 0,
            vertical: spacing.padding3 ?? 0,
          ),
          child: Row(
            children: [
              const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: MediaQuery.sizeOf(context).width * 0.4,
                          height: 19,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(
                              spacing.radius2 ?? 0,
                            ),
                          ),
                        ),
                        Container(
                          width: MediaQuery.sizeOf(context).width * 0.2,
                          height: 19,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(
                              spacing.radius2 ?? 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(
                          spacing.radius2 ?? 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView(SearchState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
          Padding(
            padding: EdgeInsets.only(bottom: spacing.padding5 ?? 0),
            child: Image.asset(
              AssetConstants.conversationEmpty,
              package: UIConstants.packageName,
              height: 120,
              width: 120,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: spacing.padding1 ?? 0),
            child: Text(
              cc.Translations.of(context).noRecordsFound,
              style: TextStyle(
                color: style.emptyStateTextColor ?? colorPalette.textPrimary,
                fontSize: typography.heading3?.bold?.fontSize,
                fontWeight: typography.heading3?.bold?.fontWeight,
                fontFamily: typography.heading3?.bold?.fontFamily,
              ).merge(style.emptyStateTextStyle),
            ),
          ),
          if (state.searchText.isNotEmpty)
            Text(
              '${cc.Translations.of(context).search} "${state.searchText}"',
              style: TextStyle(
                color:
                    style.emptyStateSubTitleTextColor ??
                    colorPalette.textSecondary,
                fontSize: typography.body?.regular?.fontSize,
                fontWeight: typography.body?.regular?.fontWeight,
                fontFamily: typography.body?.regular?.fontFamily,
              ).merge(style.emptyStateSubTitleTextStyle),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: spacing.padding5 ?? 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: colorPalette.error,
            ),
            SizedBox(height: spacing.padding3 ?? 0),
            Text(
              cc.Translations.of(context).somethingWentWrongError,
              style: TextStyle(
                color: style.errorStateTextColor ?? colorPalette.textPrimary,
                fontSize: typography.heading4?.medium?.fontSize,
                fontWeight: typography.heading4?.medium?.fontWeight,
                fontFamily: typography.heading4?.medium?.fontFamily,
              ).merge(style.errorStateTextStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLoading() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.padding3 ?? 0),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: colorPalette.primary,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}
