import 'package:flutter/material.dart';

import '../../../../cometchat_chat_uikit.dart';

///[UsersConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatUsers]
///can be used by a component where [CometChatUsers] is a child component
///
///  ```dart
/// UsersConfiguration(
///      usersStyle: UsersStyle(),
///      avatarStyle: AvatarStyle(),
///      listItemStyle: ListItemStyle(),
///      statusIndicatorStyle: StatusIndicatorStyle(),
///    );
///   ```
///
class UsersConfiguration {
  const UsersConfiguration(
      {this.title,
      this.searchPlaceholder,
      this.showBackButton,
      this.hideSearch,
      this.usersRequestBuilder,
      this.subtitleView,
      this.hideSeparator,
      this.listItemView,
      this.usersStyle,
      this.options,
      this.backButton,
      this.searchBoxIcon,
      this.theme,
      this.selectionMode,
      this.onSelection,
      this.emptyStateText,
      this.errorStateText,
      this.loadingStateView,
      this.emptyStateView,
      this.errorStateView,
      this.listItemStyle,
      this.avatarStyle,
      this.statusIndicatorStyle,
      this.appBarOptions,
      this.hideSectionSeparator,
      this.disableUsersPresence,
      this.activateSelection,
      this.hideError,
      this.stateCallBack,
      this.controller,
      this.usersProtocol,
      this.onError,
      this.onBack,
      this.onItemTap,
      this.onItemLongPress,
      this.selectionIcon,
      this.submitIcon,
      this.hideAppbar,
      this.controllerTag});

  ///[title] Title of the user list component
  final String? title;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[showBackButton] switch on/off back button
  final bool? showBackButton;

  ///[hideSearch] switch on/off search input
  final bool? hideSearch;

  ///[usersRequestBuilder] custom request builder
  final UsersRequestBuilder? usersRequestBuilder;

  ///[subtitleView] to set subtitle for each user
  final Widget? Function(BuildContext, User)? subtitleView;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSeparator;

  ///[listItemView] set custom view for each user
  final Widget Function(User)? listItemView;

  ///[usersStyle] sets style for the [CometChatUsers]
  final UsersStyle? usersStyle;

  final List<CometChatOption>? Function(
      User, CometChatUsersController controller)? options;

  ///[backButton] back button
  final Widget? backButton;

  ///[searchBoxIcon] search icon
  final Widget? searchBoxIcon;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///[selectionMode] specifies mode users module is opening in
  final SelectionMode? selectionMode;

  ///[onSelection] function will be performed
  final Function(List<User>?, BuildContext)? onSelection;

  ///[emptyStateText] text to be displayed when the list is empty
  final String? emptyStateText;

  ///[errorStateText] text to be displayed when error occur
  final String? errorStateText;

  ///[loadingStateView] returns view fow loading state
  final WidgetBuilder? loadingStateView;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[errorStateView] returns view fow error state behind the dialog
  final WidgetBuilder? errorStateView;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[avatarStyle] set style for avatar
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget> Function(BuildContext context)? appBarOptions;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSectionSeparator;

  ///[disableUsersPresence] controls visibility of status indicator shown if user is online
  final bool? disableUsersPresence;

  ///[activateSelection] lets the widget know if users are allowed to be selected
  final ActivateSelection? activateSelection;

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatUsersController object
  final Function(CometChatUsersController controller)? stateCallBack;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  ///[usersProtocol] set custom users request builder protocol
  final UsersBuilderProtocol? usersProtocol;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[onItemTap] callback triggered on tapping a user item
  final Function(BuildContext context, User)? onItemTap;

  ///[onItemLongPress] callback triggered on pressing for long on a user item
  final Function(BuildContext context, User)? onItemLongPress;

  ///[selectionIcon] will override the default selection complete icon
  final Widget? selectionIcon;

  ///[submitIcon] will override the default selection complete icon
  final Widget? submitIcon;

  ///[hideAppbar] toggle visibility for app bar
  final bool? hideAppbar;

  ///Group tag to create from , if this is passed its parent responsibility to close this
  final String? controllerTag;

  UsersConfiguration merge(UsersConfiguration mergeWith) {
    return UsersConfiguration(
        title: title ?? mergeWith.title,
        searchPlaceholder: searchPlaceholder ?? mergeWith.searchPlaceholder,
        showBackButton: showBackButton ?? mergeWith.showBackButton,
        hideSearch: hideSearch ?? mergeWith.hideSearch,
        usersRequestBuilder:
            usersRequestBuilder ?? mergeWith.usersRequestBuilder,
        subtitleView: subtitleView ?? mergeWith.subtitleView,
        hideSeparator: hideSeparator ?? mergeWith.hideSeparator,
        listItemView: listItemView ?? mergeWith.listItemView,
        usersStyle: usersStyle ?? mergeWith.usersStyle,
        options: options ?? mergeWith.options,
        backButton: backButton ?? mergeWith.backButton,
        searchBoxIcon: searchBoxIcon ?? mergeWith.searchBoxIcon,
        theme: theme ?? mergeWith.theme,
        selectionMode: selectionMode ?? mergeWith.selectionMode,
        onSelection: onSelection ?? mergeWith.onSelection,
        emptyStateText: emptyStateText ?? mergeWith.emptyStateText,
        errorStateText: errorStateText ?? mergeWith.errorStateText,
        loadingStateView: loadingStateView ?? mergeWith.loadingStateView,
        emptyStateView: emptyStateView ?? mergeWith.emptyStateView,
        errorStateView: errorStateView ?? mergeWith.errorStateView,
        listItemStyle: listItemStyle ?? mergeWith.listItemStyle,
        avatarStyle: avatarStyle ?? mergeWith.avatarStyle,
        statusIndicatorStyle:
            statusIndicatorStyle ?? mergeWith.statusIndicatorStyle,
        appBarOptions: appBarOptions ?? mergeWith.appBarOptions,
        hideSectionSeparator:
            hideSectionSeparator ?? mergeWith.hideSectionSeparator,
        disableUsersPresence:
            disableUsersPresence ?? mergeWith.disableUsersPresence,
        activateSelection: activateSelection ?? mergeWith.activateSelection,
        hideError: hideError ?? mergeWith.hideError,
        stateCallBack: stateCallBack ?? mergeWith.stateCallBack,
        controller: controller ?? mergeWith.controller,
        usersProtocol: usersProtocol ?? mergeWith.usersProtocol,
        onError: onError ?? mergeWith.onError,
        onBack: onBack ?? mergeWith.onBack,
        onItemTap: onItemTap ?? mergeWith.onItemTap,
        onItemLongPress: onItemLongPress ?? mergeWith.onItemLongPress,
        selectionIcon: selectionIcon ?? mergeWith.selectionIcon,
        submitIcon: submitIcon ?? mergeWith.submitIcon,
        controllerTag: controllerTag ?? mergeWith.controllerTag);
  }
}
