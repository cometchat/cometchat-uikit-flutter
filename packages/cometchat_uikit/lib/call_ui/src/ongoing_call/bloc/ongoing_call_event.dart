import 'package:equatable/equatable.dart';

import '../../../../cometchat_calls_uikit.dart';

/// Base class for all ongoing call events
/// Uses Equatable for proper event comparison in BLoC
abstract class OngoingCallEvent extends Equatable {
  const OngoingCallEvent();

  @override
  List<Object?> get props => [];
}

/// Load the calling screen: joins the session (the Calls SDK generates the
/// call token itself).
class LoadCallingScreen extends OngoingCallEvent {
  const LoadCallingScreen();
}

/// End call button was pressed (or back while the call still connects).
/// Behavior depends on callWorkFlow:
/// - directCalling (a meeting): leaves the session;
/// - defaultCalling (a 1-on-1 call): leaves the session, closes the screen
///   and ends the call on the server (`endCall`).
/// Once the call is on its way out, a second one is ignored.
class EndCallButtonPressed extends OngoingCallEvent {
  const EndCallButtonPressed();
}

/// Session timeout occurred
/// Ends the session
class SessionTimeout extends OngoingCallEvent {
  const SessionTimeout();
}

/// The session was left or its connection closed (from SDK callbacks).
/// A 1-on-1 call screen then closes without sending `endCall`; a meeting
/// ignores it. While this screen ends the call itself, it is that end's
/// echo and is ignored.
class OngoingCallEnded extends OngoingCallEvent {
  const OngoingCallEnded();
}

/// User list changed (from SDK callback)
/// Updates the participants list in state
class UserListChanged extends OngoingCallEvent {
  final List<RTCUser> users;

  const UserListChanged(this.users);

  @override
  List<Object?> get props => [users];
}

/// Participant list changed (from V5 SDK callback)
/// Updates the participants list in state
class ParticipantListChanged extends OngoingCallEvent {
  final List<Participant> participants;

  const ParticipantListChanged(this.participants);

  @override
  List<Object?> get props => [participants];
}

/// A participant left the session (from V5 SDK callback)
///
/// A peer that leaves was in the session, so it counts as seen: the 1-on-1
/// "peer left" rule, armed only once the peer has been seen, can then end
/// the call. It does not count as the native join.
class ParticipantLeft extends OngoingCallEvent {
  final Participant participant;

  const ParticipantLeft(this.participant);

  @override
  List<Object?> get props => [participant];
}

/// Calling widget received from SDK
class CallingWidgetReceived extends OngoingCallEvent {
  final dynamic widget;

  const CallingWidgetReceived(this.widget);

  @override
  List<Object?> get props => [widget];
}
