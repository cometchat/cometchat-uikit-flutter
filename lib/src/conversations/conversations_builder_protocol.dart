import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

abstract class ConversationsBuilderProtocol
    extends BuilderProtocol<ConversationsRequestBuilder, ConversationsRequest> {
  const ConversationsBuilderProtocol(ConversationsRequestBuilder _builder) : super(_builder);
}

class UIConversationsBuilder extends ConversationsBuilderProtocol {
  const UIConversationsBuilder(ConversationsRequestBuilder _builder) : super(_builder);

  @override
  ConversationsRequest getRequest() {
    return requestBuilder.build();
  }

  @override
  ConversationsRequest getSearchRequest(String val) {
    // requestBuilder.searchKeyword = val;
    return requestBuilder.build();
  }
}
