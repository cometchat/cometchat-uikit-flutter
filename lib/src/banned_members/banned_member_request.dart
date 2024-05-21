import '../../../cometchat_chat_uikit.dart';

/// [UIBannedGroupMemberRequestBuilder] is an interface that is used to construct the request body for fetching banned group members using [BannedGroupMembersRequestBuilder]
mixin UIBannedGroupMemberRequestBuilder {
  /// [requestBuilder] is an instance of [BannedGroupMembersRequestBuilder]
  late BannedGroupMembersRequestBuilder requestBuilder;

  /// [getRequest] method is used to get the request body for fetching banned group members
  BannedGroupMembersRequest getRequest();

  /// [getSearchRequest] method is used to get the request body for searching banned group members
  BannedGroupMembersRequest getSearchRequest(String val);
}

/// [BannedGroupMemberRequestImplementer] is a class that implements [UIBannedGroupMemberRequestBuilder] interface
class BannedGroupMemberRequestImplementer
    with UIBannedGroupMemberRequestBuilder {
  ///the constructor takes [BannedGroupMembersRequestBuilder] as parameter and assigns to [requestBuilder]
  BannedGroupMemberRequestImplementer(
      BannedGroupMembersRequestBuilder builder) {
    requestBuilder = builder;
  }

  /// [getRequest] method is used to get the request body for fetching banned group members
  @override
  BannedGroupMembersRequest getRequest() {
    return requestBuilder.build();
  }

  /// [getSearchRequest] method is used to get the request body for searching banned group members
  @override
  BannedGroupMembersRequest getSearchRequest(String val) {
    requestBuilder.searchKeyword = val;
    return requestBuilder.build();
  }
}
