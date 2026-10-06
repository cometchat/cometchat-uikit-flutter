/// Golden pins for [CometChatOutgoingCall], the dialing screen.
///
/// The real screen is rendered in its resting (idle) state through its `bloc`
/// seam, so no Calls SDK session, ringback tone or network is involved. The
/// callee has no avatar URL, so the avatar shows initials.
///
///   flutter test test/call_ui/outgoing_call/goldens/                  # verify
///   flutter test test/call_ui/outgoing_call/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

class _MockOutgoingCallBloc
    extends MockBloc<OutgoingCallEvent, OutgoingCallState>
    implements OutgoingCallBloc {}

final _callee = User(uid: 'u-marcus', name: 'Marcus Webb');

Call _call(String type) => Call(
  sessionId: 'golden-session',
  receiverUid: 'u-marcus',
  receiverType: CometChatReceiverType.user,
  type: type,
  sender: User(uid: 'u-me', name: 'Sam Carter'),
);

_MockOutgoingCallBloc _bloc() {
  const state = OutgoingCallState();
  final bloc = _MockOutgoingCallBloc();
  whenListen(bloc, Stream<OutgoingCallState>.value(state), initialState: state);
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        'outgoing call, dialing',
        fileName: 'outgoing_call_dialing',
        size: goldenScreen,
        settle: false,
        builder: () => CometChatOutgoingCall(
          call: _call(CallTypeConstants.audioCall),
          user: _callee,
          bloc: _bloc(),
        ),
      );
    },
  );
}
