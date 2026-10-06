/// Golden pins for the state views of [CometChatConversations]: what the
/// screen shows while it loads, when there is nothing, and when the fetch
/// failed.
///
/// The real screen is rendered, held in each state through its
/// `conversationsBloc` seam.
///
///   flutter test test/chat_ui/conversations/goldens/                  # verify
///   flutter test test/chat_ui/conversations/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

class _MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {
  final _typing = <String, ValueNotifier<List<TypingIndicator>>>{};

  @override
  ValueNotifier<List<TypingIndicator>> getTypingNotifier(String id) =>
      _typing.putIfAbsent(id, () => ValueNotifier(const []));

  @override
  List<TypingIndicator> getTypingIndicators(String conversationId) => const [];

  @override
  // ignore: must_call_super
  void add(ConversationsEvent event) {}
}

_MockConversationsBloc _bloc(ConversationsState state) {
  final bloc = _MockConversationsBloc();
  whenListen(
    bloc,
    Stream<ConversationsState>.value(state),
    initialState: state,
  );
  return bloc;
}

const _size = Size(375, 560);

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        'conversations empty state',
        fileName: 'conversations_state_empty',
        size: _size,
        builder: () => CometChatConversations(
          conversationsBloc: _bloc(const ConversationsEmpty()),
        ),
      );

      lightDarkGolden(
        'conversations error state',
        fileName: 'conversations_state_error',
        size: _size,
        builder: () => CometChatConversations(
          conversationsBloc: _bloc(
            const ConversationsError(message: 'Something went wrong'),
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
