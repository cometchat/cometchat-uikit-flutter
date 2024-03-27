import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../../../cometchat_chat_uikit.dart';

///[TextModerationExtension] is the controller class for enabling and disabling the extension
///the extension censors out abusive words and sensitive information such as personal details, email ids
class TextModerationExtension extends ExtensionsDataSource {
  TextModerationConfiguration? configuration;
  TextModerationExtension({this.configuration});

  @override
  void enable(
      {Function(bool success)? onSuccess,
      Function(CometChatException exception)? onError}) async {
    List<Future<bool?>> extensionList = [
      CometChat.isExtensionEnabled("profanity-filter",
          onSuccess: (bool success) {
        debugPrint("profanity-filter has been enabled on dashboard");
      }, onError: (CometChatException exception) {
        if (onError != null) {
          onError(exception);
        }
        if (kDebugMode) {
          debugPrint(
              "Exception occurred while enabling profanity-filter extension: ${exception.details}");
        }
      }),
      CometChat.isExtensionEnabled("data-masking", onSuccess: (bool success) {
        debugPrint("data-masking has been enabled on dashboard");
      }, onError: (CometChatException exception) {
        if (onError != null) {
          onError(exception);
        }
        if (kDebugMode) {
          debugPrint(
              "Exception occurred while enabling  data-masking extension: ${exception.details}");
        }
      })
    ];
    List<bool?> results = await Future.wait(extensionList);
    if (results.contains(true)) {
      addExtension();

      if (onSuccess != null) {
        onSuccess(true);
      }
    }
  }

  @override
  void addExtension() {
    ChatConfigurator.enable((dataSource) => TextModerationExtensionDecorator(
        dataSource,
        configuration: configuration));
  }

  @override
  String getExtensionId() {
    return "data-masking";
  }
}
