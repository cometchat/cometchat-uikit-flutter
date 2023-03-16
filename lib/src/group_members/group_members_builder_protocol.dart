import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

abstract class GroupMembersBuilderProtocol
    extends BuilderProtocol<GroupMembersRequestBuilder, GroupMembersRequest> {
  const GroupMembersBuilderProtocol(GroupMembersRequestBuilder _builder)
      : super(_builder);
}

class UIGroupMembersBuilder extends GroupMembersBuilderProtocol {
  const UIGroupMembersBuilder(GroupMembersRequestBuilder _builder)
      : super(_builder);

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
