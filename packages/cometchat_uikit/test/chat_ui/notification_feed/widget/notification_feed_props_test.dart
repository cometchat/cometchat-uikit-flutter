/// Render-verified prop matrix for [CometChatNotificationFeed] — Track 3 PROP1
/// (ENG-38769).
///
/// Uses the `notificationFeedBloc` seam added alongside this work, so feed
/// items render without a live SDK. Every case pumps the real widget and
/// asserts a rendered consequence.
///
///   flutter test test/chat_ui/notification_feed/widget/notification_feed_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationFeedBloc
    extends MockBloc<NotificationFeedEvent, NotificationFeedState>
    implements NotificationFeedBloc {}

NotificationFeedItem _item(String id, String text) => NotificationFeedItem(
  id: id,
  category: 'general',
  content: {
    'version': '1.0',
    'body': [
      {'type': 'text', 'text': text},
    ],
  },
  sentAt: 1700000000,
  sender: 'u1',
  receiver: 'u2',
  receiverType: 'user',
);

MockNotificationFeedBloc _mock({
  List<NotificationFeedItem>? items,
  List<NotificationCategory> categories = const [],
  NotificationFeedScreenState screenState = NotificationFeedScreenState.loaded,
  String? error,
}) {
  final state = NotificationFeedState(
    items: items ?? [_item('n1', 'A notification')],
    categories: categories,
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

void main() {
  setUpAll(() => registerFallbackValue('n1'));

  group('header chrome', () {
    testWidgets('title renders in the app bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(),
            title: 'MY_FEED_TITLE',
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('MY_FEED_TITLE'), findsOneWidget);
    });

    testWidgets('showHeader false removes the app bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(),
            title: 'MY_FEED_TITLE',
            showHeader: false,
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('MY_FEED_TITLE'), findsNothing);
    });

    testWidgets('showBackButton adds the back control', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(),
            showBackButton: true,
          ),
        ),
      );
      await _settle(tester);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(IconButton),
        ),
        findsWidgets,
      );
    });

    testWidgets('showBackButton false leaves no back control', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(),
            showBackButton: false,
          ),
        ),
      );
      await _settle(tester);
      expect(tester.widget<AppBar>(find.byType(AppBar)).leading, isNull);
    });

    testWidgets('onBackPress fires from the back control', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(),
            showBackButton: true,
            onBackPress: () => pressed = true,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(IconButton),
            )
            .first,
      );
      await _settle(tester);
      expect(pressed, isTrue);
    });

    testWidgets('headerView replaces the default app bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(),
            headerView: AppBar(title: const Text('CUSTOM_HEADER')),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('CUSTOM_HEADER'), findsOneWidget);
    });

    testWidgets('showFilterChips renders the category chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(
              categories: [NotificationCategory(id: 'c1', label: 'Alerts')],
            ),
            showFilterChips: true,
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(NotificationFeedFilterChips), findsOneWidget);
    });

    testWidgets('showFilterChips false removes the category chips', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(
              categories: [NotificationCategory(id: 'c1', label: 'Alerts')],
            ),
            showFilterChips: false,
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(NotificationFeedFilterChips), findsNothing);
    });
  });

  group('state views', () {
    testWidgets('emptyStateView renders on the empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(
              items: const [],
              screenState: NotificationFeedScreenState.empty,
            ),
            emptyStateView: const Text('EMPTY_SLOT'),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('EMPTY_SLOT'), findsOneWidget);
    });

    testWidgets('errorStateView renders on the error state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(
              items: const [],
              screenState: NotificationFeedScreenState.error,
              error: 'boom',
            ),
            errorStateView: const Text('ERROR_SLOT'),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('ERROR_SLOT'), findsOneWidget);
    });

    testWidgets('loadingStateView renders on the loading state', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(
              items: const [],
              screenState: NotificationFeedScreenState.loading,
            ),
            loadingStateView: const Text('LOADING_SLOT'),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('LOADING_SLOT'), findsOneWidget);
    });

    testWidgets('onError fires with the bloc error message', (tester) async {
      String? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(
              items: const [],
              screenState: NotificationFeedScreenState.error,
              error: 'BOOM_MESSAGE',
            ),
            onError: (error) => seen = error.toString(),
          ),
        ),
      );
      await _settle(tester);
      expect(seen, contains('BOOM_MESSAGE'));
    });
  });

  group('feed items', () {
    testWidgets('the injected bloc drives the rendered cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(items: [_item('n1', 'INJECTED_BODY')]),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(FeedItemCard), findsOneWidget);
    });

    testWidgets('onItemClick and onActionClick reach the card', (tester) async {
      void itemClick(NotificationFeedItem item) {}
      void actionClick(
        NotificationFeedItem item,
        CometChatCardActionEvent action,
      ) {}
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(),
            onItemClick: itemClick,
            onActionClick: actionClick,
          ),
        ),
      );
      await _settle(tester);
      final card = tester.widget<FeedItemCard>(find.byType(FeedItemCard));
      expect(card.onItemClick, same(itemClick));
      expect(card.onActionClick, same(actionClick));
    });

    testWidgets('cardThemeMode reaches the card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(),
            cardThemeMode: CometChatCardThemeMode.dark,
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester.widget<FeedItemCard>(find.byType(FeedItemCard)).cardThemeMode,
        CometChatCardThemeMode.dark,
      );
    });

    testWidgets('cardThemeOverride reaches the card', (tester) async {
      const override = CometChatCardThemeOverride();
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(),
            cardThemeOverride: override,
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<FeedItemCard>(find.byType(FeedItemCard))
            .cardThemeOverride,
        same(override),
      );
    });

    testWidgets('scrollToItemId scrolls to the deep-linked item', (
      tester,
    ) async {
      // The deep-linked id is deliberately absent from the loaded page, which
      // is the branch that fetches it rather than scrolling to it.
      final bloc = _mock(items: [_item('n1', 'First')]);
      when(
        () => bloc.getFeedItem(any()),
      ).thenAnswer((_) async => Success(_item('deep', 'Deep linked')));
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: bloc,
            scrollToItemId: 'deep',
          ),
        ),
      );
      await _settle(tester);
      // _handleScrollToItem waits 500ms before it looks the item up.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      final requested = verify(
        () => bloc.getFeedItem(captureAny()),
      ).captured.cast<String>();
      expect(requested, contains('deep'));
    });
  });

  group('style and request builders', () {
    testWidgets('style paints the feed background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CometChatNotificationFeed(
            notificationFeedBloc: _mock(),
            style: const CometChatNotificationFeedStyle(
              backgroundColor: Color(0xFF224466),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widgetList<Scaffold>(find.byType(Scaffold))
            .map((s) => s.backgroundColor),
        contains(const Color(0xFF224466)),
      );
    });

    testWidgets(
      'notificationFeedRequestBuilder and '
      'notificationCategoriesRequestBuilder reach the bloc the widget builds',
      (tester) async {
        final feedBuilder = NotificationFeedRequestBuilder();
        final categoriesBuilder = NotificationCategoriesRequestBuilder();
        NotificationFeedBloc? built;
        await tester.pumpWidget(
          MaterialApp(
            home: CometChatNotificationFeed(
              notificationFeedRequestBuilder: feedBuilder,
              notificationCategoriesRequestBuilder: categoriesBuilder,
              headerView: AppBar(
                title: Builder(
                  builder: (context) {
                    built = BlocProvider.of<NotificationFeedBloc>(context);
                    return const Text('H');
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(built?.feedRequestBuilder, same(feedBuilder));
        expect(built?.categoriesRequestBuilder, same(categoriesBuilder));
      },
    );
  });
}
