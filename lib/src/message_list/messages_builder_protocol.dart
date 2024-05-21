import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[MessagesBuilderProtocol] is an interface that defines the structure for fetching the messages.
///It provides a generic [requestBuilder] property and methods [getRequest] and [getSearchRequest] that needs to be overridden.
abstract class MessagesBuilderProtocol
    extends BuilderProtocol<MessagesRequestBuilder, MessagesRequest> {
  const MessagesBuilderProtocol(super._builder);
}

///[UIMessagesBuilder] is the default [MessagesBuilderProtocol] used when a custom builder protocol is not passed
class UIMessagesBuilder extends MessagesBuilderProtocol {
  const UIMessagesBuilder(super._builder);

  @override
  MessagesRequest getRequest() {
    return requestBuilder.build();
  }

  @override
  MessagesRequest getSearchRequest(String val) {
    requestBuilder.searchKeyword = val;
    return requestBuilder.build();
  }
}
