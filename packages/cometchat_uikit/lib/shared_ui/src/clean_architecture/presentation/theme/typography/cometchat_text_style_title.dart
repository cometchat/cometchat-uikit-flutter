import 'package:flutter/material.dart';

///[CometChatTextStyleTitle] is a class that gives the styling to the text displayed in the title
class CometChatTextStyleTitle extends ThemeExtension<CometChatTextStyleTitle> {
  const CometChatTextStyleTitle({this.bold, this.medium, this.regular});

  ///[bold] defines the styling for the text with FontWeight.w700.
  final TextStyle? bold;

  ///[medium] defines the styling for the text with FontWeight.w500.
  final TextStyle? medium;

  ///[regular] defines the styling for the text with FontWeight.w400.
  final TextStyle? regular;

  @override
  CometChatTextStyleTitle copyWith({
    TextStyle? bold,
    TextStyle? medium,
    TextStyle? regular,
  }) {
    return CometChatTextStyleTitle(
      bold: bold ?? this.bold,
      medium: medium ?? this.medium,
      regular: regular ?? this.regular,
    );
  }

  @override
  CometChatTextStyleTitle lerp(
    covariant ThemeExtension<CometChatTextStyleTitle>? other,
    double t,
  ) {
    if (other is! CometChatTextStyleTitle) {
      return this;
    }
    return CometChatTextStyleTitle(
      bold: TextStyle.lerp(bold, other.bold, t)!,
      medium: TextStyle.lerp(medium, other.medium, t)!,
      regular: TextStyle.lerp(regular, other.regular, t)!,
    );
  }

  /// Resolves the default type for this role, then lets a
  /// [CometChatTextStyleTitle] supplied through `ThemeData.extensions`
  /// override it. Merge direction is `default.merge(supplied)` so the
  /// caller wins; the reverse silently discards their style.
  static CometChatTextStyleTitle of(BuildContext context) {
    final ext = Theme.of(context).extension<CometChatTextStyleTitle>();
    final base = _ccTextStyle(context);
    return CometChatTextStyleTitle(
      bold: base.copyWith(fontWeight: FontWeight.w700).merge(ext?.bold),
      medium: base.copyWith(fontWeight: FontWeight.w500).merge(ext?.medium),
      regular: base.copyWith(fontWeight: FontWeight.w400).merge(ext?.regular),
    );
  }

  static TextStyle _ccTextStyle(BuildContext context) {
    return const TextStyle(fontSize: 32, fontWeight: FontWeight.w700);
  }

  CometChatTextStyleTitle merge(CometChatTextStyleTitle? other) {
    if (other == null) return this;
    return copyWith(
      bold: bold?.merge(other.bold),
      medium: medium?.merge(other.medium),
      regular: regular?.merge(other.regular),
    );
  }
}
