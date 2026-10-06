/// Regression test: a call accepted from the native call UI must not then be
/// rejected as busy.
///
/// Accepting from CallKit (iOS) or the call notification (Android) opens the
/// call screen directly through master_app — `CallScreenOverlay.show` — and
/// never sets `CallEventService.activeCall`. When the SDK then delivers
/// `onIncomingCallReceived` for that same call (as the app comes to the
/// foreground), the busy check saw a call screen up and, because its duplicate
/// check only looked at `activeCall`, rejected the call the user had just
/// accepted. The user accepted and never got into the call.
///
/// The call screen is stood in for by the bookkeeping CallScreenOverlay.show
/// records for it: showing it for real needs a navigator, and since round 1b
/// a show() without one keeps nothing.
///
///   flutter test test/call_ui/busy_same_call_test.dart
library;

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDataSource extends Fake implements CallOperationsDataSource {
  final List<(String, String)> rejects = [];

  @override
  Future<void> waitForCallsSdk() async {}

  @override
  Future<Call> rejectCall(String sessionId, String status) async {
    rejects.add((sessionId, status));
    return _call(sessionId);
  }
}

Call _call(String sessionId) => Call(
  id: 1,
  sessionId: sessionId,
  callStatus: 'initiated',
  callInitiator: User(uid: 'peer', name: 'Peer'),
  receiverUid: 'me',
  type: 'audio',
  receiverType: 'user',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDataSource dataSource;
  final service = CallEventService.instance;

  setUpAll(() {
    // What master_app's native-accept path does: open the call screen for the
    // accepted session without touching activeCall. What CallScreenOverlay
    // records for that screen is set directly.
    ActiveCallTracker.callScreenSessionId = 'accepted';
    ActiveCallTracker.callScreenWorkFlow = CallWorkFlow.defaultCalling;
  });

  tearDownAll(() {
    ActiveCallTracker.callScreenSessionId = null;
    ActiveCallTracker.callScreenWorkFlow = null;
  });

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = _FakeDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    service.activeCall = null;
    ActiveCallTracker.busyRejectDelay = Duration.zero;
  });

  tearDown(() async {
    service.activeCall = null;
    ActiveCallTracker.busyRejectDelay = const Duration(seconds: 2);
    await CallOperationsServiceLocator.instance.reset();
  });

  test('the call already on screen is never answered with busy', () async {
    expect(ActiveCallTracker.callScreenSessionId, 'accepted');
    expect(service.activeCall, isNull, reason: 'native accept sets no record');

    service.onIncomingCallReceived(_call('accepted'));
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(
      dataSource.rejects,
      isEmpty,
      reason:
          'this is the call the user just accepted — rejecting it as busy '
          'ends it before they ever get in',
    );
  });

  test('a genuinely different call is still answered with busy', () async {
    service.onIncomingCallReceived(_call('another'));
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(dataSource.rejects, [('another', 'busy')]);
  });
}
