/// Golden pins for [CometChatCallLogs]: the call-log row in each direction and
/// media type, and the screen's state views.
///
/// The real screen is rendered, held in a fixed state through its
/// `callLogsBloc` seam, so neither the Calls SDK nor the network is involved.
///
///   flutter test test/call_ui/call_logs/goldens/                  # verify
///   flutter test test/call_ui/call_logs/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

class _MockCallLogsBloc extends MockBloc<CallLogsEvent, CallLogsState>
    implements CallLogsBloc {}

final _me = User(uid: 'u-me', name: 'Sam Carter');

CallUser _meInCall() => CallUser(uid: 'u-me', name: 'Sam Carter');

/// The row prints the time in the device's zone. Building the stamp from a
/// local DateTime keeps the printed string, and so its width, the same in
/// every zone.
final int _initiatedAt =
    DateTime(2025, 5, 15, 10, 30).millisecondsSinceEpoch ~/ 1000;

CallLog _log({
  required String session,
  required String peer,
  required String type,
  required String status,
  required bool byMe,
}) {
  final other = CallUser(uid: 'u-$session', name: peer);
  return CallLog(
    sessionId: session,
    receiverType: ReceiverTypeConstants.user,
    type: type,
    status: status,
    initiatedAt: _initiatedAt,
    totalDurationInMinutes: 3.5,
    initiator: byMe ? _meInCall() : other,
    receiver: byMe ? other : _meInCall(),
  );
}

/// Direction comes from who initiated the call, missed from an unanswered
/// or cancelled call somebody else placed (a rejected or busy one is not
/// missed, round 5).
List<CallLog> _logs() => [
  _log(
    session: 's1',
    peer: 'Priya Raman',
    type: CallTypeConstants.audioCall,
    status: CallStatusConstants.ended,
    byMe: true,
  ),
  _log(
    session: 's2',
    peer: 'Marcus Webb',
    type: CallTypeConstants.videoCall,
    status: CallStatusConstants.ended,
    byMe: true,
  ),
  _log(
    session: 's3',
    peer: 'Bianca Rossi',
    type: CallTypeConstants.audioCall,
    status: CallStatusConstants.ended,
    byMe: false,
  ),
  _log(
    session: 's4',
    peer: 'Chen Wei',
    type: CallTypeConstants.videoCall,
    status: CallStatusConstants.ended,
    byMe: false,
  ),
  _log(
    session: 's5',
    peer: 'Dmitri Volkov',
    type: CallTypeConstants.audioCall,
    status: CallStatusConstants.unanswered,
    byMe: false,
  ),
  _log(
    session: 's6',
    peer: 'Aisha Khan',
    type: CallTypeConstants.videoCall,
    status: CallStatusConstants.cancelled,
    byMe: false,
  ),
];

_MockCallLogsBloc _bloc(CallLogsState state) {
  final bloc = _MockCallLogsBloc();
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream<CallLogsState>.value(state), initialState: state);
  return bloc;
}

const _size = Size(375, 560);

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        'call log rows: outgoing, incoming and missed, audio and video',
        fileName: 'call_logs_list_loaded',
        size: _size,
        builder: () {
          final logs = _logs();
          return CometChatCallLogs(
            callLogsBloc: _bloc(
              CallLogsState(
                status: CallLogsStatus.loaded,
                callLogs: logs,
                loggedInUser: _me,
                groupedEntries: {'15 May 2025': logs},
              ),
            ),
          );
        },
      );

      lightDarkGolden(
        'call logs empty state',
        fileName: 'call_logs_state_empty',
        size: _size,
        builder: () => CometChatCallLogs(
          callLogsBloc: _bloc(
            const CallLogsState(status: CallLogsStatus.empty),
          ),
        ),
      );

      lightDarkGolden(
        'call logs error state',
        fileName: 'call_logs_state_error',
        size: _size,
        builder: () => CometChatCallLogs(
          callLogsBloc: _bloc(
            const CallLogsState(
              status: CallLogsStatus.error,
              errorMessage: 'Something went wrong',
            ),
          ),
        ),
      );

      // The loading (shimmer) state has no golden on purpose. The shimmer is an
      // animation, so the frame that gets rasterised depends on where its
      // controller happens to be: baked on macOS these passed locally and
      // failed on CI's Linux runner, in all five list components. A golden of
      // an animating gradient pins timing, not layout. The loading views keep
      // their widget-test coverage instead (ENG-38688).
    },
  );
}
