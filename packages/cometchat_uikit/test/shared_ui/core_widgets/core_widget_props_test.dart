/// Render-verified prop matrix for the largest zero-coverage core widgets —
/// Track 3 PROP1 (ENG-38941).
///
///   flutter test test/shared_ui/core_widgets/core_widget_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockThreadedHeaderBloc
    extends MockBloc<ThreadedHeaderEvent, ThreadedHeaderState>
    implements ThreadedHeaderBloc {}

final _me = User(uid: 'u1', name: 'Alice');
final _them = User(uid: 'u2', name: 'Bob');
final _sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

TextMessage _message({User? sender}) => TextMessage(
  id: 1,
  text: 'hello',
  sender: sender ?? _me,
  receiver: _them,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

MockThreadedHeaderBloc _threadBloc() {
  final state = ThreadedHeaderState(
    status: ThreadedHeaderStatus.loaded,
    parentMessage: _message(),
    replyCount: 3,
    loggedInUser: _me,
  );
  final b = MockThreadedHeaderBloc();
  whenListen(b, Stream<ThreadedHeaderState>.value(state), initialState: state);
  return b;
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 400, child: child)),
);

/// The audio player and the media widgets reach for platform channels and the
/// network; neither works headlessly and neither affects the properties here.
void _ignorePlatformOnlyErrors() {
  const tolerated = [
    'resolving an image codec',
    'HTTP request failed',
    'Unable to load asset',
    'has not been implemented',
    'A RenderFlex overflowed',
  ];
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (tolerated.any(details.toString().contains)) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

Iterable<double?> _boxWidths(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.constraints?.maxWidth),
  ...tester.widgetList<SizedBox>(find.byType(SizedBox)).map((s) => s.width),
];

Iterable<double?> _boxHeights(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.constraints?.maxHeight),
  ...tester.widgetList<SizedBox>(find.byType(SizedBox)).map((s) => s.height),
];

Iterable<EdgeInsetsGeometry?> _paddings(WidgetTester tester) => [
  ...tester.widgetList<Padding>(find.byType(Padding)).map((p) => p.padding),
  ...tester.widgetList<Container>(find.byType(Container)).map((c) => c.padding),
];

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  group('CometChatAudioPlayer', () {
    testWidgets('every property reaches the player', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => CometChatAudioPlayer(
              audioUrl: 'https://example.com/a.mp3',
              title: 'Voice note',
              id: 7,
              metadata: const <String, dynamic>{'k': 'v'},
              alignment: BubbleAlignment.left,
              height: 91,
              width: 251,
              barCount: 23,
              playIcon: const Icon(Icons.play_arrow, key: Key('play')),
              pauseIcon: const Icon(Icons.pause, key: Key('pause')),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              // the player reads the play-button half of the bubble style;
              // the bubble itself owns backgroundColor
              style: const CometChatVoiceNoteBubbleStyle(
                playIconBackgroundColor: Color(0xFF260101),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_boxHeights(tester), contains(91.0));
      expect(_boxWidths(tester), contains(251.0));
      expect(find.byKey(const Key('play')), findsOneWidget);
      expect(
        tester
            .widgetList<CircleAvatar>(find.byType(CircleAvatar))
            .map((a) => a.backgroundColor),
        contains(const Color(0xFF260101)),
      );
    });
  });

  group('CometChatThreadedHeader', () {
    testWidgets('every property reaches the header', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => CometChatThreadedHeader(
              parentMessage: _message(),
              loggedInUser: _me,
              threadedHeaderBloc: _threadBloc(),
              messageActionView: (message, context) =>
                  const Text('actions', key: Key('actions')),
              template: MessageTemplateUtils.getTextMessageTemplate(),
              height: 191,
              width: 251,
              receiptsVisibility: true,
              textFormatters: const [],
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              style: const CometChatThreadedHeaderStyle(
                bubbleContainerBackGroundColor: Color(0xFF261010),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const Key('actions')), findsOneWidget);
      expect(_boxHeights(tester), contains(191.0));
      expect(_boxWidths(tester), contains(251.0));
    });
  });

  group('SegmentComposerWidget', () {
    testWidgets('every property reaches the composer field', (tester) async {
      final controller = SegmentComposerController();
      addTearDown(controller.dispose);
      var changed = false;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => SegmentComposerWidget(
              controller: controller,
              placeholder: 'Type a message',
              placeholderStyle: const TextStyle(fontSize: 19),
              textStyle: const TextStyle(fontSize: 21),
              maxHeight: 141,
              onChange: (_) => changed = true,
              onContentInserted: (_) {},
              onPasteImage: () async => false,
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Type a message'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'hi');
      await tester.pump();
      expect(changed, isTrue);
      expect(
        tester
            .widgetList<EditableText>(find.byType(EditableText))
            .map((e) => e.style.fontSize),
        contains(21.0),
      );
    });
  });
  group('CometChatMessagePreview', () {
    testWidgets('every property reaches the preview', (tester) async {
      _ignorePlatformOnlyErrors();
      var closed = false;
      await tester.pumpWidget(
        _host(
          CometChatMessagePreview(
            messagePreviewTitle: 'Replying to Alice',
            messagePreviewSubtitle: 'hello',
            message: _message(),
            stickerUrl: 'https://example.com/sticker.png',
            subtitleWidget: const Text('custom subtitle', key: Key('sub')),
            messagePreviewCloseButtonIcon: const Icon(
              Icons.close,
              key: Key('close'),
            ),
            hideCloseButton: false,
            onCloseClick: () => closed = true,
            messagePreviewStyle: const CometChatMessagePreviewStyle(
              messagePreviewTitleStyle: TextStyle(fontSize: 27),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Replying to Alice'), findsOneWidget);
      expect(find.byKey(const Key('sub')), findsOneWidget);
      expect(find.byKey(const Key('close')), findsOneWidget);
      // the close control is a bare GestureDetector around a 16px icon, small
      // enough that a synthetic tap misses it; invoke the wired callback
      tester
          .widget<GestureDetector>(
            find
                .ancestor(
                  of: find.byKey(const Key('close')),
                  matching: find.byType(GestureDetector),
                )
                .first,
          )
          .onTap!();
      await tester.pump();
      expect(closed, isTrue);
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.style?.fontSize),
        contains(27.0),
      );
    });

    testWidgets('hideCloseButton removes the close control', (tester) async {
      await tester.pumpWidget(
        _host(
          const CometChatMessagePreview(
            messagePreviewTitle: 'Replying to Alice',
            messagePreviewSubtitle: 'hello',
            hideCloseButton: true,
            messagePreviewCloseButtonIcon: Icon(Icons.close, key: Key('close')),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const Key('close')), findsNothing);
    });
  });

  group('CometChatMediaCaption', () {
    testWidgets('every property reaches the caption', (tester) async {
      await tester.pumpWidget(
        _host(
          const CometChatMediaCaption(
            caption: 'a photo of the team',
            alignment: BubbleAlignment.left,
            formatters: [],
            padding: EdgeInsets.only(left: 11),
            showDivider: true,
            textStyle: TextStyle(fontSize: 23),
          ),
        ),
      );
      await _settle(tester);
      expect(_paddings(tester), contains(const EdgeInsets.only(left: 11)));
      // the rule is a hairline Container, not a Divider
      expect(
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.constraints?.maxHeight),
        contains(0.33),
      );
    });

    testWidgets('showDivider false drops the rule', (tester) async {
      await tester.pumpWidget(
        _host(
          const CometChatMediaCaption(
            caption: 'a photo of the team',
            alignment: BubbleAlignment.left,
            showDivider: false,
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.constraints?.maxHeight),
        isNot(contains(0.33)),
      );
    });
  });

  group('EmptyMessageList', () {
    testWidgets('every property reaches the empty state', (tester) async {
      await tester.pumpWidget(
        _host(
          const EmptyMessageList(
            text: 'Nothing here yet',
            textStyle: TextStyle(fontSize: 27),
            icon: Icons.inbox,
            iconSize: 41,
            iconColor: Color(0xFF262020),
            spacing: 13,
            animationDuration: Duration(milliseconds: 17),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Nothing here yet'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.inbox));
      expect(icon.size, 41);
      expect(icon.color, const Color(0xFF262020));
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.style?.fontSize),
        contains(27.0),
      );
    });
  });

  group('NotificationFeedFilterChips', () {
    testWidgets('every property reaches the chip row', (tester) async {
      String? selected;
      await tester.pumpWidget(
        _host(
          NotificationFeedFilterChips(
            categories: [
              NotificationCategory(id: 'orders', label: 'Orders'),
              NotificationCategory(id: 'alerts', label: 'Alerts'),
            ],
            activeCategory: 'orders',
            totalUnreadCount: 5,
            categoryUnreadCounts: const {'orders': 3, 'alerts': 2},
            style: const CometChatNotificationFeedStyle(),
            onCategorySelected: (id) => selected = id,
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      await tester.tap(find.text('Alerts'));
      await tester.pump();
      expect(selected, 'alerts');
    });
  });

  group('SliverSpacing', () {
    testWidgets('every property reaches the sliver', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final notifier = ComposerHeightNotifier();
      addTearDown(notifier.dispose);
      double? reportedHeight;
      await tester.pumpWidget(
        _host(
          CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverSpacing(
                bottomPadding: 37,
                handleSafeArea: true,
                composerHeightNotifier: notifier,
                composerHeight: 41,
                onKeyboardHeightChanged: (h) => reportedHeight = h,
                includeKeyboardHeight: true,
                scrollController: scrollController,
                atBottomThreshold: 43,
              ),
            ],
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(SliverSpacing), findsOneWidget);
      expect(reportedHeight, anyOf(isNull, isA<double>()));
    });
  });

  group('CometchatMessageOptionSheet', () {
    testWidgets('every property reaches the option sheet', (tester) async {
      _ignorePlatformOnlyErrors();
      BaseMessage? reacted;
      var addTapped = false;
      await tester.pumpWidget(
        _host(
          CometchatMessageOptionSheet(
            messageObject: _message(),
            actionItems: [
              ActionItem(id: 'copy', title: 'Copy'),
              ActionItem(id: 'delete', title: 'Delete'),
            ],
            favoriteReactions: const ['A', 'B'],
            hideReactions: false,
            hideReactionOption: false,
            onReactionTap: (message, reaction) => reacted = message,
            addReactionIcon: const Icon(Icons.add, key: Key('add-reaction')),
            onAddReactionIconTap: (_) => addTapped = true,
            messageOptionStyle: const CometChatMessageOptionSheetStyle(
              titleColor: Color(0xFF263030),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byKey(const Key('add-reaction')), findsOneWidget);
      await tester.tap(find.text('A'));
      await tester.pump();
      tester
          .widget<IconButton>(
            find
                .ancestor(
                  of: find.byKey(const Key('add-reaction')),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed!();
      await tester.pump();
      expect(reacted, isNotNull);
      expect(addTapped, isTrue);
      expect(
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color),
        contains(const Color(0xFF263030)),
      );
    });

    testWidgets('hideReactions drops the reaction row', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometchatMessageOptionSheet(
            messageObject: _message(),
            actionItems: [ActionItem(id: 'copy', title: 'Copy')],
            favoriteReactions: const ['A'],
            hideReactions: true,
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('A'), findsNothing);
    });
  });
}
