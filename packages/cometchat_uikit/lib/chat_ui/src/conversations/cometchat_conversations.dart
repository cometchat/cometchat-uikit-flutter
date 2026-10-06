import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../cometchat_chat_uikit.dart' as cc;
import '../../../shared_ui/src/clean_architecture/core/utils/thread_toast.dart';

///[CometChatConversations] is a component that shows all conversations involving the logged in user with the help of [CometChatListBase] and [CometChatListItem]
///By default, for each conversation that will be listed, the name of the user or group the logged in user is having conversation with will be displayed in the title of every list item,
///the subtitle will contain the last message in that conversation along with its receipt status, the leading view will contain the avatars of the user and groups and
///status indicator will indicate if users are online and icons for indicating a private or password protected group,
///and the trailing view will contain the time of the last message in that conversation and the number of unread messages.
///
///fetched conversations are listed down according to the order of recent activity
///conversations are fetched using [ConversationsBuilderProtocol] and [ConversationsRequestBuilder]
///
/// ```dart
/// CometChatConversations(
///  avatarStyle: CometChatAvatarStyle(),
///  statusIndicatorStyle: CometChatStatusIndicatorStyle(),
///  badgeStyle: CometChatBadgeStyle(),
///  receiptStyle: CometChatMessageReceiptStyle(),
///  appBarOptions: [],
///  hideReceipt: false,
///  protectedGroupIcon: Icon(Icons.lock),
///  privateGroupIcon: Icon(Icons.lock),
///  )
///  ```

class CometChatConversations extends StatefulWidget {
  /// Style for every list item: background, gradient, border, corner
  /// radius, padding, margin, size, title style and a separator line between
  /// rows (none after the last). [conversationsStyle] wins wherever both set
  /// a value.
  final ListItemStyle? listItemStyle;

  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Tag of a controller from the GetX-based implementation.
  @Deprecated(
    'Has no effect. To supply your own bloc, use conversationsBloc. Will be removed in 7.0.0.',
  )
  final String? controllerTag;

  const CometChatConversations({
    super.key,
    this.conversationsProtocol,
    this.subtitleView,
    this.listItemView,
    this.conversationsStyle = const CometChatConversationsStyle(),
    this.scrollController,
    this.backButton,
    this.showBackButton = false,
    this.selectionMode,
    this.onSelection,
    this.title,
    this.conversationsRequestBuilder,
    this.hideError,
    this.emptyStateView,
    this.errorStateView,
    this.trailingView,
    this.appBarOptions,
    this.usersStatusVisibility = true,
    this.receiptsVisibility = true,
    this.protectedGroupIcon,
    this.privateGroupIcon,
    this.readIcon,
    this.deliveredIcon,
    this.sentIcon,
    this.activateSelection,
    this.datePattern,
    this.typingIndicatorText,
    this.onBack,
    this.onItemTap,
    this.onItemLongPress,
    this.hideAppbar = false,
    this.textFormatters,
    this.mentionAllLabel,
    this.mentionAllLabelId,
    this.datePadding,
    this.dateHeight,
    this.dateBackgroundIsTransparent,
    this.dateWidth,
    this.badgeWidth,
    this.badgeHeight,
    this.badgePadding,
    this.statusIndicatorWidth,
    this.statusIndicatorHeight,
    this.statusIndicatorBorderRadius,
    this.avatarMargin,
    this.avatarPadding,
    this.avatarWidth,
    this.avatarHeight,
    this.deleteConversationOptionVisibility = true,
    this.pinConversationOptionVisibility = true,
    this.groupTypeVisibility = true,
    this.setOptions,
    this.addOptions,
    this.loadingStateView,
    this.leadingView,
    this.titleView,
    this.onLoad,
    this.onEmpty,
    this.onError,
    this.customSoundForMessages,
    this.disableSoundForMessages = false,
    this.submitIcon,
    this.dateTimeFormatterCallback,
    this.conversationsBloc,
    this.routeObserver,
    this.hideSearch,
    this.searchReadOnly = false,
    this.onSearchTap,
    this.searchBoxIcon,
    this.searchPadding,
    this.searchContentPadding,
    this.listItemStyle,
    this.controllerTag,
  });

  ///[routeObserver] Optional RouteObserver to detect when this widget is not visible.
  ///When provided, the widget will freeze rebuilds during keyboard animation
  ///when another screen is pushed on top (e.g., messages screen).
  ///This prevents expensive rebuilds caused by MediaQuery changes.
  ///
  ///Usage:
  ///```dart
  ///// In your app, create a global RouteObserver
  ///final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
  ///
  ///// Add it to MaterialApp
  ///MaterialApp(
  ///  navigatorObservers: [routeObserver],
  ///  ...
  ///)
  ///
  ///// Pass it to CometChatConversations
  ///CometChatConversations(
  ///  routeObserver: routeObserver,
  ///  ...
  ///)
  ///```
  final RouteObserver<ModalRoute<void>>? routeObserver;

  ///[conversationsBloc] Optional external ConversationsBloc instance.
  ///If provided, this bloc will be used instead of creating a new one internally.
  ///This allows for custom bloc implementations with overridden hooks.
  final ConversationsBloc? conversationsBloc;

  ///[conversationsProtocol] Request builder protocol to fetch conversations.
  final ConversationsBuilderProtocol? conversationsProtocol;

  ///[conversationsRequestBuilder] Request builder to fetch conversations.
  final ConversationsRequestBuilder? conversationsRequestBuilder;

  ///[subtitleView] to set subtitle for each conversation
  final Widget? Function(BuildContext context, Conversation conversation)?
  subtitleView;

  ///[trailingView] to set tailView for each conversation
  final Widget? Function(Conversation conversation)? trailingView;

  ///[listItemView] set custom view for each conversation
  final Widget Function(Conversation conversation)? listItemView;

  ///[conversationsStyle] sets style
  final CometChatConversationsStyle conversationsStyle;

  ///[scrollController] to handle scrolling behavior.
  final ScrollController? scrollController;

  ///[backButton] back button
  final Widget? backButton;

  ///[showBackButton] switch on/off back button
  final bool showBackButton;

  ///[selectionMode] specifies mode conversations module is opening in
  final SelectionMode? selectionMode;

  ///[onSelection] function will be performed
  final Function(List<Conversation>? list)? onSelection;

  ///[title] sets title for the list
  final String? title;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[errorStateView] returns view fow error state
  final WidgetBuilder? errorStateView;

  ///[loadingStateView] returns view fow loading state
  final WidgetBuilder? loadingStateView;

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget>? appBarOptions;

  ///[usersStatusVisibility] controls visibility of status indicator shown if a user is online
  final bool? usersStatusVisibility;

  ///[receiptsVisibility] controls visibility of receipts
  final bool? receiptsVisibility;

  ///[protectedGroupIcon] provides icon in status indicator for protected group
  final Widget? protectedGroupIcon;

  ///[privateGroupIcon] provides icon in status indicator for private group
  final Widget? privateGroupIcon;

  ///[readIcon] provides icon in read receipts if a message is read
  final Widget? readIcon;

  ///[deliveredIcon] provides icon in read receipts if a message is delivered
  final Widget? deliveredIcon;

  ///[sentIcon] provides icon in read receipts if a message is sent
  final Widget? sentIcon;

  ///[activateSelection] lets the widget know if conversations are allowed to be selected
  final ActivateSelection? activateSelection;

  ///[datePattern] is used to generate customDateString for CometChatDate
  final String Function(Conversation conversation)? datePattern;

  ///[typingIndicatorText] if not null is visible instead of default text shown when another user is typing
  final String? typingIndicatorText;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[onItemTap] callback triggered on tapping a conversation item
  final Function(Conversation conversation)? onItemTap;

  ///[onItemLongPress] callback triggered on pressing for long on a conversation item
  final Function(Conversation conversation)? onItemLongPress;

  ///[hideAppbar] toggle visibility for app bar
  final bool? hideAppbar;

  ///[textFormatters] is a list of text formatters for message bubbles with type text
  final List<CometChatTextFormatter>? textFormatters;

  ///[mentionAllLabel] is the label an @all mention shows in a conversation's
  ///last-message preview, in place of the localized "Notify All". Ignored when
  ///[textFormatters] is given: set it on the [CometChatMentionsFormatter] in
  ///that list instead.
  final String? mentionAllLabel;

  ///[mentionAllLabelId] is the id of the @all mention the preview formats,
  ///when the app sends @all under an id other than "all". Ignored when
  ///[textFormatters] is given, like [mentionAllLabel].
  final String? mentionAllLabelId;

  ///[datePadding] provides padding for [CometChatDate]
  final EdgeInsets? datePadding;

  ///[dateHeight] provides height for [CometChatDate]
  final double? dateHeight;

  ///[dateBackgroundIsTransparent] controls the background of [CometChatDate]
  final bool? dateBackgroundIsTransparent;

  ///[dateWidth] provides width for [CometChatDate]
  final double? dateWidth;

  ///[badgeWidth] provides width for [CometChatBadge]
  final double? badgeWidth;

  ///[badgeHeight] provides height for [CometChatBadge]
  final double? badgeHeight;

  ///[badgePadding] provides padding to the widget
  final EdgeInsetsGeometry? badgePadding;

  ///[avatarWidth] provides width to the widget
  final double? avatarWidth;

  ///[avatarHeight] provides height to the widget
  final double? avatarHeight;

  ///[avatarPadding] provides padding to the widget
  final EdgeInsetsGeometry? avatarPadding;

  ///[avatarMargin] provides margin to the widget
  final EdgeInsetsGeometry? avatarMargin;

  ///[statusIndicatorWidth] provides width to the status indicator
  final double? statusIndicatorWidth;

  ///[statusIndicatorHeight] provides height to the status indicator
  final double? statusIndicatorHeight;

  ///[statusIndicatorBorderRadius] provides borderRadius to the status indicator
  final BorderRadiusGeometry? statusIndicatorBorderRadius;

  ///[deleteConversationOptionVisibility] controls visibility of delete conversation option
  final bool? deleteConversationOptionVisibility;

  ///[pinConversationOptionVisibility] controls the Pin/Unpin action shown in
  ///the long-press overlay. The rendered action follows the conversation's
  ///pin state: unpinned → Pin; pinned by the logged-in user → Unpin; pinned
  ///by an admin surface (`pinnedBy == app_system` or another uid) → no
  ///action, since only a self pin is user-removable. The pinned indicator on
  ///the row renders whenever `pinnedBy` exists, independent of this flag.
  final bool? pinConversationOptionVisibility;

  ///[groupTypeVisibility] Hide the group type icon which is visible on the group icon.
  final bool? groupTypeVisibility;

  ///[submitIcon] will override the default submit icon
  final Widget? submitIcon;

  ///[setOptions] sets List of actions available on the long press of list item
  final List<CometChatOption>? Function(
    Conversation conversation,
    ConversationsBloc bloc,
    BuildContext context,
  )?
  setOptions;

  ///[addOptions] adds into the current List of actions available on the long press of list item
  final List<CometChatOption>? Function(
    Conversation conversation,
    ConversationsBloc bloc,
    BuildContext context,
  )?
  addOptions;

  ///[leadingView] to set leading view for each conversation
  final Widget? Function(BuildContext context, Conversation conversation)?
  leadingView;

  ///[titleView] to set title view for each conversation
  final Widget? Function(BuildContext context, Conversation conversation)?
  titleView;

  ///[onError] callback triggered when the component encounters an error
  final OnError? onError;

  ///[onLoad] callback triggered when conversations are loaded successfully
  final OnLoad<Conversation>? onLoad;

  ///[onEmpty] callback triggered when the conversations list is empty
  final OnEmpty? onEmpty;

  ///[customSoundForMessages] set custom sound for messages
  final String? customSoundForMessages;

  ///[disableSoundForMessages] disable sound for messages
  final bool? disableSoundForMessages;

  /// [dateTimeFormatterCallback] is a callback that can be used to format the date and time
  final DateTimeFormatterCallback? dateTimeFormatterCallback;

  /// [hideSearch] hides the search bar in the app bar
  final bool? hideSearch;

  ///[searchReadOnly] to specify if search box is read only
  final bool searchReadOnly;

  ///[onSearchTap] callback triggered on search box tap
  final GestureTapCallback? onSearchTap;

  ///[searchBoxIcon] search box prefix icon
  final Widget? searchBoxIcon;

  ///[searchPadding] provides padding to the search
  final EdgeInsetsGeometry? searchPadding;

  ///[searchContentPadding] provides padding to the search content
  final EdgeInsetsGeometry? searchContentPadding;

  @override
  State<CometChatConversations> createState() => _CometChatConversationsState();
}

class _CometChatConversationsState extends State<CometChatConversations>
    with AutomaticKeepAliveClientMixin, RouteAware {
  late CometChatConversationsStyle style;
  late CometChatStatusIndicatorStyle statusStyle;
  late CometChatTypingIndicatorStyle typingStyle;
  late CometChatMessageReceiptStyle receiptStyle;
  late CometChatDateStyle datesStyle;
  late CometChatTypography typography;
  late CometChatColorPalette colorPalette;
  late CometChatSpacing spacing;

  late String dateString;

  ///BLoC to manage conversations state
  late ConversationsBloc conversationsBloc;

  /// Where the user last pressed, used to position the options menu.

  /// Track which conversation is showing delete overlay
  String? _conversationShowingDeleteOverlay;

  /// The integrator's options for the row whose menu was opened last, fixed
  /// at long-press so the menu doesn't change under the user while it closes.
  ({String? id, List<CometChatOption> options, bool keepDefaults})?
  _menuOptions;

  /// Flag to track if theme has been initialized
  bool _themeInitialized = false;

  /// Track brightness to detect dark mode changes
  Brightness? _cachedBrightness;

  /// Track if this route is currently active (visible)
  /// When false, the widget will use cached content to prevent rebuilds
  bool _isRouteActive = true;

  /// Cached widget to return when route is not active
  /// This prevents expensive rebuilds during keyboard animation
  Widget? _cachedWidget;

  /// Keep state alive when offstage (e.g., in IndexedStack, PageView)
  /// This prevents expensive re-initialization when switching tabs
  @override
  bool get wantKeepAlive => true;

  bool _routeSubscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Subscribe to route changes if routeObserver is provided (only once)
    if (widget.routeObserver != null && !_routeSubscribed) {
      widget.routeObserver!.subscribe(this, ModalRoute.of(context)!);
      _routeSubscribed = true;
    }

    // Only initialize theme once to avoid expensive lookups during keyboard animation
    // But re-initialize when brightness changes (dark mode toggle)
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (_themeInitialized && !brightnessChanged) return;
    _cachedBrightness = currentBrightness;
    _themeInitialized = true;
    _cachedWidget = null; // Clear cached widget so it rebuilds with new theme

    typography = CometChatThemeHelper.getTypography(context);
    colorPalette = CometChatThemeHelper.getColorPalette(context);
    spacing = CometChatThemeHelper.getSpacing(context);
    style = CometChatThemeHelper.getTheme<CometChatConversationsStyle>(
      context: context,
      defaultTheme: CometChatConversationsStyle.of,
    ).merge(widget.conversationsStyle);
    statusStyle = CometChatThemeHelper.getTheme<CometChatStatusIndicatorStyle>(
      context: context,
      defaultTheme: CometChatStatusIndicatorStyle.of,
    ).merge(style.statusIndicatorStyle);
    typingStyle = CometChatThemeHelper.getTheme<CometChatTypingIndicatorStyle>(
      context: context,
      defaultTheme: CometChatTypingIndicatorStyle.of,
    ).merge(style.typingIndicatorStyle);
    receiptStyle = CometChatThemeHelper.getTheme<CometChatMessageReceiptStyle>(
      context: context,
      defaultTheme: CometChatMessageReceiptStyle.of,
    ).merge(style.receiptStyle);
    datesStyle = CometChatThemeHelper.getTheme<CometChatDateStyle>(
      context: context,
      defaultTheme: CometChatDateStyle.of,
    ).merge(style.dateStyle);
  }

  // RouteAware callbacks - track when this route is visible
  @override
  void didPush() {
    _isRouteActive = true;
  }

  @override
  void didPopNext() {
    // Covering route was popped - this route is now visible again
    _isRouteActive = true;
    _cachedWidget = null; // Clear cache to allow fresh rebuild
  }

  @override
  void didPushNext() {
    // Another route was pushed on top - this route is no longer visible
    _isRouteActive = false;
  }

  @override
  void didPop() {
    _isRouteActive = false;
  }

  @override
  void initState() {
    dateString = DateTime.now().microsecondsSinceEpoch.toString();

    // Use external bloc if provided, otherwise create a new one
    if (widget.conversationsBloc != null) {
      conversationsBloc = widget.conversationsBloc!;
      _isExternalBloc = true;
      // Skip service locator initialization when external bloc is provided
      // The external bloc is responsible for its own dependencies
    } else {
      // Initialize service locator if not already initialized (only for internal bloc)
      _initializeServiceLocator();

      // Create BLoC with dependencies from service locator and configuration options
      conversationsBloc = ConversationsBloc(
        disableSoundForMessages: widget.disableSoundForMessages ?? false,
        customSoundForMessages: widget.customSoundForMessages,
        usersStatusVisibility: widget.usersStatusVisibility ?? true,
        receiptsVisibility: widget.receiptsVisibility ?? true,
        conversationsRequestBuilder: widget.conversationsRequestBuilder,
        conversationsProtocol: widget.conversationsProtocol,
      );
      _isExternalBloc = false;
    }

    // Load conversations
    conversationsBloc.add(const LoadConversations());

    super.initState();
  }

  /// Initialize service locator if not already initialized
  void _initializeServiceLocator() {
    if (!ConversationsServiceLocator.instance.isInitialized) {
      ConversationsServiceLocator.instance.setup();
    }
  }

  /// Track if bloc is external (should not be closed by this widget)
  bool _isExternalBloc = false;

  @override
  void dispose() {
    // Unsubscribe from route observer
    if (widget.routeObserver != null) {
      widget.routeObserver!.unsubscribe(this);
    }
    // Only close the bloc if we created it internally
    if (!_isExternalBloc) {
      conversationsBloc.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Required for AutomaticKeepAliveClientMixin
    super.build(context);

    // When route is not active (another screen on top), return cached widget
    // This prevents expensive rebuilds during keyboard animation on the messages screen
    if (!_isRouteActive && widget.routeObserver != null) {
      if (_cachedWidget != null) {
        return _cachedWidget!;
      }
    }

    // Build the actual widget
    final builtWidget = RepaintBoundary(
      child: BlocProvider.value(
        value: conversationsBloc,
        child: ClipRRect(
          borderRadius: style.borderRadius ?? BorderRadius.circular(0),
          child: CometChatListBase(
            titleView: BlocBuilder<ConversationsBloc, ConversationsState>(
              builder: (context, state) {
                final selectedCount = state is ConversationsLoaded
                    ? state.selectedConversations.length
                    : 0;
                return Text(
                  selectedCount > 0
                      ? "$selectedCount"
                      : widget.title ?? cc.Translations.of(context).chats,
                  style:
                      TextStyle(
                            color: colorPalette.textPrimary,
                            fontSize: typography.heading1?.bold?.fontSize,
                            fontWeight: typography.heading1?.bold?.fontWeight,
                            fontFamily: typography.heading1?.bold?.fontFamily,
                          )
                          .merge(style.titleTextStyle)
                          .copyWith(color: style.titleTextColor),
                );
              },
            ),
            titleSpacing: widget.showBackButton ? 0 : 16,
            hideSearch: widget.hideSearch ?? true,
            searchBoxIcon: widget.searchBoxIcon,
            searchPadding:
                widget.searchPadding ??
                EdgeInsets.symmetric(
                  horizontal: spacing.padding4 ?? 0,
                  vertical: spacing.padding3 ?? 0,
                ),
            searchContentPadding:
                widget.searchContentPadding ??
                EdgeInsets.symmetric(
                  horizontal: spacing.padding3 ?? 0,
                  vertical: spacing.padding2 ?? 0,
                ),
            searchBoxHeight: 40,
            onSearchTap: widget.onSearchTap,
            searchReadOnly: widget.searchReadOnly,
            hideAppBar: widget.hideAppbar,
            backIcon: BlocBuilder<ConversationsBloc, ConversationsState>(
              builder: (context, state) {
                final hasSelection =
                    state is ConversationsLoaded &&
                    state.selectedConversations.isNotEmpty;
                return hasSelection
                    ? IconButton(
                        tooltip: Translations.of(context).clearSearch,
                        onPressed: () {
                          conversationsBloc.add(
                            const ClearConversationSelection(),
                          );
                        },
                        icon: Icon(
                          Icons.clear,
                          color: colorPalette.iconPrimary,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                      )
                    : (widget.backButton ??
                          IconButton(
                            tooltip: Translations.of(context).back,
                            onPressed: widget.onBack,
                            icon: Icon(
                              Icons.arrow_back,
                              // Resolve the style before the palette — see
                              // ENG-39105.
                              color:
                                  style.backIconColor ??
                                  colorPalette.iconPrimary,
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                          ));
              },
            ),
            showBackButton: widget.showBackButton,
            onBack: widget.onBack,
            menuOptions: [
              if (widget.appBarOptions != null &&
                  widget.appBarOptions!.isNotEmpty)
                ...widget.appBarOptions!,
              _getSelectionWidget(),
            ],
            style: ListBaseStyle(
              background: style.backgroundColor ?? colorPalette.background1,
              titleStyle:
                  TextStyle(
                        color: style.titleTextColor ?? colorPalette.textPrimary,
                        fontSize: typography.heading1?.bold?.fontSize,
                        fontWeight: typography.heading1?.bold?.fontWeight,
                        fontFamily: typography.heading1?.bold?.fontFamily,
                      )
                      .merge(style.titleTextStyle)
                      .copyWith(color: style.titleTextColor),
              backIconTint: style.backIconColor ?? colorPalette.iconPrimary,
              border: style.border,
              borderRadius: style.borderRadius,
              searchIconTint:
                  style.searchIconColor ?? colorPalette.iconSecondary,
              searchBoxBackground:
                  style.searchBackgroundColor ?? colorPalette.background3,
              borderSide:
                  style.searchBorder ??
                  BorderSide(
                    color: colorPalette.borderLight ?? Colors.transparent,
                    width: 1,
                  ),
              searchTextFieldRadius:
                  style.searchBorderRadius ??
                  BorderRadius.circular(spacing.radiusMax ?? 0),
              searchPlaceholderStyle:
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
              appBarShape: Border(
                bottom: BorderSide(
                  color:
                      style.separatorColor ??
                      colorPalette.borderLight ??
                      Colors.transparent,
                  width: style.separatorHeight ?? 1,
                ),
              ),
            ),
            container: ConversationsList(
              conversationsBloc: conversationsBloc,
              style: style,
              listItemStyle: widget.listItemStyle,
              statusStyle: statusStyle,
              typingStyle: typingStyle,
              receiptStyle: receiptStyle,
              datesStyle: datesStyle,
              colorPalette: colorPalette,
              spacing: spacing,
              typography: typography,
              scrollController: widget.scrollController,
              loadingStateView: widget.loadingStateView,
              emptyStateView: widget.emptyStateView,
              errorStateView: widget.errorStateView,
              hideError: widget.hideError,
              listItemView: widget.listItemView,
              subtitleView: widget.subtitleView,
              trailingView: widget.trailingView,
              leadingView: widget.leadingView,
              titleView: widget.titleView,
              avatarHeight: widget.avatarHeight,
              avatarWidth: widget.avatarWidth,
              avatarPadding: widget.avatarPadding,
              avatarMargin: widget.avatarMargin,
              statusIndicatorHeight: widget.statusIndicatorHeight,
              statusIndicatorWidth: widget.statusIndicatorWidth,
              statusIndicatorBorderRadius: widget.statusIndicatorBorderRadius,
              privateGroupIcon: widget.privateGroupIcon,
              protectedGroupIcon: widget.protectedGroupIcon,
              usersStatusVisibility: widget.usersStatusVisibility,
              groupTypeVisibility: widget.groupTypeVisibility,
              selectionMode: widget.selectionMode,
              activateSelection: widget.activateSelection,
              onItemTap: _handleItemTapWithDeleteDismiss,
              onItemLongPress:
                  widget.onItemLongPress ?? _handleDefaultLongPress,
              hideThreadIndicator: false,
              receiptsVisibility: widget.receiptsVisibility,
              typingIndicatorText: widget.typingIndicatorText,
              readIcon: widget.readIcon,
              deliveredIcon: widget.deliveredIcon,
              sentIcon: widget.sentIcon,
              textFormatters: widget.textFormatters ?? _mentionAllFormatters(),
              datePattern: widget.datePattern,
              datePadding: widget.datePadding,
              dateHeight: widget.dateHeight,
              dateWidth: widget.dateWidth,
              dateBackgroundIsTransparent: widget.dateBackgroundIsTransparent,
              badgeWidth: widget.badgeWidth,
              badgeHeight: widget.badgeHeight,
              badgePadding: widget.badgePadding,
              dateTimeFormatterCallback: widget.dateTimeFormatterCallback,
              itemWrapperBuilder:
                  (widget.deleteConversationOptionVisibility == true ||
                      widget.pinConversationOptionVisibility != false)
                  ? _wrapItemWithDeleteOverlay
                  : null,
              onLoad: widget.onLoad,
              onEmpty: widget.onEmpty,
              onError: widget.onError,
            ),
          ),
        ),
      ),
    );

    // Cache the widget for when route becomes inactive
    _cachedWidget = builtWidget;

    return builtWidget;
  }

  /// Returns the selection widget for the app bar.
  Widget _getSelectionWidget() {
    return BlocBuilder<ConversationsBloc, ConversationsState>(
      builder: (context, state) {
        if (state is ConversationsLoaded &&
            state.selectedConversations.isNotEmpty) {
          return IconButton(
            tooltip: Translations.of(context).done,
            onPressed: () {
              final selectedIds = state.selectedConversations;
              final selectedConversations = state.conversations
                  .where((c) => selectedIds.contains(c.conversationId))
                  .toList();
              if (widget.onSelection != null) {
                widget.onSelection!(selectedConversations);
              }
            },
            icon:
                widget.submitIcon ??
                Icon(
                  Icons.check,
                  color: style.submitIconColor ?? colorPalette.iconPrimary,
                  size: 24,
                ),
          );
        } else {
          return const SizedBox(height: 0, width: 0);
        }
      },
    );
  }

  /// The kit's default formatters with the @all label configured, or null
  /// (the rows build the plain defaults) when no @all prop is set.
  List<CometChatTextFormatter>? _mentionAllFormatters() {
    if (widget.mentionAllLabel == null && widget.mentionAllLabelId == null) {
      return null;
    }
    return [
      for (final formatter in MessageTemplateUtils.getDefaultTextFormatters())
        formatter is CometChatMentionsFormatter
            ? CometChatMentionsFormatter(
                mentionAllLabel: widget.mentionAllLabel,
                mentionAllLabelId: widget.mentionAllLabelId,
              )
            : formatter,
    ];
  }

  /// Whether the long-press menu offers Pin/Unpin for this row.
  ///
  /// Unpinned → Pin. Pinned by the logged-in user → Unpin. Pinned by an
  /// admin surface (`app_system`, or another uid) → neither: those pins are
  /// not user-removable, though the row still shows the pinned indicator.
  bool _canTogglePin(Conversation conversation) {
    if (widget.pinConversationOptionVisibility == false) return false;
    // Server feature flag (features.ux.conversations.pinned.enabled) —
    // absence means enabled, so older backends keep the option.
    if (!CometChat.isPinConversationEnabled()) return false;
    final pinnedBy = conversation.pinnedBy;
    if (pinnedBy == null) return true;
    return pinnedBy == CometChatUIKit.loggedInUser?.uid;
  }

  /// The long-press options the integrator supplied for [conversation].
  ///
  /// [CometChatConversations.setOptions] replaces the built-in Pin and Delete
  /// entries; [CometChatConversations.addOptions] goes in front of them.
  ({List<CometChatOption> options, bool keepDefaults}) _customOptions(
    Conversation conversation,
  ) {
    if (widget.setOptions != null) {
      return (
        options:
            widget.setOptions!(conversation, conversationsBloc, context) ??
            const <CometChatOption>[],
        keepDefaults: false,
      );
    }
    return (
      options:
          widget.addOptions?.call(conversation, conversationsBloc, context) ??
          const <CometChatOption>[],
      keepDefaults: true,
    );
  }

  /// Closes the menu, then runs the option's own action.
  void _handleCustomOption(CometChatOption option) {
    setState(() => _conversationShowingDeleteOverlay = null);
    option.onClick?.call();
  }

  /// The option's icon, drawn the way the kit's other option menus draw it.
  Widget? _customOptionIcon(CometChatOption option) {
    if (option.iconWidget != null) return option.iconWidget;
    final asset = option.icon;
    if (asset == null || asset.isEmpty) return null;
    return Image.asset(
      asset,
      package: option.packageName ?? UIConstants.packageName,
      color: option.iconTint ?? colorPalette.iconSecondary,
      height: 24,
      width: 24,
    );
  }

  /// Default long press handler that shows the action overlay on the tile
  void _handleDefaultLongPress(Conversation conversation) {
    final custom = _customOptions(conversation);
    final hasDefaults =
        custom.keepDefaults &&
        (widget.deleteConversationOptionVisibility == true ||
            _canTogglePin(conversation));
    if (custom.options.isEmpty && !hasDefaults) {
      return;
    }
    _menuOptions = (
      id: conversation.conversationId,
      options: custom.options,
      keepDefaults: custom.keepDefaults,
    );

    setState(() {
      // Toggle the delete overlay for this conversation
      if (_conversationShowingDeleteOverlay == conversation.conversationId) {
        _conversationShowingDeleteOverlay = null;
      } else {
        _conversationShowingDeleteOverlay = conversation.conversationId;
      }
    });
  }

  /// Intercepts item taps to dismiss delete overlay if one is showing
  void _handleItemTapWithDeleteDismiss(Conversation conversation) {
    if (_conversationShowingDeleteOverlay != null) {
      setState(() {
        _conversationShowingDeleteOverlay = null;
      });
      return;
    }
    if (widget.onItemTap != null) {
      widget.onItemTap!(conversation);
    }
  }

  /// Handle delete button tap from overlay
  void _handleDeleteFromOverlay(Conversation conversation) {
    setState(() {
      _conversationShowingDeleteOverlay = null;
    });
    _showDeleteConfirmationDialog(conversation);
  }

  /// Wraps a conversation list item with a delete overlay when long-pressed.
  Widget _wrapItemWithDeleteOverlay(
    BuildContext context,
    Conversation conversation,
    Widget child,
  ) {
    final isOpen =
        _conversationShowingDeleteOverlay == conversation.conversationId;

    final bool isPinned = conversation.pinnedBy != null;
    final bool showPinAction = _canTogglePin(conversation);
    final bool showDeleteAction =
        widget.deleteConversationOptionVisibility == true;
    final custom = _menuOptions?.id == conversation.conversationId
        ? _menuOptions
        : null;
    final bool keepDefaults = custom?.keepDefaults ?? true;

    return _ConversationContextMenu(
      open: isOpen,
      onDismissed: () {
        if (_conversationShowingDeleteOverlay == conversation.conversationId) {
          setState(() => _conversationShowingDeleteOverlay = null);
        }
      },
      colorPalette: colorPalette,
      typography: typography,
      entries: [
        for (final option in custom?.options ?? const <CometChatOption>[])
          (
            label: option.title ?? '',
            icon: null,
            iconWidget: _customOptionIcon(option),
            labelStyle: option.titleStyle,
            isDestructive: false,
            action: () => _handleCustomOption(option),
          ),
        if (keepDefaults && showPinAction)
          (
            label: isPinned
                ? cc.Translations.of(context).unpinButton
                : cc.Translations.of(context).pinButton,
            icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            iconWidget: null,
            labelStyle: null,
            isDestructive: false,
            action: () => _handlePinFromOverlay(conversation),
          ),
        if (keepDefaults && showDeleteAction)
          (
            label: cc.Translations.of(context).delete,
            icon: Icons.delete_outline,
            iconWidget: null,
            labelStyle: null,
            isDestructive: true,
            action: () => _handleDeleteFromOverlay(conversation),
          ),
      ],
      child: child,
    );
  }

  /// Handle the Pin/Unpin action from the long-press overlay: SDK call →
  /// stamp the conversation object → toast. No confirm dialog — the action
  /// is instantly reversible.
  Future<void> _handlePinFromOverlay(Conversation conversation) async {
    setState(() {
      _conversationShowingDeleteOverlay = null;
    });

    String? conversationWith;
    final counterpart = conversation.conversationWith;
    if (counterpart is User) {
      conversationWith = counterpart.uid;
    } else if (counterpart is Group) {
      conversationWith = counterpart.guid;
    }
    if (conversationWith == null || conversationWith.isEmpty) return;

    final bool pin = conversation.pinnedBy == null;
    final updated = pin
        ? await CometChat.pinConversation(
            conversationWith,
            conversation.conversationType,
            onError: (error) {
              if (mounted) {
                CometChatThreadToast.show(
                  context,
                  _conversationPinErrorText(error),
                );
              }
            },
          )
        : await CometChat.unpinConversation(
            conversationWith,
            conversation.conversationType,
            onError: (error) {
              if (mounted) {
                CometChatThreadToast.show(
                  context,
                  _conversationPinErrorText(error),
                );
              }
            },
          );

    if (updated != null && mounted) {
      // No local mutation: the SDK facade fans the pin out to
      // ConversationListener on success, and the bloc both restamps the row
      // and reorders it around the pinned shelf — one path for this device
      // and for echoes from the user's other devices.
      CometChatThreadToast.show(
        context,
        pin
            ? cc.Translations.of(context).conversationPinnedToast
            : cc.Translations.of(context).conversationUnpinnedToast,
      );
    }
  }

  /// Maps a conversation pin/unpin failure to its user-facing toast text.
  /// The cap error interpolates the server-supplied limit from the
  /// structured errorParams, falling back to the `/me` cap
  /// (`features.ux.conversations.pinned.limit`), then a static default.
  String _conversationPinErrorText(CometChatException error) {
    final limit = (error.errorParams?['limit'] as num?)?.toInt();
    switch (error.code) {
      case 'ERR_PINNED_CONVERSATIONS_LIMIT_EXCEEDED':
        return cc.Translations.of(context).conversationPinLimitReachedToast(
          limit ?? CometChat.getPinnedConversationsLimit() ?? 5,
        );
      case 'ERR_UNAUTHORIZED':
      case 'ERR_FORBIDDEN':
      case 'ERR_PERMISSION_DENIED':
        return cc.Translations.of(context).actionPermissionDenied;
      default:
        return cc.Translations.of(context).pinSaveFailed;
    }
  }

  /// Shows delete confirmation dialog
  void _showDeleteConfirmationDialog(Conversation conversation) {
    final confirmDialogStyle =
        CometChatThemeHelper.getTheme<CometChatConfirmDialogStyle>(
          context: context,
          defaultTheme: CometChatConfirmDialogStyle.of,
        ).merge(style.deleteConversationDialogStyle);

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
          color: confirmDialogStyle.iconColor ?? colorPalette.error,
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
      onCancel: (dialogContext) {
        Navigator.of(dialogContext).pop();
      },
      style: CometChatConfirmDialogStyle(
        iconColor: confirmDialogStyle.iconColor ?? colorPalette.error,
        backgroundColor: confirmDialogStyle.backgroundColor,
        shadow: confirmDialogStyle.shadow,
        iconBackgroundColor: confirmDialogStyle.iconBackgroundColor,
        borderRadius: confirmDialogStyle.borderRadius,
        border: confirmDialogStyle.border,
        cancelButtonBackground:
            confirmDialogStyle.cancelButtonBackground ??
            colorPalette.transparent,
        confirmButtonBackground:
            confirmDialogStyle.confirmButtonBackground ?? colorPalette.error,
        cancelButtonTextColor: confirmDialogStyle.cancelButtonTextColor,
        confirmButtonTextColor: confirmDialogStyle.confirmButtonTextColor,
        messageTextColor: confirmDialogStyle.messageTextColor,
        titleTextColor: confirmDialogStyle.titleTextColor,
        titleTextStyle:
            TextStyle(
                  color:
                      confirmDialogStyle.titleTextColor ??
                      colorPalette.textPrimary,
                  fontSize: typography.heading2?.medium?.fontSize,
                  fontWeight: typography.heading2?.medium?.fontWeight,
                  fontFamily: typography.heading2?.medium?.fontFamily,
                )
                .merge(confirmDialogStyle.titleTextStyle)
                .copyWith(color: confirmDialogStyle.titleTextColor),
        messageTextStyle:
            TextStyle(
                  color:
                      confirmDialogStyle.messageTextColor ??
                      colorPalette.textSecondary,
                  fontSize: typography.body?.regular?.fontSize,
                  fontWeight: typography.body?.regular?.fontWeight,
                  fontFamily: typography.body?.regular?.fontFamily,
                )
                .merge(confirmDialogStyle.messageTextStyle)
                .copyWith(color: confirmDialogStyle.messageTextColor),
        confirmButtonTextStyle:
            TextStyle(
                  color:
                      confirmDialogStyle.confirmButtonTextColor ??
                      colorPalette.white,
                  fontSize: typography.button?.medium?.fontSize,
                  fontWeight: typography.button?.medium?.fontWeight,
                  fontFamily: typography.button?.medium?.fontFamily,
                )
                .merge(confirmDialogStyle.confirmButtonTextStyle)
                .copyWith(color: confirmDialogStyle.confirmButtonTextColor),
        cancelButtonTextStyle:
            TextStyle(
                  color:
                      confirmDialogStyle.cancelButtonTextColor ??
                      colorPalette.textPrimary,
                  fontSize: typography.button?.medium?.fontSize,
                  fontWeight: typography.button?.medium?.fontWeight,
                  fontFamily: typography.button?.medium?.fontFamily,
                )
                .merge(confirmDialogStyle.cancelButtonTextStyle)
                .copyWith(color: confirmDialogStyle.cancelButtonTextColor),
      ),
      onConfirm: (dialogContext) {
        Navigator.of(dialogContext).pop();
        if (conversation.conversationId != null) {
          conversationsBloc.add(
            DeleteConversation(conversation.conversationId!),
          );
        }
      },
    ).show();
  }
}

/// Long-press context menu for a conversation row, rendered with the M3 menu
/// primitives ([MenuAnchor]/[MenuItemButton]) so its surface, elevation,
/// shape and ripple match the message header's ⋯ menu instead of a
/// hand-rolled popup.
///
/// The list owns which row is open, so [open] drives the menu controller
/// rather than a button press; [onDismissed] reports a tap-outside back so
/// the list can clear its own state.
class _ConversationContextMenu extends StatefulWidget {
  const _ConversationContextMenu({
    required this.open,
    required this.onDismissed,
    required this.entries,
    required this.colorPalette,
    required this.typography,
    required this.child,
  });

  final bool open;
  final VoidCallback onDismissed;
  final List<
    ({
      String label,
      IconData? icon,
      Widget? iconWidget,
      TextStyle? labelStyle,
      bool isDestructive,
      VoidCallback action,
    })
  >
  entries;
  final CometChatColorPalette colorPalette;
  final CometChatTypography typography;
  final Widget child;

  @override
  State<_ConversationContextMenu> createState() =>
      _ConversationContextMenuState();
}

/// Fixed so the anchor offset can cancel it exactly; wide enough for
/// "Unpin"/"Delete" with the 24dp icon and 12dp gutters.
const double _menuWidth = 180;

class _ConversationContextMenuState extends State<_ConversationContextMenu> {
  final MenuController _controller = MenuController();

  @override
  void didUpdateWidget(covariant _ConversationContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open == oldWidget.open) return;
    // Deferred a frame: open() needs the anchor laid out, and this runs from
    // the same build that introduced it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.open && !_controller.isOpen) {
        _controller.open();
      } else if (!widget.open && _controller.isOpen) {
        _controller.close();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.colorPalette;
    if (widget.entries.isEmpty) return widget.child;

    return MenuAnchor(
      controller: _controller,
      onClose: widget.onDismissed,
      // Alignment.topRight puts the menu's LEFT edge on the row's right
      // edge, which runs it off screen. Shifting left by the menu's own
      // width plus the gutter lands its right edge inside the row instead —
      // hence the fixed item width below, so the shift is exact.
      alignmentOffset: const Offset(-(_menuWidth + 16), -8),
      style: MenuStyle(
        alignment: Alignment.topRight,
        backgroundColor: WidgetStatePropertyAll(
          palette.background1 ?? palette.white,
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(2),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      builder: (context, controller, child) => child!,
      menuChildren: [
        for (final entry in widget.entries)
          MenuItemButton(
            style: MenuItemButton.styleFrom(
              minimumSize: const Size(_menuWidth, 48),
              maximumSize: const Size(_menuWidth, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: entry.isDestructive
                  ? palette.error
                  : palette.textPrimary,
              iconColor: entry.isDestructive
                  ? palette.error
                  : palette.iconSecondary,
              textStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
                fontFamily: widget.typography.body?.medium?.fontFamily,
              ),
            ),
            leadingIcon:
                entry.iconWidget ??
                Icon(
                  entry.icon,
                  size: 24,
                  color: entry.isDestructive
                      ? palette.error
                      : palette.iconSecondary,
                ),
            onPressed: entry.action,
            child: Text(
              entry.label,
              style: entry.labelStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      child: widget.child,
    );
  }
}
