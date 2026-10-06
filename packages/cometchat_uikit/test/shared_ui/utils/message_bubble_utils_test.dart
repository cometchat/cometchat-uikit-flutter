/// Behaviour tests for the parts of `message_utils.dart` the message-list
/// tests do not reach: the template override hooks on
/// [MessageUtils.getMessageBubble], the pinned/saved status glyphs, the
/// per-type style plumbing in [BubbleUIBuilder.getAdditionalConfigurations],
/// the upload-error border radius, and the two combinators on
/// [CometChatMessageBubbleStyleData].
///
/// The bubble itself is asserted by pumping it: a template hook is only
/// credited when the widget it returned is in the tree, so a hook that is
/// declared but never called fails here.
///
///   flutter test test/shared_ui/utils/message_bubble_utils_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _alice = User(uid: 'u1', name: 'Alice');
final _bob = User(uid: 'u2', name: 'Bob');
final _team = Group(guid: 'g1', name: 'Team', type: 'public');

TextMessage _text({
  User? sender,
  AppEntity? receiver,
  DateTime? editedAt,
  DateTime? savedAt,
  Map<String, dynamic>? metadata,
}) {
  final m = TextMessage(
    text: 'hello there',
    receiverUid: 'u2',
    receiverType: CometChatReceiverType.user,
    type: MessageTypeConstants.text,
    sender: sender ?? _alice,
    receiver: receiver,
    editedAt: editedAt,
    metadata: metadata,
  );
  if (savedAt != null) m.savedAt = savedAt;
  return m;
}

/// Pumps [MessageUtils.getMessageBubble] with the palettes taken from the live
/// theme, so only the arguments under test vary.
Future<void> pumpBubble(
  WidgetTester tester, {
  required BaseMessage message,
  CometChatMessageTemplate? template,
  BubbleAlignment alignment = BubbleAlignment.left,
  bool showPinIndicator = false,
  bool showSaveIndicator = false,
  bool showSentDateInHeader = false,
  bool forceLeftLayout = false,
  String? senderNameOverride,
  bool? receiptsVisibility,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => Scaffold(
          body: MessageUtils.getMessageBubble(
            message: message,
            template: template,
            bubbleAlignment: alignment,
            colorPalette: CometChatThemeHelper.getColorPalette(context),
            typography: CometChatThemeHelper.getTypography(context),
            spacing: CometChatThemeHelper.getSpacing(context),
            context: context,
            showPinIndicator: showPinIndicator,
            showSaveIndicator: showSaveIndicator,
            showSentDateInHeader: showSentDateInHeader,
            forceLeftLayout: forceLeftLayout,
            senderNameOverride: senderNameOverride,
            receiptsVisibility: receiptsVisibility,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    // `isSent` and the bubble background both compare against this static.
    CometChatUIKit.loggedInUser = _alice;
  });

  tearDown(() {
    CometChatUIKit.loggedInUser = null;
    ModerationCheckUtil.instance.hideModerationStatus = false;
  });

  // ==========================================================================
  group('getMessageBubble — template overrides', () {
    testWidgets('bubbleView replaces the whole bubble', (tester) async {
      var calls = 0;
      await pumpBubble(
        tester,
        message: _text(),
        template: CometChatMessageTemplate(
          type: MessageTypeConstants.text,
          category: MessageCategoryConstants.message,
          bubbleView: (message, context, alignment) {
            calls++;
            // The bubble hook is always asked for the LEFT alignment, whatever
            // the caller passed — the whole bubble is the integrator's now.
            expect(alignment, BubbleAlignment.left);
            return const Text('custom bubble');
          },
        ),
        alignment: BubbleAlignment.right,
      );
      expect(calls, 1);
      expect(find.text('custom bubble'), findsOneWidget);
      // Nothing of the default bubble is built alongside it.
      expect(find.byType(CometChatMessageBubble), findsNothing);
    });

    testWidgets('a deleted message ignores bubbleView', (tester) async {
      // Deleted messages get the deleted bubble, not the integrator's view —
      // otherwise a custom bubble would keep rendering content that is gone.
      final deleted = _text()..deletedAt = DateTime(2026, 9, 8);
      await pumpBubble(
        tester,
        message: deleted,
        template: CometChatMessageTemplate(
          type: MessageTypeConstants.text,
          category: MessageCategoryConstants.message,
          bubbleView: (message, context, alignment) =>
              const Text('custom bubble'),
        ),
      );
      expect(find.text('custom bubble'), findsNothing);
      expect(find.byType(CometChatMessageBubble), findsOneWidget);
    });

    testWidgets('a bubbleView returning null falls back to an empty box', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        message: _text(),
        template: CometChatMessageTemplate(
          type: MessageTypeConstants.text,
          category: MessageCategoryConstants.message,
          bubbleView: (message, context, alignment) => null,
        ),
      );
      expect(find.byType(CometChatMessageBubble), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('statusInfoView replaces the default status row', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        message: _text(),
        template: CometChatMessageTemplate(
          type: MessageTypeConstants.text,
          category: MessageCategoryConstants.message,
          statusInfoView: (message, context, alignment) =>
              const Text('my status'),
        ),
      );
      expect(find.text('my status'), findsOneWidget);
    });

    testWidgets('headerView replaces the sender name row', (tester) async {
      await pumpBubble(
        tester,
        message: _text(sender: _bob, receiver: _team),
        template: CometChatMessageTemplate(
          type: MessageTypeConstants.text,
          category: MessageCategoryConstants.message,
          headerView: (message, context, alignment) => const Text('my header'),
        ),
      );
      expect(find.text('my header'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
    });

    testWidgets('contentView supplies the bubble body', (tester) async {
      await pumpBubble(
        tester,
        message: _text(),
        template: CometChatMessageTemplate(
          type: MessageTypeConstants.text,
          category: MessageCategoryConstants.message,
          contentView:
              (message, context, alignment, {additionalConfigurations}) =>
                  const Text('my content'),
        ),
      );
      expect(find.text('my content'), findsOneWidget);
    });
  });

  // ==========================================================================
  group('getMessageBubble — header and avatar', () {
    testWidgets('a group message from someone else shows name and avatar', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        message: _text(sender: _bob, receiver: _team),
      );
      expect(find.text('Bob'), findsOneWidget);
      expect(find.byType(CometChatAvatar), findsOneWidget);
    });

    testWidgets('a one-to-one message shows neither', (tester) async {
      await pumpBubble(
        tester,
        message: _text(sender: _bob, receiver: _alice),
      );
      expect(find.text('Bob'), findsNothing);
      expect(find.byType(CometChatAvatar), findsNothing);
    });

    testWidgets('a right-aligned group message shows no avatar', (
      tester,
    ) async {
      // The avatar belongs to the other party's side of the list.
      await pumpBubble(
        tester,
        message: _text(sender: _alice, receiver: _team),
        alignment: BubbleAlignment.right,
      );
      expect(find.byType(CometChatAvatar), findsNothing);
    });

    testWidgets('forceLeftLayout names every sender, even in a 1-1 chat', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        message: _text(sender: _bob, receiver: _alice),
        alignment: BubbleAlignment.right,
        forceLeftLayout: true,
      );
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('senderNameOverride replaces the name', (tester) async {
      await pumpBubble(
        tester,
        message: _text(sender: _alice, receiver: _alice),
        forceLeftLayout: true,
        senderNameOverride: 'You',
      );
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('showSentDateInHeader enlarges and bolds the name', (
      tester,
    ) async {
      // The list surfaces give the name more presence than a chat bubble.
      await pumpBubble(
        tester,
        message: _text(sender: _bob, receiver: _team),
        showSentDateInHeader: true,
      );
      final withDate = tester.widget<Text>(find.text('Bob'));

      await pumpBubble(
        tester,
        message: _text(sender: _bob, receiver: _team),
      );
      final plain = tester.widget<Text>(find.text('Bob'));

      expect(withDate.style!.fontWeight, FontWeight.w500);
      expect(withDate.style!.fontSize, plain.style!.fontSize! + 2);
    });
  });

  // ==========================================================================
  group('getMessageBubble — status glyphs', () {
    testWidgets('showPinIndicator adds the pin glyph', (tester) async {
      await pumpBubble(tester, message: _text(), showPinIndicator: true);
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });

    testWidgets('no pin glyph by default', (tester) async {
      await pumpBubble(tester, message: _text());
      expect(find.byIcon(Icons.push_pin), findsNothing);
    });

    testWidgets('the save glyph needs both the flag and a savedAt', (
      tester,
    ) async {
      final saved = _text(savedAt: DateTime(2026, 9, 8));
      await pumpBubble(tester, message: saved, showSaveIndicator: true);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);

      // The flag alone is not enough: an unsaved message shows nothing.
      await pumpBubble(tester, message: _text(), showSaveIndicator: true);
      expect(find.byIcon(Icons.bookmark), findsNothing);

      // ...and neither is savedAt alone.
      await pumpBubble(tester, message: saved);
      expect(find.byIcon(Icons.bookmark), findsNothing);
    });

    testWidgets('pin and save together read as two glyphs and two bullets', (
      tester,
    ) async {
      await pumpBubble(
        tester,
        message: _text(savedAt: DateTime(2026, 9, 8)),
        showPinIndicator: true,
        showSaveIndicator: true,
      );
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.text(' • '), findsNWidgets(2));
    });

    testWidgets('an edited text message is tagged', (tester) async {
      await pumpBubble(tester, message: _text(editedAt: DateTime(2026, 9, 8)));
      await tester.pump();
      final label = Translations.of(
        tester.element(find.byType(Scaffold)),
      ).edited;
      expect(find.text(label), findsOneWidget);
    });

    testWidgets('an edited media caption is tagged too', (tester) async {
      // The tag used to be restricted to type == text, which silently hid it
      // on edited media captions once those became editable.
      final media = MediaMessage(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        type: MessageTypeConstants.image,
        sender: _alice,
        editedAt: DateTime(2026, 9, 8),
      );
      await pumpBubble(tester, message: media);
      final label = Translations.of(
        tester.element(find.byType(Scaffold)),
      ).edited;
      expect(find.text(label), findsOneWidget);
    });

    testWidgets('an edited call message is not tagged', (tester) async {
      // Other categories stay excluded — a call is never "edited" by a user.
      final call = Call(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        type: MessageTypeConstants.audio,
        category: MessageCategoryConstants.call,
        sender: _alice,
        editedAt: DateTime(2026, 9, 8),
      );
      await pumpBubble(tester, message: call);
      final label = Translations.of(
        tester.element(find.byType(Scaffold)),
      ).edited;
      expect(find.text(label), findsNothing);
    });

    testWidgets('the edited tag inverts on the outgoing side', (tester) async {
      // Right-aligned bubbles are filled, so the tag has to go white to stay
      // readable; left-aligned ones sit on the neutral fill.
      final edited = _text(editedAt: DateTime(2026, 9, 8));
      await pumpBubble(
        tester,
        message: edited,
        alignment: BubbleAlignment.right,
      );
      final context = tester.element(find.byType(Scaffold));
      final palette = CometChatThemeHelper.getColorPalette(context);
      final label = Translations.of(context).edited;
      expect(tester.widget<Text>(find.text(label)).style!.color, palette.white);

      await pumpBubble(tester, message: edited);
      expect(
        tester.widget<Text>(find.text(label)).style!.color,
        palette.neutral600,
      );
    });

    testWidgets('an unedited message is not tagged', (tester) async {
      await pumpBubble(tester, message: _text());
      final label = Translations.of(
        tester.element(find.byType(Scaffold)),
      ).edited;
      expect(find.text(label), findsNothing);
    });
  });

  // ==========================================================================
  group('getMessageBubble — background colour', () {
    /// The bubble's own fill, read back off the rendered bubble.
    Color? fillOf(WidgetTester tester) => tester
        .widget<CometChatMessageBubble>(find.byType(CometChatMessageBubble))
        .style
        ?.backgroundColor;

    testWidgets('my own message uses the primary colour', (tester) async {
      late Color? primary;
      await pumpBubble(tester, message: _text(sender: _alice));
      primary = CometChatThemeHelper.getColorPalette(
        tester.element(find.byType(Scaffold)),
      ).primary;
      expect(fillOf(tester), primary);
    });

    testWidgets('someone else\'s message uses the neutral colour', (
      tester,
    ) async {
      await pumpBubble(tester, message: _text(sender: _bob));
      final neutral = CometChatThemeHelper.getColorPalette(
        tester.element(find.byType(Scaffold)),
      ).neutral300;
      expect(fillOf(tester), neutral);
      expect(fillOf(tester), isNot(isNull));
    });

    testWidgets('a deleted message from someone else falls back to neutral', (
      tester,
    ) async {
      // The deleted bubble declares no fill of its own, so the generic
      // sender-based fallback decides — this is the one path that reaches its
      // "not mine" arm.
      final deleted = _text(sender: _bob)..deletedAt = DateTime(2026, 9, 8);
      await pumpBubble(tester, message: deleted);
      final neutral = CometChatThemeHelper.getColorPalette(
        tester.element(find.byType(Scaffold)),
      ).neutral300;
      expect(fillOf(tester), neutral);
    });

    testWidgets('the two fills differ, so sent and received are tellable', (
      tester,
    ) async {
      await pumpBubble(tester, message: _text(sender: _alice));
      final mine = fillOf(tester);
      await pumpBubble(tester, message: _text(sender: _bob));
      expect(fillOf(tester), isNot(mine));
    });
  });

  // ==========================================================================
  group('getSentTextMediaBorderRadiusGeometry', () {
    late CometChatSpacing spacing;
    late CometChatColorPalette palette;
    late CometChatTypography typography;

    Future<void> prime(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              spacing = CometChatThemeHelper.getSpacing(context);
              palette = CometChatThemeHelper.getColorPalette(context);
              typography = CometChatThemeHelper.getTypography(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
    }

    BorderRadiusGeometry? radiusFor(BaseMessage message) =>
        BubbleUIBuilder.getSentTextMediaBorderRadiusGeometry(
          message,
          BorderRadius.circular(99),
          palette,
          typography,
          spacing,
        );

    testWidgets('a normal message keeps the radius it was given', (
      tester,
    ) async {
      await prime(tester);
      expect(radiusFor(_text()), BorderRadius.circular(99));
    });

    testWidgets('an upload failure squares off the bottom corners', (
      tester,
    ) async {
      // A failed upload grows an error strip beneath the bubble, so the
      // bubble must stop rounding where the strip joins it.
      await prime(tester);
      for (final code in [
        ErrorConstants.fileErrorCodeAndroid,
        ErrorConstants.fileErrorCodeIOS,
      ]) {
        final failed = _text(metadata: {'error': code});
        final radius = radiusFor(failed) as BorderRadius;
        expect(radius.bottomLeft, Radius.zero, reason: code);
        expect(radius.bottomRight, Radius.zero, reason: code);
        expect(radius.topLeft, isNot(Radius.zero), reason: code);
      }
    });

    testWidgets('a moderation-disapproved message squares off too', (
      tester,
    ) async {
      // Disapproved messages also grow a strip below the bubble.
      await prime(tester);
      final flagged = _text()
        ..moderationStatus = ModerationStatusEnum.DISAPPROVED;
      final radius = radiusFor(flagged) as BorderRadius;
      expect(radius.bottomLeft, Radius.zero);
      expect(radius.bottomRight, Radius.zero);
    });

    testWidgets('hiding the moderation status restores the radius', (
      tester,
    ) async {
      await prime(tester);
      final flagged = _text()
        ..moderationStatus = ModerationStatusEnum.DISAPPROVED;
      ModerationCheckUtil.instance.hideModerationStatus = true;
      expect(radiusFor(flagged), BorderRadius.circular(99));
    });

    testWidgets('an approved message keeps its radius', (tester) async {
      await prime(tester);
      final ok = _text()..moderationStatus = ModerationStatusEnum.APPROVED;
      expect(radiusFor(ok), BorderRadius.circular(99));
    });

    testWidgets('unrelated metadata does not square the corners', (
      tester,
    ) async {
      await prime(tester);
      expect(
        radiusFor(_text(metadata: const {'error': 'SOMETHING_ELSE'})),
        BorderRadius.circular(99),
      );
    });

    testWidgets('an empty metadata map does not square the corners', (
      tester,
    ) async {
      await prime(tester);
      expect(
        radiusFor(_text(metadata: const <String, dynamic>{})),
        BorderRadius.circular(99),
      );
    });
  });

  // ==========================================================================
  group('BubbleUIBuilder.getTextFormatters', () {
    test('a text message is handed to every formatter', () {
      final formatters = [CometChatMentionsFormatter()];
      final message = _text();
      final out = BubbleUIBuilder.getTextFormatters(message, formatters);
      expect(out, same(formatters));
      expect(out.single.message, same(message));
    });

    test('a non-text message leaves the formatters untouched', () {
      final formatter = CometChatMentionsFormatter();
      final media = MediaMessage(
        receiverUid: 'u2',
        receiverType: CometChatReceiverType.user,
        type: MessageTypeConstants.image,
        sender: _alice,
      );
      BubbleUIBuilder.getTextFormatters(media, [formatter]);
      expect(formatter.message, isNull);
    });

    test('an empty formatter list comes straight back', () {
      expect(BubbleUIBuilder.getTextFormatters(_text(), const []), isEmpty);
    });
  });

  // ==========================================================================
  group('BubbleUIBuilder.getAdditionalConfigurations', () {
    /// Every per-type bubble style set to something identifiable, so the
    /// "copy the style, drop the border" plumbing can be checked per slot.
    CometChatOutgoingMessageBubbleStyle outgoing() =>
        CometChatOutgoingMessageBubbleStyle(
          textBubbleStyle: const CometChatTextBubbleStyle(
            backgroundColor: Color(0xFF000001),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          imageBubbleStyle: const CometChatImageBubbleStyle(
            backgroundColor: Color(0xFF000002),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          fileBubbleStyle: const CometChatFileBubbleStyle(
            backgroundColor: Color(0xFF000003),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          videoBubbleStyle: const CometChatVideoBubbleStyle(
            backgroundColor: Color(0xFF000004),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          audioBubbleStyle: const CometChatAudioBubbleStyle(
            backgroundColor: Color(0xFF000005),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          deletedBubbleStyle: const CometChatDeletedBubbleStyle(
            backgroundColor: Color(0xFF000006),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          voiceCallBubbleStyle: const CometChatCallBubbleStyle(
            backgroundColor: Color(0xFF000007),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          videoCallBubbleStyle: const CometChatCallBubbleStyle(
            backgroundColor: Color(0xFF000008),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
        );

    CometChatIncomingMessageBubbleStyle incoming() =>
        CometChatIncomingMessageBubbleStyle(
          textBubbleStyle: const CometChatTextBubbleStyle(
            backgroundColor: Color(0xFF0000A1),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          imageBubbleStyle: const CometChatImageBubbleStyle(
            backgroundColor: Color(0xFF0000A2),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          fileBubbleStyle: const CometChatFileBubbleStyle(
            backgroundColor: Color(0xFF0000A3),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          videoBubbleStyle: const CometChatVideoBubbleStyle(
            backgroundColor: Color(0xFF0000A4),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          audioBubbleStyle: const CometChatAudioBubbleStyle(
            backgroundColor: Color(0xFF0000A5),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          deletedBubbleStyle: const CometChatDeletedBubbleStyle(
            backgroundColor: Color(0xFF0000A6),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          voiceCallBubbleStyle: const CometChatCallBubbleStyle(
            backgroundColor: Color(0xFF0000A7),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
          videoCallBubbleStyle: const CometChatCallBubbleStyle(
            backgroundColor: Color(0xFF0000A8),
            border: Border.fromBorderSide(BorderSide(width: 7)),
          ),
        );

    Future<AdditionalConfigurations?> configure(
      WidgetTester tester,
      BaseMessage message,
    ) async {
      AdditionalConfigurations? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = BubbleUIBuilder.getAdditionalConfigurations(
                context,
                message,
                null,
                incoming(),
                outgoing(),
                null,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      return result;
    }

    testWidgets('my own message takes the outgoing per-type styles', (
      tester,
    ) async {
      final config = (await configure(tester, _text(sender: _alice)))!;
      expect(config.textBubbleStyle?.backgroundColor, const Color(0xFF000001));
      expect(config.imageBubbleStyle?.backgroundColor, const Color(0xFF000002));
      expect(config.fileBubbleStyle?.backgroundColor, const Color(0xFF000003));
      expect(config.videoBubbleStyle?.backgroundColor, const Color(0xFF000004));
      expect(config.audioBubbleStyle?.backgroundColor, const Color(0xFF000005));
      expect(
        config.deletedBubbleStyle?.backgroundColor,
        const Color(0xFF000006),
      );
      expect(
        config.voiceCallBubbleStyle?.backgroundColor,
        const Color(0xFF000007),
      );
      expect(
        config.videoCallBubbleStyle?.backgroundColor,
        const Color(0xFF000008),
      );
    });

    testWidgets('someone else\'s message takes the incoming styles', (
      tester,
    ) async {
      final config = (await configure(tester, _text(sender: _bob)))!;
      expect(config.textBubbleStyle?.backgroundColor, const Color(0xFF0000A1));
      expect(config.imageBubbleStyle?.backgroundColor, const Color(0xFF0000A2));
      expect(config.fileBubbleStyle?.backgroundColor, const Color(0xFF0000A3));
      expect(config.videoBubbleStyle?.backgroundColor, const Color(0xFF0000A4));
      expect(config.audioBubbleStyle?.backgroundColor, const Color(0xFF0000A5));
      expect(
        config.deletedBubbleStyle?.backgroundColor,
        const Color(0xFF0000A6),
      );
      expect(
        config.voiceCallBubbleStyle?.backgroundColor,
        const Color(0xFF0000A7),
      );
      expect(
        config.videoCallBubbleStyle?.backgroundColor,
        const Color(0xFF0000A8),
      );
    });

    testWidgets('every copied per-type style has its border erased', (
      tester,
    ) async {
      // The outer message bubble draws the border; an inner one would double
      // it. Each slot is re-copied with a transparent, zero-width border.
      final config = (await configure(tester, _text(sender: _alice)))!;
      final borders = <String, BoxBorder?>{
        'text': config.textBubbleStyle?.border,
        'image': config.imageBubbleStyle?.border,
        'file': config.fileBubbleStyle?.border,
        'video': config.videoBubbleStyle?.border,
        'audio': config.audioBubbleStyle?.border,
        'deleted': config.deletedBubbleStyle?.border,
        'voiceCall': config.voiceCallBubbleStyle?.border,
        'videoCall': config.videoCallBubbleStyle?.border,
      };
      borders.forEach((slot, border) {
        expect(border, isNotNull, reason: slot);
        expect(
          border,
          Border.all(color: Colors.transparent, width: 0),
          reason: slot,
        );
      });
    });

    testWidgets('the link preview style keeps its own border', (tester) async {
      // This is the one slot the builder hands through as-is rather than
      // re-copying, so its border survives — the control for the assertion
      // above. It still has to pick the right side.
      AdditionalConfigurations? sent;
      AdditionalConfigurations? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              const border = Border.fromBorderSide(BorderSide(width: 7));
              final out = CometChatOutgoingMessageBubbleStyle(
                linkPreviewBubbleStyle: const CometChatLinkPreviewBubbleStyle(
                  backgroundColor: Color(0xFF00BB01),
                  border: border,
                ),
              );
              final inc = CometChatIncomingMessageBubbleStyle(
                linkPreviewBubbleStyle: const CometChatLinkPreviewBubbleStyle(
                  backgroundColor: Color(0xFF00BB02),
                  border: border,
                ),
              );
              sent = BubbleUIBuilder.getAdditionalConfigurations(
                context,
                _text(sender: _alice),
                null,
                inc,
                out,
                null,
              );
              received = BubbleUIBuilder.getAdditionalConfigurations(
                context,
                _text(sender: _bob),
                null,
                inc,
                out,
                null,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      expect(
        sent!.linkPreviewBubbleStyle?.backgroundColor,
        const Color(0xFF00BB01),
      );
      expect(
        received!.linkPreviewBubbleStyle?.backgroundColor,
        const Color(0xFF00BB02),
      );
      expect(
        sent!.linkPreviewBubbleStyle?.border,
        const Border.fromBorderSide(BorderSide(width: 7)),
        reason: 'the link preview border is not erased like the others',
      );
    });

    testWidgets('the extension bubble styles are projected per side, with the '
        'border erased', (tester) async {
      // Threaded headers, pinned rows and message info render through this
      // builder, so the polls / sticker / collaborative styles have to reach
      // those bubbles the way they reach the message list's.
      const border = Border.fromBorderSide(BorderSide(width: 7));
      AdditionalConfigurations? sent;
      AdditionalConfigurations? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              const out = CometChatOutgoingMessageBubbleStyle(
                pollsBubbleStyle: CometChatPollsBubbleStyle(
                  backgroundColor: Color(0xFF00CC01),
                  border: border,
                ),
                stickerBubbleStyle: CometChatStickerBubbleStyle(
                  backgroundColor: Color(0xFF00CC02),
                  border: border,
                ),
                collaborativeDocumentBubbleStyle:
                    CometChatCollaborativeBubbleStyle(
                      backgroundColor: Color(0xFF00CC03),
                      border: border,
                    ),
                collaborativeWhiteboardBubbleStyle:
                    CometChatCollaborativeBubbleStyle(
                      backgroundColor: Color(0xFF00CC04),
                      border: border,
                    ),
              );
              const inc = CometChatIncomingMessageBubbleStyle(
                pollsBubbleStyle: CometChatPollsBubbleStyle(
                  backgroundColor: Color(0xFF00DD01),
                ),
                stickerBubbleStyle: CometChatStickerBubbleStyle(
                  backgroundColor: Color(0xFF00DD02),
                ),
                collaborativeDocumentBubbleStyle:
                    CometChatCollaborativeBubbleStyle(
                      backgroundColor: Color(0xFF00DD03),
                    ),
                collaborativeWhiteboardBubbleStyle:
                    CometChatCollaborativeBubbleStyle(
                      backgroundColor: Color(0xFF00DD04),
                    ),
              );
              sent = BubbleUIBuilder.getAdditionalConfigurations(
                context,
                _text(sender: _alice),
                null,
                inc,
                out,
                null,
              );
              received = BubbleUIBuilder.getAdditionalConfigurations(
                context,
                _text(sender: _bob),
                null,
                inc,
                out,
                null,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      final erased = Border.all(color: Colors.transparent, width: 0);

      expect(sent!.pollsBubbleStyle?.backgroundColor, const Color(0xFF00CC01));
      expect(
        sent!.stickerBubbleStyle?.backgroundColor,
        const Color(0xFF00CC02),
      );
      expect(
        sent!.collaborativeDocumentBubbleStyle?.backgroundColor,
        const Color(0xFF00CC03),
      );
      expect(
        sent!.collaborativeWhiteboardBubbleStyle?.backgroundColor,
        const Color(0xFF00CC04),
      );
      expect(sent!.pollsBubbleStyle?.border, erased);
      expect(sent!.stickerBubbleStyle?.border, erased);
      expect(sent!.collaborativeDocumentBubbleStyle?.border, erased);
      expect(sent!.collaborativeWhiteboardBubbleStyle?.border, erased);

      expect(
        received!.pollsBubbleStyle?.backgroundColor,
        const Color(0xFF00DD01),
      );
      expect(
        received!.stickerBubbleStyle?.backgroundColor,
        const Color(0xFF00DD02),
      );
      expect(
        received!.collaborativeDocumentBubbleStyle?.backgroundColor,
        const Color(0xFF00DD03),
      );
      expect(
        received!.collaborativeWhiteboardBubbleStyle?.backgroundColor,
        const Color(0xFF00DD04),
      );
    });

    testWidgets('the translation style is picked per side, as-is', (
      tester,
    ) async {
      // The translation sits inside the text bubble rather than being the
      // bubble, so, like the link preview, it is handed through untouched.
      AdditionalConfigurations? sent;
      AdditionalConfigurations? received;
      final out = CometChatMessageTranslationBubbleStyle(
        dividerColor: const Color(0xFF00EE01),
      );
      final inc = CometChatMessageTranslationBubbleStyle(
        dividerColor: const Color(0xFF00EE02),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              sent = BubbleUIBuilder.getAdditionalConfigurations(
                context,
                _text(sender: _alice),
                null,
                CometChatIncomingMessageBubbleStyle(
                  messageTranslationBubbleStyle: inc,
                ),
                CometChatOutgoingMessageBubbleStyle(
                  messageTranslationBubbleStyle: out,
                ),
                null,
              );
              received = BubbleUIBuilder.getAdditionalConfigurations(
                context,
                _text(sender: _bob),
                null,
                CometChatIncomingMessageBubbleStyle(
                  messageTranslationBubbleStyle: inc,
                ),
                CometChatOutgoingMessageBubbleStyle(
                  messageTranslationBubbleStyle: out,
                ),
                null,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      expect(
        sent!.messageTranslationBubbleStyle?.dividerColor,
        const Color(0xFF00EE01),
      );
      expect(
        received!.messageTranslationBubbleStyle?.dividerColor,
        const Color(0xFF00EE02),
      );
    });

    testWidgets('formatters reach the configuration', (tester) async {
      AdditionalConfigurations? result;
      final formatter = CometChatMentionsFormatter();
      final message = _text();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = BubbleUIBuilder.getAdditionalConfigurations(
                context,
                message,
                [formatter],
                null,
                null,
                null,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      expect(result!.textFormatters, hasLength(1));
      expect(result!.textFormatters!.single.message, same(message));
    });
  });

  // ==========================================================================
  group('CometChatMessageBubbleStyleData', () {
    CometChatMessageBubbleStyleData base() => CometChatMessageBubbleStyleData(
      backgroundColor: const Color(0xFF111111),
      border: Border.all(color: const Color(0xFF222222)),
      borderRadius: BorderRadius.circular(4),
      senderNameTextStyle: const TextStyle(fontSize: 11),
      threadedMessageIndicatorIconColor: const Color(0xFF333333),
      threadedMessageIndicatorTextStyle: const TextStyle(fontSize: 12),
      moderationBackgroundColor: const Color(0xFF444444),
      moderationTextStyle: const TextStyle(fontSize: 13),
      moderationIconTint: const Color(0xFF555555),
      exceptionBackgroundColor: const Color(0xFF666666),
      exceptionTextStyle: const TextStyle(fontSize: 14),
      exceptionIconTint: const Color(0xFF777777),
    );

    test('copyWith with no arguments keeps every field', () {
      final copy = base().copyWith();
      expect(copy.backgroundColor, const Color(0xFF111111));
      expect(copy.borderRadius, BorderRadius.circular(4));
      expect(copy.senderNameTextStyle, const TextStyle(fontSize: 11));
      expect(copy.threadedMessageIndicatorIconColor, const Color(0xFF333333));
      expect(copy.moderationBackgroundColor, const Color(0xFF444444));
      expect(copy.moderationTextStyle, const TextStyle(fontSize: 13));
      expect(copy.moderationIconTint, const Color(0xFF555555));
      expect(copy.exceptionBackgroundColor, const Color(0xFF666666));
      expect(copy.exceptionTextStyle, const TextStyle(fontSize: 14));
      expect(copy.exceptionIconTint, const Color(0xFF777777));
    });

    test('copyWith replaces only what it is given', () {
      final copy = base().copyWith(backgroundColor: const Color(0xFFAAAAAA));
      expect(copy.backgroundColor, const Color(0xFFAAAAAA));
      expect(copy.borderRadius, BorderRadius.circular(4));
      expect(copy.exceptionIconTint, const Color(0xFF777777));
    });

    test('merge(null) returns the receiver itself', () {
      final b = base();
      expect(identical(b.merge(null), b), isTrue);
    });

    test('merge takes every non-null field from the other side', () {
      final other = CometChatMessageBubbleStyleData(
        backgroundColor: const Color(0xFFAAAAA1),
        border: Border.all(color: const Color(0xFFAAAAA2)),
        borderRadius: BorderRadius.circular(9),
        senderNameTextStyle: const TextStyle(fontSize: 21),
        threadedMessageIndicatorIconColor: const Color(0xFFAAAAA3),
        threadedMessageIndicatorTextStyle: const TextStyle(fontSize: 22),
        moderationBackgroundColor: const Color(0xFFAAAAA4),
        moderationTextStyle: const TextStyle(fontSize: 23),
        moderationIconTint: const Color(0xFFAAAAA5),
        exceptionBackgroundColor: const Color(0xFFAAAAA6),
        exceptionTextStyle: const TextStyle(fontSize: 24),
        exceptionIconTint: const Color(0xFFAAAAA7),
        messageBubbleAvatarStyle: const CometChatAvatarStyle(),
        messageBubbleDateStyle: const CometChatDateStyle(),
        messageReceiptStyle: CometChatMessageReceiptStyle(),
      );
      final merged = base().merge(other);
      expect(merged.backgroundColor, const Color(0xFFAAAAA1));
      expect(merged.border, other.border);
      expect(merged.borderRadius, BorderRadius.circular(9));
      expect(merged.senderNameTextStyle, const TextStyle(fontSize: 21));
      expect(merged.threadedMessageIndicatorIconColor, const Color(0xFFAAAAA3));
      expect(
        merged.threadedMessageIndicatorTextStyle,
        const TextStyle(fontSize: 22),
      );
      expect(merged.moderationBackgroundColor, const Color(0xFFAAAAA4));
      expect(merged.moderationTextStyle, const TextStyle(fontSize: 23));
      expect(merged.moderationIconTint, const Color(0xFFAAAAA5));
      expect(merged.exceptionBackgroundColor, const Color(0xFFAAAAA6));
      expect(merged.exceptionTextStyle, const TextStyle(fontSize: 24));
      expect(merged.exceptionIconTint, const Color(0xFFAAAAA7));
      expect(
        merged.messageBubbleAvatarStyle,
        same(other.messageBubbleAvatarStyle),
      );
      expect(merged.messageBubbleDateStyle, same(other.messageBubbleDateStyle));
      expect(merged.messageReceiptStyle, same(other.messageReceiptStyle));
    });

    test('merge keeps the receiver\'s value where the other side is null', () {
      final merged = base().merge(
        CometChatMessageBubbleStyleData(
          backgroundColor: const Color(0xFFAAAAA1),
        ),
      );
      expect(merged.backgroundColor, const Color(0xFFAAAAA1));
      // Everything the other side left null falls through.
      expect(merged.borderRadius, BorderRadius.circular(4));
      expect(merged.senderNameTextStyle, const TextStyle(fontSize: 11));
      expect(merged.exceptionIconTint, const Color(0xFF777777));
    });

    test('merge does not mutate either side', () {
      final a = base();
      final b = CometChatMessageBubbleStyleData(
        backgroundColor: const Color(0xFFAAAAA1),
      );
      a.merge(b);
      expect(a.backgroundColor, const Color(0xFF111111));
      expect(b.borderRadius, isNull);
    });
  });
}
