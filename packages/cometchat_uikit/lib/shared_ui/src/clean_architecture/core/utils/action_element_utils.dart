import 'dart:async';
import "package:cometchat_sdk/cometchat_sdk.dart" hide CardMessage;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/models/interactive_elements/base_interactive_element.dart';
import '../../data/models/interactive_actions/api_action.dart';
import '../../data/models/interactive_actions/url_navigation_action.dart';
import '../constants/ui_kit_constants.dart';
import '../../presentation/views/misc/web_view/web_view_style.dart';
import '../../presentation/views/misc/web_view/cometchat_web_view.dart';
import '../../../utils/network_utils.dart';
import '../../../logging/cometchat_log.dart';

class ActionElementUtils {
  static final defaultHeader = {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  static Future<bool> performAction({
    BuildContext? context,
    required BaseInteractiveElement element,
    Map<String, dynamic>? body,
    WebViewStyle? style,
    required int messageId,
  }) async {
    if (element.action?.actionType == ActionTypeConstants.apiAction) {
      if (element.action == null) return false;
      APIAction apiAction = element.action! as APIAction;
      Map<String, dynamic> requestBody = body ?? {};

      http.Response? response;
      await Future.delayed(const Duration(seconds: 2));

      switch (apiAction.method.toUpperCase()) {
        case APIRequestTypeConstants.put:
          response = await NetworkUtils.put(
            apiAction.url,
            apiAction.headers ?? defaultHeader,
            requestBody,
          );
          break;
        case APIRequestTypeConstants.post:
          response = await NetworkUtils.postData(
            apiAction.url,
            apiAction.headers ?? defaultHeader,
            requestBody,
          );
          break;
        case APIRequestTypeConstants.delete:
          response = await NetworkUtils.delete(
            apiAction.url,
            apiAction.headers ?? defaultHeader,
            requestBody,
          );
          break;
        case APIRequestTypeConstants.patch:
          response = await NetworkUtils.patchData(
            apiAction.url,
            apiAction.headers ?? defaultHeader,
            requestBody,
          );
          break;
      }

      if (response != null) {
        if (response.statusCode == 200) {
          await CometChat.markAsInteracted(
            messageId,
            element.elementId,
            onSuccess: (String res) {},
            onError: (CometChatException e) {},
          );
          return true;
        } else {
          if (kDebugMode) {
            ccLog(
              "Error in API Action ${response.statusCode} ${response.body}",
            );
          }
          return false;
        }
      }
    } else if (element.action?.actionType ==
        ActionTypeConstants.urlNavigation) {
      URLNavigationAction apiNavigationAction =
          element.action! as URLNavigationAction;

      if (context != null) {
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CometChatWebView(
                title: "WEB",
                webViewUrl: apiNavigationAction.url,
                webViewStyle: const WebViewStyle(),
              ),
            ),
          ),
        );
      }

      return true;
    }
    return false;
  }
}
