import 'package:flutter/material.dart';

/// [CometChatTextStyleLink] is a class that gives the styling to the text displayed in the link
class CometChatTextStyleLink extends ThemeExtension<CometChatTextStyleLink> {
  const CometChatTextStyleLink({this.regular});

  ///[regular] defines the styling for the text with FontWeight.w400.
  final TextStyle? regular;

  @override
  CometChatTextStyleLink copyWith({TextStyle? regular}) {
    return CometChatTextStyleLink(regular: regular ?? this.regular);
  }

  @override
  CometChatTextStyleLink lerp(
    covariant ThemeExtension<CometChatTextStyleLink>? other,
    double t,
  ) {
    if (other is! CometChatTextStyleLink) {
      return this;
    }
    return CometChatTextStyleLink(
      regular: TextStyle.lerp(regular, other.regular, t)!,
    );
  }

  /// Resolves the default type for this role, then lets a
  /// [CometChatTextStyleLink] supplied through `ThemeData.extensions`
  /// override it. Merge direction is `default.merge(supplied)` so the
  /// caller wins; the reverse silently discards their style.
  static CometChatTextStyleLink of(BuildContext context) {
    final ext = Theme.of(context).extension<CometChatTextStyleLink>();
    final base = _ccTextStyle(context);
    return CometChatTextStyleLink(
      regular: base.copyWith(fontWeight: FontWeight.w400).merge(ext?.regular),
    );
  }

  static TextStyle _ccTextStyle(BuildContext context) {
    return const TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
  }

  CometChatTextStyleLink merge(CometChatTextStyleLink? other) {
    if (other == null) return this;
    return copyWith(regular: regular?.merge(other.regular));
  }
}
