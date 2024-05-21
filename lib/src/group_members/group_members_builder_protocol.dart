import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[GroupMembersBuilderProtocol] is an interface that defines the structure for fetching the group members.
///It provides a generic [requestBuilder] property and methods [getRequest] and [getSearchRequest] that needs to be overridden.
abstract class GroupMembersBuilderProtocol
    extends BuilderProtocol<GroupMembersRequestBuilder, GroupMembersRequest> {
  const GroupMembersBuilderProtocol(super._builder);
}

///[UIGroupMembersBuilder] is the default [GroupMembersBuilderProtocol] used when a custom builder protocol is not passed
class UIGroupMembersBuilder extends GroupMembersBuilderProtocol {
  const UIGroupMembersBuilder(super._builder);

  @override
  GroupMembersRequest getRequest() {
    return requestBuilder.build();
  }

  @override
  GroupMembersRequest getSearchRequest(String val) {
    requestBuilder.searchKeyword = val;
    return requestBuilder.build();
  }
}
