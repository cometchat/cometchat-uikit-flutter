import '../../../../flutter_chat_ui_kit.dart';

///Configuration class to alter [CometChatGroups] properties from all parent widgets
///
/// ```dart
/// GroupsConfiguration(
///         hideCreateGroup: false,
///         showBackButton: true,
///         title: 'Groups',
///         hideSearch: false,
///         searchPlaceholder: 'Search',
///         groupListConfiguration: GroupListConfiguration(),
///       );
///```
///
class GroupsConfiguration {
  const GroupsConfiguration(
      {this.title,
      this.searchPlaceholder,
      this.showBackButton = true,
      this.hideSearch = false,
      this.hideCreateGroup = false,
      this.activeGroup,
      this.groupListConfiguration = const GroupListConfiguration()});

  ///[title] Title of the component
  final String? title;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[showBackButton] switch on/off back button
  final bool showBackButton;

  ///[hideSearch] switch on/ff search input
  final bool hideSearch;

  ///[hideCreateGroup] switch on/ff option to create group
  final bool hideCreateGroup;

  ///[activeGroup] selected group
  final String? activeGroup;

  ///[groupListConfiguration] group list configuration
  final GroupListConfiguration groupListConfiguration;
}
