/// Golden pins for [CometChatIncomingCall], the ringing banner.
///
/// The real widget is rendered in its resting (idle) state through its
/// `incomingCallBloc` seam, so no Calls SDK session, ringtone or network is
/// involved. The caller has no avatar URL, so the avatar shows initials.
///
///   flutter test test/call_ui/incoming_call/goldens/                  # verify
///   flutter test test/call_ui/incoming_call/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

class _MockIncomingCallBloc
    extends MockBloc<IncomingCallEvent, IncomingCallState>
    implements IncomingCallBloc {
  _MockIncomingCallBloc(this._callType);

  final String _callType;

  /// Non-nullable, so mocktail's default null would throw while building.
  /// Mirrors the two strings the real bloc returns.
  @override
  String getSubtitle(BuildContext context) =>
      _callType == CallTypeConstants.videoCall
      ? Translations.of(context).incomingVideoCall
      : Translations.of(context).incomingAudioCall;
}

final _caller = User(uid: 'u-priya', name: 'Priya Raman');

Call _call(String type) => Call(
  sessionId: 'golden-session',
  receiverUid: 'u-me',
  receiverType: CometChatReceiverType.user,
  type: type,
  sender: _caller,
);

_MockIncomingCallBloc _bloc(String type) {
  const state = IncomingCallState();
  final bloc = _MockIncomingCallBloc(type);
  whenListen(bloc, Stream<IncomingCallState>.value(state), initialState: state);
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

const _size = Size(375, 200);

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      for (final type in [
        CallTypeConstants.audioCall,
        CallTypeConstants.videoCall,
      ]) {
        lightDarkGolden(
          'incoming $type call, ringing',
          fileName: 'incoming_call_$type',
          size: _size,
          settle: false,
          builder: () => CometChatIncomingCall(
            call: _call(type),
            user: _caller,
            incomingCallBloc: _bloc(type),
          ),
        );
      }
    },
  );
}
