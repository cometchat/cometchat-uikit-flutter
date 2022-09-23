import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///Configuration class to alter [CometChatGroupList] properties from all parent widgets
///
///```dart
/// GroupListConfiguration(
///         limit: 30,
///         joinedOnly: false,
///         tags: ['abc'],
///         hideError: false,
///         searchKeyword: '',
///         errorText: 'Something went wrong',
///         emptyText: 'No Groups',
///         customView: CustomView(
///             loading: Center(child: CircularProgressIndicator()),
///             empty: Center(
///               child: Text('No Groups'),
///             ),
///             error: Center(
///                child: Text('Something went wrong'),
///             )),
///         dataItemConfiguration: DataItemConfiguration(
///             avatarConfiguration: AvatarConfiguration(),
///             statusIndicatorConfiguration:
///             StatusIndicatorConfiguration(),
///             inputData: InputData(
///                   status: true,
///                   thumbnail: true,
///                   title: true,
///                    subtitle: (Group group) {
///                     return group.membersCount.toString();
///                   })),
///       );
///```
class GroupListConfiguration {
  const GroupListConfiguration(
      {this.limit = 30,
      this.searchKeyword,
      this.tags = const [],
      this.emptyText,
      this.errorText,
      this.customView = const CustomView(),
      this.hideError = false,
      this.joinedOnly = false,
      this.dataItemConfiguration = const DataItemConfiguration()});

  ///[limit] number of groups that should be fetched in a single iteration
  final int limit;

  ///[searchKeyword] set predefined search keyword
  final String? searchKeyword;

  ///[tags] list of tags based on which the list of groups is to be fetched
  final List<String> tags;

  ///[emptyText]text to be displayed when the list is empty
  final String? emptyText;

  ///[errorText] text to be displayed when the list has encountered any error
  final String? errorText;

  ///[customView] custom widgets for loading,error,empty
  ///allows you to embed a custom view/component for loading, empty and error state.
  ///If no value is set, default view will be rendered.
  final CustomView customView;

  ///[hideError] toggle visibility of any error in case there is any
  final bool hideError;

  ///[joinedOnly] if set true [CometChatGroupList] will only fetch joined groups
  final bool joinedOnly;

  ///[dataItemConfiguration] data item configuration
  ///DataItemConfiguration(
  ///   avatarConfiguration: AvatarConfiguration(),
  ///   statusIndicatorConfiguration:
  ///     StatusIndicatorConfiguration(),
  ///   inputData: InputData(
  ///     status: true,
  ///     thumbnail: true,
  ///     title: true,
  ///     subtitle: (Group group) {
  ///       return group.membersCount.toString();
  ///     })),
  final DataItemConfiguration<Group>? dataItemConfiguration;
}
