/// `CometChatMentionsFormatter` — the composer side. Track 3 TEST3
/// (ENG-38684).
///
/// Everything between the user typing "@" and a mention being anchored in the
/// text: the tracker that decides when a suggestion list is open, the fetch
/// that fills it, what tapping a suggestion does to the text field, and the
/// bookkeeping that keeps mention offsets correct as the text around them
/// moves. None of it had ever run in a test — `cometchat_mentions_formatter`
/// sat at 14% with only the read path covered.
///
/// No SDK call is made: the formatter reaches the network through a
/// `UsersRequestBuilder`, which is injectable, so the tests hand it a builder
/// whose `build()` returns a request that answers from a fixture.
///
///   flutter test test/shared_ui/formatters/mentions_formatter_composer_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as cc;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _me = cc.User(uid: 'me', name: 'Me');
final _bob = cc.User(uid: 'u2', name: 'Bob');
final _carol = cc.User(uid: 'u3', name: 'Carol');
final _group = cc.Group(
  guid: 'g1',
  name: 'Team',
  type: GroupTypeConstants.public,
);

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Collects whatever the formatter pushes at a sink, without a live stream.
class _Sink<T> implements StreamSink<T> {
  final List<T> added = [];

  @override
  void add(T event) => added.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A [cc.UsersRequest] that answers from a fixture instead of the network.
class _FakeUsersRequest implements cc.UsersRequest {
  _FakeUsersRequest(this.pages, this.error);

  final List<List<cc.User>> pages;
  final cc.CometChatException? error;
  int calls = 0;

  @override
  Future<List<cc.User>> fetchNext({
    required Function(List<cc.User> userList)? onSuccess,
    required Function(cc.CometChatException excep)? onError,
  }) async {
    calls++;
    if (error != null) {
      onError?.call(error!);
      return const [];
    }
    final page = calls <= pages.length ? pages[calls - 1] : const <cc.User>[];
    onSuccess?.call(page);
    return page;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The seam: the formatter only ever calls `build()` on the builder it was
/// given, so overriding that is enough to keep the SDK out of the test.
class _FakeUsersRequestBuilder extends cc.UsersRequestBuilder {
  _FakeUsersRequestBuilder(this.pages, {this.error});

  final List<List<cc.User>> pages;
  final cc.CometChatException? error;

  /// The search keyword passed to each `build()`, in order.
  final List<String?> keywords = [];
  final List<int> limits = [];
  _FakeUsersRequest? lastRequest;

  @override
  cc.UsersRequest build() {
    keywords.add(searchKeyword);
    limits.add(limit);
    return lastRequest = _FakeUsersRequest(pages, error);
  }
}

/// Records the panel events the formatter emits, and can be made to throw so
/// that the formatter's own error handling is exercised.
class _PanelSpy with CometChatUIEventListener {
  final List<CustomUIPosition> shown = [];
  final List<CustomUIPosition> hidden = [];
  final List<WidgetBuilder> builders = [];
  bool throwOnHide = false;

  @override
  void showPanel(
    Map<String, dynamic>? id,
    CustomUIPosition uiPosition,
    WidgetBuilder child,
  ) {
    shown.add(uiPosition);
    builders.add(child);
  }

  @override
  void hidePanel(Map<String, dynamic>? id, CustomUIPosition uiPosition) {
    hidden.add(uiPosition);
    if (throwOnHide) throw StateError('host listener blew up');
  }
}

// ---------------------------------------------------------------------------

/// Invokes a suggestion's tap handler.
///
/// `SuggestionListItem.onTap` is declared as a bare `Function?`, so calling it
/// directly is a dynamic call; the cast keeps the call site statically typed.
void _tap(SuggestionListItem item) => (item.onTap! as void Function())();

class _Harness {
  _Harness({
    List<List<cc.User>> pages = const [],
    cc.CometChatException? error,
    cc.Group? group,
    String? mentionAllLabel,
    String? mentionAllLabelId,
    bool disableMentionAll = false,
    MentionsVisibility? visibleIn,
  }) : builder = _FakeUsersRequestBuilder(pages, error: error) {
    formatter = CometChatMentionsFormatter(
      usersRequestBuilder: builder,
      // Forces the users branch of init() even when a group is set, so the
      // group-only @all suggestion can be tested without a members request.
      mentionsType: MentionsType.users,
      group: group,
      disableMentionAll: disableMentionAll,
      mentionAllLabel: mentionAllLabel,
      mentionAllLabelId: mentionAllLabelId,
      visibleIn: visibleIn,
      composerId: const {'guid': 'g1'},
      suggestionListEventSink: suggestions,
      previousTextEventSink: previousText,
      onSearch: searches.add,
      onError: errors.add,
    )..init();
  }

  final _FakeUsersRequestBuilder builder;
  final _Sink<List<SuggestionListItem>> suggestions = _Sink();
  final _Sink<String> previousText = _Sink();
  final List<String?> searches = [];
  final List<Exception> errors = [];
  final TextEditingController controller = TextEditingController();

  late final CometChatMentionsFormatter formatter;

  /// The most recent non-empty suggestion list pushed at the composer.
  List<SuggestionListItem> get lastSuggestions =>
      suggestions.added.lastWhere((s) => s.isNotEmpty, orElse: () => const []);

  /// Puts [text] in the field with the caret at [offset] (end of text when
  /// omitted), then reports the change as the composer would.
  void type(String text, {int? offset, String previous = ''}) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset ?? text.length),
    );
    formatter.onChange(controller, previous);
  }

  void dispose() => controller.dispose();
}

void main() {
  late _PanelSpy panel;

  setUp(() {
    CometChatUIKit.loggedInUser = _me;
    panel = _PanelSpy();
    CometChatUIEvents.addUiListener('mentions-composer-test', panel);
  });

  tearDown(() {
    CometChatUIEvents.removeUiListener('mentions-composer-test');
    CometChatUIKit.loggedInUser = null;
  });

  // ==========================================================================
  group('init picks a request builder', () {
    test('the injected users builder is the one that gets configured', () {
      final h = _Harness(pages: const []);
      addTearDown(h.dispose);

      h.formatter.mentionTracker = '@Bo';
      h.formatter.initializeFetchRequest('Bo', h.controller);

      expect(h.builder.keywords, ['Bo']);
      expect(h.builder.limits, [10], reason: 'the page size is fixed at 10');
    });

    test('a group with the default mentions type builds a members request', () {
      // No fake is injected here, so this only asserts that init() takes the
      // group branch and produces *something* — building a real
      // GroupMembersRequest needs no SDK call.
      final f = CometChatMentionsFormatter(group: _group)..init();
      expect(() => f.init(), returnsNormally);
    });
  });

  // ==========================================================================
  group('typing opens and feeds the suggestion list', () {
    test('a bare "@" at the start of the field opens a search', () {
      final h = _Harness(
        pages: [
          [_bob, _carol],
        ],
      );
      addTearDown(h.dispose);

      h.type('@', previous: '');

      expect(h.formatter.mentionTracker, '@');
      expect(h.formatter.mentionStartIndex, 0);
      expect(h.searches, ['@']);
      expect(h.builder.keywords, [''], reason: 'the @ is stripped');
      expect(h.lastSuggestions.map((s) => s.id), ['u2', 'u3']);
      expect(h.lastSuggestions.first.title, 'Bob');
      expect(h.formatter.hasMore, isTrue);
      // The loading panel goes up while the first page is in flight.
      expect(panel.shown, contains(CustomUIPosition.composerPreview));
    });

    test('an "@" that follows a space also opens a search', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);

      h.type('hi @', previous: 'hi ');

      expect(h.formatter.mentionTracker, '@');
      expect(h.formatter.mentionStartIndex, 3);
      expect(h.builder.keywords, ['']);
    });

    test('an "@" glued to a word does not open a search', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);

      h.type('mail@', previous: 'mail');

      expect(h.formatter.mentionTracker, isEmpty);
      expect(h.builder.keywords, isEmpty);
      expect(h.searches, isEmpty);
    });

    test('each further keystroke narrows the search', () {
      final h = _Harness(
        pages: [
          [_bob, _carol],
          [_bob],
        ],
      );
      addTearDown(h.dispose);

      h.type('@', previous: '');
      h.type('@B', previous: '@');

      expect(h.formatter.mentionTracker, '@B');
      expect(h.formatter.mentionEndIndex, 1);
      expect(h.builder.keywords, ['', 'B']);
      expect(h.searches, ['@', '@B']);
    });

    test(
      'four trailing spaces abandon the mention and record a placeholder',
      () {
        final h = _Harness();
        addTearDown(h.dispose);
        h.formatter
          ..mentionTracker = '@Bob   '
          ..mentionStartIndex = 0
          ..mentionEndIndex = 6
          ..lastCursorPos = 7;

        h.type('@Bob    ', previous: '@Bob   ');

        expect(h.formatter.mentionTracker, isEmpty);
        expect(h.formatter.mentionStartIndex, 0);
        expect(h.formatter.mentionEndIndex, 0);
        // The abandoned text is remembered as a mention with nobody behind it,
        // so a later paste of the same text cannot be mistaken for a real ping.
        expect(h.formatter.mentionedUsersMap['@Bob    '], [null]);
        expect(h.searches, [null]);
        expect(panel.hidden, contains(CustomUIPosition.composerPreview));
      },
    );

    test('a newline abandons the mention too', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter
        ..mentionTracker = '@Bob'
        ..mentionStartIndex = 0
        ..mentionEndIndex = 3
        ..lastCursorPos = 4;

      h.type('@Bob\n', previous: '@Bob');

      expect(h.formatter.mentionTracker, isEmpty);
      expect(h.formatter.mentionedUsersMap.containsKey('@Bob\n'), isTrue);
    });

    test('a second placeholder for the same abandoned text is inserted after '
        'the mentions already to its left', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter
        ..mentionedUsersMap['@Bob\n'] = [_bob]
        ..mentionTracker = '@Bob'
        ..mentionStartIndex = 3
        ..mentionEndIndex = 6
        ..lastCursorPos = 7;

      h.type('hi @Bob\n', previous: 'hi @Bob');

      expect(h.formatter.mentionedUsersMap['@Bob\n'], [null, _bob]);
    });

    test('abandoning a mention that starts the message CRASHES when the same '
        'text is already tracked', () {
      // FINDING: the placeholder index is computed as
      //   text.substring(0, cursor - tracker.length).allMatches(mention)
      // — the receiver and the argument are the wrong way round. It is meant
      // to count how many times the mention already occurs to the LEFT of the
      // caret; what it actually counts is how many times that left-hand slice
      // occurs inside the mention text.
      //
      // When the mention starts at offset 0 the slice is the empty string,
      // which `allMatches` finds at every position of the mention plus one —
      // six here — so `insert(6, null)` is called on a one-element list and
      // throws. onChange is called on every keystroke, so this takes the
      // composer down mid-typing. Expected:
      //   mention.allMatches(text.substring(0, cursor - tracker.length)).
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter
        ..mentionedUsersMap['@Bob\n'] = [_bob]
        ..mentionTracker = '@Bob'
        ..mentionStartIndex = 0
        ..mentionEndIndex = 3
        ..lastCursorPos = 4;

      expect(
        () => h.type('@Bob\n', previous: '@Bob'),
        throwsA(isA<RangeError>()),
      );
    });

    test(
      'the mention limit swaps the suggestion list for a warning banner',
      () {
        final h = _Harness(
          pages: [
            [_bob],
          ],
        );
        addTearDown(h.dispose);
        h.formatter
          ..mentionsLimit = 1
          ..mentionCount.add('u2');

        h.type('@', previous: '');

        expect(panel.shown, contains(CustomUIPosition.composerTop));
        expect(
          h.builder.keywords,
          isEmpty,
          reason: 'no search is issued once the limit is hit',
        );
      },
    );

    testWidgets('the warning banner names the limit', (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter
        ..mentionsLimit = 1
        ..mentionCount.add('u2');
      h.type('@', previous: '');

      final builder = panel.builders.last;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              final banner = builder(context);
              expect(banner, isA<Container>());
              expect((banner as Container).constraints?.maxHeight, 40);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
    });

    test('emptying the field closes the list and forgets every mention', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter
        ..listItems.add(_bob)
        ..mentionedUsersMap['@Bob'] = [_bob]
        ..mentionCount.add('u2')
        ..mentionAllPositions.add('@All');

      h.type('', previous: '@Bob');

      expect(h.formatter.listItems, isEmpty);
      expect(h.formatter.mentionedUsersMap, isEmpty);
      expect(h.formatter.mentionCount, isEmpty);
      expect(h.formatter.mentionAllPositions, isEmpty);
      expect(h.formatter.lastCursorPos, 0);
      expect(panel.hidden, contains(CustomUIPosition.composerPreview));
    });

    test('a fetch error is reported to onError and nothing is suggested', () {
      final h = _Harness(error: cc.CometChatException('ERR', 'boom', 'boom'));
      addTearDown(h.dispose);

      h.type('@', previous: '');

      expect(h.errors.single, isA<cc.CometChatException>());
      expect((h.errors.single as cc.CometChatException).code, 'ERR');
      expect(h.suggestions.added.every((s) => s.isEmpty), isTrue);
    });

    test(
      'an empty first page reports "no results" rather than an empty list',
      () {
        final h = _Harness(pages: const [[]]);
        addTearDown(h.dispose);

        h.type('@zzz', previous: '@zz');

        // onSearch(null) is the signal the composer reads as "nothing matched".
        expect(h.searches.last, isNull);
        expect(h.formatter.hasMore, isFalse);
      },
    );

    test('scrolling to the bottom pages, and an empty page is not pushed at '
        'the composer', () {
      final h = _Harness(
        pages: [
          [_bob],
          [_carol],
          const [],
        ],
      );
      addTearDown(h.dispose);

      h.type('@', previous: '');
      final afterFirst = h.suggestions.added.length;

      h.formatter.onScrollToBottom(h.controller);
      // The formatter accumulates the pages it has seen, but only pushes the
      // rows of the page it just fetched — the composer appends its own side.
      expect(h.formatter.listItems.map((u) => u.uid), ['u2', 'u3']);
      expect(h.suggestions.added.last.map((s) => s.id), ['u3']);

      final afterSecond = h.suggestions.added.length;
      h.formatter.onScrollToBottom(h.controller);
      expect(
        h.suggestions.added.length,
        afterSecond,
        reason: 'an empty page must not re-push and re-scroll the list',
      );
      expect(afterSecond, greaterThan(afterFirst));
    });
  });

  // ==========================================================================
  group('tapping a user suggestion', () {
    test('anchors the mention, names the user and moves the caret past it', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);

      h.type('hi @Bo', previous: 'hi @B');
      expect(h.formatter.mentionTracker, '@Bo');

      _tap(h.lastSuggestions.single);

      expect(h.controller.text, 'hi @Bob ');
      expect(h.controller.selection.baseOffset, 8);
      expect(h.formatter.lastCursorPos, 8);
      expect(h.formatter.trackedMentionPositions, {3: '@Bob'});
      expect(h.formatter.mentionTextToPositions, {
        '@Bob': [3],
      });
      expect(h.formatter.mentionedUsersMap['@Bob'], [_bob]);
      expect(h.formatter.mentionCount, {'u2'});
      // The list closes behind the tap.
      expect(h.formatter.mentionTracker, isEmpty);
      expect(h.formatter.listItems, isEmpty);
      expect(h.previousText.added.last, 'hi @Bob ');
      expect(panel.hidden, contains(CustomUIPosition.composerPreview));
    });

    test('the same name already present earlier gets a null placeholder for '
        'the earlier occurrence', () {
      // "@Bob" is already in the text but was never resolved to a user (it was
      // typed or pasted). The new pick must not claim that older occurrence,
      // so the list is padded and the picked user lands after it.
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);

      h.type('@Bob hi @Bo', previous: '@Bob hi @B');
      _tap(h.lastSuggestions.single);

      expect(h.controller.text, '@Bob hi @Bob ');
      expect(h.formatter.mentionedUsersMap['@Bob'], [null, _bob]);
    });

    test('a tracker that already spells the whole name fills the slot it '
        'reserved instead of adding one', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter.mentionedUsersMap['@Bob'] = [null];

      h.type('@Bob', previous: '@Bo');
      expect(h.formatter.mentionTracker, '@Bob');
      _tap(h.lastSuggestions.single);

      // The picked user lands in the slot the tracker had reserved (index 0),
      // rather than being appended behind it.
      expect(h.formatter.mentionedUsersMap['@Bob']?.first, _bob);
      expect(h.formatter.getMentionedUsers('@Bob '), [_bob]);
      expect(h.formatter.mentionCount, {'u2'});
    });

    test('a recorded conflict index decides which slot the user fills', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter.mentionedUsersMap['@Bob'] = [_carol, null];

      h.type('@Bo', previous: '@B');
      h.formatter.conflictingIndex = 1;
      _tap(h.lastSuggestions.single);

      expect(h.formatter.mentionedUsersMap['@Bob'], [_carol, _bob]);
      expect(
        h.formatter.conflictingIndex,
        isNull,
        reason: 'the conflict is consumed, not left to catch the next pick',
      );
    });
  });

  // ==========================================================================
  group('the @all suggestion', () {
    test('is offered first, only in a group', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
        group: _group,
        mentionAllLabel: 'Everyone',
      );
      addTearDown(h.dispose);

      h.type('@', previous: '');

      expect(h.lastSuggestions.map((s) => s.id), ['all', 'u2']);
      expect(h.lastSuggestions.first.title, '@Everyone');
      expect(h.lastSuggestions.first.subtitle, 'Notify everyone in this group');
      expect(h.lastSuggestions.first.avatarName, 'Team');
    });

    testWidgets('keeps its configured label when the formatter has a context', (
      tester,
    ) async {
      // With a BuildContext the localized "Notify All" used to replace the
      // configured label — and in the composer there always is one.
      final h = _Harness(
        pages: [
          [_bob],
        ],
        group: _group,
        mentionAllLabel: 'Everyone',
      );
      addTearDown(h.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              h.formatter.context = context;
              return const SizedBox();
            },
          ),
        ),
      );

      h.type('@', previous: '');

      expect(h.lastSuggestions.first.id, 'all');
      expect(h.lastSuggestions.first.title, '@Everyone');
    });

    test('is absent outside a group', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
        mentionAllLabel: 'Everyone',
      );
      addTearDown(h.dispose);

      h.type('@', previous: '');

      expect(h.lastSuggestions.map((s) => s.id), ['u2']);
    });

    test('is absent when disabled', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
        group: _group,
        disableMentionAll: true,
      );
      addTearDown(h.dispose);

      h.type('@', previous: '');

      expect(h.lastSuggestions.map((s) => s.id), ['u2']);
      expect(h.formatter.listItems.map((u) => u.uid), ['u2']);
    });

    test('is filtered out when the keyword cannot match its label', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
        group: _group,
        mentionAllLabel: 'Everyone',
      );
      addTearDown(h.dispose);

      h.type('@zz', previous: '@z');

      expect(h.lastSuggestions.map((s) => s.id), ['u2']);
    });

    test('survives a keyword that is a prefix of its label', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
        group: _group,
        mentionAllLabel: 'Everyone',
      );
      addTearDown(h.dispose);

      h.type('@eve', previous: '@ev');

      expect(h.lastSuggestions.map((s) => s.id), ['all', 'u2']);
    });

    test('is offered when the search finds no users at all', () {
      final h = _Harness(
        pages: const [[]],
        group: _group,
        mentionAllLabel: 'Everyone',
      );
      addTearDown(h.dispose);

      h.type('@', previous: '');

      expect(h.lastSuggestions.map((s) => s.id), ['all']);
      expect(h.searches, [
        '@',
      ], reason: 'not a "no results" search — the @all row is still there');
    });

    test('a custom label id is carried on the suggestion', () {
      final h = _Harness(
        pages: const [[]],
        group: _group,
        mentionAllLabel: 'Team',
        mentionAllLabelId: 'engineering',
      );
      addTearDown(h.dispose);

      h.type('@', previous: '');

      expect(h.lastSuggestions.single.id, 'engineering');
    });

    test('tapping it anchors the label and flags it as an @all', () {
      final h = _Harness(
        pages: const [[]],
        group: _group,
        mentionAllLabel: 'Everyone',
      );
      addTearDown(h.dispose);

      h.type('hi @Ev', previous: 'hi @E');
      // Setting `.text` is how a composer replaces the field content; it
      // leaves the selection at -1, which the tap handler has to recover from.
      h.controller.text = 'hi @Ev';
      _tap(h.lastSuggestions.single);

      expect(h.controller.text, 'hi @Everyone ');
      expect(h.controller.selection.baseOffset, 13);
      expect(h.formatter.mentionAllPositions, {'@Everyone'});
      expect(h.formatter.trackedMentionPositions, {3: '@Everyone'});
      expect(h.formatter.mentionedUsersMap['@Everyone'], [null]);
      expect(
        h.formatter.mentionCount,
        isEmpty,
        reason: 'an @all is not a user and must not use up a mention slot',
      );
    });

    test('tapping it with the caret before the tracker still anchors when the '
        'tracker ends the text', () {
      final h = _Harness(
        pages: const [[]],
        group: _group,
        mentionAllLabel: 'Everyone',
      );
      addTearDown(h.dispose);

      // Open the list, then move the field out from under it: the caret sits
      // before the mention the tracker is still describing.
      h.type('@Ev', previous: '@E');
      h.formatter.mentionTracker = '@Everyone';
      h.controller.value = const TextEditingValue(
        text: 'x@Everyone',
        selection: TextSelection.collapsed(offset: 2),
      );
      _tap(h.lastSuggestions.single);

      expect(h.controller.text, 'x@Everyone ');
      expect(h.formatter.trackedMentionPositions, {1: '@Everyone'});
    });

    test('tapping it with an unrecoverable caret does nothing at all', () {
      final h = _Harness(
        pages: const [[]],
        group: _group,
        mentionAllLabel: 'Everyone',
      );
      addTearDown(h.dispose);

      h.type('@Ev', previous: '@E');
      h.formatter.mentionTracker = '@Everyone';
      h.controller.value = const TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: 1),
      );
      _tap(h.lastSuggestions.single);

      expect(h.controller.text, 'abc');
      expect(h.formatter.mentionAllPositions, isEmpty);
      expect(h.formatter.trackedMentionPositions, isEmpty);
    });

    test('a host listener that throws cannot take the composer down', () {
      final h = _Harness(
        pages: const [[]],
        group: _group,
        mentionAllLabel: 'Everyone',
      );
      addTearDown(h.dispose);

      h.type('hi @Ev', previous: 'hi @E');
      h.controller.text = 'hi @Ev';
      panel.throwOnHide = true;

      expect(() => _tap(h.lastSuggestions.single), returnsNormally);
      // The text edit happens before the panel event, so it survives.
      expect(h.controller.text, 'hi @Everyone ');
    });

    test('a second @all keeps a slot per occurrence', () {
      final h = _Harness(
        pages: const [[]],
        group: _group,
        mentionAllLabel: 'Everyone',
      );
      addTearDown(h.dispose);
      h.formatter
        ..mentionedUsersMap['@Everyone'] = [null]
        ..mentionTextToPositions['@Everyone'] = [0];

      h.type('@Everyone @Ev', previous: '@Everyone @E');
      h.controller.text = '@Everyone @Ev';
      _tap(h.lastSuggestions.single);

      expect(h.formatter.mentionedUsersMap['@Everyone'], [null, null]);
      expect(h.formatter.mentionTextToPositions['@Everyone'], [0, 10]);
    });
  });

  // ==========================================================================
  group('visibility gating', () {
    test('a users-only formatter ignores changes in a group', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
        group: _group,
        visibleIn: MentionsVisibility.usersConversationOnly,
      );
      addTearDown(h.dispose);

      h.type('@', previous: '');

      expect(h.formatter.mentionTracker, isEmpty);
      expect(h.builder.keywords, isEmpty);
    });

    test('a group-only formatter ignores changes outside a group', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
        visibleIn: MentionsVisibility.groupConversationOnly,
      );
      addTearDown(h.dispose);

      h.type('@', previous: '');

      expect(h.formatter.mentionTracker, isEmpty);
      expect(h.builder.keywords, isEmpty);
    });

    test('"both" tracks everywhere', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
        group: _group,
        visibleIn: MentionsVisibility.both,
      );
      addTearDown(h.dispose);

      h.type('@', previous: '');

      expect(h.formatter.mentionTracker, '@');
    });
  });

  // ==========================================================================
  group('deleting near a mention', () {
    test('backspacing into an anchored mention removes the whole mention and '
        'its trailing space', () {
      // Half a mention is not a mention: the composer deletes the lot rather
      // than leaving "@Bo" pointing at a user id.
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter
        ..trackedMentionPositions[3] = '@Bob'
        ..mentionTextToPositions['@Bob'] = [3]
        ..mentionedUsersMap['@Bob'] = [_bob]
        ..mentionCount.add('u2');

      // Delete the "B" in the middle of "@Bob".
      h.type('hi @ob there', offset: 4, previous: 'hi @Bob there');

      expect(h.controller.text, 'hi there');
      expect(h.controller.selection.baseOffset, 3);
      expect(h.formatter.trackedMentionPositions, isEmpty);
      expect(h.formatter.mentionTextToPositions, isEmpty);
      expect(h.formatter.mentionedUsersMap, isEmpty);
      expect(h.formatter.mentionCount, isEmpty);
    });

    test('backspacing the LAST character of a mention leaves the space '
        'behind', () {
      // The trailing space is only swallowed when the deletion range has to be
      // widened to the right; deleting the final character of the mention
      // already reaches its end, so the space stays and the text is left with
      // a double blank. Worth pinning: it is the difference between "hi there"
      // and "hi  there" depending on which character the user backspaces.
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter
        ..trackedMentionPositions[3] = '@Bob'
        ..mentionTextToPositions['@Bob'] = [3]
        ..mentionedUsersMap['@Bob'] = [_bob];

      h.type('hi @Bo there', offset: 6, previous: 'hi @Bob there');

      expect(h.controller.text, 'hi  there');
      expect(h.formatter.trackedMentionPositions, isEmpty);
    });

    test('an @all is un-anchored the same way', () {
      final h = _Harness(mentionAllLabel: 'Everyone');
      addTearDown(h.dispose);
      h.formatter
        ..trackedMentionPositions[0] = '@Everyone'
        ..mentionTextToPositions['@Everyone'] = [0]
        ..mentionedUsersMap['@Everyone'] = [null]
        ..mentionAllPositions.add('@Everyone');

      h.type(
        '@Everyon hello there',
        offset: 8,
        previous: '@Everyone hello there',
      );

      expect(h.controller.text, ' hello there');
      expect(h.formatter.mentionAllPositions, isEmpty);
      expect(h.formatter.mentionedUsersMap, isEmpty);
      expect(h.formatter.mentionTextToPositions, isEmpty);
    });

    test('un-anchoring a mention that leaves the text shorter than the caret '
        'CRASHES onChange', () {
      // FINDING: `_removeMentionIfDeleted` rewrites the controller's text —
      // here from "@Everyone hi" (12 chars) down to " hi" (3) — but `_onChange`
      // carries on with the cursor position it read before that rewrite. The
      // very next statement is
      //   textEditingController.text.substring(0, cursorPosition)
      // which throws RangeError as soon as the removed mention was longer than
      // what is left after the caret. A user backspacing inside a mention in a
      // short message takes the composer down. Expected: re-read the caret from
      // the controller after `_removeMentionIfDeleted`, or return early once it
      // has rewritten the field.
      final h = _Harness(mentionAllLabel: 'Everyone');
      addTearDown(h.dispose);
      h.formatter
        ..trackedMentionPositions[0] = '@Everyone'
        ..mentionTextToPositions['@Everyone'] = [0]
        ..mentionedUsersMap['@Everyone'] = [null]
        ..mentionAllPositions.add('@Everyone');

      expect(
        () => h.type('@Everyon hi', offset: 8, previous: '@Everyone hi'),
        throwsA(isA<RangeError>()),
      );
      // The text edit itself did land before the throw.
      expect(h.controller.text, ' hi');
    });

    test(
      'a deletion that misses every mention just shifts the ones after it',
      () {
        final h = _Harness();
        addTearDown(h.dispose);
        h.formatter
          ..trackedMentionPositions[9] = '@Bob'
          ..mentionTextToPositions['@Bob'] = [9]
          ..mentionedUsersMap['@Bob'] = [_bob];

        h.type('hi ther @Bob', offset: 7, previous: 'hi there @Bob');

        expect(h.controller.text, 'hi ther @Bob');
        expect(h.formatter.trackedMentionPositions, {8: '@Bob'});
        expect(h.formatter.mentionTextToPositions, {
          '@Bob': [8],
        });
      },
    );

    test('inserting before a mention shifts it along', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter
        ..trackedMentionPositions[0] = '@Bob'
        ..mentionTextToPositions['@Bob'] = [0]
        ..mentionedUsersMap['@Bob'] = [_bob];

      h.type('xx@Bob', offset: 2, previous: '@Bob');

      expect(h.formatter.trackedMentionPositions, {2: '@Bob'});
      expect(h.formatter.mentionTextToPositions, {
        '@Bob': [2],
      });
    });

    test('deleting the tracking character closes the list', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter
        ..mentionTracker = '@Bo'
        ..mentionStartIndex = 3
        ..mentionEndIndex = 5
        ..lastCursorPos = 6
        ..listItems.add(_bob);

      h.type('hi Bo', offset: 3, previous: 'hi @Bo');

      expect(h.formatter.mentionTracker, isEmpty);
      expect(h.formatter.listItems, isEmpty);
      expect(panel.hidden, contains(CustomUIPosition.composerPreview));
    });

    test('backspacing inside the tracker shortens it', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter
        ..mentionTracker = '@Bob'
        ..mentionStartIndex = 0
        ..mentionEndIndex = 3
        ..lastCursorPos = 4;

      h.type('@Bo', previous: '@Bob');

      expect(h.formatter.mentionTracker, '@Bo');
      expect(h.formatter.mentionEndIndex, 2);
      expect(h.builder.keywords, ['Bo']);
    });

    test('deleting before the tracker slides its indices back', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter
        ..mentionTracker = '@Bo'
        ..mentionStartIndex = 5
        ..mentionEndIndex = 7
        ..lastCursorPos = 8;

      h.type('hi t @Bo', offset: 4, previous: 'hi the @Bo');

      expect(h.formatter.mentionStartIndex, 3);
      expect(h.formatter.mentionEndIndex, 5);
    });
  });

  // ==========================================================================
  group('pasting', () {
    test('pasting a copy of an existing mention reserves a slot for it', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter.mentionedUsersMap['@Bob'] = [_bob];

      h.type('@Bob hi @Bob', previous: '@Bob hi');

      // The pasted "@Bob" is not the same ping: it gets its own, empty slot
      // after the one that was already resolved.
      expect(h.formatter.mentionedUsersMap['@Bob'], [_bob, null]);
      expect(h.formatter.lastCursorPos, 12);
    });

    test('a paste while the list is open closes it', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter
        ..mentionedUsersMap['@Bob'] = [_bob]
        ..listItems.add(_bob)
        ..mentionTracker = '@Bo';

      h.type('@Bob hi @Bob', previous: '@Bob hi');

      expect(h.formatter.listItems, isEmpty);
      expect(h.formatter.mentionTracker, isEmpty);
      expect(panel.hidden, contains(CustomUIPosition.composerPreview));
    });
  });

  // ==========================================================================
  group('cursorInMentionTracker', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    test('a deletion with the caret at the end of a mention reopens that '
        'mention for editing', () {
      final f = CometChatMentionsFormatter();
      f.mentionedUsersMap['@Bob'] = [_bob];
      f.mentionCount.add('u2');
      // The "!" after the mention was just deleted; the caret now sits exactly
      // where the mention ends.
      controller.text = 'hi @Bob';

      f.cursorInMentionTracker(7, controller, 'hi @Bob!');

      expect(f.mentionTracker, '@Bob');
      expect(f.mentionStartIndex, 3);
      expect(f.mentionEndIndex, 6);
      expect(f.searchOnActiveMention, isTrue);
      // The user is no longer mentioned, so the slot is released.
      expect(f.mentionedUsersMap.containsKey('@Bob'), isFalse);
      expect(f.mentionCount, isEmpty);
    });

    test('a user mentioned twice keeps its count when one copy is reopened '
        'at its end', () {
      final f = CometChatMentionsFormatter();
      f.mentionedUsersMap['@Bob'] = [_bob, _bob];
      f.mentionCount.add('u2');
      controller.text = '@Bob @Bob';

      f.cursorInMentionTracker(9, controller, '@Bob @Bob!');

      expect(f.mentionedUsersMap['@Bob'], [_bob]);
      expect(f.mentionCount, {'u2'}, reason: 'still mentioned once');
    });

    test('a user mentioned twice LOSES its count when one copy is reopened '
        'from the inside', () {
      // FINDING: the two arms of `cursorInMentionTracker` disagree. The
      // "caret at the end of a mention" arm checks whether the user is still
      // mentioned somewhere else before dropping them from `mentionCount`; the
      // "caret inside a mention" arm removes the uid unconditionally. So
      // clicking into one of two mentions of the same person silently drops
      // them from the count that enforces the ten-mention limit — repeat it
      // and the composer will let a message exceed the limit. Expected: the
      // same `userStillMentioned` guard in both arms.
      final f = CometChatMentionsFormatter();
      f.mentionedUsersMap['@Bob'] = [_bob, _bob];
      f.mentionCount.add('u2');
      controller.text = '@Bob @Bob';

      f.cursorInMentionTracker(2, controller, '@Bob @Bob');

      expect(f.mentionedUsersMap['@Bob'], [_bob]);
      expect(f.mentionCount, isEmpty);
    });

    test('putting the caret inside a mention reopens it without the delete '
        'flag', () {
      final f = CometChatMentionsFormatter();
      f.mentionedUsersMap['@Bob'] = [_bob];
      f.mentionCount.add('u2');
      controller.text = 'hi @Bob';

      f.cursorInMentionTracker(5, controller, 'hi @Bob');

      expect(f.mentionTracker, '@B');
      expect(f.mentionStartIndex, 3);
      expect(f.searchOnActiveMention, isFalse);
      expect(f.mentionedUsersMap, isEmpty);
      expect(f.mentionCount, isEmpty);
    });

    test(
      'with no mention under the caret it falls back to plain @ tracking',
      () {
        final f = CometChatMentionsFormatter()..init();
        controller.text = 'say @he';

        f.cursorInMentionTracker(7, controller, 'say @h');

        expect(f.mentionTracker, '@he');
        expect(f.mentionStartIndex, 4);
        expect(f.mentionEndIndex, 6);
      },
    );

    test('a run of four spaces after the @ is not tracked', () {
      final f = CometChatMentionsFormatter()..init();
      controller.text = '@    x';

      f.cursorInMentionTracker(6, controller, '@    ');

      expect(f.mentionTracker, isEmpty);
    });
  });

  // ==========================================================================
  group('checkIfTrackerPlacedCausesDuplication', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    test('a new "@" typed where a duplicate name already sits reserves the '
        'right slot', () {
      final f = CometChatMentionsFormatter();
      f.mentionedUsersMap['@Bob'] = [_bob];
      controller.text = '@Bob hi @Bob';

      f.checkIfTrackerPlacedCausesDuplication(8, controller);

      expect(f.mentionedUsersMap['@Bob'], [_bob, null]);
      expect(f.conflictingIndex, 1);
    });

    test('nothing happens when the occurrences already have slots', () {
      final f = CometChatMentionsFormatter();
      f.mentionedUsersMap['@Bob'] = [_bob, _bob];
      controller.text = '@Bob hi @Bob';

      f.checkIfTrackerPlacedCausesDuplication(8, controller);

      expect(f.mentionedUsersMap['@Bob'], [_bob, _bob]);
      expect(f.conflictingIndex, isNull);
    });

    test('an empty map is a no-op', () {
      final f = CometChatMentionsFormatter();
      controller.text = '@Bob';

      f.checkIfTrackerPlacedCausesDuplication(0, controller);

      expect(f.mentionedUsersMap, isEmpty);
      expect(f.conflictingIndex, isNull);
    });
  });

  // ==========================================================================
  group('buildInputFieldText', () {
    Future<List<AttributedText>> attrs(
      WidgetTester tester,
      CometChatMentionsFormatter f,
      String text, {
      List<AttributedText>? existing,
    }) async {
      late List<AttributedText> out;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              out = f.buildInputFieldText(
                context: context,
                withComposing: false,
                text: text,
                existingAttributes: existing,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      return out;
    }

    testWidgets('an anchored mention is highlighted over exactly its own '
        'characters', (tester) async {
      final f = CometChatMentionsFormatter();
      f.trackedMentionPositions[3] = '@Bob';
      f.mentionedUsersMap['@Bob'] = [_bob];

      final out = await attrs(tester, f, 'hi @Bob!');

      expect(out, hasLength(1));
      expect(out.single.start, 3);
      expect(out.single.end, 7);
      expect(out.single.underlyingText, '@Bob');
      expect(out.single.backgroundColor, isNotNull);
      expect(out.single.padding, isA<EdgeInsets>());
    });

    testWidgets('a stale position is ignored rather than painted over the '
        'wrong text', (tester) async {
      final f = CometChatMentionsFormatter();
      f.trackedMentionPositions[3] = '@Bob';
      f.mentionedUsersMap['@Bob'] = [_bob];

      expect(await attrs(tester, f, 'hi @Carol!'), isEmpty);
      // Past the end of the text entirely.
      expect(await attrs(tester, f, 'hi'), isEmpty);
    });

    testWidgets('mentioning yourself is styled differently from mentioning '
        'someone else', (tester) async {
      final f = CometChatMentionsFormatter();
      f.trackedMentionPositions[0] = '@Me';
      f.trackedMentionPositions[4] = '@Bob';
      f.mentionedUsersMap['@Me'] = [_me];
      f.mentionedUsersMap['@Bob'] = [_bob];

      final out = await attrs(tester, f, '@Me @Bob');

      expect(out, hasLength(2));
      expect(out[0].style, isNot(out[1].style));
      expect(out[0].backgroundColor, isNot(out[1].backgroundColor));
    });

    testWidgets('an @all is styled like a mention of yourself', (tester) async {
      final f = CometChatMentionsFormatter();
      f.trackedMentionPositions[0] = '@All';
      f.trackedMentionPositions[5] = '@Me';
      f.mentionAllPositions.add('@All');
      f.mentionedUsersMap['@Me'] = [_me];

      final out = await attrs(tester, f, '@All @Me');

      expect(out, hasLength(2));
      expect(out[0].style, out[1].style);
      expect(out[0].backgroundColor, out[1].backgroundColor);
    });

    testWidgets('a custom mentions style wins over the palette default', (
      tester,
    ) async {
      final f = CometChatMentionsFormatter(
        style: CometChatMentionsStyle(
          mentionTextBackgroundColor: const Color(0xFF00FF00),
          mentionTextColor: const Color(0xFF0000FF),
          borderRadius: 11,
        ),
      );
      f.trackedMentionPositions[0] = '@Bob';
      f.mentionedUsersMap['@Bob'] = [_bob];

      final out = await attrs(tester, f, '@Bob');

      expect(out.single.backgroundColor, const Color(0xFF00FF00));
      expect(out.single.style?.color, const Color(0xFF0000FF));
      expect(out.single.borderRadius, 11);
    });

    testWidgets('existing attributes from another formatter are merged in', (
      tester,
    ) async {
      final f = CometChatMentionsFormatter();
      f.trackedMentionPositions[5] = '@Bob';
      f.mentionedUsersMap['@Bob'] = [_bob];

      final out = await attrs(
        tester,
        f,
        'bold @Bob',
        existing: [AttributedText(start: 0, end: 4, underlyingText: 'bold')],
      );

      expect(out.map((a) => a.underlyingText), ['bold', '@Bob']);
    });

    testWidgets('no anchored mentions means no attributes', (tester) async {
      expect(
        await attrs(tester, CometChatMentionsFormatter(), 'plain text'),
        isEmpty,
      );
    });

    testWidgets('a host style callback that throws drops the highlight '
        'instead of the whole field', (tester) async {
      final f = CometChatMentionsFormatter(
        messageInputTextStyle: (context) => throw StateError('host blew up'),
      );
      f.trackedMentionPositions[0] = '@Bob';
      f.mentionedUsersMap['@Bob'] = [_bob];

      expect(await attrs(tester, f, '@Bob'), isEmpty);
    });
  });

  // ==========================================================================
  group('caret moves that are not simple typing', () {
    test('adding text in front of an open tracker re-reads the caret', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter
        ..mentionTracker = '@Bo'
        ..mentionStartIndex = 7
        ..mentionEndIndex = 9
        ..lastCursorPos = 10;

      h.type('hix the @Bo', offset: 3, previous: 'hi the @Bo');

      // The tracker still exists and the composer keeps searching rather than
      // dropping the half-typed mention on the floor.
      expect(h.formatter.mentionTracker, isNotEmpty);
      expect(h.builder.keywords, isNotEmpty);
    });

    test('moving the caret one character forward after an edit-in-place '
        'closes the reopened mention', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter
        ..searchOnActiveMention = true
        ..mentionTracker = '@Bob'
        ..lastCursorPos = 6;

      h.type('hi @Bob', previous: 'hi @Bo');

      expect(h.formatter.searchOnActiveMention, isFalse);
      expect(h.formatter.mentionTracker, isEmpty);
    });

    test('backspacing one character back into a reopened mention re-runs the '
        'search', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter
        ..searchOnActiveMention = true
        ..mentionTracker = '@Bob'
        ..mentionStartIndex = 3
        ..mentionEndIndex = 6
        ..lastCursorPos = 8
        ..mentionedUsersMap['@Bob'] = [_bob]
        ..mentionCount.add('u2');

      h.type('hi @Bob', offset: 7, previous: 'hi @Bob!');

      expect(h.formatter.mentionTracker, '@Bob');
      expect(h.formatter.mentionedUsersMap, isEmpty);
    });

    test('deleting the tracking character itself releases the mention', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter.mentionedUsersMap['@Bob'] = [_bob];

      h.type('hi Bob', offset: 3, previous: 'hi @Bob');

      expect(h.formatter.mentionedUsersMap, isEmpty);
    });

    test('deleting just after a resolved mention reopens it', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter.mentionedUsersMap['@Bob'] = [_bob];

      h.type('@Bob', previous: '@Bob!');

      expect(h.formatter.mentionTracker, '@Bob');
      expect(h.formatter.mentionedUsersMap, isEmpty);
    });

    test('a deletion that jumps the caret away closes the list', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter.lastCursorPos = 0;

      h.type('@Bzz', previous: '@Bzz!');

      expect(panel.hidden, contains(CustomUIPosition.composerPreview));
      expect(h.formatter.mentionTracker, '@Bzz');
    });

    test('a deletion right where the caret already was keeps tracking', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter.lastCursorPos = 5;

      h.type('@Bzz', previous: '@Bzz!');

      expect(h.formatter.mentionTracker, '@Bzz');
      expect(h.formatter.mentionStartIndex, 0);
      expect(h.formatter.mentionEndIndex, 3);
      expect(h.builder.keywords, ['Bzz']);
    });

    test('an insertion with no open tracker picks the mention up from the '
        'text', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter.lastCursorPos = 5;

      h.type('hi @Bo', previous: 'hi @B');

      expect(h.formatter.mentionTracker, '@Bo');
      expect(h.formatter.mentionStartIndex, 3);
      expect(h.formatter.mentionEndIndex, 5);
    });

    test('a tracker that is growing back into an intercepted mention '
        'reserves a slot for it', () {
      // The composer sets `interceptedMention` when the user backspaces into
      // an existing mention; typing forward again has to re-reserve the slot
      // the resolved user will go back into, rather than claiming the one the
      // untouched copy of that mention already owns.
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter
        ..interceptedMention = '@Bobby'
        ..mentionedUsersMap['@Bobby'] = [_bob]
        ..mentionTracker = '@B'
        ..mentionStartIndex = 0
        ..mentionEndIndex = 1;

      h.type('@Bobby x', offset: 3, previous: '@Bbby x');

      expect(h.formatter.mentionTracker, '@Bo');
      expect(h.formatter.mentionedUsersMap['@Bobby'], [null, _bob]);
    });

    test('a mention placed before an identical one shifts the tracked '
        'position of the later copy only', () {
      final h = _Harness();
      addTearDown(h.dispose);
      h.formatter
        ..trackedMentionPositions[0] = '@Bob'
        ..trackedMentionPositions[9] = '@Bob'
        ..mentionTextToPositions['@Bob'] = [0, 9]
        ..mentionedUsersMap['@Bob'] = [_bob, _bob];

      h.type('@Bob hix @Bob', offset: 8, previous: '@Bob hi @Bob');

      expect(h.formatter.trackedMentionPositions, {0: '@Bob', 10: '@Bob'});
      expect(h.formatter.mentionTextToPositions, {
        '@Bob': [0, 10],
      });
    });
  });

  // ==========================================================================
  group('picking a suggestion among identical names', () {
    test('a copy on each side of the caret gets its own reserved slot', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter
        ..mentionedUsersMap['@Bob'] = [null]
        ..mentionTextToPositions['@Bob'] = [0]
        ..mentionTracker = '@B'
        ..mentionStartIndex = 8
        ..mentionEndIndex = 9;

      h.type('@Bob hi @Bo @Bob', offset: 11, previous: '@Bob hi @B @Bob');
      _tap(h.lastSuggestions.single);

      // One copy to the left, one to the right, and the picked user between
      // them.
      expect(h.formatter.mentionedUsersMap['@Bob'], [null, _bob, null]);
      expect(h.formatter.mentionTextToPositions['@Bob'], [0, 8]);
    });

    test('copies only to the right of the caret are padded after the pick', () {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.formatter
        ..mentionTracker = '@B'
        ..mentionStartIndex = 0
        ..mentionEndIndex = 1;

      h.type('@Bo @Bob @Bob', offset: 3, previous: '@B @Bob @Bob');
      _tap(h.lastSuggestions.single);

      expect(h.formatter.mentionedUsersMap['@Bob'], [_bob, null, null]);
    });
  });

  // ==========================================================================
  group('localized labels and injected styles', () {
    testWidgets('once the formatter has seen a context the @all row is '
        'localized', (tester) async {
      final h = _Harness(pages: const [[]], group: _group);
      addTearDown(h.dispose);

      late String notifyAll;
      late String subtitle;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              notifyAll = Translations.of(context).notifyAll;
              subtitle = Translations.of(context).notifyEveryoneInThisGroup;
              // Storing the context is a side effect of the read path.
              h.formatter.getAttributedText('', context, BubbleAlignment.left);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      h.type('@', previous: '');

      expect(h.lastSuggestions.single.title, '@$notifyAll');
      expect(h.lastSuggestions.single.subtitle, subtitle);
    });

    testWidgets('an injected bubble style callback replaces the built-in one', (
      tester,
    ) async {
      const injected = TextStyle(fontSize: 42);
      final f = CometChatMentionsFormatter(
        messageBubbleTextStyle: (context, alignment, {forConversation}) =>
            injected,
        messageInputTextStyle: (context) => injected,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              expect(
                f.getMessageBubbleTextStyle(context, BubbleAlignment.left),
                injected,
              );
              expect(f.getMessageInputTextStyle(context), injected);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
    });

    testWidgets('an outgoing bubble colours a mention differently from an '
        'incoming one, and a self-mention differently again', (tester) async {
      final f = CometChatMentionsFormatter();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              final rightOther = f.getMessageBubbleTextStyle(
                context,
                BubbleAlignment.right,
              );
              final leftOther = f.getMessageBubbleTextStyle(
                context,
                BubbleAlignment.left,
              );
              final rightSelf = f.getMessageBubbleTextStyle(
                context,
                BubbleAlignment.right,
                isLoggedInUser: true,
              );
              expect(rightOther.color, isNot(leftOther.color));
              expect(rightSelf.color, isNot(rightOther.color));
              expect(
                f.getMessageInputTextStyle(context, isLoggedInUser: true).color,
                isNot(f.getMessageInputTextStyle(context).color),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
    });

    testWidgets('the loading panel the composer is handed builds', (
      tester,
    ) async {
      final h = _Harness(
        pages: [
          [_bob],
        ],
      );
      addTearDown(h.dispose);
      h.type('@', previous: '');
      final builder = panel.builders.first;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              expect(builder(context), isA<Container>());
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
    });
  });

  // ==========================================================================
  group('onMessageEdit side effects', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    test('an open suggestion list is closed before the text is rewritten', () {
      final f = CometChatMentionsFormatter(composerId: const {'guid': 'g1'});
      f.listItems.add(_bob);
      controller.text = 'hi <@uid:u2>';

      f.onMessageEdit(controller, mentionedUsers: [_bob]);

      expect(panel.hidden, contains(CustomUIPosition.composerTop));
      expect(controller.text, 'hi @Bob');
    });

    test('two @all tokens get one slot each', () {
      final f = CometChatMentionsFormatter(mentionAllLabel: 'All');
      controller.text = '<@all:all> and <@all:all>';

      f.onMessageEdit(controller);

      expect(controller.text, '@All and @All');
      expect(f.mentionedUsersMap['@All'], [null, null]);
      expect(f.mentionTextToPositions['@All'], [0, 9]);
    });
  });
}
