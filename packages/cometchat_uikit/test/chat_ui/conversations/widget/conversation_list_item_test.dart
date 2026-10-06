import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: Translations.localizationsDelegates,
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

/// Minimal User fake — just enough for the list item's rendering path.
class _FakeUser extends Fake implements User {
  _FakeUser({required this.name});

  @override
  final String name;

  @override
  String get uid => 'u1';

  @override
  String get status => 'online';

  @override
  String? get avatar => null;

  @override
  String? get role => 'default';
}

/// Minimal Conversation fake whose `conversationWith` is a [User].
class _FakeConversation extends Fake implements Conversation {
  // Pin Conversation fields — read by the trailing view's pin glyph.
  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;
  _FakeConversation({required User user, int unreadMessageCount = 0})
    : _user = user,
      _unreadMessageCount = unreadMessageCount;

  final User _user;
  final int _unreadMessageCount;

  @override
  String get conversationId => 'c1';

  @override
  int get unreadMessageCount => _unreadMessageCount;

  @override
  AppEntity get conversationWith => _user;

  @override
  BaseMessage? get lastMessage => null;
}

void main() {
  group('CometChatConversationListItem', () {
    testWidgets('renders the user name as the title', (tester) async {
      final conv = _FakeConversation(user: _FakeUser(name: 'Alice'));

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: conv,
              onItemClick: (_) {},
            ),
          ),
        );
        await tester.pump();
      });

      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('fires onItemClick when tapped', (tester) async {
      Conversation? tappedConv;
      final conv = _FakeConversation(user: _FakeUser(name: 'Bob'));

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: conv,
              onItemClick: (c) => tappedConv = c,
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.byType(CometChatConversationListItem));
        await tester.pump();
      });

      expect(tappedConv, same(conv));
    });

    testWidgets('fires onItemLongClick when long-pressed', (tester) async {
      Conversation? longPressedConv;
      final conv = _FakeConversation(user: _FakeUser(name: 'Carol'));

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: conv,
              onItemClick: (_) {},
              onItemLongClick: (c) => longPressedConv = c,
            ),
          ),
        );
        await tester.pump();
        await tester.longPress(find.byType(CometChatConversationListItem));
        await tester.pump();
      });

      expect(longPressedConv, same(conv));
    });

    testWidgets('shows a selection checkbox when selectionMode != none', (
      tester,
    ) async {
      final conv = _FakeConversation(user: _FakeUser(name: 'Dan'));

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: conv,
              onItemClick: (_) {},
              selectionMode: SelectionMode.multiple,
              isSelected: false,
            ),
          ),
        );
        await tester.pump();
      });

      expect(find.byType(Checkbox), findsOneWidget);
      final cb = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(cb.value, isFalse);
    });

    testWidgets('checkbox is checked when isSelected is true', (tester) async {
      final conv = _FakeConversation(user: _FakeUser(name: 'Eve'));

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: conv,
              onItemClick: (_) {},
              selectionMode: SelectionMode.multiple,
              isSelected: true,
            ),
          ),
        );
        await tester.pump();
      });

      final cb = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(cb.value, isTrue);
    });

    testWidgets('leadingView slot overrides default avatar', (tester) async {
      final conv = _FakeConversation(user: _FakeUser(name: 'Frank'));

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: conv,
              onItemClick: (_) {},
              leadingView: (_, _) => const SizedBox(
                key: Key('custom-leading'),
                width: 40,
                height: 40,
              ),
            ),
          ),
        );
        await tester.pump();
      });

      expect(find.byKey(const Key('custom-leading')), findsOneWidget);
    });

    testWidgets('titleView slot overrides default title', (tester) async {
      final conv = _FakeConversation(user: _FakeUser(name: 'Grace'));

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: conv,
              onItemClick: (_) {},
              titleView: (_, _) =>
                  const Text('Custom Title', key: Key('custom-title')),
            ),
          ),
        );
        await tester.pump();
      });

      expect(find.byKey(const Key('custom-title')), findsOneWidget);
      // Default user name should not be rendered as title.
      expect(find.text('Grace'), findsNothing);
    });

    testWidgets(
      'Semantics label includes conversation name and selected state',
      (tester) async {
        final conv = _FakeConversation(user: _FakeUser(name: 'Henry'));

        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                conversation: conv,
                onItemClick: (_) {},
                isSelected: true,
                selectionMode: SelectionMode.multiple,
              ),
            ),
          );
          await tester.pump();
        });

        // Find the Semantics node with the matching label via a custom finder.
        final matches = find.byWidgetPredicate((w) {
          return w is Semantics &&
              (w.properties.label?.contains('Henry') ?? false) &&
              (w.properties.selected == true);
        });
        expect(matches, findsWidgets);
      },
    );
  });
}
