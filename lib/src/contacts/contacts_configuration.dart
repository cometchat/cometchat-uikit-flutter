import 'package:flutter/material.dart';
import '../../../cometchat_chat_uikit.dart';

///[ContactsConfiguration] is a component that displays a list of users and groups with the help of [CometChatListBase] and [CometChatListItem]
///
///
/// ```dart
///   ContactsConfiguration(
///
/// );
/// ```

class ContactsConfiguration {
  ContactsConfiguration(
      {this.usersConfiguration,
      this.onItemTap,
      this.groupsConfiguration,
      this.usersTabTitle,
      this.groupsTabTitle,
      this.theme,
      this.title,
      this.closeIcon,
      this.contactsStyle,
      this.onClose,
      this.onSubmitIconTap,
      this.tabVisibility = TabVisibility.usersAndGroups,
      this.hideSubmitIcon,
      this.selectionLimit,
      this.selectionMode,
      this.submitIcon,
      this.snackBarConfiguration});

  ///[usersConfiguration] set custom users request builder protocol
  final UsersConfiguration? usersConfiguration;

  ///[onItemTap] callback triggered on tapping a user or group item
  final UserGroupBuilder? onItemTap;

  ///[GroupConfiguration] custom request groups request builder protocol
  final GroupsConfiguration? groupsConfiguration;

  ///[usersTabTitle] title text of user tab
  final String? usersTabTitle;

  ///[groupsTabTitle] title text of group tab
  final String? groupsTabTitle;

  ///[title] sets title for the list
  final String? title;

  ///[closeIcon] close icon widget
  final Widget? closeIcon;

  ///[contactsStyle] sets style
  final ContactsStyle? contactsStyle;

  ///[onClose] call function to be called on close button click
  final VoidCallback? onClose;

  ///[theme] set custom theme
  final CometChatTheme? theme;

  ///[onSubmitIconTap] triggered when clicked on submit icon
  final Function(BuildContext context, List<User>? selectedUsersList,
      List<Group>? selectedGroupsList)? onSubmitIconTap;

  ///[tabVisibility] parameter to alter visibility of different tabs
  final TabVisibility? tabVisibility;

  ///[submitIcon] triggered when clicked on submit icon
  final Widget? submitIcon;

  ///[selectionLimit] set the limit for maximum selection limit, default limit is 5
  final int? selectionLimit;

  ///[hideSubmitIcon] triggered when clicked on submit icon
  final bool? hideSubmitIcon;

  ///[SelectionMode] sets the selection mode
  final SelectionMode? selectionMode;

  ///[snackBarConfiguration] sets configuration properties for showing snackBar
  final SnackBarConfiguration? snackBarConfiguration;

  ContactsConfiguration merge(ContactsConfiguration mergeWith) {
    return ContactsConfiguration(
      usersConfiguration: usersConfiguration == null
          ? mergeWith.usersConfiguration
          : usersConfiguration!.merge(
              mergeWith.usersConfiguration ?? const UsersConfiguration()),
      onItemTap: onItemTap ?? mergeWith.onItemTap,
      groupsConfiguration: groupsConfiguration == null
          ? mergeWith.groupsConfiguration
          : groupsConfiguration!.merge(
              mergeWith.groupsConfiguration ?? const GroupsConfiguration()),
      usersTabTitle: usersTabTitle ?? mergeWith.usersTabTitle,
      groupsTabTitle: groupsTabTitle ?? mergeWith.groupsTabTitle,
      title: title ?? mergeWith.title,
      closeIcon: closeIcon ?? mergeWith.closeIcon,
      contactsStyle: contactsStyle ?? mergeWith.contactsStyle,
      onClose: onClose ?? mergeWith.onClose,
      theme: theme ?? mergeWith.theme,
      onSubmitIconTap: onSubmitIconTap ?? mergeWith.onSubmitIconTap,
      tabVisibility: tabVisibility ?? mergeWith.tabVisibility,
      submitIcon: submitIcon ?? mergeWith.submitIcon,
      selectionLimit: selectionLimit ?? mergeWith.selectionLimit,
      hideSubmitIcon: hideSubmitIcon ?? mergeWith.hideSubmitIcon,
      selectionMode: selectionMode ?? mergeWith.selectionMode,
      snackBarConfiguration:
          snackBarConfiguration ?? mergeWith.snackBarConfiguration,
    );
  }
}
