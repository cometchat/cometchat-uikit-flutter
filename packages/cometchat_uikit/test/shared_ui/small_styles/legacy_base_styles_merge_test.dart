/// `merge` on the five surviving [BaseStyles] subclasses.
///
/// These predate the modern style contract: they have no `copyWith` and no
/// `lerp`, so `test/helpers/style_contract.dart` cannot describe them, and
/// their `merge` runs the OTHER way round — `a.merge(b)` keeps `a`'s value
/// wherever `a` set one, whereas every `copyWith`-based style in the Kit lets
/// the ARGUMENT win. Each merge body was entirely unexecuted; a field dropped
/// from one of these tables silently discards an integrator's styling, which
/// is exactly what these tests catch.
///
///   flutter test test/shared_ui/small_styles/legacy_base_styles_merge_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = Color(0xFFAA0001);
const _b = Color(0xFFBB0002);
final _borderA = Border.all(color: _a, width: 1);
final _borderB = Border.all(color: _b, width: 2);
const _gradientA = LinearGradient(colors: [_a, _b]);
const _gradientB = LinearGradient(colors: [_b, _a]);
const _textA = TextStyle(color: _a, fontSize: 11);
const _textB = TextStyle(color: _b, fontSize: 22);

void main() {
  // =========================================================================
  group('QuickViewStyle', () {
    QuickViewStyle full(Color c, TextStyle t, Border b, Gradient g, double d) =>
        QuickViewStyle(
          titleStyle: t,
          subtitleStyle: t,
          closeIconTint: c,
          leadingBarTint: c,
          leadingBarWidth: d,
          width: d,
          height: d,
          background: c,
          border: b,
          borderRadius: BorderRadius.circular(d),
          gradient: g,
        );

    test('every field of the receiver survives the merge', () {
      final merged = full(
        _a,
        _textA,
        _borderA,
        _gradientA,
        1,
      ).merge(full(_b, _textB, _borderB, _gradientB, 2));

      expect(merged.titleStyle, _textA);
      expect(merged.subtitleStyle, _textA);
      expect(merged.closeIconTint, _a);
      expect(merged.leadingBarTint, _a);
      expect(merged.leadingBarWidth, 1);
      expect(merged.width, 1);
      expect(merged.height, 1);
      expect(merged.background, _a);
      expect(merged.border, _borderA);
      expect(merged.borderRadius, BorderRadius.circular(1));
      expect(merged.gradient, _gradientA);
    });

    test('an empty receiver takes every field from the argument', () {
      final merged = const QuickViewStyle().merge(
        full(_b, _textB, _borderB, _gradientB, 2),
      );

      expect(merged.titleStyle, _textB);
      expect(merged.subtitleStyle, _textB);
      expect(merged.closeIconTint, _b);
      expect(merged.leadingBarTint, _b);
      expect(merged.leadingBarWidth, 2);
      expect(merged.width, 2);
      expect(merged.height, 2);
      expect(merged.background, _b);
      expect(merged.border, _borderB);
      expect(merged.borderRadius, BorderRadius.circular(2));
      expect(merged.gradient, _gradientB);
    });

    test('the argument fills only the holes the receiver left', () {
      final merged = QuickViewStyle(
        titleStyle: _textA,
        leadingBarWidth: 1,
      ).merge(full(_b, _textB, _borderB, _gradientB, 2));

      expect(merged.titleStyle, _textA, reason: 'the receiver set it');
      expect(merged.leadingBarWidth, 1);
      expect(merged.subtitleStyle, _textB, reason: 'the receiver did not');
      expect(merged.background, _b);
    });
  });

  // =========================================================================
  group('SingleSelectStyle', () {
    SingleSelectStyle full(
      Color c,
      TextStyle t,
      Border b,
      Gradient g,
      double d,
    ) => SingleSelectStyle(
      labelStyle: t,
      selectedOptionTextStyle: t,
      optionTextStyle: t,
      selectedOptionBackground: c,
      optionBackground: c,
      width: d,
      height: d,
      background: c,
      border: b,
      borderRadius: BorderRadius.circular(d),
      gradient: g,
    );

    test('every field of the receiver survives the merge', () {
      final merged = full(
        _a,
        _textA,
        _borderA,
        _gradientA,
        1,
      ).merge(full(_b, _textB, _borderB, _gradientB, 2));

      expect(merged.labelStyle, _textA);
      expect(merged.selectedOptionTextStyle, _textA);
      expect(merged.optionTextStyle, _textA);
      expect(merged.selectedOptionBackground, _a);
      expect(merged.optionBackground, _a);
      expect(merged.width, 1);
      expect(merged.height, 1);
      expect(merged.background, _a);
      expect(merged.border, _borderA);
      expect(merged.borderRadius, BorderRadius.circular(1));
      expect(merged.gradient, _gradientA);
    });

    test('an empty receiver takes every field from the argument', () {
      final merged = SingleSelectStyle().merge(
        full(_b, _textB, _borderB, _gradientB, 2),
      );

      expect(merged.labelStyle, _textB);
      expect(merged.selectedOptionTextStyle, _textB);
      expect(merged.optionTextStyle, _textB);
      expect(merged.selectedOptionBackground, _b);
      expect(merged.optionBackground, _b);
      expect(merged.width, 2);
      expect(merged.height, 2);
      expect(merged.background, _b);
      expect(merged.border, _borderB);
      expect(merged.borderRadius, BorderRadius.circular(2));
      expect(merged.gradient, _gradientB);
    });

    test('its fields are mutable, unlike every modern style class', () {
      final style = SingleSelectStyle(labelStyle: _textA)
        ..labelStyle = _textB
        ..optionBackground = _b;

      expect(style.labelStyle, _textB);
      expect(style.optionBackground, _b);
    });
  });

  // =========================================================================
  group('WebViewStyle', () {
    WebViewStyle full(Color c, TextStyle t, Border b, Gradient g, double d) =>
        WebViewStyle(
          titleStyle: t,
          appBarColor: c,
          backIconColor: c,
          width: d,
          height: d,
          background: c,
          border: b,
          borderRadius: BorderRadius.circular(d),
          gradient: g,
        );

    test('every field of the receiver survives the merge', () {
      final merged = full(
        _a,
        _textA,
        _borderA,
        _gradientA,
        1,
      ).merge(full(_b, _textB, _borderB, _gradientB, 2));

      expect(merged.titleStyle, _textA);
      expect(merged.appBarColor, _a);
      expect(merged.backIconColor, _a);
      expect(merged.width, 1);
      expect(merged.height, 1);
      expect(merged.background, _a);
      expect(merged.border, _borderA);
      expect(merged.borderRadius, BorderRadius.circular(1));
      expect(merged.gradient, _gradientA);
    });

    test('an empty receiver takes every field from the argument', () {
      final merged = const WebViewStyle().merge(
        full(_b, _textB, _borderB, _gradientB, 2),
      );

      expect(merged.titleStyle, _textB);
      expect(merged.appBarColor, _b);
      expect(merged.backIconColor, _b);
      expect(merged.width, 2);
      expect(merged.background, _b);
      expect(merged.border, _borderB);
      expect(merged.borderRadius, BorderRadius.circular(2));
      expect(merged.gradient, _gradientB);
    });
  });

  // =========================================================================
  group('ButtonElementStyle', () {
    ButtonElementStyle full(
      Color c,
      TextStyle t,
      Border b,
      Gradient g,
      double d,
    ) => ButtonElementStyle(
      buttonTextStyle: t,
      loadingIconTint: c,
      width: d,
      height: d,
      background: c,
      border: b,
      borderRadius: BorderRadius.circular(d),
      gradient: g,
    );

    test('every field of the receiver survives the merge', () {
      final merged = full(
        _a,
        _textA,
        _borderA,
        _gradientA,
        1,
      ).merge(full(_b, _textB, _borderB, _gradientB, 2));

      expect(merged.buttonTextStyle, _textA);
      expect(merged.loadingIconTint, _a);
      expect(merged.width, 1);
      expect(merged.height, 1);
      expect(merged.background, _a);
      expect(merged.border, _borderA);
      expect(merged.borderRadius, BorderRadius.circular(1));
      expect(merged.gradient, _gradientA);
    });

    test('an empty receiver takes every field from the argument', () {
      final merged = ButtonElementStyle().merge(
        full(_b, _textB, _borderB, _gradientB, 2),
      );

      expect(merged.buttonTextStyle, _textB);
      expect(merged.loadingIconTint, _b);
      expect(merged.width, 2);
      expect(merged.height, 2);
      expect(merged.background, _b);
      expect(merged.border, _borderB);
      expect(merged.borderRadius, BorderRadius.circular(2));
      expect(merged.gradient, _gradientB);
    });
  });

  // =========================================================================
  group('CometChatNewMessageIndicatorStyle', () {
    // The odd one out: it is not a BaseStyles subclass, it takes a NULLABLE
    // argument, and its precedence runs the modern way round — the argument
    // wins.
    const receiver = CometChatNewMessageIndicatorStyle(
      textColor: _a,
      dividerColor: _a,
      textStyle: _textA,
      backgroundColor: _a,
    );

    test('merging null hands back the receiver itself', () {
      expect(receiver.merge(null), same(receiver));
    });

    test('every non-null field of the argument wins', () {
      final merged = receiver.merge(
        const CometChatNewMessageIndicatorStyle(
          textColor: _b,
          dividerColor: _b,
          textStyle: _textB,
          backgroundColor: _b,
        ),
      );

      expect(merged.textColor, _b);
      expect(merged.dividerColor, _b);
      expect(merged.textStyle, _textB);
      expect(merged.backgroundColor, _b);
    });

    test('a null field of the argument leaves the receiver alone', () {
      final merged = receiver.merge(
        const CometChatNewMessageIndicatorStyle(textColor: _b),
      );

      expect(merged.textColor, _b);
      expect(merged.dividerColor, _a);
      expect(merged.textStyle, _textA);
      expect(merged.backgroundColor, _a);
    });

    test('merging onto an empty receiver takes the whole argument', () {
      final merged = const CometChatNewMessageIndicatorStyle().merge(
        const CometChatNewMessageIndicatorStyle(
          textColor: _b,
          dividerColor: _b,
          textStyle: _textB,
          backgroundColor: _b,
        ),
      );

      expect(merged.textColor, _b);
      expect(merged.dividerColor, _b);
      expect(merged.textStyle, _textB);
      expect(merged.backgroundColor, _b);
    });
  });

  // =========================================================================
  test('the four BaseStyles subclasses invert the modern precedence', () {
    // Pinned deliberately: `a.merge(b)` keeps a's value here, while the
    // `copyWith`-based classes (and CometChatNewMessageIndicatorStyle above)
    // give b's value precedence. Anything reading these side by side has to
    // know which way round each one runs.
    expect(
      const QuickViewStyle(
        background: _a,
      ).merge(const QuickViewStyle(background: _b)).background,
      _a,
    );
    expect(
      SingleSelectStyle(
        background: _a,
      ).merge(SingleSelectStyle(background: _b)).background,
      _a,
    );
    expect(
      const WebViewStyle(
        background: _a,
      ).merge(const WebViewStyle(background: _b)).background,
      _a,
    );
    expect(
      ButtonElementStyle(
        background: _a,
      ).merge(ButtonElementStyle(background: _b)).background,
      _a,
    );
    expect(
      const CometChatNewMessageIndicatorStyle(backgroundColor: _a)
          .merge(const CometChatNewMessageIndicatorStyle(backgroundColor: _b))
          .backgroundColor,
      _b,
      reason: 'this one runs the other way round',
    );
  });
}
