/// Render-verified tests for the conversation-row props that 6.2.0 had
/// deprecated as no-ops and that now take effect:
///
/// - `listItemStyle` on [CometChatConversations], [ConversationsList] and
///   [CometChatConversationListItem]. The v6 docs list it on
///   CometChatConversations, and Android applies its row item style.
/// - [CometChatConversationListItemStyle.checkBoxSelectIcon], which Android
///   Compose applies to the row's checkbox.
///
/// Every test pumps the real widget and reads what the prop changed in the
/// built tree, comparing against a pump without it where the default could
/// otherwise coincide with the sentinel.
///
///   flutter test test/chat_ui/conversations/widget/list_item_style_and_select_icon_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class _MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {
  @override
  ValueNotifier<List<TypingIndicator>> getTypingNotifier(String id) =>
      ValueNotifier(const []);

  @override
  List<TypingIndicator> getTypingIndicators(String conversationId) => [];

  @override
  // ignore: must_call_super
  void add(ConversationsEvent event) {}
}

class _FakeUser extends Fake implements User {
  _FakeUser(this.name, this.uid);

  @override
  final String name;

  @override
  final String uid;

  @override
  String? get avatar => null;

  @override
  String get status => 'online';

  @override
  String? get role => 'default';

  @override
  String? get link => null;
}

class _FakeConversation extends Fake implements Conversation {
  _FakeConversation(this.conversationWith, this.conversationId);

  @override
  final AppEntity conversationWith;

  @override
  final String conversationId;

  @override
  int get unreadMessageCount => 0;

  @override
  BaseMessage? get lastMessage => null;

  @override
  String get conversationType => 'user';

  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;
}

// Sentinels no theme uses.
const _kBackground = Color(0xFF12AB34);
const _kGradientStart = Color(0xFF223344);
const _kSeparator = Color(0xFFAA1122);
const _kTitle = Color(0xFFCC7711);
const _kStyleBackground = Color(0xFF5566AA);
const _kTint = Color(0xFFEE22CC);
const _kPadding = EdgeInsets.all(11);
const _kMargin = EdgeInsets.all(7);
const _kRadius = BorderRadius.all(Radius.circular(9));

const _fullItemStyle = ListItemStyle(
  background: _kBackground,
  padding: _kPadding,
  margin: _kMargin,
  height: 131,
  width: 301,
  borderRadius: _kRadius,
  separatorColor: _kSeparator,
  titleStyle: TextStyle(color: _kTitle, fontSize: 19),
);

final _palette = CometChatColorPalette(
  primary: const Color(0xFF6852D6),
  textPrimary: const Color(0xFF141414),
  textSecondary: const Color(0xFF727272),
  iconSecondary: const Color(0xFFA1A1A1),
  background1: const Color(0xFFFFFFFF),
  background4: const Color(0xFFE8E8E8),
  borderDefault: const Color(0xFFDCDCDC),
  white: const Color(0xFFFFFFFF),
);

Conversation _alice() => _FakeConversation(_FakeUser('Alice', 'u1'), 'user_u1');

_MockConversationsBloc _loadedBloc() {
  final bloc = _MockConversationsBloc();
  // Two rows: the list draws no separator after the last one, and the
  // assertions read the first.
  final state = ConversationsLoaded(
    conversations: [
      _alice(),
      _FakeConversation(_FakeUser('Bob', 'u2'), 'user_u2'),
    ],
    hasMore: false,
  );
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream.fromIterable([state]), initialState: state);
  return bloc;
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// The row's root container: the first [Container] under the row.
Container _rowContainer(WidgetTester tester) => tester.widget<Container>(
  find
      .descendant(
        of: find.byType(CometChatConversationListItem),
        matching: find.byType(Container),
      )
      .first,
);

/// The row's decoration, or null while the row paints a plain colour.
BoxDecoration? _rowDecoration(WidgetTester tester) =>
    _rowContainer(tester).decoration as BoxDecoration?;

/// The row's background colour, whichever way the container paints it.
Color? _rowColor(WidgetTester tester) =>
    _rowContainer(tester).color ?? _rowDecoration(tester)?.color;

TextStyle? _titleStyle(WidgetTester tester) =>
    tester.widget<Text>(find.text('Alice')).style;

/// Asserts everything [_fullItemStyle] sets reached the row.
void _expectFullItemStyle(WidgetTester tester) {
  final container = _rowContainer(tester);
  final decoration = container.decoration! as BoxDecoration;
  expect(_rowColor(tester), _kBackground);
  expect(decoration.borderRadius, _kRadius);
  expect((decoration.border! as Border).bottom.color, _kSeparator);
  expect(container.padding, _kPadding);
  expect(container.margin, _kMargin);
  expect(container.constraints?.maxHeight, 131);
  expect(container.constraints?.maxWidth, 301);
  expect(_titleStyle(tester)?.color, _kTitle);
  expect(_titleStyle(tester)?.fontSize, 19);
}

/// Asserts the row is back on its defaults, so a sentinel above can only
/// have come from the prop.
void _expectDefaultRow(WidgetTester tester) {
  final container = _rowContainer(tester);
  expect(_rowColor(tester), isNot(_kBackground));
  expect(_rowDecoration(tester)?.border, isNull);
  expect(container.padding, isNot(_kPadding));
  expect(container.margin, isNull);
  expect(_titleStyle(tester)?.color, isNot(_kTitle));
}

void main() {
  group('listItemStyle', () {
    testWidgets('on CometChatConversations it styles every row', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              height: 600,
              child: CometChatConversations(
                key: UniqueKey(),
                conversationsBloc: _loadedBloc(),
              ),
            ),
          ),
        );
        await tester.pump();
      });
      _expectDefaultRow(tester);

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              height: 600,
              child: CometChatConversations(
                key: UniqueKey(),
                conversationsBloc: _loadedBloc(),
                listItemStyle: _fullItemStyle,
              ),
            ),
          ),
        );
        await tester.pump();
      });
      _expectFullItemStyle(tester);
    });

    testWidgets('CometChatConversationsStyle wins where both set a value', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              height: 600,
              child: CometChatConversations(
                conversationsBloc: _loadedBloc(),
                conversationsStyle: const CometChatConversationsStyle(
                  backgroundColor: _kStyleBackground,
                  itemTitleTextStyle: TextStyle(fontSize: 13),
                ),
                listItemStyle: _fullItemStyle,
              ),
            ),
          ),
        );
        await tester.pump();
      });
      expect(_rowColor(tester), _kStyleBackground);
      expect(_titleStyle(tester)?.fontSize, 13);
      // Fields the conversations style does not set still come through.
      expect(_rowContainer(tester).padding, _kPadding);
    });

    testWidgets('on ConversationsList it reaches the rows', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              height: 600,
              child: ConversationsList(
                conversationsBloc: _loadedBloc(),
                style: const CometChatConversationsStyle(),
                statusStyle: const CometChatStatusIndicatorStyle(),
                typingStyle: const CometChatTypingIndicatorStyle(),
                receiptStyle: CometChatMessageReceiptStyle(),
                datesStyle: const CometChatDateStyle(),
                colorPalette: _palette,
                spacing: CometChatSpacing(),
                typography: const CometChatTypography(),
                listItemStyle: _fullItemStyle,
              ),
            ),
          ),
        );
        await tester.pump();
      });
      expect(_rowColor(tester), _kBackground);
      _expectFullItemStyle(tester);
    });

    testWidgets('on CometChatConversationListItem it styles the row', (
      tester,
    ) async {
      Future<void> pump({ListItemStyle? listItemStyle}) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                key: UniqueKey(),
                conversation: _alice(),
                onItemClick: (_) {},
                colorPalette: _palette,
                listItemStyle: listItemStyle,
              ),
            ),
          );
          await tester.pump();
        });
      }

      await pump();
      _expectDefaultRow(tester);

      await pump(listItemStyle: _fullItemStyle);
      _expectFullItemStyle(tester);
    });

    testWidgets('an explicit border replaces the separator line', (
      tester,
    ) async {
      final border = Border.all(color: _kTint, width: 3);
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _alice(),
              onItemClick: (_) {},
              colorPalette: _palette,
              listItemStyle: ListItemStyle(
                border: border,
                separatorColor: _kSeparator,
              ),
            ),
          ),
        );
        await tester.pump();
      });
      expect(_rowDecoration(tester)?.border, border);
    });

    testWidgets('the gradient stands in for the default background only', (
      tester,
    ) async {
      const gradient = LinearGradient(colors: [_kGradientStart, _kBackground]);
      Future<void> pump({
        bool isSelected = false,
        CometChatConversationListItemStyle? style,
      }) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatConversationListItem(
                key: UniqueKey(),
                conversation: _alice(),
                onItemClick: (_) {},
                colorPalette: _palette,
                isSelected: isSelected,
                style: style,
                listItemStyle: const ListItemStyle(gradient: gradient),
              ),
            ),
          );
          await tester.pump();
        });
      }

      await pump();
      expect(_rowDecoration(tester)?.gradient, gradient);

      // Selection keeps its highlight colour visible.
      await pump(isSelected: true);
      expect(_rowDecoration(tester)?.gradient, isNull);

      // An explicit background colour is not painted over.
      await pump(
        style: const CometChatConversationListItemStyle(
          backgroundColor: _kStyleBackground,
        ),
      );
      expect(_rowDecoration(tester)?.gradient, isNull);
      expect(_rowColor(tester), _kStyleBackground);
    });
  });

  group('checkBoxSelectIcon', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool isSelected,
      Widget? icon,
    }) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              key: UniqueKey(),
              conversation: _alice(),
              onItemClick: (_) {},
              colorPalette: _palette,
              selectionMode: SelectionMode.multiple,
              isSelected: isSelected,
              style: CometChatConversationListItemStyle(
                checkBoxSelectIcon: icon,
                checkBoxSelectIconTint: _kTint,
              ),
            ),
          ),
        );
        await tester.pump();
      });
    }

    testWidgets('replaces the default tick on a selected row', (tester) async {
      await pump(tester, isSelected: true);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);

      await pump(tester, isSelected: true, icon: const Icon(Icons.star));
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byIcon(Icons.star), findsOneWidget);
      // Tinted by checkBoxSelectIconTint, as the default tick is.
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.star))).color,
        _kTint,
      );
    });

    testWidgets('is hidden on an unselected row, which keeps its box', (
      tester,
    ) async {
      await pump(tester, isSelected: false, icon: const Icon(Icons.star));
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('tapping the custom box toggles the selection', (tester) async {
      var toggles = 0;
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatConversationListItem(
              conversation: _alice(),
              onItemClick: (_) {},
              onSelectionToggle: () => toggles++,
              colorPalette: _palette,
              selectionMode: SelectionMode.multiple,
              isSelected: true,
              style: const CometChatConversationListItemStyle(
                checkBoxSelectIcon: Icon(Icons.star),
              ),
            ),
          ),
        );
        await tester.pump();
      });
      await tester.tap(find.byIcon(Icons.star));
      expect(toggles, 1);
    });
  });
}
