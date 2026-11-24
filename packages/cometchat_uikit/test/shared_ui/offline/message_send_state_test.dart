import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_send_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  test('sendStateOf maps SDK status to the public tri-state', () {
    expect(
      sendStateOf(msg(status: CometChatMessageStatus.pending)),
      CometChatMessageSendState.sending,
    );
    expect(
      sendStateOf(msg(status: CometChatMessageStatus.sending)),
      CometChatMessageSendState.sending,
    );
    expect(
      sendStateOf(msg(status: CometChatMessageStatus.failed)),
      CometChatMessageSendState.failed,
    );
    expect(
      sendStateOf(msg(status: CometChatMessageStatus.sent)),
      CometChatMessageSendState.sent,
    );
    expect(
      sendStateOf(msg(status: CometChatMessageStatus.delivered)),
      CometChatMessageSendState.sent,
    );
    expect(
      sendStateOf(msg(status: CometChatMessageStatus.read)),
      CometChatMessageSendState.sent,
    );
    // A message with no send state (default) derives to sent.
    expect(sendStateOf(msg()), CometChatMessageSendState.sent);
  });
}
