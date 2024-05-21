import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[UsersBuilderProtocol] is an interface that defines the structure for fetching the users.
///It provides a generic [requestBuilder] property and methods [getRequest] and [getSearchRequest] that needs to be overridden.
abstract class UsersBuilderProtocol
    extends BuilderProtocol<UsersRequestBuilder, UsersRequest> {
  const UsersBuilderProtocol(super._builder);
}

///[UIUsersBuilder] is the default [UsersBuilderProtocol] used when a custom builder protocol is not passed
class UIUsersBuilder extends UsersBuilderProtocol {
  const UIUsersBuilder(super._builder);

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
