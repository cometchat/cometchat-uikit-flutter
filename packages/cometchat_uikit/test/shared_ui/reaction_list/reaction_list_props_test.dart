/// Render-verified prop matrix for [CometChatReactionList] and
/// [CometChatReactionListStyle] — Track 3 PROP1/PROP2 (ENG-38934).
///
/// The sheet is a four-state component — loading, loaded, empty, error — with
/// a tab row across the top (one tab per emoji, plus "All") and a reactor list
/// below. Each property is exercised in the state that renders it, driven
/// through the `reactionListBloc` seam.
///
///   flutter test test/shared_ui/reaction_list/reaction_list_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockReactionListBloc
    extends MockBloc<ReactionListEvent, ReactionListState>
    implements ReactionListBloc {}

final _me = User(uid: 'u1', name: 'Alice');

Reaction _reaction(String emoji, String uid, String name) => Reaction(
  id: '$uid-$emoji',
  messageId: 1,
  reaction: emoji,
  uid: uid,
  reactedAt: 1700000000,
  reactedBy: User(uid: uid, name: name),
);

TextMessage _message() => TextMessage(
  id: 1,
  text: 'hi',
  sender: _me,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
);

/// Two reactors under two emoji, so the tab row has a selected and an
/// unselected tab and the list below has rows.
final _loaded = ReactionListLoaded(
  messageReactions: {
    'all': [_reaction('👍', 'u1', 'Alice'), _reaction('🎉', 'u2', 'Bob')],
    '👍': [_reaction('👍', 'u1', 'Alice')],
    '🎉': [_reaction('🎉', 'u2', 'Bob')],
  },
  selectedReaction: 'all',
  totalReactions: 2,
  canFetchMore: false,
);

const _empty = ReactionListLoaded(
  messageReactions: {},
  selectedReaction: 'all',
  totalReactions: 0,
  canFetchMore: false,
);

const _loading = ReactionListLoading(
  messageReactions: {},
  selectedReaction: 'all',
);

final _errored = ReactionListError(
  error: CometChatException('ERR', 'boom', 'boom'),
  messageReactions: const {},
  selectedReaction: 'all',
);

MockReactionListBloc _bloc(ReactionListState state) {
  final b = MockReactionListBloc();
  whenListen(b, Stream<ReactionListState>.value(state), initialState: state);
  return b;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Iterable<double?> _textSizes(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.fontSize);

Iterable<Color?> _textColors(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color);

Iterable<Color?> _boxColors(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.color ?? (c.decoration as BoxDecoration?)?.color);

Iterable<BoxBorder?> _boxBorders(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.border);

Iterable<BorderRadiusGeometry?> _boxRadii(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.borderRadius);

void main() {
  // The "tap to remove" subtitle only renders on the row for the logged-in
  // user's own reaction, which is decided by this static.
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  group('the sheet', () {
    testWidgets('backgroundColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                backgroundColor: const Color(0xFF1C0101),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_boxColors(tester), contains(const Color(0xFF1C0101)));
    });

    testWidgets('border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                border: const Border.fromBorderSide(
                  BorderSide(color: Color(0xFF1C0202), width: 3),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _boxBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF1C0202), width: 3),
          ),
        ),
      );
    });

    testWidgets('borderRadius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                borderRadius: const BorderRadius.all(Radius.circular(59)),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _boxRadii(tester),
        contains(const BorderRadius.all(Radius.circular(59))),
      );
    });
  });

  group('the emoji tab row', () {
    testWidgets('tabTextStyle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                tabTextStyle: const TextStyle(fontSize: 31),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(31.0));
    });

    testWidgets('tabTextColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                tabTextColor: const Color(0xFF1C0303),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      // the unselected tabs take tabTextColor
      expect(_textColors(tester), contains(const Color(0xFF1C0303)));
    });

    testWidgets('activeTabTextColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                activeTabTextColor: const Color(0xFF1C0404),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textColors(tester), contains(const Color(0xFF1C0404)));
    });

    testWidgets('activeTabBackgroundColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                activeTabBackgroundColor: const Color(0xFF1C0505),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_boxColors(tester), contains(const Color(0xFF1C0505)));
    });

    testWidgets('activeTabIndicatorColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                activeTabIndicatorColor: const Color(0xFF1C0606),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      // the indicator is a bottom BorderSide under the selected tab, not a fill
      expect(
        _boxBorders(tester).whereType<Border>().map((b) => b.bottom.color),
        contains(const Color(0xFF1C0606)),
      );
    });
  });

  group('the reactor rows', () {
    testWidgets('titleTextStyle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                titleTextStyle: const TextStyle(fontSize: 27),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(27.0));
    });

    testWidgets('titleTextColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                titleTextColor: const Color(0xFF1C0707),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textColors(tester), contains(const Color(0xFF1C0707)));
    });

    testWidgets('subtitleTextStyle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                subtitleTextStyle: const TextStyle(fontSize: 17),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(17.0));
    });

    testWidgets('subtitleTextColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                subtitleTextColor: const Color(0xFF1C0808),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textColors(tester), contains(const Color(0xFF1C0808)));
    });

    testWidgets('tailViewTextStyle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                tailViewTextStyle: const TextStyle(fontSize: 19),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(19.0));
    });
  });

  group('reactor avatars', () {
    Iterable<Color?> avatarFills(WidgetTester tester) => tester
        .widgetList<CometChatAvatar>(find.byType(CometChatAvatar))
        .map((a) => a.style?.backgroundColor);

    testWidgets('style avatarStyle reaches every reactor avatar — the route '
        'CometChatMessageList takes through reactionListStyle', (tester) async {
      const fill = Color(0xFF1A0A0A);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              key: const ValueKey('unstyled'),
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(avatarFills(tester), isNot(contains(fill)));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              key: const ValueKey('styled'),
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                avatarStyle: const CometChatAvatarStyle(backgroundColor: fill),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(avatarFills(tester), isNotEmpty);
      expect(avatarFills(tester), everyElement(fill));
    });

    testWidgets('avatarStyle on the list wins over the style', (tester) async {
      const fromStyle = Color(0xFF1A0A0A);
      const fromWidget = Color(0xFF0A1A0A);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                avatarStyle: const CometChatAvatarStyle(
                  backgroundColor: fromStyle,
                ),
              ),
              avatarStyle: const CometChatAvatarStyle(
                backgroundColor: fromWidget,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(avatarFills(tester), isNotEmpty);
      expect(avatarFills(tester), everyElement(fromWidget));
    });
  });

  group('the empty and error states', () {
    testWidgets('emptyTextStyle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_empty),
              style: CometChatReactionListStyle(
                emptyTextStyle: const TextStyle(fontSize: 21),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(21.0));
    });

    testWidgets('errorTextStyle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_errored),
              style: CometChatReactionListStyle(
                errorTextStyle: const TextStyle(fontSize: 23),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(23.0));
    });

    testWidgets('errorTextColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_errored),
              style: CometChatReactionListStyle(
                errorTextColor: const Color(0xFF1C0909),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textColors(tester), contains(const Color(0xFF1C0909)));
    });

    testWidgets('errorSubtitleStyle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_errored),
              style: CometChatReactionListStyle(
                errorSubtitleStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textSizes(tester), contains(13.0));
    });

    testWidgets('errorSubtitleColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_errored),
              style: CometChatReactionListStyle(
                errorSubtitleColor: const Color(0xFF1C0A0A),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_textColors(tester), contains(const Color(0xFF1C0A0A)));
    });
  });

  group('CometChatReactionList own props', () {
    testWidgets('message and style drive the sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              style: CometChatReactionListStyle(
                backgroundColor: const Color(0xFF1C1010),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('You'), findsOneWidget);
      expect(_boxColors(tester), contains(const Color(0xFF1C1010)));
    });

    testWidgets('selectedReaction picks the opening tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              selectedReaction: '👍',
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatReactionList), findsOneWidget);
    });

    testWidgets('reactionRequestBuilder is accepted alongside a bloc', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              reactionRequestBuilder: (ReactionsRequestBuilder()..limit = 7),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('height, width and padding size the sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              height: 321,
              width: 234,
              padding: const EdgeInsets.only(left: 61),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.padding),
        contains(const EdgeInsets.only(left: 61)),
      );
    });

    testWidgets('listItemStyle reaches the reactor rows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              listItemStyle: const ListItemStyle(background: Color(0xFF1C1212)),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_boxColors(tester), contains(const Color(0xFF1C1212)));
    });

    testWidgets('emptyStateText replaces the empty copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_empty),
              emptyStateText: 'nobody reacted',
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('nobody reacted'), findsOneWidget);
    });

    testWidgets('emptyStateView replaces the empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_empty),
              emptyStateView: (_) => const Text('custom empty'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('custom empty'), findsOneWidget);
    });

    testWidgets('errorStateText replaces the error copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_errored),
              errorStateText: 'it broke',
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('it broke'), findsOneWidget);
    });

    testWidgets('errorStateView replaces the error state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_errored),
              errorStateView: (_) => const Text('custom error'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('custom error'), findsOneWidget);
    });

    testWidgets('loadingStateView and loadingIcon replace the loading state', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loading),
              loadingStateView: (_) => const Text('custom loading'),
              loadingIcon: const Icon(Icons.hourglass_empty),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('custom loading'), findsOneWidget);
    });

    testWidgets('onTap and onReactionListItemClick fire from a reactor row', (
      tester,
    ) async {
      Reaction? tapped;
      String? clicked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatReactionList(
              message: _message(),
              reactionListBloc: _bloc(_loaded),
              onTap: (reaction, message) => tapped = reaction,
              // the two callbacks carry different payloads: onTap gets the
              // Reaction, onReactionListItemClick gets its emoji
              onReactionListItemClick: (reaction, message) =>
                  clicked = reaction,
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('You'));
      await tester.pump();
      expect(tapped?.reaction ?? clicked, '👍');
    });
  });
}
