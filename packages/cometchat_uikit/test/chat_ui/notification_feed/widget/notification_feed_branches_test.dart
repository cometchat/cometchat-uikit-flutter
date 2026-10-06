/// The [CometChatNotificationFeed] branches the prop matrix does not reach:
/// the events each gesture dispatches and the two default-state views.
///
/// The prop matrix pins that each style value paints. This pins the plumbing —
/// paging on scroll, pull-to-refresh, category switching, retry, and the
/// read-report a card raises when it is tapped. Each of those is a bloc event
/// whose absence would look exactly like a working screen.
///
///   flutter test test/chat_ui/notification_feed/widget/notification_feed_branches_test.dart
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
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
  bool hasMorePages = false,
  StreamController<NotificationFeedState>? controller,
}) {
  final state = NotificationFeedState(
    items: items ?? [_item('n1', 'A notification')],
    categories: categories,
    screenState: screenState,
    hasMorePages: hasMorePages,
    error: error,
  );
  final bloc = MockNotificationFeedBloc();
  whenListen(
    bloc,
    controller?.stream ?? Stream<NotificationFeedState>.value(state),
    initialState: state,
  );
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Widget _screen(CometChatNotificationFeed child) => MaterialApp(home: child);

void main() {
  setUpAll(() {
    registerFallbackValue('n1');
    registerFallbackValue(const LoadNotificationFeed());
  });

  // =========================================================================
  group('category chips', () {
    testWidgets('picking a category dispatches SwitchCategory with its id', (
      tester,
    ) async {
      final bloc = _mock(
        categories: const [NotificationCategory(id: 'orders', label: 'Orders')],
      );

      await tester.pumpWidget(
        _screen(CometChatNotificationFeed(notificationFeedBloc: bloc)),
      );
      await _settle(tester);
      await tester.tap(find.text('Orders'));
      await tester.pump();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<SwitchCategory>())),
      ).captured;
      expect((captured.single as SwitchCategory).categoryId, 'orders');
    });

    testWidgets('picking All clears the category filter', (tester) async {
      final bloc = _mock(
        categories: const [NotificationCategory(id: 'orders', label: 'Orders')],
      );

      await tester.pumpWidget(
        _screen(CometChatNotificationFeed(notificationFeedBloc: bloc)),
      );
      await _settle(tester);
      await tester.tap(find.text('All'));
      await tester.pump();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<SwitchCategory>())),
      ).captured;
      expect((captured.single as SwitchCategory).categoryId, isNull);
    });

    testWidgets('the chip row is hidden while the first load is in flight', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          CometChatNotificationFeed(
            notificationFeedBloc: _mock(
              screenState: NotificationFeedScreenState.loading,
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('All'), findsNothing);
    });
  });

  // =========================================================================
  group('paging and refresh', () {
    testWidgets('scrolling to the bottom asks for the next page', (
      tester,
    ) async {
      final bloc = _mock(
        items: List.generate(30, (i) => _item('n$i', 'Notification $i')),
        hasMorePages: true,
      );

      await tester.pumpWidget(
        _screen(CometChatNotificationFeed(notificationFeedBloc: bloc)),
      );
      await _settle(tester);

      await tester.fling(find.byType(ListView), const Offset(0, -6000), 6000);
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(any(that: isA<LoadMoreFeedItems>())),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('pull-to-refresh dispatches RefreshFeed', (tester) async {
      final controller = StreamController<NotificationFeedState>.broadcast();
      addTearDown(controller.close);
      final bloc = _mock(
        items: List.generate(10, (i) => _item('n$i', 'Notification $i')),
        controller: controller,
      );

      await tester.pumpWidget(
        _screen(CometChatNotificationFeed(notificationFeedBloc: bloc)),
      );
      await _settle(tester);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => bloc.add(any(that: isA<RefreshFeed>()))).called(1);

      // Settle the indicator: the widget waits for a non-refreshing state.
      controller.add(
        NotificationFeedState(
          items: [],
          screenState: NotificationFeedScreenState.loaded,
        ),
      );
      await tester.pumpAndSettle();
    });
  });

  // =========================================================================
  group('state views', () {
    testWidgets('the empty view draws its glyph at half the text colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          CometChatNotificationFeed(
            notificationFeedBloc: _mock(
              items: const [],
              screenState: NotificationFeedScreenState.empty,
            ),
          ),
        ),
      );
      await _settle(tester);

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.move_to_inbox_outlined),
      );
      expect(icon.color?.a, closeTo(0.5, 0.001));
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('the error view draws its glyph at half the text colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screen(
          CometChatNotificationFeed(
            notificationFeedBloc: _mock(
              items: const [],
              screenState: NotificationFeedScreenState.error,
              error: 'boom',
            ),
          ),
        ),
      );
      await _settle(tester);

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.color?.a, closeTo(0.5, 0.001));
      expect(find.text('boom'), findsOneWidget);
    });

    testWidgets('Retry reloads the feed', (tester) async {
      final bloc = _mock(
        items: const [],
        screenState: NotificationFeedScreenState.error,
        error: 'boom',
      );

      await tester.pumpWidget(
        _screen(CometChatNotificationFeed(notificationFeedBloc: bloc)),
      );
      await _settle(tester);
      clearInteractions(bloc);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      verify(() => bloc.add(any(that: isA<LoadNotificationFeed>()))).called(1);
    });
  });

  // =========================================================================
  group('scrollToItemId', () {
    testWidgets('an item already in the feed is scrolled to, not refetched', (
      tester,
    ) async {
      final bloc = _mock(
        items: List.generate(20, (i) => _item('n$i', 'Notification $i')),
      );

      await tester.pumpWidget(
        _screen(
          CometChatNotificationFeed(
            notificationFeedBloc: bloc,
            scrollToItemId: 'n15',
          ),
        ),
      );
      await _settle(tester);
      // The handler waits half a second before it looks.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.getFeedItem(any()));
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.controller!.offset, greaterThan(0));
    });

    testWidgets('an item not in the feed is fetched and prepended', (
      tester,
    ) async {
      final bloc = _mock();
      when(
        () => bloc.getFeedItem('missing'),
      ).thenAnswer((_) async => Success(_item('missing', 'Fetched later')));

      await tester.pumpWidget(
        _screen(
          CometChatNotificationFeed(
            notificationFeedBloc: bloc,
            scrollToItemId: 'missing',
          ),
        ),
      );
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      verify(() => bloc.getFeedItem('missing')).called(1);
      final captured = verify(
        () => bloc.add(captureAny(that: isA<FeedItemReceived>())),
      ).captured;
      expect((captured.single as FeedItemReceived).feedItem.id, 'missing');
    });

    testWidgets('a fetch that fails changes nothing', (tester) async {
      final bloc = _mock();
      when(
        () => bloc.getFeedItem('missing'),
      ).thenAnswer((_) async => const Failure(message: 'not found'));

      await tester.pumpWidget(
        _screen(
          CometChatNotificationFeed(
            notificationFeedBloc: bloc,
            scrollToItemId: 'missing',
          ),
        ),
      );
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      verify(() => bloc.getFeedItem('missing')).called(1);
      verifyNever(() => bloc.add(any(that: isA<FeedItemReceived>())));
    });
  });

  // =========================================================================
  group('card taps', () {
    testWidgets('tapping a card reports it as clicked and calls onItemClick', (
      tester,
    ) async {
      final bloc = _mock();
      NotificationFeedItem? clicked;

      await tester.pumpWidget(
        _screen(
          CometChatNotificationFeed(
            notificationFeedBloc: bloc,
            onItemClick: (item) => clicked = item,
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.byType(FeedItemCard).first, warnIfMissed: false);
      await tester.pump();

      final captured = verify(
        () => bloc.add(captureAny(that: isA<ReportClicked>())),
      ).captured;
      expect((captured.single as ReportClicked).feedItem.id, 'n1');
      expect(clicked?.id, 'n1');
    });
  });
}
