/// Addressing for the UI event bus.
///
/// [CometChatUIEvents] fans every panel event out to every registered
/// listener, so each component decides for itself whether an event was meant
/// for it. That decision used to be hand-rolled per component, and each
/// hand-rolled copy got it wrong in a different way. This is the single
/// definition.
///
/// An id is the loose `Map<String, dynamic>` the bus carries. Two keys
/// identify the target:
///
///   * `uid` or `guid` — the conversation.
///   * `parentMessageId` — the thread inside that conversation. Absent means
///     the conversation itself, not "any thread".
///
/// Anything else in the map (AI panels add an `extension` key) is ignored.
///
/// **An absent key is a value, not a wildcard.** That is the whole point of
/// this file. A composer in the parent conversation builds `{uid: 'U'}`; the
/// thread composer beside it builds `{parentMessageId: 42, uid: 'U'}`. The
/// previous composer check compared `parentMessageId` only when *both* maps
/// carried the key — which for that pair is never — so it compared nothing
/// that distinguished them, and a sticker keyboard or mention list opened in
/// the thread opened in the parent conversation too. The message list had the
/// mirror-image bug: it never looked at `parentMessageId` at all.
library;

/// Whether an event addressed to [eventId] targets the component identified by
/// [componentId].
///
/// [nullTargetsAll] decides what an unaddressed event (a null [eventId]) means
/// for this caller. The composer treats it as a broadcast, because the public
/// `CometChatUIKitHelper` lets an integrator raise a panel without naming a
/// conversation. The message list treats it as addressed to nobody.
bool uiEventTargets(
  Map<String, dynamic>? eventId,
  Map<String, dynamic>? componentId, {
  required bool nullTargetsAll,
}) {
  if (eventId == null) return nullTargetsAll;
  if (componentId == null) return false;

  // Threads first: this is the comparison that actually separates a
  // conversation from a thread opened on one of its messages.
  if (uiEventThreadOf(eventId) != uiEventThreadOf(componentId)) return false;

  final eventConversation = uiEventConversationOf(eventId);
  final componentConversation = uiEventConversationOf(componentId);

  // A partial id that names no conversation is still subject to the thread
  // check above; only a *mismatching* name rules the event out. Integrators
  // may hand `CometChatUIKitHelper.showPanel` a bare `{parentMessageId: n}`,
  // and that should keep working.
  if (eventConversation == null || componentConversation == null) return true;

  return eventConversation == componentConversation;
}

/// The thread an id refers to; 0 is the conversation itself.
///
/// Absent, null, 0 and a non-numeric value all collapse to 0, so the parent
/// conversation compares equal to itself and unequal to any real thread.
int uiEventThreadOf(Map<String, dynamic> id) {
  final value = id['parentMessageId'];
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// The conversation an id refers to, or null if it names none.
///
/// Groups win over users so that a malformed id carrying both keys resolves
/// consistently on every side of a comparison.
String? uiEventConversationOf(Map<String, dynamic> id) {
  final guid = id['guid'];
  if (guid is String && guid.isNotEmpty) return 'guid:$guid';
  final uid = id['uid'];
  if (uid is String && uid.isNotEmpty) return 'uid:$uid';
  return null;
}

/// Builds the id a component publishes and matches against.
///
/// Mirrors what the composer and message list each used to build inline.
/// `parentMessageId` is omitted when 0 so the map stays the shape the rest of
/// the Kit and existing integrations expect; [uiEventThreadOf] reads the
/// omission back as 0.
Map<String, dynamic> buildUiEventId({
  String? uid,
  String? guid,
  int parentMessageId = 0,
}) {
  final id = <String, dynamic>{};
  if (parentMessageId != 0) id['parentMessageId'] = parentMessageId;
  if (guid != null && guid.isNotEmpty) {
    id['guid'] = guid;
  } else if (uid != null && uid.isNotEmpty) {
    id['uid'] = uid;
  }
  return id;
}
