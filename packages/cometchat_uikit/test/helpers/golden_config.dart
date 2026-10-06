import 'dart:io' show Platform;

import 'package:alchemist/alchemist.dart';

/// Platform goldens render with the host's real fonts, so they differ between
/// machines and OS releases and cannot be shared (ENG-38688 TEST5). They are
/// opt-in:
///
///     ALCHEMIST_PLATFORM_GOLDENS=true flutter test
///
/// The CI variant renders with the Ahem font, is deterministic, and always
/// runs, locally and in CI alike. So a plain `flutter test` gives the same
/// answer on every machine.
final bool platformGoldensEnabled =
    Platform.environment['ALCHEMIST_PLATFORM_GOLDENS'] == 'true';

/// How far the Ahem variant may drift before it fails, as a fraction of pixels.
///
/// That variant is meant to be byte-identical everywhere, but the same scene
/// rasterises a few pixels differently on macOS and Linux: the message-list
/// golden generated on a Mac differed by 0.02% (88 px) on CI. 0.05% absorbs
/// that and still catches a real change; a moved or recoloured icon alone
/// differs by several times more. Platform goldens stay exact.
const double ciGoldenDiffThreshold = 0.0005;

/// The configuration every golden test in this package runs under.
AlchemistConfig goldenConfig() => AlchemistConfig(
  platformGoldensConfig: PlatformGoldensConfig(enabled: platformGoldensEnabled),
  ciGoldensConfig: const CiGoldensConfig(diffThreshold: ciGoldenDiffThreshold),
);
