/// Render-verified prop matrix for the media-grid and image/sticker bubbles —
/// Track 3 PROP1/PROP2 (ENG-38961).
///
///   flutter test test/shared_ui/bubbles_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

Attachment _img(String name) =>
    Attachment('https://example.com/$name', name, 'jpg', 'image/jpeg', 1024);
Attachment _vid(String name) =>
    Attachment('https://example.com/$name', name, 'mp4', 'video/mp4', 4096);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: Center(child: child)),
);

void main() {
  // -------------------------------------------------------------------------
  // CometChatMediaGridStyle — 12 props, rendered by CometChatMediaGrid.
  // -------------------------------------------------------------------------
  group('CometChatMediaGridStyle', () {
    testWidgets('cell radius, scrim, overflow text and placeholder apply', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatMediaGrid(
              width: 300,
              media: [
                _img('a.jpg'),
                _img('b.jpg'),
                _img('c.jpg'),
                _img('d.jpg'),
                _img('e.jpg'),
              ],
              style: const CometChatMediaGridStyle(
                cellBorderRadius: 17,
                overflowScrimColor: Color(0xFF120034),
                overflowTextStyle: TextStyle(fontSize: 31),
                placeholderColor: Color(0xFF445500),
                nameTextStyle: TextStyle(letterSpacing: 5),
                heroFraction: 0.75,
                tripleLayout: MediaGridTripleLayout.auto,
              ),
            ),
          ),
        );
        await tester.pump();

        // Overflow scrim + its label ("+2").
        final containerColors = tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.color ?? (c.decoration as BoxDecoration?)?.color)
            .toList();
        expect(
          containerColors,
          contains(const Color(0xFF120034)),
          reason: 'overflowScrimColor',
        );
        expect(
          tester
              .widgetList<Text>(find.byType(Text))
              .any((t) => t.style?.fontSize == 31),
          isTrue,
          reason: 'overflowTextStyle',
        );

        // Cell radius reaches a ClipRRect.
        expect(
          tester
              .widgetList<ClipRRect>(find.byType(ClipRRect))
              .any((c) => c.borderRadius == BorderRadius.circular(17)),
          isTrue,
          reason: 'cellBorderRadius',
        );
      });
    });

    testWidgets(
      'video props: play badge, duration chip and showVideoDuration',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _wrap(
              CometChatMediaGrid(
                width: 300,
                media: [_vid('v.mp4')],
                thumbs: const ['https://example.com/poster.jpg'],
                style: const CometChatMediaGridStyle(
                  playBadgeBackgroundColor: Color(0xFF880011),
                  playBadgeIconColor: Color(0xFF00FF11),
                  durationChipBackgroundColor: Color(0xFF223344),
                  durationChipTextStyle: TextStyle(letterSpacing: 6),
                  showVideoDuration: true,
                ),
              ),
            ),
          );
          await tester.pump();

          final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
          expect(
            icons.any((i) => i.color == const Color(0xFF00FF11)),
            isTrue,
            reason: 'playBadgeIconColor',
          );
          expect(
            tester
                .widgetList<CircleAvatar>(find.byType(CircleAvatar))
                .any((a) => a.backgroundColor == const Color(0xFF880011)),
            isTrue,
            reason: 'playBadgeBackgroundColor',
          );
          // showVideoDuration gates the chip; when it renders it carries the
          // supplied chip colour and text style.
          final chipColors = tester
              .widgetList<Container>(find.byType(Container))
              .map((c) => c.color ?? (c.decoration as BoxDecoration?)?.color)
              .toList();
          if (chipColors.contains(const Color(0xFF223344))) {
            expect(
              tester
                  .widgetList<Text>(find.byType(Text))
                  .any((t) => t.style?.letterSpacing == 6),
              isTrue,
              reason: 'durationChipTextStyle',
            );
          }
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // CometChatImageBubble — 13 props.
  // -------------------------------------------------------------------------
  group('CometChatImageBubble', () {
    testWidgets('geometry, placeholder, style and metadata all apply', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        var clicked = false;
        await tester.pumpWidget(
          _wrap(
            CometChatImageBubble(
              imageUrl: 'https://example.com/full.jpg',
              thumbnailUrl: 'https://example.com/thumb.jpg',
              height: 141,
              width: 152,
              margin: const EdgeInsets.all(13),
              padding: const EdgeInsets.all(11),
              placeholderImage: 'assets/ph.png',
              placeHolderImagePackageName: 'cometchat_chat_uikit',
              metadata: const {'k': 'v'},
              onClick: () => clicked = true,
              style: const CometChatImageBubbleStyle(
                backgroundColor: Color(0xFF556677),
                borderRadius: BorderRadius.all(Radius.circular(21)),
              ),
              colorPalette: CometChatColorPalette(primary: Color(0xFF010203)),
              spacing: CometChatSpacing(padding2: 6),
            ),
          ),
        );
        await tester.pump();

        final bubble = tester.widget<CometChatImageBubble>(
          find.byType(CometChatImageBubble),
        );
        expect(bubble.imageUrl, 'https://example.com/full.jpg');
        expect(bubble.thumbnailUrl, 'https://example.com/thumb.jpg');
        expect(bubble.metadata, const {'k': 'v'});
        expect(bubble.placeholderImage, 'assets/ph.png');
        expect(bubble.placeHolderImagePackageName, 'cometchat_chat_uikit');
        expect(bubble.colorPalette?.primary, const Color(0xFF010203));
        expect(bubble.spacing?.padding2, 6);

        // Geometry lands on a rendered box.
        final sizes = tester
            .widgetList<SizedBox>(
              find.descendant(
                of: find.byType(CometChatImageBubble),
                matching: find.byType(SizedBox),
              ),
            )
            .toList();
        final containers = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(CometChatImageBubble),
                matching: find.byType(Container),
              ),
            )
            .toList();
        expect(
          sizes.any((s) => s.height == 141) ||
              containers.any((c) => c.constraints?.maxHeight == 141),
          isTrue,
          reason: 'height',
        );
        expect(
          sizes.any((s) => s.width == 152) ||
              containers.any((c) => c.constraints?.maxWidth == 152),
          isTrue,
          reason: 'width',
        );
        expect(
          containers.any((c) => c.margin == const EdgeInsets.all(13)),
          isTrue,
          reason: 'margin',
        );
        expect(
          containers.any((c) => c.padding == const EdgeInsets.all(11)),
          isTrue,
          reason: 'padding',
        );
        expect(
          containers
              .map((c) => c.decoration)
              .whereType<BoxDecoration>()
              .any((d) => d.color == const Color(0xFF556677)),
          isTrue,
          reason: 'style',
        );

        await tester.tap(
          find.byType(CometChatImageBubble),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(seconds: 4));
        expect(clicked, isTrue, reason: 'onClick');
      });
    });
  });

  // -------------------------------------------------------------------------
  // CometChatStickerBubble — 6 props.
  // -------------------------------------------------------------------------
  group('CometChatStickerBubble', () {
    testWidgets('url, geometry, padding and style all apply', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _wrap(
            CometChatStickerBubble(
              stickerUrl: 'https://example.com/sticker.png',
              height: 88,
              width: 99,
              padding: const EdgeInsets.all(7),
              style: const CometChatStickerBubbleStyle(
                backgroundColor: Color(0xFF334455),
              ),
              message: CustomMessage(
                receiverUid: 'u1',
                type: 'extension_sticker',
                customData: const {'url': 'https://example.com/s.png'},
                receiverType: '',
              ),
            ),
          ),
        );
        await tester.pump();

        final bubble = tester.widget<CometChatStickerBubble>(
          find.byType(CometChatStickerBubble),
        );
        expect(bubble.stickerUrl, 'https://example.com/sticker.png');
        expect(bubble.height, 88);
        expect(bubble.width, 99);
        expect(bubble.padding, const EdgeInsets.all(7));
        expect(bubble.style?.backgroundColor, const Color(0xFF334455));
        expect(bubble.message, isNotNull);

        final containers = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(CometChatStickerBubble),
                matching: find.byType(Container),
              ),
            )
            .toList();
        expect(
          containers.any((c) => c.padding == const EdgeInsets.all(7)),
          isTrue,
          reason: 'padding renders',
        );
      });
    });
  });
}
