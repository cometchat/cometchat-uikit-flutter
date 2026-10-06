import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../cometchat_chat_uikit.dart';

/// A widget that displays the list of conversations with state handling and pagination.
///
/// This widget uses [BlocBuilder] to listen to [ConversationsBloc] and renders
/// the appropriate view based on the current state:
/// - [ConversationsLoading] → [ConversationsLoadingView]
/// - [ConversationsEmpty] → [ConversationsEmptyView]
/// - [ConversationsError] → [ConversationsErrorView]
/// - [ConversationsLoaded] → ListView.builder with [CometChatConversationListItem]
///
/// The widget handles pagination by dispatching [LoadMoreConversations] event
/// when the user scrolls to the bottom of the list.
///
/// Typing indicators are managed per-conversation using ValueNotifier for
/// optimized rebuilds - only the affected conversation item rebuilds when
/// typing status changes.
class ConversationsList extends StatelessWidget {
  /// Generic list-item style applied to every row; see
  /// [CometChatConversationListItem.listItemStyle].
  final ListItemStyle? listItemStyle;

  const ConversationsList({
    super.key,
    required this.conversationsBloc,
    required this.style,
    required this.statusStyle,
    required this.typingStyle,
    required this.receiptStyle,
    required this.datesStyle,
    required this.colorPalette,
    required this.spacing,
    required this.typography,
    this.scrollController,
    this.loadingStateView,
    this.emptyStateView,
    this.errorStateView,
    this.hideError,
    this.listItemView,
    this.subtitleView,
    this.trailingView,
    this.leadingView,
    this.titleView,
    this.avatarHeight,
    this.avatarWidth,
    this.avatarPadding,
    this.avatarMargin,
    this.statusIndicatorHeight,
    this.statusIndicatorWidth,
    this.statusIndicatorBorderRadius,
    this.privateGroupIcon,
    this.protectedGroupIcon,
    this.usersStatusVisibility,
    this.groupTypeVisibility,
    this.selectionMode,
    this.activateSelection,
    this.onItemTap,
    this.onItemLongPress,
    this.hideThreadIndicator,
    this.receiptsVisibility,
    this.typingIndicatorText,
    this.readIcon,
    this.deliveredIcon,
    this.sentIcon,
    this.textFormatters,
    this.datePattern,
    this.datePadding,
    this.dateHeight,
    this.dateWidth,
    this.dateBackgroundIsTransparent,
    this.badgeWidth,
    this.badgeHeight,
    this.badgePadding,
    this.dateTimeFormatterCallback,
    this.itemWrapperBuilder,
    this.onLoad,
    this.onEmpty,
    this.onError,
    this.listItemStyle,
  });

  /// The BLoC managing conversations state.
  final ConversationsBloc conversationsBloc;

  /// The style configuration for the conversations widget.
  final CometChatConversationsStyle style;

  /// The style configuration for the status indicator.
  final CometChatStatusIndicatorStyle statusStyle;

  /// The style configuration for typing indicator.
  final CometChatTypingIndicatorStyle typingStyle;

  /// The style configuration for message receipts.
  final CometChatMessageReceiptStyle receiptStyle;

  /// The style configuration for the date widget.
  final CometChatDateStyle datesStyle;

  /// The color palette used for styling.
  final CometChatColorPalette colorPalette;

  /// The spacing configuration for padding and margins.
  final CometChatSpacing spacing;

  /// The typography configuration for text styles.
  final CometChatTypography typography;

  /// Optional scroll controller for the list.
  final ScrollController? scrollController;

  /// Custom loading state view builder.
  final WidgetBuilder? loadingStateView;

  /// Custom empty state view builder.
  final WidgetBuilder? emptyStateView;

  /// Custom error state view builder.
  final WidgetBuilder? errorStateView;

  /// Whether to hide the error view.
  final bool? hideError;

  /// Custom list item view builder.
  final Widget Function(Conversation conversation)? listItemView;

  /// Custom subtitle view builder.
  final Widget? Function(BuildContext context, Conversation conversation)?
  subtitleView;

  /// Custom trailing view builder.
  final Widget? Function(Conversation conversation)? trailingView;

  /// Custom leading view builder.
  final Widget? Function(BuildContext context, Conversation conversation)?
  leadingView;

  /// Custom title view builder.
  final Widget? Function(BuildContext context, Conversation conversation)?
  titleView;

  /// Height for the avatar.
  final double? avatarHeight;

  /// Width for the avatar.
  final double? avatarWidth;

  /// Padding for the avatar.
  final EdgeInsetsGeometry? avatarPadding;

  /// Margin for the avatar.
  final EdgeInsetsGeometry? avatarMargin;

  /// Height for the status indicator.
  final double? statusIndicatorHeight;

  /// Width for the status indicator.
  final double? statusIndicatorWidth;

  /// Border radius for the status indicator.
  final BorderRadiusGeometry? statusIndicatorBorderRadius;

  /// Custom icon for private groups.
  final Widget? privateGroupIcon;

  /// Custom icon for protected (password) groups.
  final Widget? protectedGroupIcon;

  /// Whether to show user online status.
  final bool? usersStatusVisibility;

  /// Whether to show group type icons.
  final bool? groupTypeVisibility;

  /// The selection mode for the conversations list.
  final SelectionMode? selectionMode;

  /// When selection should be activated.
  final ActivateSelection? activateSelection;

  /// Callback when an item is tapped.
  final Function(Conversation conversation)? onItemTap;

  /// Callback when an item is long-pressed.
  final Function(Conversation conversation)? onItemLongPress;

  /// Whether to hide the thread indicator.
  final bool? hideThreadIndicator;

  /// Whether to show receipt icons.
  final bool? receiptsVisibility;

  /// Custom text for typing indicator.
  final String? typingIndicatorText;

  /// Custom icon for read receipt status.
  final Widget? readIcon;

  /// Custom icon for delivered receipt status.
  final Widget? deliveredIcon;

  /// Custom icon for sent receipt status.
  final Widget? sentIcon;

  /// List of text formatters for message formatting.
  final List<CometChatTextFormatter>? textFormatters;

  /// Custom date pattern callback.
  final String Function(Conversation)? datePattern;

  /// Padding for the date widget.
  final EdgeInsets? datePadding;

  /// Height for the date widget.
  final double? dateHeight;

  /// Width for the date widget.
  final double? dateWidth;

  /// Whether the date background should be transparent.
  final bool? dateBackgroundIsTransparent;

  /// Width for the badge widget.
  final double? badgeWidth;

  /// Height for the badge widget.
  final double? badgeHeight;

  /// Padding for the badge widget.
  final EdgeInsetsGeometry? badgePadding;

  /// Callback for custom date/time formatting.
  final DateTimeFormatterCallback? dateTimeFormatterCallback;

  /// Optional wrapper builder that wraps each conversation list item.
  /// Used by the parent widget to add overlays (e.g., delete button) on top of items.
  final Widget Function(
    BuildContext context,
    Conversation conversation,
    Widget child,
  )?
  itemWrapperBuilder;

  /// Callback triggered when conversations are loaded successfully.
  final OnLoad<Conversation>? onLoad;

  /// Callback triggered when the conversations list is empty.
  final OnEmpty? onEmpty;

  /// Callback triggered when the component encounters an error.
  final OnError? onError;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConversationsBloc, ConversationsState>(
      bloc: conversationsBloc,
      listener: (context, state) {
        if (state is ConversationsLoaded && onLoad != null) {
          onLoad!(state.conversations);
        }
        if (state is ConversationsEmpty && onEmpty != null) {
          onEmpty!();
        }
        if (state is ConversationsError && onError != null) {
          onError!(
            CometChatException(
              'CONVERSATIONS_ERROR',
              state.message,
              state.message,
            ),
          );
        }
      },
      builder: (context, state) {
        // Handle error state
        if (state is ConversationsError) {
          if (hideError == true) {
            return const SizedBox();
          }
          return ConversationsErrorView(
            customView: errorStateView,
            errorMessage: state.message,
            style: style,
            colorPalette: colorPalette,
            spacing: spacing,
            typography: typography,
          );
        }

        // Handle loading state
        if (state is ConversationsLoading) {
          return ConversationsLoadingView(
            customView: loadingStateView,
            colorPalette: colorPalette,
            spacing: spacing,
            typography: typography,
          );
        }

        // Handle empty state
        if (state is ConversationsEmpty) {
          return ConversationsEmptyView(
            customView: emptyStateView,
            style: style,
            colorPalette: colorPalette,
            spacing: spacing,
            typography: typography,
          );
        }

        // Handle loaded state
        if (state is ConversationsLoaded) {
          return _buildConversationsList(context, state);
        }

        // Default to loading view for initial/unknown states
        return ConversationsLoadingView(
          customView: loadingStateView,
          colorPalette: colorPalette,
          spacing: spacing,
          typography: typography,
        );
      },
    );
  }

  /// Builds the conversations list for the loaded state.
  Widget _buildConversationsList(
    BuildContext context,
    ConversationsLoaded state,
  ) {
    final conversations = state.conversations;
    final hasMore = state.hasMore;
    final selectedConversations = state.selectedConversations;

    return ListView.builder(
      controller: scrollController,
      itemCount: hasMore ? conversations.length + 1 : conversations.length,
      itemBuilder: (context, index) {
        // Handle pagination - load more when reaching the end
        if (index >= conversations.length) {
          conversationsBloc.add(const LoadMoreConversations());
          return ConversationsLoadingView(
            customView: loadingStateView,
            colorPalette: colorPalette,
            spacing: spacing,
            typography: typography,
          );
        }

        final conversation = conversations[index];
        final conversationId = conversation.conversationId ?? '';

        // Wrap each item with ValueListenableBuilder for typing indicators
        // This ensures only this item rebuilds when its typing status changes
        return ValueListenableBuilder<List<TypingIndicator>>(
          valueListenable: conversationsBloc.getTypingNotifier(conversationId),
          builder: (context, typingIndicators, child) {
            final item = _buildListItem(
              context,
              conversation,
              selectedConversations,
              typingIndicators,
              isLastRow: index == conversations.length - 1,
            );
            if (itemWrapperBuilder != null) {
              return itemWrapperBuilder!(context, conversation, item);
            }
            return item;
          },
        );
      },
    );
  }

  /// Builds a single list item for a conversation. [isLastRow] marks the
  /// last loaded conversation.
  Widget _buildListItem(
    BuildContext context,
    Conversation conversation,
    Set<String> selectedConversations,
    List<TypingIndicator> typingIndicators, {
    required bool isLastRow,
  }) {
    // Use custom listItemView if provided
    if (listItemView != null) {
      return listItemView!(conversation);
    }

    final isSelected = selectedConversations.contains(
      conversation.conversationId,
    );

    // Calculate hideThreadIndicator dynamically
    // Show thread indicator (hideThreadIndicator = false) only when:
    // The last message has a parentMessageId (is a reply in a thread)
    final shouldHideThreadIndicator = _shouldHideThreadIndicator(conversation);

    // The row style: CometChatConversationsStyle.itemStyle, under the
    // item-level fields CometChatConversationsStyle carries itself. merge
    // lets only the non-null ones win, so an unset field keeps itemStyle's.
    final rowStyle =
        (style.itemStyle ?? const CometChatConversationListItemStyle()).merge(
          CometChatConversationListItemStyle(
            titleTextStyle: style.itemTitleTextStyle,
            titleTextColor: style.itemTitleTextColor,
            subtitleTextStyle: style.itemSubtitleTextStyle,
            subtitleTextColor: style.itemSubtitleTextColor,
            backgroundColor: style.backgroundColor,
            selectedBackgroundColor: style.listItemSelectedBackgroundColor,
            messageTypeIconTint: style.messageTypeIconColor,
            checkBoxBackgroundColor: style.checkBoxBackgroundColor,
            checkBoxCheckedBackgroundColor:
                style.checkBoxCheckedBackgroundColor,
            // Resolved rather than cast: the style takes any geometry.
            checkBoxBorderRadius: style.checkBoxBorderRadius?.resolve(
              Directionality.of(context),
            ),
            checkBoxStrokeColor: style.checkBoxBorder?.color,
            checkBoxStrokeWidth: style.checkBoxBorder?.width,
            checkBoxSelectIconTint: style.checkboxSelectedIconColor,
            privateGroupIconBackground: style.privateGroupIconBackground,
            protectedGroupIconBackground: style.protectedGroupIconBackground,
          ),
        );

    return CometChatConversationListItem(
      conversation: conversation,
      onItemClick: (conv) => _handleItemTap(conv, selectedConversations),
      onItemLongClick:
          onItemLongPress != null ||
              activateSelection == ActivateSelection.onLongClick
          ? (conv) => _handleItemLongPress(conv, selectedConversations)
          : null,
      onSelectionToggle: () => _handleSelectionToggle(conversation),
      isSelected: isSelected,
      selectionMode: selectionMode ?? SelectionMode.none,
      hideUserStatus: !(usersStatusVisibility ?? true),
      hideGroupType: !(groupTypeVisibility ?? true),
      hideReceipts: !(receiptsVisibility ?? true),
      hideThreadIndicator: shouldHideThreadIndicator,
      typingIndicators: typingIndicators,
      // Android draws no separator after the last row, whichever style
      // asks for one.
      hideSeparator: isLastRow,
      textFormatters: textFormatters,
      dateTimeFormatterCallback: dateTimeFormatterCallback,
      avatarHeight: avatarHeight,
      avatarWidth: avatarWidth,
      avatarPadding: avatarPadding,
      avatarMargin: avatarMargin,
      statusIndicatorHeight: statusIndicatorHeight,
      statusIndicatorWidth: statusIndicatorWidth,
      statusIndicatorBorderRadius: statusIndicatorBorderRadius,
      typingIndicatorText: typingIndicatorText,
      datePattern: datePattern,
      datePadding: datePadding,
      dateHeight: dateHeight,
      dateWidth: dateWidth,
      dateBackgroundIsTransparent: dateBackgroundIsTransparent,
      badgeWidth: badgeWidth,
      badgeHeight: badgeHeight,
      badgePadding: badgePadding,
      privateGroupIcon: privateGroupIcon,
      protectedGroupIcon: protectedGroupIcon,
      privateGroupIconBackground: style.privateGroupIconBackground,
      protectedGroupIconBackground: style.protectedGroupIconBackground,
      readIcon: readIcon,
      deliveredIcon: deliveredIcon,
      sentIcon: sentIcon,
      leadingView: leadingView != null
          ? (conv, typing) => leadingView!(context, conv)
          : null,
      titleView: titleView != null
          ? (conv, typing) => titleView!(context, conv)
          : null,
      subtitleView: subtitleView != null
          ? (conv, typing) => subtitleView!(context, conv)
          : null,
      trailingView: trailingView != null
          ? (conv, typing) => trailingView!(conv)
          : null,
      colorPalette: colorPalette,
      spacing: spacing,
      typography: typography,
      // Pass nested styles from CometChatConversationsStyle to the list item
      avatarStyle: style.avatarStyle,
      statusIndicatorStyle: statusStyle,
      receiptStyle: receiptStyle,
      dateStyle: datesStyle,
      badgeStyle: style.badgeStyle,
      typingIndicatorStyle: typingStyle,
      listItemStyle: listItemStyle,
      style: rowStyle,
    );
  }

  /// Handles tap on a conversation item.
  void _handleItemTap(
    Conversation conversation,
    Set<String> selectedConversations,
  ) {
    if ((activateSelection == ActivateSelection.onClick ||
            (activateSelection == ActivateSelection.onLongClick &&
                selectedConversations.isNotEmpty)) &&
        !(selectionMode == null || selectionMode == SelectionMode.none)) {
      conversationsBloc.add(
        ToggleConversationSelection(conversation.conversationId ?? ''),
      );
    } else if (onItemTap != null) {
      onItemTap!(conversation);
    }
  }

  /// Handles long press on a conversation item.
  void _handleItemLongPress(
    Conversation conversation,
    Set<String> selectedConversations,
  ) {
    if (activateSelection == ActivateSelection.onLongClick &&
        selectedConversations.isEmpty &&
        !(selectionMode == null || selectionMode == SelectionMode.none)) {
      conversationsBloc.add(
        ToggleConversationSelection(conversation.conversationId ?? ''),
      );
    } else if (onItemLongPress != null) {
      onItemLongPress!(conversation);
    }
  }

  /// Handles selection toggle for a conversation.
  void _handleSelectionToggle(Conversation conversation) {
    conversationsBloc.add(
      ToggleConversationSelection(conversation.conversationId ?? ''),
    );
  }

  /// Determines whether to hide the thread indicator for a conversation.
  ///
  /// Returns false (show indicator) only when:
  /// - The last message has a parentMessageId (is a reply in a thread)
  /// - hideThreadIndicator parameter is not explicitly set to true
  bool _shouldHideThreadIndicator(Conversation conversation) {
    // If hideThreadIndicator is explicitly set to true, always hide
    if (hideThreadIndicator == true) {
      return true;
    }

    final lastMessage = conversation.lastMessage;
    if (lastMessage == null) {
      return true;
    }

    // Show thread indicator only when message has a parentMessageId (is a reply in a thread)
    final isThreadReply = lastMessage.parentMessageId != 0;

    // Hide indicator if it's not a thread reply
    return !isThreadReply;
  }
}
