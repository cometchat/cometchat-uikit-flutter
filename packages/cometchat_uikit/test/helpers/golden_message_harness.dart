/// Shared harness for the message-content and search goldens.
///
/// Every golden in that batch renders a real Kit widget twice — light and
/// dark — side by side in one PNG, following the layout the conversations
/// goldens established. The pieces here are the ones those files would
/// otherwise each repeat: the themed host, the light/dark pair, and an
/// in-memory stand-in for the network so the media grid has real pixels to
/// lay out without a socket ever being opened.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The page colours the Kit's own screens sit on (`background1`).
const Color goldenLightBackground = Color(0xFFFFFFFF);
const Color goldenDarkBackground = Color(0xFF141414);

/// Hosts [child] the way a Kit screen would: the Kit reads brightness from
/// `MediaQuery.platformBrightness` and sizes bubbles from `MediaQuery.size`,
/// so both are pinned; Theme / Directionality / Material / Overlay are
/// supplied because the scenario is built outside a MaterialApp.
Widget goldenThemed({
  required Brightness brightness,
  required Size size,
  required Widget child,
  AlignmentGeometry alignment = Alignment.centerLeft,
  EdgeInsetsGeometry padding = const EdgeInsets.all(8),
}) {
  return MediaQuery(
    data: MediaQueryData(platformBrightness: brightness, size: size),
    child: Theme(
      data: brightness == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: brightness == Brightness.dark
              ? goldenDarkBackground
              : goldenLightBackground,
          // A Kit screen always sits under a Navigator's Overlay, and some
          // content (the audio row's Slider) mounts an OverlayPortal. One
          // Overlay per scenario keeps that portal inside its own theme.
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (_) => Padding(
                  padding: padding,
                  child: Align(alignment: alignment, child: child),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One golden file holding [build] rendered light and dark.
///
/// [build] is called once per theme so stateful widgets never share state
/// across the two scenarios.
void goldenLightDark(
  String fileName,
  String description, {
  required Widget Function() build,
  required Size size,
  AlignmentGeometry alignment = Alignment.centerLeft,
  EdgeInsetsGeometry padding = const EdgeInsets.all(8),
}) {
  goldenTest(
    description,
    fileName: fileName,
    // Asset and (faked) network images decode on a real async turn; without
    // this the golden captures the placeholder instead of the picture.
    pumpBeforeTest: precacheImages,
    builder: () => Localizations(
      locale: const Locale('en'),
      delegates: Translations.localizationsDelegates,
      child: GoldenTestGroup(
        scenarioConstraints: BoxConstraints.tightFor(
          width: size.width,
          height: size.height,
        ),
        children: [
          for (final brightness in Brightness.values.reversed)
            GoldenTestScenario(
              name: brightness == Brightness.light ? 'light' : 'dark',
              child: goldenThemed(
                brightness: brightness,
                size: size,
                alignment: alignment,
                padding: padding,
                child: build(),
              ),
            ),
        ],
      ),
    ),
  );
}

/// The alignment a bubble of [alignment] takes in the message list.
AlignmentGeometry goldenRowAlignment(BubbleAlignment alignment) =>
    alignment == BubbleAlignment.right
    ? Alignment.centerRight
    : Alignment.centerLeft;

/// The status row the message list puts in a bubble's `statusInfoView` slot:
/// the sent time, then a receipt on outgoing bubbles. The list builds this
/// privately, so it is mirrored here — same typography token, same colours —
/// because a bubble's bottom padding is designed around the row being there.
Widget goldenStatusInfo(
  BubbleAlignment alignment, {
  ReceiptStatus receipt = ReceiptStatus.read,
}) {
  return Builder(
    builder: (context) {
      final palette = CometChatThemeHelper.getColorPalette(context);
      final typography = CometChatThemeHelper.getTypography(context);
      final spacing = CometChatThemeHelper.getSpacing(context);
      final outgoing = alignment == BubbleAlignment.right;
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '12:30 pm',
            style: TextStyle(
              fontSize: typography.caption2?.regular?.fontSize ?? 10,
              fontWeight: typography.caption2?.regular?.fontWeight,
              color: outgoing ? palette.white : palette.neutral600,
            ),
          ),
          if (outgoing) ...[
            SizedBox(width: spacing.padding1 ?? 4),
            CometChatReceipt(status: receipt, size: 16),
          ],
        ],
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Fake network
// ---------------------------------------------------------------------------

/// A URL the fake network answers with a [width]×[height] two-tone picture in
/// [color] — a lighter "sky" over a darker band, so a golden shows which part
/// of the source `BoxFit.cover` kept.
String goldenImageUrl(String name, int color, {int width = 8, int height = 6}) {
  final hex = (color & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return 'https://media.golden.test/$width/$height/$hex/$name';
}

/// Routes every `HttpClient` created in this isolate to an in-memory server
/// that understands [goldenImageUrl] and answers 404 to anything else. No
/// socket is opened. Call from `main()` before declaring tests.
void installGoldenImageNetwork() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _GoldenHttpOverrides();
  });
}

class _GoldenHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _GoldenHttpClient();
}

class _GoldenHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _GoldenRequest(url);

  @override
  void close({bool force = false}) {}
}

class _GoldenRequest extends Fake implements HttpClientRequest {
  _GoldenRequest(this._url);

  final Uri _url;

  @override
  final HttpHeaders headers = _GoldenHeaders();

  @override
  Future<HttpClientResponse> close() async {
    final s = _url.pathSegments;
    if (_url.host != 'media.golden.test' || s.length < 4) {
      return _GoldenResponse(HttpStatus.notFound, Uint8List(0));
    }
    return _GoldenResponse(
      HttpStatus.ok,
      _twoToneBmp(
        width: int.parse(s[0]),
        height: int.parse(s[1]),
        rgb: int.parse(s[2], radix: 16),
      ),
    );
  }
}

class _GoldenHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _GoldenResponse extends Fake implements HttpClientResponse {
  _GoldenResponse(this.statusCode, this._body);

  final Uint8List _body;

  @override
  final int statusCode;

  @override
  int get contentLength => _body.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_body).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

/// An uncompressed 32-bit BMP: no zlib or CRC needed, and Flutter's codec
/// decodes it like any other image.
Uint8List _twoToneBmp({
  required int width,
  required int height,
  required int rgb,
}) {
  const headerSize = 54;
  final pixelBytes = width * height * 4;
  final data = ByteData(headerSize + pixelBytes)
    ..setUint8(0, 0x42) // 'B'
    ..setUint8(1, 0x4D) // 'M'
    ..setUint32(2, headerSize + pixelBytes, Endian.little)
    ..setUint32(10, headerSize, Endian.little)
    ..setUint32(14, 40, Endian.little) // BITMAPINFOHEADER
    ..setInt32(18, width, Endian.little)
    ..setInt32(22, height, Endian.little) // positive: rows run bottom-up
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, 32, Endian.little)
    ..setUint32(34, pixelBytes, Endian.little)
    ..setInt32(38, 2835, Endian.little)
    ..setInt32(42, 2835, Endian.little);

  final r = (rgb >> 16) & 0xFF;
  final g = (rgb >> 8) & 0xFF;
  final b = rgb & 0xFF;
  final bandRows = (height / 3).ceil();
  for (var row = 0; row < height; row++) {
    // Row 0 is the bottom of the picture — the darker band.
    final shade = row < bandRows ? 0.55 : 1.0;
    for (var col = 0; col < width; col++) {
      final o = headerSize + (row * width + col) * 4;
      data
        ..setUint8(o, (b * shade).round())
        ..setUint8(o + 1, (g * shade).round())
        ..setUint8(o + 2, (r * shade).round())
        ..setUint8(o + 3, 0xFF);
    }
  }
  return data.buffer.asUint8List();
}
