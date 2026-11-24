import 'package:flutter/material.dart';

/// Stub — should never be reached at runtime.
Widget buildFileImage(
  String filePath, {
  BoxFit fit = BoxFit.cover,
  FilterQuality filterQuality = FilterQuality.medium,
  int? cacheWidth,
  int? cacheHeight,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  Widget Function(BuildContext, Widget, int?, bool)? frameBuilder,
}) {
  return const SizedBox.shrink();
}

/// Stub — should never be reached at runtime.
ImageProvider fileImageProvider(String filePath) => NetworkImage(filePath);
