import 'package:flutter/material.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import '../../flutter_chat_ui_kit.dart';

///[CometChatAddMembers] is a container component that wraps and formats  [CometChatUsers]  component
///it list down users according to different parameter set in order of recent activity and select users on click
///
///

class CometChatAddMembers extends StatelessWidget {
  CometChatAddMembers(
      {Key? key,
      this.title,
      this.searchPlaceholder,
      this.backButton,
      this.showBackButton = true,
      this.searchIcon,
      this.hideSearch = false,
      this.theme,
      this.onSelection,
      required Group group,
      this.style,
      this.subtitleView,
      this.disableUsersPresence,
      this.listItemView,
      this.options,
      this.hideSeparator,
      this.appBarOptions,
      this.selectionMode = SelectionMode.multiple,
      this.errorStateText,
      this.emptyStateText,
      this.usersRequestBuilder,
      this.usersProtocol,
      this.hideError,
      this.loadingStateView,
      this.emptyStateView,
      this.errorStateView,
      this.onBack,
      this.selectionIcon})
      : _cometChatAddMembersController =
            CometChatAddMembersController(group: group),
        super(key: key);

  ///[title] Title of the component
  final String? title;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[backButton] back button widget
  final Widget? backButton;

  ///[showBackButton] switch visibility of back button
  final bool showBackButton;

  ///[searchIcon] replace search icon
  final Widget? searchIcon;

  ///[hideSearch] switch visibility of search input
  final bool? hideSearch;

  ///[theme] set custom theme
  final CometChatTheme? theme;

  ///[onSelection] method will be performed on complete selection
  final Function(List<User>?, BuildContext)? onSelection;

  ///[style] provides styling to this widget
  final AddMembersStyle? style;

  ///[subtitleView] provides custom view for subtitle in list item
  final Widget? Function(BuildContext, User)? subtitleView;

  ///[disableUsersPresence] controls visibility of status indicator shown if user is online
  final bool? disableUsersPresence;

  ///[listItemView] provides custom view for list item
  final Widget Function(User)? listItemView;

  ///[appBarOptions] custom options shown in the app bar
  final List<Widget> Function(BuildContext context)? appBarOptions;

  ///[options] are the actions available on swiping the user item
  final List<CometChatOption>? Function(
      User, CometChatUsersController controller)? options;

  ///[hideSeparator] controls visibility of the separator
  final bool? hideSeparator;

  ///[selectionMode] specifies mode users module is opening in
  final SelectionMode selectionMode;

  ///[emptyStateText] text to be displayed when the list is empty
  final String? emptyStateText;

  ///[errorStateText] text to be displayed when error occurs
  final String? errorStateText;

  ///[loadingStateView] returns view fow loading state
  final WidgetBuilder? loadingStateView;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[errorStateView] returns view fow error state behind the dialog
  final WidgetBuilder? errorStateView;

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[usersRequestBuilder] custom request builder
  final UsersRequestBuilder? usersRequestBuilder;

  ///[usersProtocol] set custom request builder
  final UsersBuilderProtocol? usersProtocol;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[selectionIcon] will override the default selection complete icon
  final Widget? selectionIcon;

  final CometChatAddMembersController _cometChatAddMembersController;

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
        init: _cometChatAddMembersController,
        global: false,
        dispose: (GetBuilderState<CometChatAddMembersController> state) =>
            state.controller?.onClose(),
        builder: (CometChatAddMembersController controller) {
          return CometChatUsers(
            theme: theme,
            title: title ?? Translations.of(context).add_members,
            showBackButton: showBackButton,
            hideSearch: hideSearch ?? false,
            searchPlaceholder: searchPlaceholder,
            selectionMode: selectionMode,
            onSelection: onSelection ?? controller.addMember,
            backButton: backButton,
            onBack: onBack,
            searchBoxIcon: searchIcon,
            usersStyle: UsersStyle(
                titleStyle: style?.titleStyle,
                border: style?.border,
                gradient: style?.gradient,
                backIconTint: style?.backIconTint,
                searchBackground: style?.searchBackground,
                searchPlaceholderStyle: style?.placeholderStyle,
                searchTextStyle: style?.searchStyle,
                searchIconTint: style?.searchIconTint,
                borderRadius: style?.borderRadius,
                background: style?.background,
                height: style?.height,
                width: style?.width,
                searchBorderColor: style?.searchBorderColor,
                searchBorderRadius: style?.searchBorderRadius,
                searchBorderWidth: style?.searchBorderWidth,
                errorTextStyle: style?.errorStateTextStyle,
                emptyTextStyle: style?.emptyStateTextStyle),
            appBarOptions: appBarOptions,
            listItemView: listItemView,
            hideSeparator: hideSeparator,
            subtitleView: subtitleView,
            disableUsersPresence: disableUsersPresence,
            options: options,
            errorStateText: errorStateText,
            emptyStateText: emptyStateText,
            errorStateView: errorStateView,
            emptyStateView: emptyStateView,
            loadingStateView: loadingStateView,
            usersRequestBuilder: usersRequestBuilder,
            usersProtocol: usersProtocol,
            hideError: hideError,
            activateSelection: ActivateSelection.onClick,
            selectionIcon: selectionIcon,
          );
        });
  }
}
