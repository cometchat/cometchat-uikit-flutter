/// Golden pins for [CometChatNotificationFeed]: the feed item card, read and
/// unread, the category chips, and the feed's state views.
///
/// The real screen is rendered, held in a fixed state through its
/// `notificationFeedBloc` seam. Card bodies are plain text elements, so the
/// card renderer loads nothing.
///
///   flutter test test/chat_ui/notification_feed/goldens/                  # verify
///   flutter test test/chat_ui/notification_feed/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

class _MockNotificationFeedBloc
    extends MockBloc<NotificationFeedEvent, NotificationFeedState>
    implements NotificationFeedBloc {}

/// Years old, so the card prints an absolute `dd/MM/yyyy` stamp and the feed
/// files it under its oldest section, whatever day the test runs on. Built
/// from a local DateTime so the printed date is the same in every zone.
final int _sentAt = DateTime(2024, 3, 14, 12).millisecondsSinceEpoch ~/ 1000;

NotificationFeedItem _item(
  String id, {
  required String category,
  required String text,
  bool read = false,
}) => NotificationFeedItem(
  id: id,
  category: category,
  content: {
    'version': '1.0',
    'body': [
      {'type': 'text', 'text': text},
    ],
  },
  sentAt: _sentAt,
  readAt: read ? _sentAt + 60 : null,
  sender: 'system',
  receiver: 'u-me',
  receiverType: 'user',
);

List<NotificationFeedItem> _items() => [
  _item('n1', category: 'billing', text: 'Your invoice for March is ready'),
  _item(
    'n2',
    category: 'security',
    text: 'New sign-in from a Mac in Lisbon',
    read: true,
  ),
  _item(
    'n3',
    category: 'billing',
    text: 'Payment received, thank you',
    read: true,
  ),
];

const _categories = [
  NotificationCategory(id: 'billing', label: 'Billing'),
  NotificationCategory(id: 'security', label: 'Security'),
];

_MockNotificationFeedBloc _bloc(NotificationFeedState state) {
  final bloc = _MockNotificationFeedBloc();
  whenListen(
    bloc,
    Stream<NotificationFeedState>.value(state),
    initialState: state,
  );
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

const _size = Size(375, 560);

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        'feed items: one unread, two read, under category chips',
        fileName: 'notification_feed_loaded',
        size: _size,
        settle: false,
        builder: () => CometChatNotificationFeed(
          notificationFeedBloc: _bloc(
            NotificationFeedState(
              items: _items(),
              categories: _categories,
              totalUnreadCount: 1,
              categoryUnreadCounts: const {'billing': 1},
              screenState: NotificationFeedScreenState.loaded,
              hasMorePages: false,
            ),
          ),
        ),
      );

      lightDarkGolden(
        'notification feed empty state',
        fileName: 'notification_feed_state_empty',
        size: _size,
        settle: false,
        builder: () => CometChatNotificationFeed(
          notificationFeedBloc: _bloc(
            NotificationFeedState(
              screenState: NotificationFeedScreenState.empty,
              hasMorePages: false,
            ),
          ),
        ),
      );

      lightDarkGolden(
        'notification feed error state',
        fileName: 'notification_feed_state_error',
        size: _size,
        settle: false,
        builder: () => CometChatNotificationFeed(
          notificationFeedBloc: _bloc(
            NotificationFeedState(
              screenState: NotificationFeedScreenState.error,
              error: 'Something went wrong',
              hasMorePages: false,
            ),
          ),
        ),
      );

      lightDarkGolden(
        'notification feed loading state',
        fileName: 'notification_feed_state_loading',
        size: _size,
        settle: false,
        builder: () => CometChatNotificationFeed(
          notificationFeedBloc: _bloc(
            NotificationFeedState(hasMorePages: false),
          ),
        ),
      );
    },
  );
}
