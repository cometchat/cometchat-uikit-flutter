import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';

/// Reusable generators for conversations-layer property-based tests.
///
/// `cometchat_sdk` types are not directly constructible in tests — they come
/// from the SDK as domain DTOs. We provide lightweight [Fake] subclasses with
/// just enough surface area to drive the properties we care about.

// ---------------------------------------------------------------------------
// Fakes — domain doubles
// ---------------------------------------------------------------------------

class FakeConversation extends Fake implements Conversation {
  // Pin Conversation fields — read by the trailing view's pin glyph.
  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;
  final String _id;
  FakeConversation(this._id);

  @override
  String? get conversationId => _id;

  @override
  String toString() => 'Conv($_id)';
}

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// Short alphanumeric ids bounded to 1..6 chars — keeps the search space small
/// and collisions likely, which is what we want for invariant testing.
Generator<String> conversationIdGen() => any.letterOrDigits
    .map((s) => s.isEmpty ? 'a' : s)
    .map((s) => s.length > 6 ? s.substring(0, 6) : s);

/// Generates a single [Conversation] with an id drawn from [conversationIdGen].
Generator<Conversation> conversationGen() =>
    conversationIdGen().map((id) => FakeConversation(id));

/// Generates a list of conversations with potentially duplicate ids. Use
/// [distinctConversationsGen] when you need uniqueness.
Generator<List<Conversation>> conversationsGen({int maxLength = 20}) =>
    any.listWithLengthInRange(0, maxLength, conversationGen());

/// Generates a list of conversations with unique ids (deduplicated by id,
/// order preserved). Useful when the invariant assumes the pre-condition
/// "no duplicates".
Generator<List<Conversation>> distinctConversationsGen({int maxLength = 20}) =>
    conversationsGen(maxLength: maxLength).map((list) {
      final seen = <String>{};
      final out = <Conversation>[];
      for (final c in list) {
        final id = c.conversationId;
        if (id != null && seen.add(id)) out.add(c);
      }
      return out;
    });

// ---------------------------------------------------------------------------
// Pair helpers — for properties that need two related inputs
// ---------------------------------------------------------------------------

/// A non-empty list and a valid index into it.
class IndexedList {
  final List<Conversation> list;
  final int index;
  const IndexedList(this.list, this.index);

  Conversation get selected => list[index];
  String get selectedId => selected.conversationId!;

  @override
  String toString() =>
      'IndexedList(len=${list.length}, idx=$index, id=$selectedId)';
}

Generator<IndexedList> indexedListGen({int maxLength = 20}) {
  return any
      .listWithLengthInRange(1, maxLength, conversationGen())
      .bind((list) {
        return any.intInRange(0, list.length).map((i) {
          // intInRange is exclusive of upper bound, so index is in [0, list.length - 1]
          return IndexedList(list, i);
        });
      })
      .map((il) {
        // Ensure the selected conversation has a unique id so RemoveConversation
        // by id semantics are unambiguous.
        final targetId = il.list[il.index].conversationId!;
        final dedup = <Conversation>[];
        var replaced = false;
        for (var i = 0; i < il.list.length; i++) {
          final c = il.list[i];
          if (i == il.index) {
            dedup.add(c);
            replaced = true;
          } else if (c.conversationId == targetId) {
            // Replace duplicate with a fresh unique id so only the selected
            // one matches for removal.
            dedup.add(FakeConversation('${targetId}_${i}x'));
          } else {
            dedup.add(c);
          }
        }
        assert(replaced);
        return IndexedList(dedup, il.index);
      });
}
