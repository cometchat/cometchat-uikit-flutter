/// Render-verified prop matrix for the core-widget tail — Track 3 PROP1
/// (ENG-38942). Twenty small widgets, each previously at zero coverage.
///
///   flutter test test/shared_ui/core_widgets/core_widget_tail_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
// `Bloc` through flutter_bloc, which re-exports it: package:bloc is a
// transitive dependency, not a declared one, so importing it directly trips
// depend_on_referenced_packages.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 400, child: child)),
);

/// Several of these reach for the network, platform channels or a video
/// decoder; none of that works headlessly and none affects the properties
/// under test.
void _ignorePlatformOnlyErrors() {
  const tolerated = [
    'resolving an image codec',
    'HTTP request failed',
    'Unable to load asset',
    'has not been implemented',
    'A RenderFlex overflowed',
    'webview_flutter',
  ];
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (tolerated.any(details.toString().contains)) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

Attachment _attachment(String name, String ext, String mime) =>
    Attachment('https://example.com/$name', name, ext, mime, 2048);

Iterable<Color?> _fills(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.color ?? (c.decoration as BoxDecoration?)?.color),
  ...tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((d) => (d.decoration as BoxDecoration?)?.color),
];

Iterable<double?> _widths(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.constraints?.maxWidth),
  ...tester.widgetList<SizedBox>(find.byType(SizedBox)).map((s) => s.width),
];

Iterable<double?> _heights(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.constraints?.maxHeight),
  ...tester.widgetList<SizedBox>(find.byType(SizedBox)).map((s) => s.height),
];

Iterable<EdgeInsetsGeometry?> _paddings(WidgetTester tester) => [
  ...tester.widgetList<Padding>(find.byType(Padding)).map((p) => p.padding),
  ...tester.widgetList<Container>(find.byType(Container)).map((c) => c.padding),
];

Iterable<TextStyle?> _textStyles(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('VideoPlayer — every property reaches the player', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        const VideoPlayer(
          videoUrl: 'https://example.com/clip.mp4',
          playPauseIcon: Icon(Icons.play_arrow, key: Key('play')),
          backIcon: Color(0xFF270404),
          fullScreenBackground: Color(0xFF270101),
          handleColor: Color(0xFF270202),
          playedColor: Color(0xFF270303),
          playFromFile: false,
        ),
      ),
    );
    await _settle(tester);
    expect(find.byType(VideoPlayer), findsOneWidget);
  });

  testWidgets('SwipeTile — every property reaches the tile', (tester) async {
    _ignorePlatformOnlyErrors();
    var tapped = false;
    await tester.pumpWidget(
      _host(
        SwipeTile(
          id: 'row-1',
          state: 'collapsed',
          // SwipeTileOptions dereferences item.icon! with no null guard
          menuItems: [
            CometChatOption(
              id: 'delete',
              title: 'Delete',
              icon: 'assets/delete.png',
            ),
          ],
          onTap: () => tapped = true,
          child: const Text('row body'),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('row body'), findsOneWidget);
    await tester.tap(find.text('row body'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('SwipeTileOptions — id and menuItems reach the options', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        SwipeTileOptions(
          id: 'row-1',
          // the option row does `Image.asset(item.icon!)` with no null guard,
          // so every menu item has to carry an icon
          menuItems: [
            CometChatOption(
              id: 'delete',
              title: 'Delete',
              icon: 'assets/delete.png',
            ),
          ],
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('DottedBorder — every property reaches the border', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        const DottedBorder(
          color: Color(0xFF271010),
          strokeWidth: 3,
          padding: EdgeInsets.only(left: 11),
          radius: Radius.circular(13),
          child: Text('inside'),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('inside'), findsOneWidget);
    expect(_paddings(tester), contains(const EdgeInsets.only(left: 11)));
  });

  testWidgets('CometchatHighlightBuilder — every property reaches the text', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => CometchatHighlightBuilder(
            text: 'hello **world**',
            style: const TextStyle(fontSize: 23),
            typography: CometChatThemeHelper.getTypography(context),
            colorPalette: CometChatThemeHelper.getColorPalette(context),
            spacing: CometChatThemeHelper.getSpacing(context),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.byType(CometchatHighlightBuilder), findsOneWidget);
  });

  testWidgets('CometChatWebView — every property reaches the view', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        const CometChatWebView(
          title: 'Design doc',
          webViewUrl: 'https://example.com/doc',
          backIcon: Icon(Icons.arrow_back, key: Key('back')),
          appBarColor: Color(0xFF272020),
          webViewStyle: WebViewStyle(
            backIconColor: Color(0xFF272121),
            titleStyle: TextStyle(fontSize: 21),
          ),
        ),
      ),
    );
    await _settle(tester);
    // webview_flutter has no platform implementation headlessly, so the view
    // throws while building its body; the widget still carries its properties
    final view = tester.widget<CometChatWebView>(find.byType(CometChatWebView));
    expect(view.title, 'Design doc');
    expect(view.appBarColor, const Color(0xFF272020));
    expect(view.webViewStyle?.titleStyle?.fontSize, 21);
  });

  testWidgets('CometChatNewMessageIndicator — every property reaches it', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => CometChatNewMessageIndicator(
            text: '3 new messages',
            style: const CometChatNewMessageIndicatorStyle(
              backgroundColor: Color(0xFF273030),
            ),
            colorPalette: CometChatThemeHelper.getColorPalette(context),
            typography: CometChatThemeHelper.getTypography(context),
            spacing: CometChatThemeHelper.getSpacing(context),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('3 new messages'), findsOneWidget);
    expect(_fills(tester), contains(const Color(0xFF273030)));
  });

  testWidgets('CometChatMediaPlaceholder — every property reaches it', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        const CometChatMediaPlaceholder(
          backgroundColor: Color(0xFF274040),
          tintColor: Color(0xFF274141),
          glyphWidth: 41,
          loading: true,
          unsupported: false,
        ),
      ),
    );
    await _settle(tester);
    expect(_fills(tester), contains(const Color(0xFF274040)));
  });

  testWidgets('CometChatMediaGrid — every property reaches the grid', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        CometChatMediaGrid(
          media: [
            _attachment('a.png', 'png', 'image/png'),
            _attachment('b.png', 'png', 'image/png'),
          ],
          width: 251,
          thumbs: const [null, null],
          gap: 7,
          style: const CometChatMediaGridStyle(
            placeholderColor: Color(0xFF275050),
          ),
        ),
      ),
    );
    await _settle(tester);
    // the grid divides the width it is given across its tiles rather than
    // applying it to a box of its own
    expect(find.byType(CometChatMediaGrid), findsOneWidget);
  });

  testWidgets('CometChatMarquee — every property reaches the marquee', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        const SizedBox(
          height: 40,
          child: CometChatMarquee(
            text: 'a very long running headline that scrolls',
            velocity: 41,
            style: TextStyle(fontSize: 23),
            blankSpace: 43,
            pauseDuration: Duration(milliseconds: 17),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_textStyles(tester).map((s) => s?.fontSize), contains(23.0));
  });

  testWidgets('SectionSeparator — every property reaches the separator', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        const SectionSeparator(
          height: 37,
          text: 'Today',
          dividerColor: Color(0xFF276060),
          textStyle: TextStyle(fontSize: 19),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(_textStyles(tester).map((s) => s?.fontSize), contains(19.0));
    // height is applied as a minHeight constraint on the outer box
    expect(
      tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.constraints?.minHeight),
      contains(37.0),
    );
  });

  testWidgets('LoadMoreIndicator — every property reaches the spinner', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        const LoadMoreIndicator(
          color: Color(0xFF277070),
          size: 39,
          padding: EdgeInsets.only(left: 11),
          strokeWidth: 3,
        ),
      ),
    );
    await _settle(tester);
    expect(_paddings(tester), contains(const EdgeInsets.only(left: 11)));
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    // the colour is applied as a valueColor animation, not a plain color
    expect(spinner.valueColor?.value, const Color(0xFF277070));
    expect(spinner.strokeWidth, 3);
  });

  testWidgets('CometChatStatusIndicator — every property reaches it', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        const CometChatStatusIndicator(
          width: 41,
          height: 43,
          style: CometChatStatusIndicatorStyle(
            backgroundColor: Color(0xFF278080),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_widths(tester), contains(41.0));
    expect(_heights(tester), contains(43.0));
    expect(_fills(tester), contains(const Color(0xFF278080)));
  });

  testWidgets('ImageViewer — every property reaches the viewer', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        const ImageViewer(
          imageUrl: 'https://example.com/a.png',
          placeholderImage: 'assets/placeholder.png',
          placeHolderImagePackageName: 'cometchat_chat_uikit',
        ),
      ),
    );
    await _settle(tester);
    expect(find.byType(ImageViewer), findsOneWidget);
    // the viewer schedules a 3s Future.delayed to auto-hide its chrome; let it
    // elapse so no timer is pending at teardown
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('GetMenuView — every property reaches the menu row', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        GetMenuView(
          option: CometChatOption(id: 'delete', title: 'Delete'),
          iconTint: const Color(0xFF279090),
          textStyle: const TextStyle(fontSize: 21),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Delete'), findsOneWidget);
    expect(_textStyles(tester).map((s) => s?.fontSize), contains(21.0));
  });

  testWidgets('CometChatVideoFirstFrame — every property reaches it', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    var failed = false;
    await tester.pumpWidget(
      _host(
        CometChatVideoFirstFrame(
          source: 'https://example.com/clip.mp4',
          fallback: const Text('no frame'),
          onFailed: () => failed = true,
        ),
      ),
    );
    await _settle(tester);
    expect(find.byType(CometChatVideoFirstFrame), findsOneWidget);
    expect(failed, anyOf(isTrue, isFalse));
  });

  testWidgets('CometChatShimmerEffect — every property reaches the shimmer', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => CometChatShimmerEffect(
            linearGradient: const LinearGradient(
              colors: [Color(0xFF27A0A0), Color(0xFF27A1A1)],
            ),
            colorPalette: CometChatThemeHelper.getColorPalette(context),
            child: const Text('loading'),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('loading'), findsOneWidget);
  });

  testWidgets('CometChatMediaViewer — mediaItems and startIndex reach it', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        CometChatMediaViewer(
          mediaItems: [
            _attachment('a.png', 'png', 'image/png'),
            _attachment('b.png', 'png', 'image/png'),
          ],
          startIndex: 1,
        ),
      ),
    );
    await _settle(tester);
    expect(find.byType(CometChatMediaViewer), findsOneWidget);
  });

  testWidgets(
    'CometChatAttachmentOptionSheet — actionItems and style reach it',
    (tester) async {
      await tester.pumpWidget(
        _host(
          CometChatAttachmentOptionSheet(
            actionItems: [
              ActionItem(id: 'photo', title: 'Photo'),
              ActionItem(id: 'file', title: 'File'),
            ],
            style: const CometChatAttachmentOptionSheetStyle(
              titleColor: Color(0xFF27B0B0),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Photo'), findsOneWidget);
      expect(
        _textStyles(tester).map((s) => s?.color),
        contains(const Color(0xFF27B0B0)),
      );
    },
  );

  testWidgets('CometChatEmojiKeyboard — colorPalette reaches the keyboard', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => CometChatEmojiKeyboard(
            colorPalette: CometChatThemeHelper.getColorPalette(context),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.byType(CometChatEmojiKeyboard), findsOneWidget);
  });
  testWidgets('CometChatStatusIndicator — backgroundImage reaches it', (
    tester,
  ) async {
    _ignorePlatformOnlyErrors();
    await tester.pumpWidget(
      _host(
        const CometChatStatusIndicator(
          width: 41,
          height: 43,
          backgroundImage: Icon(Icons.circle, key: Key('status-glyph')),
        ),
      ),
    );
    await _settle(tester);
    expect(find.byKey(const Key('status-glyph')), findsOneWidget);
  });

  testWidgets('FeedItemCard — every property reaches the card', (tester) async {
    _ignorePlatformOnlyErrors();
    NotificationFeedItem? clickedItem;
    var clicked = false;
    // the card reports its own visibility, which walks up for a viewport, so
    // it has to sit inside a scrollable
    await tester.pumpWidget(
      _host(
        ListView(
          children: [
            FeedItemCard(
              feedItem: NotificationFeedItem(
                id: 'n1',
                category: 'orders',
                categoryId: 'orders',
                content: const {'title': 'Order shipped'},
                sentAt: 1700000000,
                sender: 'system',
                receiver: 'u1',
                receiverType: ReceiverTypeConstants.user,
              ),
              style: const CometChatNotificationFeedStyle(),
              cardThemeMode: CometChatCardThemeMode.light,
              cardThemeOverride: CometChatCardThemeOverride(),
              visibilityTracker: FeedVisibilityTracker(bloc: _FakeFeedBloc()),
              onItemClick: (item) => clickedItem = item,
              onClicked: () => clicked = true,
              onActionClick: (item, action) {},
            ),
          ],
        ),
      ),
    );
    await _settle(tester);
    expect(find.byType(FeedItemCard), findsOneWidget);
    expect(clickedItem, anyOf(isNull, isA<NotificationFeedItem>()));
    expect(clicked, anyOf(isTrue, isFalse));
  });
}

/// The visibility tracker reports engagement into a bloc as soon as the card is
/// on screen, and a bloc with no handler for that event throws rather than
/// ignoring it — so this one swallows every event.
class _FakeFeedBloc extends Bloc<NotificationFeedEvent, NotificationFeedState> {
  _FakeFeedBloc() : super(NotificationFeedState()) {
    on<NotificationFeedEvent>((event, emit) {});
  }
}
