/// The ringing v2 call engine (phase 2, as Android has it): the UI Kit keeps
/// its `Call`-based calling API, and runs it on the Calls SDK.
///
/// * `CometChatUIKitCalls.initiateCall(Call)` places the call with
///   `CometChatCalls.initiateCall` (with the settings the session is
///   prepared with) and gives back a chat `Call`, built from the
///   `InitiatedCall`, with the ID of its call message.
/// * `CometChatUIKitCalls.rejectCall(sessionId, status)` ends it before the
///   join with `CometChatCalls.endCall`, and gives back the call message of
///   that status: the call as this device knows it (the Calls SDK's
///   `endCall` reports no data since 5.1.0-team).
/// * The data sources (call operations, call logs) go through them, with
///   the settings the call components put on the call.
///
/// The Calls SDK is replaced through the `CallsRinging` seam. The web
/// fallback to the chat SDK runs only on web (`kIsWeb`), not under test.
///
///   flutter test test/call_ui/call_operations/ringing_v2_engine_test.dart
library;

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show
        CallType,
        CometChatCallsException,
        InitiateCallOptions,
        InitiatedCall,
        ReceiverType,
        SessionSettings,
        SessionSettingsBuilder,
        SessionType;
import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/data/datasources/call_logs_remote_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource_impl.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/cometchat_uikit_calls.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatUIKit;
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/call_prepare_settings.dart';
import 'package:cometchat_chat_uikit/src/calls_ringing.dart';
import 'package:cometchat_chat_uikit/src/ringing_call_mapping.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart'
    show Call, CometChatException, User;
import 'package:flutter_test/flutter_test.dart';

/// One `CometChatCalls.initiateCall` the seam caught.
typedef _Initiate = ({
  String receiver,
  InitiateCallOptions? options,
  void Function(InitiatedCall) onSuccess,
  void Function(CometChatCallsException) onError,
});

/// One `CometChatCalls.endCall` the seam caught.
typedef _End = ({
  String sessionId,
  String? status,
  void Function() onSuccess,
  void Function(CometChatCallsException) onError,
});

final _me = User(uid: 'me', name: 'Me');
final _peer = User(uid: 'peer', name: 'Peer');

InitiatedCall _initiated({String sessionId = 's1', String type = 'audio'}) =>
    InitiatedCall(
      sessionId: sessionId,
      messageId: '501',
      conversationId: 'me_user_peer',
      sender: 'me',
      receiver: 'peer',
      receiverType: ReceiverType.user,
      type: type,
      initiatedAt: 1700000000000,
    );

Call _ringing(String sessionId) => Call(
  id: 1,
  sessionId: sessionId,
  callStatus: 'initiated',
  callInitiator: _peer,
  receiverUid: 'me',
  type: 'audio',
  receiverType: 'user',
);

final _refused = CometChatCallsException('ERR_X', 'refused', 'details');

SessionSettings _audioSettings() =>
    (SessionSettingsBuilder()..setType(SessionType.audio)).build();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<_Initiate> initiates;
  late List<_End> ends;

  setUp(() {
    initiates = <_Initiate>[];
    ends = <_End>[];
    CallsRinging.initiateCall =
        ({
          required String receiver,
          InitiateCallOptions? options,
          required void Function(InitiatedCall) onSuccess,
          required void Function(CometChatCallsException) onError,
        }) async {
          initiates.add((
            receiver: receiver,
            options: options,
            onSuccess: onSuccess,
            onError: onError,
          ));
        };
    CallsRinging.endCall =
        ({
          required String sessionId,
          String? status,
          required void Function() onSuccess,
          required void Function(CometChatCallsException) onError,
        }) async {
          ends.add((
            sessionId: sessionId,
            status: status,
            onSuccess: onSuccess,
            onError: onError,
          ));
        };
    CometChatUIKit.loggedInUser = _me;
    ActiveCallTracker.mayHaveMediaSession = false;
    ActiveCallTracker.ringingCall = null;
    CallEventService.instance.activeCall = null;
    ActiveCallTracker.forgetFinishedCalls();
  });

  tearDown(() {
    CallsRinging.debugReset();
    CometChatUIKit.loggedInUser = null;
    ActiveCallTracker.mayHaveMediaSession = false;
    ActiveCallTracker.ringingCall = null;
    CallEventService.instance.activeCall = null;
    ActiveCallTracker.forgetFinishedCalls();
  });

  group('CometChatUIKitCalls.initiateCall', () {
    test('places the call to its receiver, as its type, with the settings '
        'the session is prepared with', () {
      final settings = _audioSettings();
      CometChatUIKitCalls.initiateCall(
        Call(receiverUid: 'peer', receiverType: 'user', type: 'audio'),
        sessionSettings: settings,
      );

      expect(initiates.single.receiver, 'peer');
      final options = initiates.single.options!;
      expect(options.type, CallType.audio);
      expect(options.receiverType, ReceiverType.user);
      expect(options.sessionSettings, same(settings));
    });

    test('a group call goes to the group; a call with no type is a video '
        'call', () {
      CometChatUIKitCalls.initiateCall(
        Call(receiverUid: 'g1', receiverType: 'group', type: ''),
      );

      expect(initiates.single.receiver, 'g1');
      expect(initiates.single.options!.receiverType, ReceiverType.group);
      expect(initiates.single.options!.type, CallType.video);
      expect(initiates.single.options!.sessionSettings, isNull);
    });

    test('gives back the call as a chat Call, with its call message, the '
        'caller and the receiver, and marks the prepared session', () {
      Call? got;
      final call = Call(
        receiverUid: 'peer',
        receiverType: 'user',
        type: 'audio',
      )..receiver = _peer;
      CometChatUIKitCalls.initiateCall(call, onSuccess: (c) => got = c);

      initiates.single.onSuccess(_initiated());

      expect(got!.id, 501);
      expect(got!.sessionId, 's1');
      expect(got!.callStatus, 'initiated');
      expect(got!.type, 'audio');
      expect(got!.receiverUid, 'peer');
      expect(got!.category, 'call');
      expect(got!.conversationId, 'me_user_peer');
      expect(got!.callInitiator, same(_me));
      expect(got!.callReceiver, same(_peer));
      expect(ActiveCallTracker.mayHaveMediaSession, isTrue);
    });

    test('a refusal reaches onError as the chat SDK exception, its code, '
        'message and details kept, and marks nothing', () {
      CometChatException? got;
      CometChatUIKitCalls.initiateCall(
        Call(receiverUid: 'peer', receiverType: 'user', type: 'audio'),
        onError: (e) => got = e,
      );

      initiates.single.onError(_refused);

      expect(got!.code, 'ERR_X');
      expect(got!.message, 'refused');
      expect(got!.details, 'details');
      expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
    });

    test('a host callback that throws does not escape', () {
      CometChatUIKitCalls.initiateCall(
        Call(receiverUid: 'peer', receiverType: 'user', type: 'audio'),
        onSuccess: (_) => throw StateError('host bug'),
        onError: (_) => throw StateError('host bug'),
      );

      expect(() => initiates.single.onSuccess(_initiated()), returnsNormally);
      expect(() => initiates.single.onError(_refused), returnsNormally);
    });
  });

  group('CometChatUIKitCalls.rejectCall', () {
    test('ends the session with the status, and gives back the call as this '
        'device knows it, in that status, with no call message', () {
      ActiveCallTracker.ringingCall = _ringing('s1');
      Call? got;
      CometChatUIKitCalls.rejectCall('s1', 'busy', onSuccess: (c) => got = c);

      expect(ends.single.sessionId, 's1');
      expect(ends.single.status, 'busy');

      ends.single.onSuccess();

      expect(got!.id, 0);
      expect(got!.sessionId, 's1');
      expect(got!.callStatus, 'busy');
      expect(got!.receiverUid, 'me');
      expect(got!.callInitiator, same(_peer));
      expect(got!.category, 'call');
    });

    test(
      'a call this device does not know comes back as its session alone',
      () {
        Call? got;
        CometChatUIKitCalls.rejectCall(
          's9',
          'cancelled',
          onSuccess: (c) => got = c,
        );

        ends.single.onSuccess();

        expect(got!.sessionId, 's9');
        expect(got!.callStatus, 'cancelled');
        expect(got!.id, 0);
      },
    );

    test('a failed end drops the record of the call and reaches onError as '
        'the chat SDK exception', () {
      ActiveCallTracker.ringingCall = _ringing('s1');
      CometChatException? got;
      CometChatUIKitCalls.rejectCall('s1', 'rejected', onError: (e) => got = e);

      ends.single.onError(_refused);

      expect(got!.code, 'ERR_X');
      expect(ActiveCallTracker.ringingCall, isNull);
    });

    test('a decline that lands leaves the record to the events that follow '
        'it, as before', () {
      final ringing = _ringing('s1');
      ActiveCallTracker.ringingCall = ringing;
      CometChatUIKitCalls.rejectCall('s1', 'rejected');

      ends.single.onSuccess();

      expect(ActiveCallTracker.ringingCall, same(ringing));
    });

    for (final status in ['cancelled', 'unanswered']) {
      test('the caller\'s $status clears the prepared-session mark, landed '
          'or not', () {
        ActiveCallTracker.mayHaveMediaSession = true;
        CometChatUIKitCalls.rejectCall('s1', status);
        ends.single.onSuccess();
        expect(ActiveCallTracker.mayHaveMediaSession, isFalse);

        ActiveCallTracker.mayHaveMediaSession = true;
        CometChatUIKitCalls.rejectCall('s2', status);
        ends.last.onError(_refused);
        expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
      });
    }

    test('a decline keeps the mark of a session this device is in', () {
      ActiveCallTracker.mayHaveMediaSession = true;
      CometChatUIKitCalls.rejectCall('s2', 'busy');

      ends.single.onSuccess();

      expect(ActiveCallTracker.mayHaveMediaSession, isTrue);
    });
  });

  group('CallOperationsDataSourceImpl', () {
    final dataSource = CallOperationsDataSourceImpl();

    test('initiateCall places the call with the settings put on it', () async {
      final settings = _audioSettings();
      final call = Call(
        receiverUid: 'peer',
        receiverType: 'user',
        type: 'audio',
      );
      CallPrepareSettings.attach(call, settings);

      final future = dataSource.initiateCall(call);
      expect(initiates.single.options!.sessionSettings, same(settings));
      initiates.single.onSuccess(_initiated());

      expect((await future).sessionId, 's1');
    });

    test('initiateCall with no settings put on the call leaves them to the '
        'Calls SDK', () {
      dataSource.initiateCall(
        Call(receiverUid: 'peer', receiverType: 'user', type: 'audio'),
      );

      expect(initiates.single.options!.sessionSettings, isNull);
    });

    test('initiateCall fails with a CallOperationsException carrying the '
        'Calls SDK code', () async {
      final future = dataSource.initiateCall(
        Call(receiverUid: 'peer', receiverType: 'user', type: 'audio'),
      );
      initiates.single.onError(_refused);

      await expectLater(
        future,
        throwsA(
          isA<CallOperationsException>().having((e) => e.code, 'code', 'ERR_X'),
        ),
      );
    });

    test('rejectCall ends the call and returns its message', () async {
      final future = dataSource.rejectCall('s1', 'cancelled');
      ends.single.onSuccess();

      final call = await future;
      expect(call.callStatus, 'cancelled');
      expect(ends.single.status, 'cancelled');
    });
  });

  group('CallLogsRemoteDataSourceImpl', () {
    test('a call-back is placed with the Calls SDK, with the settings put on '
        'it', () async {
      final settings = _audioSettings();
      final call = Call(
        receiverUid: 'peer',
        receiverType: 'user',
        type: 'audio',
      );
      CallPrepareSettings.attach(call, settings);

      final future = CallLogsRemoteDataSourceImpl().initiateCall(call);
      expect(initiates.single.receiver, 'peer');
      expect(initiates.single.options!.sessionSettings, same(settings));
      initiates.single.onSuccess(_initiated());

      expect((await future).id, 501);
    });

    test('a refusal fails with its code', () async {
      final future = CallLogsRemoteDataSourceImpl().initiateCall(
        Call(receiverUid: 'peer', receiverType: 'user', type: 'audio'),
      );
      initiates.single.onError(_refused);

      await expectLater(
        future,
        throwsA(
          isA<CallLogsRemoteDataSourceException>().having(
            (e) => e.code,
            'code',
            'ERR_X',
          ),
        ),
      );
    });
  });

  group('RingingCallMapping.ended', () {
    test('the known call in the new status, claiming no call message', () {
      final known = _ringing('s1');
      final call = RingingCallMapping.ended('s1', 'rejected', known: known);

      expect(call.id, 0);
      expect(call.sessionId, 's1');
      expect(call.callStatus, 'rejected');
      expect(call.type, 'audio');
      expect(call.callInitiator, same(_peer));
      expect(call.category, 'call');
    });

    test('without a known call: the session alone', () {
      final call = RingingCallMapping.ended('s1', 'cancelled');

      expect(call.id, 0);
      expect(call.sessionId, 's1');
      expect(call.callStatus, 'cancelled');
      expect(call.callInitiator, isNull);
    });
  });
}
