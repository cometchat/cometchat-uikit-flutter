/// [AIUtils]' three chip builders.
///
/// `getErrorText` runs from the AI panels, but `getOnError`, `getEmptyView`
/// and `getLoadingIndicator` are public helpers that nothing in the Kit calls
/// any more — so none of them had ever been built. Each is the same shape: a
/// [Chip] holding an icon and a caption, with every part overridable.
///
///   flutter test test/shared_ui/utils/ai_utils_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bg = Color(0xFF111213);
const _shadow = Color(0xFF212223);
const _tint = Color(0xFF313233);
const _text = TextStyle(color: Color(0xFF414243), fontSize: 19);

Future<void> _pump(WidgetTester tester, WidgetBuilder builder) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Builder(builder: builder)),
    ),
  );
  await tester.pump();
}

Chip _chip(WidgetTester tester) => tester.widget<Chip>(find.byType(Chip));

Image _image(WidgetTester tester) => tester.widget<Image>(find.byType(Image));

void main() {
  group('getOnError', () {
    testWidgets('defaults to the shipped error art and copy', (tester) async {
      await _pump(tester, (context) => AIUtils.getOnError(context));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        (_image(tester).image as AssetImage).assetName,
        AssetConstants.repliesError,
      );
      expect((_image(tester).image as AssetImage).package, isNotNull);
      expect(_chip(tester).backgroundColor, isNull);
    });

    testWidgets('every override reaches the chip', (tester) async {
      await _pump(
        tester,
        (context) => AIUtils.getOnError(
          context,
          backgroundColor: _bg,
          shadowColor: _shadow,
          // A real asset that is NOT the default, so the override is proven
          // and the image still resolves inside the test bundle.
          errorIconUrl: AssetConstants.repliesEmpty,
          errorIconPackageName: UIConstants.packageName,
          errorStateText: 'Could not reach the assistant',
          errorIconTint: _tint,
          errorTextStyle: _text,
        ),
      );

      expect(_chip(tester).backgroundColor, _bg);
      expect(_chip(tester).shadowColor, _shadow);
      expect(_image(tester).color, _tint);
      expect(
        (_image(tester).image as AssetImage).assetName,
        AssetConstants.repliesEmpty,
      );
      expect(
        (_image(tester).image as AssetImage).package,
        UIConstants.packageName,
      );
      final label = tester.widget<Text>(
        find.text('Could not reach the assistant'),
      );
      expect(label.style, _text);
    });
  });

  group('getEmptyView', () {
    testWidgets('defaults to the empty art and copy', (tester) async {
      await _pump(tester, (context) => AIUtils.getEmptyView(context));

      expect(find.text('No messages found'), findsOneWidget);
      expect(
        (_image(tester).image as AssetImage).assetName,
        AssetConstants.repliesEmpty,
      );
    });

    testWidgets('every override reaches the chip', (tester) async {
      await _pump(
        tester,
        (context) => AIUtils.getEmptyView(
          context,
          backgroundColor: _bg,
          shadowColor: _shadow,
          emptyIconUrl: AssetConstants.repliesError,
          emptyIconPackageName: UIConstants.packageName,
          emptyStateText: 'Nothing to summarise yet',
          emptyIconTint: _tint,
          emptyTextStyle: _text,
        ),
      );

      expect(_chip(tester).backgroundColor, _bg);
      expect(_chip(tester).shadowColor, _shadow);
      expect(_image(tester).color, _tint);
      expect(
        (_image(tester).image as AssetImage).assetName,
        AssetConstants.repliesError,
      );
      expect(
        tester.widget<Text>(find.text('Nothing to summarise yet')).style,
        _text,
      );
    });
  });

  group('getLoadingIndicator', () {
    testWidgets('defaults to the spinner art and copy', (tester) async {
      await _pump(tester, (context) => AIUtils.getLoadingIndicator(context));

      expect(
        (_image(tester).image as AssetImage).assetName,
        AssetConstants.spinner,
      );
      // Whatever the translation says, the chip carries exactly one caption.
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('every override reaches the chip', (tester) async {
      await _pump(
        tester,
        (context) => AIUtils.getLoadingIndicator(
          context,
          backgroundColor: _bg,
          shadowColor: _shadow,
          loadingIconUrl: AssetConstants.repliesError,
          loadingIconPackageName: UIConstants.packageName,
          loadingStateText: 'Thinking…',
          loadingIconTint: _tint,
          loadingTextStyle: _text,
        ),
      );

      expect(_chip(tester).backgroundColor, _bg);
      expect(_chip(tester).shadowColor, _shadow);
      expect(_image(tester).color, _tint);
      expect(
        (_image(tester).image as AssetImage).assetName,
        AssetConstants.repliesError,
      );
      expect(tester.widget<Text>(find.text('Thinking…')).style, _text);
    });
  });

  group('getErrorText', () {
    testWidgets('its default caption is the two-line apology', (tester) async {
      Color? secondary;
      await _pump(tester, (context) {
        final palette = CometChatThemeHelper.getColorPalette(context);
        secondary = palette.textSecondary;
        return AIUtils.getErrorText(
          context,
          palette,
          CometChatThemeHelper.getTypography(context),
          CometChatThemeHelper.getSpacing(context),
        );
      });

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, contains('\n'));
      expect(text.textAlign, TextAlign.center);
      expect(secondary, isNotNull);
      expect(text.style?.color, secondary);
    });

    testWidgets('errorStateText replaces it and errorTextStyle merges over '
        'the typography default', (tester) async {
      await _pump(
        tester,
        (context) => AIUtils.getErrorText(
          context,
          CometChatThemeHelper.getColorPalette(context),
          CometChatThemeHelper.getTypography(context),
          CometChatThemeHelper.getSpacing(context),
          errorStateText: 'No summary available',
          errorTextStyle: _text,
        ),
      );

      final text = tester.widget<Text>(find.text('No summary available'));
      expect(text.style?.color, _text.color);
      expect(text.style?.fontSize, 19);
      expect(
        text.style?.fontWeight,
        isNotNull,
        reason: 'the typography default survives the merge',
      );
    });
  });

  test('extensionKey is the map key the AI panels address themselves with', () {
    expect(AIUtils.extensionKey, 'aiExtension');
  });
}
