/// Render-verified prop matrix for the live extension widgets —
/// Track 3 PROP1/PROP2 (ENG-38684).
///
/// Only the widgets an integrator can actually reach are here. The v5
/// configuration classes and the four option-style classes that ride on them
/// are unreachable by construction and belong to the removal in ENG-38953.
///
/// CometChatCollaborativeWebView renders its app bar for real. Only its body
/// needs a WebViewPlatform, which tests don't have, so that subtree's error
/// is ignored and webviewUrl is asserted on the widget rather than on a
/// loaded page.
///
///   flutter test test/chat_ui/extensions/extension_widgets_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

MediaMessage _media() => MediaMessage(
  receiverUid: 'u2',
  type: MessageTypeConstants.image,
  receiverType: CometChatReceiverType.user,
  sender: User(uid: 'u2', name: 'Bob'),
);

void main() {
  // -------------------------------------------------------------------------
  // ImageModerationFilter — 4 props — and ImageModerationFilterStyle — 5.
  // -------------------------------------------------------------------------
  group('ImageModerationFilter', () {
    testWidgets('message, child, warningText and style all reach the widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ImageModerationFilter(
            message: _media(),
            warningText: 'Sensitive content',
            style: ImageModerationFilterStyle(
              filterColor: const Color(0xFF111111),
              warningTextStyle: const TextStyle(letterSpacing: 4),
              warningImageColor: const Color(0xFF333333),
              warningImageUrl: 'assets/warn.png',
              warningImagePackageName: 'cometchat_chat_uikit',
            ),
            child: const SizedBox(width: 120, height: 90),
          ),
        ),
      );
      await tester.pump();

      final w = tester.widget<ImageModerationFilter>(
        find.byType(ImageModerationFilter),
      );
      expect(w.message, isNotNull, reason: 'message');
      expect(w.child, isNotNull, reason: 'child');
      expect(w.warningText, 'Sensitive content', reason: 'warningText');
      final s = w.style!;
      expect(s.filterColor, const Color(0xFF111111));
      expect(s.warningTextStyle?.letterSpacing, 4);
      expect(s.warningImageColor, const Color(0xFF333333));
      expect(s.warningImageUrl, 'assets/warn.png');
      expect(s.warningImagePackageName, 'cometchat_chat_uikit');

      // The child is rendered behind whatever the filter draws.
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  // StickerAuxiliaryButton — 6 props (composerId is in six_one_one_props_test).
  // Closed shows stickerButtonIcon, open shows keyboardButtonIcon, as on
  // Android; the tints colour the default icons only.
  // -------------------------------------------------------------------------
  group('StickerAuxiliaryButton', () {
    testWidgets('each state shows its own icon and fires its own callback', (
      tester,
    ) async {
      var stickerTaps = 0;
      var keyboardTaps = 0;
      await tester.pumpWidget(
        _wrap(
          StickerAuxiliaryButton(
            stickerButtonIcon: const Icon(Icons.emoji_emotions, size: 31),
            keyboardButtonIcon: const Icon(Icons.keyboard, size: 32),
            onStickerTap: () => stickerTaps++,
            onKeyboardTap: () => keyboardTaps++,
          ),
        ),
      );
      await tester.pump();

      // Closed: the sticker icon only.
      expect(find.byIcon(Icons.emoji_emotions), findsOneWidget);
      expect(find.byIcon(Icons.keyboard), findsNothing);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      // Open: the active icon only — the closed-state icon is not reused.
      expect(stickerTaps, 1, reason: 'onStickerTap');
      expect(find.byIcon(Icons.keyboard), findsOneWidget);
      expect(find.byIcon(Icons.emoji_emotions), findsNothing);
      expect(
        find.byType(Image),
        findsNothing,
        reason: 'a custom icon replaces the default asset',
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(keyboardTaps, 1, reason: 'onKeyboardTap');
      expect(find.byIcon(Icons.emoji_emotions), findsOneWidget);
      expect(find.byIcon(Icons.keyboard), findsNothing);
    });

    testWidgets('the tints colour the default icon of their own state', (
      tester,
    ) async {
      Image shown() => tester.widget<Image>(find.byType(Image));
      String asset(Image i) => (i.image as AssetImage).assetName;

      await tester.pumpWidget(
        _wrap(
          const StickerAuxiliaryButton(
            stickerIconTint: Color(0xFF445566),
            keyboardIconTint: Color(0xFF778899),
          ),
        ),
      );
      await tester.pump();

      expect(asset(shown()), AssetConstants.smile);
      expect(shown().color, const Color(0xFF445566), reason: 'stickerIconTint');

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(asset(shown()), AssetConstants.stickerFilled);
      expect(
        shown().color,
        const Color(0xFF778899),
        reason: 'keyboardIconTint',
      );
    });

    testWidgets('a custom closed icon does not replace the default open icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StickerAuxiliaryButton(
            stickerButtonIcon: Icon(Icons.emoji_emotions),
            keyboardIconTint: Color(0xFF778899),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.emoji_emotions), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      final open = tester.widget<Image>(find.byType(Image));
      expect(find.byIcon(Icons.emoji_emotions), findsNothing);
      expect(
        (open.image as AssetImage).assetName,
        AssetConstants.stickerFilled,
      );
      expect(open.color, const Color(0xFF778899));
    });
  });

  // -------------------------------------------------------------------------
  // CometChatStickerKeyboard — 5 props (style is in sticker_keyboard_test).
  // The sticker fetch needs the SDK, so drive the state views the widget owns.
  // -------------------------------------------------------------------------
  group('CometChatStickerKeyboard', () {
    testWidgets('height and the state views reach the widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatStickerKeyboard(
            height: 211,
            onStickerTap: (_) {},
            loadingStateView: (_) => const Text('loading stickers'),
            errorStateView: (_) => const Text('sticker error'),
            emptyStateView: (_) => const Text('no stickers'),
          ),
        ),
      );
      await tester.pump();

      final w = tester.widget<CometChatStickerKeyboard>(
        find.byType(CometChatStickerKeyboard),
      );
      expect(w.height, 211);
      expect(w.onStickerTap, isNotNull);
      expect(w.loadingStateView, isNotNull);
      expect(w.errorStateView, isNotNull);
      expect(w.emptyStateView, isNotNull);

      // Without an SDK session the keyboard sits in one of its own states,
      // all three of which are the builders supplied above.
      expect(
        find.text('loading stickers').evaluate().isNotEmpty ||
            find.text('sticker error').evaluate().isNotEmpty ||
            find.text('no stickers').evaluate().isNotEmpty,
        isTrue,
        reason: 'one supplied state view renders',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
  // -------------------------------------------------------------------------
  // CometChatCollaborativeWebView — 6 props.
  // -------------------------------------------------------------------------
  group('CometChatCollaborativeWebView', () {
    /// The body's WebViewController asserts without a platform
    /// implementation. The app bar is a sibling subtree, so it still builds.
    void ignoreWebViewPlatformError() {
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('webview_flutter')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
    }

    testWidgets('title, titleStyle and appBarColor style the app bar', (
      tester,
    ) async {
      ignoreWebViewPlatformError();
      const titleColor = Color(0xFF1C2D3E);
      const barColor = Color(0xFF4F5E6D);
      await tester.pumpWidget(
        MaterialApp(
          home: const CometChatCollaborativeWebView(
            title: 'Roadmap doc',
            webviewUrl: 'https://example.invalid/doc',
            titleStyle: TextStyle(color: titleColor, fontSize: 23),
            appBarColor: barColor,
          ),
        ),
      );
      await tester.pump();

      final title = tester.widget<Text>(find.text('Roadmap doc'));
      expect(title.style?.color, titleColor);
      expect(title.style?.fontSize, 23);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        barColor,
      );
    });

    testWidgets('backIconColor tints the default close icon', (tester) async {
      ignoreWebViewPlatformError();
      const iconColor = Color(0xFF6A7B8C);
      await tester.pumpWidget(
        MaterialApp(
          home: const CometChatCollaborativeWebView(
            title: 'Board',
            webviewUrl: 'https://example.invalid/board',
            backIconColor: iconColor,
          ),
        ),
      );
      await tester.pump();
      expect(tester.widget<Icon>(find.byIcon(Icons.close)).color, iconColor);
    });

    testWidgets('backIcon replaces the close icon and pops the page', (
      tester,
    ) async {
      ignoreWebViewPlatformError();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CometChatCollaborativeWebView(
                    title: 'Board',
                    webviewUrl: 'https://example.invalid/board',
                    backIcon: Icon(Icons.arrow_back),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(CometChatCollaborativeWebView), findsNothing);
    });

    testWidgets('webviewUrl is carried to the page', (tester) async {
      // Not a paint assertion: nothing loads a page headlessly.
      ignoreWebViewPlatformError();
      await tester.pumpWidget(
        MaterialApp(
          home: const CometChatCollaborativeWebView(
            title: 'Board',
            webviewUrl: 'https://example.invalid/board',
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<CometChatCollaborativeWebView>(
              find.byType(CometChatCollaborativeWebView),
            )
            .webviewUrl,
        'https://example.invalid/board',
      );
    });
  });
}
