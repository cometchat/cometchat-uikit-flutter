/// Style matrix for [CometChatNotificationFeedStyle] — Track 3 PROP1
/// (ENG-38769).
///
/// Uses the `notificationFeedBloc` seam, so feed cards, filter chips and the
/// empty/error states are all reachable. Every case asserts a rendered
/// consequence.
///
/// Six properties are not covered here and cannot be: `connectivityBanner*`
/// (x3), `timestampHeader*` (x2) and `separatorColor` have no render site —
/// the feed has no connectivity banner, no timestamp group headers and no row
/// separator. See ENG-38858.
///
///   flutter test test/chat_ui/notification_feed/widget/notification_feed_style_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationFeedBloc
    extends MockBloc<NotificationFeedEvent, NotificationFeedState>
    implements NotificationFeedBloc {}

NotificationFeedItem _item(String id, String text, {int? readAt}) =>
    NotificationFeedItem(
      id: id,
      category: 'general',
      content: {
        'version': '1.0',
        'body': [
          {'type': 'text', 'text': text},
        ],
      },
      sentAt: 1700000000,
      readAt: readAt,
      sender: 'u1',
      receiver: 'u2',
      receiverType: 'user',
    );

MockNotificationFeedBloc _mock({
  List<NotificationFeedItem>? items,
  List<NotificationCategory> categories = const [],
  String? activeCategory,
  Map<String, int> categoryUnreadCounts = const {},
  NotificationFeedScreenState screenState = NotificationFeedScreenState.loaded,
  String? error,
}) {
  final state = NotificationFeedState(
    items: items ?? [_item('n1', 'A notification')],
    categories: categories,
    activeCategory: activeCategory,
    categoryUnreadCounts: categoryUnreadCounts,
    screenState: screenState,
    hasMorePages: false,
    error: error,
  );
  final bloc = MockNotificationFeedBloc();
  whenListen(
    bloc,
    Stream<NotificationFeedState>.value(state),
    initialState: state,
  );
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Widget _feed(
  CometChatNotificationFeedStyle style, {
  List<NotificationFeedItem>? items,
  List<NotificationCategory> categories = const [],
  String? activeCategory,
  Map<String, int> categoryUnreadCounts = const {},
  NotificationFeedScreenState screenState = NotificationFeedScreenState.loaded,
  String? error,
  bool showBackButton = false,
}) => MaterialApp(
  home: CometChatNotificationFeed(
    notificationFeedBloc: _mock(
      items: items,
      categories: categories,
      activeCategory: activeCategory,
      categoryUnreadCounts: categoryUnreadCounts,
      screenState: screenState,
      error: error,
    ),
    showBackButton: showBackButton,
    style: style,
  ),
);

Iterable<TextStyle> _textStyles(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.style)
    .whereType<TextStyle>();

Iterable<Color?> _decorationColors(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .map((d) => d.color);

const _categories = [
  NotificationCategory(id: 'c1', label: 'Alerts'),
  NotificationCategory(id: 'c2', label: 'Updates'),
];

void main() {
  group('surface', () {
    testWidgets('backgroundColor paints the scaffold', (tester) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            backgroundColor: Color(0xFF201010),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widgetList<Scaffold>(find.byType(Scaffold))
            .map((s) => s.backgroundColor),
        contains(const Color(0xFF201010)),
      );
    });
  });

  group('header', () {
    testWidgets('headerTitleColor colours the title', (tester) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            headerTitleColor: Color(0xFF202020),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF202020)),
      );
    });

    testWidgets('headerTitleTextStyle styles the title', (tester) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            headerTitleTextStyle: TextStyle(fontSize: 41),
          ),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(41.0));
    });

    testWidgets('backIconColor tints the back control', (tester) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            backIconColor: Color(0xFF212121),
          ),
          showBackButton: true,
        ),
      );
      await _settle(tester);
      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        contains(const Color(0xFF212121)),
      );
    });
  });

  group('filter chips', () {
    testWidgets('chipActiveBackgroundColor paints the selected chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            chipActiveBackgroundColor: Color(0xFF222222),
          ),
          categories: _categories,
          activeCategory: 'c1',
        ),
      );
      await _settle(tester);
      expect(_decorationColors(tester), contains(const Color(0xFF222222)));
    });

    testWidgets('chipInactiveBackgroundColor paints the unselected chips', (
      tester,
    ) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            chipInactiveBackgroundColor: Color(0xFF232323),
          ),
          categories: _categories,
          activeCategory: 'c1',
        ),
      );
      await _settle(tester);
      expect(_decorationColors(tester), contains(const Color(0xFF232323)));
    });

    testWidgets('chipActiveTextColor colours the selected chip label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            chipActiveTextColor: Color(0xFF242424),
          ),
          categories: _categories,
          activeCategory: 'c1',
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF242424)),
      );
    });

    testWidgets('chipInactiveTextColor colours the unselected chip labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            chipInactiveTextColor: Color(0xFF252525),
          ),
          categories: _categories,
          activeCategory: 'c1',
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF252525)),
      );
    });

    testWidgets('chipBorderColor outlines the chips', (tester) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            chipBorderColor: Color(0xFF262626),
          ),
          categories: _categories,
        ),
      );
      await _settle(tester);
      final borders = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<Border>();
      expect(
        borders.map((b) => b.top.color),
        contains(const Color(0xFF262626)),
      );
    });

    testWidgets('chipTextStyle styles the chip labels', (tester) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            chipTextStyle: TextStyle(fontSize: 42),
          ),
          categories: _categories,
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(42.0));
    });

    testWidgets('badgeBackgroundColor paints the chip unread badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            badgeBackgroundColor: Color(0xFF272727),
          ),
          categories: _categories,
          categoryUnreadCounts: const {'c1': 3},
        ),
      );
      await _settle(tester);
      expect(_decorationColors(tester), contains(const Color(0xFF272727)));
    });

    testWidgets('badgeTextColor colours the badge count', (tester) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            badgeTextColor: Color(0xFF282828),
          ),
          categories: _categories,
          categoryUnreadCounts: const {'c1': 3},
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF282828)),
      );
    });

    testWidgets('badgeTextStyle styles the badge count', (tester) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            badgeTextStyle: TextStyle(fontSize: 43),
          ),
          categories: _categories,
          categoryUnreadCounts: const {'c1': 3},
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(43.0));
    });
  });

  group('feed card', () {
    testWidgets('cardBackgroundColor paints the card', (tester) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            cardBackgroundColor: Color(0xFF292929),
          ),
        ),
      );
      await _settle(tester);
      expect(_decorationColors(tester), contains(const Color(0xFF292929)));
    });

    testWidgets('cardBorderColor and cardBorderWidth outline the card', (
      tester,
    ) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            cardBorderColor: Color(0xFF2A2A2A),
            cardBorderWidth: 3,
          ),
        ),
      );
      await _settle(tester);
      final borders = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<Border>();
      expect(
        borders.map((b) => b.top.color),
        contains(const Color(0xFF2A2A2A)),
      );
      expect(borders.map((b) => b.top.width), contains(3.0));
    });

    testWidgets('cardBorderRadius rounds the card', (tester) async {
      await tester.pumpWidget(
        _feed(const CometChatNotificationFeedStyle(cardBorderRadius: 17)),
      );
      await _settle(tester);
      expect(
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.borderRadius),
        contains(BorderRadius.circular(17)),
      );
    });

    testWidgets('unreadIndicatorColor paints the unread stripe', (
      tester,
    ) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            unreadIndicatorColor: Color(0xFF2B2B2B),
          ),
          items: [_item('n1', 'Unread one')],
        ),
      );
      await _settle(tester);
      expect(_decorationColors(tester), contains(const Color(0xFF2B2B2B)));
    });

    testWidgets('timestampTextColor colours the card timestamp', (
      tester,
    ) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            timestampTextColor: Color(0xFF2C2C2C),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF2C2C2C)),
      );
    });

    testWidgets('timestampTextStyle styles the card timestamp', (tester) async {
      await tester.pumpWidget(
        _feed(
          const CometChatNotificationFeedStyle(
            // Kept close to the 11px default: the card's metadata Row is narrow
            // and a large size overflows it, which is a test artefact rather than
            // anything this property does.
            timestampTextStyle: TextStyle(fontSize: 13),
          ),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(13.0));
    });
  });

  group('empty state', () {
    Widget empty(CometChatNotificationFeedStyle style) => _feed(
      style,
      items: const [],
      screenState: NotificationFeedScreenState.empty,
    );

    testWidgets('emptyStateTextStyle styles the title', (tester) async {
      await tester.pumpWidget(
        empty(
          const CometChatNotificationFeedStyle(
            emptyStateTextStyle: TextStyle(fontSize: 45),
          ),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(45.0));
    });

    testWidgets('emptyStateTextColor tints the empty illustration', (
      tester,
    ) async {
      await tester.pumpWidget(
        empty(
          const CometChatNotificationFeedStyle(
            emptyStateTextColor: Color(0xFF2D2D2D),
          ),
        ),
      );
      await _settle(tester);
      final tinted = [
        ...tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        ..._textStyles(tester).map((s) => s.color),
      ];
      expect(
        tinted.whereType<Color>().map((c) => c.toARGB32() & 0x00FFFFFF),
        contains(0x2D2D2D),
      );
    });

    testWidgets('emptyStateSubtitleTextStyle styles the subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        empty(
          const CometChatNotificationFeedStyle(
            emptyStateSubtitleTextStyle: TextStyle(fontSize: 46),
          ),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(46.0));
    });

    testWidgets('emptyStateSubtitleTextColor colours the subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        empty(
          const CometChatNotificationFeedStyle(
            emptyStateSubtitleTextColor: Color(0xFF2E2E2E),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF2E2E2E)),
      );
    });
  });

  group('error state and retry', () {
    Widget errored(CometChatNotificationFeedStyle style) => _feed(
      style,
      items: const [],
      screenState: NotificationFeedScreenState.error,
      error: 'boom',
    );

    testWidgets('errorStateTextStyle styles the title', (tester) async {
      await tester.pumpWidget(
        errored(
          const CometChatNotificationFeedStyle(
            errorStateTextStyle: TextStyle(fontSize: 47),
          ),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(47.0));
    });

    testWidgets('errorStateTextColor tints the error illustration', (
      tester,
    ) async {
      await tester.pumpWidget(
        errored(
          const CometChatNotificationFeedStyle(
            errorStateTextColor: Color(0xFF2F2F2F),
          ),
        ),
      );
      await _settle(tester);
      final tinted = [
        ...tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        ..._textStyles(tester).map((s) => s.color),
      ];
      expect(
        tinted.whereType<Color>().map((c) => c.toARGB32() & 0x00FFFFFF),
        contains(0x2F2F2F),
      );
    });

    testWidgets('errorStateSubtitleTextStyle styles the subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        errored(
          const CometChatNotificationFeedStyle(
            errorStateSubtitleTextStyle: TextStyle(fontSize: 48),
          ),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(48.0));
    });

    testWidgets('errorStateSubtitleTextColor colours the subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        errored(
          const CometChatNotificationFeedStyle(
            errorStateSubtitleTextColor: Color(0xFF303030),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF303030)),
      );
    });

    testWidgets('retryButtonBackgroundColor fills the retry button', (
      tester,
    ) async {
      await tester.pumpWidget(
        errored(
          const CometChatNotificationFeedStyle(
            retryButtonBackgroundColor: Color(0xFF313131),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<ElevatedButton>(find.byType(ElevatedButton))
            .style
            ?.backgroundColor
            ?.resolve({}),
        const Color(0xFF313131),
      );
    });

    testWidgets('retryButtonTextStyle styles the retry label', (tester) async {
      await tester.pumpWidget(
        errored(
          const CometChatNotificationFeedStyle(
            retryButtonTextStyle: TextStyle(fontSize: 49),
          ),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(49.0));
    });

    testWidgets('retryButtonTextColor colours the retry label', (tester) async {
      await tester.pumpWidget(
        errored(
          const CometChatNotificationFeedStyle(
            retryButtonTextColor: Color(0xFF323232),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF323232)),
      );
    });
  });
}
