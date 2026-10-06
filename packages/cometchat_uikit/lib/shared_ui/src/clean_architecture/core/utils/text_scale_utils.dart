import 'package:flutter/widgets.dart';

/// Above this scale, single-line labels are allowed to wrap.
///
/// 1.15 rather than 2.0 deliberately: measurement showed names in the shared
/// list item already losing characters at 1.3, well before the 200% that
/// WCAG 2.1 AA (1.4.4 Resize Text) sets as the bar. Waiting for 2.0 to react
/// leaves the most common settings broken.
const double kTextScaleWrapThreshold = 1.15;

/// The user's current text scale, as a plain multiplier.
double currentTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1);

/// `maxLines` for a label that is one line at default text size.
///
/// A label pinned to `maxLines: 1` does not survive the user scaling their
/// text up. It keeps its single line and drops characters off the end —
/// silently, with no overflow stripes and no error, so it survives review and
/// reaches a user who can no longer read who a message is from.
///
/// Trading that truncation for height is nearly always the right call: a list
/// row can absorb a second line, and a clipped name cannot be recovered.
///
/// ```dart
/// Text(
///   user.name,
///   maxLines: scaledMaxLines(context),
///   overflow: TextOverflow.ellipsis,
/// )
/// ```
///
/// Pass [scaled] to allow more than two lines, or [threshold] to react at a
/// different scale. Keeping [TextOverflow.ellipsis] alongside this is still
/// correct — it is the backstop for a string long enough to exhaust even the
/// extra lines.
int scaledMaxLines(
  BuildContext context, {
  int base = 1,
  int scaled = 2,
  double threshold = kTextScaleWrapThreshold,
}) => currentTextScale(context) > threshold ? scaled : base;

/// Grows a fixed dimension with the user's text size.
///
/// For boxes that cannot simply size to their content — a square media
/// thumbnail, say, where height also sets the width. Capped at [maxFactor] so
/// that a very large accessibility setting cannot turn a tray tile into a
/// full-screen one.
double scaledDimension(
  BuildContext context,
  double size, {
  double maxFactor = 1.5,
}) {
  final double scale = currentTextScale(context);
  return size * (scale < 1.0 ? 1.0 : (scale > maxFactor ? maxFactor : scale));
}
