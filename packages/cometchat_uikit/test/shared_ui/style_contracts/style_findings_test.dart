/// Bugs found by the style contract sweep, pinned at their current behaviour.
///
/// Each test here documents something the contract in
/// `test/helpers/style_contract.dart` refuses to accept, so the class had to
/// be excluded from the generic table. They are written as assertions on the
/// *wrong* behaviour on purpose: when the bug is fixed the test fails and the
/// FINDING comment says what the expectation should become. Nothing in `lib/`
/// was changed.
///
///   flutter test test/shared_ui/style_contracts/style_findings_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = Color(0xFF112233);
const _b = Color(0xFF445566);
const _c = Color(0xFF778899);

void main() {
  group('CometChatMediaRecorderStyle', () {
    test('FINDING copyWith keeps only the arguments it is given', () {
      // FINDING: this copyWith builds the result straight from its parameters
      // with no `?? this.<field>` fallback on any field, so it behaves like a
      // constructor, not a copy. `style.copyWith(textColor: x)` throws away
      // every other property the style had. Expected behaviour: the untouched
      // fields survive.
      final style = CometChatMediaRecorderStyle(
        backgroundColor: _a,
        textColor: _b,
        borderRadius: BorderRadius.circular(9),
      );

      final copied = style.copyWith(textColor: _c);

      expect(copied.textColor, _c);
      expect(copied.backgroundColor, isNull); // should be _a
      expect(copied.borderRadius, isNull); // should be BorderRadius.circular(9)

      // Even copyWith() with no arguments returns an empty style.
      expect(style.copyWith().backgroundColor, isNull);
    });

    test('FINDING merge therefore discards the receiver', () {
      // FINDING: merge is `copyWith(<every field of the argument>)`, and with
      // the copyWith above that means the receiver's values are dropped
      // wherever the argument is null. An integrator who supplies a style that
      // only sets the send-button colour loses the rest of the resolved theme.
      final resolved = CometChatMediaRecorderStyle(
        backgroundColor: _a,
        textColor: _b,
      );
      final supplied = CometChatMediaRecorderStyle(sendButtonIconColor: _c);

      final merged = resolved.merge(supplied);

      expect(merged.sendButtonIconColor, _c);
      expect(merged.backgroundColor, isNull); // should be _a
      expect(merged.textColor, isNull); // should be _b
    });

    test('FINDING copyWith drops three of its own parameters', () {
      // FINDING: `recordingButtonIconColor`, `sendButtonTextStyle` and
      // `sendButtonTextColor` are declared on copyWith but never read — there
      // are no such fields. They are part of the public API and silently do
      // nothing.
      final style = CometChatMediaRecorderStyle(sendButtonIconColor: _a)
          .copyWith(
            sendButtonIconColor: _a,
            recordingButtonIconColor: _b,
            sendButtonTextStyle: const TextStyle(fontSize: 21),
            sendButtonTextColor: _c,
          );
      expect(style.sendButtonIconColor, _a);
    });
  });

  group('CometChatColorPalette', () {
    test('FINDING the extendedPrimary ramp is shifted by one slot', () {
      // FINDING: copyWith reads the ramp one step behind itself —
      //   extendedPrimary200: extendedPrimary100 ?? this.extendedPrimary200,
      //   extendedPrimary300: extendedPrimary200 ?? this.extendedPrimary300, …
      // so setting 100 also overwrites 200, every value lands one slot too
      // low, and `extendedPrimary900` can never be set at all. copyWith is
      // how a resolved palette is adjusted, so a caller's ramp override lands
      // on the wrong tokens.
      final palette = CometChatColorPalette().copyWith(
        extendedPrimary100: _a,
        extendedPrimary900: _c,
      );

      expect(palette.extendedPrimary100, _a);
      expect(palette.extendedPrimary200, _a); // should be null
      expect(palette.extendedPrimary900, isNull); // should be _c

      // The same shift one step further up the ramp.
      final mid = CometChatColorPalette().copyWith(extendedPrimary500: _b);
      expect(mid.extendedPrimary500, isNull); // should be _b
      expect(mid.extendedPrimary600, _b); // should be null
    });

    test('FINDING copyWith declares a `neutral` parameter it never reads', () {
      // FINDING: there is no `neutral` field; the parameter is dead API.
      // `alertColor`, by contrast, is alive — it is the only way to set
      // `messageSeen` through copyWith.
      final palette = CometChatColorPalette().copyWith(
        neutral: _a,
        alertColor: _b,
      );
      expect(palette.messageSeen, _b);
    });
  });

  group('CometChatSpacing', () {
    test('FINDING lerp interpolates `spacing` towards `other.spacing1`', () {
      // FINDING: `spacing: lerpDouble(spacing, other.spacing1, t)` — the first
      // line of the lerp reads the wrong field on `other`, so animating
      // between two spacing scales lands `spacing` on the other scale's
      // `spacing1`. Every other line of the lerp is correctly paired.
      final from = CometChatSpacing(spacing: 2, spacing1: 4);
      final to = CometChatSpacing(spacing: 200, spacing1: 400);

      final end = from.lerp(to, 1.0);

      expect(end.spacing, 400); // should be 200 — to.spacing
      expect(end.spacing1, 400);
    });

    test('padding/margin/radius fall back to the spacing scale', () {
      // The constructor derives the three aliases from `spacing*` when they
      // are not given, and keeps an explicit value when they are.
      final spacing = CometChatSpacing(spacing4: 99);
      expect(spacing.padding4, 99);
      expect(spacing.margin4, 99);
      expect(spacing.radius4, 99);
      expect(CometChatSpacing(spacing4: 99, padding4: 7).padding4, 7);

      // FINDING: the padding scale stops at padding10 while margin runs to
      // margin20 and radius to radiusMax — there is no padding11..padding20
      // or paddingMax field at all, even though copyWith advertises them.
      expect(CometChatSpacing().margin20, 80);
      expect(CometChatSpacing().padding10, 40);
      expect(CometChatSpacing().radiusMax, 1000);
    });

    test('FINDING copyWith declares padding11..paddingMax but drops them', () {
      // FINDING: copyWith accepts padding11-padding20, paddingMax and
      // marginMax; none of them exist as fields, so the values vanish with no
      // way to read them back — the call is accepted and does nothing.
      final spacing = CometChatSpacing(
        spacing4: 99,
      ).copyWith(padding11: 11, marginMax: 12);
      expect(spacing.spacing4, 99);
      expect(spacing.padding10, 40);
    });
  });

  group('lerp guards', () {
    test('FINDING CometChatStickerBubbleStyle.lerp throws on a null other', () {
      // FINDING: `other!.messageBubbleBackgroundImage` — the null-check
      // operator on a parameter that `ThemeExtension.lerp` is allowed to be
      // passed as null. `ThemeData.lerp` hands null to an extension that the
      // other theme does not carry, so animating between a theme with this
      // extension and one without crashes.
      expect(
        () => CometChatStickerBubbleStyle().lerp(null, 0.5),
        throwsA(isA<TypeError>()),
      );
    });

    test('FINDING CometChatPollsBubbleStyle.lerp throws on empty styles', () {
      // FINDING: the text-style slots are lerped with a trailing `!`, and
      // `TextStyle.lerp(null, null, t)` is null, so lerping two poll styles
      // that leave a text style unset — two default-constructed ones, say —
      // throws. Incoming and outgoing bubble styles forward into this, so they
      // throw too.
      expect(
        () =>
            CometChatPollsBubbleStyle().lerp(CometChatPollsBubbleStyle(), 0.5),
        throwsA(isA<TypeError>()),
      );
      expect(
        () =>
            CometChatIncomingMessageBubbleStyle(
              pollsBubbleStyle: CometChatPollsBubbleStyle(),
            ).lerp(
              CometChatIncomingMessageBubbleStyle(
                pollsBubbleStyle: CometChatPollsBubbleStyle(),
              ),
              0.5,
            ),
        throwsA(isA<TypeError>()),
      );
    });

    test('FINDING some lerps fade towards null instead of returning this', () {
      // FINDING: `ThemeExtension.lerp` is documented to return `this` when
      // `other` is not the same type. These classes instead interpolate
      // towards null, so a theme animation into a theme without the extension
      // fades the style out rather than leaving it alone.
      final style = CometChatTextBubbleStyle(backgroundColor: _a);
      final faded = style.lerp(null, 1.0);
      expect(identical(faded, style), isFalse);
      expect(faded.backgroundColor?.a, 0); // fully transparent, not _a
    });
  });

  group('CometChatMessageBubbleStyle', () {
    test('FINDING lerp ignores t for backgroundImage', () {
      // FINDING: `backgroundImage: other.backgroundImage ?? backgroundImage`
      // — the other end's image is adopted at every t, including t == 0, so
      // the image snaps instead of being held until the animation ends.
      const mine = DecorationImage(image: AssetImage('mine'));
      const theirs = DecorationImage(image: AssetImage('theirs'));
      final at0 = const CometChatMessageBubbleStyle(
        backgroundImage: mine,
      ).lerp(const CometChatMessageBubbleStyle(backgroundImage: theirs), 0.0);
      expect(at0.backgroundImage, theirs); // should be `mine` at t == 0
    });
  });

  group('dead copyWith parameters', () {
    test('FINDING several style classes accept arguments they never read', () {
      // FINDING: each of these parameters is declared on the class's copyWith
      // but never assigned to a field, so an integrator's value is dropped
      // without a warning. Listed here so the set is visible in one place.
      // There is no `senderNameTextStyle` / `messageReceiptStyle` field to
      // read back at all — the parameters exist only on copyWith, so the call
      // is a no-op on a style that otherwise round-trips.
      expect(
        CometChatOutgoingMessageBubbleStyle(backgroundColor: _a)
            .copyWith(senderNameTextStyle: const TextStyle(fontSize: 21))
            .backgroundColor,
        _a,
      );
      expect(
        CometChatIncomingMessageBubbleStyle(backgroundColor: _a)
            .copyWith(messageReceiptStyle: CometChatMessageReceiptStyle())
            .backgroundColor,
        _a,
      );
      expect(
        const CometChatMessageHeaderStyle()
            .copyWith(backButtonIconTint: _a)
            .backIconColor,
        isNull,
      );
      expect(
        const CometChatMessageListStyle()
            .copyWith(loadingStateIconColor: _a, loadingStateIconSize: 8)
            .backgroundColor,
        isNull,
      );
      expect(
        CometChatReactionsStyle()
            .copyWith(emojiTextColor: _a, elevation: 4)
            .backgroundColor,
        isNull,
      );
    });
  });
}
