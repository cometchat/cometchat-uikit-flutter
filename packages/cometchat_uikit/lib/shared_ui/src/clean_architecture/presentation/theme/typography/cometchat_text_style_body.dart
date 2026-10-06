import 'package:flutter/material.dart';

///[CometChatTextStyleBody] is a class that gives the styling to the text displayed in the body
class CometChatTextStyleBody extends ThemeExtension<CometChatTextStyleBody> {
  const CometChatTextStyleBody({this.bold, this.medium, this.regular});

  /// The bold variant of the body style.
  final TextStyle? bold;

  /// The medium variant of the body style.
  final TextStyle? medium;

  /// The regular variant of the body style.
  final TextStyle? regular;

  @override
  CometChatTextStyleBody copyWith({
    TextStyle? bold,
    TextStyle? medium,
    TextStyle? regular,
  }) {
    return CometChatTextStyleBody(
      bold: bold ?? this.bold,
      medium: medium ?? this.medium,
      regular: regular ?? this.regular,
    );
  }

  @override
  CometChatTextStyleBody lerp(
    covariant ThemeExtension<CometChatTextStyleBody>? other,
    double t,
  ) {
    if (other is! CometChatTextStyleBody) {
      return this;
    }
    return CometChatTextStyleBody(
      bold: TextStyle.lerp(bold, other.bold, t),
      medium: TextStyle.lerp(medium, other.medium, t),
      regular: TextStyle.lerp(regular, other.regular, t),
    );
  }

  /// Resolves the default type for this role, then lets a
  /// [CometChatTextStyleBody] supplied through `ThemeData.extensions`
  /// override it. Merge direction is `default.merge(supplied)` so the
  /// caller wins; the reverse silently discards their style.
  static CometChatTextStyleBody of(BuildContext context) {
    final ext = Theme.of(context).extension<CometChatTextStyleBody>();
    final base = _ccTextStyle(context);
    return CometChatTextStyleBody(
      bold: base.copyWith(fontWeight: FontWeight.w700).merge(ext?.bold),
      medium: base.copyWith(fontWeight: FontWeight.w500).merge(ext?.medium),
      regular: base.copyWith(fontWeight: FontWeight.w400).merge(ext?.regular),
    );
  }

  static TextStyle _ccTextStyle(BuildContext context) {
    return const TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
  }

  CometChatTextStyleBody merge(CometChatTextStyleBody? other) {
    if (other == null) return this;
    return copyWith(
      bold: bold?.merge(other.bold),
      medium: medium?.merge(other.medium),
      regular: regular?.merge(other.regular),
    );
  }
}
