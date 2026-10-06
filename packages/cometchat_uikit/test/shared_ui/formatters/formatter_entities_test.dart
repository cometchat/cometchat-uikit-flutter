/// The rich-text entities and the three pattern formatters —
/// Track 3 TEST3 / construction coverage (ENG-38684).
///
/// Seven exported classes that no test had ever constructed: the three
/// value objects the rich-text controller passes around
/// ([FormattedSegment], [FormatResult], [LinkData]), the [AttributedText] span
/// descriptor every formatter emits, and the email, phone and URL formatters
/// themselves.
///
/// The entities are `Equatable`, which makes their `props` list load-bearing —
/// a field left out of it makes two different values compare equal, and the
/// controller de-duplicates segments by equality. So each one is tested for
/// what it distinguishes, not only for what it stores.
///
/// [FormatCompatibility] comes along because it is the rule the toolbar
/// enables and disables buttons from, and its matrix is deliberately
/// asymmetric in one place.
///
///   flutter test test/shared_ui/formatters/formatter_entities_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _selection = TextSelection.collapsed(offset: 4);

void main() {
  // ---------------------------------------------------------------------------
  group('FormattedSegment', () {
    const segment = FormattedSegment(
      start: 0,
      end: 4,
      formatType: FormatType.bold,
      text: 'Bold',
    );

    test('carries its range, type and text', () {
      expect(segment.start, 0);
      expect(segment.end, 4);
      expect(segment.formatType, FormatType.bold);
      expect(segment.text, 'Bold');
      expect(segment.metadata, isNull);
    });

    test('equality distinguishes every field, metadata included', () {
      expect(
        segment,
        const FormattedSegment(
          start: 0,
          end: 4,
          formatType: FormatType.bold,
          text: 'Bold',
        ),
      );
      expect(segment, isNot(segment.copyOfWithStart(1)));
      expect(
        segment,
        isNot(
          const FormattedSegment(
            start: 0,
            end: 4,
            formatType: FormatType.italic,
            text: 'Bold',
          ),
        ),
      );
      expect(
        segment,
        isNot(
          const FormattedSegment(
            start: 0,
            end: 4,
            formatType: FormatType.bold,
            text: 'Bold',
            metadata: {'href': 'https://cometchat.com'},
          ),
        ),
        reason: 'metadata is in props, so a link segment is not a bare one',
      );
    });

    test(
      'two equal segments hash alike, which is what de-duplication needs',
      () {
        // Built through a function so the analyzer cannot fold the two into one
        // constant — the point is the runtime hash, not the compiler's.
        FormattedSegment build(int start) => FormattedSegment(
          start: start,
          end: 4,
          formatType: FormatType.bold,
          text: 'Bold',
        );

        expect(<FormattedSegment>{build(0), build(0)}, hasLength(1));
        expect(<FormattedSegment>{build(0), build(1)}, hasLength(2));
        expect(build(0).hashCode, segment.hashCode);
      },
    );

    test('toString names the range and the type', () {
      expect(segment.toString(), contains('start: 0'));
      expect(segment.toString(), contains('end: 4'));
      expect(segment.toString(), contains('bold'));
    });

    test('metadata carries the link target for a link segment', () {
      const link = FormattedSegment(
        start: 0,
        end: 9,
        formatType: FormatType.link,
        text: 'CometChat',
        metadata: {'url': 'https://cometchat.com'},
      );

      expect(link.metadata!['url'], 'https://cometchat.com');
    });
  });

  // ---------------------------------------------------------------------------
  group('FormatResult', () {
    const result = FormatResult(
      newText: '**Bold**',
      newSelection: _selection,
      formatApplied: FormatType.bold,
    );

    test('carries the rewritten text, the new selection and the format', () {
      expect(result.newText, '**Bold**');
      expect(result.newSelection, _selection);
      expect(result.formatApplied, FormatType.bold);
    });

    test('equality distinguishes the selection as well as the text', () {
      expect(
        result,
        const FormatResult(
          newText: '**Bold**',
          newSelection: _selection,
          formatApplied: FormatType.bold,
        ),
      );
      expect(
        result,
        isNot(
          const FormatResult(
            newText: '**Bold**',
            newSelection: TextSelection.collapsed(offset: 8),
            formatApplied: FormatType.bold,
          ),
        ),
        reason: 'the caret moving is a different result',
      );
      expect(
        result,
        isNot(
          const FormatResult(
            newText: '_Bold_',
            newSelection: _selection,
            formatApplied: FormatType.italic,
          ),
        ),
      );
    });

    test('toString names the applied format', () {
      expect(result.toString(), contains('bold'));
      expect(result.toString(), contains('**Bold**'));
    });
  });

  // ---------------------------------------------------------------------------
  group('LinkData', () {
    const link = LinkData(
      url: 'https://cometchat.com',
      displayText: 'CometChat',
    );

    test('keeps the url and the display text apart', () {
      expect(link.url, 'https://cometchat.com');
      expect(link.displayText, 'CometChat');
    });

    test('equality distinguishes both halves', () {
      expect(
        link,
        const LinkData(url: 'https://cometchat.com', displayText: 'CometChat'),
      );
      expect(
        link,
        isNot(
          const LinkData(url: 'https://cometchat.com', displayText: 'Home'),
        ),
        reason: 'same target, different label, different link',
      );
      expect(
        link,
        isNot(
          const LinkData(url: 'https://example.com', displayText: 'CometChat'),
        ),
      );
    });

    test('an empty display text is allowed — a bare url pasted in', () {
      const bare = LinkData(url: 'https://cometchat.com', displayText: '');
      expect(bare.displayText, isEmpty);
      expect(bare, isNot(link));
    });
  });

  // ---------------------------------------------------------------------------
  group('FormatType', () {
    test('every value has a distinct icon and a distinct label', () {
      final icons = FormatType.values.map((f) => f.icon).toSet();
      final labels = FormatType.values.map((f) => f.label).toSet();

      expect(icons, hasLength(FormatType.values.length));
      expect(labels, hasLength(FormatType.values.length));
    });

    test('the labels are human-readable, not enum names', () {
      expect(FormatType.inlineCode.label, 'Inline Code');
      expect(FormatType.orderedList.label, 'Numbered List');
      expect(FormatType.blockquote.label, 'Quote');
    });
  });

  // ---------------------------------------------------------------------------
  group('FormatCompatibility', () {
    test('with nothing active, everything is available', () {
      expect(FormatCompatibility.isCompatible(FormatType.bold, {}), isTrue);
      expect(
        FormatCompatibility.getCompatibleFormats({}),
        FormatType.values.toSet(),
      );
      expect(FormatCompatibility.getDisabledFormats({}), isEmpty);
    });

    test('a format is always compatible with itself — that is how it is '
        'turned off again', () {
      expect(
        FormatCompatibility.isCompatible(FormatType.codeBlock, {
          FormatType.codeBlock,
        }),
        isTrue,
      );
    });

    test('the inline formats combine freely', () {
      expect(
        FormatCompatibility.isCompatible(FormatType.bold, {
          FormatType.italic,
          FormatType.underline,
        }),
        isTrue,
      );
      expect(
        FormatCompatibility.getDisabledFormats({
          FormatType.bold,
          FormatType.italic,
        }),
        isEmpty,
      );
    });

    test('a code block disables the inline formats but not the line ones', () {
      final disabled = FormatCompatibility.getDisabledFormats({
        FormatType.codeBlock,
      });

      expect(
        disabled,
        containsAll(<FormatType>{
          FormatType.bold,
          FormatType.italic,
          FormatType.underline,
          FormatType.strikethrough,
          FormatType.inlineCode,
          FormatType.link,
        }),
      );
      expect(
        disabled,
        isNot(contains(FormatType.bulletList)),
        reason: 'tapping a list while in a code block switches modes',
      );
      expect(disabled, isNot(contains(FormatType.orderedList)));
      expect(disabled, isNot(contains(FormatType.blockquote)));
    });

    test('the relation is deliberately one-way for code block', () {
      // You may turn a code block on while bold is active, but not bold while
      // a code block is active. The matrix says so on purpose — the comment in
      // the source calls it out — so this asserts the asymmetry rather than
      // treating it as a bug.
      expect(
        FormatCompatibility.isCompatible(FormatType.codeBlock, {
          FormatType.bold,
        }),
        isTrue,
      );
      expect(
        FormatCompatibility.isCompatible(FormatType.bold, {
          FormatType.codeBlock,
        }),
        isFalse,
      );
    });

    test('a target must clear every active format, not just one', () {
      // bold is fine with italic, and not fine with codeBlock, so the
      // combination has to fail.
      expect(
        FormatCompatibility.isCompatible(FormatType.bold, {
          FormatType.italic,
          FormatType.codeBlock,
        }),
        isFalse,
      );
    });

    test('disabled and compatible are complements over the whole enum', () {
      const active = {FormatType.codeBlock};
      final disabled = FormatCompatibility.getDisabledFormats(active);
      final compatible = FormatCompatibility.getCompatibleFormats(active);

      expect(disabled.intersection(compatible), isEmpty);
      expect(disabled.union(compatible), FormatType.values.toSet());
    });
  });

  // ---------------------------------------------------------------------------
  group('AttributedText', () {
    test('requires only a range and defaults to an inline span', () {
      final span = AttributedText(start: 0, end: 5);

      expect(span.start, 0);
      expect(span.end, 5);
      expect(span.isBlockElement, isFalse);
      expect(span.style, isNull);
      expect(span.underlyingText, isNull);
      expect(span.onTap, isNull);
      expect(span.backgroundColor, isNull);
      expect(span.padding, isNull);
      expect(span.borderRadius, isNull);
      expect(span.border, isNull);
    });

    test('a block element carries its own box decoration', () {
      final border = Border.all(width: 1);
      final span = AttributedText(
        start: 0,
        end: 12,
        isBlockElement: true,
        backgroundColor: const Color(0xFFEDF2F2),
        padding: const EdgeInsets.all(8),
        borderRadius: 6,
        border: border,
      );

      expect(span.isBlockElement, isTrue);
      expect(span.backgroundColor, const Color(0xFFEDF2F2));
      expect(span.padding, const EdgeInsets.all(8));
      expect(span.borderRadius, 6);
      expect(span.border, border);
    });

    test('underlyingText is the target, distinct from the rendered range', () {
      // A mention renders "@Alice" but resolves to a uid; a link renders a
      // label but navigates to a url. That indirection is this field.
      final span = AttributedText(
        start: 4,
        end: 10,
        underlyingText: 'https://cometchat.com',
      );

      expect(span.underlyingText, 'https://cometchat.com');
    });

    test('onTap is invoked with the underlying text by the caller', () {
      String? tapped;
      final span = AttributedText(
        start: 0,
        end: 9,
        underlyingText: 'https://cometchat.com',
        onTap: (value) => tapped = value,
      );

      span.onTap!(span.underlyingText!);
      expect(tapped, 'https://cometchat.com');
    });

    test(
      'every field is mutable — formatters adjust ranges as text shifts',
      () {
        final span = AttributedText(start: 0, end: 5)
          ..start = 3
          ..end = 8
          ..style = const TextStyle(fontWeight: FontWeight.bold)
          ..isBlockElement = true;

        expect(span.start, 3);
        expect(span.end, 8);
        expect(span.style?.fontWeight, FontWeight.bold);
        expect(span.isBlockElement, isTrue);
      },
    );

    test('toString names the range and the underlying text', () {
      final span = AttributedText(start: 1, end: 2, underlyingText: 'x');

      expect(span.toString(), contains('start: 1'));
      expect(span.toString(), contains('end: 2'));
      expect(span.toString(), contains('x'));
    });
  });

  // ---------------------------------------------------------------------------
  group('the three pattern formatters', () {
    test('each defaults to the pattern for its own kind', () {
      expect(CometChatEmailFormatter().pattern, isNotNull);
      expect(CometChatPhoneNumberFormatter().pattern, isNotNull);
      expect(CometChatUrlFormatter().pattern, isNotNull);

      expect(
        CometChatEmailFormatter().pattern!.hasMatch('alice@example.com'),
        isTrue,
      );
      expect(
        CometChatUrlFormatter().pattern!.hasMatch('https://cometchat.com'),
        isTrue,
      );
    });

    test('the default patterns do not match each other kind', () {
      expect(
        CometChatEmailFormatter().pattern!.hasMatch('not an email'),
        isFalse,
      );
      expect(CometChatUrlFormatter().pattern!.hasMatch('alice'), isFalse);
    });

    test('a supplied pattern overrides the default', () {
      final custom = RegExp(r'ONLY-THIS');
      final formatter = CometChatUrlFormatter(pattern: custom);

      expect(formatter.pattern, same(custom));
      expect(formatter.pattern!.hasMatch('ONLY-THIS'), isTrue);
      expect(formatter.pattern!.hasMatch('https://cometchat.com'), isFalse);
    });

    test('init leaves an already-set pattern alone', () {
      // `init` uses `??=`, so it seeds a null pattern and never clobbers one
      // the integrator passed.
      final custom = RegExp(r'ONLY-THIS');
      final formatter = CometChatUrlFormatter(pattern: custom)..init();

      expect(formatter.pattern, same(custom));
    });

    test('onSearch is stored and invoked with the matched text', () async {
      String? searched;
      final formatter = CometChatUrlFormatter(
        onSearch: (value) async {
          searched = value;
          return true;
        },
      );

      await formatter.onSearch!('https://cometchat.com');
      expect(searched, 'https://cometchat.com');
    });

    testWidgets('getMessageBubbleTextStyle falls back to the theme, and a '
        'supplied builder wins', (tester) async {
      const override = TextStyle(fontSize: 33);
      late TextStyle derived;
      late TextStyle overridden;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              derived = CometChatEmailFormatter().getMessageBubbleTextStyle(
                context,
                BubbleAlignment.left,
              );
              overridden = CometChatEmailFormatter(
                messageBubbleTextStyle: (_, _, {forConversation = false}) =>
                    override,
              ).getMessageBubbleTextStyle(context, BubbleAlignment.left);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(derived.color, isNotNull);
      expect(overridden, override);
    });

    testWidgets('the derived bubble style differs by alignment', (
      tester,
    ) async {
      late TextStyle incoming;
      late TextStyle outgoing;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final formatter = CometChatUrlFormatter();
              incoming = formatter.getMessageBubbleTextStyle(
                context,
                BubbleAlignment.left,
              );
              outgoing = formatter.getMessageBubbleTextStyle(
                context,
                BubbleAlignment.right,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(incoming.color, isNot(outgoing.color));
    });

    testWidgets('FIXED — getMessageInputTextStyle returns a default style on '
        'all three', (tester) async {
      // All three used to override it as `throw UnimplementedError()` with a
      // TODO. It is public API inherited from CometChatTextFormatter, so an
      // integrator writing a custom composer against the documented surface got
      // an exception rather than a style. ENG-38686 made them return a default
      // style, matching CometChatMarkdownTextFormatter. This case was written to
      // go red the day that happened, and did.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              for (final formatter in <CometChatTextFormatter>[
                CometChatEmailFormatter(),
                CometChatPhoneNumberFormatter(),
                CometChatUrlFormatter(),
              ]) {
                expect(
                  formatter.getMessageInputTextStyle(context),
                  isA<TextStyle>(),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}

extension on FormattedSegment {
  /// A copy with a different start, for the equality cases.
  FormattedSegment copyOfWithStart(int newStart) => FormattedSegment(
    start: newStart,
    end: end,
    formatType: formatType,
    text: text,
    metadata: metadata,
  );
}
