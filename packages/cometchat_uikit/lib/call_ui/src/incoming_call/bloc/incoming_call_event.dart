import 'package:equatable/equatable.dart';

import 'incoming_call_state.dart';

/// Base class for all incoming call events
/// Uses Equatable for proper event comparison in BLoC
abstract class IncomingCallEvent extends Equatable {
  const IncomingCallEvent();

  @override
  List<Object?> get props => [];
}

/// Accept the incoming call: asks for the microphone (and, for a video call,
/// the camera), then accepts it and shows the call screen.
///
/// The first tap wins: ignored once the call has been accepted, declined or
/// given up (and while either is on its way), and after a refused permission
/// declined it. After a failed accept it can be tried again.
class AcceptCall extends IncomingCallEvent {
  const AcceptCall();
}

/// Decline the incoming call (`rejected`) and dismiss its banner.
///
/// The first tap wins: ignored once the call has been accepted, declined or
/// given up (and while either is on its way).
class RejectCall extends IncomingCallEvent {
  const RejectCall();
}

/// The call stopped ringing on this device without being answered or
/// declined here: the caller cancelled it or gave up, the same user answered
/// or declined it on another device, or it rang for 60 seconds with nobody
/// acting on it. Its banner is dismissed and the ringtone stops; nothing is
/// sent to the server. The state becomes [IncomingCallStatus.cancelled].
class CallCancelled extends IncomingCallEvent {
  const CallCancelled();
}
