/// The caller's side of an accept (round 2 review): what happens between
/// the callee answering and the call screen coming up.
///
/// Every test mounts the real CometChatOutgoingCall as a route and runs on
/// the test's fake clock.
///
///   flutter test test/call_ui/outgoing_call/outgoing_call_accept_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/cometchat_outgoing_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

/// The bloc behind the outgoing call screen on show.
OutgoingCallBloc _screenBloc() => CometChatCallEvents.callEventsListener.values
    .whereType<OutgoingCallBloc>()
    .single;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;
  late List<Exception> errors;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    errors = <Exception>[];
  });

  tearDown(() async {
    SoundChannelSpy.remove();
    removeCallJoinDefaults();
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveOutgoingValue(false);
    CallEventService.instance.activeCall = null;
    CallScreenOverlay.dismiss();
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// Mounts the app with the real outgoing call screen on top, ringing, and
  /// a Calls SDK that joins at once.
  Future<void> ring(WidgetTester tester) async {
    await installCallJoinDefaults();
    await mountCallNavigator(tester);
    CallEventService.instance.activeCall = buildCall();
    unawaited(
      CallNavigationContext.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => CometChatOutgoingCall(
            call: buildCall(),
            user: User(uid: 'peer', name: 'Peer'),
            onError: errors.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CometChatOutgoingCall), findsOneWidget);
  }

  testWidgets('a permission request that throws at the accept closes the '
      'screen, frees the device and reaches onError with its code', (
    WidgetTester tester,
  ) async {
    await ring(tester);
    PermissionChannelStub.requestError = PlatformException(
      code: 'PermissionHandler.PermissionManager',
      message: 'A request for permissions is already running.',
    );

    _screenBloc().onOutgoingCallAccepted(buildCall());
    await tester.pumpAndSettle();

    expect(find.byType(CometChatOutgoingCall), findsNothing);
    expect(CallScreenOverlay.isShowing, isFalse);
    expect(CallEventService.instance.activeCall, isNull);
    final CometChatException error = errors.single as CometChatException;
    expect(error.code, 'PermissionHandler.PermissionManager');
    expect(error.message, 'A request for permissions is already running.');
    // As a refusal: nothing goes to the server.
    expect(dataSource.calls, isEmpty);
  });

  testWidgets('the same accept twice asks for permissions once and opens '
      'one call screen', (WidgetTester tester) async {
    await ring(tester);
    final Completer<void> prompt = Completer<void>();
    PermissionChannelStub.gate = prompt;

    _screenBloc().onOutgoingCallAccepted(buildCall());
    await tester.pump();
    final int asked = PermissionChannelStub.requested.length;
    expect(asked, greaterThan(0));
    _screenBloc().onOutgoingCallAccepted(buildCall());
    await tester.pump();
    expect(PermissionChannelStub.requested, hasLength(asked));

    prompt.complete();
    await tester.pumpAndSettle();
    expect(CallScreenOverlay.isShowing, isTrue);
    expect(dataSource.startSessionCount, 1);
    expect(errors, isEmpty);
  });
  testWidgets('a decline echo while the accept\'s prompt is up changes '
      'nothing: the call has moved on', (WidgetTester tester) async {
    await ring(tester);
    final Completer<void> prompt = Completer<void>();
    PermissionChannelStub.gate = prompt;

    _screenBloc().onOutgoingCallAccepted(buildCall());
    await tester.pump();
    _screenBloc().onIncomingCallCancelled(
      buildCall()..callStatus = CallStatusConstants.rejected,
    );
    await tester.pump();

    prompt.complete();
    await tester.pumpAndSettle();
    expect(CallScreenOverlay.isShowing, isTrue);
    expect(errors, isEmpty);
  });
}
