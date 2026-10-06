import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show SessionSettings;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_event_listener.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/calls_sdk_gateway.dart';
import 'package:cometchat_chat_uikit/src/calls_sdk_session.dart';
import 'package:cometchat_chat_uikit/src/ghost_join_guard.dart';

/// Shared fakes/stubs for the call BLoC tests.
///
/// Everything here replaces a seam the call BLoCs actually depend on:
/// * [FakeCallOperationsDataSource] — the abstract datasource injected through
///   `CallOperationsServiceLocator.setup(dataSource: ...)`.
/// * [PermissionChannelStub] — `CallPermissions` goes through
///   permission_handler's default `MethodChannelPermissionHandler`, so the
///   platform channel is the only seam available for it.
/// * [SoundChannelSpy] — `SoundManager` talks to `UIConstants.channel`.
/// * [CallEventRecorder] — `CometChatCallEvents` is a plain in-process
///   listener registry, so it can be observed directly.
/// * [FakeCallsSdkGateway] — `CallsSdkSession` reaches the Calls SDK and the
///   chat SDK's auth token only through a `CallsSdkGateway`;
///   [installReadyCallsSdk] puts a session over this fake in place and runs it
///   to ready, so the call screen's readiness guard passes without a device.

// ===========================================================================
// Datasource
// ===========================================================================

/// A datasource whose every call-operation method is scriptable.
///
/// Only the methods the BLoCs under test actually reach are implemented;
/// everything else inherits `Fake`'s throwing `noSuchMethod`, so a change that
/// widens the path fails loudly instead of silently hitting the real SDK.
class FakeCallOperationsDataSource extends Fake
    implements CallOperationsDataSource {
  /// Calls recorded as `method:arg1[:arg2]`, in order.
  final List<String> calls = <String>[];

  /// When non-null, `acceptCall` throws this instead of returning.
  CallOperationsException? acceptError;

  /// When non-null, `rejectCall` throws this instead of returning.
  CallOperationsException? rejectError;

  /// When non-null, `endCall` throws this instead of returning.
  CallOperationsException? endCallError;

  /// When non-null, `endSession` throws this instead of returning.
  CallOperationsException? endSessionError;

  /// When non-null, `startSession` throws this instead of returning.
  CallOperationsException? startSessionError;

  /// Call returned by `acceptCall`; defaults to an audio call.
  Call Function(String sessionId)? onAcceptCall;

  /// Call returned by `rejectCall`; defaults to an audio call.
  Call Function(String sessionId, String status)? onRejectCall;

  /// Replaces `startSession`'s immediate join, e.g. with one that never
  /// answers (wrap it in `joinWithDeadline` for the 30 s limit).
  Future<Widget> Function(String sessionId)? onStartSession;

  /// When set, `acceptCall` waits for it before answering (a slow or hung
  /// network).
  Completer<void>? acceptGate;

  /// When set, `initiateCall` waits for it before answering.
  Completer<void>? initiateGate;

  /// The session the server gives a call `initiateCall` places.
  String placedSessionId = 'placed';

  /// When set, `rejectCall` waits for it before answering.
  Completer<void>? rejectGate;

  /// When set, `endCall` waits for it before answering.
  Completer<void>? endCallGate;

  int get initiateCallCount => _count('initiateCall');
  int get acceptCallCount => _count('acceptCall');
  int get rejectCallCount => _count('rejectCall');
  int get endCallCount => _count('endCall');
  int get endSessionCount => _count('endSession');
  int get startSessionCount => _count('startSession');

  int _count(String method) =>
      calls.where((String c) => c == method || c.startsWith('$method:')).length;

  @override
  Future<void> waitForCallsSdk() async {
    calls.add('waitForCallsSdk');
  }

  /// Places [call] as the server does: the same call, with a session
  /// ([placedSessionId]) and status `initiated`.
  @override
  Future<Call> initiateCall(Call call) async {
    calls.add('initiateCall:${call.receiverUid}');
    await initiateGate?.future;
    return Call(
      sessionId: placedSessionId,
      receiverUid: call.receiverUid,
      receiverType: call.receiverType,
      type: call.type,
      callStatus: 'initiated',
    );
  }

  @override
  Future<Call> acceptCall(String sessionId) async {
    calls.add('acceptCall:$sessionId');
    await acceptGate?.future;
    final CallOperationsException? error = acceptError;
    if (error != null) throw error;
    return onAcceptCall?.call(sessionId) ?? buildCall(sessionId: sessionId);
  }

  @override
  Future<Call> rejectCall(String sessionId, String status) async {
    calls.add('rejectCall:$sessionId:$status');
    await rejectGate?.future;
    final CallOperationsException? error = rejectError;
    if (error != null) throw error;
    return onRejectCall?.call(sessionId, status) ??
        buildCall(sessionId: sessionId);
  }

  @override
  Future<Call> endCall(String sessionId) async {
    calls.add('endCall:$sessionId');
    await endCallGate?.future;
    final CallOperationsException? error = endCallError;
    if (error != null) throw error;
    return buildCall(sessionId: sessionId);
  }

  /// The settings of every `startSession`, in order.
  final List<SessionSettings> startedSettings = <SessionSettings>[];

  /// Leaves the session as `CometChatUIKitCalls.endSession` does: the
  /// "maybe in a session" mark is cleared, failure or not.
  @override
  Future<void> endSession() async {
    calls.add('endSession');
    ActiveCallTracker.mayHaveMediaSession = false;
    final CallOperationsException? error = endSessionError;
    if (error != null) throw error;
  }

  /// Joins at once and hands back a [FakeCallingWidget] as the call view.
  ///
  /// Keeps the "maybe in a session" mark as `CometChatUIKitCalls.startSession`
  /// does: set as the join starts, cleared when the Calls SDK refuses it.
  @override
  Future<Widget> startSession(
    String sessionId,
    SessionSettings settings,
  ) async {
    calls.add('startSession:$sessionId');
    startedSettings.add(settings);
    ActiveCallTracker.mayHaveMediaSession = true;
    final CallOperationsException? error = startSessionError;
    if (error != null) {
      ActiveCallTracker.mayHaveMediaSession = false;
      throw error;
    }
    final Future<Widget> Function(String sessionId)? start = onStartSession;
    if (start != null) return start(sessionId);
    return const FakeCallingWidget();
  }
}

/// Builds a [Call] with the fields the BLoCs read.
Call buildCall({
  String sessionId = 'session_1',
  String receiverUid = 'peer',
  String type = CallTypeConstants.audioCall,
  String receiverType = ReceiverTypeConstants.user,
}) => Call(
  sessionId: sessionId,
  receiverUid: receiverUid,
  type: type,
  receiverType: receiverType,
);

/// The logged-in user the call tests act as: `CometChatUIKit.loggedInUser`
/// in the tests that check who acted in an event.
final User testMe = User(uid: 'me', name: 'Me');

/// [call] as an event the logged-in user ([testMe]) acted on: an "ongoing",
/// "rejected" or "busy" from their other device. The server names the actor
/// as the event's `callInitiator`.
Call byMe(Call call) => call..callInitiator = testMe;

/// [call] as an event someone other than the logged-in user acted on:
/// another member of a group call answering it, say.
Call byOther(Call call, {String uid = 'someone'}) =>
    call..callInitiator = User(uid: uid, name: uid);

/// A [Call] whose `sessionId` is null, which no public constructor allows.
class NullSessionCall extends Fake implements Call {
  NullSessionCall({this.type = CallTypeConstants.audioCall});

  @override
  final String type;

  @override
  String? get sessionId => null;
}

// ===========================================================================
// Platform-channel stubs
// ===========================================================================

/// Answers permission_handler's method channel so `CallPermissions` resolves
/// without a device.
class PermissionChannelStub {
  PermissionChannelStub._();

  static const MethodChannel _channel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  static const int _denied = 0;
  static const int _granted = 1;

  /// `PermissionStatus.permanentlyDenied`'s raw value.
  static const int _permanentlyDenied = 4;

  /// Permissions requested through the channel, in order, as raw values.
  static final List<int> requested = <int>[];

  /// When set, a permission request waits for it before answering: the
  /// system prompt is still up.
  static Completer<void>? gate;

  /// When set, a permission request throws it (after [gate]): the plugin
  /// refusing, say because a request is already running.
  static Object? requestError;

  /// Install the stub. [granted] decides what every request resolves to;
  /// a refusal is a permanent one ("don't ask again") with
  /// [permanentlyDenied]. [grantedPermissions], when given, grants only
  /// those and refuses the rest.
  static void install({
    required bool granted,
    bool permanentlyDenied = false,
    Set<Permission>? grantedPermissions,
  }) {
    requested.clear();
    final int refused = permanentlyDenied ? _permanentlyDenied : _denied;
    int statusOf(int value) {
      final Set<Permission>? only = grantedPermissions;
      if (only != null) {
        return only.any((Permission p) => p.value == value)
            ? _granted
            : refused;
      }
      return granted ? _granted : refused;
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          switch (call.method) {
            case 'checkPermissionStatus':
              return statusOf(call.arguments as int);
            case 'requestPermissions':
              final List<int> values = List<int>.from(
                call.arguments as List<Object?>,
              );
              requested.addAll(values);
              await gate?.future;
              final Object? error = requestError;
              if (error != null) throw error;
              return <int, int>{for (final int v in values) v: statusOf(v)};
            default:
              return null;
          }
        });
  }

  /// Whether the camera permission was part of any request.
  static bool get cameraRequested =>
      requested.contains(Permission.camera.value);

  static void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    requested.clear();
    gate = null;
    requestError = null;
  }
}

/// Answers the Calls plugin's own method channel (`cometchatcalls_plugin`)
/// and records what is asked of it: the ongoing-call service started and
/// stopped, the session left. Without an answer each call there failed with
/// a MissingPluginException (printed, not thrown).
class CallsPluginChannelRecorder {
  CallsPluginChannelRecorder._();

  static const MethodChannel _channel = MethodChannel('cometchatcalls_plugin');

  /// Every invocation on the channel, in order.
  static final List<MethodCall> calls = <MethodCall>[];

  /// The method names invoked, in order.
  static List<String> get methods => <String>[
    for (final MethodCall c in calls) c.method,
  ];

  /// Arguments of every invocation of [method], in order.
  static List<Object?> argumentsOf(String method) => <Object?>[
    for (final MethodCall c in calls)
      if (c.method == method) c.arguments,
  ];

  static void install() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          calls.add(call);
          return null;
        });
  }

  static void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    calls.clear();
  }
}

/// Records what `SoundManager` and the call tone (`playCallTone`,
/// `stopCallTone`) ask the UI Kit's platform channel to do.
class SoundChannelSpy {
  SoundChannelSpy._();

  static const MethodChannel _channel = MethodChannel('cometchat_chat_uikit');

  /// Method names invoked on the channel, in order.
  static final List<String> methods = <String>[];

  /// Every invocation on the channel, in order, with its arguments.
  static final List<MethodCall> calls = <MethodCall>[];

  /// Arguments of the last `playCustomSound` invocation.
  static Map<Object?, Object?>? lastPlayArguments;

  /// When set, runs as each invocation is recorded, and its future is
  /// awaited before the channel answers: to look at the app at that moment,
  /// or to hold an answer back (a native side still busy).
  static Future<void> Function(MethodCall call)? onCall;

  /// Arguments of the last invocation of [method], or null if there was none.
  static Map<Object?, Object?>? lastArgumentsOf(String method) {
    for (final MethodCall call in calls.reversed) {
      if (call.method == method) {
        return call.arguments as Map<Object?, Object?>?;
      }
    }
    return null;
  }

  static void install() {
    methods.clear();
    calls.clear();
    lastPlayArguments = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          methods.add(call.method);
          calls.add(call);
          if (call.method == 'playCustomSound') {
            lastPlayArguments = call.arguments as Map<Object?, Object?>?;
          }
          await onCall?.call(call);
          return null;
        });
  }

  static void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    methods.clear();
    calls.clear();
    lastPlayArguments = null;
    onCall = null;
  }
}

// ===========================================================================
// UI Kit event bus
// ===========================================================================

/// Captures the UI Kit call events the BLoCs broadcast.
class CallEventRecorder with CometChatCallEventListener {
  CallEventRecorder(this._id) {
    CometChatCallEvents.addCallEventsListener(_id, this);
  }

  final String _id;

  final List<Call> accepted = <Call>[];
  final List<Call> rejected = <Call>[];
  final List<Call> ended = <Call>[];
  final List<Call> outgoing = <Call>[];

  /// Every event in the order it arrived, as `name:sessionId`.
  final List<String> ordered = <String>[];

  @override
  void ccCallAccepted(Call call) {
    accepted.add(call);
    ordered.add('accepted:${call.sessionId}');
  }

  @override
  void ccCallRejected(Call call) {
    rejected.add(call);
    ordered.add('rejected:${call.sessionId}');
  }

  @override
  void ccCallEnded(Call call) {
    ended.add(call);
    ordered.add('ended:${call.sessionId}');
  }

  @override
  void ccOutgoingCall(Call call) {
    outgoing.add(call);
    ordered.add('outgoing:${call.sessionId}');
  }

  void dispose() => CometChatCallEvents.removeCallEventsListener(_id);
}

// ===========================================================================
// Calls SDK
// ===========================================================================

/// The settings snapshot [installReadyCallsSdk] initialises with.
const CallsSdkSettings testCallsSdkSettings = CallsSdkSettings(
  appId: 'test-app',
  region: 'us',
);

/// A scriptable Calls SDK / chat SDK behind `CallsSdkGateway`.
///
/// By default everything succeeds at once: init marks it initialised, a login
/// stores the token as the Calls login, a logout clears it. Set [onInit],
/// [onLogin] or [onLogout] to make a call fail, hang (return a future that
/// never completes) or finish when the test says so.
class FakeCallsSdkGateway implements CallsSdkGateway {
  FakeCallsSdkGateway({
    this.chatToken = 'chat-token-me',
    this.callsToken,
    bool initialized = false,
    this.deinitOnLogout = false,
  }) : _initialized = initialized;

  /// Gateway calls in order: `init:<appId>:<region>`, `initFromSettings`,
  /// `login:<token>`, `logout`, `setNativeAuthToken:<token>`.
  final List<String> calls = <String>[];

  bool _initialized;

  /// What the chat SDK reports as the logged-in user's auth token.
  String? chatToken;

  /// The token the Calls SDK is logged in with.
  String? callsToken;

  /// Calls plugin 5.0.4: logout also de-initialises the SDK.
  bool deinitOnLogout;

  /// Whether the web fallback is on offer.
  @override
  bool supportsNativeAuthTokenFallback = false;

  /// Runs inside `init` / `initFromSettings`, before it succeeds.
  Future<void> Function()? onInit;

  /// Runs inside `loginWithAuthToken`, before it succeeds.
  Future<void> Function(String token)? onLogin;

  /// Runs inside `logout`, before it succeeds.
  Future<void> Function()? onLogout;

  int _count(String method) =>
      calls.where((String c) => c == method || c.startsWith('$method:')).length;

  int get initCount => _count('init') + _count('initFromSettings');
  int get loginCount => _count('login');
  int get logoutCount => _count('logout');

  set initialized(bool value) => _initialized = value;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> init(String appId, String region) async {
    calls.add('init:$appId:$region');
    await (onInit?.call() ?? Future<void>.value());
    _initialized = true;
  }

  @override
  Future<void> initFromSettings() async {
    calls.add('initFromSettings');
    await (onInit?.call() ?? Future<void>.value());
    _initialized = true;
  }

  @override
  Future<void> loginWithAuthToken(String authToken) async {
    calls.add('login:$authToken');
    await (onLogin?.call(authToken) ?? Future<void>.value());
    callsToken = authToken;
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
    await (onLogout?.call() ?? Future<void>.value());
    callsToken = null;
    if (deinitOnLogout) _initialized = false;
  }

  @override
  Future<String?> callsAuthToken() async => callsToken;

  @override
  Future<String?> chatAuthToken() async => chatToken;

  @override
  Future<void> setNativeAuthToken(String authToken) async {
    calls.add('setNativeAuthToken:$authToken');
  }
}

/// Makes `CallsSdkSession.instance` a session over [gateway] (a fresh
/// [FakeCallsSdkGateway] by default) and runs it to ready, so
/// `CallsSdkSession.instance.isReady` is true. The gateway's call log is
/// cleared afterwards, so a test sees only the calls it causes.
///
/// Pair with [uninstallCallsSdk] in tearDown.
Future<FakeCallsSdkGateway> installReadyCallsSdk({
  FakeCallsSdkGateway? gateway,
}) async {
  final FakeCallsSdkGateway fake = gateway ?? FakeCallsSdkGateway();
  final CallsSdkSession session = installCallsSdk(fake);
  if (!await session.ensureReady()) {
    throw StateError('the fake Calls SDK did not become ready');
  }
  fake.calls.clear();
  return fake;
}

/// Makes `CallsSdkSession.instance` a session over [gateway] without running
/// it, and returns that session.
CallsSdkSession installCallsSdk(
  FakeCallsSdkGateway gateway, {
  CallsSdkSettings? Function()? settings,
  CallsSdkTimeouts timeouts = const CallsSdkTimeouts(),
}) {
  final CallsSdkSession session = CallsSdkSession(
    gateway: gateway,
    settings: settings ?? () => testCallsSdkSettings,
    timeouts: timeouts,
  );
  CallsSdkSession.debugInstance = session;
  return session;
}

/// Puts the real Calls SDK session back.
void uninstallCallsSdk() => CallsSdkSession.debugInstance = null;

/// What a call screen needs to join under test, as it would on a device
/// where the user granted the permissions: a ready fake Calls SDK
/// ([installReadyCallsSdk]) and a permission channel that grants everything.
/// Pair it with a [FakeCallOperationsDataSource], whose `startSession` joins
/// at once, set up through `CallOperationsServiceLocator`.
///
/// Returns the fake gateway, for tests that script it (for example to make
/// the Calls SDK not ready). Undo with [removeCallJoinDefaults].
///
/// The native join watchdog is off ([ActiveCallTracker.nativeJoinTimeout]):
/// nothing here reports the native join, so a call screen left up would give
/// its call up after 30 s, and a test that ends with one up would end with
/// its timer pending. The watchdog's own tests turn it back on.
Future<FakeCallsSdkGateway> installCallJoinDefaults() async {
  GhostJoinGuard.disarm();
  PermissionChannelStub.install(granted: true);
  CallsPluginChannelRecorder.install();
  ActiveCallTracker.nativeJoinTimeout = null;
  return installReadyCallsSdk();
}

/// Undoes [installCallJoinDefaults], and clears the "maybe in a session"
/// mark a join left (the fake datasource sets it as the real one does).
void removeCallJoinDefaults() {
  GhostJoinGuard.disarm();
  PermissionChannelStub.remove();
  CallsPluginChannelRecorder.remove();
  uninstallCallsSdk();
  ActiveCallTracker.mayHaveMediaSession = false;
  ActiveCallTracker.nativeJoinTimeout = const Duration(seconds: 30);
}

// ===========================================================================
// Navigator
// ===========================================================================

/// Mounts an app whose navigator is `CallNavigationContext.navigatorKey`, as
/// a host app does, so a call can be placed (the call components refuse
/// with NO_NAVIGATOR otherwise) and its screens shown for real. The surface
/// is made tall enough for the outgoing call screen, and [SoundChannelSpy]
/// answers its ringback.
Future<void> mountCallNavigator(WidgetTester tester) async {
  SoundChannelSpy.install();
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: CallNavigationContext.navigatorKey,
      localizationsDelegates: Translations.localizationsDelegates,
      home: const Scaffold(body: Text('chat')),
    ),
  );
}

// ===========================================================================
// Misc
// ===========================================================================

/// A widget the session-start fake can hand back as the "calling screen".
class FakeCallingWidget extends StatelessWidget {
  const FakeCallingWidget({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
