/// Behaviour tests for the small `core/` helpers that were at zero coverage:
/// `ai_utils.dart`, `loading_indicator.dart` and
/// `constants/request_builder_constants.dart`.
///
/// The three AI state chips and the loading dialog are asserted by pumping
/// what they build — the point of each is the default it supplies (which asset,
/// which localized string) and the override that replaces it, and neither is
/// visible without rendering.
///
///   flutter test test/shared_ui/utils/small_core_utils_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds [build] inside a real tree and returns the widget it produced.
Future<Widget> pumpBuilt(
  WidgetTester tester,
  Widget Function(BuildContext) build,
) async {
  late Widget produced;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) {
          produced = build(context);
          return Scaffold(body: Center(child: produced));
        },
      ),
    ),
  );
  await tester.pump();
  return produced;
}

/// The bundled asset behind the only [Image] in the pumped tree.
String assetInTree(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  return (image.image as AssetImage).assetName;
}

void main() {
  // ==========================================================================
  group('AIUtils state chips', () {
    testWidgets('the error chip defaults to the error asset and copy', (
      tester,
    ) async {
      final w = await pumpBuilt(tester, (c) => AIUtils.getOnError(c));
      expect(w, isA<Chip>());
      expect(assetInTree(tester), AssetConstants.repliesError);
      final context = tester.element(find.byType(Scaffold));
      expect(
        find.text(Translations.of(context).somethingWentWrongError),
        findsOneWidget,
      );
    });

    testWidgets('the empty chip defaults to the empty asset and copy', (
      tester,
    ) async {
      await pumpBuilt(tester, (c) => AIUtils.getEmptyView(c));
      expect(assetInTree(tester), AssetConstants.repliesEmpty);
      final context = tester.element(find.byType(Scaffold));
      expect(
        find.text(Translations.of(context).noMessagesFound),
        findsOneWidget,
      );
    });

    testWidgets('the loading chip defaults to the spinner and copy', (
      tester,
    ) async {
      await pumpBuilt(tester, (c) => AIUtils.getLoadingIndicator(c));
      expect(assetInTree(tester), AssetConstants.spinner);
      final context = tester.element(find.byType(Scaffold));
      expect(
        find.text(Translations.of(context).generatingIceBreakers),
        findsOneWidget,
      );
    });

    testWidgets('the three chips do not share an asset', (tester) async {
      final seen = <String>{};
      for (final build in <Widget Function(BuildContext)>[
        AIUtils.getOnError,
        AIUtils.getEmptyView,
        AIUtils.getLoadingIndicator,
      ]) {
        await pumpBuilt(tester, build);
        seen.add(assetInTree(tester));
      }
      expect(seen, hasLength(3));
    });

    testWidgets('every override replaces the default on the error chip', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (c) => AIUtils.getOnError(
          c,
          backgroundColor: const Color(0xFF111111),
          shadowColor: const Color(0xFF222222),
          errorIconUrl: 'assets/icons/close.png',
          errorIconTint: const Color(0xFF333333),
          errorStateText: 'my error',
          errorTextStyle: const TextStyle(fontSize: 31),
        ),
      );
      final chip = w as Chip;
      expect(chip.backgroundColor, const Color(0xFF111111));
      expect(chip.shadowColor, const Color(0xFF222222));
      expect(assetInTree(tester), 'assets/icons/close.png');
      expect(
        tester.widget<Image>(find.byType(Image)).color,
        const Color(0xFF333333),
      );
      expect(tester.widget<Text>(find.text('my error')).style?.fontSize, 31);
    });

    testWidgets('every override replaces the default on the empty chip', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (c) => AIUtils.getEmptyView(
          c,
          backgroundColor: const Color(0xFF111111),
          shadowColor: const Color(0xFF222222),
          emptyIconUrl: 'assets/icons/close.png',
          emptyIconTint: const Color(0xFF333333),
          emptyStateText: 'nothing here',
          emptyTextStyle: const TextStyle(fontSize: 32),
        ),
      );
      expect((w as Chip).backgroundColor, const Color(0xFF111111));
      expect(assetInTree(tester), 'assets/icons/close.png');
      expect(
        tester.widget<Text>(find.text('nothing here')).style?.fontSize,
        32,
      );
    });

    testWidgets('every override replaces the default on the loading chip', (
      tester,
    ) async {
      final w = await pumpBuilt(
        tester,
        (c) => AIUtils.getLoadingIndicator(
          c,
          backgroundColor: const Color(0xFF111111),
          shadowColor: const Color(0xFF222222),
          loadingIconUrl: 'assets/icons/close.png',
          loadingIconTint: const Color(0xFF333333),
          loadingStateText: 'thinking',
          loadingTextStyle: const TextStyle(fontSize: 33),
        ),
      );
      expect((w as Chip).backgroundColor, const Color(0xFF111111));
      expect(assetInTree(tester), 'assets/icons/close.png');
      expect(tester.widget<Text>(find.text('thinking')).style?.fontSize, 33);
    });
  });

  // ==========================================================================
  group('AIUtils.getErrorText', () {
    testWidgets('defaults to the two-line apology from the theme', (
      tester,
    ) async {
      late TextStyle expected;
      final w = await pumpBuilt(tester, (c) {
        final typography = CometChatThemeHelper.getTypography(c);
        final palette = CometChatThemeHelper.getColorPalette(c);
        expected = TextStyle(
          fontSize: typography.body?.regular?.fontSize,
          fontWeight: typography.body?.regular?.fontWeight,
          fontFamily: typography.body?.regular?.fontFamily,
          color: palette.textSecondary,
        );
        return AIUtils.getErrorText(
          c,
          palette,
          typography,
          CometChatThemeHelper.getSpacing(c),
        );
      });
      expect(w, isA<Container>());
      final text = tester.widget<Text>(find.byType(Text));
      final context = tester.element(find.byType(Scaffold));
      expect(
        text.data,
        '${Translations.of(context).looksLikeSomethingWrong}\n'
        '${Translations.of(context).pleaseTryAgain}.',
      );
      expect(text.textAlign, TextAlign.center);
      expect(text.style?.color, expected.color);
      expect(text.style?.fontSize, expected.fontSize);
    });

    testWidgets('the caller\'s text and style win', (tester) async {
      await pumpBuilt(
        tester,
        (c) => AIUtils.getErrorText(
          c,
          CometChatThemeHelper.getColorPalette(c),
          CometChatThemeHelper.getTypography(c),
          CometChatThemeHelper.getSpacing(c),
          errorStateText: 'no luck',
          errorTextStyle: const TextStyle(color: Color(0xFF445566)),
        ),
      );
      final text = tester.widget<Text>(find.text('no luck'));
      expect(
        text.style?.color,
        const Color(0xFF445566),
        reason: 'the override is merged over the theme colour',
      );
    });

    test('the extension key is the one the AI extension registers', () {
      expect(AIUtils.extensionKey, 'aiExtension');
    });
  });

  // ==========================================================================
  group('showLoadingIndicatorDialog', () {
    /// Opens the dialog from a button tap so it gets a real Navigator.
    Future<void> open(
      WidgetTester tester, {
      Color? background,
      Color? shadowColor,
      Color? progressIndicatorColor,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showLoadingIndicatorDialog(
                  context,
                  background: background,
                  shadowColor: shadowColor,
                  progressIndicatorColor: progressIndicatorColor,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // The dialog holds a CircularProgressIndicator, which never stops
      // animating, so pumpAndSettle would time out. Two frames is enough for
      // the route transition to put it on screen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('shows a spinner in a dialog with the default colours', (
      tester,
    ) async {
      await open(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        const Color(0xff3399FF),
      );
      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor,
        const Color(0xffFFFFFF),
      );
    });

    testWidgets('the caller\'s colours replace the defaults', (tester) async {
      await open(
        tester,
        background: const Color(0xFF101010),
        shadowColor: const Color(0xFF202020),
        progressIndicatorColor: const Color(0xFF303030),
      );
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        const Color(0xFF303030),
      );
      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor,
        const Color(0xFF101010),
      );
    });

    testWidgets('it cannot be dismissed by tapping the barrier', (
      tester,
    ) async {
      // It is a blocking progress dialog; the caller closes it.
      await open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  // ==========================================================================
  group('RequestBuilderConstants', () {
    test('every default builder asks for 30 at a time', () {
      expect(RequestBuilderConstants.getDefaultUsersRequestBuilder().limit, 30);
      expect(
        RequestBuilderConstants.getDefaultGroupsRequestBuilder().limit,
        30,
      );
      expect(
        RequestBuilderConstants.getDefaultMessagesRequestBuilder().limit,
        30,
      );
      expect(
        RequestBuilderConstants.getDefaultConversationsRequestBuilder().limit,
        30,
      );
    });

    test('the message builder hides thread replies', () {
      // A chat list that shows replies inline duplicates every threaded
      // message, so this default is load-bearing.
      expect(
        RequestBuilderConstants.getDefaultMessagesRequestBuilder().hideReplies,
        isTrue,
      );
    });

    test('each call hands back a fresh builder, not a shared one', () {
      // Callers mutate what they get back, so a cached instance would leak
      // one screen's filters into the next.
      final a = RequestBuilderConstants.getDefaultUsersRequestBuilder()
        ..limit = 5;
      final b = RequestBuilderConstants.getDefaultUsersRequestBuilder();
      expect(b.limit, 30);
      expect(identical(a, b), isFalse);
    });
  });
}
