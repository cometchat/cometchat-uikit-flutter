import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../cometchat_chat_uikit.dart' as cc;

/// [CometChatGroupMembers] displays all members of a [Group] as a list.
///
/// Migrated from GetX controller to BLoC architecture.
/// The widget now owns a [GroupMembersBloc] that is created in `initState`
/// and disposed in `dispose`, fixing the bug where `onInit` was never called
/// because the controller was created inside `build()` of a StatelessWidget.
class CometChatGroupMembers extends StatefulWidget {
  const CometChatGroupMembers({
    super.key,
    this.groupMembersProtocol,
    this.subtitleView,
    this.hideSeparator,
    this.listItemView,
    this.style,
    this.controller,
    this.searchPlaceholder,
    this.backButton,
    this.showBackButton = true,
    this.searchBoxIcon,
    this.hideSearch = false,
    this.selectionMode,
    this.onSelection,
    this.stateCallBack,
    this.groupMembersRequestBuilder,
    this.hideError,
    this.loadingStateView,
    this.emptyStateView,
    this.errorStateView,
    this.appBarOptions,
    this.options,
    required this.group,
    this.trailingView,
    this.selectIcon,
    this.submitIcon,
    this.onError,
    this.onBack,
    this.onItemTap,
    this.onItemLongPress,
    this.activateSelection,
    this.height,
    this.width,
    this.controllerTag,
    this.hideAppbar,
    this.searchKeyword,
    this.onLoad,
    this.onEmpty,
    this.setOptions,
    this.addOptions,
    this.leadingView,
    this.titleView,
    this.hideBanMemberOption,
    this.hideKickMemberOption,
    this.hideScopeChangeOption,
    this.usersStatusVisibility = true,
    this.groupMembersBloc,
  });

  // ── Props ──────────────────────────────────────────────────────────────────

  ///[groupMembersBloc] Optional external GroupMembersBloc instance.
  ///If provided, this bloc is used instead of creating one internally, and the
  ///widget will not close it on dispose. Mirrors
  ///[CometChatConversations.conversationsBloc]; it is the seam that lets a test
  ///supply member data without a live SDK.
  final GroupMembersBloc? groupMembersBloc;

  final GroupMembersBuilderProtocol? groupMembersProtocol;

  /// [groupMembersRequestBuilder] sets the request the list fetches members
  /// with: its limit is the page size, and its filters (scopes, status, search
  /// keyword) apply to every page. [group] decides whose members load — the
  /// builder's own guid is set aside when it differs. A keyword typed into the
  /// search box replaces the builder's own while the search runs; clearing it
  /// brings the builder's back. The builder itself is never changed. Ignored
  /// when [groupMembersBloc] is given — pass it to that bloc.
  final GroupMembersRequestBuilder? groupMembersRequestBuilder;
  final Widget? Function(BuildContext context, GroupMember groupMember)?
  subtitleView;
  final bool? hideSeparator;
  final Widget Function(GroupMember groupMember)? listItemView;
  final CometChatGroupMembersStyle? style;
  final ScrollController? controller;

  /// Legacy options callback — kept for backward compatibility.
  /// Receives a [CometChatGroupMembersController] stub that delegates to the BLoC.
  final List<CometChatOption>? Function(
    Group group,
    GroupMember member,
    CometChatGroupMembersController controller,
    BuildContext context,
  )?
  options;

  final String? searchPlaceholder;
  final Widget? backButton;
  final bool showBackButton;
  final Widget? searchBoxIcon;
  final bool hideSearch;
  final SelectionMode? selectionMode;
  final Function(List<GroupMember>?)? onSelection;

  /// Legacy stateCallBack — kept for backward compatibility.
  final Function(CometChatGroupMembersController controller)? stateCallBack;

  final bool? hideError;
  final WidgetBuilder? loadingStateView;
  final WidgetBuilder? emptyStateView;
  final WidgetBuilder? errorStateView;
  final List<Widget>? appBarOptions;
  final Group group;
  final Function(BuildContext context, GroupMember groupMember)? trailingView;
  final Widget? submitIcon;
  final Widget? selectIcon;
  final VoidCallback? onBack;
  final Function(GroupMember groupMember)? onItemTap;
  final Function(GroupMember groupMember)? onItemLongPress;
  final ActivateSelection? activateSelection;
  final OnError? onError;
  final double? height;
  final double? width;
  final String? controllerTag;
  final bool? hideAppbar;
  final String? searchKeyword;
  final OnLoad<GroupMember>? onLoad;
  final OnEmpty? onEmpty;

  final List<CometChatOption>? Function(
    Group group,
    GroupMember groupMember,
    CometChatGroupMembersController controller,
    BuildContext context,
  )?
  setOptions;

  final List<CometChatOption>? Function(
    Group group,
    GroupMember groupMember,
    CometChatGroupMembersController controller,
    BuildContext context,
  )?
  addOptions;

  final Widget? Function(BuildContext context, GroupMember groupMember)?
  leadingView;
  final Widget? Function(BuildContext context, GroupMember groupMember)?
  titleView;
  final bool? usersStatusVisibility;
  final bool? hideKickMemberOption;
  final bool? hideBanMemberOption;
  final bool? hideScopeChangeOption;

  @override
  State<CometChatGroupMembers> createState() => _CometChatGroupMembersState();
}

class _CometChatGroupMembersState extends State<CometChatGroupMembers> {
  late GroupMembersBloc _bloc;
  bool _isExternalBloc = false;
  final ValueNotifier<bool> _isSelectionOn = ValueNotifier<bool>(false);

  // Cached theme values (theme-caching pattern)
  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;
  bool _themeInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.groupMembersBloc != null) {
      // An externally supplied bloc owns its own dependencies and lifecycle.
      _bloc = widget.groupMembersBloc!;
      _isExternalBloc = true;
    } else {
      _bloc = GroupMembersBloc(
        group: widget.group,
        groupMembersRequestBuilder: widget.groupMembersRequestBuilder,
        usersStatusVisibility: widget.usersStatusVisibility ?? true,
        hideKickMemberOption: widget.hideKickMemberOption ?? false,
        hideBanMemberOption: widget.hideBanMemberOption ?? false,
        hideScopeChangeOption: widget.hideScopeChangeOption ?? false,
      );
      _isExternalBloc = false;
    }
    // Trigger initial load — this is the fix: onInit was never called before
    _bloc.add(const LoadGroupMembers());
    if (widget.stateCallBack != null) {
      widget.stateCallBack!(_buildLegacyControllerStub());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_themeInitialized) {
      _colorPalette = CometChatThemeHelper.getColorPalette(context);
      _typography = CometChatThemeHelper.getTypography(context);
      _spacing = CometChatThemeHelper.getSpacing(context);
      _themeInitialized = true;
    }
  }

  @override
  void dispose() {
    if (!_isExternalBloc) {
      _bloc.close();
    }
    _isSelectionOn.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  CometChatGroupMembersStyle _resolvedStyle(BuildContext context) {
    return CometChatThemeHelper.getTheme<CometChatGroupMembersStyle>(
      context: context,
      defaultTheme: CometChatGroupMembersStyle.of,
    ).merge(widget.style);
  }

  /// Build the scope badge shown as trailing on each member row.
  Widget _buildScopeBadge(
    GroupMember member,
    CometChatGroupMembersStyle style,
  ) {
    Color? bg;
    BoxBorder? border;
    Color? textColor;
    TextStyle? textStyle;
    String scope = member.scope ?? GroupMemberScope.participant;

    if (member.uid == widget.group.owner) {
      scope = GroupMemberScope.owner;
      bg = style.ownerMemberScopeBackgroundColor ?? _colorPalette.primary;
      textColor =
          style.ownerMemberScopeTextColor ??
          style.ownerMemberScopeTextStyle?.color ??
          _colorPalette.white;
      border = style.ownerMemberScopeBorder;
      textStyle = style.ownerMemberScopeTextStyle;
    } else if (scope == GroupMemberScope.admin) {
      bg =
          style.adminMemberScopeBackgroundColor ??
          _colorPalette.extendedPrimary100;
      border =
          style.adminMemberScopeBorder ??
          Border.all(
            color: _colorPalette.borderHighlight ?? Colors.transparent,
            width: 1,
          );
      textColor =
          style.adminMemberScopeTextColor ??
          style.adminMemberScopeTextStyle?.color ??
          _colorPalette.textHighlight;
      textStyle = style.adminMemberScopeTextStyle;
    } else if (scope == GroupMemberScope.moderator) {
      bg =
          style.moderatorMemberScopeBackgroundColor ??
          _colorPalette.extendedPrimary100;
      textColor =
          style.moderatorMemberScopeTextColor ??
          style.moderatorMemberScopeTextStyle?.color ??
          _colorPalette.textHighlight;
      border = style.moderatorMemberScopeBorder;
      textStyle = style.moderatorMemberScopeTextStyle;
    } else {
      return const SizedBox();
    }

    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: _spacing.padding3 ?? 0,
        vertical: _spacing.padding1 ?? 0,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: BorderRadius.circular(_spacing.radiusMax ?? 0),
      ),
      child: Text(
        scope.isNotEmpty
            ? '${scope[0].toUpperCase()}${scope.substring(1)}'
            : '',
        style: TextStyle(
          fontSize: _typography.caption1?.regular?.fontSize,
          fontWeight: _typography.caption1?.regular?.fontWeight,
          color: textColor,
        ).merge(textStyle).copyWith(color: textColor),
      ),
    );
  }

  /// Build a single member list item.
  Widget _buildListItem(
    GroupMember member,
    GroupMembersLoaded state,
    CometChatGroupMembersStyle groupMemberStyle,
    GlobalKey itemKey,
  ) {
    if (widget.listItemView != null) {
      return widget.listItemView!(member);
    }

    Widget? subtitle = widget.subtitleView?.call(context, member);
    Widget? title = widget.titleView?.call(context, member);
    Widget? leading = widget.leadingView?.call(context, member);
    Widget tail = widget.trailingView != null
        ? widget.trailingView!(context, member)
        : _buildScopeBadge(member, groupMemberStyle);

    final isSelected = state.selectedMembers.contains(member.uid);
    final hasSelection = state.selectedMembers.isNotEmpty;

    final statusUtils = StatusIndicatorUtils.getStatusIndicatorFromParams(
      context: context,
      groupMember: member,
      // Without isSelected the utility never takes its selected branch, so
      // selectIcon was inert. Groups, Search and Conversations all pass it.
      isSelected: isSelected,
      onlineStatusIndicatorColor:
          groupMemberStyle.onlineStatusColor ?? _colorPalette.success,
      usersStatusVisibility: widget.usersStatusVisibility,
      selectIcon: widget.selectIcon,
    );

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (groupMemberStyle.listItemSelectedBackgroundColor ??
                  _colorPalette.background4)
            : _colorPalette.transparent,
      ),
      padding: EdgeInsets.only(
        left: hasSelection ? 0 : _spacing.padding4 ?? 0,
        right: _spacing.padding4 ?? 0,
        top: _spacing.padding2 ?? 0,
        bottom: _spacing.padding2 ?? 0,
      ),
      child: GestureDetector(
        onLongPress: () =>
            _onItemLongPress(member, state, groupMemberStyle, itemKey),
        onTap: () => _onItemTap(member, state),
        child: Row(
          children: [
            if (hasSelection)
              Checkbox(
                fillColor: isSelected
                    ? WidgetStateProperty.all(
                        groupMemberStyle.checkboxCheckedBackgroundColor ??
                            _colorPalette.iconHighlight,
                      )
                    : WidgetStateProperty.all(
                        groupMemberStyle.checkboxBackgroundColor ??
                            _colorPalette.transparent,
                      ),
                value: isSelected,
                onChanged: (_) => _onItemTap(member, state),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      groupMemberStyle.checkboxBorderRadius ??
                      BorderRadius.circular(_spacing.radius1 ?? 0),
                ),
                checkColor:
                    groupMemberStyle.checkboxSelectedIconColor ??
                    _colorPalette.white,
                side:
                    groupMemberStyle.checkboxBorder ??
                    BorderSide(
                      color:
                          (isSelected
                              ? _colorPalette.borderHighlight
                              : _colorPalette.borderDefault) ??
                          Colors.transparent,
                      width: 1.25,
                    ),
              )
            else
              const SizedBox(),
            Expanded(
              child: CometChatListItem(
                id: member.uid,
                avatarName: member.name,
                avatarURL: member.avatar,
                title:
                    (_bloc.loggedInUser != null &&
                        _bloc.loggedInUser!.uid == member.uid)
                    ? cc.Translations.of(context).you
                    : member.name,
                key: UniqueKey(),
                subtitleView: subtitle,
                tailView: tail,
                avatarStyle:
                    groupMemberStyle.avatarStyle ??
                    const CometChatAvatarStyle(),
                avatarHeight: 40,
                avatarWidth: 40,
                statusIndicatorColor: statusUtils.statusIndicatorColor,
                statusIndicatorIcon: statusUtils.icon,
                statusIndicatorStyle:
                    groupMemberStyle.statusIndicatorStyle ??
                    const CometChatStatusIndicatorStyle(),
                hideSeparator: widget.hideSeparator ?? true,
                titleView: title,
                leadingStateView: leading,
                style: ListItemStyle(
                  background: _colorPalette.transparent,
                  titleStyle: TextStyle(
                    fontSize: _typography.heading4?.medium?.fontSize,
                    fontWeight: _typography.heading4?.medium?.fontWeight,
                    fontFamily: _typography.heading4?.medium?.fontFamily,
                    color: _colorPalette.textPrimary,
                  ),
                ).merge(groupMemberStyle.listItemStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTap(GroupMember member, GroupMembersLoaded state) {
    final isOwner = member.uid == widget.group.owner;
    final canSelect =
        !isOwner &&
        (widget.activateSelection == ActivateSelection.onClick ||
            (widget.activateSelection == ActivateSelection.onLongClick &&
                state.selectedMembers.isNotEmpty)) &&
        !(widget.selectionMode == null ||
            widget.selectionMode == SelectionMode.none);

    if (canSelect) {
      _bloc.add(ToggleMemberSelection(member.uid));
      final willBeEmpty =
          state.selectedMembers.length == 1 &&
          state.selectedMembers.contains(member.uid);
      if (willBeEmpty) {
        _isSelectionOn.value = false;
      } else if (widget.activateSelection == ActivateSelection.onClick) {
        _isSelectionOn.value = true;
      }
    } else if (widget.onItemTap != null) {
      widget.onItemTap!(member);
    }
  }

  void _onItemLongPress(
    GroupMember member,
    GroupMembersLoaded state,
    CometChatGroupMembersStyle groupMemberStyle,
    GlobalKey itemKey,
  ) {
    final isOwner = member.uid == widget.group.owner;
    final canStartSelection =
        !isOwner &&
        widget.activateSelection == ActivateSelection.onLongClick &&
        state.selectedMembers.isEmpty &&
        !(widget.selectionMode == null ||
            widget.selectionMode == SelectionMode.none);

    if (canStartSelection) {
      _bloc.add(ToggleMemberSelection(member.uid));
      _isSelectionOn.value = true;
      return;
    }

    if (widget.onItemLongPress != null) {
      widget.onItemLongPress!(member);
      return;
    }

    // Build options with wired onClick closures
    final legacyController = _buildLegacyControllerStub();
    List<CometChatOption> opts = [];

    if (widget.options != null) {
      // Legacy full-replacement hook, kept ahead of setOptions for the v4
      // call shape.
      opts =
          widget.options!(widget.group, member, legacyController, context) ??
          [];
    } else if (widget.setOptions != null) {
      opts =
          widget.setOptions!(widget.group, member, legacyController, context) ??
          [];
    } else {
      if (widget.addOptions != null) {
        opts.addAll(
          widget.addOptions!(widget.group, member, legacyController, context) ??
              [],
        );
      }
      // Get permission-filtered option metadata, then wire real actions
      final metaOptions = _bloc.getDefaultOptions(
        member,
        context,
        _colorPalette,
        _typography,
        _spacing,
      );
      opts.addAll(
        metaOptions.map(
          (o) => CometChatOption(
            id: o.id,
            title: o.title,
            icon: o.icon,
            packageName: o.packageName,
            backgroundColor: o.backgroundColor,
            iconTint: _colorPalette.iconSecondary,
            iconWidget: o.iconWidget,
            onClick: () =>
                _handleMemberOptionClick(o.id, member, groupMemberStyle),
          ),
        ),
      );

      if (widget.addOptions != null &&
          widget.group.owner != CometChatUIKit.loggedInUser?.uid &&
          member.scope == GroupMemberScope.admin) {
        return;
      }
    }

    _showPopupMenu(opts, groupMemberStyle, itemKey, member);
  }

  /// Dispatch the correct action for a member option tap.
  void _handleMemberOptionClick(
    String optionId,
    GroupMember member,
    CometChatGroupMembersStyle groupMemberStyle,
  ) {
    final confirmDialogStyle =
        CometChatThemeHelper.getTheme<CometChatConfirmDialogStyle>(
          context: context,
          defaultTheme: CometChatConfirmDialogStyle.of,
        ).merge(groupMemberStyle.confirmDialogStyle);
    final changeScopeStyle =
        CometChatThemeHelper.getTheme<CometChatChangeScopeStyle>(
          context: context,
          defaultTheme: CometChatChangeScopeStyle.of,
        ).merge(groupMemberStyle.changeScopeStyle);

    switch (optionId) {
      case GroupMemberOptionConstants.kick:
        _showConfirmDialog(
          title: '${cc.Translations.of(context).kick} ${member.name}?',
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 48,
            color: confirmDialogStyle.iconColor ?? _colorPalette.error,
          ),
          message:
              '${cc.Translations.of(context).areYouSureRemove} ${member.name} ${cc.Translations.of(context).from} ${widget.group.name}?',
          confirmText: cc.Translations.of(context).kick.toUpperCase(),
          confirmDialogStyle: confirmDialogStyle,
          onConfirm: () {
            Navigator.of(context).pop();
            _bloc.add(KickMember(member));
          },
        );
        break;

      case GroupMemberOptionConstants.ban:
        _showConfirmDialog(
          title: '${cc.Translations.of(context).ban} ${member.name}?',
          icon: Icon(
            Icons.not_interested,
            size: 48,
            color: confirmDialogStyle.iconColor ?? _colorPalette.error,
          ),
          message:
              '${cc.Translations.of(context).areYouSureBan} ${member.name} ${cc.Translations.of(context).from} ${widget.group.name}?',
          confirmText: cc.Translations.of(context).ban.toUpperCase(),
          confirmDialogStyle: confirmDialogStyle,
          onConfirm: () {
            Navigator.of(context).pop();
            _bloc.add(BanMember(member));
          },
        );
        break;

      case GroupMemberOptionConstants.changeScope:
        showModalBottomSheet(
          context: context,
          barrierColor: (_colorPalette.textPrimary ?? const Color(0xFF141414))
              .withValues(alpha: 0.8),
          builder: (_) => SingleChildScrollView(
            child: CometChatChangeScope(
              group: widget.group,
              member: member,
              style: changeScopeStyle,
              onSave: (group, m, newScope, oldScope) async {
                _bloc.add(ChangeMemberScope(member: m, newScope: newScope));
              },
            ),
          ),
        );
        break;
    }
  }

  void _showConfirmDialog({
    required String title,
    required Widget icon,
    required String message,
    required String confirmText,
    required CometChatConfirmDialogStyle confirmDialogStyle,
    required VoidCallback onConfirm,
  }) {
    CometChatConfirmDialog(
      context: context,
      icon: icon,
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _typography.heading2?.medium?.fontSize,
          fontWeight: _typography.heading2?.medium?.fontWeight,
          fontFamily: _typography.heading2?.medium?.fontFamily,
          color: _colorPalette.textPrimary,
        ).merge(confirmDialogStyle.titleTextStyle),
      ),
      messageText: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _typography.body?.regular?.fontSize,
          fontWeight: _typography.body?.regular?.fontWeight,
          fontFamily: _typography.body?.regular?.fontFamily,
          color: _colorPalette.textSecondary,
        ).merge(confirmDialogStyle.messageTextStyle),
      ),
      confirmButtonText: confirmText,
      cancelButtonText: cc.Translations.of(context).cancelCapital,
      style: CometChatConfirmDialogStyle(
        iconColor: confirmDialogStyle.iconColor ?? _colorPalette.error,
        backgroundColor: confirmDialogStyle.backgroundColor,
        cancelButtonBackground:
            confirmDialogStyle.cancelButtonBackground ??
            _colorPalette.borderLight,
        confirmButtonBackground:
            confirmDialogStyle.confirmButtonBackground ?? _colorPalette.error,
        cancelButtonTextColor: confirmDialogStyle.cancelButtonTextColor,
        confirmButtonTextColor:
            confirmDialogStyle.confirmButtonTextColor ?? _colorPalette.white,
      ),
      onCancel: (dialogContext) => Navigator.of(dialogContext).pop(),
      onConfirm: (dialogContext) {
        Navigator.of(dialogContext).pop();
        onConfirm();
      },
    ).show();
  }

  /// Minimal legacy controller stub — only used when [setOptions]/[addOptions] callbacks
  /// are provided by the consumer and need a controller reference.
  /// The legacy controller handed to [CometChatGroupMembers.stateCallBack],
  /// [CometChatGroupMembers.setOptions] and
  /// [CometChatGroupMembers.addOptions]. Built once so callers keep a stable
  /// reference, and its selectionMap is synced from bloc state — otherwise
  /// `stateCallBack` hands back a controller whose selection is always empty.
  CometChatGroupMembersController? _legacyController;

  CometChatGroupMembersController _buildLegacyControllerStub() {
    return _legacyController ??= CometChatGroupMembersController(
      groupMembersBuilderProtocol:
          widget.groupMembersProtocol ??
          UIGroupMembersBuilder(
            widget.groupMembersRequestBuilder ??
                (GroupMembersRequestBuilder(widget.group.guid)
                  ..searchKeyword = widget.searchKeyword),
          ),
      group: widget.group,
      hideBanMemberOption: widget.hideBanMemberOption,
      hideKickMemberOption: widget.hideKickMemberOption,
      hideScopeChangeOption: widget.hideScopeChangeOption,
    );
  }

  void _showPopupMenu(
    List<CometChatOption> options,
    CometChatGroupMembersStyle groupMemberStyle,
    GlobalKey widgetKey,
    GroupMember member,
  ) {
    if (options.isEmpty) return;
    final position = WidgetPositionUtil.getWidgetPosition(context, widgetKey);
    showMenu(
      context: context,
      position: position ?? const RelativeRect.fromLTRB(0, 0, 0, 0),
      menuPadding: EdgeInsets.zero,
      color:
          groupMemberStyle.optionsBackgroundColor ?? _colorPalette.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_spacing.radius2 ?? 0),
        side: BorderSide(
          color: _colorPalette.borderLight ?? Colors.transparent,
          width: 1,
        ),
      ),
      shadowColor: _colorPalette.transparent,
      elevation: 8,
      items: options
          .map(
            (o) => CustomPopupMenuItem<CometChatOption>(
              value: o,
              child: GetMenuView(
                option: o,
                textStyle: groupMemberStyle.optionsTextStyle,
                iconTint: groupMemberStyle.optionsIconColor ?? o.iconTint,
              ),
            ),
          )
          .toList(),
    ).then((selected) {
      if (selected?.onClick != null) selected!.onClick!();
    });
  }

  // ── State views ────────────────────────────────────────────────────────────

  Widget _buildLoading(CometChatGroupMembersStyle style) {
    if (widget.loadingStateView != null) {
      return Center(child: widget.loadingStateView!(context));
    }
    return CometChatShimmerEffect(
      colorPalette: _colorPalette,
      child: ListView.builder(
        itemCount: 30,
        shrinkWrap: true,
        itemBuilder: (_, _) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _spacing.padding4 ?? 0,
            vertical: _spacing.padding3 ?? 0,
          ),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(right: _spacing.padding3 ?? 0),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          height: 19,
                          width: MediaQuery.sizeOf(context).width * 0.4,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(
                              _spacing.radius2 ?? 0,
                            ),
                          ),
                        ),
                        Container(
                          height: 19,
                          width: MediaQuery.sizeOf(context).width * 0.2,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(
                              _spacing.radius2 ?? 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(
                          _spacing.radius2 ?? 0,
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

  Widget _buildEmpty(CometChatGroupMembersStyle style) {
    if (widget.emptyStateView != null) return widget.emptyStateView!(context);
    return UIStateUtils.getDefaultEmptyStateView(
      context,
      _colorPalette,
      _typography,
      _spacing,
      emptyStateTextColor: style.emptyStateTextColor,
      emptyStateTextStyle: style.emptyStateTextStyle,
      emptyStateSubtitleColor: style.emptyStateSubtitleTextColor,
      emptyStateSubtitleStyle: style.emptyStateSubtitleTextStyle,
    );
  }

  Widget _buildError(CometChatGroupMembersStyle style) {
    if (widget.errorStateView != null) return widget.errorStateView!(context);
    return UIStateUtils.getDefaultErrorStateView(
      context,
      _colorPalette,
      _typography,
      _spacing,
      () => _bloc.add(const LoadGroupMembers()),
      errorStateTextStyle: style.errorStateTextStyle,
      errorStateSubtitleStyle: style.errorStateSubtitleStyle,
      buttonTextStyle: style.retryButtonTextStyle,
      buttonTextColor: style.retryButtonTextColor,
      buttonBackgroundColor: style.retryButtonBackgroundColor,
      buttonBorderSide: style.retryButtonBorder,
      buttonBorderRadius: style.retryButtonBorderRadius,
    );
  }

  Widget _buildList(
    GroupMembersLoaded state,
    CometChatGroupMembersStyle style,
  ) {
    final keys = List.generate(state.members.length, (_) => GlobalKey());
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Trigger load-more when near the bottom
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200 &&
            state.hasMore &&
            !state.isLoadingMore) {
          _bloc.add(const LoadMoreGroupMembers());
        }
        return false;
      },
      child: ListView.builder(
        controller: widget.controller,
        padding: style.listPadding,
        // Only add the loader slot when actively loading more
        itemCount: state.members.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (ctx, index) {
          if (index >= state.members.length) {
            // Pagination loader slot — only shown when isLoadingMore is true
            return Center(
              child: Padding(
                padding: EdgeInsets.all(_spacing.padding4 ?? 16),
                child: SizedBox(
                  height: 30,
                  width: 30,
                  child: CircularProgressIndicator(
                    color: style.loadingIconColor ?? _colorPalette.primary,
                  ),
                ),
              ),
            );
          }
          return SizedBox(
            key: keys[index],
            child: _buildListItem(
              state.members[index],
              state,
              style,
              keys[index],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionWidget(CometChatGroupMembersStyle style) {
    if (!_isSelectionOn.value) return const SizedBox(height: 0, width: 0);
    return IconButton(
      tooltip: Translations.of(context).done,
      onPressed: () {
        final selected = _bloc.getSelectedList();
        widget.onSelection?.call(selected);
      },
      icon:
          widget.submitIcon ??
          Icon(
            Icons.check,
            color: style.submitIconColor ?? _colorPalette.iconPrimary,
            size: 24,
          ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final groupMemberStyle = _resolvedStyle(context);

    return BlocProvider<GroupMembersBloc>.value(
      value: _bloc,
      child: BlocConsumer<GroupMembersBloc, GroupMembersState>(
        // Lifecycle callbacks, matching ConversationsList: onLoad, onEmpty and
        // onError are part of the documented public API, so they have to fire
        // on the state transitions they describe.
        listener: (ctx, state) {
          if (state is GroupMembersLoaded && widget.onLoad != null) {
            widget.onLoad!(state.members);
          }
          if (state is GroupMembersEmpty && widget.onEmpty != null) {
            widget.onEmpty!();
          }
          if (state is GroupMembersError && widget.onError != null) {
            widget.onError!(
              CometChatException(
                'GROUP_MEMBERS_ERROR',
                state.message,
                state.message,
              ),
            );
          }
        },
        builder: (ctx, state) {
          // Title: show selection count or "Members"
          final titleText =
              (state is GroupMembersLoaded && state.selectedMembers.isNotEmpty)
              ? '${state.selectedMembers.length}'
              : cc.Translations.of(context).members;

          final hasSelection =
              state is GroupMembersLoaded && state.selectedMembers.isNotEmpty;

          return CometChatListBase(
            titleSpacing: widget.showBackButton ? 0 : 16,
            titleView: Text(
              titleText,
              style: TextStyle(
                color: _colorPalette.textPrimary,
                fontSize: _typography.heading1?.bold?.fontSize,
                fontWeight: _typography.heading1?.bold?.fontWeight,
                fontFamily: _typography.heading1?.bold?.fontFamily,
              ).merge(groupMemberStyle.titleStyle),
            ),
            hideSearch: widget.hideSearch,
            hideAppBar: widget.hideAppbar ?? false,
            backIcon: hasSelection
                ? IconButton(
                    tooltip: Translations.of(context).clearSearch,
                    onPressed: () {
                      _bloc.add(const ClearMemberSelection());
                      _isSelectionOn.value = false;
                    },
                    icon: Icon(
                      Icons.clear,
                      color: _colorPalette.iconPrimary,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                  )
                : (widget.backButton ??
                      IconButton(
                        tooltip: Translations.of(context).back,
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back,
                          color:
                              groupMemberStyle.backIconColor ??
                              _colorPalette.iconPrimary,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                      )),
            onBack: widget.onBack,
            placeholder: widget.searchPlaceholder,
            searchText: widget.searchKeyword,
            showBackButton: widget.showBackButton,
            searchBoxIcon: widget.searchBoxIcon,
            onSearch: (val) => _bloc.add(SearchGroupMembers(val)),
            menuOptions: [
              if (widget.appBarOptions != null &&
                  widget.appBarOptions!.isNotEmpty)
                ...widget.appBarOptions!,
              ValueListenableBuilder<bool>(
                valueListenable: _isSelectionOn,
                builder: (_, _, _) => _buildSelectionWidget(groupMemberStyle),
              ),
            ],
            searchPadding: EdgeInsets.symmetric(
              horizontal: _spacing.padding4 ?? 0,
              vertical: _spacing.padding3 ?? 0,
            ),
            searchContentPadding: EdgeInsets.symmetric(
              horizontal: _spacing.padding3 ?? 0,
              vertical: _spacing.padding2 ?? 0,
            ),
            searchBoxHeight: 40,
            style: ListBaseStyle(
              background:
                  groupMemberStyle.backgroundColor ?? _colorPalette.background1,
              titleStyle: TextStyle(
                color: _colorPalette.textPrimary,
                fontSize: _typography.heading1?.bold?.fontSize,
                fontWeight: _typography.heading1?.bold?.fontWeight,
                fontFamily: _typography.heading1?.bold?.fontFamily,
              ).merge(groupMemberStyle.titleStyle),
              height: widget.height,
              width: widget.width,
              backIconTint: groupMemberStyle.backIconColor,
              searchIconTint:
                  groupMemberStyle.searchIconColor ??
                  _colorPalette.iconSecondary,
              border: groupMemberStyle.border,
              borderRadius: groupMemberStyle.borderRadius,
              searchTextStyle: TextStyle(
                color: _colorPalette.textPrimary,
                fontSize: _typography.heading4?.regular?.fontSize,
                fontWeight: _typography.heading4?.regular?.fontWeight,
                fontFamily: _typography.heading4?.regular?.fontFamily,
              ).merge(groupMemberStyle.searchTextStyle),
              searchPlaceholderStyle: TextStyle(
                color: _colorPalette.textTertiary,
                fontSize: _typography.heading4?.regular?.fontSize,
                fontWeight: _typography.heading4?.regular?.fontWeight,
                fontFamily: _typography.heading4?.regular?.fontFamily,
              ).merge(groupMemberStyle.searchPlaceholderStyle),
              searchTextFieldRadius: groupMemberStyle.searchBorderRadius,
              searchBoxBackground:
                  groupMemberStyle.searchBackground ??
                  _colorPalette.background3,
              appBarShape: Border(
                bottom: BorderSide(
                  color:
                      groupMemberStyle.separatorColor ??
                      _colorPalette.borderLight ??
                      Colors.transparent,
                  width: groupMemberStyle.separatorHeight ?? 1,
                ),
              ),
            ),
            container: _buildContainer(state, groupMemberStyle),
          );
        },
      ),
    );
  }

  /// Mirrors the bloc's selected uids onto the legacy controller's
  /// selectionMap so integrators reading it through [stateCallBack] see the
  /// same selection the list is showing.
  void _syncLegacySelection(GroupMembersLoaded state) {
    final controller = _legacyController;
    if (controller == null) return;
    controller.selectionMap
      ..clear()
      ..addEntries(
        state.members
            .where((m) => state.selectedMembers.contains(m.uid))
            .map((m) => MapEntry(m.uid, m)),
      );
  }

  Widget _buildContainer(
    GroupMembersState state,
    CometChatGroupMembersStyle style,
  ) {
    if (state is GroupMembersLoading || state is GroupMembersInitial) {
      return _buildLoading(style);
    } else if (state is GroupMembersEmpty) {
      return _buildEmpty(style);
    } else if (state is GroupMembersError) {
      // hideError suppresses the error view, as on CometChatConversations.
      if (widget.hideError == true) return const SizedBox.shrink();
      return _buildError(style);
    } else if (state is GroupMembersLoaded) {
      _syncLegacySelection(state);
      if (state.members.isEmpty) return _buildEmpty(style);
      return _buildList(state, style);
    }
    return _buildLoading(style);
  }
}
