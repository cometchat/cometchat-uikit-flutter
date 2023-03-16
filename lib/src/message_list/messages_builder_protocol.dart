import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

abstract class MessagesBuilderProtocol
    extends BuilderProtocol<MessagesRequestBuilder, MessagesRequest> {
  const MessagesBuilderProtocol(MessagesRequestBuilder _builder)
      : super(_builder);
}

class UIMessagesBuilder extends MessagesBuilderProtocol {
  const UIMessagesBuilder(MessagesRequestBuilder _builder) : super(_builder);

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
