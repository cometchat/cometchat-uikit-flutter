import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

abstract class BannedMemberBuilderProtocol extends BuilderProtocol<
    BannedGroupMembersRequestBuilder, BannedGroupMembersRequest> {
  const BannedMemberBuilderProtocol(super.builder);
}

class UIBannedMemberBuilder extends BannedMemberBuilderProtocol {
  const UIBannedMemberBuilder(super.builder);

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
