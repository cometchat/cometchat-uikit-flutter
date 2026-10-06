/// Drives [CallButtonsBloc] against a fake call-operations data source.
///
/// Two seams make this bloc reachable headless:
///
///  * `CallOperationsServiceLocator.setup(dataSource: ...)` — the bloc resolves
///    its use cases through that singleton, so a fake data source replaces
///    every SDK call it would otherwise make.
///  * the permission_handler method channel, mocked here, which is what
///    `CallPermissions.requestForCallType` talks to.
///
/// What is left is genuinely out of reach: the navigation in
/// `_navigateToOutgoingCall` needs a live `CallNavigationContext.navigatorKey`
/// and would build the real outgoing-call screen.
///
///   flutter test test/call_ui/call_buttons/call_buttons_bloc_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// MessageStatus is declared twice in the package; the event listener uses the
// one from the clean-architecture constants.
// ignore: implementation_imports
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/enums.dart'
    as core_enums;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' show Permission;

import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';

import '../helpers/call_bloc_harness.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Everything the bloc can ask of the call-operations layer. Only
/// [initiateCall], [rejectCall] (a placed call that cannot be shown is
/// cancelled), [sendCustomMessage] and [getLoggedInUser] are used by these
/// paths; the rest throw so an unexpected call is loud rather than silent.
class _FakeDataSource implements CallOperationsDataSource {
  _FakeDataSource({this.loggedInUser});

  final User? loggedInUser;

  /// When set, `initiateCall` throws it instead of echoing the call back.
  CallOperationsException? initiateError;

  /// When set, `sendCustomMessage` throws it instead of echoing the message.
  CallOperationsException? sendError;

  /// When set, `initiateCall` answers with a call carrying this session, as
  /// the server does, instead of echoing the call back.
  String? placedSessionId;

  /// When set, `rejectCall` throws it instead of answering.
  CallOperationsException? rejectError;

  final List<Call> initiatedCalls = [];
  final List<CustomMessage> sentMessages = [];

  /// `rejectCall`s as (session, status).
  final List<(String, String)> rejects = [];

  /// When set, `initiateCall` waits for it before answering.
  Completer<void>? initiateGate;

  @override
  Future<Call> initiateCall(Call call) async {
    if (initiateError != null) throw initiateError!;
    initiatedCalls.add(call);
    await initiateGate?.future;
    final sessionId = placedSessionId;
    if (sessionId == null) return call;
    return Call(
      sessionId: sessionId,
      receiverUid: call.receiverUid,
      receiverType: call.receiverType,
      type: call.type,
    );
  }

  @override
  Future<CustomMessage> sendCustomMessage(CustomMessage message) async {
    if (sendError != null) throw sendError!;
    sentMessages.add(message);
    return message;
  }

  @override
  Future<User?> getLoggedInUser() async => loggedInUser;

  @override
  Future<Call> acceptCall(String sessionId) => throw UnimplementedError();

  @override
  Future<Call> endCall(String sessionId) => throw UnimplementedError();

  @override
  Future<void> endSession() => throw UnimplementedError();

  @override
  Future<String> generateCallToken(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<String?> getUserAuthToken() async => 'token';

  @override
  Future<Call> rejectCall(String sessionId, String status) async {
    rejects.add((sessionId, status));
    if (rejectError != null) throw rejectError!;
    return Call(
      sessionId: sessionId,
      receiverUid: 'u2',
      receiverType: 'user',
      type: 'audio',
      callStatus: status,
    );
  }

  /// The meeting's call screen joins at once.
  @override
  Future<Widget> startSession(
    String sessionId,
    SessionSettings settings,
  ) async => const SizedBox.shrink();

  @override
  Future<void> waitForCallsSdk() async {}
}

class _CallEventSpy with CometChatCallEventListener {
  final List<Call> outgoing = [];

  @override
  void ccOutgoingCall(Call call) => outgoing.add(call);
}

class _MessageEventSpy with CometChatMessageEventListener {
  final List<(BaseMessage, core_enums.MessageStatus)> sent = [];

  @override
  void ccMessageSent(
    BaseMessage message,
    core_enums.MessageStatus messageStatus,
  ) {
    sent.add((message, messageStatus));
  }
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

/// permission_handler's `PermissionStatus.granted` / `.denied` /
/// `.permanentlyDenied` indices.
const int _granted = 1;
const int _denied = 0;
const int _permanentlyDenied = 4;

/// Answers the permission channel with [status] for every permission asked.
void _mockPermissions(int status) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_permissionChannel, (call) async {
        switch (call.method) {
          case 'checkPermissionStatus':
            return status;
          case 'requestPermissions':
            return <int, int>{
              for (final p in call.arguments as List) p as int: status,
            };
          default:
            return null;
        }
      });
}

/// Waits for the bloc's async handler, which only awaits real futures.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Lets the bloc place a call and, 300 ms later, push its outgoing call
/// screen on the navigator [mountCallNavigator] put up.
Future<void> _placeAndPush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDataSource dataSource;
  late _CallEventSpy callSpy;
  late _MessageEventSpy messageSpy;

  setUp(() async {
    dataSource = _FakeDataSource(
      loggedInUser: User(uid: 'me', name: 'Me'),
    );
    await CallOperationsServiceLocator.instance.reset();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);

    callSpy = _CallEventSpy();
    messageSpy = _MessageEventSpy();
    CometChatCallEvents.addCallEventsListener('call_buttons_test', callSpy);
    CometChatMessageEvents.addMessagesListener('call_buttons_test', messageSpy);
    _mockPermissions(_granted);
  });

  tearDown(() async {
    CometChatCallEvents.removeCallEventsListener('call_buttons_test');
    CometChatMessageEvents.removeMessagesListener('call_buttons_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, null);
    await CallOperationsServiceLocator.instance.reset();
    ActiveCallTracker.debugResetPlacingCall();
  });

  // =========================================================================
  group('CallButtonsBloc — direct calls to a user', () {
    testWidgets('a voice call disables the buttons, then reports a call in '
        'progress', (tester) async {
      await mountCallNavigator(tester);
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );
      final states = <CallButtonsState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const InitiateVoiceCall());
      await _placeAndPush(tester);

      expect(states.map((s) => s.isDisabled).toList(), [true, false]);
      expect(states.last.isCallInProgress, isTrue);
      expect(states.last.errorMessage, isNull);
      expect(dataSource.initiatedCalls.single.receiverUid, 'u2');
      expect(dataSource.initiatedCalls.single.receiverType, 'user');
      expect(
        dataSource.initiatedCalls.single.type,
        CallTypeConstants.audioCall,
      );
      // The placed call is announced to the app.
      expect(callSpy.outgoing.single.category, 'call');

      await tester.runAsync(sub.cancel);
      await tester.runAsync(bloc.close);
    });

    testWidgets('a video call is placed with the video call type', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );

      bloc.add(const InitiateVideoCall());
      await _placeAndPush(tester);

      expect(
        dataSource.initiatedCalls.single.type,
        CallTypeConstants.videoCall,
      );
      expect(bloc.state.isCallInProgress, isTrue);

      await tester.runAsync(bloc.close);
    });

    testWidgets('a denied microphone stops an audio call before the network', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      _mockPermissions(_denied);
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );

      bloc.add(const InitiateVoiceCall());
      await tester.pump();
      await tester.pump();

      expect(dataSource.initiatedCalls, isEmpty);
      expect(bloc.state.isDisabled, isFalse);
      expect(bloc.state.isCallInProgress, isFalse);
      expect(
        bloc.state.errorMessage,
        'Microphone permission is required to start the call.',
      );

      await tester.runAsync(bloc.close);
    });

    testWidgets('a denied camera names both permissions for a video call', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      _mockPermissions(_denied);
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );

      bloc.add(const InitiateVideoCall());
      await tester.pump();
      await tester.pump();

      expect(dataSource.initiatedCalls, isEmpty);
      expect(
        bloc.state.errorMessage,
        'Microphone and camera permission is required to start the call.',
      );

      await tester.runAsync(bloc.close);
    });

    testWidgets('a denied microphone reaches onError as PERMISSION_DENIED, '
        'naming the missing permission (round 1b)', (tester) async {
      await mountCallNavigator(tester);
      _mockPermissions(_denied);
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: errors.add,
      );

      bloc.add(const InitiateVoiceCall());
      await tester.pump();
      await tester.pump();

      final error = errors.single as CometChatException;
      expect(error.code, 'PERMISSION_DENIED');
      expect(error.details, 'microphone');
      expect(error.errorParams?['permissions'], <String>['microphone']);
      expect(
        error.message,
        'Microphone permission is required to start the call.',
      );
      expect(dataSource.initiatedCalls, isEmpty);

      await tester.runAsync(bloc.close);
    });

    testWidgets('a permanently denied camera reaches onError as '
        'PERMISSION_PERMANENTLY_DENIED (round 1b)', (tester) async {
      await mountCallNavigator(tester);
      _mockPermissions(_permanentlyDenied);
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: errors.add,
      );

      bloc.add(const InitiateVideoCall());
      await tester.pump();
      await tester.pump();

      final error = errors.single as CometChatException;
      expect(error.code, 'PERMISSION_PERMANENTLY_DENIED');
      expect(error.details, 'microphone,camera');
      expect(dataSource.initiatedCalls, isEmpty);

      await tester.runAsync(bloc.close);
    });

    testWidgets('a video call with only the camera refused names the camera '
        '(round 2, P2-C02)', (tester) async {
      await mountCallNavigator(tester);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permissionChannel, (call) async {
            if (call.method != 'requestPermissions') return _granted;
            return <int, int>{
              for (final p in call.arguments as List)
                p as int: p == Permission.camera.value ? _denied : _granted,
            };
          });
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: errors.add,
      );

      bloc.add(const InitiateVideoCall());
      await tester.pump();
      await tester.pump();

      final error = errors.single as CometChatException;
      expect(error.code, 'PERMISSION_DENIED');
      expect(error.details, 'camera');
      expect(dataSource.initiatedCalls, isEmpty);

      await tester.runAsync(bloc.close);
    });

    testWidgets('a rejected initiation re-enables the buttons and reports the '
        'error', (tester) async {
      await mountCallNavigator(tester);
      dataSource.initiateError = const CallOperationsException(
        message: 'user is busy',
        code: 'CALL_BUSY',
      );
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: errors.add,
      );

      bloc.add(const InitiateVoiceCall());
      await _placeAndPush(tester);

      expect(bloc.state.isDisabled, isFalse);
      expect(bloc.state.isCallInProgress, isFalse);
      expect(bloc.state.errorMessage, 'user is busy');
      // The failure's code is kept and its text is the message (round 1b).
      // It used to be `CometChatException('ERR', failure.message, '')`, which
      // is (code, details, message): the code was lost and `message` empty.
      final reported = errors.single as CometChatException;
      expect(reported.message, 'user is busy');
      expect(reported.details, 'user is busy');
      expect(reported.code, 'CALL_BUSY');
      expect(callSpy.outgoing, isEmpty);

      await tester.runAsync(bloc.close);
    });

    testWidgets('a rejected initiation hands errorCallback the SDK\'s own '
        'exception (round 1b)', (tester) async {
      await mountCallNavigator(tester);
      final sdkError = CometChatException(
        'ERR_UID_NOT_FOUND',
        'The user with uid u2 does not exist.',
        'User not found',
      );
      dataSource.initiateError = CallOperationsException(
        message: 'User not found',
        code: 'ERR_UID_NOT_FOUND',
        originalException: sdkError,
      );
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: errors.add,
      );

      bloc.add(const InitiateVoiceCall());
      await _placeAndPush(tester);

      expect(errors.single, same(sdkError));

      await tester.runAsync(bloc.close);
    });

    testWidgets('with neither user nor group the call fails validation', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      final bloc = CallButtonsBloc();

      bloc.add(const InitiateVoiceCall());
      await _placeAndPush(tester);

      // No receiver id, so the use case refuses before the data source.
      expect(dataSource.initiatedCalls, isEmpty);
      expect(bloc.state.errorMessage, 'Receiver UID is required');
      expect(bloc.state.isDisabled, isFalse);

      await tester.runAsync(bloc.close);
    });

    testWidgets(
      'a custom call-settings builder is consulted for the call type',
      (tester) async {
        await mountCallNavigator(tester);
        final calls = <(User?, Group?, bool?)>[];
        final user = User(uid: 'u2', name: 'U2');
        final bloc = CallButtonsBloc(
          user: user,
          callSettingsBuilder: (u, g, isAudioOnly) {
            calls.add((u, g, isAudioOnly));
            return SessionSettingsBuilder();
          },
        );

        bloc.add(const InitiateVideoCall());
        await _placeAndPush(tester);

        expect(calls.single.$1, same(user));
        expect(calls.single.$2, isNull);
        // A video call is not audio-only.
        expect(calls.single.$3, isFalse);

        await tester.runAsync(bloc.close);
      },
    );

    testWidgets(
      'the outgoing-call configuration supplies the session settings when '
      'no builder is given',
      (tester) async {
        await mountCallNavigator(tester);
        final settings = SessionSettingsBuilder();
        final bloc = CallButtonsBloc(
          user: User(uid: 'u2', name: 'U2'),
          outgoingCallConfiguration: CometChatOutgoingCallConfiguration(
            sessionSettingsBuilder: settings,
          ),
        );

        bloc.add(const InitiateVoiceCall());
        await _placeAndPush(tester);

        // The configured builder is used as-is instead of a default being built;
        // what is observable here is that the call still goes through.
        expect(
          bloc.outgoingCallConfiguration?.sessionSettingsBuilder,
          settings,
        );
        expect(dataSource.initiatedCalls.single.receiverUid, 'u2');

        await tester.runAsync(bloc.close);
      },
    );
  });

  // =========================================================================
  // Round 2, P2-C01: one placement at a time, and nothing leaves the
  // buttons dead.
  group('CallButtonsBloc — the placement guard (round 2, P2-C01)', () {
    /// Answers every permission request with granted and counts them.
    List<String> countPermissionRequests() {
      final requests = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permissionChannel, (call) async {
            if (call.method != 'requestPermissions') return _granted;
            requests.add(call.method);
            return <int, int>{
              for (final p in call.arguments as List) p as int: _granted,
            };
          });
      return requests;
    }

    testWidgets('P2-E01: two taps in one frame place one call and ask for '
        'permission once', (tester) async {
      await mountCallNavigator(tester);
      final requests = countPermissionRequests();
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );

      bloc
        ..add(const InitiateVoiceCall())
        ..add(const InitiateVoiceCall());
      await tester.pumpAndSettle();

      expect(dataSource.initiatedCalls, hasLength(1));
      expect(requests, hasLength(1));
      expect(callSpy.outgoing, hasLength(1));

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(bloc.close);
    });

    testWidgets('P2-E02: voice and video pressed together place one call', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      final requests = countPermissionRequests();
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );

      bloc
        ..add(const InitiateVoiceCall())
        ..add(const InitiateVideoCall());
      await tester.pumpAndSettle();

      expect(dataSource.initiatedCalls, hasLength(1));
      expect(
        dataSource.initiatedCalls.single.type,
        CallTypeConstants.audioCall,
      );
      expect(requests, hasLength(1));

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(bloc.close);
    });

    // Round 2 review: two blocs (a header rebuilt for someone else while a
    // call is being placed, two card taps in master_app) placed two calls.
    testWidgets('another bloc placing a call meanwhile: ACTIVE_CALL, nothing '
        'placed; once that one is done, the next tap goes through', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      final server = Completer<void>();
      dataSource.initiateGate = server;
      final first = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        outgoingCallConfiguration: CometChatOutgoingCallConfiguration(
          disableSoundForCalls: true,
        ),
      );
      final errors = <Exception>[];
      final second = CallButtonsBloc(
        user: User(uid: 'u3', name: 'U3'),
        errorCallback: errors.add,
        outgoingCallConfiguration: CometChatOutgoingCallConfiguration(
          disableSoundForCalls: true,
        ),
      );

      first.add(const InitiateVoiceCall());
      await tester.pump();
      expect(dataSource.initiatedCalls, hasLength(1));
      second.add(const InitiateVideoCall());
      await tester.pump();

      expect(errors.map((e) => (e as CometChatException).code), <String>[
        'ACTIVE_CALL',
      ]);
      expect(second.state.isDisabled, isFalse);
      expect(dataSource.initiatedCalls, hasLength(1));

      server.complete();
      await tester.pumpAndSettle();
      expect(ActiveCallTracker.isPlacingCall, isFalse);
      second.add(const InitiateVideoCall());
      await tester.pumpAndSettle();
      expect(dataSource.initiatedCalls, hasLength(2));
      expect(dataSource.initiatedCalls.last.receiverUid, 'u3');

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(first.close);
      await tester.runAsync(second.close);
    });

    testWidgets('once a placement is over the next tap goes through', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      _mockPermissions(_denied);
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: errors.add,
      );

      bloc.add(const InitiateVoiceCall());
      await tester.pumpAndSettle();
      bloc.add(const InitiateVoiceCall());
      await tester.pumpAndSettle();

      expect(errors, hasLength(2));
      await tester.runAsync(bloc.close);
    });

    testWidgets('a permission request that throws brings the buttons back '
        'and reaches onError with its code', (tester) async {
      await mountCallNavigator(tester);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permissionChannel, (call) async {
            throw PlatformException(
              code: 'PermissionHandler.PermissionManager',
              message: 'A request for permissions is already running.',
            );
          });
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: errors.add,
      );
      final states = <CallButtonsState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const InitiateVoiceCall());
      await tester.pumpAndSettle();

      expect(states.first.isDisabled, isTrue);
      expect(bloc.state.isDisabled, isFalse);
      expect(bloc.state.isCallInProgress, isFalse);
      final error = errors.single as CometChatException;
      expect(error.code, 'PermissionHandler.PermissionManager');
      expect(error.message, 'A request for permissions is already running.');
      expect(dataSource.initiatedCalls, isEmpty);

      // And the next tap is not dropped.
      _mockPermissions(_granted);
      bloc.add(const InitiateVoiceCall());
      await tester.pumpAndSettle();
      expect(dataSource.initiatedCalls, hasLength(1));

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(sub.cancel);
      await tester.runAsync(bloc.close);
    });

    testWidgets('a header reused for another user calls that user', (
      tester,
    ) async {
      SoundChannelSpy.install();
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget header(User user) => MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        localizationsDelegates: Translations.localizationsDelegates,
        home: Scaffold(
          body: CometChatCallButtons(user: user, hideVideoCallButton: true),
        ),
      );

      /// The call buttons blocs listening for call events now.
      List<CallButtonsBloc> listening() => CometChatCallEvents
          .callEventsListener
          .values
          .whereType<CallButtonsBloc>()
          .toList();

      await tester.pumpWidget(header(User(uid: 'u1', name: 'U1')));
      final CallButtonsBloc first = listening().single;
      await tester.pumpWidget(header(User(uid: 'u2', name: 'U2')));

      // Round 2 review (R23): the bloc built for the first user is closed,
      // its listeners gone with it; only the new one listens.
      expect(first.isClosed, isTrue);
      expect(listening().single, isNot(same(first)));

      await tester.tap(find.byIcon(Icons.call_outlined));
      await tester.pumpAndSettle();

      expect(dataSource.initiatedCalls.single.receiverUid, 'u2');
      await tester.pumpWidget(const SizedBox());
      expect(listening(), isEmpty);
    });

    testWidgets('a header whose receiver stays the same keeps its bloc', (
      tester,
    ) async {
      SoundChannelSpy.install();
      Widget header(User user) => MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        home: Scaffold(body: CometChatCallButtons(user: user)),
      );
      await tester.pumpWidget(header(User(uid: 'u1', name: 'U1')));
      final CallButtonsBloc first = CometChatCallEvents
          .callEventsListener
          .values
          .whereType<CallButtonsBloc>()
          .single;
      await tester.pumpWidget(header(User(uid: 'u1', name: 'U1 renamed')));

      expect(first.isClosed, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(first.isClosed, isTrue);
    });
  });

  // =========================================================================
  // Round 2, P2-C03: the outgoing screen opens through the one launcher.
  group('CallButtonsBloc — the outgoing screen (round 2, P2-C03)', () {
    testWidgets('P2-N19: the buttons stay off until the outgoing screen is '
        'up, which is on the next frame', (tester) async {
      await mountCallNavigator(tester);
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );

      bloc.add(const InitiateVoiceCall());
      await tester.idle();

      // Placed and announced; the screen waits for the frame.
      expect(callSpy.outgoing, hasLength(1));
      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(bloc.state.isDisabled, isTrue);

      await tester.pump();
      expect(bloc.state.isDisabled, isFalse);
      await tester.pumpAndSettle();

      expect(find.byType(CometChatOutgoingCall), findsOneWidget);
      expect(bloc.state.isDisabled, isFalse);
      expect(bloc.state.isCallInProgress, isTrue);
      final screen = tester.widget<CometChatOutgoingCall>(
        find.byType(CometChatOutgoingCall),
      );
      expect(screen.user?.name, 'U2');

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(bloc.close);
    });

    testWidgets('P2-E14: the chat is left while the call is being placed: '
        'once placed, its screen still opens (owner, P2-D07 A)', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      final server = Completer<void>();
      dataSource
        ..placedSessionId = 'placed-7'
        ..initiateGate = server;
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        outgoingCallConfiguration: CometChatOutgoingCallConfiguration(
          disableSoundForCalls: true,
        ),
      );

      bloc.add(const InitiateVoiceCall());
      await tester.pump();
      expect(dataSource.initiatedCalls, hasLength(1));

      // The chat, and the header's bloc with it, go. (Its close completes
      // once the placement it is running has finished.)
      unawaited(bloc.close());
      await tester.pump();
      expect(bloc.isClosed, isTrue);
      server.complete();
      await tester.pumpAndSettle();

      expect(callSpy.outgoing.single.sessionId, 'placed-7');
      final screen = tester.widget<CometChatOutgoingCall>(
        find.byType(CometChatOutgoingCall),
      );
      expect(screen.call.sessionId, 'placed-7');
      expect(screen.disableSoundForCalls, isTrue);

      await tester.pumpWidget(const SizedBox());
    });
  });

  // =========================================================================
  // Round 1b: a call is only placed when its screen can be shown.
  group('CallButtonsBloc — no navigator (round 1b)', () {
    tearDown(() {
      CometChatCallEvents.removeCallEventsListener('CallEventService');
      CallEventService.instance.activeCall = null;
    });

    test('no navigator: NO_NAVIGATOR, and nothing is placed', () async {
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: errors.add,
      );

      bloc.add(const InitiateVoiceCall());
      await _settle();

      expect((errors.single as CometChatException).code, 'NO_NAVIGATOR');
      expect(dataSource.initiatedCalls, isEmpty);
      expect(dataSource.rejects, isEmpty);
      expect(bloc.state.isDisabled, isFalse);
      expect(bloc.state.isCallInProgress, isFalse);

      await bloc.close();
    });

    test('no navigator: refused before the permission prompt (round 1b '
        'review)', () async {
      final asked = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permissionChannel, (call) async {
            asked.add(call.method);
            return <int, int>{
              for (final p in call.arguments as List) p as int: _granted,
            };
          });
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: errors.add,
      );

      bloc.add(const InitiateVoiceCall());
      await _settle();

      expect((errors.single as CometChatException).code, 'NO_NAVIGATOR');
      expect(asked, isEmpty);

      await bloc.close();
    });

    testWidgets('the navigator goes before the screen can be pushed: the '
        'placed call is released, cancelled, and onError gets NO_NAVIGATOR', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      // The UI Kit's own listener, so ccOutgoingCall sets the record.
      CometChatCallEvents.addCallEventsListener(
        'CallEventService',
        CallEventService.instance,
      );
      dataSource.placedSessionId = 'placed-1';
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: errors.add,
      );

      final server = Completer<void>();
      dataSource.initiateGate = server;
      bloc.add(const InitiateVoiceCall());
      await tester.pump();

      // The host's navigator goes away while the call is being placed.
      await tester.pumpWidget(const SizedBox());
      server.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(CallEventService.instance.activeCall, isNull);
      expect((errors.single as CometChatException).code, 'NO_NAVIGATOR');
      expect(dataSource.rejects, [('placed-1', 'cancelled')]);
      expect(bloc.state.isCallInProgress, isFalse);
      expect(bloc.state.isDisabled, isFalse);

      await tester.runAsync(bloc.close);
    });

    testWidgets('an onError that throws does not stop the release, the '
        'cancel or the buttons coming back (round 1b review)', (tester) async {
      await mountCallNavigator(tester);
      CometChatCallEvents.addCallEventsListener(
        'CallEventService',
        CallEventService.instance,
      );
      dataSource.placedSessionId = 'placed-3';
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: (Exception e) => throw StateError('host bug'),
      );

      final server = Completer<void>();
      dataSource.initiateGate = server;
      bloc.add(const InitiateVoiceCall());
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      server.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull);
      expect(CallEventService.instance.activeCall, isNull);
      expect(dataSource.rejects, [('placed-3', 'cancelled')]);
      expect(bloc.state.isDisabled, isFalse);
      expect(bloc.state.isCallInProgress, isFalse);

      await tester.runAsync(bloc.close);
    });

    testWidgets('a cancel of that call that fails reaches onError too, SDK '
        'code kept', (tester) async {
      await mountCallNavigator(tester);
      dataSource
        ..placedSessionId = 'placed-2'
        ..rejectError = CallOperationsException(
          message: 'Call already ended',
          code: 'ERR_CALL_ENDED',
          originalException: CometChatException(
            'ERR_CALL_ENDED',
            'The call has already ended.',
            'Call already ended',
          ),
        );
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: errors.add,
      );

      final server = Completer<void>();
      dataSource.initiateGate = server;
      bloc.add(const InitiateVoiceCall());
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      server.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(errors.map((e) => (e as CometChatException).code), <String>[
        'NO_NAVIGATOR',
        'ERR_CALL_ENDED',
      ]);

      await tester.runAsync(bloc.close);
    });
  });

  // =========================================================================
  group('CallButtonsBloc — meetings in a group', () {
    test('a denied microphone stops a meeting with a meeting-specific '
        'message', () async {
      _mockPermissions(_denied);
      final bloc = CallButtonsBloc(
        group: Group(guid: 'g1', name: 'G1', type: GroupTypeConstants.public),
      );

      bloc.add(const InitiateVoiceCall());
      await _settle();

      expect(dataSource.sentMessages, isEmpty);
      expect(
        bloc.state.errorMessage,
        'Microphone permission is required to start the meeting.',
      );
      expect(bloc.state.isDisabled, isFalse);

      await bloc.close();
    });

    test('a denied microphone for a meeting reaches onError as '
        'PERMISSION_DENIED (round 1b)', () async {
      _mockPermissions(_denied);
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        group: Group(guid: 'g1', name: 'G1', type: GroupTypeConstants.public),
        errorCallback: errors.add,
      );

      bloc.add(const InitiateVoiceCall());
      await _settle();

      final error = errors.single as CometChatException;
      expect(error.code, 'PERMISSION_DENIED');
      expect(
        error.message,
        'Microphone permission is required to start the meeting.',
      );
      expect(dataSource.sentMessages, isEmpty);

      await bloc.close();
    });

    test(
      'a denied camera names both permissions for a video meeting',
      () async {
        _mockPermissions(_denied);
        final bloc = CallButtonsBloc(
          group: Group(guid: 'g1', name: 'G1', type: GroupTypeConstants.public),
        );

        bloc.add(const InitiateVideoCall());
        await _settle();

        expect(
          bloc.state.errorMessage,
          'Microphone and camera permission is required to start the meeting.',
        );

        await bloc.close();
      },
    );

    testWidgets('a meeting opens the call overlay and announces a meeting '
        'message', (tester) async {
      // The meeting screen joins for real: a ready Calls SDK behind it.
      await installReadyCallsSdk();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const SizedBox(),
        ),
      );
      addTearDown(() {
        CallScreenOverlay.dismiss();
        CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
        uninstallCallsSdk();
      });
      final group = Group(
        guid: 'g1',
        name: 'G1',
        type: GroupTypeConstants.public,
      );
      final bloc = CallButtonsBloc(group: group);

      bloc.add(const InitiateVoiceCall());
      await tester.pump();
      await tester.pump();

      expect(CallScreenOverlay.isShowing, isTrue);
      final message = dataSource.sentMessages.single;
      expect(message.receiverUid, 'g1');
      expect(message.receiverType, ReceiverTypeConstants.group);
      expect(message.type, MessageTypeConstants.meeting);
      expect(message.customData?['sessionID'], 'g1');
      expect(message.customData?['callType'], CallTypeConstants.audioCall);
      expect(message.sender?.uid, 'me');
      // The unread-count flag is what makes the meeting bubble count for
      // members who are not looking at the group.
      expect(
        message.metadata?[UpdateSettingsConstant.incrementUnreadCount],
        isTrue,
      );
      // Round 5 (P5-C01): the message's events come from
      // CometChatUIKit.sendCustomMessage alone; the bloc used to send a
      // second ccMessageSent of its own.
      expect(messageSpy.sent, isEmpty);
      expect(bloc.state.isCallInProgress, isTrue);
      expect(bloc.state.isDisabled, isFalse);

      CallScreenOverlay.dismiss();
      await tester.pump();
      await tester.runAsync(bloc.close);
    });

    test('with no navigator a meeting reports NO_NAVIGATOR, announces '
        'nothing, and can be tried again (round 1b)', () async {
      // It used to keep the uninserted overlay entry: the first meeting
      // announced a meeting nobody could see, and the second threw on
      // removing that entry, leaving the button dead.
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        group: Group(guid: 'g1', name: 'G1', type: GroupTypeConstants.public),
        errorCallback: errors.add,
      );

      for (var attempt = 1; attempt <= 2; attempt++) {
        bloc.add(const InitiateVoiceCall());
        await _settle();

        expect(CallScreenOverlay.isShowing, isFalse);
        expect(errors, hasLength(attempt));
        expect((errors.last as CometChatException).code, 'NO_NAVIGATOR');
        expect(dataSource.sentMessages, isEmpty);
        expect(bloc.state.isDisabled, isFalse);
        expect(bloc.state.isCallInProgress, isFalse);
      }

      await bloc.close();
    });
  });

  // =========================================================================
  group('CallButtonsBloc — call lifecycle events', () {
    /// The call the server placed for these tests.
    Call placed() => Call(
      sessionId: 'placed',
      receiverUid: 'u2',
      receiverType: 'user',
      type: 'audio',
    );

    setUp(() => dataSource.placedSessionId = 'placed');

    testWidgets('a rejected call re-enables the buttons', (tester) async {
      await mountCallNavigator(tester);
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );
      bloc.add(const InitiateVoiceCall());
      await _placeAndPush(tester);
      expect(bloc.state.isCallInProgress, isTrue);

      bloc.add(CallRejected(placed()));
      await _placeAndPush(tester);

      expect(bloc.state.isDisabled, isFalse);
      expect(bloc.state.isCallInProgress, isFalse);
      expect(bloc.state.errorMessage, isNull);

      await tester.runAsync(bloc.close);
    });

    testWidgets('an ended call re-enables the buttons and clears the error, '
        'once it is the call these buttons placed', (tester) async {
      await mountCallNavigator(tester);
      dataSource.initiateError = const CallOperationsException(message: 'busy');
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );
      bloc.add(const InitiateVoiceCall());
      await _placeAndPush(tester);
      expect(bloc.state.errorMessage, 'busy');

      // Nothing was placed, so an ended call is not these buttons' call:
      // the error stays until the next tap.
      bloc.add(CallEnded(placed()));
      await _placeAndPush(tester);
      expect(bloc.state.errorMessage, 'busy');

      dataSource.initiateError = null;
      bloc.add(const InitiateVoiceCall());
      await _placeAndPush(tester);
      bloc.add(CallEnded(placed()));
      await _placeAndPush(tester);

      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.isDisabled, isFalse);
      expect(bloc.state.isCallInProgress, isFalse);

      await tester.runAsync(bloc.close);
    });

    testWidgets('the SDK and UI-kit listener callbacks feed the same events', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      final call = placed();

      for (final fire in <void Function(CallButtonsBloc)>[
        (b) => b.onOutgoingCallRejected(call),
        (b) => b.onCallEndedMessageReceived(call),
        (b) => b.ccCallRejected(call),
        (b) => b.ccCallEnded(call),
      ]) {
        final bloc = CallButtonsBloc(
          user: User(uid: 'u2', name: 'U2'),
        );
        bloc.add(const InitiateVoiceCall());
        await _placeAndPush(tester);
        expect(bloc.state.isCallInProgress, isTrue);

        fire(bloc);
        await _placeAndPush(tester);

        expect(bloc.state.isCallInProgress, isFalse);
        expect(bloc.state.isDisabled, isFalse);
        await tester.runAsync(bloc.close);
      }
    });

    testWidgets("another call's end leaves the call in progress", (
      tester,
    ) async {
      await mountCallNavigator(tester);
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );
      bloc.add(const InitiateVoiceCall());
      await _placeAndPush(tester);
      expect(bloc.state.isCallInProgress, isTrue);

      bloc
        ..ccCallEnded(
          Call(
            sessionId: 'someone-elses',
            receiverUid: 'x',
            receiverType: 'user',
            type: 'audio',
          ),
        )
        ..onOutgoingCallRejected(
          Call(receiverUid: 'x', receiverType: 'user', type: 'audio'),
        );
      await _placeAndPush(tester);

      expect(bloc.state.isCallInProgress, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(bloc.close);
    });

    testWidgets('the last call ending while the next is being placed '
        'leaves the buttons off until that placement is done', (tester) async {
      await mountCallNavigator(tester);
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        outgoingCallConfiguration: CometChatOutgoingCallConfiguration(
          disableSoundForCalls: true,
        ),
      );
      bloc.add(const InitiateVoiceCall());
      await _placeAndPush(tester);
      expect(bloc.state.isCallInProgress, isTrue);

      PermissionChannelStub.install(granted: true);
      final prompt = Completer<void>();
      PermissionChannelStub.gate = prompt;
      addTearDown(PermissionChannelStub.remove);
      dataSource.placedSessionId = 'placed-2';
      bloc.add(const InitiateVideoCall());
      await tester.pump();
      expect(bloc.state.isDisabled, isTrue);

      // The first call's end arrives now.
      bloc.ccCallEnded(placed());
      await tester.pump();
      expect(bloc.state.isDisabled, isTrue);

      prompt.complete();
      await tester.pumpAndSettle();
      expect(bloc.state.isDisabled, isFalse);
      expect(bloc.state.isCallInProgress, isTrue);
      expect(dataSource.initiatedCalls, hasLength(2));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(bloc.close);
    });

    // Round 2 review (probe C): an unrelated call ending while a call is
    // being placed brought the buttons back mid-way. master_app's card
    // action closes its bloc on the first state with the buttons back, and
    // the call was then dropped without a word.
    testWidgets('an unrelated call ending during the permission prompt '
        'leaves the buttons off, and a host that waits for them to come '
        'back still gets its call placed', (tester) async {
      await mountCallNavigator(tester);
      PermissionChannelStub.install(granted: true);
      final prompt = Completer<void>();
      PermissionChannelStub.gate = prompt;
      addTearDown(PermissionChannelStub.remove);
      final errors = <Exception>[];
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
        errorCallback: errors.add,
        outgoingCallConfiguration: CometChatOutgoingCallConfiguration(
          disableSoundForCalls: true,
        ),
      );
      // What master_app's card action does.
      unawaited(
        bloc.stream
            .firstWhere((CallButtonsState s) => !s.isDisabled)
            .then((_) => bloc.close()),
      );

      bloc.add(const InitiateVoiceCall());
      await tester.pump();
      expect(bloc.state.isDisabled, isTrue);

      CometChatCallEvents.ccCallRejected(
        Call(
          sessionId: 'someone-else',
          receiverUid: 'x',
          receiverType: 'user',
          type: 'audio',
        ),
      );
      CometChatCallEvents.ccCallEnded(
        Call(
          sessionId: 'someone-else',
          receiverUid: 'x',
          receiverType: 'user',
          type: 'audio',
        ),
      );
      await tester.pump();
      expect(bloc.state.isDisabled, isTrue);
      expect(bloc.isClosed, isFalse);

      prompt.complete();
      await tester.pumpAndSettle();

      expect(dataSource.initiatedCalls, hasLength(1));
      expect(find.byType(CometChatOutgoingCall), findsOneWidget);
      expect(bloc.isClosed, isTrue);
      expect(errors, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });

  // =========================================================================
  group('CallButtonsBloc — lifecycle', () {
    test('starts in the initial state', () async {
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );

      expect(bloc.state, CallButtonsState.initial());
      expect(bloc.state.isDisabled, isFalse);

      await bloc.close();
    });

    test('registers a UI-kit call listener and removes it on close', () async {
      final before = CometChatCallEvents.callEventsListener.length;
      final bloc = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );

      expect(CometChatCallEvents.callEventsListener.length, before + 1);

      await bloc.close();

      expect(CometChatCallEvents.callEventsListener.length, before);
    });

    test('two blocs register under different listener ids', () async {
      final before = CometChatCallEvents.callEventsListener.length;
      final a = CallButtonsBloc(
        user: User(uid: 'u2', name: 'U2'),
      );
      final b = CallButtonsBloc(
        user: User(uid: 'u3', name: 'U3'),
      );

      expect(CometChatCallEvents.callEventsListener.length, before + 2);

      await a.close();
      await b.close();
    });
  });
}
