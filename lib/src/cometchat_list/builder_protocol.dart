import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///[BuilderProtocol] is the Marker class to define protocols
///Used to generate different request builders
///T1 is the type of Request builder to be passed and T2 should be the respective request type
///eg for user list [T1] will be [UsersRequestBuilder] and [T2] will be [UsersRequest]
abstract class BuilderProtocol<T1, T2> {
  final T1 requestBuilder;

  const BuilderProtocol(this.requestBuilder);

  ///called for simple request
  T2 getRequest();

  ///called when implementing search
  T2 getSearchRequest(String val);
}
