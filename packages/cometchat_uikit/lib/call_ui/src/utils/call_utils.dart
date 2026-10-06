import 'package:flutter/material.dart';

import '../../../cometchat_calls_uikit.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../src/missed_call_rule.dart';

/// [CallUtils] is a utility class that contains methods to perform call related operations.
///
/// A call is missed when it went unanswered or was cancelled, for the person
/// who did not start it. One rule drives the call bubbles' text, icon and
/// colour, [isMissedCall], the call logs and the Chats list: a rejected or
/// busy call is never missed and reads the same on both sides. (The chat SDK
/// gives realtime and history call messages the user who acted as
/// `callInitiator`, the callee who declined, say; only the statuses the
/// caller sends say reliably who started a call.)
class CallUtils {
  /// The uid of [call]'s initiator: null when it has none or it is a group.
  /// Read with a type check, where a hard cast threw for both.
  static String? _initiatorUid(Call call) {
    final initiator = call.callInitiator;
    return initiator is User ? initiator.uid : null;
  }

  /// Whether [loggedInUser] started [call], as its initiator says.
  static bool _startedBy(Call call, User? loggedInUser) {
    final uid = _initiatorUid(call);
    return uid != null && loggedInUser != null && uid == loggedInUser.uid;
  }

  /// The one missed rule, for a 1:1 call message.
  static bool _isMissedForMe(Call call, User? loggedInUser) =>
      call.receiverType == ReceiverTypeConstants.user &&
      MissedCallRule.isMissed(
        status: call.callStatus,
        startedByMe: _startedBy(call, loggedInUser),
      );

  /// Returns the call status message: the text of a call action bubble,
  /// after a leading space.
  ///
  /// Each status reads as its outcome. The direction only counts for the
  /// statuses the caller sends:
  ///
  /// | Status | Caller | Callee |
  /// | --- | --- | --- |
  /// | initiated | Outgoing Call | Incoming Call |
  /// | ongoing | Call accepted | Call accepted |
  /// | ended | Call ended | Call ended |
  /// | cancelled | Call cancelled | Missed voice call / Missed video call |
  /// | unanswered | Call unanswered | Missed voice call / Missed video call |
  /// | rejected | Call rejected | Call rejected |
  /// | busy | Call busy | Call busy |
  ///
  /// Any other status reads "Voice call" or "Video call". A message that is
  /// not a [Call] gives just the space.
  static String getCallStatus(
    BuildContext context,
    BaseMessage baseMessage,
    User? loggedInUser,
  ) {
    if (baseMessage is! Call) return " ";
    final call = baseMessage;
    final translations = Translations.of(context);
    final video = isVideoCall(call);
    if (_isMissedForMe(call, loggedInUser)) {
      return video
          ? " ${translations.missedVideoCall}"
          : " ${translations.missedVoiceCall}";
    }
    final String callMessageText;
    switch (call.callStatus) {
      case CallStatusConstants.initiated:
        callMessageText = _startedBy(call, loggedInUser)
            ? translations.outgoingCall
            : translations.incomingCall;
      case CallStatusConstants.ongoing:
        callMessageText = translations.callAccepted;
      case CallStatusConstants.ended:
        callMessageText = translations.callEnded;
      case CallStatusConstants.cancelled:
        callMessageText = translations.callCancelled;
      case CallStatusConstants.unanswered:
        callMessageText = translations.callUnanswered;
      case CallStatusConstants.rejected:
        callMessageText = translations.callRejected;
      case CallStatusConstants.busy:
        callMessageText = translations.callBusy;
      default:
        callMessageText = video
            ? translations.videoCall
            : translations.voiceCall;
    }
    return " $callMessageText";
  }

  /// Returns true if the call is a video call.
  static bool isVideoCall(Call call) {
    return call.type == CallTypeConstants.videoCall;
  }

  /// Returns true if the call is initiated by the logged in user.
  static bool isLoggedInUser(User? initiator, User? loggedInUser) {
    if (initiator == null || loggedInUser == null) {
      return false;
    } else {
      return initiator.uid == loggedInUser.uid;
    }
  }

  static String getLastMessageForGroupCall(
    BaseMessage lastMessage,
    BuildContext context,
    User? loggedInUser,
  ) {
    String message = "";
    if (lastMessage.receiverType == ReceiverTypeConstants.group) {
      if (!isLoggedInUser(lastMessage.sender, loggedInUser)) {
        message =
            "${lastMessage.sender?.name} ${Translations.of(context).initiatedGroupCall}";
      } else {
        message = Translations.of(context).youInitiatedGroupCall;
      }
    }
    return message;
  }

  ///[isMissedCall] returns true if [call] is a missed call for
  ///[loggedInUser]: a 1:1 call that went unanswered or was cancelled, which
  ///[loggedInUser] did not start. A rejected or busy call is never missed.
  static bool isMissedCall(Call call, User? loggedInUser) =>
      _isMissedForMe(call, loggedInUser);

  /// Returns true if the call is initiated by the logged in user.
  static bool callLogLoggedInUser(CallLog? callLog, User? loggedInUser) {
    if (callLog == null || loggedInUser == null) {
      return false;
    } else if (callLog.initiator is CallEntity ||
        (callLog.receiver is CallEntity)) {
      if (callLog.initiator is CallUser) {
        CallUser initiatorUser = callLog.initiator as CallUser;
        return initiatorUser.uid == loggedInUser.uid;
      } else if (callLog.receiver is CallUser) {
        CallUser receiverUser = callLog.receiver as CallUser;
        return receiverUser.uid == loggedInUser.uid;
      } else if (callLog.initiator is CallGroup) {
        CallUser receiverUser = callLog.receiver as CallUser;
        return receiverUser.uid == loggedInUser.uid;
      } else if (callLog.receiver is CallGroup) {
        CallUser initiatorUser = callLog.initiator as CallUser;
        return initiatorUser.uid == loggedInUser.uid;
      }
    }
    return false;
  }

  /// [isMissedCallLog] returns true if [callLog] is a missed call for
  /// [loggedInUser]: one that went unanswered or was cancelled, which
  /// [loggedInUser] did not start (as [callLogLoggedInUser] reads it). A
  /// rejected or busy call is never missed. The call logs' icon
  /// ([getCallIcon]), title colour ([getCallStatusColor]) and label
  /// ([getStatus]) all follow it, as the call bubbles follow [isMissedCall].
  static bool isMissedCallLog(CallLog? callLog, User? loggedInUser) =>
      callLog != null &&
      MissedCallRule.isMissed(
        status: callLog.status,
        startedByMe: callLogLoggedInUser(callLog, loggedInUser),
      );

  /// [getStatus] return call status: the label of a call-log row, after a
  /// leading space. A missed call ([isMissedCallLog]) reads "Missed Call";
  /// otherwise an initiated or ended call reads by direction, an ongoing one
  /// "Ongoing call", an unanswered or cancelled one (yours) "Unanswered Call"
  /// or "Cancelled Call", and a rejected or busy one "Call rejected" or
  /// "Call busy" on both sides. A missing log, user or context gives the
  /// empty string.
  static String getStatus(
    BuildContext? context,
    CallLog? callLog,
    User? loggedInUser,
  ) {
    if (callLog == null || loggedInUser == null) {
      return "";
    }

    if (context == null) {
      return "";
    }

    final translations = Translations.of(context);
    if (isMissedCallLog(callLog, loggedInUser)) {
      return " ${translations.missedCall}";
    }
    final mine = callLogLoggedInUser(callLog, loggedInUser);
    final String callMessageText;
    switch (callLog.status) {
      case CallStatusConstants.initiated:
      case CallStatusConstants.ended:
        callMessageText = mine
            ? translations.outgoingCall
            : translations.incomingCall;
      case CallStatusConstants.ongoing:
        callMessageText = translations.ongoingCall;
      case CallStatusConstants.unanswered:
        callMessageText = translations.unansweredCall;
      case CallStatusConstants.cancelled:
        callMessageText = translations.cancelledCall;
      case CallStatusConstants.rejected:
        callMessageText = translations.callRejected;
      case CallStatusConstants.busy:
        callMessageText = translations.callBusy;
      default:
        callMessageText = "";
    }
    return " $callMessageText";
  }

  /// [getCallIcon] Return call status icon: the missed icon for a missed call
  /// ([isMissedCallLog]), otherwise outgoing or incoming by direction,
  /// whatever the status.
  static Widget getCallIcon(
    BuildContext context,
    CallLog callLog,
    User? loggedInUser,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
    CometChatCallLogsStyle style, {
    Widget? incomingCallIcon,
    Widget? outgoingCallIcon,
    Widget? missedCallIcon,
  }) {
    if (isMissedCallLog(callLog, loggedInUser)) {
      return missedCallIcon ??
          Icon(
            Icons.call_missed_outgoing_rounded,
            color: style.missedCallIconColor ?? colorPalette.error,
            size: 16,
          );
    }
    if (callLogLoggedInUser(callLog, loggedInUser)) {
      return outgoingCallIcon ??
          Icon(
            Icons.call_made_outlined,
            color: style.outgoingCallIconColor ?? colorPalette.success,
            size: 16,
          );
    }
    return incomingCallIcon ??
        Icon(
          Icons.call_received_outlined,
          color: style.incomingCallIconColor ?? colorPalette.success,
          size: 16,
        );
  }

  /// [getCallStatusColor] returns call status color: the error colour for a
  /// missed call ([isMissedCallLog]), textPrimary for every other one.
  static Color getCallStatusColor(
    CallLog callLog,
    User? loggedInUser,
    CometChatColorPalette colorPalette,
  ) {
    if (isMissedCallLog(callLog, loggedInUser)) {
      return colorPalette.error ?? Colors.transparent;
    }
    return colorPalette.textPrimary ?? Colors.transparent;
  }

  static bool isAudioCall(CallLog callLog) {
    return callLog.type == CallTypeConstants.audioCall;
  }

  static bool isCallInitiatedByMe(Call call) {
    if (call.callInitiator is User) {
      User initiator = call.callInitiator as User;
      return initiator.uid == CometChatUIKit.loggedInUser?.uid;
    }
    return false;
  }

  /// The icon asset of a call action bubble: the missed glyph for a missed
  /// call (see [isMissedCall]), a direction glyph while a call is initiated,
  /// and the plain call glyph for every other status.
  static String getCallIconByStatus(
    BuildContext context,
    BaseMessage baseMessage,
    User? loggedInUser,
    bool isAudio,
  ) {
    if (baseMessage is! Call) return "";
    final call = baseMessage;
    if (_isMissedForMe(call, loggedInUser)) {
      return isAudio ? AssetConstants.audioMissed : AssetConstants.videoMissed;
    }
    if (call.callStatus == CallStatusConstants.initiated) {
      if (_startedBy(call, loggedInUser)) {
        return isAudio
            ? AssetConstants.outgoingAudioCallNoFill
            : AssetConstants.outgoingVideoCallNoFill;
      }
      return isAudio
          ? AssetConstants.incomingAudioCallNoFill
          : AssetConstants.incomingVideoCallNoFill;
    }
    return isAudio ? AssetConstants.callNoFill : AssetConstants.videocamNoFill;
  }

  /// The colour of a call action bubble's text, and of its icon: the error
  /// colour for a missed call (see [isMissedCall]), textSecondary otherwise.
  static Color getCallTextColor(
    BuildContext context,
    BaseMessage baseMessage,
    User? loggedInUser,
    CometChatColorPalette colorPalette,
  ) {
    if (baseMessage is Call && _isMissedForMe(baseMessage, loggedInUser)) {
      return colorPalette.error ?? Colors.transparent;
    }
    return colorPalette.textSecondary ?? Colors.transparent;
  }

  /// The colour of a call icon: the error colour for a missed call (see
  /// [isMissedCall]), iconSecondary otherwise. The call action bubbles paint
  /// their icon with [getCallTextColor] instead, so it matches their text.
  static Color getCallIconColor(
    BuildContext context,
    BaseMessage baseMessage,
    User? loggedInUser,
    CometChatColorPalette colorPalette,
  ) {
    if (baseMessage is Call && _isMissedForMe(baseMessage, loggedInUser)) {
      return colorPalette.error ?? Colors.transparent;
    }
    return colorPalette.iconSecondary ?? Colors.transparent;
  }
}
