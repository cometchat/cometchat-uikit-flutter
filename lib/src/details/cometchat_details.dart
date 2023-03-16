import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:get/get_state_manager/get_state_manager.dart';

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
      GroupMembersConfiguration? viewMembersConfiguration,
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
      OnError? onError})
      : _cometChatDetailsController = CometChatDetailsController(user, group,
            stateCallBack: stateCallBack,
            addMemberConfiguration: addMemberConfiguration,
            transferOwnershipConfiguration: transferOwnershipConfiguration,
            data: data,
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
      CometChatDetailsController detailsController, CometChatTheme _theme) {
    Widget? _subtitle;
    Color? backgroundColor;
    Widget? icon;
    User? user = detailsController.user;
    Group? group = detailsController.group;

    if (subtitleView != null) {
      _subtitle = subtitleView!(user: user, group: group);
    } else {
      String subtitleText;
      if (user != null) {
        subtitleText = user.status ?? "";
      } else {
        subtitleText =
            "${detailsController.membersCount} ${Translations.of(context).members}";
      }
      _subtitle = Text(subtitleText,
          style: TextStyle(
              fontSize: _theme.typography.subtitle1.fontSize,
              fontWeight: _theme.typography.subtitle1.fontWeight,
              fontFamily: _theme.typography.subtitle1.fontFamily,
              color: _theme.palette.getAccent600()));
    }
    if ((user != null && disableUsersPresence != true) || group != null) {
      StatusIndicatorUtils statusIndicatorUtils =
          StatusIndicatorUtils.getStatusIndicatorFromParams(
              isSelected: false,
              theme: _theme,
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
      subtitleView: _subtitle,
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
                  fontSize: _theme.typography.name.fontSize,
                  fontWeight: _theme.typography.name.fontWeight,
                  fontFamily: _theme.typography.name.fontFamily,
                  color: _theme.palette.getAccent())
              .merge(listItemStyle?.titleStyle),
          height: listItemStyle?.height ?? 72,
          border: listItemStyle?.border,
          borderRadius: listItemStyle?.borderRadius,
          gradient: listItemStyle?.gradient,
          separatorColor: listItemStyle?.separatorColor,
          width: listItemStyle?.width),
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
      CometChatDetailsController detailsController, CometChatTheme _theme) {
    CometChatDetailsTemplate _template = detailsController.templateList[index];
    String _sectionId = _template.id;

    if (detailsController.optionsMap[_sectionId] == null ||
        detailsController.optionsMap[_sectionId]!.isEmpty) {
      return const SizedBox();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_template.title != null && _template.title != "")
        SizedBox(
          height: 16,
          child: Text(_template.title!.toUpperCase(),
              style: TextStyle(
                      color: _theme.palette.getAccent500(),
                      fontSize: _theme.typography.text2.fontSize,
                      fontWeight: _theme.typography.text2.fontWeight,
                      fontFamily: _theme.typography.text2.fontFamily)
                  .merge(_template.titleStyle)),
        ),
      ...List.generate(
          detailsController.optionsMap[_sectionId]!.length,
          (index) => _getOption(
              index, context, _sectionId, detailsController, _theme)),
      if (_template.hideSectionSeparator == true &&
          index != detailsController.templateList.length - 1)
        Divider(
          thickness: 1,
          color: _theme.palette.getAccent100(),
        )
    ]);
  }

  Widget _getOption(int index, BuildContext context, String sectionId,
      CometChatDetailsController detailsController, CometChatTheme _theme) {
    CometChatDetailsOption _option =
        detailsController.optionsMap[sectionId]![index];
    return _option.customView ??
        SizedBox(
          height: _option.height ?? 56,
          child: Center(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => detailsController.useOption(_option, sectionId),
              title: Text(
                _option.title ?? "",
                style: _option.titleStyle ??
                    TextStyle(
                        fontFamily: _theme.typography.name.fontFamily,
                        fontWeight: _theme.typography.name.fontWeight,
                        color: sectionId ==
                                DetailsTemplateConstants.destructiveActions
                            ? _theme.palette.getError()
                            : _theme.palette.getPrimary()),
              ),
              trailing: _option.tail,
            ),
          ),
        );
  }

  Widget _getListOfSectionData(BuildContext context,
      CometChatDetailsController detailsController, CometChatTheme _theme) {
    return Column(children: [
      ...List.generate(
          detailsController.templateList.length,
          (index) =>
              _getSectionData(context, index, detailsController, _theme)),
      const SizedBox(
        height: 10,
      ),
      Divider(
        thickness: 1,
        color: _theme.palette.getAccent100(),
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
