/// Tests for ENG-39487 — the sender of a message was not subscribed to its
/// thread, so replies to their own message never notified them.
///
/// The server does not stamp `threadSubscribed` on your own outgoing message,
/// and the UI Kit otherwise only ever subscribed from an explicit Follow tap.
/// The composer now subscribes on send success.
///
/// These pin the two contracts that fix rests on: which thread a sent message
/// belongs to, and the feature gate that decides whether to subscribe at all.
/// The call itself goes through `CometChat.subscribeToThread`, a static on the
/// SDK with no seam to intercept, so whether the subscription lands is a
/// device/integration check rather than a unit one.
///
///   flutter test test/chat_ui/message_composer/sender_thread_subscription_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

final _me = User(uid: 'u1', name: 'Alice');

TextMessage _message({int id = 0, int parentMessageId = 0}) => TextMessage(
  id: id,
  text: 'hi',
  sender: _me,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
)..parentMessageId = parentMessageId;

void main() {
  group('resolveThreadId — which thread a sent message belongs to', () {
    test('a root message is its own thread', () {
      expect(MessageTemplateUtils.resolveThreadId(_message(id: 42)), 42);
    });

    test('a reply belongs to the thread it was sent into', () {
      // Subscribing the sender to the *parent* is the point: replying should
      // follow the conversation you replied in, not start a new one.
      expect(
        MessageTemplateUtils.resolveThreadId(
          _message(id: 99, parentMessageId: 42),
        ),
        42,
      );
    });

    test('an unacknowledged root resolves to 0 and is skipped', () {
      // id is 0 until the server answers. Subscribing then would target
      // nothing, so the composer only subscribes once it has a real id.
      expect(MessageTemplateUtils.resolveThreadId(_message()), 0);
    });
  });

  group('the feature gate', () {
    test('thread subscription is off unless an app opts in', () {
      // The composer must not start creating subscriptions for apps that do
      // not ship follow/unfollow.
      expect(UIKitSettingsBuilder().enableThreadSubscription, isFalse);
    });

    test('opting in is what turns the auto-subscribe on', () {
      final builder = UIKitSettingsBuilder()..enableThreadSubscription = true;
      expect(builder.enableThreadSubscription, isTrue);
    });

    test('a freshly built message is not subscribed', () {
      expect(_message(id: 42).threadSubscribed, isFalse);
    });

    test('isSubscribedToThreadOf reads the message, not a cache', () {
      final message = _message(id: 42);
      expect(MessageTemplateUtils.isSubscribedToThreadOf(message), isFalse);
      message.threadSubscribed = true;
      expect(MessageTemplateUtils.isSubscribedToThreadOf(message), isTrue);
    });
  });
}
