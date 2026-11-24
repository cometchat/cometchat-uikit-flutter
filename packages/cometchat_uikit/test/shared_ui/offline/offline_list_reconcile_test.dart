import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_reconcile.dart';
import 'package:flutter_test/flutter_test.dart';

/// A message-like row: server id (0 = un-acked), updatedAt, a local key.
class Row {
  const Row(this.id, {this.updatedAt = 0, this.localKey});
  final int id;
  final int updatedAt;
  final String? localKey;
}

ReconcileConfig<Row> cfg({bool Function(Row)? keep}) => ReconcileConfig<Row>(
  rowKey: (r) => r.id > 0 ? 's:${r.id}' : 'l:${r.localKey}',
  hasServerId: (r) => r.id > 0,
  updatedAt: (r) => r.updatedAt,
  compare: (a, b) {
    // un-acked rows last; otherwise by id.
    final aa = a.id > 0, bb = b.id > 0;
    if (aa != bb) return aa ? -1 : 1;
    return a.id.compareTo(b.id);
  },
  keep: keep,
);

ReconcileResult<Row> server(
  List<Row> current,
  List<Row> page, {
  int opGen = 0,
  int listGen = 0,
  bool Function(Row)? keep,
}) => reconcileServer(
  current: current,
  server: page,
  currentHasMore: true,
  opGen: opGen,
  listGen: listGen,
  config: cfg(keep: keep),
);

/// A conversation-like row keyed by conversationId and sorted newest first.
class Conv {
  const Conv(this.id, this.at, {this.ownUnsentPreview = false});
  final String id;
  final int at;
  final bool ownUnsentPreview;
}

void main() {
  test('cached then server upsert in place', () {
    final cached = reconcileCached(
      current: const <Row>[],
      cached: const [Row(1), Row(2)],
      currentHasMore: true,
      opGen: 0,
      listGen: 0,
      config: cfg(),
    );
    expect(cached.rows.map((r) => r.id), [1, 2]);
    expect(cached.hasMore, isTrue); // cached never changes hasMore
    final s = server(cached.rows, const [Row(1), Row(2), Row(3)]);
    expect(s.rows.map((r) => r.id), [1, 2, 3]);
    expect(s.hasMore, isTrue);
  });

  test('a phase from an older list generation is dropped unapplied', () {
    final current = const [Row(1)];
    final c = reconcileCached(
      current: current,
      cached: const [Row(2)],
      currentHasMore: true,
      opGen: 0,
      listGen: 1,
      config: cfg(),
    );
    expect(c.dropped, isTrue);
    expect(c.rows.map((r) => r.id), [1]);
    final s = server(current, const [Row(5)], opGen: 3, listGen: 4);
    expect(s.dropped, isTrue);
    expect(s.rows.map((r) => r.id), [1]);
    expect(s.hasMore, isTrue);
  });

  test('server removes an omission inside its range only', () {
    // server returns 2 and 4: 3 (inside) goes, 1 and 5 (outside) stay.
    final r = server(
      const [Row(1), Row(2), Row(3), Row(4), Row(5)],
      const [Row(2), Row(4)],
    );
    expect(r.rows.map((e) => e.id), [1, 2, 4, 5]);
  });

  test('the omission range follows the sort order, not numeric ids', () {
    // Conversations sorted newest first and keyed by conversationId.
    final conv = ReconcileConfig<Conv>(
      rowKey: (c) => c.id,
      hasServerId: (_) => true,
      updatedAt: (c) => c.at,
      compare: (a, b) => b.at.compareTo(a.at),
      keep: (c) => c.ownUnsentPreview,
    );
    final current = const [
      Conv('a', 50),
      Conv('b', 40),
      Conv('c', 30),
      Conv('d', 20, ownUnsentPreview: true),
      Conv('e', 15),
      Conv('f', 10),
    ];
    // The sync slice covers at 50..15: 'b' and 'c' are proven omissions,
    // 'd' is kept (own unsent preview), 'f' lies below the slice and stays.
    final r = reconcileServer(
      current: current,
      server: const [Conv('a', 50), Conv('e', 15)],
      currentHasMore: true,
      opGen: 0,
      listGen: 0,
      config: conv,
    );
    expect(r.rows.map((c) => c.id), ['a', 'd', 'e', 'f']);
  });

  test('a row without a server id is never removed (BEH-READ-30)', () {
    final r = server(
      [const Row(1), const Row(0, localKey: 'p1'), const Row(3)],
      const [Row(1), Row(3)],
    );
    expect(r.rows.any((e) => e.id == 0 && e.localKey == 'p1'), isTrue);
  });

  test('the keep predicate protects an omitted row', () {
    final r = server(
      const [Row(1), Row(2), Row(3)],
      const [Row(1), Row(3)],
      keep: (row) => row.id == 2,
    );
    expect(r.rows.map((e) => e.id), [1, 2, 3]);
  });

  test('newer updatedAt wins a same-id collision', () {
    final r = server(
      [const Row(1, updatedAt: 100)],
      [const Row(1, updatedAt: 50)],
    );
    expect(r.rows.single.updatedAt, 100); // live edit not reverted
  });

  test('empty cached page never ends history; empty server page does', () {
    final cached = reconcileCached(
      current: const [Row(1)],
      cached: const <Row>[],
      currentHasMore: true,
      opGen: 0,
      listGen: 0,
      config: cfg(),
    );
    expect(cached.hasMore, isTrue);
    expect(server(const [Row(1)], const <Row>[]).hasMore, isFalse);
  });

  test('un-acked rows sort last', () {
    final r = server(
      [const Row(0, localKey: 'p1'), const Row(5)],
      const [Row(5)],
    );
    expect(r.rows.last.id, 0);
  });
}
