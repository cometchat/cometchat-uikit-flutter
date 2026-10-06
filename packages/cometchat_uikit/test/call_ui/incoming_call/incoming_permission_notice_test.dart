/// What the user sees when an incoming call cannot be answered (round 3:
/// P3-C05 under the owner's strict rule, and the review's "benign
/// accept/decline failures").
///
/// Before: a refused permission declined the call and the banner simply
/// vanished (its error state landed after the dismiss), and an accept or a
/// decline that failed because the call was already over showed a red
/// "Something went wrong".
///
/// Now, with no `onError`: a SnackBar on the app's navigator says the
/// microphone (and camera, for a video call) is needed, with a Settings
/// action when the system will not ask again; a call that was already over
/// shows nothing. `onError` still hears of everything, codes kept.
///
///   flutter test test/call_ui/incoming_call/incoming_permission_notice_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_incoming_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/call_errors.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:cometchat_chat_uikit/src/sound_loop_owner.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import '../helpers/call_bloc_harness.dart';

const MethodChannel _permissions = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;
  late CallEventRecorder events;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    SoundChannelSpy.install();
    PermissionChannelStub.install(granted: true);
    incomingRingtoneLoop.reset();
    ActiveCallTracker.ringingCall = null;
    events = CallEventRecorder('incoming_permission_notice_test');
  });

  tearDown(() async {
    events.dispose();
    SoundChannelSpy.remove();
    PermissionChannelStub.remove();
    incomingRingtoneLoop.reset();
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.incomingCallSessionId = null;
    ActiveCallTracker.forgetFinishedCalls();
    CallStateService.instance.setActiveIncomingValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    await CallOperationsServiceLocator.instance.reset();
  });

  /// The app as a host has it: a Scaffold under the navigator, so a SnackBar
  /// has somewhere to show. The incoming call's banner over it.
  Future<void> ring(
    WidgetTester tester, {
    String type = CallTypeConstants.audioCall,
    OnError? onError,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        localizationsDelegates: Translations.localizationsDelegates,
        home: const Scaffold(body: Text('chats')),
      ),
    );
    final Call call = buildCall(type: type);
    ActiveCallTracker.ringingCall = call;
    IncomingCallOverlay.show(
      context: CallNavigationContext.navigatorKey.currentContext!,
      call: call,
      user: User(uid: 'peer', name: 'Peer'),
      onError: onError,
      disableSoundForCalls: true,
    );
    await tester.pump();
  }

  Future<void> tapAccept(WidgetTester tester) async {
    await tester.tap(find.text('Accept'));
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
  }

  group('P3-C05: a refused permission at accept', () {
    testWidgets('P3-E22: microphone refused, no onError: the call is declined '
        'and the user is told why, with no Settings action and no "Something '
        'went wrong"', (WidgetTester tester) async {
      PermissionChannelStub.install(granted: false);
      await ring(tester);

      await tapAccept(tester);

      expect(find.byType(CometChatIncomingCall), findsNothing);
      expect(dataSource.calls, <String>['rejectCall:session_1:rejected']);
      expect(events.ordered, <String>['rejected:session_1']);
      expect(ActiveCallTracker.ringingCall, isNull);
      expect(
        find.text('Allow microphone access to answer calls.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBarAction), findsNothing);
      expect(find.text('Something went wrong'), findsNothing);

      // Nor queued behind it: the messenger shows one SnackBar at a time.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('P3-E23: permanently refused: the SnackBar offers Settings, '
        'which opens the app\'s settings page', (WidgetTester tester) async {
      PermissionChannelStub.install(granted: false, permanentlyDenied: true);
      final List<String> opened = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permissions, (MethodCall call) async {
            if (call.method == 'openAppSettings') {
              opened.add(call.method);
              return true;
            }
            if (call.method == 'requestPermissions') {
              final List<int> values = List<int>.from(
                call.arguments as List<Object?>,
              );
              return <int, int>{for (final int v in values) v: 4};
            }
            return 4;
          });
      await ring(tester);

      await tapAccept(tester);

      expect(find.byType(SnackBarAction), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.runAsync(pumpEventQueue);
      expect(opened, <String>['openAppSettings']);
    });

    testWidgets('P3-E24: a video call with only the camera refused is declined '
        '(strict rule), and the message names both', (
      WidgetTester tester,
    ) async {
      PermissionChannelStub.install(
        granted: false,
        grantedPermissions: <Permission>{Permission.microphone},
      );
      await ring(tester, type: CallTypeConstants.videoCall);

      await tapAccept(tester);

      expect(dataSource.acceptCallCount, 0);
      expect(dataSource.calls, <String>['rejectCall:session_1:rejected']);
      expect(
        find.text('Allow camera and microphone access to answer video calls.'),
        findsOneWidget,
      );
    });

    testWidgets('with an onError the host is told (PERMISSION_DENIED) and the '
        'UI Kit shows nothing itself', (WidgetTester tester) async {
      PermissionChannelStub.install(granted: false);
      final List<Exception> errors = <Exception>[];
      await ring(tester, onError: errors.add);

      await tapAccept(tester);

      expect(
        (errors.single as CometChatException).code,
        CallErrorCodes.permissionDenied,
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failed decline after the refusal still announces it '
        '(ccCallRejected) and releases the record', (
      WidgetTester tester,
    ) async {
      PermissionChannelStub.install(granted: false);
      dataSource.rejectError = const CallOperationsException(message: 'down');
      final List<Exception> errors = <Exception>[];
      await ring(tester, onError: errors.add);

      await tapAccept(tester);

      expect(events.ordered, <String>['rejected:session_1']);
      expect(ActiveCallTracker.ringingCall, isNull);
      expect(errors, hasLength(2));
    });

    testWidgets('the permission plugin failing declines the call and reports '
        'the platform error: the banner is not left with both buttons off', (
      WidgetTester tester,
    ) async {
      PermissionChannelStub.requestError = PlatformException(
        code: 'ERROR_ALREADY_REQUESTING_PERMISSIONS',
        message: 'A request for permissions is already running',
      );
      final List<Exception> errors = <Exception>[];
      await ring(tester, onError: errors.add);

      await tapAccept(tester);

      expect(find.byType(CometChatIncomingCall), findsNothing);
      expect(dataSource.calls, <String>['rejectCall:session_1:rejected']);
      expect(
        (errors.single as CometChatException).code,
        'ERROR_ALREADY_REQUESTING_PERMISSIONS',
      );
      expect(ActiveCallTracker.ringingCall, isNull);
    });
  });

  // Round 3 review: the notice waited for the decline's round trip (up to
  // about a minute on a bad network), and nothing checked for a logout
  // after it.
  group('the refused permission is explained at once', () {
    testWidgets('the SnackBar shows as the banner goes, while the decline is '
        'still on its way', (WidgetTester tester) async {
      PermissionChannelStub.install(granted: false);
      final Completer<void> server = Completer<void>();
      dataSource.rejectGate = server;
      await ring(tester);

      await tapAccept(tester);

      expect(find.byType(CometChatIncomingCall), findsNothing);
      expect(
        find.text('Allow microphone access to answer calls.'),
        findsOneWidget,
      );
      expect(dataSource.rejectCallCount, 1);
      server.complete();
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
    });

    test('onError hears of the refusal before the decline lands', () async {
      PermissionChannelStub.install(granted: false);
      final Completer<void> server = Completer<void>();
      dataSource.rejectGate = server;
      final List<Exception> errors = <Exception>[];
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
        errorCallback: errors.add,
      );
      addTearDown(bloc.close);

      bloc.add(const AcceptCall());
      await pumpEventQueue();
      expect(dataSource.rejectCallCount, 1);
      expect(
        (errors.single as CometChatException).code,
        CallErrorCodes.permissionDenied,
      );
      server.complete();
      await pumpEventQueue();
    });

    test('a logout while the decline is on its way: its answer is only '
        'logged (no event, no report, no state)', () async {
      PermissionChannelStub.install(granted: false);
      final Completer<void> server = Completer<void>();
      dataSource.rejectGate = server;
      dataSource.rejectError = const CallOperationsException(
        message: 'Network down',
        code: 'NETWORK',
      );
      final List<Exception> errors = <Exception>[];
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
        errorCallback: errors.add,
      );
      addTearDown(bloc.close);

      bloc.add(const AcceptCall());
      await pumpEventQueue();
      expect(errors, hasLength(1));
      final IncomingCallStatus before = bloc.state.status;
      CallsLifecycle.tearDownLocalCalls();
      server.complete();
      await pumpEventQueue();

      expect(errors, hasLength(1), reason: 'the failed decline not reported');
      expect(events.rejected, isEmpty);
      expect(bloc.state.status, before);
    });
  });

  group('a call already over by the time the request landed', () {
    for (final (String code, String message) in <(String, String)>[
      ('ERR_CALL_TERMINATED', 'The call with sessionid session_1 is ended.'),
      ('ERR_HTTP_400', 'The call has already been cancelled.'),
    ]) {
      testWidgets('P3-E04 / P3-E12: an accept failing with $code shows no '
          '"Something went wrong"; onError-less hosts see the banner go', (
        WidgetTester tester,
      ) async {
        dataSource.acceptError = CallOperationsException(
          message: message,
          code: code,
          originalException: CometChatException(code, message, message),
        );
        await ring(tester);

        await tapAccept(tester);

        expect(find.byType(CometChatIncomingCall), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(ActiveCallTracker.ringingCall, isNull);
      });
    }

    testWidgets('onError still gets the SDK\'s exception, code kept', (
      WidgetTester tester,
    ) async {
      final CometChatException sdk = CometChatException(
        'ERR_CALL_TERMINATED',
        'The call with sessionid session_1 is ended.',
        'The call with sessionid session_1 is ended.',
      );
      dataSource.acceptError = CallOperationsException(
        message: sdk.message!,
        code: sdk.code,
        originalException: sdk,
      );
      final List<Exception> errors = <Exception>[];
      await ring(tester, onError: errors.add);

      await tapAccept(tester);

      expect(errors.single, same(sdk));
    });

    test('isCallAlreadyOver: the server\'s "is ended" and the usual wording '
        'of a call already over, not a network failure', () {
      bool over(String code, String message) =>
          isCallAlreadyOver(CometChatException(code, message, message));
      expect(over('ERR_CALL_TERMINATED', ''), isTrue);
      expect(over('X', 'The call with sessionid abc is ended.'), isTrue);
      expect(over('X', 'Call already ended'), isTrue);
      expect(over('X', 'The call was cancelled by the initiator'), isTrue);
      expect(over('X', 'The call has been rejected'), isTrue);
      expect(over('X', 'Call is unanswered'), isTrue);
      expect(over('NETWORK', 'Network down'), isFalse);
      expect(over('ERR_HTTP_500', 'Internal server error'), isFalse);
      expect(over('X', 'The request was cancelled'), isFalse);
    });

    // Round 3 review: an accept after the same user answered on another
    // device (during the permission prompt, say) fails as "already
    // started"; master_app's VoipCallHandler matches that text. It, and
    // the server's other ERR_CALL_* codes, used to show "Something went
    // wrong".
    test('isCallAlreadyOver: a call already answered, bounced busy, or any '
        'of the server\'s ERR_CALL_* codes for a call no longer ringing', () {
      bool over(String code, String message) =>
          isCallAlreadyOver(CometChatException(code, message, message));
      expect(over('ERR_BAD_REQUEST', 'The call is already started'), isTrue);
      expect(over('X', 'Call already accepted'), isTrue);
      expect(over('X', 'The call is ongoing'), isTrue);
      expect(over('X', 'The call is busy'), isTrue);
      for (final String code in <String>[
        'ERR_CALL_ENDED',
        'ERR_CALL_CANCELLED',
        'ERR_CALL_REJECTED',
        'ERR_CALL_BUSY',
        'ERR_CALL_UNANSWERED',
        'ERR_CALL_ACCEPTED',
        'ERR_CALL_ONGOING',
      ]) {
        expect(over(code, ''), isTrue, reason: code);
      }
      expect(over('ERR_CALL_NOT_FOUND', 'Not found'), isFalse);
      expect(over('X', 'The callback started'), isFalse);
    });

    test('isCallAlreadyOver reads the message and the details alike', () {
      // CometChatException(code, details, message).
      expect(
        isCallAlreadyOver(
          CometChatException('X', '', 'The call is already started'),
        ),
        isTrue,
        reason: 'the message alone',
      );
      expect(
        isCallAlreadyOver(CometChatException('X', 'The call is ended', null)),
        isTrue,
        reason: 'the details alone',
      );
    });
  });

  testWidgets('any other accept failure still shows "Something went wrong" '
      'without an onError', (WidgetTester tester) async {
    dataSource.acceptError = const CallOperationsException(
      message: 'Network down',
      code: 'NETWORK',
    );
    await ring(tester);

    await tapAccept(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('a decline failing because the call was already over shows no '
      '"Something went wrong" either', (WidgetTester tester) async {
    dataSource.rejectError = const CallOperationsException(
      message: 'The call with sessionid session_1 is ended.',
      code: 'ERR_CALL_TERMINATED',
    );
    await ring(tester);

    await tester.tap(find.text('Decline'));
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.byType(CometChatIncomingCall), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(events.ordered, <String>['rejected:session_1']);
  });
}
