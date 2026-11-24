import 'dart:io';
import 'package:flutter/material.dart';

/// Build an Image widget from a local file path (native only).
Widget buildFileImage(
  String filePath, {
  BoxFit fit = BoxFit.cover,
  FilterQuality filterQuality = FilterQuality.medium,
  int? cacheWidth,
  int? cacheHeight,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  Widget Function(BuildContext, Widget, int?, bool)? frameBuilder,
}) {
  if (cacheWidth != null || cacheHeight != null) {
    return Image(
      image: ResizeImage(
        FileImage(File(filePath)),
        width: cacheWidth ?? 512,
        height: cacheHeight ?? 512,
        policy: ResizeImagePolicy.fit,
      ),
      fit: fit,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
      frameBuilder: frameBuilder,
    );
  }
  return Image.file(
    File(filePath),
    fit: fit,
    filterQuality: filterQuality,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    errorBuilder: errorBuilder,
    frameBuilder: frameBuilder,
  );
}

/// An image provider for a local file path (native).
ImageProvider fileImageProvider(String filePath) => FileImage(File(filePath));
