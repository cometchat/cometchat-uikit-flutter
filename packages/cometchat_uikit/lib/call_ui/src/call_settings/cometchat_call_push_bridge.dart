/// A call ringing through push (ringing v2), as the push ringer reports it
/// to the UI Kit through a [CometChatCallPushBridge].
class CometChatPushCall {
  /// Creates a [CometChatPushCall].
  const CometChatPushCall({
    required this.sessionId,
    required this.callType,
    this.receiverType = 'user',
    this.callerUid,
    this.callerName,
    this.callerAvatarUrl,
  });

  /// The call's session.
  final String sessionId;

  /// `audio` or `video`.
  final String callType;

  /// `user` for a 1-on-1 call, `group` for a group call.
  final String receiverType;

  /// The caller's UID, when the push carried it.
  final String? callerUid;

  /// The caller's name, when the push carried it.
  final String? callerName;

  /// The caller's avatar, when the push carried it.
  final String? callerAvatarUrl;

  /// Whether this is a video call.
  bool get isVideo => callType == 'video';

  @override
  String toString() => 'CometChatPushCall($sessionId, $callType)';
}

/// A call that stopped ringing without being answered on this device, or an
/// answered call ended from the system's call UI (iOS CallKit).
class CometChatPushCallEnded {
  /// Creates a [CometChatPushCallEnded].
  const CometChatPushCallEnded({required this.call, required this.reason});

  /// The call.
  final CometChatPushCall call;

  /// Why it ended, as the push ringer names it: for `cometchat_voip`,
  /// `declined`, `cancelled`, `timedOut`, `answeredElsewhere`, `remoteEnded`,
  /// `failed` or `filtered`.
  final String reason;

  @override
  String toString() => 'CometChatPushCallEnded(${call.sessionId}, $reason)';
}

/// How the UI Kit answers, declines and follows calls that ring through push
/// (ringing v2), without depending on a push package itself.
///
/// The push ringer (`cometchat_voip`) rings incoming calls on its own ring
/// screen (Android) or CallKit (iOS), in every app state. The app implements
/// this bridge over it and sets it on `UIKitSettingsBuilder.callPushBridge`.
/// The UI Kit then:
///
/// * joins every call answered on the ring screen ([answered]) on its own
///   call screen, as it does for a call answered from its own UI. The app
///   does not join calls itself. The UI Kit listens from the moment call
///   handling starts, so the answer that launched the app reaches it too
///   (the push ringer holds it for its first listener);
/// * closes what it shows for a call that stopped ringing or was ended from
///   CallKit ([ended]);
/// * answers through [answer] (`CometChatUIKitCalls.acceptCall`, the
///   deprecated incoming call screen's Accept);
/// * stops the ring of a call it declines or answers busy itself
///   ([dismissRinging]), having told CometChat the status;
/// * on iOS, reports the calls it places, joins and ends to CallKit
///   ([reportOutgoingCall], [reportCallConnected], [reportCallEnded]).
///
/// Extend it rather than implement it: members added later come with a
/// default, so an app's bridge keeps compiling. With `cometchat_voip`:
///
/// ```dart
/// class VoipBridge extends CometChatCallPushBridge {
///   CometChatPushCall _call(CometChatVoipCall c) => CometChatPushCall(
///     sessionId: c.sessionId,
///     callType: c.callType,
///     receiverType: c.receiverType,
///     callerUid: c.callerUid,
///     callerName: c.callerName,
///     callerAvatarUrl: c.callerAvatarUrl,
///   );
///
///   @override
///   Stream<CometChatPushCall> get answered =>
///       CometChatVoip.onCallAnswered.map(_call);
///
///   @override
///   Stream<CometChatPushCallEnded> get ended =>
///       CometChatVoip.onCallEnded.map(
///         (e) => CometChatPushCallEnded(
///           call: _call(e.call),
///           reason: e.reason.wireName,
///         ),
///       );
///
///   @override
///   Future<void> answer(String sessionId) => CometChatVoip.answer(sessionId);
///
///   @override
///   Future<void> decline(String sessionId) =>
///       CometChatVoip.decline(sessionId);
///
///   @override
///   Future<void> dismissRinging(String sessionId, {required bool answered}) =>
///       CometChatVoip.dismissRinging(sessionId, answered: answered);
///
///   @override
///   Future<void> reportOutgoingCall({
///     required String sessionId,
///     required String calleeName,
///     bool hasVideo = false,
///   }) => CometChatVoip.reportOutgoingCall(
///     sessionId: sessionId,
///     calleeName: calleeName,
///     hasVideo: hasVideo,
///   );
///
///   @override
///   Future<void> reportCallConnected(String sessionId) =>
///       CometChatVoip.reportCallConnected(sessionId);
///
///   @override
///   Future<void> reportCallEnded(String sessionId) =>
///       CometChatVoip.reportCallEnded(sessionId);
/// }
/// ```
///
/// Not used on web, where calls ring through the chat SDK as before.
abstract class CometChatCallPushBridge {
  /// Creates a bridge.
  const CometChatCallPushBridge();

  /// Calls answered on this device: on the ring screen, from CallKit, or
  /// through [answer]. The UI Kit joins each on its call screen.
  Stream<CometChatPushCall> get answered;

  /// Calls that stopped ringing without being answered here, and answered
  /// calls ended from CallKit (iOS).
  Stream<CometChatPushCallEnded> get ended;

  /// Answers the ringing call [sessionId] as the ring screen's Answer does:
  /// CometChat hears it was answered, and [answered] follows.
  Future<void> answer(String sessionId);

  /// Declines the ringing call [sessionId] as the ring screen's Decline
  /// does.
  Future<void> decline(String sessionId);

  /// Stops ringing [sessionId], which the UI Kit has answered or declined
  /// and reported to CometChat itself. Sends nothing to CometChat. With
  /// [answered], the session prepared while it rang is kept for the join.
  Future<void> dismissRinging(String sessionId, {required bool answered});

  /// Reports a call this device placed to the system's call UI (iOS
  /// CallKit). Does nothing by default.
  Future<void> reportOutgoingCall({
    required String sessionId,
    required String calleeName,
    bool hasVideo = false,
  }) async {}

  /// Reports that the session [sessionId] is joined (iOS CallKit starts its
  /// timer). Does nothing by default.
  Future<void> reportCallConnected(String sessionId) async {}

  /// Reports that the call [sessionId] is over, when this device ended it
  /// (iOS: ends the CallKit call). Does nothing by default.
  Future<void> reportCallEnded(String sessionId) async {}
}
