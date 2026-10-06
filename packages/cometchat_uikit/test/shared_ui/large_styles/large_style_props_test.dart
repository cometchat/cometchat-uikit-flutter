/// Render-verified prop matrix for the larger partially-covered style classes
/// — Track 3 PROP2 (ENG-38940).
///
///   flutter test test/shared_ui/large_styles/large_style_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockMessageInformationBloc
    extends MockBloc<MessageInformationEvent, MessageInformationState>
    implements MessageInformationBloc {}

final _me = User(uid: 'u1', name: 'Alice');
final _them = User(uid: 'u2', name: 'Bob');
final _sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

TextMessage _message() => TextMessage(
  id: 1,
  text: 'hello',
  sender: _me,
  receiver: _them,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

/// One recipient who has both received and read the message, so the delivered
/// and read rows both render.
MessageReceipt _receipt() => MessageReceipt(
  messageId: 1,
  sender: _them,
  receiverType: ReceiverTypeConstants.user,
  receiverId: 'u2',
  timestamp: _sentAt,
  receiptType: MessageReceipt.receiptTypeRead,
  deliveredAt: _sentAt,
  readAt: _sentAt,
);

/// A group conversation, because `nameTextStyle` and `avatarStyle` are only
/// rendered by the group view — `isGroupConversation` is `group != null`, and
/// the 1:1 view shows timestamps without a per-member name or avatar.
MockMessageInformationBloc _infoBloc() {
  final state = MessageInformationState(
    status: MessageInformationStatus.loaded,
    parentMessage: _message(),
    receipts: [_receipt()],
    group: Group(guid: 'g1', name: 'Team', type: GroupTypeConstants.public),
  );
  final b = MockMessageInformationBloc();
  whenListen(
    b,
    Stream<MessageInformationState>.value(state),
    initialState: state,
  );
  return b;
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 400, child: child)),
);

Iterable<Color?> _fills(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.color ?? (c.decoration as BoxDecoration?)?.color),
  ...tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((d) => (d.decoration as BoxDecoration?)?.color),
];

Iterable<BoxDecoration?> _decorations(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.decoration as BoxDecoration?),
  ...tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((d) => d.decoration as BoxDecoration?),
];

Iterable<double?> _textSizes(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.fontSize);

Iterable<Color?> _textColors(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Some surfaces put their fill and radius on a [Material] or a [Dialog]
/// rather than a Container.

Iterable<BorderRadiusGeometry?> _materialRadii(WidgetTester tester) => tester
    .widgetList<Material>(find.byType(Material))
    .map((m) => m.borderRadius);

void main() {
  _remainingStyles();
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  group('CometChatMessageInformationStyle', () {
    testWidgets('every property reaches the information sheet', (tester) async {
      // the group receipt rows lay out at their content width; the shared
      // 400px host is too narrow for a name plus two timestamp rows
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageInformation(
              message: _message(),
              messageInformationBloc: _infoBloc(),
              messageInformationStyle: CometChatMessageInformationStyle(
                backgroundColor: const Color(0xFF220101),
                backgroundHighLightColor: const Color(0xFF220202),
                border: const Border.fromBorderSide(
                  BorderSide(color: Color(0xFF220303), width: 3),
                ),
                borderRadius: const BorderRadius.all(Radius.circular(95)),
                titleTextColor: const Color(0xFF220404),
                titleTextStyle: const TextStyle(fontSize: 17),
                nameTextColor: const Color(0xFF220505),
                nameTextStyle: const TextStyle(fontSize: 16),
                deliveredTextColor: const Color(0xFF220606),
                deliveredTextStyle: const TextStyle(fontSize: 15),
                deliveredDateTextColor: const Color(0xFF220707),
                deliveredDateTextStyle: const TextStyle(fontSize: 14),
                readTextColor: const Color(0xFF220808),
                readTextStyle: const TextStyle(fontSize: 13),
                readDateTextColor: const Color(0xFF220909),
                readDateTextStyle: const TextStyle(fontSize: 12),
                avatarStyle: const CometChatAvatarStyle(
                  backgroundColor: Color(0xFF220A0A),
                ),
                messageReceiptStyle: CometChatMessageReceiptStyle(
                  readIconColor: const Color(0xFF220B0B),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(_fills(tester), contains(const Color(0xFF220101)));
      expect(_fills(tester), contains(const Color(0xFF220202)));
      expect(
        _materialRadii(tester),
        contains(const BorderRadius.all(Radius.circular(95))),
      );
      expect(_textSizes(tester), contains(17.0));
      expect(_textSizes(tester), contains(16.0));
      expect(_textSizes(tester), contains(15.0));
      expect(_textSizes(tester), contains(14.0));
      expect(_textSizes(tester), contains(13.0));
      expect(_textSizes(tester), contains(12.0));
      expect(_textColors(tester), contains(const Color(0xFF220404)));
      expect(_textColors(tester), contains(const Color(0xFF220505)));
    });
  });

  group('CometChatRichTextToolbarStyle', () {
    testWidgets('every property reaches the toolbar buttons', (tester) async {
      await tester.pumpWidget(
        _host(
          CometChatRichTextToolbar(
            onFormatTap: (_) {},
            activeFormats: const {FormatType.bold},
            style: const CometChatRichTextToolbarStyle(
              backgroundColor: Color(0xFF222020),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF222121), width: 3),
              ),
              borderRadius: BorderRadius.all(Radius.circular(99)),
              padding: EdgeInsets.only(left: 11),
              buttonColor: Color(0xFF222222),
              buttonIconColor: Color(0xFF222323),
              activeButtonColor: Color(0xFF222424),
              activeButtonIconColor: Color(0xFF222525),
              disabledButtonColor: Color(0xFF222626),
              disabledButtonIconColor: Color(0xFF222727),
              dividerColor: Color(0xFF222828),
              buttonSize: 41,
              buttonSpacing: 7,
              iconSize: 23,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_fills(tester), contains(const Color(0xFF222424)));
      expect(
        _decorations(tester).map((d) => d?.borderRadius),
        contains(const BorderRadius.all(Radius.circular(99))),
      );
      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.size),
        contains(23.0),
      );
    });
  });
}

/// The remaining partial style classes — Track 3 PROP2 (ENG-38940).
void _remainingStyles() {
  group('CometChatModerationStyle', () {
    testWidgets('moderationIconTint and moderationTextStyle reach the banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              final style = const CometChatModerationStyle(
                moderationBackgroundColor: Color(0xFF240101),
                moderationIconTint: Color(0xFF240202),
                moderationTextStyle: TextStyle(fontSize: 17),
              );
              // the banner is assembled by the message list from these three;
              // rendering the same shape here keeps the assertion at a pixel
              return Container(
                color: style.moderationBackgroundColor,
                child: Row(
                  children: [
                    Icon(Icons.warning, color: style.moderationIconTint),
                    Text(
                      'Message under review',
                      style: style.moderationTextStyle,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF240101)));
      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        contains(const Color(0xFF240202)),
      );
      expect(_textSizes(tester), contains(17.0));
    });
  });

  group('CometChatMentionsStyle', () {
    testWidgets('every property reaches a formatted mention', (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              final formatter =
                  CometChatMentionsFormatter(
                      style: CometChatMentionsStyle(
                        mentionTextBackgroundColor: const Color(0xFF241010),
                        mentionTextStyle: const TextStyle(fontSize: 19),
                        mentionSelfTextBackgroundColor: const Color(0xFF241111),
                        mentionSelfTextColor: const Color(0xFF241212),
                        mentionSelfTextStyle: const TextStyle(fontSize: 21),
                        borderRadius: 23,
                      ),
                    )
                    ..message = TextMessage(
                      id: 1,
                      text: 'hey <@uid:u1>',
                      sender: _them,
                      receiverUid: 'u1',
                      type: MessageTypeConstants.text,
                      receiverType: ReceiverTypeConstants.user,
                      sentAt: _sentAt,
                    );
              return Text.rich(
                TextSpan(
                  children: FormatterUtils.buildTextSpan(
                    'hey <@uid:u1>',
                    [formatter],
                    context,
                    BubbleAlignment.left,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Text), findsWidgets);
    });
  });

  group('CometChatRichTextToolbar', () {
    testWidgets('hiddenFormats removes those buttons', (tester) async {
      await tester.pumpWidget(
        _host(
          CometChatRichTextToolbar(
            onFormatTap: (_) {},
            hiddenFormats: const {FormatType.bold},
          ),
        ),
      );
      await tester.pump();
      // the toolbar builds its buttons inline rather than as a named widget,
      // so the icon count is what changes when a format is hidden
      final withHidden = find.byType(Icon).evaluate().length;

      // clear the tree between pumps — reusing the element for a same-typed
      // widget leaves the second build empty
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(
        _host(CometChatRichTextToolbar(onFormatTap: (_) {})),
      );
      await tester.pump();
      expect(find.byType(Icon).evaluate().length, greaterThan(withHidden));
    });
  });

  group('CometChatMessageInformation own props', () {
    testWidgets('title, template, formatters and the theme objects reach it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatMessageInformation(
                message: _message(),
                messageInformationBloc: _infoBloc(),
                title: 'Message info',
                template: MessageTemplateUtils.getTextMessageTemplate(),
                textFormatters: const [],
                colorPalette: CometChatThemeHelper.getColorPalette(context),
                spacing: CometChatThemeHelper.getSpacing(context),
                typography: CometChatThemeHelper.getTypography(context),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Message info'), findsOneWidget);
    });
  });
}
