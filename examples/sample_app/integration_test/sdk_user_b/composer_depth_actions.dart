import '../config/test_credentials.dart';
import 'sdk_user_b.dart';

/// REST helpers for the composer-side depth suites (E2E-100…E2E-129).
///
/// The point of these is to assert on the payload that actually LEFT the
/// device: User A sends through the UI, then User B reads the message back
/// over REST and the test checks the raw `data.text` (markdown markers,
/// `<@uid:…>` mention tokens) and `quotedMessageId`.
///
/// Unlike the receipt helpers these do NOT swallow errors — a REST failure
/// must fail the test, not turn the payload assertion into a no-op.
class ComposerDepthActions {
  ComposerDepthActions._();

  static String _senderUid(Map<String, dynamic> m) {
    final s = m['sender'];
    if (s is Map) return (s['uid'] ?? '').toString();
    return (s ?? '').toString();
  }

  static int _id(Map<String, dynamic> m) =>
      int.tryParse((m['id'] ?? '').toString()) ?? -1;

  /// Raw `data.text` of a message as the server stored it.
  static String textOf(Map<String, dynamic> message) {
    final data = message['data'];
    if (data is Map) return (data['text'] ?? '').toString();
    return '';
  }

  /// `quotedMessageId` of a reply, or null for a plain message. The key is the
  /// one the SDK's `BaseMessageDto.fromJson` reads (`json['quotedMessageId']`).
  static String? quotedMessageIdOf(Map<String, dynamic> message) {
    final v = message['quotedMessageId'];
    if (v == null) return null;
    final s = v.toString();
    return (s.isEmpty || s == '0') ? null : s;
  }

  static Future<Map<String, dynamic>?> _latestFromAContaining(
    String token, {
    required Map<String, String> scope,
  }) async {
    final data = await SdkUserB.get(
      '/messages',
      query: {...scope, 'per_page': '50', 'category': 'message'},
    );
    final list = (data['data'] as List?) ?? const [];
    Map<String, dynamic>? best;
    for (final raw in list) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      if (_senderUid(m) != TestCredentials.userAUid) continue;
      if (!textOf(m).contains(token)) continue;
      if (best == null || _id(m) > _id(best)) best = m;
    }
    return best;
  }

  /// Poll (as User B) for the message User A sent in the 1:1 chat whose text
  /// contains [token]. Returns null when it never shows up within [timeout] —
  /// callers must treat that as a failure.
  static Future<Map<String, dynamic>?> waitForMessageFromA(
    String token, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (true) {
      final m = await _latestFromAContaining(
        token,
        scope: {'uid': TestCredentials.userAUid},
      );
      if (m != null || DateTime.now().isAfter(end)) return m;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  /// Send "<@uid:A> [trailing]" from User B to User A — the wire syntax the
  /// UI Kit itself emits (cometchat_mentions_formatter.dart
  /// `handlePreMessageSend`: `"<@uid:${user.uid}>"`). Returns the message id.
  static Future<int> sendMentionOfAToA(String trailing) async {
    final data = await SdkUserB.post(
      '/messages',
      body: {
        'receiver': TestCredentials.userAUid,
        'receiverType': 'user',
        'category': 'message',
        'type': 'text',
        'data': {'text': '<@uid:${TestCredentials.userAUid}> $trailing'},
      },
    );
    final id = data['data']['id'];
    return id is int ? id : int.parse(id.toString());
  }
}
