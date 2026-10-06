import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../shared_ui/cometchat_uikit_shared.dart';
import '../../../../cometchat_chat_uikit.dart' as cc;
import '../bloc/bloc.dart';
import '../cometchat_ai_assistant_chat_history_style.dart';

/// A BLoC-based widget that displays AI assistant conversation history.
///
/// Shows a list of past AI chat messages with support for:
/// - Pagination (load more on scroll)
/// - Date separators and sticky date header
/// - Message deletion via long-press
/// - New chat button
/// - Loading, empty, and error states
///
/// Usage:
/// ```dart
/// CometChatAIAssistantChatHistory(
///   user: someUser,
///   onMessageClicked: (message) { /* navigate */ },
///   onNewChatButtonClicked: () { /* start new chat */ },
/// )
/// ```
class CometChatAIAssistantChatHistory extends StatefulWidget {
  const CometChatAIAssistantChatHistory({
    super.key,
    this.user,
    this.group,
    this.messagesRequestBuilder,
    this.emptyStateView,
    this.errorStateView,
    this.loadingStateView,
    this.onMessageClicked,
    this.onNewChatButtonClicked,
    this.style,
    this.dateSeparatorPattern,
    this.dateTimeFormatterCallback,
    this.emptyStateText,
    this.errorStateText,
    this.onClose,
    this.backButton,
    this.errorStateSubtitleText,
    this.emptyStateSubtitleText,
    this.height,
    this.width,
    this.hideStickyDate,
    this.hideDateSeparator,
    this.aiAssistantChatHistoryBloc,
  }) : assert(
         user != null || group != null,
         'One of user or group should be passed',
       ),
       assert(
         user == null || group == null,
         'Only one of user or group should be passed',
       );

  ///[aiAssistantChatHistoryBloc] Optional external
  ///AIAssistantChatHistoryBloc instance. If provided, it is used instead of
  ///creating one internally and the widget does not close it on dispose.
  ///Mirrors [CometChatConversations.conversationsBloc] — the seam that lets a
  ///test supply history without a live SDK.
  final AIAssistantChatHistoryBloc? aiAssistantChatHistoryBloc;

  final User? user;
  final Group? group;
  final MessagesRequestBuilder? messagesRequestBuilder;
  final WidgetBuilder? loadingStateView;
  final WidgetBuilder? emptyStateView;
  final WidgetBuilder? errorStateView;
  final void Function(BaseMessage? message)? onMessageClicked;
  final VoidCallback? onNewChatButtonClicked;
  final CometChatAIAssistantChatHistoryStyle? style;
  final String Function(DateTime dateTime)? dateSeparatorPattern;
  final DateTimeFormatterCallback? dateTimeFormatterCallback;
  final String? emptyStateText;
  final String? emptyStateSubtitleText;
  final String? errorStateText;
  final String? errorStateSubtitleText;
  final VoidCallback? onClose;
  final Widget? backButton;
  final double? width;
  final double? height;
  final bool? hideStickyDate;
  final bool? hideDateSeparator;

  @override
  State<CometChatAIAssistantChatHistory> createState() =>
      _CometChatAIAssistantChatHistoryState();
}

class _CometChatAIAssistantChatHistoryState
    extends State<CometChatAIAssistantChatHistory> {
  late AIAssistantChatHistoryBloc _bloc;
  bool _isExternalBloc = false;
  late ScrollController _scrollController;

  // Theme — cached in didChangeDependencies
  late CometChatAIAssistantChatHistoryStyle _style;
  late CometChatDateStyle _dateStyle;
  late CometChatColorPalette _colorPalette;
  late CometChatSpacing _spacing;
  late CometChatTypography _typography;
  bool _themeInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);

    if (widget.aiAssistantChatHistoryBloc != null) {
      _bloc = widget.aiAssistantChatHistoryBloc!;
      _isExternalBloc = true;
    } else {
      _bloc = AIAssistantChatHistoryBloc(
        user: widget.user,
        group: widget.group,
        messagesRequestBuilder: widget.messagesRequestBuilder,
      );
      _bloc.add(const LoadChatHistory());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_themeInitialized) {
      _colorPalette = CometChatThemeHelper.getColorPalette(context);
      _spacing = CometChatThemeHelper.getSpacing(context);
      _typography = CometChatThemeHelper.getTypography(context);
      _style =
          CometChatThemeHelper.getTheme<CometChatAIAssistantChatHistoryStyle>(
            context: context,
            defaultTheme: CometChatAIAssistantChatHistoryStyle.of,
          ).merge(widget.style);
      _dateStyle = CometChatThemeHelper.getTheme<CometChatDateStyle>(
        context: context,
        defaultTheme: CometChatDateStyle.of,
      ).merge(_style.dateSeparatorStyle);
      _themeInitialized = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // an injected bloc belongs to its owner, so only close what we created
    if (!_isExternalBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _onScroll() {
    _updateStickyDate();
  }

  void _updateStickyDate() {
    if (widget.hideStickyDate == true) return;
    final messages = _bloc.items;
    if (messages.isEmpty) return;

    // Simple approach: use the first visible message's date
    // A more precise approach would use scroll offset + item heights
    final offset = _scrollController.offset;
    final estimatedIndex = (offset / 60).clamp(0, messages.length - 1).toInt();
    final date = messages[estimatedIndex].sentAt;

    if (date != null && _bloc.stickyDateNotifier.value != date) {
      _bloc.stickyDateNotifier.value = date;
      _bloc.stickyDateString = widget.dateSeparatorPattern != null
          ? widget.dateSeparatorPattern!(date)
          : null;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: CometChatListBase(
        title: cc.Translations.of(context).chatHistory,
        showBackButton: true,
        titleSpacing: _spacing.padding1,
        backIcon:
            widget.backButton ??
            Semantics(
              button: true,
              label: cc.Translations.of(context).close,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Icon(
                  Icons.close,
                  size: 24,
                  color: _style.closeIconColor ?? _colorPalette.iconSecondary,
                ),
              ),
            ),
        leadingIconPadding: EdgeInsets.only(left: _spacing.padding ?? 0),
        hideSearch: true,
        style: ListBaseStyle(
          height: widget.height,
          width: widget.width,
          background: _style.backgroundColor ?? _colorPalette.background3,
          appBarBackground:
              _style.headerBackgroundColor ??
              _style.backgroundColor ??
              _colorPalette.background3,
          titleStyle:
              TextStyle(
                    color: _colorPalette.textPrimary,
                    fontSize: _typography.heading4?.medium?.fontSize,
                    fontWeight: _typography.heading4?.medium?.fontWeight,
                    fontFamily: _typography.heading4?.medium?.fontFamily,
                  )
                  .merge(_style.headerTitleTextStyle)
                  .copyWith(color: _style.headerTitleTextColor),
          border: _style.border,
          borderRadius: _style.borderRadius ?? BorderRadius.circular(0),
          padding: EdgeInsets.only(top: _spacing.padding2 ?? 10),
        ),
        container: Column(
          children: [
            Divider(
              color: _style.separatorColor ?? _colorPalette.borderDefault,
              height: _style.separatorHeight ?? 1,
            ),
            Expanded(
              child:
                  BlocBuilder<
                    AIAssistantChatHistoryBloc,
                    AIAssistantChatHistoryState
                  >(
                    buildWhen: (previous, current) =>
                        previous.status != current.status ||
                        previous.messages != current.messages ||
                        previous.isLoadingMore != current.isLoadingMore,
                    builder: (context, state) {
                      switch (state.status) {
                        case AIAssistantChatHistoryStatus.initial:
                        case AIAssistantChatHistoryStatus.loading:
                          return _buildLoading(context);
                        case AIAssistantChatHistoryStatus.error:
                          return _buildError(context, state);
                        case AIAssistantChatHistoryStatus.empty:
                          return _buildEmpty(context);
                        case AIAssistantChatHistoryStatus.loaded:
                          return _buildList(context, state);
                      }
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATE VIEWS
  // ============================================================

  Widget _buildLoading(BuildContext context) {
    if (widget.loadingStateView != null) {
      return Center(child: widget.loadingStateView!(context));
    }
    return CometChatShimmerEffect(
      colorPalette: _colorPalette,
      child: ListView.builder(
        itemCount: 30,
        shrinkWrap: true,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _spacing.padding4 ?? 0,
              vertical: _spacing.padding3 ?? 0,
            ),
            child: Container(
              height: 40.0,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(_spacing.radius2 ?? 0),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, AIAssistantChatHistoryState state) {
    if (widget.errorStateView != null) {
      return widget.errorStateView!(context);
    }
    return UIStateUtils.getDefaultErrorStateView(
      context,
      _colorPalette,
      _typography,
      _spacing,
      () => _bloc.add(const LoadChatHistory()),
      errorStateText: widget.errorStateText,
      errorStateSubtitle: widget.errorStateSubtitleText,
      errorStateTextColor: _style.errorStateTextColor,
      errorStateTextStyle: _style.errorStateTextStyle,
      errorStateSubtitleColor: _style.errorStateSubtitleColor,
      errorStateSubtitleStyle: _style.errorStateSubtitleStyle,
    );
  }

  Widget _buildEmpty(BuildContext context) {
    if (widget.emptyStateView != null) {
      return Center(child: widget.emptyStateView!(context));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNewChatButton(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: _spacing.padding3 ?? 12),
                  child: Image.asset(
                    AssetConstants(
                      CometChatThemeHelper.getBrightness(context),
                    ).messagesError,
                    package: UIConstants.packageName,
                    width: 150,
                    height: 150,
                  ),
                ),
                Text(
                  widget.emptyStateText ??
                      cc.Translations.of(context).noConversationHistoryFound,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(
                            color:
                                _style.emptyStateTextColor ??
                                _colorPalette.textPrimary,
                            fontSize: _typography.body?.regular?.fontSize,
                            fontWeight: _typography.body?.regular?.fontWeight,
                            fontFamily: _typography.body?.regular?.fontFamily,
                          )
                          .merge(_style.emptyStateTextStyle)
                          .copyWith(color: _style.emptyStateTextColor),
                ),
                Text(
                  widget.emptyStateSubtitleText ??
                      cc.Translations.of(context).startChatByTappingNewChat,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(
                            color:
                                _style.emptyStateSubtitleColor ??
                                _colorPalette.textPrimary,
                            fontSize: _typography.body?.regular?.fontSize,
                            fontWeight: _typography.body?.regular?.fontWeight,
                            fontFamily: _typography.body?.regular?.fontFamily,
                          )
                          .merge(_style.emptyStateSubtitleStyle)
                          .copyWith(color: _style.emptyStateSubtitleColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LIST VIEW
  // ============================================================

  Widget _buildList(BuildContext context, AIAssistantChatHistoryState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNewChatButton(),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _spacing.padding3 ?? 0),
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  itemCount: state.hasMore
                      ? state.messages.length + 1
                      : state.messages.length,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    if (index == state.messages.length) {
                      // Trigger pagination
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _bloc.add(const LoadMoreChatHistory());
                      });
                      return Center(
                        child: SizedBox(
                          height: 30,
                          width: 30,
                          child: CircularProgressIndicator(
                            color: _colorPalette.primary,
                          ),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateSeparator(state, index),
                        _buildMessageTile(state.messages[index]),
                      ],
                    );
                  },
                ),
                // Sticky date header
                if (widget.hideStickyDate != true)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: ValueListenableBuilder<DateTime?>(
                      valueListenable: _bloc.stickyDateNotifier,
                      builder: (context, stickyDate, _) {
                        if (stickyDate == null) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            0,
                            _spacing.padding2 ?? 0,
                            0,
                            0,
                          ),
                          child: CometChatDate(
                            date: stickyDate,
                            pattern: DateTimePattern.dayDateFormat,
                            customDateString: _bloc.stickyDateString,
                            style: _buildDateStyle(),
                            padding: EdgeInsets.symmetric(
                              vertical: _spacing.padding2 ?? 0,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DATE SEPARATOR
  // ============================================================

  bool _isSameDate(DateTime? dt1, DateTime? dt2) {
    if (dt1 == null || dt2 == null) return true;
    return dt1.year == dt2.year && dt1.month == dt2.month && dt1.day == dt2.day;
  }

  Widget _buildDateSeparator(AIAssistantChatHistoryState state, int index) {
    if (widget.hideDateSeparator == true) return const SizedBox.shrink();

    final message = state.messages[index];
    if (message.deletedAt != null) return const SizedBox.shrink();

    final currentDate = message.sentAt;
    String? customDateString;
    if (widget.dateSeparatorPattern != null && currentDate != null) {
      customDateString = widget.dateSeparatorPattern!(currentDate);
    }

    if (index == 0 ||
        !_isSameDate(currentDate, state.messages[index - 1].sentAt)) {
      return CometChatDate(
        date: currentDate,
        pattern: DateTimePattern.dayDateFormat,
        customDateString: customDateString,
        dateTimeFormatterCallback: widget.dateTimeFormatterCallback,
        style: _buildDateStyle(),
        padding: EdgeInsets.symmetric(vertical: _spacing.padding2 ?? 0),
      );
    }
    return const SizedBox.shrink();
  }

  CometChatDateStyle _buildDateStyle() {
    return CometChatDateStyle(
      backgroundColor: _colorPalette.background3,
      border: Border.all(
        color: _colorPalette.transparent ?? Colors.transparent,
        width: 0,
      ),
      borderRadius: BorderRadius.circular(_spacing.radius1 ?? 0),
      textStyle: TextStyle(
        fontSize: _typography.caption1?.medium?.fontSize,
        fontWeight: _typography.caption1?.medium?.fontWeight,
        fontFamily: _typography.caption1?.medium?.fontFamily,
        letterSpacing: 0,
        color: _colorPalette.textTertiary,
      ),
    ).merge(_dateStyle);
  }

  // ============================================================
  // MESSAGE TILE
  // ============================================================

  Widget _buildMessageTile(BaseMessage message) {
    if (message.deletedAt != null) return const SizedBox.shrink();
    if (message is! TextMessage) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => widget.onMessageClicked?.call(message),
      onLongPress: () => _showDeleteDialog(message),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: _spacing.padding3 ?? 0),
          child: Text(
            message.text,
            maxLines: 1,
            style: TextStyle(
              overflow: TextOverflow.ellipsis,
              fontSize: _typography.body?.regular?.fontSize,
              fontWeight: _typography.body?.regular?.fontWeight,
              fontFamily: _typography.body?.regular?.fontFamily,
              color: _colorPalette.textPrimary,
            ).merge(_style.itemTextStyle).copyWith(color: _style.itemTextColor),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NEW CHAT BUTTON
  // ============================================================

  Widget _buildNewChatButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _spacing.padding2 ?? 0),
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: widget.onNewChatButtonClicked,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: _spacing.padding4 ?? 0),
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(right: _spacing.padding2 ?? 0),
                  child: Icon(
                    Icons.add,
                    color:
                        _style.newChatIconColor ?? _colorPalette.iconSecondary,
                    size: 24,
                  ),
                ),
                Text(
                  cc.Translations.of(context).newChat,
                  style:
                      TextStyle(
                            color: _colorPalette.textPrimary,
                            fontSize: _typography.button?.regular?.fontSize,
                            fontWeight: _typography.button?.regular?.fontWeight,
                            fontFamily: _typography.button?.regular?.fontFamily,
                          )
                          .merge(_style.newChatTitleStyle)
                          .copyWith(color: _style.newChatTextColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DELETE DIALOG
  // ============================================================

  void _showDeleteDialog(BaseMessage message) {
    final confirmDialogStyle =
        CometChatThemeHelper.getTheme<CometChatConfirmDialogStyle>(
          context: context,
          defaultTheme: CometChatConfirmDialogStyle.of,
        ).merge(_style.deleteChatHistoryDialogStyle);

    CometChatConfirmDialog(
      context: context,
      confirmButtonText: cc.Translations.of(context).delete,
      cancelButtonText: cc.Translations.of(context).cancel,
      icon: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Image.asset(
          AssetConstants.deleteIcon,
          package: UIConstants.packageName,
          height: 48,
          width: 48,
          color: confirmDialogStyle.iconColor ?? _colorPalette.error,
        ),
      ),
      title: Text(
        cc.Translations.of(context).deleteConversation,
        textAlign: TextAlign.center,
      ),
      messageText: Text(
        cc.Translations.of(context).confirmDeleteConversation,
        textAlign: TextAlign.center,
      ),
      onCancel: (dialogContext) => Navigator.of(dialogContext).pop(),
      style: CometChatConfirmDialogStyle(
        iconColor: confirmDialogStyle.iconColor ?? _colorPalette.error,
        backgroundColor: confirmDialogStyle.backgroundColor,
        shadow: confirmDialogStyle.shadow,
        iconBackgroundColor: confirmDialogStyle.iconBackgroundColor,
        borderRadius: confirmDialogStyle.borderRadius,
        border: confirmDialogStyle.border,
        cancelButtonBackground:
            confirmDialogStyle.cancelButtonBackground ??
            _colorPalette.transparent,
        confirmButtonBackground:
            confirmDialogStyle.confirmButtonBackground ?? _colorPalette.error,
        cancelButtonTextColor: confirmDialogStyle.cancelButtonTextColor,
        confirmButtonTextColor: confirmDialogStyle.confirmButtonTextColor,
        messageTextColor: confirmDialogStyle.messageTextColor,
        titleTextColor: confirmDialogStyle.titleTextColor,
        titleTextStyle:
            TextStyle(
                  color:
                      confirmDialogStyle.titleTextColor ??
                      _colorPalette.textPrimary,
                  fontSize: _typography.heading2?.medium?.fontSize,
                  fontWeight: _typography.heading2?.medium?.fontWeight,
                  fontFamily: _typography.heading2?.medium?.fontFamily,
                )
                .merge(confirmDialogStyle.titleTextStyle)
                .copyWith(color: confirmDialogStyle.titleTextColor),
        messageTextStyle:
            TextStyle(
                  color:
                      confirmDialogStyle.messageTextColor ??
                      _colorPalette.textSecondary,
                  fontSize: _typography.body?.regular?.fontSize,
                  fontWeight: _typography.body?.regular?.fontWeight,
                  fontFamily: _typography.body?.regular?.fontFamily,
                )
                .merge(confirmDialogStyle.messageTextStyle)
                .copyWith(color: confirmDialogStyle.messageTextColor),
        confirmButtonTextStyle:
            TextStyle(
                  color:
                      confirmDialogStyle.confirmButtonTextColor ??
                      _colorPalette.white,
                  fontSize: _typography.button?.medium?.fontSize,
                  fontWeight: _typography.button?.medium?.fontWeight,
                  fontFamily: _typography.button?.medium?.fontFamily,
                )
                .merge(confirmDialogStyle.confirmButtonTextStyle)
                .copyWith(color: confirmDialogStyle.confirmButtonTextColor),
        cancelButtonTextStyle:
            TextStyle(
                  color:
                      confirmDialogStyle.cancelButtonTextColor ??
                      _colorPalette.textPrimary,
                  fontSize: _typography.button?.medium?.fontSize,
                  fontWeight: _typography.button?.medium?.fontWeight,
                  fontFamily: _typography.button?.medium?.fontFamily,
                )
                .merge(confirmDialogStyle.cancelButtonTextStyle)
                .copyWith(color: confirmDialogStyle.cancelButtonTextColor),
      ),
      onConfirm: (dialogContext) {
        _bloc.add(DeleteChatHistoryMessage(message));
        Navigator.of(dialogContext).pop();
      },
    ).show();
  }
}
