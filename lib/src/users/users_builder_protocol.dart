import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

abstract class UsersBuilderProtocol
    extends BuilderProtocol<UsersRequestBuilder, UsersRequest> {
  const UsersBuilderProtocol(UsersRequestBuilder _builder) : super(_builder);
}

class UIUsersBuilder extends UsersBuilderProtocol {
  const UIUsersBuilder(UsersRequestBuilder _builder) : super(_builder);

  @override
  UsersRequest getRequest() {
    return requestBuilder.build();
  }

  @override
  UsersRequest getSearchRequest(String val) {
    requestBuilder.searchKeyword = val;
    return requestBuilder.build();
  }
}
