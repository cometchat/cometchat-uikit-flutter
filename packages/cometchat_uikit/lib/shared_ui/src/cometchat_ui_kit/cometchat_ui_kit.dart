import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../cometchat_uikit_shared.dart';
import '../../../src/calls_lifecycle.dart';
import '../../../src/calls_sdk_session.dart';
import '../../../src/chat_auth_gateway.dart';
import '../utils/sdk_methods.dart' as legacy_sdk;
import '../utils/timezone_utils/data/latest.dart';
import '../clean_architecture/core/constants/enums.dart' as core_enums;
import '../constants/ui_kit_constants.dart' as chat_ui_kit_constants;
import '../logging/cometchat_log.dart';
import '../clean_architecture/data/models/interactive_message/card_message.dart'
    as legacy_card;

class CometChatUIKit {
  static UIKitSettings? authenticationSettings;

  static User? loggedInUser;

  static String localTimeZoneIdentifier = "";

  static String localTimeZoneName = "";

  static ConversationUpdateSettings? conversationUpdateSettings;

  /// Whether the UIKit was initialized via [initFromSettings] (the AI-agent /
  /// skills path). Read when the UI Kit initialises the Calls SDK, to route it
  /// through its telemetry-aware `CometChatCalls.initFromSettings` so
  /// integrationSource = "ai-agent" propagates past the Chat SDK (ENG-37368).
  /// The plain [init] path sets this back to false and the Calls SDK uses its
  /// plain init ("manual").
  static bool initializedFromSettings = false;

  /// method initializes the settings required for CometChat
  ///
  /// We suggest you call the init() method on app startup
  ///
  /// its necessary to first populate uiKitSettings inorder to call [init].
  ///
  /// With `UIKitSettings.enableCalls`, [onSuccess] is called once the Calls
  /// SDK is initialised too and, when a logged-in session was restored, the
  /// user is logged into it, as in the Android UI Kit. That wait is bounded
  /// (10 s for the init, about 22 s with the login). A Calls SDK failure or
  /// timeout never turns into [onError]: [onSuccess] still follows, and the
  /// Calls SDK is set up again when a call needs it. The returned future
  /// completes after [onSuccess] or [onError] has been called.
  static Future<void> init({
    required UIKitSettings uiKitSettings,
    Function(String successMessage)? onSuccess,
    Function(CometChatException e)? onError,
  }) => _init(
    uiKitSettings: uiKitSettings,
    fromSettings: false,
    onSuccess: onSuccess,
    onError: onError,
  );

  /// [init], recording whether it came through [initFromSettings]. The flag
  /// is set before anything else, because a restored session sets up the
  /// Calls SDK from init's onSuccess and needs to know which Calls init to
  /// use; a plain [init] after [initFromSettings] clears it again.
  static Future<void> _init({
    required UIKitSettings uiKitSettings,
    required bool fromSettings,
    Function(String successMessage)? onSuccess,
    Function(CometChatException e)? onError,
  }) async {
    //if (!checkAuthSettings(onError)) return;
    initializedFromSettings = fromSettings;
    authenticationSettings = uiKitSettings;

    // Register UIKit component BEFORE SDK init so that session restoration
    // (which fires sendIfNeeded immediately) includes the uikit block in the
    // telemetry payload. Previously this was registered in the onSuccess
    // callback which runs AFTER session restoration telemetry.
    SdkIdentification.registerComponent(
      const SessionComponentInfo(
        key: 'uikit',
        platform: chat_ui_kit_constants.SetSourceConstant.platform,
        version: chat_ui_kit_constants.SetSourceConstant.version,
      ),
    );

    // Follows a host's direct CometChat.login/logout, so call handling is
    // started and stopped for the right user even when CometChatUIKit is
    // bypassed. It only acts when enableCalls is on. Idempotent.
    CallsLifecycle.attachLoginListener();

    AppSettings appSettings =
        (AppSettingsBuilder()
              ..subscriptionType =
                  authenticationSettings?.subscriptionType ??
                  CometChatSubscriptionType.allUsers
              ..region = authenticationSettings?.region
              ..autoEstablishSocketConnection =
                  authenticationSettings?.autoEstablishSocketConnection ?? true
              ..adminHost = authenticationSettings?.adminHost
              ..clientHost = authenticationSettings?.clientHost)
            .build();

    // The chat SDK calls onSuccess without awaiting it. Keep what it starts,
    // so this future completes only once the host's onSuccess has run.
    Future<void>? succeeded;
    await ChatAuthGateway.instance.init(
      authenticationSettings!.appId!,
      appSettings,
      onSuccess: (String successMessage) {
        succeeded = _afterInit(successMessage, onSuccess);
      },
      onError: (CometChatException exception) {
        //executing custom onError handler when CometChat SDK could not be initialized
        if (onError != null) {
          try {
            onError(exception);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "CometChat SDK could not be initialized and failed to execute onError callback",
              );
            }
          }
        }
      },
    );
    await succeeded;
  }

  /// What [init] runs once the chat SDK is initialised, before it tells the
  /// host: restore a logged-in session, and with `enableCalls` set up the
  /// Calls SDK too (init, plus the login for a restored session), within a
  /// time limit. The host's onSuccess follows even when the Calls SDK
  /// failed or timed out. Never throws.
  static Future<void> _afterInit(
    String successMessage,
    Function(String successMessage)? onSuccess,
  ) async {
    Future<void>? callsReady;
    try {
      final User? user = await getLoggedInUser();
      if (user != null) {
        CometChatUIKit.loggedInUser = user;
        callsReady = _initiateAfterLogin(user);
      } else {
        if (CallsLifecycle.isStarted) {
          // Call handling is still up for a user the chat SDK no longer has:
          // an init with another app id logs the user out without telling
          // any login listener. Stop it and log the Calls SDK out (bounded,
          // not waited for).
          ccLog(
            'CometChatUIKit.init: no session any more; stopping call '
            'handling for ${CallsLifecycle.uid}',
          );
          unawaited(CallsLifecycle.shutdown());
        }
        callsReady = CallsLifecycle.readyForHost(null);
      }
      getConversationUpdateSettings();
    } catch (e) {
      ccLog('CometChatUIKit.init: restoring the session failed: $e');
    }
    if (callsReady != null) await callsReady;

    //executing custom onSuccess handler when CometChat SDK is initialized successfully
    _runHostCallback(
      () => onSuccess?.call(successMessage),
      "CometChat SDK is initialized successfully but failed to execute onSuccess callback",
    );

    unawaited(
      CometChat.setSource(
        chat_ui_kit_constants.SetSourceConstant.uiKitVersion,
        kIsWeb ? 'web' : _nativePlatformName(),
        chat_ui_kit_constants.SetSourceConstant.platform,
      ),
    );
  }

  /// Initializes the UIKit from `cometchat-settings.json` asset file.
  ///
  /// Reads the settings file from the app's asset bundle, parses the `uiKit`
  /// section to configure UIKitSettings, and delegates to the Chat SDK's
  /// `init()` method. Also persists `integrationSource = "ai-agent"` for
  /// telemetry attribution via the Chat SDK.
  ///
  /// The `cometchat-settings.json` file must be placed at the project root
  /// and registered in `pubspec.yaml`:
  /// ```yaml
  /// flutter:
  ///   assets:
  ///     - cometchat-settings.json
  /// ```
  ///
  /// @nodoc
  static Future<void> initFromSettings({
    Function(String successMessage)? onSuccess,
    Function(CometChatException e)? onError,
  }) async {
    try {
      // 1. Read cometchat-settings.json to extract UIKit-level config
      String jsonString;
      try {
        jsonString = await rootBundle.loadString('cometchat-settings.json');
      } catch (e) {
        final error = CometChatException(
          'ERR_INIT_FAILED',
          'cometchat-settings.json not found',
          'cometchat-settings.json not found. Ensure the file exists at the '
              'project root and is registered in pubspec.yaml under flutter: assets:.',
        );
        if (onError != null) onError(error);
        return;
      }

      // 2. Parse JSON
      Map<String, dynamic> json;
      try {
        json = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        final error = CometChatException(
          'ERR_INIT_FAILED',
          'Invalid JSON',
          'cometchat-settings.json is not valid JSON.',
        );
        if (onError != null) onError(error);
        return;
      }

      // 3. Extract fields for UIKitSettings
      final appId = json['appId'] as String?;
      final region = json['region'] as String?;
      String? authKey;
      final credentials = json['credentials'];
      if (credentials is Map<String, dynamic>) {
        authKey = credentials['authKey'] as String?;
      }

      // Parse uiKit section
      final uiKitSection = json['uiKit'] as Map<String, dynamic>? ?? {};
      final subscribePresenceForAllUsers =
          uiKitSection['subscribePresenceForAllUsers'] as bool? ?? true;
      // Calling toggle for the file-based path (ENG-37368) — without this the
      // settings door could never initialize the Calls SDK at all (UIKitSettings
      // defaults enableCalls to false and the file is the only input here).
      // Key name matches the Android UIKit's settings schema (uiKit.enableCalling).
      final enableCalling = uiKitSection['enableCalling'] as bool? ?? false;

      // Parse chatSDK section for host overrides
      final chatSdkSection = json['chatSDK'] as Map<String, dynamic>? ?? {};
      final autoEstablishSocketConnection =
          chatSdkSection['autoEstablishSocketConnection'] as bool? ?? true;
      final adminHost = chatSdkSection['adminHost'] as String?;
      final clientHost = chatSdkSection['clientHost'] as String?;

      // 4. Build UIKitSettings from the parsed file
      final builder = UIKitSettingsBuilder()
        ..appId = appId
        ..region = region
        ..authKey = authKey
        ..subscriptionType = subscribePresenceForAllUsers
            ? CometChatSubscriptionType.allUsers
            : null
        ..autoEstablishSocketConnection = autoEstablishSocketConnection
        ..adminHost = adminHost
        ..clientHost = clientHost
        ..enableCalls = enableCalling;

      final uiKitSettings = builder.build();

      // 5. Delegate to regular init with the built settings. It sets the
      // door flag first: with a restored session, init's onSuccess sets up
      // the Calls SDK, whose routing must already know it came from settings.
      await _init(
        uiKitSettings: uiKitSettings,
        fromSettings: true,
        onSuccess: (String successMessage) {
          // Mark integration source as ai-agent for file-based init
          CometChat.setIntegrationSource('ai-agent');
          if (onSuccess != null) onSuccess(successMessage);
        },
        onError: onError,
      );
    } catch (e) {
      final error = CometChatException(
        'ERR_INIT_FAILED',
        e.toString(),
        'Failed to initialize from settings: ${e.toString()}',
      );
      if (onError != null) onError(error);
    }
  }

  /// Use this function only for testing purpose. For production, use [loginWithAuthToken]
  ///
  /// When another user is logged in, their calls are cleaned up first, as
  /// [logout] does (declined, cancelled or ended on the server within about
  /// 3 s, then closed locally), before the chat SDK logs [uid] in.
  ///
  /// With `UIKitSettings.enableCalls`, [onSuccess] is called once the Calls
  /// SDK is also initialised and the user logged into it, as in the Android
  /// UI Kit. That wait is bounded (about 22 s at most). A Calls SDK failure
  /// or timeout never turns into [onError]: [onSuccess] still follows, and
  /// the Calls SDK is set up again when a call needs it. The same applies
  /// when [uid] is already logged in. The returned future completes after
  /// [onSuccess] or [onError] has been called.
  static Future<User?> login(
    String uid, {
    Function(User user)? onSuccess,
    Function(CometChatException excep)? onError,
  }) async {
    if (!checkAuthSettings(onError)) return null;
    User? loggedInUser = await getLoggedInUser();

    if (loggedInUser == null || loggedInUser.uid != uid) {
      if (loggedInUser != null) {
        // Another user is logged in and this login replaces them. End their
        // calls first, as logout does, while they can still be heard:
        // after the login anything sent goes out as the new user. Call
        // handling itself is switched over once the new user is in.
        try {
          await CallsLifecycle.prepareForLogout();
        } catch (e) {
          ccLog('CometChatUIKit.login: call clean-up failed: $e');
        }
      }
      // The chat SDK calls onSuccess without awaiting it. Keep what it
      // starts, so this future completes only once the host's onSuccess ran.
      Future<void>? succeeded;
      User? user = await ChatAuthGateway.instance.login(
        uid,
        authenticationSettings!.authKey!,
        onSuccess: (User user) {
          succeeded = _afterLogin(
            user,
            onSuccess,
            onError,
            "user login is successful but failed to execute onSuccess callback",
          );
        },
        onError: onError,
      );
      await succeeded;
      return user;
    } else {
      await _afterLogin(
        loggedInUser,
        onSuccess,
        onError,
        "user already logged in but failed to execute onSuccess callback",
      );
      return loggedInUser;
    }
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
  /// With `UIKitSettings.enableCalls`, [onSuccess] is called once the Calls
  /// SDK is also initialised and the user logged into it, as in the Android
  /// UI Kit. That wait is bounded (about 22 s at most). A Calls SDK failure
  /// or timeout never turns into [onError]: [onSuccess] still follows, and
  /// the Calls SDK is set up again when a call needs it. The returned future
  /// completes after [onSuccess] or [onError] has been called.
  ///
  /// When a user is already logged in: for the same auth token the chat SDK
  /// holds, [onSuccess] is called with that user; for any other token,
  /// [onError] gets `ERR_USER_ALREADY_LOGGED_IN` and null is returned. Call
  /// [logout] first to log in as someone else.
  ///
  ///  method could throw [PlatformException] with error codes specifying the cause
  static Future<User?> loginWithAuthToken(
    String authToken, {
    Function(User user)? onSuccess,
    Function(CometChatException excep)? onError,
  }) async {
    if (!checkAuthSettings(onError)) return null;
    User? loggedInUser = await getLoggedInUser();

    if (loggedInUser == null) {
      // See login: this future completes once the host's onSuccess ran.
      Future<void>? succeeded;
      User? user = await ChatAuthGateway.instance.loginWithAuthToken(
        authToken,
        onSuccess: (User user) {
          //executing custom onSuccess handler when user is logged in successfully using auth token
          succeeded = _afterLogin(
            user,
            onSuccess,
            onError,
            "user login is successful but failed to execute onSuccess callback",
          );
        },
        onError: onError,
      );
      await succeeded;
      return user;
    }

    // Someone is logged in already. A uid cannot be read from a token, so
    // compare with the token the chat SDK holds: succeeding with the current
    // user for another user's token would hand the host the wrong identity.
    String? currentToken;
    try {
      currentToken = await ChatAuthGateway.instance.getUserAuthToken();
    } catch (e) {
      ccLog('CometChatUIKit.loginWithAuthToken: reading the auth token: $e');
    }
    if (currentToken != null && currentToken == authToken) {
      await _afterLogin(
        loggedInUser,
        onSuccess,
        onError,
        "user already logged in but failed to execute onSuccess callback",
      );
      return loggedInUser;
    }
    _runHostCallback(
      () => onError?.call(
        CometChatException(
          'ERR_USER_ALREADY_LOGGED_IN',
          'User ${loggedInUser.uid} is logged in with a different auth token.',
          'A user is already logged in. Log out first '
              '(CometChatUIKit.logout), then log in with this auth token.',
        ),
      ),
      "user already logged in but failed to execute onError callback",
    );
    return null;
  }

  /// What the login paths run once the chat SDK has a logged-in [user],
  /// before the host hears of it: record the user, run the UI Kit's own
  /// set-up, wait for the Calls SDK when `enableCalls` is on (bounded, see
  /// [CallsLifecycle.readyForHost]), then call [onSuccess].
  ///
  /// Without `enableCalls` there is nothing to wait for, and [onSuccess] runs
  /// before this returns, inside the chat SDK's own callback, as before.
  ///
  /// If [user] logged out (or another user logged in) while this waited for
  /// the Calls SDK, [onError] gets `ERR_LOGGED_OUT_DURING_LOGIN` instead, so
  /// the host never proceeds with a session that is already gone.
  /// Never throws.
  static Future<void> _afterLogin(
    User user,
    Function(User user)? onSuccess,
    Function(CometChatException excep)? onError,
    String failureLog,
  ) {
    Future<void>? callsReady;
    try {
      getConversationUpdateSettings();
      CometChatUIKit.loggedInUser = user;
      callsReady = _initiateAfterLogin(user);
    } catch (e) {
      ccLog('CometChatUIKit: set-up after login failed: $e');
    }
    void succeed() => _runHostCallback(() => onSuccess?.call(user), failureLog);
    if (callsReady == null) {
      succeed();
      return Future<void>.value();
    }
    void settle() {
      if (CometChatUIKit.loggedInUser?.uid == user.uid) {
        succeed();
        return;
      }
      _runHostCallback(
        () => onError?.call(
          CometChatException(
            'ERR_LOGGED_OUT_DURING_LOGIN',
            'User ${user.uid} logged out before the login finished.',
            'The session ended while the UI Kit was setting up calls. '
                'Log in again.',
          ),
        ),
        "user logged out during login but failed to execute onError callback",
      );
    }

    return callsReady.then((_) => settle(), onError: (_) => settle());
  }

  /// The UI Kit's own set-up for a logged-in [user]: the chat event bridge,
  /// the time zone details and, with `enableCalls`, call handling.
  ///
  /// Returns what the host's onSuccess has to wait for (see
  /// [CallsLifecycle.readyForHost]), or null when there is nothing.
  static Future<void>? _initiateAfterLogin(User user) {
    _initializeSDKEVent();
    _inititalizeTimeZoneDetails();

    // Calls first: the call listeners go up at once and the Calls SDK sets
    // up while the time zone database loads. Single-flight: the chat SDK's
    // login listener may already have started it for this user.
    final callsReady = CallsLifecycle.readyForHost(user);

    try {
      initializeTimeZones();
    } catch (e) {
      ccLog('CometChatUIKit: loading the time zone database failed: $e');
    }
    return callsReady;
  }

  /// Calls a host callback, logging instead of throwing when it fails.
  static void _runHostCallback(void Function() callback, String failureLog) {
    try {
      callback();
    } catch (e) {
      if (kDebugMode) {
        ccLog(failureLog);
      }
    }
  }

  static void _initializeSDKEVent() {
    ChatSDKEventInitializer();
  }

  ///Method returns user after creation in cometchat environment
  ///
  /// Ideally, user creation should take place at your backend
  ///
  /// `uid` specified on user creation. Not editable after that.
  ///
  /// `name` Display name of the user.
  ///
  /// `avatar` URL to profile picture of the user.
  static Future<User?> createUser(
    User user, {
    Function(User user)? onSuccess,
    Function(CometChatException e)? onError,
  }) async {
    if (!checkAuthSettings(onError)) return null;

    User? resultUser;

    resultUser = await CometChat.createUser(
      user,
      authenticationSettings!.authKey!,
      onSuccess: onSuccess,
      onError: onError,
    );
    return resultUser;
  }

  ///Updating a user similar to creating a user should ideally be achieved at your backend using the Restful APIs
  ///
  /// [user] a user object which user needs to be updated.
  ///
  /// method could throw `PlatformException` with error codes specifying the cause
  static Future<User?> updateUser(
    User user, {
    Function(User retUser)? onSuccess,
    Function(CometChatException excep)? onError,
  }) async {
    if (!checkAuthSettings(onError)) return null;

    User? user0;

    user0 = await CometChat.updateUser(
      user,
      authenticationSettings!.authKey!,
      onSuccess: onSuccess,
      onError: onError,
    );

    return user0;
  }

  ///used to logout user
  ///
  /// Calls come first, while the user can still be heard: within about 3 s,
  /// best effort, an incoming call still ringing is declined, a call this
  /// device placed that is still ringing is cancelled, a 1-on-1 call in
  /// progress is ended and a group meeting is left; then the call screens
  /// are closed and the media session left. Only then is the chat SDK
  /// logged out.
  ///
  /// On success call handling stops and the Calls SDK is logged out too
  /// (never an error), before [onSuccess]; [onSuccess] waits at most about
  /// 5 s for the Calls logout. So a logout takes at most about 3 s of call
  /// clean-up, the chat logout, and 5 s. On failure [onError] is
  /// called and call handling stays up: the user is still logged in and
  /// still gets calls. The returned future completes after [onSuccess] or
  /// [onError] has been called.
  ///
  /// method could throw [PlatformException] with error codes specifying the cause
  static Future<void> logout({
    dynamic Function(String)? onSuccess,
    Function(CometChatException excep)? onError,
  }) async {
    if (!checkAuthSettings(onError)) return;

    // Before the chat logout: afterwards nothing can be sent as this user.
    // It used to tear call handling down first and send nothing, so the
    // other party kept ringing or sat alone in the call, and a failed logout
    // still left the user without calls.
    try {
      await CallsLifecycle.prepareForLogout();
    } catch (e) {
      ccLog('CometChatUIKit.logout: call clean-up failed: $e');
    }

    // The chat SDK calls onSuccess without awaiting it. Keep what it starts,
    // so this future completes only once the host's onSuccess has run.
    Future<void>? succeeded;
    await ChatAuthGateway.instance.logout(
      onSuccess: (message) {
        succeeded = _afterLogout(message, onSuccess);
      },
      onError: (error) {
        // Still logged in: the call listeners stay registered.
        _runHostCallback(
          () => onError?.call(error),
          'user logout was unsuccessful: ${error.message}, but unable to '
          'execute custom onError callback',
        );
      },
    );
    await succeeded;
  }

  /// What [logout] runs once the chat SDK has logged out, before the host
  /// hears of it: stop call handling and log the Calls SDK out (bounded,
  /// shared with the chat SDK's logout listener), forget the user, then
  /// call [onSuccess]. Never throws.
  static Future<void> _afterLogout(
    String message,
    dynamic Function(String)? onSuccess,
  ) async {
    // Bounded as a whole: the Calls logout first waits for a Calls login
    // still in flight, and each wait had its own limit, so onSuccess could
    // come some 10 s after the chat logout. What is still running when the
    // limit is up finishes on its own.
    final limit = CallsSdkSession.instance.timeouts.logout;
    try {
      await CallsLifecycle.shutdown().timeout(
        limit,
        onTimeout: () => ccLog(
          'CometChatUIKit.logout: the Calls SDK logout is still running '
          'after ${limit.inSeconds} s; carrying on',
        ),
      );
    } catch (e) {
      ccLog('CometChatUIKit.logout: stopping calls failed: $e');
    }
    CometChatUIKit.loggedInUser = null;
    _runHostCallback(
      () => onSuccess?.call(message),
      'user logout was successful: $message, but unable to execute custom '
      'onSuccess callback',
    );
  }

  static bool checkAuthSettings(Function(CometChatException e)? onError) {
    if (authenticationSettings == null) {
      if (onError != null) {
        onError(
          CometChatException(
            "ERR",
            "Authentication null",
            "Populate uiKitSettings before initializing",
          ),
        );
      }
      return false;
    }

    if (authenticationSettings!.appId == null) {
      if (onError != null) {
        onError(
          CometChatException(
            "appIdErr",
            "APP ID null",
            "Populate appId in uiKitSettings before initializing",
          ),
        );
      }
      return false;
    }
    return true;
  }

  //---------- Helper methods to send messages ----------
  ///[sendCustomMessage] used to send a custom message
  static Future<CustomMessage?> sendCustomMessage(
    CustomMessage message, {
    dynamic Function(CustomMessage)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) async {
    if (message.parentMessageId == -1) {
      message.parentMessageId = 0;
    }

    message.sender ??= loggedInUser;
    if (message.muid.trim().isEmpty) {
      message.muid = DateTime.now().microsecondsSinceEpoch.toString();
    }

    CometChatMessageEvents.ccMessageSent(
      message,
      core_enums.MessageStatus.inProgress,
    );
    CustomMessage? result = await CometChat.sendCustomMessage(
      message,
      onSuccess: (CustomMessage sentMessage) {
        //executing the custom onSuccess handler
        if (onSuccess != null) {
          try {
            onSuccess(sentMessage);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message sent successfully but failed to execute onSuccess callback",
              );
            }
          }
        }
        // Preserve muid if SDK response has empty muid (needed for pending→sent dedup)
        if (sentMessage.muid.isEmpty && message.muid.isNotEmpty) {
          sentMessage.muid = message.muid;
        }
        //the ccMessageSent event is emitted to update the message receipt shown
        //in the footer of the message bubble from in progress to sent
        CometChatMessageEvents.ccMessageSent(
          sentMessage,
          core_enums.MessageStatus.sent,
        );
      },
      onError: (error) {
        //executing the custom onError handler
        if (onError != null) {
          try {
            onError(error);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message could not be sent and failed to execute onError callback",
              );
            }
          }
        }
        //a error property is added to the metadata of the message
        //because of which a error message receipt will be shown in the
        //footer of the message bubble in the message list
        if (message.metadata != null) {
          message.metadata!["error"] = error;
        } else {
          message.metadata = {"error": error};
        }
        CometChatMessageEvents.ccMessageSent(
          message,
          core_enums.MessageStatus.error,
        );
      },
    );
    return result;
  }

  ///[sendTextMessage] used to send a text message
  static Future<TextMessage?> sendTextMessage(
    TextMessage message, {
    dynamic Function(TextMessage)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) async {
    if (message.parentMessageId == -1) {
      message.parentMessageId = 0;
    }
    message.sender ??= loggedInUser;
    if (message.muid.trim().isEmpty) {
      message.muid = DateTime.now().microsecondsSinceEpoch.toString();
    }

    CometChatMessageEvents.ccMessageSent(
      message,
      core_enums.MessageStatus.inProgress,
    );
    TextMessage? result = await CometChat.sendMessage(
      message,
      onSuccess: (TextMessage sentMessage) {
        //executing the custom onSuccess handler
        if (onSuccess != null) {
          try {
            onSuccess(sentMessage);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message sent successfully but failed to execute onSuccess callback",
              );
            }
          }
        }
        // Preserve muid if SDK response has empty muid (needed for pending→sent dedup)
        if (sentMessage.muid.isEmpty && message.muid.isNotEmpty) {
          sentMessage.muid = message.muid;
        }
        //the ccMessageSent event is emitted to update the message receipt shown
        //in the footer of the message bubble from in progress to sent
        CometChatMessageEvents.ccMessageSent(
          sentMessage,
          core_enums.MessageStatus.sent,
        );
      },
      onError: (error) {
        //executing the custom onError handler
        if (onError != null) {
          try {
            onError(error);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message could not be sent and failed to execute onError callback",
              );
            }
          }
        }
        //a error property is added to the metadata of the message
        //because of which a error message receipt will be shown in the
        //footer of the message bubble in the message list
        if (message.metadata != null) {
          message.metadata!["error"] = error;
        } else {
          message.metadata = {"error": error};
        }
        CometChatMessageEvents.ccMessageSent(
          message,
          core_enums.MessageStatus.error,
        );
      },
    );
    return result;
  }

  ///[sendMediaMessage] used to send a media message
  static Future<MediaMessage?> sendMediaMessage(
    MediaMessage message, {
    dynamic Function(MediaMessage)? onSuccess,
    dynamic Function(CometChatException)? onError,
    bool replacePathForIOS = true,
  }) async {
    if (message.parentMessageId == -1) {
      message.parentMessageId = 0;
    }

    message.sender ??= loggedInUser;
    if (message.muid.trim().isEmpty) {
      message.muid = DateTime.now().microsecondsSinceEpoch.toString();
    }

    CometChatMessageEvents.ccMessageSent(
      message,
      core_enums.MessageStatus.inProgress,
    );

    MediaMessage? mediaMessage2;

    if (replacePathForIOS == true) {
      //for sending files
      mediaMessage2 = MediaMessage(
        receiverType: message.receiverType,
        type: message.type,
        receiverUid: message.receiverUid,
        file:
            (!kIsWeb &&
                _isIOS() &&
                message.file != null &&
                (!message.file!.startsWith('file://')))
            ? 'file://${message.file}'
            : message.file,
        metadata: message.metadata,
        sender: message.sender,
        parentMessageId: message.parentMessageId,
        muid: message.muid,
        category: message.category,
        attachment: message.attachment,
        caption: message.caption,
        tags: message.tags,
      );
    }

    MediaMessage? result = await CometChat.sendMediaMessage(
      mediaMessage2 ?? message,
      onSuccess: (MediaMessage sentMessage) {
        //executing the custom onSuccess handler

        if (replacePathForIOS == true) {
          if (!kIsWeb && _isIOS()) {
            if (message.file != null) {
              sentMessage.file = message.file?.replaceAll("file://", '');
            }
          } else {
            sentMessage.file = message.file;
          }
        }

        if (onSuccess != null) {
          try {
            onSuccess(sentMessage);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message sent successfully but failed to execute onSuccess callback",
              );
            }
          }
        }
        // Preserve muid if SDK response has empty muid (needed for pending→sent dedup)
        if (sentMessage.muid.isEmpty && message.muid.isNotEmpty) {
          sentMessage.muid = message.muid;
        }
        //the ccMessageSent event is emitted to update the message receipt shown
        //in the footer of the message bubble from in progress to sent
        CometChatMessageEvents.ccMessageSent(
          sentMessage,
          core_enums.MessageStatus.sent,
        );
      },
      onError: (error) {
        //executing the custom onError handler
        if (onError != null) {
          try {
            onError(error);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message could not be sent and failed to execute onError callback",
              );
            }
          }
        }
        //a error property is added to the metadata of the message
        //because of which a error message receipt will be shown in the
        //footer of the message bubble in the message list
        if (message.metadata != null) {
          message.metadata!["error"] = error;
        } else {
          message.metadata = {"error": error};
        }
        CometChatMessageEvents.ccMessageSent(
          message,
          core_enums.MessageStatus.error,
        );
      },
    );
    return result;
  }

  ///[sendFormMessage] used to send a custom message
  static Future<FormMessage?> sendFormMessage(
    FormMessage message, {
    dynamic Function(FormMessage)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) async {
    if (message.parentMessageId == -1) {
      message.parentMessageId = 0;
    }

    message.sender ??= loggedInUser;
    if (message.muid.trim().isEmpty) {
      message.muid = DateTime.now().microsecondsSinceEpoch.toString();
    }

    CometChatMessageEvents.ccMessageSent(
      message,
      core_enums.MessageStatus.inProgress,
    );
    FormMessage? result = await legacy_sdk.SDKMethods.sendFormMessage(
      message,
      onSuccess: (FormMessage sentMessage) {
        //executing the custom onSuccess handler
        if (onSuccess != null) {
          try {
            onSuccess(sentMessage);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message sent successfully but failed to execute onSuccess callback",
              );
            }
          }
        }
        // Preserve muid if SDK response has empty muid (needed for pending→sent dedup)
        if (sentMessage.muid.isEmpty && message.muid.isNotEmpty) {
          sentMessage.muid = message.muid;
        }
        //the ccMessageSent event is emitted to update the message receipt shown
        //in the footer of the message bubble from in progress to sent
        CometChatMessageEvents.ccMessageSent(
          sentMessage,
          core_enums.MessageStatus.sent,
        );
      },
      onError: (error) {
        //executing the custom onError handler
        if (onError != null) {
          try {
            onError(error);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message could not be sent and failed to execute onError callback",
              );
            }
          }
        }
        //a error property is added to the metadata of the message
        //because of which a error message receipt will be shown in the
        //footer of the message bubble in the message list
        if (message.metadata != null) {
          message.metadata!["error"] = error;
        } else {
          message.metadata = {"error": error};
        }
        CometChatMessageEvents.ccMessageSent(
          message,
          core_enums.MessageStatus.error,
        );
      },
    );
    return result;
  }

  ///[sendFormMessage] used to send a custom message
  static Future<legacy_card.CardMessage?> sendCardMessage(
    legacy_card.CardMessage message, {
    dynamic Function(legacy_card.CardMessage)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) async {
    if (message.parentMessageId == -1) {
      message.parentMessageId = 0;
    }

    message.sender ??= loggedInUser;
    if (message.muid.trim().isEmpty) {
      message.muid = DateTime.now().microsecondsSinceEpoch.toString();
    }

    CometChatMessageEvents.ccMessageSent(
      message,
      core_enums.MessageStatus.inProgress,
    );
    legacy_card.CardMessage?
    result = await legacy_sdk.SDKMethods.sendCardMessage(
      message,
      onSuccess: (legacy_card.CardMessage sentMessage) {
        //executing the custom onSuccess handler
        if (onSuccess != null) {
          try {
            onSuccess(sentMessage);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message sent successfully but failed to execute onSuccess callback",
              );
            }
          }
        }
        // Preserve muid if SDK response has empty muid (needed for pending→sent dedup)
        if (sentMessage.muid.isEmpty && message.muid.isNotEmpty) {
          sentMessage.muid = message.muid;
        }
        //the ccMessageSent event is emitted to update the message receipt shown
        //in the footer of the message bubble from in progress to sent
        CometChatMessageEvents.ccMessageSent(
          sentMessage,
          core_enums.MessageStatus.sent,
        );
      },
      onError: (error) {
        //executing the custom onError handler
        if (onError != null) {
          try {
            onError(error);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message could not be sent and failed to execute onError callback",
              );
            }
          }
        }
        //a error property is added to the metadata of the message
        //because of which a error message receipt will be shown in the
        //footer of the message bubble in the message list
        if (message.metadata != null) {
          message.metadata!["error"] = error;
        } else {
          message.metadata = {"error": error};
        }
        CometChatMessageEvents.ccMessageSent(
          message,
          core_enums.MessageStatus.error,
        );
      },
    );
    return result;
  }

  ///[SchedulerMessage] used to send a custom message
  static Future<SchedulerMessage?> sendSchedulerMessage(
    SchedulerMessage message, {
    dynamic Function(SchedulerMessage)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) async {
    if (message.parentMessageId == -1) {
      message.parentMessageId = 0;
    }

    message.sender ??= loggedInUser;
    if (message.muid.trim().isEmpty) {
      message.muid = DateTime.now().microsecondsSinceEpoch.toString();
    }

    CometChatMessageEvents.ccMessageSent(
      message,
      core_enums.MessageStatus.inProgress,
    );
    SchedulerMessage? result = await legacy_sdk.SDKMethods.sendSchedulerMessage(
      message,
      onSuccess: (SchedulerMessage sentMessage) {
        //executing the custom onSuccess handler
        if (onSuccess != null) {
          try {
            onSuccess(sentMessage);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message sent successfully but failed to execute onSuccess callback",
              );
            }
          }
        }
        // Preserve muid if SDK response has empty muid (needed for pending→sent dedup)
        if (sentMessage.muid.isEmpty && message.muid.isNotEmpty) {
          sentMessage.muid = message.muid;
        }
        //the ccMessageSent event is emitted to update the message receipt shown
        //in the footer of the message bubble from in progress to sent
        CometChatMessageEvents.ccMessageSent(
          sentMessage,
          core_enums.MessageStatus.sent,
        );
      },
      onError: (error) {
        //executing the custom onError handler
        if (onError != null) {
          try {
            onError(error);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message could not be sent and failed to execute onError callback",
              );
            }
          }
        }
        //a error property is added to the metadata of the message
        //because of which a error message receipt will be shown in the
        //footer of the message bubble in the message list
        if (message.metadata != null) {
          message.metadata!["error"] = error;
        } else {
          message.metadata = {"error": error};
        }
        CometChatMessageEvents.ccMessageSent(
          message,
          core_enums.MessageStatus.error,
        );
      },
    );
    return result;
  }

  ///[getLoggedInUser] checks if any session is active and retrieves the [User] data of the logged in user
  static Future<User?> getLoggedInUser({
    dynamic Function(User)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) async {
    User? user = await ChatAuthGateway.instance.getLoggedInUser(
      onSuccess: (user) {
        CometChatUIKit.loggedInUser = user;

        //executing the custom onSuccess handler
        if (onSuccess != null) {
          try {
            onSuccess(user);
          } catch (e) {
            if (kDebugMode) {
              ccLog("failed to execute onSuccess callback");
            }
          }
        }
      },
      onError: (error) {
        //executing the custom onError handler
        if (onError != null) {
          try {
            onError(error);
          } catch (e) {
            if (kDebugMode) {
              ccLog("failed to execute onError callback");
            }
          }
        }
      },
    );
    return user;
  }

  ///[soundManager] used to play sound
  static final SoundManager soundManager = SoundManager();

  static void _inititalizeTimeZoneDetails() {
    try {
      String currentTimeZone = DateTime.now().timeZoneName;
      // Defensive copy. This used to bind the shared static directly and then
      // removeWhere on it, which permanently emptied SchedulerUtils.timeZones
      // for the rest of the process and made a second call operate on the
      // residue of the first. ENG-39021.
      Map<String, Map> timeZones = Map.of(SchedulerUtils.timeZones);
      timeZones.removeWhere((key, value) {
        if (value["sabbr"] != null && value["sabbr"] == currentTimeZone) {
          return false;
        } else if (value["abbr"] == currentTimeZone) {
          return false;
        }
        return true;
      });
      localTimeZoneIdentifier = timeZones.keys.first;
      localTimeZoneName = timeZones.values.first["name"];
    } catch (e) {
      if (kDebugMode) {
        ccLog("failed to initialize timezone details ${e.toString()}");
      }
    }
  }

  ///[addReaction] will add a reaction to a message with the provided message ID and will update the UI of `CometChatMessageList` and `CometChatReactions` accordingly

  static Future<BaseMessage?> addReaction(
    int messageId,
    String reaction, {
    dynamic Function(BaseMessage)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) async {
    final message = await CometChat.addReaction(
      messageId,
      reaction,
      onSuccess: (reactedMessage) {
        //executing the custom onSuccess handler
        if (onSuccess != null) {
          try {
            onSuccess(reactedMessage);
          } catch (e) {
            if (kDebugMode) {
              ccLog("failed to execute onSuccess callback");
            }
          }
        }

        CometChatMessageEvents.ccMessageEdited(
          reactedMessage,
          MessageEditStatus.success,
        );
      },
      onError: (error) {
        //executing the custom onError handler
        if (onError != null) {
          try {
            onError(error);
          } catch (e) {
            if (kDebugMode) {
              ccLog("failed to execute onError callback");
            }
          }
        }
      },
    );

    return message;
  }

  ///[addReaction] will remove a reaction to a message with the provided message ID and will update the UI of [CometChatMessageList] and [CometChatReactions] accordingly
  static Future<BaseMessage?> removeReaction(
    int messageId,
    String reaction, {
    dynamic Function(BaseMessage)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) async {
    final message = await CometChat.removeReaction(
      messageId,
      reaction,
      onSuccess: (reactedMessage) {
        //executing the custom onSuccess handler
        if (onSuccess != null) {
          try {
            onSuccess(reactedMessage);
          } catch (e) {
            if (kDebugMode) {
              ccLog("failed to execute onSuccess callback");
            }
          }
        }

        CometChatMessageEvents.ccMessageEdited(
          reactedMessage,
          MessageEditStatus.success,
        );
      },
      onError: (error) {
        //executing the custom onError handler
        if (onError != null) {
          try {
            onError(error);
          } catch (e) {
            if (kDebugMode) {
              ccLog("failed to execute onError callback");
            }
          }
        }
      },
    );

    return message;
  }

  static void getConversationUpdateSettings() async {
    await CometChat.getConversationUpdateSettings(
      onSuccess: (settings) {
        conversationUpdateSettings = settings;
      },
      onError: (exception) {
        if (kDebugMode) {
          ccLog("Cannot get conversation update settings ${exception.message}");
        }
      },
    );
  }

  ///[sendCustomInteractiveMessage] can be used to send a custom interactive message
  static Future<InteractiveMessage?> sendCustomInteractiveMessage(
    InteractiveMessage message, {
    dynamic Function(InteractiveMessage)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) async {
    if (message.parentMessageId == -1) {
      message.parentMessageId = 0;
    }

    message.sender ??= loggedInUser;
    if (message.muid.trim().isEmpty) {
      message.muid = DateTime.now().microsecondsSinceEpoch.toString();
    }

    CometChatMessageEvents.ccMessageSent(
      message,
      core_enums.MessageStatus.inProgress,
    );

    InteractiveMessage? result = await CometChat.sendInteractiveMessage(
      message,
      onSuccess: (InteractiveMessage sentMessage) {
        //executing the custom onSuccess handler
        if (onSuccess != null) {
          try {
            onSuccess(sentMessage);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message sent successfully but failed to execute onSuccess callback",
              );
            }
          }
        }
        // Preserve muid if SDK response has empty muid (needed for pending→sent dedup)
        if (sentMessage.muid.isEmpty && message.muid.isNotEmpty) {
          sentMessage.muid = message.muid;
        }
        //the ccMessageSent event is emitted to update the message receipt shown
        //in the footer of the message bubble from in progress to sent
        CometChatMessageEvents.ccMessageSent(
          sentMessage,
          core_enums.MessageStatus.sent,
        );
      },
      onError: (error) {
        //executing the custom onError handler
        if (onError != null) {
          try {
            onError(error);
          } catch (e) {
            if (kDebugMode) {
              ccLog(
                "message could not be sent and failed to execute onError callback",
              );
            }
          }
        }
        //a error property is added to the metadata of the message
        //because of which a error message receipt will be shown in the
        //footer of the message bubble in the message list
        if (message.metadata != null) {
          message.metadata!["error"] = error;
        } else {
          message.metadata = {"error": error};
        }
        CometChatMessageEvents.ccMessageSent(
          message,
          core_enums.MessageStatus.error,
        );
      },
    );
    return result;
  }

  /// Returns the native platform name, web-safe via defaultTargetPlatform.
  static String _nativePlatformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  /// Returns true if running on iOS (safe to call only when !kIsWeb).
  static bool _isIOS() {
    try {
      return defaultTargetPlatform == TargetPlatform.iOS;
    } catch (_) {
      return false;
    }
  }
}
