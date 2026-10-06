import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../cometchat_chat_uikit.dart' as cc;
import '../../../shared_ui/src/clean_architecture/core/utils/thread_toast.dart';
import '../../../call_ui/src/call_buttons/cometchat_call_buttons.dart';
import '../../../src/calling_configuration_resolver.dart';
import 'package:intl/intl.dart';

/// [CometChatMessageHeader] is a widget which shows [user]/[group] details using [CometChatListItem]
/// if its being shown for an [User] then the name of the user will be in the [CometChatListItem.title] of [CometChatListItem] and their online/offline status will be in the [subtitleView]
/// if its being shown for an [Group] then the name of the group will be in the [CometChatListItem.title] of [CometChatListItem] and their member count will be in the [subtitleView]
///
/// ```dart
/// CometChatMessageHeader(
///   user: <user>,
///   messageHeaderStyle: MessageHeaderStyle(),
/// );
///
/// ```
/// For Group
/// ```dart
/// CometChatMessageHeader(
///   group: <group>,
///  messageHeaderStyle: MessageHeaderStyle(),
/// );
///
/// ```
class CometChatMessageHeader extends StatefulWidget
    implements PreferredSizeWidget {
  const CometChatMessageHeader({
    super.key,
    this.backButton,
    this.messageHeaderStyle,
    this.group,
    this.user,
    this.trailingView,
    this.listItemView,
    this.showBackButton = true,
    this.subtitleView,
    this.listItemStyle,
    this.onBack,
    this.threadSubscriptionVisibility = true,
    this.parentMessage,
    this.pinnedMessagesVisibility = true,
    this.onPinnedMessageItemTap,
    this.pinnedMessagesStyle,
    this.onInfoTap,
    this.onSearchTap,
    this.onHeaderTap,
    this.onPinnedMessagesTap,
    this.avatarHeight,
    this.avatarWidth,
    this.height,
    this.padding,
    this.hideVideoCallButton,
    this.hideVoiceCallButton,
    this.titleView,
    this.leadingStateView,
    this.auxiliaryButtonView,
    this.usersStatusVisibility = true,
    this.dateTimeFormatterCallback,
    this.hideNewChatButton,
    this.hideChatHistoryButton,
    this.chatHistoryButtonClick,
    this.newChatButtonClick,
    this.newChatIcon,
    this.chatHistoryIcon,
    this.messageHeaderBloc,
  }) : assert(
         user != null || group != null,
         "One of user or group should be passed",
       ),
       assert(
         user == null || group == null,
         "Only one of user or group should be passed",
       );

  ///[messageHeaderBloc] Optional external MessageHeaderBloc instance.
  ///If provided, it is used instead of creating one internally and the
  ///widget does not close it on dispose. Mirrors
  ///[CometChatConversations.conversationsBloc].
  final MessageHeaderBloc? messageHeaderBloc;

  /// [backButton] used to set back button widget
  final WidgetBuilder? backButton;

  /// [subtitleView] to set subtitle view
  final Widget? Function(Group? group, User? user, BuildContext context)?
  subtitleView;

  /// set [User] object, one is mandatory either [user] or [group]
  final User? user;

  /// set [Group] object, one is mandatory either [user] or [group]
  final Group? group;

  /// [listItemView] set custom view for listItem
  final Widget Function(Group? group, User? user, BuildContext context)?
  listItemView;

  /// [CometChatMessageHeaderStyle] set styling props for message header
  final CometChatMessageHeaderStyle? messageHeaderStyle;

  /// [showBackButton] toggle visibility for back button
  final bool? showBackButton;

  /// [listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  /// [trailingView] set appbar options
  final List<Widget>? Function(User? user, Group? group, BuildContext context)?
  trailingView;

  /// [onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  /// [threadSubscriptionVisibility] controls the thread mute/unmute
  /// notification bell rendered in the header's trailing area (pinned right,
  /// sized to the back icon) when [parentMessage] is set. Defaults to
  /// visible; the bell additionally requires the thread-subscription feature
  /// gate ([UIKitSettings.enableThreadSubscription]) to be on.
  ///
  /// Naming note: the cross-platform design doc (§6.2) defines this flag on
  /// each platform's *threaded-header* component, because that is where the
  /// other four kits render the control. On Flutter the landed design places
  /// the bell in the message header's top bar instead, so the same flag name
  /// lives here — one concept, one name, per-platform placement.
  final bool? threadSubscriptionVisibility;

  /// [parentMessage] the thread's root message the notification bell acts
  /// on. The bell renders only when this is set (and
  /// [threadSubscriptionVisibility] is not false).
  final BaseMessage? parentMessage;

  /// [pinnedMessagesVisibility] controls the pinned-messages entry in the
  /// header's overflow (⋯) menu, which opens the conversation's
  /// [CometChatPinnedMessages] as a pushed screen. Defaults to visible; the
  /// entry additionally requires the server Pin feature flag
  /// ([CometChat.isPinMessageEnabled]) and renders only on a conversation
  /// header (never when [parentMessage] puts the header in thread mode).
  final bool? pinnedMessagesVisibility;

  /// [onPinnedMessageItemTap] forwarded to the pinned-messages screen — fires
  /// when a pinned row is tapped (after that screen pops) so the host screen
  /// can jump its message list to the tapped message.
  final Function(BaseMessage message)? onPinnedMessageItemTap;

  /// [pinnedMessagesStyle] styling for the pinned-messages screen opened from
  /// the header's overflow (⋯) menu.
  final CometChatPinnedMessagesStyle? pinnedMessagesStyle;

  /// [onInfoTap] when set, the header's ⋯ overflow menu carries a
  /// "Group Info"/"User Info" entry that invokes it (the host app owns the
  /// info screen).
  final VoidCallback? onInfoTap;

  /// [onSearchTap] when set, the header's ⋯ overflow menu carries a
  /// "Search" entry that invokes it.
  final VoidCallback? onSearchTap;

  /// [onHeaderTap] fires when the avatar/name/subtitle area is tapped, or
  /// the [listItemView] that replaces it — typically wired to open the info
  /// screen.
  final VoidCallback? onHeaderTap;

  /// [onPinnedMessagesTap] when set, the ⋯ menu's pinned-messages entry
  /// invokes this instead of pushing [CometChatPinnedMessages] itself — so a
  /// host with its own layout (a desktop side panel, say) can decide where
  /// the list appears. [onPinnedMessageItemTap] still forwards row taps when
  /// the kit does the presenting.
  final VoidCallback? onPinnedMessagesTap;

  /// [avatarHeight] set height for avatar
  final double? avatarHeight;

  /// [avatarWidth] set width for avatar
  final double? avatarWidth;

  /// [height] set height for message header
  final double? height;

  /// [padding] set padding for message header
  final EdgeInsetsGeometry? padding;

  /// [hideVideoCallButton] is a [bool] that can be used to hide/display video call button
  final bool? hideVideoCallButton;

  /// [hideVoiceCallButton] is a [bool] that can be used to hide/display voice call button
  final bool? hideVoiceCallButton;

  /// [leadingStateView] to set leading View
  final Widget? Function(Group? group, User? user, BuildContext context)?
  leadingStateView;

  /// [titleView] to set to set titleView view
  final Widget? Function(Group? group, User? user, BuildContext context)?
  titleView;

  /// [auxiliaryButtonView] to set auxiliary view
  final Widget? Function(Group? group, User? user, BuildContext context)?
  auxiliaryButtonView;

  /// [usersStatusVisibility] controls visibility of status indicator shown if a user is online
  final bool? usersStatusVisibility;

  /// [dateTimeFormatterCallback] is a callback that can be used to format the date and time
  final DateTimeFormatterCallback? dateTimeFormatterCallback;

  /// [hideChatHistoryButton] is a [bool] that can be used to hide/display chat history button
  final bool? hideChatHistoryButton;

  /// [hideNewChatButton] is a [bool] that can be used to hide/display chat button button
  final bool? hideNewChatButton;

  /// [newChatButtonClick] callback triggered on new chat button click
  final VoidCallback? newChatButtonClick;

  /// [chatHistoryButtonClick] callback triggered on chat history button click
  final VoidCallback? chatHistoryButtonClick;

  /// [newChatIcon] provides new chat icon
  final IconData? newChatIcon;

  /// [chatHistoryIcon] provides chat history icon
  final IconData? chatHistoryIcon;

  @override
  State<CometChatMessageHeader> createState() => _CometChatMessageHeaderState();

  @override
  Size get preferredSize {
    return Size.fromHeight(height ?? 65);
  }
}

class _CometChatMessageHeaderState extends State<CometChatMessageHeader> {
  /// Whether the thread notification bell should render: a root message to
  /// act on ([CometChatMessageHeader.parentMessage]), visibility not turned
  /// off, and the thread-subscription feature gate on.
  bool get _showThreadBell =>
      widget.parentMessage != null &&
      widget.threadSubscriptionVisibility != false &&
      CometChatUIKit.authenticationSettings?.enableThreadSubscription == true;

  /// Whether the overflow menu's pinned-messages entry should render: a
  /// conversation header (not a thread header), visibility not turned off,
  /// and the server Pin feature flag enabled.
  bool get _showPinnedMessagesButton =>
      widget.parentMessage == null &&
      widget.pinnedMessagesVisibility != false &&
      CometChat.isPinMessageEnabled();

  void _openPinnedMessages() {
    // A host that owns its own layout (e.g. a desktop side panel) can take
    // over the presentation; otherwise the kit pushes the screen itself.
    final opener = widget.onPinnedMessagesTap;
    if (opener != null) {
      opener();
      return;
    }
    CometChatPinnedMessages.show(
      context,
      user: widget.user,
      group: widget.group,
      onItemTap: widget.onPinnedMessageItemTap,
      style: widget.pinnedMessagesStyle,
    );
  }

  /// Whether the ⋯ overflow menu renders: conversation headers only.
  bool get _showOverflowMenu =>
      widget.parentMessage == null &&
      (_showPinnedMessagesButton ||
          widget.onInfoTap != null ||
          widget.onSearchTap != null);

  /// One overflow entry: label + icon + action + whether it is destructive.
  ///
  /// Menu order: search, pinned messages, info. No entry is destructive
  /// today — the delete-chat entry was removed — but the flag and its
  /// styling are kept for the next one that is.
  List<({String label, IconData icon, VoidCallback action, bool isDestructive})>
  get _overflowEntries {
    final translations = cc.Translations.of(context);
    return [
      if (widget.onSearchTap != null)
        (
          label: translations.search,
          icon: Icons.search,
          action: widget.onSearchTap!,
          isDestructive: false,
        ),
      if (_showPinnedMessagesButton)
        (
          label: translations.pinnedMessagesTitle,
          icon: Icons.push_pin_outlined,
          action: _openPinnedMessages,
          isDestructive: false,
        ),
      if (widget.onInfoTap != null)
        (
          label: widget.group != null
              ? translations.groupInfo
              : translations.userInfo,
          icon: Icons.info_outline,
          action: widget.onInfoTap!,
          isDestructive: false,
        ),
    ];
  }

  /// Builds the native Material 3 dropdown for the ⋯ button.
  ///
  /// Uses [MenuAnchor]/[MenuItemButton] — the M3 menu primitives — so the
  /// surface, elevation, shape, ripple and leading-icon layout come from the
  /// theme instead of being hand-rolled. Same presentation on every platform
  /// (Flutter's Cupertino library has no anchored menu widget).
  Widget _buildOverflowMenu(
    CometChatMessageHeaderStyle headerStyle,
    CometChatColorPalette colorPalette,
  ) {
    final entries = _overflowEntries;
    // M3 menu spec, expressed in kit tokens: container is a surface at
    // elevation 2 with a 4dp corner and 8dp vertical padding; items are 48dp
    // tall with a 12dp gutter, label-large text (14/500, +0.1 tracking) in
    // the primary text colour, and a 24dp leading icon in the secondary icon
    // colour. Spelled out rather than left to ThemeData so the menu matches
    // the kit palette in apps that never configured a Material theme.
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          colorPalette.background1 ?? colorPalette.white,
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(2),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        visualDensity: VisualDensity.standard,
      ),
      builder: (context, controller, child) => IconButton(
        tooltip: Translations.of(context).more,
        iconSize: 26,
        icon: Icon(
          Icons.more_vert,
          color:
              headerStyle.menuIconColor ??
              headerStyle.backIconColor ??
              colorPalette.iconPrimary,
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        for (final entry in entries)
          MenuItemButton(
            style: MenuItemButton.styleFrom(
              minimumSize: const Size(112, 48),
              maximumSize: const Size(280, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: entry.isDestructive
                  ? colorPalette.error
                  : colorPalette.textPrimary,
              iconColor: entry.isDestructive
                  ? colorPalette.error
                  : colorPalette.iconSecondary,
              textStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
                fontFamily: typography.body?.medium?.fontFamily,
              ),
            ),
            leadingIcon: Icon(
              entry.icon,
              size: 24,
              color: entry.isDestructive
                  ? colorPalette.error
                  : colorPalette.iconSecondary,
            ),
            onPressed: entry.action,
            child: Text(entry.label),
          ),
      ],
    );
  }

  late MessageHeaderBloc _bloc;
  bool _isExternalBloc = false;
  late CometChatMessageHeaderStyle headerStyle;
  late CometChatColorPalette colorPalette;
  late CometChatTypography typography;
  late CometChatSpacing spacing;
  late CometChatStatusIndicatorStyle statusIndicatorStyle;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;
  double _cachedWidth = 300; // Cached to avoid MediaQuery in build()

  @override
  void initState() {
    super.initState();
    if (widget.messageHeaderBloc != null) {
      _bloc = widget.messageHeaderBloc!;
      _isExternalBloc = true;
    } else {
      _bloc = MessageHeaderBloc(
        usersStatusVisibility: widget.usersStatusVisibility ?? true,
      );
      _isExternalBloc = false;
    }

    // Set initial user or group
    if (widget.user != null) {
      _bloc.add(SetUser(widget.user!));
    } else if (widget.group != null) {
      _bloc.add(SetGroup(widget.group!));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize theme once to avoid expensive lookups during keyboard animation
    // But re-initialize when brightness changes (dark mode toggle)
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (_themeInitialized && !brightnessChanged) return;
    _cachedBrightness = currentBrightness;
    _themeInitialized = true;

    // Cache width to avoid MediaQuery in build()
    _cachedWidth = MediaQuery.sizeOf(context).width;

    headerStyle = CometChatThemeHelper.getTheme<CometChatMessageHeaderStyle>(
      context: context,
      defaultTheme: CometChatMessageHeaderStyle.of,
    ).merge(widget.messageHeaderStyle);
    statusIndicatorStyle =
        CometChatThemeHelper.getTheme<CometChatStatusIndicatorStyle>(
          context: context,
          defaultTheme: CometChatStatusIndicatorStyle.of,
        ).merge(headerStyle.statusIndicatorStyle);
    typography = CometChatThemeHelper.getTypography(context);
    colorPalette = CometChatThemeHelper.getColorPalette(context);
    spacing = CometChatThemeHelper.getSpacing(context);
  }

  @override
  void didUpdateWidget(CometChatMessageHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update bloc if user/group changed
    if (widget.user != oldWidget.user && widget.user != null) {
      _bloc.add(SetUser(widget.user!));
    } else if (widget.group != oldWidget.group && widget.group != null) {
      _bloc.add(SetGroup(widget.group!));
    }
  }

  @override
  void dispose() {
    if (!_isExternalBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: SafeArea(
        child: Container(
          height: widget.height,
          width: _cachedWidth,
          padding:
              widget.padding ?? EdgeInsets.only(left: spacing.padding4 ?? 0),
          decoration: BoxDecoration(
            color: headerStyle.backgroundColor ?? colorPalette.background1,
            border: headerStyle.border,
            borderRadius: headerStyle.borderRadius ?? BorderRadius.circular(0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _getBackButtonView(context, headerStyle, colorPalette),
              // When the thread bell occupies the trailing slot beside a
              // custom listItemView, the body must EXPAND so the bell pins to
              // the right edge (a loose Flexible would leave it hugging the
              // title on wide layouts).
              if (_showThreadBell && widget.listItemView != null)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: spacing.padding4 ?? 0),
                    child: _getBody(context),
                  ),
                )
              else
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(left: spacing.padding4 ?? 0),
                    child: _getBody(context),
                  ),
                ),
              // A custom listItemView replaces the whole list item including
              // its tail, so the thread notification bell gets its trailing
              // slot here in that case — pinned to the right edge.
              if (_showThreadBell && widget.listItemView != null)
                Padding(
                  padding: EdgeInsets.only(right: spacing.padding2 ?? 0),
                  child: _ThreadNotificationBell(
                    parentMessage: widget.parentMessage!,
                  ),
                ),
              // ...and any host-supplied trailing controls sit AFTER it, so a
              // close/dismiss affordance lands beside the bell rather than
              // replacing it. (On the default list-item path trailingView is
              // consumed by the list item itself — see _getTrailingView.)
              if (widget.listItemView != null && widget.trailingView != null)
                ...?widget.trailingView!(widget.user, widget.group, context),
            ],
          ),
        ),
      ),
    );
  }

  // Back Button view
  Widget _getBackButtonView(
    BuildContext context,
    CometChatMessageHeaderStyle style,
    CometChatColorPalette colorPalette,
  ) {
    if (widget.showBackButton == true) {
      if (widget.backButton != null) {
        return widget.backButton!(context);
      }
      Widget leading;
      leading = Semantics(
        button: true,
        label: cc.Translations.of(context).back,
        child: GestureDetector(
          onTap:
              widget.onBack ??
              () {
                Navigator.pop(context);
              },
          child:
              style.backIcon ??
              Image.asset(
                AssetConstants.back,
                excludeFromSemantics: true,
                package: UIConstants.packageName,
                color: style.backIconColor ?? colorPalette.iconPrimary,
              ),
        ),
      );

      return leading;
    } else {
      return const SizedBox(height: 0, width: 0);
    }
  }

  // Body / Title view using BLoC
  Widget _getBody(BuildContext context) {
    return BlocBuilder<MessageHeaderBloc, MessageHeaderState>(
      builder: (context, state) {
        // Handle initial/loading state - use widget's user/group directly
        // until the BLoC state is populated
        if (state.status == MessageHeaderStatus.initial ||
            state.status == MessageHeaderStatus.loading) {
          // Use widget's user/group as fallback during initial load
          if (widget.user == null && widget.group == null) {
            return const SizedBox.shrink();
          }
          // Create a temporary state with widget data
          final tempState = MessageHeaderState(
            status: MessageHeaderStatus.loaded,
            user: widget.user,
            group: widget.group,
            memberCount: widget.group?.membersCount ?? 0,
          );
          return _getListItem(context, tempState);
        }
        return _getListItem(context, state);
      },
    );
  }

  // typing indicator view
  Widget _getTypingIndicator(
    BuildContext context,
    MessageHeaderState state,
    TextStyle? typingIndicatorTextStyle,
    CometChatTypography typography,
    Color? color,
  ) {
    String text;
    if (state.user != null) {
      text = cc.Translations.of(context).typing;
    } else {
      text =
          "${state.typingUser?.name ?? ''}: ${cc.Translations.of(context).typing}";
    }
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: typography.caption1?.regular?.fontSize,
        color: color,
        fontWeight: typography.caption1?.regular?.fontWeight,
      ).merge(typingIndicatorTextStyle),
    );
  }

  // subtitle view
  Widget? _getSubtitleView(
    BuildContext context,
    MessageHeaderState state,
    CometChatMessageHeaderStyle style,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
  ) {
    Widget? subtitle;
    final subtitleStyle = TextStyle(
      color:
          style.subtitleTextColor ??
          style.subtitleTextStyle?.color ??
          colorPalette.textSecondary,
      fontSize:
          style.subtitleTextStyle?.fontSize ??
          typography.caption1?.regular?.fontSize,
      fontFamily:
          style.subtitleTextStyle?.fontFamily ??
          typography.caption1?.regular?.fontFamily,
      fontWeight:
          style.subtitleTextStyle?.fontWeight ??
          typography.caption1?.regular?.fontWeight,
    );

    if (state.isTyping && state.userIsNotBlocked) {
      subtitle = _getTypingIndicator(
        context,
        state,
        style.typingIndicatorTextStyle,
        typography,
        colorPalette.primary,
      );
    } else if (widget.subtitleView != null) {
      subtitle = widget.subtitleView!(state.group, state.user, context);
    } else if (state.user != null) {
      if (widget.usersStatusVisibility == true && state.userIsNotBlocked) {
        final statusText = state.isUserOnline
            ? cc.Translations.of(context).online
            : _getUserActivityStatus(context, state);
        // Wrap in LayoutBuilder so the marquee is constrained to the
        // available width and does not overflow into trailing widgets.
        subtitle = LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: CometChatMarquee(
                velocity: 30,
                text: statusText,
                style: subtitleStyle,
              ),
            );
          },
        );
      } else {
        subtitle = null;
      }
    } else {
      subtitle = Text(
        '${state.memberCount} ${state.memberCount == 1 ? cc.Translations.of(context).member : cc.Translations.of(context).members}',
        style: subtitleStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return subtitle;
  }

  // title view
  Widget? _getTitleView(BuildContext context, MessageHeaderState state) {
    if (widget.titleView != null) {
      return widget.titleView!(state.group, state.user, context);
    }
    return null;
  }

  // leading view
  Widget? _getLeadingView(BuildContext context, MessageHeaderState state) {
    if (widget.leadingStateView != null) {
      return widget.leadingStateView!(state.group, state.user, context);
    }
    return null;
  }

  // auxiliary header view
  Widget? _getAuxiliaryButtonView(
    BuildContext context,
    MessageHeaderState state,
    CometChatMessageHeaderStyle style,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    if (widget.auxiliaryButtonView != null) {
      return widget.auxiliaryButtonView!(state.group, state.user, context);
    } else {
      if (state.isUserAgentic) {
        return null;
      }
      return _buildCallButtons(style);
    }
  }

  // trailing view
  List<Widget>? _getTrailingView(
    BuildContext context,
    MessageHeaderState state,
    CometChatMessageHeaderStyle style,
  ) {
    if (widget.trailingView != null) {
      return widget.trailingView!(state.user, state.group, context);
    }
    return null;
  }

  Widget _getListItem(BuildContext context, MessageHeaderState state) {
    if (widget.listItemView != null) {
      // The custom view replaces the item, not the header's tap: it gets the
      // same tap target the default item does (its own controls win first).
      return GestureDetector(
        onTap: widget.onHeaderTap,
        child: widget.listItemView!(widget.group, widget.user, context),
      );
    }

    // Safety check - if both user and group are null, show empty widget
    if (state.user == null && state.group == null) {
      return const SizedBox.shrink();
    }

    String? avatarName;
    String? avatarUrl;
    String? title;
    Color? statusIndicatorColor;
    Widget? icon;
    Widget? leadingStateView;
    Widget? titleView;
    Widget? subtitleView;
    Widget? auxiliaryHeaderMenu;
    Widget? tailView;

    if (state.user != null) {
      avatarName = state.user?.name;
      avatarUrl = state.user?.avatar;
      title = state.user?.name;
    } else {
      avatarName = state.group?.name;
      avatarUrl = state.group?.icon;
      title = state.group?.name;
    }

    StatusIndicatorUtils util =
        StatusIndicatorUtils.getStatusIndicatorFromParams(
          context: context,
          user: state.user,
          group: state.group,
          privateGroupIcon: headerStyle.privateGroupBadgeIcon,
          protectedGroupIcon: headerStyle.passwordProtectedGroupBadgeIcon,
          onlineStatusIndicatorColor:
              statusIndicatorStyle.backgroundColor ??
              headerStyle.onlineStatusColor ??
              colorPalette.success,
          usersStatusVisibility: !_hideUserPresence(state),
          // Without this the helper never takes its group branch, so the
          // private/protected badge icons and their backgrounds were inert.
          groupTypeVisibility: true,
          privateGroupIconBackground: headerStyle.privateGroupBadgeIconColor,
          protectedGroupIconBackground:
              headerStyle.passwordProtectedGroupBadgeIconColor,
        );

    statusIndicatorColor = util.statusIndicatorColor;
    List<Widget>? tailWidgetList = [];
    icon = util.icon;
    leadingStateView = _getLeadingView(context, state);
    titleView = _getTitleView(context, state);
    subtitleView = _getSubtitleView(
      context,
      state,
      headerStyle,
      colorPalette,
      typography,
    );

    auxiliaryHeaderMenu = _getAuxiliaryButtonView(
      context,
      state,
      headerStyle,
      colorPalette,
      typography,
      spacing,
    );
    if (auxiliaryHeaderMenu != null) {
      tailWidgetList.add(auxiliaryHeaderMenu);
    }

    if (_showThreadBell) {
      tailWidgetList.add(
        _ThreadNotificationBell(parentMessage: widget.parentMessage!),
      );
    }

    if (widget.trailingView != null) {
      var temp = _getTrailingView(context, state, headerStyle);

      if (temp != null) {
        tailWidgetList.addAll(temp);
      }
    }

    if (state.isUserAgentic) {
      tailWidgetList.addAll(_getAgenticButtons());
    }

    // ⋯ overflow menu — rightmost: View pinned messages, Pin conversation,
    // Group/User info, Search. Platform-adaptive presentation.
    if (_showOverflowMenu) {
      tailWidgetList.add(_buildOverflowMenu(headerStyle, colorPalette));
    }

    if (tailWidgetList.isNotEmpty) {
      tailView = Padding(
        padding: EdgeInsets.only(
          left: spacing.padding3 ?? 0,
          top: spacing.padding2 ?? 0,
          bottom: spacing.padding2 ?? 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: tailWidgetList,
        ),
      );
    }

    return GestureDetector(
      // Tapping the avatar/name/subtitle area opens the info screen (tail
      // buttons claim their own taps first).
      onTap: widget.onHeaderTap,
      child: CometChatListItem(
        avatarName: avatarName,
        avatarURL: avatarUrl,
        avatarWidth: widget.avatarWidth ?? 40,
        avatarHeight: widget.avatarHeight ?? 40,
        title: title,
        subtitleView: subtitleView,
        titlePadding: EdgeInsets.only(left: spacing.padding2 ?? 0),
        avatarStyle: CometChatAvatarStyle(
          backgroundColor: widget.group != null
              ? headerStyle.groupIconBackgroundColor
              : null,
        ).merge(headerStyle.avatarStyle),
        statusIndicatorColor: statusIndicatorColor,
        statusIndicatorIcon: icon,
        statusIndicatorStyle: CometChatStatusIndicatorStyle(
          border: Border.all(
            width: spacing.spacing ?? 0,
            color: colorPalette.background1 ?? Colors.white,
          ),
          backgroundColor: colorPalette.success,
        ).merge(statusIndicatorStyle),
        hideSeparator: true,
        tailView: tailView,
        titleView: titleView,
        leadingStateView: leadingStateView,
        style:
            widget.listItemStyle ??
            ListItemStyle(
              background: Colors.transparent,
              height: 56,
              titleStyle: TextStyle(
                fontSize:
                    headerStyle.titleTextStyle?.fontSize ??
                    typography.heading4?.medium?.fontSize,
                fontWeight:
                    headerStyle.titleTextStyle?.fontWeight ??
                    typography.heading4?.medium?.fontWeight,
                fontFamily:
                    headerStyle.titleTextStyle?.fontFamily ??
                    typography.heading4?.medium?.fontFamily,
                color:
                    headerStyle.titleTextColor ??
                    headerStyle.titleTextStyle?.color ??
                    colorPalette.textPrimary,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      ),
    );
  }

  Widget _buildTightIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
    EdgeInsetsGeometry? padding,
  }) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: SizedBox(
        width: 30,
        height: 30,
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }

  List<Widget> _getAgenticButtons() {
    return [
      if (!(widget.hideNewChatButton ?? false))
        _buildTightIconButton(
          color:
              headerStyle.newChatIconColor ??
              colorPalette.iconSecondary ??
              Colors.transparent,
          icon: widget.newChatIcon ?? Icons.add,
          tooltip: Translations.of(context).newChat,
          onPressed:
              widget.newChatButtonClick ??
              () {
                FocusManager.instance.primaryFocus?.unfocus();
              },
          padding: EdgeInsets.only(right: spacing.padding2 ?? 0),
        ),
      if (!(widget.hideChatHistoryButton ?? false))
        _buildTightIconButton(
          color:
              headerStyle.chatHistoryIconColor ??
              colorPalette.iconSecondary ??
              Colors.transparent,
          icon: widget.chatHistoryIcon ?? Icons.history,
          tooltip: Translations.of(context).chatHistory,
          onPressed:
              widget.chatHistoryButtonClick ??
              () {
                FocusManager.instance.primaryFocus?.unfocus();
              },
          padding: EdgeInsets.only(right: spacing.padding4 ?? 0),
        ),
    ];
  }

  bool _hideUserPresence(MessageHeaderState state) {
    return state.user != null &&
        (widget.usersStatusVisibility == false || !state.userIsNotBlocked);
  }

  Widget? _buildCallButtons(CometChatMessageHeaderStyle style) {
    if (CometChatUIKit.authenticationSettings?.enableCalls != true) {
      return null;
    }

    final callingConfig = CallingConfigurationResolver.resolved;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CometChatCallButtons(
          user: widget.user,
          group: widget.group,
          callButtonsStyle:
              (callingConfig?.callButtonsConfiguration?.callButtonsStyle ??
                      const CometChatCallButtonsStyle())
                  .merge(style.callButtonsStyle),
          onError: callingConfig?.callButtonsConfiguration?.onError,
          hideVoiceCallButton:
              widget.hideVoiceCallButton ??
              callingConfig?.callButtonsConfiguration?.hideVoiceCallButton,
          hideVideoCallButton:
              widget.hideVideoCallButton ??
              callingConfig?.callButtonsConfiguration?.hideVideoCallButton,
          voiceCallIcon: callingConfig?.callButtonsConfiguration?.voiceCallIcon,
          videoCallIcon: callingConfig?.callButtonsConfiguration?.videoCallIcon,
          outgoingCallConfiguration:
              callingConfig
                  ?.callButtonsConfiguration
                  ?.outgoingCallConfiguration ??
              callingConfig?.outgoingCallConfiguration,
          callSettingsBuilder:
              callingConfig?.callButtonsConfiguration?.callSettingsBuilder,
        ),
      ],
    );
  }

  String _getUserActivityStatus(
    BuildContext context,
    MessageHeaderState state,
  ) {
    if (state.user == null) {
      return "";
    }
    if (state.user?.lastActiveAt == null) {
      return cc.Translations.of(context).offline;
    }
    return _getLastSeenText(state.user!.lastActiveAt!, context);
  }

  String _getLastSeenText(DateTime lastActiveAt, BuildContext context) {
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(lastActiveAt);

    if (difference.inMinutes <= 1) {
      return _getMinute(lastActiveAt, context);
    } else if (difference.inMinutes < 60) {
      return _getMinutes(difference, lastActiveAt, context);
    } else if (difference.inHours < 2) {
      return _getHour(difference, lastActiveAt, context);
    } else if (difference.inHours < 24) {
      int diffInHours = difference.inHours;
      return _getHours(difference, diffInHours, lastActiveAt, context);
    } else {
      return _getFormattedDateWithTime(lastActiveAt, context);
    }
  }

  String _getMinute(DateTime date, BuildContext context) {
    if (widget.dateTimeFormatterCallback?.minute(date.millisecondsSinceEpoch) !=
        null) {
      return widget.dateTimeFormatterCallback?.minute(
            date.millisecondsSinceEpoch,
          ) ??
          "${cc.Translations.of(context).lastSeen} 1 ${cc.Translations.of(context).minuteAgo}";
    } else {
      return CometChatUIKit.authenticationSettings?.dateTimeFormatterCallback
              ?.minute(date.millisecondsSinceEpoch) ??
          "${cc.Translations.of(context).lastSeen} 1 ${cc.Translations.of(context).minuteAgo}";
    }
  }

  String _getMinutes(Duration difference, DateTime date, BuildContext context) {
    int diffInMinutes = difference.inMinutes;
    if (widget.dateTimeFormatterCallback?.minutes(
          diffInMinutes,
          date.millisecondsSinceEpoch,
        ) !=
        null) {
      return widget.dateTimeFormatterCallback?.minutes(
            diffInMinutes,
            date.millisecondsSinceEpoch,
          ) ??
          "${cc.Translations.of(context).lastSeen} ${difference.inMinutes} ${cc.Translations.of(context).minutesAgo}";
    } else {
      return CometChatUIKit.authenticationSettings?.dateTimeFormatterCallback
              ?.minutes(diffInMinutes, date.millisecondsSinceEpoch) ??
          "${cc.Translations.of(context).lastSeen} ${difference.inMinutes} ${cc.Translations.of(context).minutesAgo}";
    }
  }

  String _getHour(Duration difference, DateTime date, BuildContext context) {
    if (widget.dateTimeFormatterCallback?.hour(date.millisecondsSinceEpoch) !=
        null) {
      return widget.dateTimeFormatterCallback?.hour(
            date.millisecondsSinceEpoch,
          ) ??
          "${cc.Translations.of(context).lastSeen} ${difference.inHours} ${cc.Translations.of(context).hourAgo}";
    } else {
      return CometChatUIKit.authenticationSettings?.dateTimeFormatterCallback
              ?.hour(date.millisecondsSinceEpoch) ??
          "${cc.Translations.of(context).lastSeen} ${difference.inHours} ${cc.Translations.of(context).hourAgo}";
    }
  }

  String _getHours(
    Duration difference,
    int diffInHours,
    DateTime date,
    BuildContext context,
  ) {
    if (widget.dateTimeFormatterCallback?.hours(
          diffInHours,
          date.millisecondsSinceEpoch,
        ) !=
        null) {
      return widget.dateTimeFormatterCallback?.hours(
            diffInHours,
            date.millisecondsSinceEpoch,
          ) ??
          "${cc.Translations.of(context).lastSeen} ${difference.inHours} ${cc.Translations.of(context).hoursAgo}";
    } else {
      return CometChatUIKit.authenticationSettings?.dateTimeFormatterCallback
              ?.hours(diffInHours, date.millisecondsSinceEpoch) ??
          "${cc.Translations.of(context).lastSeen} ${difference.inHours} ${cc.Translations.of(context).hoursAgo}";
    }
  }

  String _getFormattedDateWithTime(
    DateTime lastActiveAt,
    BuildContext context,
  ) {
    final now = DateTime.now();
    final isSameYear = now.year == lastActiveAt.year;

    String datePattern = isSameYear ? 'dd MMM' : 'dd MMM yyyy';
    String formattedDate = DateFormat(datePattern).format(lastActiveAt);
    String formattedTime = DateFormat.jm().format(lastActiveAt);

    if (widget.dateTimeFormatterCallback?.otherDays(
          lastActiveAt.millisecondsSinceEpoch,
        ) !=
        null) {
      return widget.dateTimeFormatterCallback?.otherDays(
            lastActiveAt.millisecondsSinceEpoch,
          ) ??
          "${cc.Translations.of(context).lastSeen} $formattedDate ${cc.Translations.of(context).at} $formattedTime";
    } else {
      return CometChatUIKit.authenticationSettings?.dateTimeFormatterCallback
              ?.otherDays(lastActiveAt.millisecondsSinceEpoch) ??
          "${cc.Translations.of(context).lastSeen} $formattedDate ${cc.Translations.of(context).at} $formattedTime";
    }
  }
}

/// Thread mute/unmute notification bell rendered by [CometChatMessageHeader]
/// when [CometChatMessageHeader.showThreadNotificationButton] is on.
///
/// State: the root message's [BaseMessage.threadSubscribed] is the truth
/// (stateless redesign — the SDK keeps no cache); kept in sync with every
/// other surface via the kit event bus (`ccThreadSubscriptionChanged`). Tap =
/// optimistic flip + idempotent subscribe/unsubscribe, revert + failure
/// toast on error. Private to the header — not public kit API.
class _ThreadNotificationBell extends StatefulWidget {
  const _ThreadNotificationBell({required this.parentMessage});

  final BaseMessage parentMessage;

  @override
  State<_ThreadNotificationBell> createState() =>
      _ThreadNotificationBellState();
}

class _ThreadNotificationBellState extends State<_ThreadNotificationBell>
    with CometChatMessageEventListener {
  late bool _subscribed;
  bool _inFlight = false;
  late final String _listenerId;

  @override
  void initState() {
    super.initState();
    _subscribed = widget.parentMessage.threadSubscribed;
    _listenerId =
        'message_header_thread_bell_${DateTime.now().millisecondsSinceEpoch}';
    CometChatMessageEvents.addMessagesListener(_listenerId, this);
  }

  @override
  void didUpdateWidget(covariant _ThreadNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new root is a different thread: show its state, not the last one's.
    if (widget.parentMessage.id != oldWidget.parentMessage.id) {
      _subscribed = widget.parentMessage.threadSubscribed;
    }
  }

  @override
  void dispose() {
    CometChatMessageEvents.removeMessagesListener(_listenerId);
    super.dispose();
  }

  @override
  void ccThreadSubscriptionChanged(int parentMessageId, bool subscribed) {
    if (!mounted || parentMessageId != widget.parentMessage.id) return;
    setState(() => _subscribed = subscribed);
  }

  Future<void> _toggle() async {
    if (_inFlight) return;
    _inFlight = true;
    // The thread tapped, held across the await: parentMessage may have moved
    // on to another root by the time the server answers.
    final message = widget.parentMessage;
    final target = !_subscribed;
    setState(() => _subscribed = target); // optimistic flip
    try {
      final result = target
          ? await CometChat.subscribeToThread(message.id)
          : await CometChat.unsubscribeFromThread(message.id);
      if (!mounted) return;
      if (result != null) {
        // The message object is the state (stateless redesign) — stamp it,
        // then tell the other surfaces through the kit event bus.
        message.threadSubscribed = target;
        CometChatMessageEvents.ccThreadSubscriptionChanged(message.id, target);
        CometChatThreadToast.show(
          context,
          target
              ? Translations.of(context).threadUnmutedToast
              : Translations.of(context).threadMutedToast,
        );
      } else {
        if (message.id == widget.parentMessage.id) {
          setState(() => _subscribed = !target); // revert
        }
        CometChatThreadToast.show(
          context,
          Translations.of(context).threadSubscriptionFailed,
        );
      }
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = CometChatThemeHelper.getColorPalette(context);
    final label = _subscribed
        ? Translations.of(context).threadMute
        : Translations.of(context).threadUnmute;
    return IconButton(
      onPressed: _toggle,
      tooltip: label,
      iconSize: 26,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        _subscribed
            ? Icons.notifications_outlined
            : Icons.notifications_off_outlined,
        color: palette.iconPrimary,
      ),
    );
  }
}
