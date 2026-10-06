/// Golden pins for [CometChatMessageHeader], the bar above every chat.
///
/// The real header is rendered, held in a fixed state through its
/// `messageHeaderBloc` seam (the same mock the prop tests use). Nothing here
/// reaches the network: avatars have no URL, so they fall back to initials.
///
///   flutter test test/chat_ui/message_header/goldens/                  # verify
///   flutter test test/chat_ui/message_header/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

class _MockMessageHeaderBloc
    extends MockBloc<MessageHeaderEvent, MessageHeaderState>
    implements MessageHeaderBloc {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

User _online() => User(uid: 'u-priya', name: 'Priya Raman', status: 'online');

/// A last-active stamp in another year, so the header formats it as an
/// absolute date and the golden does not depend on the wall clock.
User _lastSeen() => User(
  uid: 'u-marcus',
  name: 'Marcus Webb',
  status: 'offline',
  lastActiveAt: DateTime(2020, 3, 14, 9, 30),
);

Group _group() => Group(
  guid: 'g-design',
  name: 'Design Review',
  type: CometChatGroupType.private,
  membersCount: 12,
);

_MockMessageHeaderBloc _bloc({
  User? user,
  Group? group,
  bool isTyping = false,
  User? typingUser,
}) {
  final state = MessageHeaderState(
    status: MessageHeaderStatus.loaded,
    user: user,
    group: group,
    memberCount: group?.membersCount ?? 0,
    isTyping: isTyping,
    typingUser: typingUser,
  );
  final bloc = _MockMessageHeaderBloc();
  whenListen(
    bloc,
    Stream<MessageHeaderState>.value(state),
    initialState: state,
  );
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

/// The header only builds its call buttons when the Kit was initialised with
/// calls enabled.
void _setCallsEnabled(bool enabled) {
  CometChatUIKit.authenticationSettings = enabled
      ? (UIKitSettingsBuilder()
              ..appId = 'golden-app'
              ..region = 'us'
              ..authKey = 'golden-key'
              ..enableCalls = true)
            .build()
      : null;
}

const _size = Size(375, 80);

void main() {
  setUp(() => _setCallsEnabled(false));
  tearDown(() => _setCallsEnabled(false));

  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        'user header, online',
        fileName: 'message_header_user_online',
        size: _size,
        settle: false,
        builder: () {
          final user = _online();
          return CometChatMessageHeader(
            user: user,
            messageHeaderBloc: _bloc(user: user),
          );
        },
      );

      lightDarkGolden(
        'user header, offline with last-seen subtitle',
        fileName: 'message_header_user_last_seen',
        size: _size,
        settle: false,
        builder: () {
          final user = _lastSeen();
          return CometChatMessageHeader(
            user: user,
            messageHeaderBloc: _bloc(user: user),
          );
        },
      );

      lightDarkGolden(
        'group header, member count',
        fileName: 'message_header_group_members',
        size: _size,
        settle: false,
        builder: () {
          final group = _group();
          return CometChatMessageHeader(
            group: group,
            messageHeaderBloc: _bloc(group: group),
          );
        },
      );

      lightDarkGolden(
        'user header, typing',
        fileName: 'message_header_user_typing',
        size: _size,
        settle: false,
        builder: () {
          final user = _online();
          return CometChatMessageHeader(
            user: user,
            messageHeaderBloc: _bloc(user: user, isTyping: true),
          );
        },
      );

      lightDarkGolden(
        'group header, a member typing',
        fileName: 'message_header_group_typing',
        size: _size,
        settle: false,
        builder: () {
          final group = _group();
          return CometChatMessageHeader(
            group: group,
            messageHeaderBloc: _bloc(
              group: group,
              isTyping: true,
              typingUser: _online(),
            ),
          );
        },
      );

      lightDarkGolden(
        'user header, voice and video call buttons',
        fileName: 'message_header_call_buttons',
        size: _size,
        settle: false,
        builder: () {
          _setCallsEnabled(true);
          final user = _online();
          return CometChatMessageHeader(
            user: user,
            messageHeaderBloc: _bloc(user: user),
          );
        },
      );
    },
  );
}
