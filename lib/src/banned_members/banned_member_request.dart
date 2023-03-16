import '../../../flutter_chat_ui_kit.dart';

abstract class UIBannedGroupMemberRequestBuilder {
  late BannedGroupMembersRequestBuilder requestBuilder;

  BannedGroupMembersRequest getRequest();

  BannedGroupMembersRequest getSearchRequest(String val);
}

class BannedGroupMemberRequestImplementer with UIBannedGroupMemberRequestBuilder {
  BannedGroupMemberRequestImplementer(BannedGroupMembersRequestBuilder _builder) {
    requestBuilder = _builder;
  }

  @override
  BannedGroupMembersRequest getRequest() {
    return requestBuilder.build();
  }

  @override
  BannedGroupMembersRequest getSearchRequest(String val) {
    requestBuilder.searchKeyword = val;
    return requestBuilder.build();
  }
}