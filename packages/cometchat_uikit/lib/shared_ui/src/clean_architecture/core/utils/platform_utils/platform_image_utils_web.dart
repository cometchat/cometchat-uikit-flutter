import 'package:flutter/material.dart';

/// Web stub — local file images are not available on web.
/// This should never be called because isLocalFileAvailable returns false on web.
Widget buildFileImage(
  String filePath, {
  BoxFit fit = BoxFit.cover,
  FilterQuality filterQuality = FilterQuality.medium,
  int? cacheWidth,
  int? cacheHeight,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  Widget Function(BuildContext, Widget, int?, bool)? frameBuilder,
}) {
  // Should never be reached on web — return placeholder
  return const SizedBox.shrink();
}

/// Web: a path on the device is a `blob:` object URL, loaded over the network
/// path.
ImageProvider fileImageProvider(String filePath) => NetworkImage(filePath);
