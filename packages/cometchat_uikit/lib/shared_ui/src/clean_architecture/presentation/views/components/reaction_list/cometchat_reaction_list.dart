import "../../../../clean_architecture.dart";
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../cometchat_uikit_shared.dart'
    show ListItemStyle, CometChatListItem, CometChatAvatarStyle;

/// [CometChatReactionList] is a StatefulWidget that displays the list of reactions
/// for a particular message. It requires [reactionRequestBuilder] to fetch the
/// reactions of a particular message. It also requires [message] to fetch
/// the reactions of a particular message. It also requires [onTap] to perform
/// some action on click of a particular reaction.
///
/// ```dart
/// CometChatReactionList(
///   reactionRequestBuilder: ReactionsRequestBuilder(), // Get reactions using a builder
///   errorStateText: "Error fetching reactions", // Set error text
///   emptyStateText: "No reactions yet", // Set empty state text
///   messageObject: messageObject, // Set the message object
///   onTap: (reaction, message) => print("Tapped reaction: $reaction"), // Handle tap on reaction
/// );
///```
class CometChatReactionList extends StatefulWidget {
  const CometChatReactionList({
    super.key,
    this.reactionRequestBuilder,
    this.errorStateView,
    this.errorStateText,
    this.loadingStateView,
    this.emptyStateView,
    this.emptyStateText,
    this.loadingIcon,
    this.onTap,
    this.style,
    this.selectedReaction,
    this.listItemStyle,
    this.avatarStyle,
    this.message,
    this.height,
    this.width,
    this.padding,
    this.onReactionListItemClick,
    this.reactionListBloc,
  });

  ///[reactionRequestBuilder] is a parameter used to fetch the reactions of a particular message
  ///[reactionListBloc] Optional external ReactionListBloc instance.
  ///If provided, it is used instead of creating one internally and the widget
  ///does not close it on dispose. Mirrors
  ///[CometChatConversations.conversationsBloc] — the seam that lets a test
  ///supply reactions without a live SDK.
  final ReactionListBloc? reactionListBloc;

  final ReactionsRequestBuilder? reactionRequestBuilder;

  ///[errorStateView] is a parameter used to show the error state view in case of any error
  final WidgetBuilder? errorStateView;

  ///[errorStateText] is a parameter used to show the error state text in case of any error
  final String? errorStateText;

  ///[loadingStateView] is a parameter used to show the loading state view in case of  loading
  final WidgetBuilder? loadingStateView;

  ///[emptyStateText] text to be displayed when the list is empty
  final String? emptyStateText;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[loadingIcon] is a parameter used to show the loading icon in case of loading
  final Widget? loadingIcon;

  ///[onTap] is a parameter used to perform some action on click of a particular reaction
  final Function(Reaction, BaseMessage)? onTap;

  ///[style] is a parameter used to set the style for the reaction list
  final CometChatReactionListStyle? style;

  ///[selectedReaction] is a parameter used to set the selected reaction
  final String? selectedReaction;

  ///[listItemStyle] is a parameter used to set the style for the list item
  final ListItemStyle? listItemStyle;

  ///[avatarStyle] styles the avatar on each reactor row. Takes precedence
  ///over [CometChatReactionListStyle.avatarStyle], which is the way to set it
  ///on the list [CometChatMessageList] opens.
  final CometChatAvatarStyle? avatarStyle;

  ///[message] is a parameter used to set the message object for which the reactions are to be fetched
  final BaseMessage? message;

  ///[height] provides height to the widget
  final double? height;

  ///[width] provides width to the widget
  final double? width;

  ///[padding] provides padding to the widget
  final EdgeInsetsGeometry? padding;

  ///[onReactionListItemClick] This is to override when a reaction list item is clicked.
  final Function(String? reaction, BaseMessage? message)?
  onReactionListItemClick;

  @override
  State<CometChatReactionList> createState() => _CometChatReactionListState();
}

class _CometChatReactionListState extends State<CometChatReactionList> {
  late ReactionListBloc _bloc;
  bool _isExternalBloc = false;

  @override
  void initState() {
    super.initState();
    if (widget.reactionListBloc != null) {
      _bloc = widget.reactionListBloc!;
      _isExternalBloc = true;
    } else {
      _bloc = ReactionListBloc(
        messageId: widget.message!.id,
        reactionsRequestBuilder: widget.reactionRequestBuilder,
        messageObject: widget.message,
        initialSelectedReaction:
            widget.selectedReaction ?? ReactionConstants.allReactions,
      );
      _bloc.add(const InitializeReactionList());
    }
  }

  @override
  void dispose() {
    // an injected bloc belongs to its owner, so only close what we created
    if (!_isExternalBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  late CometChatReactionListStyle reactionListStyle;
  late CometChatColorPalette colorPalette;
  late CometChatSpacing spacing;
  late CometChatTypography typography;

  @override
  void didChangeDependencies() {
    reactionListStyle =
        CometChatThemeHelper.getTheme<CometChatReactionListStyle>(
          context: context,
          defaultTheme: CometChatReactionListStyle.of,
        ).merge(widget.style);
    colorPalette = CometChatThemeHelper.getColorPalette(context);
    spacing = CometChatThemeHelper.getSpacing(context);
    typography = CometChatThemeHelper.getTypography(context);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.6,
        maxChildSize: 0.75,
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) {
          return Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color:
                  reactionListStyle.backgroundColor ?? colorPalette.background1,
              border: reactionListStyle.border,
              borderRadius:
                  reactionListStyle.borderRadius ??
                  BorderRadius.vertical(
                    top: Radius.circular(spacing.radius4 ?? 0),
                  ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: spacing.padding3 ?? 0,
                    bottom: spacing.padding2 ?? 0,
                  ),
                  child: Container(
                    height: 4,
                    width: 50,
                    decoration: BoxDecoration(
                      color:
                          (colorPalette.textPrimary ?? const Color(0xFF141414))
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: _getList(
                      context,
                      reactionListStyle,
                      colorPalette,
                      typography,
                      spacing,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _getList(
    BuildContext context,
    CometChatReactionListStyle reactionListStyle,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    return BlocBuilder<ReactionListBloc, ReactionListState>(
      buildWhen: (previous, current) => previous != current,
      builder: (context, state) {
        if (state is ReactionListLoading && state.messageReactions.isEmpty) {
          return _getLoadingIndicator(
            context,
            reactionListStyle,
            colorPalette,
            typography,
            spacing,
          );
        } else if (state is ReactionListError) {
          return getErrorView(
            reactionListStyle,
            colorPalette,
            typography,
            spacing,
          );
        } else if (state is ReactionListLoaded) {
          if (state.isEmpty) {
            return _getNoReactionsIndicator(
              context,
              reactionListStyle,
              colorPalette,
              typography,
              spacing,
            );
          }
          return _buildReactionList(
            state,
            reactionListStyle,
            colorPalette,
            typography,
            spacing,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildReactionList(
    ReactionListLoaded state,
    CometChatReactionListStyle reactionListStyle,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    return SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildReactionTabs(
            state,
            reactionListStyle,
            colorPalette,
            typography,
            spacing,
          ),
          _buildReactedUsers(
            state,
            reactionListStyle,
            colorPalette,
            typography,
            spacing,
          ),
        ],
      ),
    );
  }

  Widget _buildReactionTabs(
    ReactionListLoaded state,
    CometChatReactionListStyle reactionListStyle,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          bottom: 1,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorPalette.borderDefault ?? Colors.transparent,
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildReactionTab(
                  state,
                  ReactionConstants.allReactions,
                  "${Translations.of(context).all} ${state.getReactionCount(ReactionConstants.allReactions)}",
                  reactionListStyle,
                  colorPalette,
                  typography,
                  spacing,
                ),
                ...state.messageReactions.keys.map(
                  (reaction) => _buildReactionTab(
                    state,
                    reaction,
                    "$reaction ${state.getReactionCount(reaction)}",
                    reactionListStyle,
                    colorPalette,
                    typography,
                    spacing,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReactionTab(
    ReactionListLoaded state,
    String reaction,
    String label,
    CometChatReactionListStyle reactionListStyle,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    final isSelected = state.selectedReaction == reaction;
    return GestureDetector(
      onTap: () => _bloc.add(UpdateSelectedReaction(reaction)),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: spacing.padding2 ?? 0,
          horizontal: spacing.padding4 ?? 0,
        ),
        decoration: BoxDecoration(
          color: isSelected ? reactionListStyle.activeTabBackgroundColor : null,
          border: isSelected
              ? Border(
                  bottom: BorderSide(
                    color:
                        reactionListStyle.activeTabIndicatorColor ??
                        colorPalette.primary ??
                        Colors.transparent,
                    width: 2,
                  ),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize:
                reactionListStyle.tabTextStyle?.fontSize ??
                typography.body?.medium?.fontSize,
            fontWeight:
                reactionListStyle.tabTextStyle?.fontWeight ??
                typography.body?.medium?.fontWeight,
            color: isSelected
                ? reactionListStyle.activeTabTextColor ??
                      reactionListStyle.tabTextStyle?.color ??
                      colorPalette.textHighlight
                : reactionListStyle.tabTextColor ??
                      reactionListStyle.tabTextStyle?.color ??
                      colorPalette.textSecondary,
          ).merge(reactionListStyle.tabTextStyle),
        ),
      ),
    );
  }

  Widget _buildReactedUsers(
    ReactionListLoaded state,
    CometChatReactionListStyle reactionListStyle,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    List<Reaction> reactions = state.reactionData;

    return SizedBox(
      height: widget.height ?? MediaQuery.of(context).size.height * .5,
      child: ListView.builder(
        itemCount: state.canFetchMore ? reactions.length + 1 : reactions.length,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          if (index >= reactions.length) {
            _bloc.add(FetchReactions(reaction: state.selectedReaction));
            return Container(
              height: 150,
              alignment: Alignment.center,
              child:
                  widget.loadingIcon ??
                  Image.asset(
                    AssetConstants.spinner,
                    package: UIConstants.packageName,
                    color: colorPalette.textSecondary,
                  ),
            );
          }

          return GestureDetector(
            onTap: () => _handleReactionTap(reactions[index], state),
            child: getReactionListItem(
              reactions[index],
              state,
              reactionListStyle,
              colorPalette,
              typography,
              spacing,
            ),
          );
        },
      ),
    );
  }

  void _handleReactionTap(Reaction reaction, ReactionListLoaded state) {
    if (widget.onReactionListItemClick != null) {
      widget.onReactionListItemClick!(reaction.reaction, widget.message);
    } else {
      final isReactedByMe =
          reaction.reactedBy?.uid == CometChatUIKit.loggedInUser?.uid;
      if (isReactedByMe) {
        _bloc.add(RemoveOwnReaction(reaction));
        // Check if we should close the sheet
        if (state.messageReactions.isEmpty ||
            (state.messageReactions.length == 1 &&
                state.messageReactions[reaction.reaction]?.length == 1)) {
          Navigator.pop(context);
        }
      }
    }
  }

  Widget getErrorView(
    CometChatReactionListStyle reactionListStyle,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    if (widget.errorStateView != null) {
      return widget.errorStateView!(context);
    }
    return SizedBox(
      height: widget.height ?? MediaQuery.of(context).size.height * .5,
      child: UIStateUtils.getDefaultErrorStateView(
        context,
        colorPalette,
        typography,
        spacing,
        null,
        errorStateText: widget.errorStateText,
        errorStateTextColor: reactionListStyle.errorTextColor,
        errorStateTextStyle: reactionListStyle.errorTextStyle,
        errorStateSubtitleColor: reactionListStyle.errorSubtitleColor,
        errorStateSubtitleStyle: reactionListStyle.errorSubtitleStyle,
      ),
    );
  }

  Widget getReactionListItem(
    Reaction reaction,
    ReactionListLoaded state,
    CometChatReactionListStyle reactionListStyle,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    final isReactedByMe =
        reaction.reactedBy?.uid == CometChatUIKit.loggedInUser?.uid;
    final title = isReactedByMe ? "You" : (reaction.reactedBy?.name ?? "");

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.padding5 ?? 0,
        vertical: spacing.padding2 ?? 0,
      ),
      child: CometChatListItem(
        avatarURL: reaction.reactedBy?.avatar,
        avatarName: reaction.reactedBy?.name,
        title: title,
        subtitleView: isReactedByMe
            ? Text(
                Translations.of(context).tapToRemove,
                style: TextStyle(
                  fontSize:
                      reactionListStyle.subtitleTextStyle?.fontSize ??
                      typography.caption1?.regular?.fontSize,
                  fontWeight:
                      reactionListStyle.subtitleTextStyle?.fontWeight ??
                      typography.caption1?.regular?.fontWeight,
                  fontFamily:
                      reactionListStyle.subtitleTextStyle?.fontFamily ??
                      typography.caption1?.regular?.fontFamily,
                  color:
                      reactionListStyle.subtitleTextColor ??
                      reactionListStyle.subtitleTextStyle?.color ??
                      colorPalette.textSecondary,
                ).merge(reactionListStyle.subtitleTextStyle),
              )
            : null,
        tailView: Text(
          reaction.reaction ?? "",
          style: typography.heading2?.regular?.merge(
            reactionListStyle.tailViewTextStyle,
          ),
        ),
        style: ListItemStyle(
          titleStyle: TextStyle(
            fontSize:
                reactionListStyle.titleTextStyle?.fontSize ??
                typography.body?.medium?.fontSize,
            fontWeight:
                reactionListStyle.titleTextStyle?.fontWeight ??
                typography.body?.medium?.fontWeight,
            fontFamily:
                reactionListStyle.titleTextStyle?.fontFamily ??
                typography.body?.medium?.fontFamily,
            color:
                reactionListStyle.titleTextColor ??
                reactionListStyle.titleTextStyle?.color ??
                colorPalette.textPrimary,
          ).merge(reactionListStyle.titleTextStyle),
        ).merge(widget.listItemStyle),
        avatarStyle:
            widget.avatarStyle ??
            reactionListStyle.avatarStyle ??
            const CometChatAvatarStyle(),
        avatarHeight: 32,
        avatarWidth: 32,
      ),
    );
  }

  Widget _getNoReactionsIndicator(
    BuildContext context,
    CometChatReactionListStyle reactionListStyle,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    if (widget.emptyStateView != null) {
      return Center(child: widget.emptyStateView!(context));
    } else {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: Text(
          widget.emptyStateText ?? Translations.of(context).noReactionsFound,
          style: TextStyle(
            fontSize:
                reactionListStyle.emptyTextStyle?.fontSize ??
                typography.body?.regular?.fontSize,
            fontWeight:
                reactionListStyle.emptyTextStyle?.fontWeight ??
                typography.body?.regular?.fontWeight,
            color:
                reactionListStyle.emptyTextStyle?.color ??
                colorPalette.textSecondary,
          ).merge(reactionListStyle.emptyTextStyle),
        ),
      );
    }
  }

  Widget _getLoadingIndicator(
    BuildContext context,
    CometChatReactionListStyle reactionListStyle,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    if (widget.loadingStateView != null) {
      return Center(child: widget.loadingStateView!(context));
    } else {
      return SizedBox(
        height: widget.height ?? MediaQuery.of(context).size.height * .5,
        child: CometChatShimmerEffect(
          colorPalette: colorPalette,
          child: ListView.builder(
            itemCount: 30,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.padding5 ?? 0,
                  vertical: spacing.padding2 ?? 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const CircleAvatar(radius: 18),
                    Flexible(
                      flex: 4,
                      child: Container(
                        margin: EdgeInsets.only(left: spacing.padding3 ?? 0),
                        height: 18,
                        decoration: BoxDecoration(
                          color: colorPalette.background1,
                          borderRadius: BorderRadius.circular(
                            spacing.radiusMax ?? 0,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const CircleAvatar(radius: 10),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }
  }
}
