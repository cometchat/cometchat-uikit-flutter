import '../../../../flutter_chat_ui_kit.dart';
import '../framework/default_extension.dart';

class CometChatUIKit {
  static UIKitSettings? authenticationSettings;

  /// method initializes the settings required for CometChat
  ///
  /// We suggest you call the init() method on app startup
  ///
  /// its necessary to first populate authSettings inorder to call [init].
  static init(
      {required UIKitSettings authSettings,
      Function(String successMessage)? onSuccess,
      Function(CometChatException e)? onError}) async {
    //if (!checkAuthSettings(onError)) return;
    authenticationSettings = authSettings;
    AppSettings appSettings = (AppSettingsBuilder()
          ..subscriptionType = authenticationSettings?.subscriptionType ??
              CometChatSubscriptionType.allUsers
          ..region = authenticationSettings?.region
          ..autoEstablishSocketConnection =
              authenticationSettings?.autoEstablishSocketConnection ?? true)
        .build();

    await CometChat.init(authenticationSettings!.appId!, appSettings,
        onSuccess: (String successMessage) {
      if (onSuccess != null) onSuccess(successMessage);
    }, onError: (CometChatException exception) {
      if (onError != null) onError(exception);
    });
  }

  /// Use this function only for testing purpose. For production, use [loginWithAuthToken]
  static login(String uid,
      {Function(User user)? onSuccess,
      Function(CometChatException excep)? onError}) async {
    if (!checkAuthSettings(onError)) return;

    await CometChat.login(uid, authenticationSettings!.apiKey!,
        onSuccess: (User user) {
      if (onSuccess != null) {
        onSuccess(user);
      }

      _initiateAfterLogin();
    }, onError: onError);
  }

  ///Returns a  [User] object after login in CometChat API.
  ///
  /// The CometChat SDK maintains the session of the logged in user within the SDK.
  /// Thus you do not need to call the login method for every session. You can use the
  /// CometChat.getLoggedInUser() method to check if there is any existing session in the SDK.
  /// This method should return the details of the logged-in user.
  ///
  /// [Create an Auth Token](https://www.cometchat.com/docs/chat-apis/ref#createauthtoken) via the CometChat API
  /// for the new user every time the user logs in to your app
  ///
  ///
  ///  method could throw [PlatformException] with error codes specifying the cause
  static loginWithAuthToken(String authToken,
      {Function(User user)? onSuccess,
      Function(CometChatException excep)? onError}) async {
    await CometChat.loginWithAuthToken(authToken, onSuccess: (User user) {
      if (onSuccess != null) {
        onSuccess(user);
      }

      _initiateAfterLogin();
    }, onError: onError);
  }

  static _initiateAfterLogin() {
    List<ExtensionsDataSource> _extensionList =
        authenticationSettings?.extensions ?? DefaultExtensions.get();

    if (_extensionList.isNotEmpty) {
      for (var element in _extensionList) {
        element.enable();
      }
    }
  }

  ///Method returns user after creation in cometchat environment
  ///
  /// Ideally, user creation should take place at your backend
  ///
  /// [uid] specified on user creation. Not editable after that.
  ///
  /// [name] Display name of the user.
  ///
  /// [avatar] URL to profile picture of the user.
  static createUser(User user,
      {Function(User user)? onSuccess,
      Function(CometChatException e)? onError}) async {
    if (!checkAuthSettings(onError)) return;
    await CometChat.createUser(user, authenticationSettings!.apiKey!,
        onSuccess: onSuccess, onError: onError);
  }

  ///Updating a user similar to creating a user should ideally be achieved at your backend using the Restful APIs
  ///
  /// [user] a user object which user needs to be updated.
  ///
  /// method could throw [PlatformException] with error codes specifying the cause
  static updateUser(User user,
      {Function(User retUser)? onSuccess,
      Function(CometChatException excep)? onError}) async {
    if (!checkAuthSettings(onError)) return;

    await CometChat.updateUser(user, authenticationSettings!.apiKey!,
        onSuccess: onSuccess, onError: onError);
  }

  ///used to logout user
  ///
  /// method could throw [PlatformException] with error codes specifying the cause
  static logout(
      {Function(Map<String, Map<String, int>> message)? onSuccess,
      Function(CometChatException excep)? onError}) async {
    if (!checkAuthSettings(onError)) return;
    await CometChat.logout(onSuccess: onSuccess, onError: onError);
    ChatConfigurator.init();
  }

  static bool checkAuthSettings(Function(CometChatException e)? onError) {
    if (authenticationSettings == null) {
      if (onError != null) {
        onError(CometChatException("ERR", "Authentication null",
            "Populate authSettings before initializing"));
      }
      return false;
    }

    if (authenticationSettings!.appId == null) {
      if (onError != null) {
        onError(CometChatException("appIdErr", "APP ID null",
            "Populate appId in authSettings before initializing"));
      }
      return false;
    }
    return true;
  }

  //---------- Helper methods to send messages ----------
  ///[sendCustomMessage] used to send a custom message
  static sendCustomMessage(CustomMessage message) {
    CometChatMessageEvents.ccMessageSent(message, MessageStatus.inProgress);
    CometChat.sendCustomMessage(message, onSuccess: (CustomMessage message2) {
      CometChatMessageEvents.ccMessageSent(message2, MessageStatus.sent);
    }, onError: (error) {
      if (message.metadata != null) {
        message.metadata!["error"] = error;
      } else {
        message.metadata = {"error": error};
      }
      CometChatMessageEvents.ccMessageSent(message, MessageStatus.error);
    });
  }

  ///[sendTextMessage] used to send a text message
  static sendTextMessage(TextMessage message) {
    CometChatMessageEvents.ccMessageSent(message, MessageStatus.inProgress);
    CometChat.sendMessage(message, onSuccess: (BaseMessage message2) {
      CometChatMessageEvents.ccMessageSent(message2, MessageStatus.sent);
    }, onError: (error) {
      if (message.metadata != null) {
        message.metadata!["error"] = error;
      } else {
        message.metadata = {"error": error};
      }
      CometChatMessageEvents.ccMessageSent(message, MessageStatus.error);
    });
  }

  ///[sendMediaMessage] used to send a media message
  static sendMediaMessage(MediaMessage message) {
    CometChatMessageEvents.ccMessageSent(message, MessageStatus.inProgress);
    CometChat.sendMediaMessage(message, onSuccess: (BaseMessage message2) {
      CometChatMessageEvents.ccMessageSent(message2, MessageStatus.sent);
    }, onError: (error) {
      if (message.metadata != null) {
        message.metadata!["error"] = error;
      } else {
        message.metadata = {"error": error};
      }
      CometChatMessageEvents.ccMessageSent(message, MessageStatus.error);
    });
  }
}
