import 'package:flutter/material.dart';

import '../../../../cometchat_chat_uikit.dart';

///[GroupsConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatGroups]
///can be used by a component where [CometChatGroups] is a child component
///
/// ```dart
/// GroupsConfiguration(
///        groupsStyle: GroupsStyle(),
///        avatarStyle: AvatarStyle(),
///        listItemStyle: ListItemStyle(),
///        statusIndicatorStyle: StatusIndicatorStyle(),
///      );
///```
///
class GroupsConfiguration {
  const GroupsConfiguration(
      {this.title,
      this.searchPlaceholder,
      this.showBackButton,
      this.hideSearch,
      this.groupsStyle,
      this.groupsRequestBuilder,
      this.subtitleView,
      this.listItemView,
      this.controller,
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
      this.createGroupIcon,
      this.joinProtectedGroupConfiguration,
      this.hideSeparator,
      this.passwordGroupIcon,
      this.privateGroupIcon,
      this.activateSelection,
      this.hideError,
      this.stateCallBack,
      this.groupsProtocol,
      this.appBarOptions,
      this.onError,
      this.onBack,
      this.onItemTap,
      this.onItemLongPress,
      this.submitIcon,
      this.selectionIcon,
      this.hideAppbar,
      this.controllerTag});

  ///[groupsRequestBuilder] set custom request builder
  final GroupsRequestBuilder? groupsRequestBuilder;

  ///[subtitleView] to set subtitle for each group
  final Widget? Function(BuildContext, Group)? subtitleView;

  ///[listItemView] set custom view for each group
  final Widget Function(Group)? listItemView;

  ///[groupsStyle] sets style
  final GroupsStyle? groupsStyle;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  ///[options]  set options which will be visible at slide of each banned member
  final List<CometChatOption>? Function(Group group,
      CometChatGroupsController controller, BuildContext context)? options;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[backButton] back button
  final Widget? backButton;

  ///[showBackButton] switch on/off back button
  final bool? showBackButton;

  ///[searchBoxIcon] search icon
  final Widget? searchBoxIcon;

  ///[hideSearch] switch on/ff search input
  final bool? hideSearch;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///[selectionMode] specifies mode groups module is opening in
  final SelectionMode? selectionMode;

  ///[onSelection] function will be performed
  final Function(List<Group>?)? onSelection;

  ///[title] sets title for the list
  final String? title;

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

  ///[createGroupIcon] replace create group icon
  final Widget? createGroupIcon;

  ///[joinProtectedGroupConfiguration] sets configuration for [CometChatJoinProtectedGroup]
  final JoinProtectedGroupConfiguration? joinProtectedGroupConfiguration;

  ///[hideSeparator]
  final bool? hideSeparator;

  ///[passwordGroupIcon] sets icon in status indicator for password group
  final Widget? passwordGroupIcon;

  ///[privateGroupIcon] sets icon in status indicator for private group
  final Widget? privateGroupIcon;

  ///[activateSelection] lets the widget know if conversations are allowed to be selected
  final ActivateSelection? activateSelection;

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatGroupsController object
  final Function(CometChatGroupsController controller)? stateCallBack;

  ///[groupsProtocol] set custom groups request builder protocol
  final GroupsBuilderProtocol? groupsProtocol;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget> Function(BuildContext context)? appBarOptions;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[onItemTap] callback triggered on tapping a group item
  final Function(BuildContext, Group)? onItemTap;

  ///[onItemLongPress] callback triggered on pressing for long on a group item
  final Function(BuildContext, Group)? onItemLongPress;

  ///[onError] callback triggered in case any error happens when fetching groups
  final OnError? onError;

  ///[submitIcon] will override the default submit icon
  final Widget? submitIcon;

  ///[selectionIcon] will change selection icon
  final Widget? selectionIcon;

  ///[hideAppbar] toggle visibility for app bar
  final bool? hideAppbar;

  ///Group tag to create from , if this is passed its parent responsibility to close this
  final String? controllerTag;

  GroupsConfiguration merge(GroupsConfiguration mergeWith) {
    return GroupsConfiguration(
        groupsRequestBuilder:
            groupsRequestBuilder ?? mergeWith.groupsRequestBuilder,
        subtitleView: subtitleView ?? mergeWith.subtitleView,
        listItemView: listItemView ?? mergeWith.listItemView,
        groupsStyle: groupsStyle ?? mergeWith.groupsStyle,
        controller: controller ?? mergeWith.controller,
        options: options ?? mergeWith.options,
        searchPlaceholder: searchPlaceholder ?? mergeWith.searchPlaceholder,
        backButton: backButton ?? mergeWith.backButton,
        showBackButton: showBackButton ?? mergeWith.showBackButton,
        searchBoxIcon: searchBoxIcon ?? mergeWith.searchBoxIcon,
        hideSearch: hideSearch ?? mergeWith.hideSearch,
        theme: theme ?? mergeWith.theme,
        selectionMode: selectionMode ?? mergeWith.selectionMode,
        onSelection: onSelection ?? mergeWith.onSelection,
        title: title ?? mergeWith.title,
        emptyStateText: emptyStateText ?? mergeWith.emptyStateText,
        errorStateText: errorStateText ?? mergeWith.errorStateText,
        loadingStateView: loadingStateView ?? mergeWith.loadingStateView,
        emptyStateView: emptyStateView ?? mergeWith.emptyStateView,
        errorStateView: errorStateView ?? mergeWith.errorStateView,
        listItemStyle: listItemStyle ?? mergeWith.listItemStyle,
        avatarStyle: avatarStyle ?? mergeWith.avatarStyle,
        statusIndicatorStyle:
            statusIndicatorStyle ?? mergeWith.statusIndicatorStyle,
        createGroupIcon: createGroupIcon ?? mergeWith.createGroupIcon,
        joinProtectedGroupConfiguration: joinProtectedGroupConfiguration ??
            mergeWith.joinProtectedGroupConfiguration,
        hideSeparator: hideSeparator ?? mergeWith.hideSeparator,
        passwordGroupIcon: passwordGroupIcon ?? mergeWith.passwordGroupIcon,
        privateGroupIcon: privateGroupIcon ?? mergeWith.privateGroupIcon,
        activateSelection: activateSelection ?? mergeWith.activateSelection,
        hideError: hideError ?? mergeWith.hideError,
        stateCallBack: stateCallBack ?? mergeWith.stateCallBack,
        groupsProtocol: groupsProtocol ?? mergeWith.groupsProtocol,
        appBarOptions: appBarOptions ?? mergeWith.appBarOptions,
        onBack: onBack ?? mergeWith.onBack,
        onItemTap: onItemTap ?? mergeWith.onItemTap,
        onItemLongPress: onItemLongPress ?? mergeWith.onItemLongPress,
        onError: onError ?? mergeWith.onError,
        submitIcon: submitIcon ?? mergeWith.submitIcon,
        selectionIcon: selectionIcon ?? mergeWith.selectionIcon,
        hideAppbar: hideAppbar ?? mergeWith.hideAppbar,
        controllerTag: controllerTag ?? mergeWith.controllerTag);
  }
}
