/// Matrix goldens for the four primitives every list row and bubble is built
/// from: [CometChatAvatar], [CometChatBadge], [CometChatStatusIndicator] and
/// [CometChatReceipt]. One PNG per primitive, all its sizes / states in a row,
/// light and dark.
///
/// Avatars have no URL, so they show the initials fallback and nothing touches
/// the network.
///
///   flutter test test/shared_ui/core_widgets/goldens/                  # verify
///   flutter test test/shared_ui/core_widgets/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

/// Lays a matrix out as rows of evenly spaced cells.
Widget _matrix(List<List<Widget>> rows) => Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: row,
          ),
        ),
    ],
  ),
);

Widget _avatar(String name, double size, {CometChatAvatarStyle? style}) =>
    CometChatAvatar(name: name, width: size, height: size, style: style);

Widget _dot({
  Color? color,
  double size = 12,
  Widget? icon,
  bool ring = false,
}) => Builder(
  builder: (context) {
    final palette = CometChatThemeHelper.getColorPalette(context);
    return CometChatStatusIndicator(
      width: size,
      height: size,
      backgroundImage: icon,
      style: CometChatStatusIndicatorStyle(
        backgroundColor: color ?? palette.success,
        border: ring
            ? Border.all(color: palette.background1 ?? Colors.white, width: 2)
            : null,
      ),
    );
  },
);

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        'avatar matrix: sizes, one and two initials, no name, custom style',
        fileName: 'avatar_matrix',
        size: const Size(375, 320),
        alignment: Alignment.topLeft,
        builder: () => _matrix([
          [
            _avatar('Priya Raman', 24),
            _avatar('Priya Raman', 32),
            _avatar('Priya Raman', 40),
            _avatar('Priya Raman', 48),
            _avatar('Priya Raman', 64),
            _avatar('Priya Raman', 96),
          ],
          [
            _avatar('Marcus', 48),
            _avatar('', 48),
            _avatar(
              'Design Review',
              48,
              style: CometChatAvatarStyle(
                borderRadius: BorderRadius.circular(12),
                placeHolderTextStyle: const TextStyle(fontSize: 18),
              ),
            ),
            _avatar(
              'Chen Wei',
              48,
              style: CometChatAvatarStyle(
                border: Border.all(color: const Color(0xFF09C26F), width: 2),
              ),
            ),
          ],
        ]),
      );

      lightDarkGolden(
        'badge matrix: zero, one digit, two digits, three digits, overflow',
        fileName: 'badge_matrix',
        size: const Size(375, 80),
        alignment: Alignment.topLeft,
        builder: () => _matrix(const [
          [
            CometChatBadge(count: 0),
            CometChatBadge(count: 1),
            CometChatBadge(count: 9),
            CometChatBadge(count: 12),
            CometChatBadge(count: 99),
            CometChatBadge(count: 250),
            CometChatBadge(count: 1200),
          ],
        ]),
      );

      lightDarkGolden(
        'status indicator matrix: online dot sizes, ring, group-type icons',
        fileName: 'status_indicator_matrix',
        size: const Size(375, 80),
        alignment: Alignment.topLeft,
        builder: () => _matrix([
          [
            _dot(size: 8),
            _dot(),
            _dot(size: 16),
            _dot(size: 16, ring: true),
            Builder(
              builder: (context) {
                final palette = CometChatThemeHelper.getColorPalette(context);
                return _dot(
                  size: 16,
                  color: palette.warning,
                  icon: Icon(Icons.shield, size: 9, color: palette.background1),
                );
              },
            ),
            Builder(
              builder: (context) {
                final palette = CometChatThemeHelper.getColorPalette(context);
                return _dot(
                  size: 16,
                  icon: Icon(Icons.lock, size: 9, color: palette.background1),
                );
              },
            ),
            const CometChatStatusIndicator(),
          ],
        ]),
      );

      lightDarkGolden(
        'receipt matrix: waiting, sent, delivered, read, error; two sizes',
        fileName: 'receipt_matrix',
        size: const Size(375, 120),
        alignment: Alignment.topLeft,
        builder: () => _matrix([
          for (final size in [16.0, 24.0])
            [
              for (final status in const [
                ReceiptStatus.waiting,
                ReceiptStatus.sent,
                ReceiptStatus.delivered,
                ReceiptStatus.read,
                ReceiptStatus.error,
              ])
                CometChatReceipt(status: status, size: size),
            ],
        ]),
      );
    },
  );
}
