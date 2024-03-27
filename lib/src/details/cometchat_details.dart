import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:get/get_state_manager/get_state_manager.dart';

///[CometChatDetails] is a mediator component that provides access to
///components for viewing, adding, banning group members if the [CometChatDetails] component is being shown for a [Group] and also components for transferring ownership and leaving the group
///and options for blocking and unblocking a user if the [CometChatDetails] component for a [User]
/// ```dart
///
///  for a User
///
///   CometChatDetails(
///   user: User(uid: 'uid', name: 'name'),
///   detailsStyle: DetailsStyle(),
///     addMemberConfiguration: AddMemberConfiguration(),
///    bannedMemberConfiguration: BannedMemberConfiguration(),
///    groupMembersConfiguration: GroupMembersConfiguration(),
///    transferOwnershipConfiguration: TransferOwnershipConfiguration(),
/// );
///
///  for a Group
///
/// CometChatDetails(
///   group: Group(guid: 'guid', name: 'name', type: 'public'),
///   detailsStyle: DetailsStyle(),
///     addMemberConfiguration: AddMemberConfiguration(),
///    bannedMemberConfiguration: BannedMemberConfiguration(),
///    groupMembersConfiguration: GroupMembersConfiguration(),
///    transferOwnershipConfiguration: TransferOwnershipConfiguration(),
/// );
///
/// ```
class CometChatDetails extends StatelessWidget {
  CometChatDetails(
      {Key? key,
      User? user,
      Group? group,
      this.title,
      this.detailsStyle,
      this.showCloseButton = true,
      this.closeButtonIcon,
      List<CometChatDetailsTemplate>? Function(Group? group, User? user)? data,
      GroupMembersConfiguration? groupMembersConfiguration,
      AddMemberConfiguration? addMemberConfiguration,
      TransferOwnershipConfiguration? transferOwnershipConfiguration,
      BannedMemberConfiguration? bannedMemberConfiguration,
      void Function(CometChatDetailsController)? stateCallBack,
      this.disableUsersPresence = false,
      this.appBarOptions,
      this.listItemStyle,
      this.avatarStyle,
      this.statusIndicatorStyle,
      this.subtitleView,
      this.hideProfile,
      this.customProfileView,
      this.protectedGroupIcon,
      this.privateGroupIcon,
      this.theme,
      this.onBack,
      ConfirmDialogStyle? leaveGroupDialogStyle,
      OnError? onError})
      : _cometChatDetailsController = CometChatDetailsController(user, group,
            stateCallBack: stateCallBack,
            addMemberConfiguration: addMemberConfiguration,
            transferOwnershipConfiguration: transferOwnershipConfiguration,
            data: data,
            leaveGroupDialogStyle: leaveGroupDialogStyle,
            onError: onError),
        super(key: key);

  ///to pass [CometChatDetails] header text use [title]
  final String? title;

  ///[detailsStyle] is used to pass styling properties
  final DetailsStyle? detailsStyle;

  ///[showCloseButton] toggles visibility for close button
  final bool? showCloseButton;

  ///to change [closeButtonIcon]
  final Icon? closeButtonIcon;

  ///[disableUsersPresence] controls visibility of status indicator
  final bool disableUsersPresence;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget>? appBarOptions;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[avatarStyle] set style for avatar
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[subtitleView] to set subtitle for each conversation
  final Widget? Function({User? user, Group? group, BuildContext context})?
      subtitleView;

  ///[hideProfile] hides view profile for users
  final bool? hideProfile;

  ///[protectedGroupIcon] provides icon in status indicator for protected group
  final Widget? protectedGroupIcon;

  ///[privateGroupIcon] provides icon in status indicator for private group
  final Widget? privateGroupIcon;

  ///[customProfileView] provides a customized view profile for users
  final Widget? customProfileView;

  ///[theme] custom theme
  final CometChatTheme? theme;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  final CometChatDetailsController _cometChatDetailsController;

  // class variables-----------------

  //initialization methods--------------

  _getProfile(BuildContext context,
      CometChatDetailsController detailsController, CometChatTheme theme) {
    Widget? subtitle;
    Color? backgroundColor;
    Widget? icon;
    User? user = detailsController.user;
    Group? group = detailsController.group;

    if (subtitleView != null) {
      subtitle = subtitleView!(user: user, group: group);
    } else {
      String subtitleText;
      if (user != null) {
        subtitleText = user.status ?? "";
      } else {
        subtitleText =
            "${detailsController.membersCount} ${Translations.of(context).members}";
      }
      subtitle = Text(subtitleText,
          style: TextStyle(
              fontSize: theme.typography.subtitle1.fontSize,
              fontWeight: theme.typography.subtitle1.fontWeight,
              fontFamily: theme.typography.subtitle1.fontFamily,
              color: theme.palette.getAccent600()));
    }
    if ((user != null && disableUsersPresence != true) || group != null) {
      StatusIndicatorUtils statusIndicatorUtils =
          StatusIndicatorUtils.getStatusIndicatorFromParams(
              isSelected: false,
              theme: theme,
              user: user,
              group: group,
              disableUsersPresence: disableUsersPresence,
              privateGroupIcon: privateGroupIcon,
              protectedGroupIcon: protectedGroupIcon,
              privateGroupIconBackground:
                  detailsStyle?.privateGroupIconBackground,
              protectedGroupIconBackground:
                  detailsStyle?.protectedGroupIconBackground,
              onlineStatusIndicatorColor: detailsStyle?.onlineStatusColor);

      backgroundColor = statusIndicatorUtils.statusIndicatorColor;
      icon = statusIndicatorUtils.icon;
    }

    return CometChatListItem(
      key: UniqueKey(),
      id: user?.uid ?? group?.guid,
      avatarName: user?.name ?? group?.name,
      avatarURL: user?.avatar ?? group?.icon,
      title: user?.name ?? group?.name,
      subtitleView: subtitle,
      statusIndicatorColor:
          disableUsersPresence == false ? backgroundColor : null,
      statusIndicatorStyle:
          statusIndicatorStyle ?? const StatusIndicatorStyle(),
      statusIndicatorIcon: icon,
      avatarStyle: AvatarStyle(
          height: avatarStyle?.height ?? 40,
          width: avatarStyle?.width ?? 40,
          background: avatarStyle?.background,
          border: avatarStyle?.border,
          borderRadius: avatarStyle?.borderRadius,
          gradient: avatarStyle?.gradient,
          nameTextStyle: avatarStyle?.nameTextStyle,
          outerBorderRadius: avatarStyle?.outerBorderRadius,
          outerViewBackgroundColor: avatarStyle?.outerViewBackgroundColor,
          outerViewBorder: avatarStyle?.outerViewBorder,
          outerViewSpacing: avatarStyle?.outerViewSpacing,
          outerViewWidth: avatarStyle?.outerViewWidth),
      style: ListItemStyle(
          background: listItemStyle?.background ?? Colors.transparent,
          titleStyle: TextStyle(
                  fontSize: theme.typography.name.fontSize,
                  fontWeight: theme.typography.name.fontWeight,
                  fontFamily: theme.typography.name.fontFamily,
                  color: theme.palette.getAccent())
              .merge(listItemStyle?.titleStyle),
          height: listItemStyle?.height ?? 72,
          border: listItemStyle?.border,
          borderRadius: listItemStyle?.borderRadius,
          gradient: listItemStyle?.gradient,
          separatorColor: listItemStyle?.separatorColor,
          width: listItemStyle?.width,
          padding: listItemStyle?.padding,
        margin: listItemStyle?.margin,
      ),
    );
  }

  _getListBaseChild(BuildContext context,
      CometChatDetailsController detailsController, CometChatTheme _theme) {
    detailsController.initializeSectionUtilities();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          if (hideProfile != true)
            customProfileView ??
                _getProfile(context, detailsController, _theme),
          const SizedBox(
            height: 15,
          ),
          _getListOfSectionData(context, detailsController, _theme)
        ],
      ),
    );
  }

  // section view components------------------
  Widget _getSectionData(BuildContext context, int index,
      CometChatDetailsController detailsController, CometChatTheme theme) {
    CometChatDetailsTemplate template = detailsController.templateList[index];
    String sectionId = template.id;

    if (detailsController.optionsMap[sectionId] == null ||
        detailsController.optionsMap[sectionId]!.isEmpty) {
      return const SizedBox();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (template.title != null && template.title != "")
        SizedBox(
          height: 16,
          child: Text(template.title!.toUpperCase(),
              style: TextStyle(
                      color: theme.palette.getAccent500(),
                      fontSize: theme.typography.text2.fontSize,
                      fontWeight: theme.typography.text2.fontWeight,
                      fontFamily: theme.typography.text2.fontFamily)
                  .merge(template.titleStyle)),
        ),
      ...List.generate(
          detailsController.optionsMap[sectionId]!.length,
          (index) =>
              _getOption(index, context, sectionId, detailsController, theme)),
      if (template.hideSectionSeparator == true &&
          index != detailsController.templateList.length - 1)
        Divider(
          thickness: 1,
          color: theme.palette.getAccent100(),
        )
    ]);
  }

  Widget _getOption(int index, BuildContext context, String sectionId,
      CometChatDetailsController detailsController, CometChatTheme theme) {
    CometChatDetailsOption option =
        detailsController.optionsMap[sectionId]![index];
    return option.customView ??
        SizedBox(
          height: option.height ?? 56,
          child: Center(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => detailsController.useOption(option, sectionId),
              title: Text(
                option.title ?? "",
                style: option.titleStyle ??
                    TextStyle(
                        fontFamily: theme.typography.name.fontFamily,
                        fontWeight: theme.typography.name.fontWeight,
                        color: sectionId ==
                                DetailsTemplateConstants.secondaryActions
                            ? theme.palette.getError()
                            : theme.palette.getPrimary()),
              ),
              trailing: option.tail,
            ),
          ),
        );
  }

  Widget _getListOfSectionData(BuildContext context,
      CometChatDetailsController detailsController, CometChatTheme theme) {
    return Column(children: [
      ...List.generate(detailsController.templateList.length,
          (index) => _getSectionData(context, index, detailsController, theme)),
      const SizedBox(
        height: 10,
      ),
      Divider(
        thickness: 1,
        color: theme.palette.getAccent100(),
      ),
    ]);
  }

  //view components end---------------

  @override
  Widget build(BuildContext context) {
    final CometChatTheme _theme = theme ?? cometChatTheme;
    return CometChatListBase(
        title: title ?? Translations.of(context).details,
        showBackButton: showCloseButton ?? true,
        backIcon: closeButtonIcon ??
            Icon(
              Icons.close,
              color: detailsStyle?.closeIconTint ?? _theme.palette.getPrimary(),
            ),
        hideSearch: true,
        menuOptions: [
          if (appBarOptions != null && appBarOptions!.isNotEmpty)
            ...appBarOptions!,
        ],
        theme: _theme,
        onBack: onBack,
        style: ListBaseStyle(
            height: detailsStyle?.height,
            width: detailsStyle?.width,
            border: detailsStyle?.border,
            borderRadius: detailsStyle?.borderRadius,
            background: detailsStyle?.gradient == null
                ? detailsStyle?.background
                : Colors.transparent,
            titleStyle: detailsStyle?.titleStyle,
            gradient: detailsStyle?.gradient),
        container: SizedBox(
            child: GetBuilder(
                init: _cometChatDetailsController,
                global: false,
                dispose: (GetBuilderState<CometChatDetailsController> state) =>
                    state.controller?.onClose(),
                builder: (CometChatDetailsController detailsController) {
                  detailsController.context = context;
                  detailsController.theme = _theme;
                  return _getListBaseChild(context, detailsController, _theme);
                })));
  }
}
