import 'package:cometchat_chat_uikit/shared_ui/src/offline/message_key.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('rowKey', () {
    test('server id wins', () {
      expect(rowKey(msg(id: 42, localMessageId: 'l1')), 's:42');
    });
    test('un-acked keys on localMessageId then muid', () {
      expect(rowKey(msg(localMessageId: 'l1')), 'l:l1');
      expect(rowKey(msg(muid: 'm9')), 'l:m:m9');
    });

    test('id-less rows with no local id or muid never share a key', () {
      expect(rowKey(msg()), isNot(rowKey(msg())));
    });
  });

  group('collapseRepeatedOwnRows (D-351)', () {
    test('unique rows come back as the same list', () {
      final rows = [
        msg(id: 1, senderUid: 'bob', muid: 'm1'),
        msg(id: 2, senderUid: 'me', localMessageId: 'l2', muid: 'm2'),
        msg(senderUid: 'me', localMessageId: 'l3', muid: 'm3'),
      ];
      expect(collapseRepeatedOwnRows(rows, 'me'), same(rows));
    });

    test('a repeated own muid folds into the first row, which keeps its '
        'place and the later receipts', () {
      final first = msg(id: 5, senderUid: 'me', localMessageId: 'l', muid: 'm')
        ..deliveredAt = DateTime(2026, 11, 1);
      final again = msg(id: 9, senderUid: 'me', localMessageId: 'l', muid: 'm')
        ..readAt = DateTime(2026, 11, 2);
      final other = msg(id: 7, senderUid: 'bob');
      final out = collapseRepeatedOwnRows([first, other, again], 'me');
      expect(out, [same(first), same(other)]);
      expect(first.deliveredAt, DateTime(2026, 11, 1));
      expect(first.readAt, DateTime(2026, 11, 2));
    });

    test(
      'the sent copy beats the pending copy, at the pending row\'s place',
      () {
        final pending = msg(senderUid: 'me', localMessageId: 'l', muid: 'm');
        final other = msg(id: 7, senderUid: 'bob');
        final sent = msg(
          id: 9,
          senderUid: 'me',
          localMessageId: 'l',
          muid: 'm',
        );
        final out = collapseRepeatedOwnRows([pending, other, sent], 'me');
        expect(out, [same(sent), same(other)]);
        // Either order: the sent copy still wins.
        final back = collapseRepeatedOwnRows([sent, pending], 'me');
        expect(back, [same(sent)]);
      },
    );

    test('a shared muid folds even when one copy has no localMessageId', () {
      final a = msg(id: 5, senderUid: 'me', localMessageId: 'l', muid: 'm');
      final b = msg(id: 9, senderUid: 'me', muid: 'm');
      expect(collapseRepeatedOwnRows([a, b], 'me'), [same(a)]);
    });

    test('other senders\' rows never fold, even on one muid', () {
      final rows = [
        msg(id: 5, senderUid: 'bob', muid: 'm'),
        msg(id: 9, senderUid: 'bob', muid: 'm'),
      ];
      expect(collapseRepeatedOwnRows(rows, 'me'), same(rows));
    });

    test('with no logged-in user nothing folds', () {
      final rows = [
        msg(id: 5, senderUid: 'me', muid: 'm'),
        msg(id: 9, senderUid: 'me', muid: 'm'),
      ];
      expect(collapseRepeatedOwnRows(rows, null), same(rows));
    });
  });

  group('renderKey', () {
    test('own message keys on localMessageId, stable across ack', () {
      final pending = msg(senderUid: 'me', localMessageId: 'l1');
      final acked = msg(id: 7, senderUid: 'me', localMessageId: 'l1');
      expect(renderKey(pending, 'me'), 'l1');
      expect(renderKey(acked, 'me'), 'l1'); // same key before and after ack
    });
    test('other sender always keys on server id', () {
      final other = msg(
        id: 7,
        senderUid: 'bob',
        localMessageId: 'l1',
        muid: 'm9',
      );
      expect(renderKey(other, 'me'), 's:7');
    });
    test('own message with only muid keys on muid', () {
      expect(renderKey(msg(senderUid: 'me', muid: 'm9'), 'me'), 'm:m9');
    });
  });

  group('MessageIdentityIndex (G6)', () {
    test('resolves by server id', () {
      final idx = MessageIdentityIndex(myUid: 'me');
      final a = msg(id: 5, senderUid: 'bob');
      idx.put(a);
      expect(idx.lookup(msg(id: 5, senderUid: 'bob')), same(a));
    });

    test(
      'localMessageId matches only no-server-id, same sender + conversation',
      () {
        final idx = MessageIdentityIndex(myUid: 'me');
        final pending = msg(
          senderUid: 'me',
          localMessageId: 'l1',
          conversationId: 'c1',
        );
        idx.put(pending);
        // same sender + conversation, no server id -> match
        expect(
          idx.lookup(
            msg(senderUid: 'me', localMessageId: 'l1', conversationId: 'c1'),
          ),
          same(pending),
        );
        // different sender -> no match
        expect(
          idx.lookup(
            msg(senderUid: 'bob', localMessageId: 'l1', conversationId: 'c1'),
          ),
          isNull,
        );
        // different conversation -> no match
        expect(
          idx.lookup(
            msg(senderUid: 'me', localMessageId: 'l1', conversationId: 'c2'),
          ),
          isNull,
        );
      },
    );

    test('never matches localMessageId against a row that has a server id', () {
      final idx = MessageIdentityIndex(myUid: 'me');
      final acked = msg(
        id: 9,
        senderUid: 'me',
        localMessageId: 'l1',
        conversationId: 'c1',
      );
      idx.put(acked);
      // a fresh pending row with the same localMessageId but no server id:
      // the alias map routes it to the acked row (same identity), which is
      // correct; but a *different* localMessageId must not match it.
      expect(
        idx.lookup(
          msg(senderUid: 'me', localMessageId: 'other', conversationId: 'c1'),
        ),
        isNull,
      );
    });

    test(
      'alias map routes a late event by localMessageId to the acked row',
      () {
        final idx = MessageIdentityIndex(myUid: 'me');
        final acked = msg(
          id: 9,
          senderUid: 'me',
          localMessageId: 'l1',
          conversationId: 'c1',
        );
        idx.put(acked);
        expect(
          idx.lookup(
            msg(senderUid: 'me', localMessageId: 'l1', conversationId: 'c1'),
          ),
          same(acked),
        );
      },
    );

    test('null/empty identities never match', () {
      final idx = MessageIdentityIndex(myUid: 'me');
      final a = msg(
        senderUid: 'me',
        conversationId: 'c1',
      ); // no id, no lid, no muid
      idx.put(a);
      expect(idx.lookup(msg(senderUid: 'me', conversationId: 'c1')), isNull);
    });

    test('clear empties the index', () {
      final idx = MessageIdentityIndex(myUid: 'me');
      idx.put(msg(id: 1, senderUid: 'bob'));
      idx.clear();
      expect(idx.lookup(msg(id: 1, senderUid: 'bob')), isNull);
    });
  });
}
