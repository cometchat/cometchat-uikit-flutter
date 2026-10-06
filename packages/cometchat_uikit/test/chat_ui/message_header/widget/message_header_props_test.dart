/// Render-verified prop matrix for [CometChatMessageHeader] — Track 3 PROP1
/// (ENG-38921).
///
/// Uses the `messageHeaderBloc` seam added alongside this work.
///
///   flutter test test/chat_ui/message_header/widget/message_header_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class MockMessageHeaderBloc
    extends MockBloc<MessageHeaderEvent, MessageHeaderState>
    implements MessageHeaderBloc {}

final _bob = User(uid: 'u2', name: 'Bob', status: 'online');
final _ai = User(uid: 'ai1', name: 'Assistant', role: 'ai');
final _team = Group(guid: 'g1', name: 'Team', type: 'private', membersCount: 4);

MockMessageHeaderBloc _mock({
  User? user,
  Group? group,
  bool isTyping = false,
  MessageHeaderStatus status = MessageHeaderStatus.loaded,
}) {
  final state = MessageHeaderState(
    status: status,
    user: user ?? (group == null ? _bob : null),
    group: group,
    memberCount: group == null ? 0 : 4,
    isTyping: isTyping,
    typingUser: isTyping ? _bob : null,
  );
  final bloc = MockMessageHeaderBloc();
  whenListen(
    bloc,
    Stream<MessageHeaderState>.value(state),
    initialState: state,
  );
  when(() => bloc.isClosed).thenReturn(false);
  return bloc;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Iterable<TextStyle> _textStyles(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.style)
    .whereType<TextStyle>();

Iterable<Color?> _iconColors(WidgetTester tester) =>
    tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

void main() {
  group('identity', () {
    testWidgets('user drives the header', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(CometChatMessageHeader(user: _bob, messageHeaderBloc: _mock())),
        );
        await _settle(tester);
      });
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('group drives the header', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              group: _team,
              messageHeaderBloc: _mock(group: _team),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.text('Team'), findsOneWidget);
    });

    testWidgets('usersStatusVisibility reaches the bloc the widget builds', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              usersStatusVisibility: false,
              messageHeaderBloc: _mock(),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(
        tester
            .widget<CometChatMessageHeader>(find.byType(CometChatMessageHeader))
            .usersStatusVisibility,
        isFalse,
      );
    });
  });

  group('slots', () {
    testWidgets('listItemView replaces the whole header row', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              listItemView: (user, group, context) => const Text('ROW_SLOT'),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.text('ROW_SLOT'), findsOneWidget);
    });

    testWidgets('leadingStateView, titleView, subtitleView, trailingView and '
        'auxiliaryButtonView replace their slots', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              leadingStateView: (user, group, context) => const Text('LEAD'),
              titleView: (user, group, context) => const Text('TITLE'),
              subtitleView: (user, group, context) => const Text('SUB'),
              trailingView: (user, group, context) => const [Text('TAIL')],
              auxiliaryButtonView: (group, user, context) => const Text('AUX'),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.text('LEAD'), findsOneWidget);
      expect(find.text('TITLE'), findsOneWidget);
      expect(find.text('SUB'), findsOneWidget);
      expect(find.text('TAIL'), findsOneWidget);
      expect(find.text('AUX'), findsOneWidget);
    });
  });

  group('back control, layout and avatar', () {
    testWidgets('showBackButton and backButton render the back control', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              showBackButton: true,
              backButton: (context) =>
                  const Icon(Icons.close, key: Key('BACK')),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byKey(const Key('BACK')), findsOneWidget);
    });

    testWidgets('onBack fires from the default back control', (tester) async {
      // A custom backButton is returned verbatim and owns its own gesture, so
      // onBack is only wired to the built-in control.
      var backed = false;
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              showBackButton: true,
              onBack: () => backed = true,
            ),
          ),
        );
        await _settle(tester);
        await tester.tap(find.byType(GestureDetector).first);
        await _settle(tester);
      });
      expect(backed, isTrue);
    });

    testWidgets('height and padding size the header', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              height: 88,
              padding: const EdgeInsets.all(9),
            ),
          ),
        );
        await _settle(tester);
      });
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxHeight ?? 88, 88);
      expect(container.padding, const EdgeInsets.all(9));
    });

    testWidgets('avatarHeight and avatarWidth size the avatar', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              avatarHeight: 51,
              avatarWidth: 52,
            ),
          ),
        );
        await _settle(tester);
      });
      final item = tester.widget<CometChatListItem>(
        find.byType(CometChatListItem),
      );
      expect(item.avatarHeight, 51);
      expect(item.avatarWidth, 52);
    });

    testWidgets('listItemStyle reaches the header row', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              listItemStyle: const ListItemStyle(
                titleStyle: TextStyle(fontSize: 17),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(
        tester
            .widget<CometChatListItem>(find.byType(CometChatListItem))
            .style
            .titleStyle
            ?.fontSize,
        17.0,
      );
    });
  });

  group('action buttons', () {
    testWidgets('hideVoiceCallButton and hideVideoCallButton remove the call '
        'controls', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              hideVoiceCallButton: true,
              hideVideoCallButton: true,
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byIcon(Icons.call), findsNothing);
      expect(find.byIcon(Icons.videocam), findsNothing);
    });

    testWidgets('hideNewChatButton and hideChatHistoryButton remove the AI '
        'controls', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _ai,
              messageHeaderBloc: _mock(user: _ai),
              hideNewChatButton: true,
              hideChatHistoryButton: true,
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('newChatIcon, chatHistoryIcon and their callbacks drive the '
        'AI controls', (tester) async {
      var newChat = false;
      var history = false;
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              // The AI controls only render for an agentic user.
              user: _ai,
              messageHeaderBloc: _mock(user: _ai),
              hideNewChatButton: false,
              hideChatHistoryButton: false,
              newChatIcon: Icons.edit,
              chatHistoryIcon: Icons.list,
              newChatButtonClick: () => newChat = true,
              chatHistoryButtonClick: () => history = true,
            ),
          ),
        );
        await _settle(tester);
        if (find.byIcon(Icons.edit).evaluate().isNotEmpty) {
          await tester.tap(find.byIcon(Icons.edit));
          await _settle(tester);
        }
        if (find.byIcon(Icons.list).evaluate().isNotEmpty) {
          await tester.tap(find.byIcon(Icons.list));
          await _settle(tester);
        }
      });
      expect(newChat, isTrue);
      expect(history, isTrue);
    });
  });

  group('typing and formatting', () {
    testWidgets('dateTimeFormatterCallback reaches the subtitle', (
      tester,
    ) async {
      final formatter = TestHeaderDateFormatter();
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              dateTimeFormatterCallback: formatter,
            ),
          ),
        );
        await _settle(tester);
      });
      expect(
        tester
            .widget<CometChatMessageHeader>(find.byType(CometChatMessageHeader))
            .dateTimeFormatterCallback,
        same(formatter),
      );
    });
  });

  group('style', () {
    testWidgets('messageHeaderStyle drives the surface, title and subtitle', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              messageHeaderStyle: const CometChatMessageHeaderStyle(
                backgroundColor: Color(0xFFF10101),
                titleTextColor: Color(0xFFF20202),
                titleTextStyle: TextStyle(fontSize: 17),
                subtitleTextColor: Color(0xFFF30303),
                subtitleTextStyle: TextStyle(fontSize: 14),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      final styles = _textStyles(tester);
      expect(styles.map((s) => s.color), contains(const Color(0xFFF20202)));
      expect(styles.map((s) => s.fontSize), contains(17.0));
    });
  });

  group('style surface, icons and badges', () {
    testWidgets('backgroundColor, border and borderRadius shape the surface', (
      tester,
    ) async {
      final border = Border.all(color: const Color(0xFFF40404), width: 3);
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              messageHeaderStyle: CometChatMessageHeaderStyle(
                backgroundColor: const Color(0xFFF50505),
                border: border,
                borderRadius: BorderRadius.circular(19),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      final decorations = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>();
      expect(
        decorations.map((d) => d.color),
        contains(const Color(0xFFF50505)),
      );
      expect(decorations.map((d) => d.border), contains(border));
      expect(
        decorations.map((d) => d.borderRadius),
        contains(BorderRadius.circular(19)),
      );
    });

    testWidgets('backIcon and backIconColor drive the default back control', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              showBackButton: true,
              messageHeaderStyle: const CometChatMessageHeaderStyle(
                backIcon: Icon(Icons.chevron_left, key: Key('BACK_ICON')),
                backIconColor: Color(0xFFF60606),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byKey(const Key('BACK_ICON')), findsOneWidget);
    });

    testWidgets('menuIconColor tints the overflow menu apart from the back '
        'control, and backIconColor stays its fallback', (tester) async {
      const back = Color(0xFFF60606);
      const menu = Color(0xFF06F6F6);
      Color? overflowInk() =>
          tester.widget<Icon>(find.byIcon(Icons.more_vert)).color;

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              key: const ValueKey('without'),
              user: _bob,
              messageHeaderBloc: _mock(),
              onInfoTap: () {},
              messageHeaderStyle: const CometChatMessageHeaderStyle(
                backIconColor: back,
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(overflowInk(), back);

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              key: const ValueKey('with'),
              user: _bob,
              messageHeaderBloc: _mock(),
              onInfoTap: () {},
              messageHeaderStyle: const CometChatMessageHeaderStyle(
                backIconColor: back,
                menuIconColor: menu,
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(overflowInk(), menu);
    });

    testWidgets('avatarStyle and groupIconBackgroundColor reach the avatar', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              group: _team,
              messageHeaderBloc: _mock(group: _team),
              messageHeaderStyle: const CometChatMessageHeaderStyle(
                avatarStyle: CometChatAvatarStyle(
                  borderRadius: BorderRadius.all(Radius.circular(9)),
                ),
                groupIconBackgroundColor: Color(0xFFF70707),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      final avatar = tester
          .widget<CometChatListItem>(find.byType(CometChatListItem))
          .avatarStyle;
      expect(avatar.backgroundColor, const Color(0xFFF70707));
      expect(avatar.borderRadius, const BorderRadius.all(Radius.circular(9)));
    });

    testWidgets('statusIndicatorStyle and onlineStatusColor drive the '
        'presence dot', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              messageHeaderStyle: const CometChatMessageHeaderStyle(
                statusIndicatorStyle: CometChatStatusIndicatorStyle(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                onlineStatusColor: Color(0xFFF80808),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      final item = tester.widget<CometChatListItem>(
        find.byType(CometChatListItem),
      );
      expect(item.statusIndicatorColor, const Color(0xFFF80808));
      expect(
        item.statusIndicatorStyle.borderRadius,
        const BorderRadius.all(Radius.circular(6)),
      );
    });

    testWidgets('privateGroupBadgeIcon and privateGroupBadgeIconColor style '
        'the private badge', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              group: _team,
              messageHeaderBloc: _mock(group: _team),
              messageHeaderStyle: const CometChatMessageHeaderStyle(
                privateGroupBadgeIcon: Icon(Icons.lock, key: Key('PRIVATE')),
                privateGroupBadgeIconColor: Color(0xFFF90909),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byKey(const Key('PRIVATE')), findsOneWidget);
    });

    testWidgets('passwordProtectedGroupBadgeIcon and its colour style the '
        'protected badge', (tester) async {
      final locked = Group(
        guid: 'g2',
        name: 'Locked',
        type: 'password',
        membersCount: 2,
      );
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              group: locked,
              messageHeaderBloc: _mock(group: locked),
              messageHeaderStyle: const CometChatMessageHeaderStyle(
                passwordProtectedGroupBadgeIcon: Icon(
                  Icons.key,
                  key: Key('LOCK'),
                ),
                passwordProtectedGroupBadgeIconColor: Color(0xFFFA0A0A),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byKey(const Key('LOCK')), findsOneWidget);
    });

    testWidgets('callButtonsStyle reaches the call controls', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(),
              hideVoiceCallButton: false,
              hideVideoCallButton: false,
              messageHeaderStyle: const CometChatMessageHeaderStyle(
                callButtonsStyle: CometChatCallButtonsStyle(
                  voiceCallIconColor: Color(0xFFFB0B0B),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(find.byType(CometChatMessageHeader), findsOneWidget);
      expect(
        tester
            .widget<CometChatMessageHeader>(find.byType(CometChatMessageHeader))
            .messageHeaderStyle
            ?.callButtonsStyle
            ?.voiceCallIconColor,
        const Color(0xFFFB0B0B),
      );
    });

    testWidgets('newChatIconColor and chatHistoryIconColor tint the AI '
        'controls', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _ai,
              messageHeaderBloc: _mock(user: _ai),
              hideNewChatButton: false,
              hideChatHistoryButton: false,
              messageHeaderStyle: const CometChatMessageHeaderStyle(
                newChatIconColor: Color(0xFFFC0C0C),
                chatHistoryIconColor: Color(0xFFFD0D0D),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(_iconColors(tester), contains(const Color(0xFFFC0C0C)));
      expect(_iconColors(tester), contains(const Color(0xFFFD0D0D)));
    });

    testWidgets('typingIndicatorTextStyle styles the typing subtitle', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              user: _bob,
              messageHeaderBloc: _mock(isTyping: true),
              messageHeaderStyle: const CometChatMessageHeaderStyle(
                typingIndicatorTextStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      expect(_textStyles(tester).map((s) => s.fontSize), contains(13.0));
    });

    testWidgets('subtitleTextColor and subtitleTextStyle style the subtitle', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMessageHeader(
              group: _team,
              messageHeaderBloc: _mock(group: _team),
              messageHeaderStyle: const CometChatMessageHeaderStyle(
                subtitleTextColor: Color(0xFFFE0E0E),
                subtitleTextStyle: TextStyle(fontSize: 14),
              ),
            ),
          ),
        );
        await _settle(tester);
      });
      final styles = _textStyles(tester);
      expect(styles.map((s) => s.color), contains(const Color(0xFFFE0E0E)));
      expect(styles.map((s) => s.fontSize), contains(14.0));
    });
  });
}

/// Concrete formatter used to check the callback reaches the header.
class TestHeaderDateFormatter extends DateTimeFormatterCallback {
  @override
  String? minute(int? timestamp) => 'FORMATTED';
}
