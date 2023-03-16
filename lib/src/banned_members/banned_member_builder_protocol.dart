import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

abstract class BannedMemberBuilderProtocol extends BuilderProtocol<
    BannedGroupMembersRequestBuilder, BannedGroupMembersRequest> {
  const BannedMemberBuilderProtocol(BannedGroupMembersRequestBuilder _builder)
      : super(_builder);
}

class UIBannedMemberBuilder extends BannedMemberBuilderProtocol {
  const UIBannedMemberBuilder(BannedGroupMembersRequestBuilder _builder)
      : super(_builder);

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
