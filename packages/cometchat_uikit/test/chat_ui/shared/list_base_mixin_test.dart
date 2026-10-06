/// Behaviour tests for the `ListBase<T>` mixin — the reusable list store the
/// chat BLoCs mix in (lib/chat_ui/src/shared/list_base.dart).
///
/// Two things make this worth pinning beyond the obvious add/remove. First,
/// every mutator replaces `_items` with a NEW list rather than mutating in
/// place, which is what makes `emit(state.copyWith(items: …))` rebuild — a
/// future "optimisation" to mutate in place would be invisible to a test that
/// only checked the contents. Second, each mutator is specified to call a
/// particular hook a particular number of times, and the BLoCs emit from those
/// hooks: `addAllItems` firing once instead of once per item, or a rejected
/// index still firing, would be a real regression.
///
/// So the recorder below captures the hook call, the list it was handed, and
/// whether that list is the same object the store now holds.
///
///   flutter test test/chat_ui/shared/list_base_mixin_test.dart
library;

import 'package:cometchat_chat_uikit/chat_ui/src/shared/list_base.dart';
import 'package:flutter_test/flutter_test.dart';

/// One hook invocation.
class _Hook {
  _Hook(this.name, this.args, this.listArg);

  final String name;
  final List<Object?> args;
  final List<String> listArg;

  @override
  String toString() => '$name$args -> $listArg';
}

class _Store with ListBase<String> {
  final List<_Hook> hooks = [];

  List<String> get hookNames => hooks.map((h) => h.name).toList();

  @override
  void onItemAdded(String item, List<String> updatedList) =>
      hooks.add(_Hook('added', [item], updatedList));

  @override
  void onItemRemoved(String item, List<String> updatedList) =>
      hooks.add(_Hook('removed', [item], updatedList));

  @override
  void onItemUpdated(
    String oldItem,
    String newItem,
    List<String> updatedList,
  ) => hooks.add(_Hook('updated', [oldItem, newItem], updatedList));

  @override
  void onListCleared(List<String> previousList) =>
      hooks.add(_Hook('cleared', const [], previousList));

  @override
  void onListReplaced(List<String> previousList, List<String> newList) =>
      hooks.add(_Hook('replaced', [previousList], newList));
}

/// A store that overrides nothing, so every mutator lands on the mixin's own
/// empty hook bodies.
class _SilentStore with ListBase<String> {}

_Store _seeded([List<String> seed = const ['a', 'b', 'c']]) {
  final s = _Store()..addAllItems(seed);
  s.hooks.clear();
  return s;
}

void main() {
  // ===========================================================================
  group('read-only surface', () {
    test('a fresh store is empty on every accessor', () {
      final s = _Store();
      expect(s.items, isEmpty);
      expect(s.itemCount, 0);
      expect(s.isEmpty, isTrue);
      expect(s.isNotEmpty, isFalse);
    });

    test('the accessors track the contents', () {
      final s = _seeded(['a']);
      expect(s.itemCount, 1);
      expect(s.isEmpty, isFalse);
      expect(s.isNotEmpty, isTrue);
    });

    test(
      'items is an unmodifiable view a caller cannot mutate behind the store',
      () {
        final s = _seeded();
        final view = s.items;
        expect(view, ['a', 'b', 'c']);
        expect(() => view.add('d'), throwsUnsupportedError);
        expect(() => view.removeAt(0), throwsUnsupportedError);
        expect(s.items, ['a', 'b', 'c']);
      },
    );

    test('items hands out a fresh view each read, not a cached one', () {
      final s = _seeded();
      expect(s.items, isNot(same(s.items)));
    });

    test('containsItem and getItemAt read without mutating', () {
      final s = _seeded();
      expect(s.containsItem('b'), isTrue);
      expect(s.containsItem('zzz'), isFalse);
      expect(s.getItemAt(0), 'a');
      expect(s.getItemAt(2), 'c');
      expect(s.getItemAt(3), isNull);
      expect(s.getItemAt(-1), isNull);
      expect(s.hooks, isEmpty);
    });
  });

  // ===========================================================================
  group('addItem / addAllItems / addAllItemsAtStart', () {
    test('addItem appends and fires added once with the new list', () {
      final s = _seeded(['a']);
      s.addItem('b');

      expect(s.items, ['a', 'b']);
      expect(s.hookNames, ['added']);
      expect(s.hooks.single.args, ['b']);
      expect(s.hooks.single.listArg, ['a', 'b']);
    });

    test('addAllItems appends the batch and fires added once per item', () {
      final s = _seeded(['a']);
      s.addAllItems(['b', 'c']);

      expect(s.items, ['a', 'b', 'c']);
      expect(s.hookNames, ['added', 'added']);
      expect(s.hooks.first.args, ['b']);
      expect(s.hooks.last.args, ['c']);
      // Every hook sees the fully-updated list, not a partial one.
      for (final h in s.hooks) {
        expect(h.listArg, ['a', 'b', 'c']);
      }
    });

    test('addAllItems with an empty batch is a complete no-op', () {
      final s = _seeded();
      s.addAllItems([]);
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hooks, isEmpty);
    });

    test('addAllItemsAtStart prepends in order and fires per item', () {
      final s = _seeded(['c']);
      s.addAllItemsAtStart(['a', 'b']);

      expect(s.items, ['a', 'b', 'c']);
      expect(s.hookNames, ['added', 'added']);
      expect(s.hooks.first.args, ['a']);
      expect(s.hooks.last.args, ['b']);
    });

    test('addAllItemsAtStart with an empty batch is a no-op', () {
      final s = _seeded();
      s.addAllItemsAtStart([]);
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hooks, isEmpty);
    });

    test('addUniqueItem adds a new value and refuses a duplicate', () {
      final s = _seeded(['a']);

      expect(s.addUniqueItem('b'), isTrue);
      expect(s.items, ['a', 'b']);
      expect(s.hookNames, ['added']);

      expect(s.addUniqueItem('a'), isFalse);
      expect(s.items, ['a', 'b']);
      expect(s.hookNames, ['added'], reason: 'a refused add must not fire');
    });
  });

  // ===========================================================================
  group('removeItem / removeItemAt / removeIf / clearItems', () {
    test('removeItem drops the value and reports true', () {
      final s = _seeded();
      expect(s.removeItem('b'), isTrue);
      expect(s.items, ['a', 'c']);
      expect(s.hookNames, ['removed']);
      expect(s.hooks.single.args, ['b']);
      expect(s.hooks.single.listArg, ['a', 'c']);
    });

    test('removeItem on an absent value reports false and fires nothing', () {
      final s = _seeded();
      expect(s.removeItem('zzz'), isFalse);
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hooks, isEmpty);
    });

    test('removeItem drops every equal element, not only the first', () {
      // It filters by `!=`, so duplicates all go. Worth pinning: a BLoC that
      // holds two equal rows loses both.
      final s = _seeded(['a', 'b', 'a']);
      expect(s.removeItem('a'), isTrue);
      expect(s.items, ['b']);
      expect(s.hookNames, ['removed']);
    });

    test('removeItemAt returns the removed item', () {
      final s = _seeded();
      expect(s.removeItemAt(1), 'b');
      expect(s.items, ['a', 'c']);
      expect(s.hookNames, ['removed']);
      expect(s.hooks.single.args, ['b']);
    });

    test('removeItemAt out of range returns null and changes nothing', () {
      final s = _seeded();
      expect(s.removeItemAt(-1), isNull);
      expect(s.removeItemAt(3), isNull);
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hooks, isEmpty);
    });

    test('removeIf drops the matches and fires removed once per match', () {
      final s = _seeded(['apple', 'banana', 'avocado']);
      s.removeIf((e) => e.startsWith('a'));

      expect(s.items, ['banana']);
      expect(s.hookNames, ['removed', 'removed']);
      expect(s.hooks.first.args, ['apple']);
      expect(s.hooks.last.args, ['avocado']);
      expect(s.hooks.first.listArg, ['banana']);
    });

    test('removeIf matching nothing is a no-op', () {
      final s = _seeded();
      s.removeIf((_) => false);
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hooks, isEmpty);
    });

    test('removeIf matching everything empties the store', () {
      final s = _seeded();
      s.removeIf((_) => true);
      expect(s.items, isEmpty);
      expect(s.hookNames, ['removed', 'removed', 'removed']);
    });

    test('removeIf evaluates the predicate twice per element', () {
      // It builds the removal list and then filters again, so a predicate
      // with side effects runs 2n times. Pinned because a BLoC passing a
      // counting or logging predicate would double-count.
      final seen = <String>[];
      final s = _seeded();
      s.removeIf((e) {
        seen.add(e);
        return e == 'b';
      });
      expect(seen, ['a', 'b', 'c', 'a', 'b', 'c']);
    });

    test('clearItems empties the store and hands the hook the old list', () {
      final s = _seeded();
      s.clearItems();

      expect(s.items, isEmpty);
      expect(s.itemCount, 0);
      expect(s.hookNames, ['cleared']);
      expect(s.hooks.single.listArg, ['a', 'b', 'c']);
    });

    test('clearItems on an empty store still fires the hook', () {
      final s = _Store();
      s.clearItems();
      expect(s.hookNames, ['cleared']);
      expect(s.hooks.single.listArg, isEmpty);
    });
  });

  // ===========================================================================
  group('updateItem / insertItemAt / replaceFirst / updateItemWhere', () {
    test('updateItem swaps in the new value and reports both sides', () {
      final s = _seeded();
      expect(s.updateItem(1, 'B'), isTrue);

      expect(s.items, ['a', 'B', 'c']);
      expect(s.hookNames, ['updated']);
      expect(s.hooks.single.args, ['b', 'B']);
      expect(s.hooks.single.listArg, ['a', 'B', 'c']);
    });

    test('updateItem out of range reports false and fires nothing', () {
      final s = _seeded();
      expect(s.updateItem(-1, 'x'), isFalse);
      expect(s.updateItem(3, 'x'), isFalse);
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hooks, isEmpty);
    });

    test('insertItemAt accepts the end position but not past it', () {
      final s = _seeded();
      expect(s.insertItemAt(3, 'd'), isTrue, reason: 'append is length, valid');
      expect(s.items, ['a', 'b', 'c', 'd']);
      expect(s.insertItemAt(5, 'x'), isFalse);
      expect(s.insertItemAt(-1, 'x'), isFalse);
      expect(s.items, ['a', 'b', 'c', 'd']);
      expect(s.hookNames, ['added']);
    });

    test('insertItemAt in the middle shifts the tail along', () {
      final s = _seeded();
      expect(s.insertItemAt(1, 'x'), isTrue);
      expect(s.items, ['a', 'x', 'b', 'c']);
      expect(s.hooks.single.args, ['x']);
    });

    test('replaceFirst swaps the first occurrence only', () {
      final s = _seeded(['a', 'b', 'a']);
      expect(s.replaceFirst('a', 'A'), isTrue);
      expect(s.items, ['A', 'b', 'a']);
      expect(s.hookNames, ['updated']);
      expect(s.hooks.single.args, ['a', 'A']);
    });

    test('replaceFirst on an absent value reports false', () {
      final s = _seeded();
      expect(s.replaceFirst('zzz', 'x'), isFalse);
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hooks, isEmpty);
    });

    test('updateItemWhere updates the first match', () {
      final s = _seeded(['apple', 'banana', 'avocado']);
      expect(s.updateItemWhere((e) => e.startsWith('a'), 'APPLE'), isTrue);
      expect(s.items, ['APPLE', 'banana', 'avocado']);
      expect(s.hooks.single.args, ['apple', 'APPLE']);
    });

    test('updateItemWhere with no match reports false', () {
      final s = _seeded();
      expect(s.updateItemWhere((_) => false, 'x'), isFalse);
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hooks, isEmpty);
    });
  });

  // ===========================================================================
  group('search', () {
    test('findFirst returns the first match and null when there is none', () {
      final s = _seeded(['apple', 'banana', 'avocado']);
      expect(s.findFirst((e) => e.startsWith('a')), 'apple');
      expect(s.findFirst((e) => e == 'zzz'), isNull);
    });

    test('findFirst stops at the first match', () {
      final visited = <String>[];
      final s = _seeded();
      s.findFirst((e) {
        visited.add(e);
        return e == 'b';
      });
      expect(visited, ['a', 'b']);
    });

    test('findIndex returns the position, or -1', () {
      final s = _seeded(['apple', 'banana', 'avocado']);
      expect(s.findIndex((e) => e.startsWith('b')), 1);
      expect(s.findIndex((e) => e == 'zzz'), -1);
    });

    test('findIndex on an empty store is -1', () {
      expect(_Store().findIndex((_) => true), -1);
    });

    test('searching fires no hooks', () {
      final s = _seeded();
      s
        ..findFirst((_) => true)
        ..findIndex((_) => true);
      expect(s.hooks, isEmpty);
    });
  });

  // ===========================================================================
  group('whole-list operations', () {
    test('replaceAll swaps the contents and reports both lists', () {
      final s = _seeded();
      s.replaceAll(['x', 'y']);

      expect(s.items, ['x', 'y']);
      expect(s.hookNames, ['replaced']);
      expect(s.hooks.single.args.single, ['a', 'b', 'c']);
      expect(s.hooks.single.listArg, ['x', 'y']);
    });

    test('replaceAll copies its argument rather than aliasing it', () {
      final s = _seeded();
      final incoming = ['x'];
      s.replaceAll(incoming);
      incoming.add('y');
      expect(s.items, ['x'], reason: 'the caller must not own the store list');
    });

    test('filterItems keeps the matches and reports a replacement', () {
      final s = _seeded(['apple', 'banana', 'avocado']);
      s.filterItems((e) => e.startsWith('a'));

      expect(s.items, ['apple', 'avocado']);
      expect(s.hookNames, ['replaced']);
      expect(s.hooks.single.args.single, ['apple', 'banana', 'avocado']);
      expect(s.hooks.single.listArg, ['apple', 'avocado']);
    });

    test('filterItems still fires when nothing is filtered out', () {
      final s = _seeded();
      s.filterItems((_) => true);
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hookNames, ['replaced']);
    });

    test('reverse flips the order and reports a replacement', () {
      final s = _seeded();
      s.reverse();

      expect(s.items, ['c', 'b', 'a']);
      expect(s.hookNames, ['replaced']);
      expect(s.hooks.single.args.single, ['a', 'b', 'c']);
      expect(s.hooks.single.listArg, ['c', 'b', 'a']);
    });

    test('reverse twice restores the original order', () {
      final s = _seeded();
      s
        ..reverse()
        ..reverse();
      expect(s.items, ['a', 'b', 'c']);
    });
  });

  // ===========================================================================
  group('swapItems / moveItem', () {
    test('swapItems exchanges two positions', () {
      final s = _seeded();
      expect(s.swapItems(0, 2), isTrue);
      expect(s.items, ['c', 'b', 'a']);
      expect(s.hookNames, ['updated']);
      // The hook reports the change at index1: 'a' was replaced by 'c'.
      expect(s.hooks.single.args, ['a', 'c']);
    });

    test('swapItems rejects either index out of range', () {
      final s = _seeded();
      expect(s.swapItems(-1, 0), isFalse);
      expect(s.swapItems(0, 3), isFalse);
      expect(s.swapItems(3, 0), isFalse);
      expect(s.swapItems(0, -1), isFalse);
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hooks, isEmpty);
    });

    test('swapItems with the same index leaves the order untouched', () {
      final s = _seeded();
      expect(s.swapItems(1, 1), isTrue);
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hookNames, ['updated']);
      expect(s.hooks.single.args, ['b', 'b']);
    });

    test('moveItem shifts an item forward', () {
      final s = _seeded();
      expect(s.moveItem(0, 2), isTrue);
      expect(s.items, ['b', 'c', 'a']);
      expect(s.hookNames, ['replaced']);
      expect(s.hooks.single.args.single, ['a', 'b', 'c']);
    });

    test('moveItem shifts an item backward', () {
      final s = _seeded();
      expect(s.moveItem(2, 0), isTrue);
      expect(s.items, ['c', 'a', 'b']);
    });

    test('moveItem rejects either index out of range', () {
      final s = _seeded();
      expect(s.moveItem(-1, 0), isFalse);
      expect(s.moveItem(0, 3), isFalse);
      expect(s.moveItem(3, 0), isFalse);
      expect(s.moveItem(0, -1), isFalse);
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hooks, isEmpty);
    });

    test(
      'moveItem onto itself is a no-op that still reports a replacement',
      () {
        final s = _seeded();
        expect(s.moveItem(1, 1), isTrue);
        expect(s.items, ['a', 'b', 'c']);
        expect(s.hookNames, ['replaced']);
      },
    );
  });

  // ===========================================================================
  group('copy-on-write', () {
    // Every mutator must hand the hook the list the store now holds, and that
    // list must be a different object from the one before — the BLoCs rely on
    // identity changing for `emit` to rebuild.
    test('each mutator publishes a new list object', () {
      final s = _seeded();
      final before = s.items;

      s.addItem('d');
      expect(s.items, isNot(orderedEquals(before)));

      final snapshots = <List<String>>[];
      s.hooks.clear();
      s
        ..addItem('e')
        ..removeItem('e')
        ..updateItem(0, 'A')
        ..insertItemAt(0, 'z')
        ..replaceAll(['p', 'q'])
        ..filterItems((_) => true)
        ..reverse()
        ..swapItems(0, 1)
        ..moveItem(0, 1);
      for (final h in s.hooks) {
        snapshots.add(h.listArg);
      }

      // Each hook saw a distinct list object.
      for (var i = 0; i < snapshots.length; i++) {
        for (var j = i + 1; j < snapshots.length; j++) {
          expect(identical(snapshots[i], snapshots[j]), isFalse);
        }
      }
    });
  });

  // ===========================================================================
  group('default hooks', () {
    test('a store that overrides nothing absorbs every mutator', () {
      final s = _SilentStore();
      expect(() {
        s
          ..addItem('a')
          ..addAllItems(['b', 'c'])
          ..addAllItemsAtStart(['z'])
          ..removeItem('b')
          ..removeItemAt(0)
          ..updateItem(0, 'A')
          ..insertItemAt(0, 'q')
          ..swapItems(0, 1)
          ..replaceAll(['p', 'q'])
          ..filterItems((_) => true)
          ..removeIf((e) => e == 'p')
          ..reverse()
          ..moveItem(0, 0)
          ..clearItems();
      }, returnsNormally);
      expect(s.items, isEmpty);
    });
  });
}
