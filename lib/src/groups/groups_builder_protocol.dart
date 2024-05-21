import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[GroupsBuilderProtocol] is an interface that defines the structure for fetching the groups.
///It provides a generic [requestBuilder] property and methods [getRequest] and [getSearchRequest] that needs to be overridden.
abstract class GroupsBuilderProtocol
    extends BuilderProtocol<GroupsRequestBuilder, GroupsRequest> {
  const GroupsBuilderProtocol(super._builder);
}

///[UIGroupsBuilder] is the default [GroupsBuilderProtocol] used when a custom builder protocol is not passed
class UIGroupsBuilder extends GroupsBuilderProtocol {
  const UIGroupsBuilder(super._builder);

  @override
  GroupsRequest getRequest() {
    return requestBuilder.build();
  }

  @override
  GroupsRequest getSearchRequest(String val) {
    requestBuilder.searchKeyword = val;
    return requestBuilder.build();
  }
}
