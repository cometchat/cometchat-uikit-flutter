/// The transient notices the offline UI can show (W1 §2.8, PR #23 §3.4/§3.7).
///
/// Each list bloc registers its own `Stream<OfflineNotice>` (read it with
/// [offlineNoticesOf]); `CometChatMessageList` and `CometChatConversations`
/// render it as today's snackbar style unless `hideOfflineNotices` is set. A
/// notice owned by no single list (cache reset, "messages not sent") goes
/// through `OfflineHub.postNotice` and is shown once, by a list that shows
/// notices. Internal to the kit (not exported): no public signature carries
/// it. Nothing emits notices in W1; W4 and W5 drive them.
library;

final Expando<Stream<OfflineNotice>> _streams = Expando('OfflineNoticeStream');

/// Registers the list-local notice stream of [bloc]. Called by the bloc.
void registerOfflineNotices(Object bloc, Stream<OfflineNotice> stream) =>
    _streams[bloc] = stream;

/// The list-local notice stream of [bloc], or null (e.g. a test double).
Stream<OfflineNotice>? offlineNoticesOf(Object bloc) => _streams[bloc];

/// A transient offline notice a list can show.
sealed class OfflineNotice {
  const OfflineNotice();
}

/// The send queue is full ("Too many messages waiting to send").
class QueueFull extends OfflineNotice {
  /// Creates the notice.
  const QueueFull();
}

/// A file was too large to queue offline.
class FileTooLargeOffline extends OfflineNotice {
  /// Creates the notice.
  const FileTooLargeOffline();
}

/// A Retry/Delete tap on a message still in flight ("Sending… try again in a
/// moment", D33b).
class SendingTryAgain extends OfflineNotice {
  /// Creates the notice.
  const SendingTryAgain();
}

/// A queued message was removed (DISCARDED). [copyText] is the message text to
/// offer a Copy action for, when it is a text message.
class UnsentRemoved extends OfflineNotice {
  /// Creates the notice; [copyText] is the removed message's text.
  const UnsentRemoved(this.copyText);

  /// The text of the removed message, offered for Copy.
  final String? copyText;
}

/// [n] messages weren't sent (an effective-offline transition turned un-acked
/// rows failed).
class MessagesNotSent extends OfflineNotice {
  /// Creates the notice for [count] messages.
  const MessagesNotSent(this.count);

  /// How many messages weren't sent.
  final int count;
}

/// [n] unsent messages couldn't be recovered after a cache reset.
class UnsentLost extends OfflineNotice {
  /// Creates the notice for [count] messages.
  const UnsentLost(this.count);

  /// How many unsent messages were lost.
  final int count;
}

/// Some unsent messages may not have been sent (cache reset, count unknown).
class UnsentMaybeLost extends OfflineNotice {
  /// Creates the notice.
  const UnsentMaybeLost();
}
