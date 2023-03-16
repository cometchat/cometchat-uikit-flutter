import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

abstract class GroupsBuilderProtocol
    extends BuilderProtocol<GroupsRequestBuilder, GroupsRequest> {
  const GroupsBuilderProtocol(GroupsRequestBuilder _builder) : super(_builder);
}

class UIGroupsBuilder extends GroupsBuilderProtocol {
  const UIGroupsBuilder(GroupsRequestBuilder _builder) : super(_builder);

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
