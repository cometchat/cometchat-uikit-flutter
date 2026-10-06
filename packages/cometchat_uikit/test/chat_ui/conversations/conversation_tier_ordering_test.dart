// Tier ordering for the conversations list: [system pins][user pins][normal].
// Socket-driven inserts land at the top of their OWN tier only.

import 'package:flutter_test/flutter_test.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/utils/conversation_tier_ordering.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

Conversation _row(String id, {DateTime? pinnedAt, String? pinnedBy}) {
  final conversation = Conversation(
    conversationId: id,
    conversationType: 'user',
    conversationWith: User(uid: 'u_$id', name: id),
  );
  conversation.pinnedAt = pinnedAt;
  conversation.pinnedBy = pinnedBy;
  return conversation;
}

void main() {
  final when = DateTime(2026, 8, 6);

  group('tierOf', () {
    test('system pin: pinnedAt set and pinnedBy == app_system', () {
      expect(
        ConversationTierOrdering.tierOf(
          _row('a', pinnedAt: when, pinnedBy: 'app_system'),
        ),
        ConversationTierOrdering.systemPinTier,
      );
    });

    test('user pin: pinnedAt set with any other pinnedBy', () {
      expect(
        ConversationTierOrdering.tierOf(
          _row('a', pinnedAt: when, pinnedBy: 'uid-1'),
        ),
        ConversationTierOrdering.userPinTier,
      );
      expect(
        ConversationTierOrdering.tierOf(_row('a', pinnedAt: when)),
        ConversationTierOrdering.userPinTier,
        reason: 'pinnedAt without pinnedBy is still a user pin',
      );
    });

    test('normal: pinnedAt null wins over a stale pinnedBy remnant', () {
      expect(
        ConversationTierOrdering.tierOf(_row('a')),
        ConversationTierOrdering.normalTier,
      );
      expect(
        ConversationTierOrdering.tierOf(_row('a', pinnedBy: 'app_system')),
        ConversationTierOrdering.normalTier,
        reason: 'pinnedAt is the pin source of truth',
      );
    });
  });

  group('tierTopIndex', () {
    final rows = [
      _row('sys1', pinnedAt: when, pinnedBy: 'app_system'),
      _row('sys2', pinnedAt: when, pinnedBy: 'app_system'),
      _row('user1', pinnedAt: when, pinnedBy: 'me'),
      _row('user2', pinnedAt: when, pinnedBy: 'me'),
      _row('normal1'),
      _row('normal2'),
    ];

    test('system pin enters at index 0', () {
      expect(
        ConversationTierOrdering.tierTopIndex(
          ConversationTierOrdering.systemPinTier,
          rows,
        ),
        0,
      );
    });

    test('user pin enters below the system section', () {
      expect(
        ConversationTierOrdering.tierTopIndex(
          ConversationTierOrdering.userPinTier,
          rows,
        ),
        2,
      );
    });

    test('normal row enters below both pin sections', () {
      expect(
        ConversationTierOrdering.tierTopIndex(
          ConversationTierOrdering.normalTier,
          rows,
        ),
        4,
      );
    });

    test('empty list: everything enters at 0', () {
      for (final tier in [0, 1, 2]) {
        expect(ConversationTierOrdering.tierTopIndex(tier, const []), 0);
      }
    });

    test('no pins loaded: pins and normal rows all enter at 0', () {
      final normalOnly = [_row('a'), _row('b')];
      expect(
        ConversationTierOrdering.tierTopIndex(
          ConversationTierOrdering.systemPinTier,
          normalOnly,
        ),
        0,
      );
      expect(
        ConversationTierOrdering.tierTopIndex(
          ConversationTierOrdering.userPinTier,
          normalOnly,
        ),
        0,
      );
    });

    test(
      'degrades gracefully: stray pin below the boundary is not counted',
      () {
        final interleaved = [
          _row('sys1', pinnedAt: when, pinnedBy: 'app_system'),
          _row('normal1'),
          _row('user-stray', pinnedAt: when, pinnedBy: 'me'),
        ];
        expect(
          ConversationTierOrdering.tierTopIndex(
            ConversationTierOrdering.userPinTier,
            interleaved,
          ),
          1,
          reason: 'leading-scan stops at the first same-or-lower tier row',
        );
      },
    );
  });
}
