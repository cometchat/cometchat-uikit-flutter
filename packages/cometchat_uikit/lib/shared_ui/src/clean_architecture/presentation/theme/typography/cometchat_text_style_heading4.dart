import 'package:flutter/material.dart';

///[CometChatTextStyleHeading4] is a class that gives the styling to the text displayed in the CometChatApp.
class CometChatTextStyleHeading4
    extends ThemeExtension<CometChatTextStyleHeading4> {
  const CometChatTextStyleHeading4({this.bold, this.medium, this.regular});

  ///[bold] defines the styling for the text with FontWeight.w700.
  final TextStyle? bold;

  ///[medium] defines the styling for the text with FontWeight.w500.
  final TextStyle? medium;

  ///[regular] defines the styling for the text with FontWeight.w400.
  final TextStyle? regular;

  @override
  CometChatTextStyleHeading4 copyWith({
    TextStyle? bold,
    TextStyle? medium,
    TextStyle? regular,
  }) {
    return CometChatTextStyleHeading4(
      bold: bold ?? this.bold,
      medium: medium ?? this.medium,
      regular: regular ?? this.regular,
    );
  }

  @override
  CometChatTextStyleHeading4 lerp(
    covariant ThemeExtension<CometChatTextStyleHeading4>? other,
    double t,
  ) {
    if (other is! CometChatTextStyleHeading4) {
      return this;
    }
    return CometChatTextStyleHeading4(
      bold: TextStyle.lerp(bold, other.bold, t)!,
      medium: TextStyle.lerp(medium, other.medium, t)!,
      regular: TextStyle.lerp(regular, other.regular, t)!,
    );
  }

  /// Resolves the default type for this role, then lets a
  /// [CometChatTextStyleHeading4] supplied through `ThemeData.extensions`
  /// override it. Merge direction is `default.merge(supplied)` so the
  /// caller wins; the reverse silently discards their style.
  static CometChatTextStyleHeading4 of(BuildContext context) {
    final ext = Theme.of(context).extension<CometChatTextStyleHeading4>();
    final base = _ccTextStyle(context);
    return CometChatTextStyleHeading4(
      bold: base.copyWith(fontWeight: FontWeight.w700).merge(ext?.bold),
      medium: base.copyWith(fontWeight: FontWeight.w500).merge(ext?.medium),
      regular: base.copyWith(fontWeight: FontWeight.w400).merge(ext?.regular),
    );
  }

  static TextStyle _ccTextStyle(BuildContext context) {
    return const TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  }

  CometChatTextStyleHeading4 merge(CometChatTextStyleHeading4? other) {
    if (other == null) return this;
    return copyWith(
      bold: bold?.merge(other.bold),
      medium: medium?.merge(other.medium),
      regular: regular?.merge(other.regular),
    );
  }
}
