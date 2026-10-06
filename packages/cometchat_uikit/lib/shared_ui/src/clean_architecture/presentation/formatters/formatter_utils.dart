import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'cometchat_text_formatter.dart';
import 'attributed_text.dart';
import '../theme/theme.dart';
import '../../../../cometchat_uikit_shared.dart' show BubbleAlignment;
import '../../../formatter/markdown/markdown_text_formatter.dart';

///[FormatterUtils] is an utility class which is used to style the text in the message bubble and the conversation subtitle
class FormatterUtils {
  /// Builds the [WidgetSpan] used for any inline run that needs a box —
  /// a mention pill, inline code, a code block, a tappable link.
  ///
  /// Two things every such span needs, and neither is the default:
  ///
  /// **The child must not scale its own text.** `RenderParagraph` already
  /// scales a placeholder: it sizes the box by the ambient text scale and
  /// paints the child through a matching transform. A `Text` inside that box
  /// resolves `MediaQuery.textScaler` a second time, so the run ends up scaled
  /// twice over — at a system font scale of 2.0 a mention occupied an 80px
  /// line where the surrounding text took 40px. That is ENG-39492: Android's
  /// larger default display size made it obvious, but nothing about it is
  /// platform-specific — it is invisible only at a scale of exactly 1.0.
  ///
  /// **The box sits on the middle of the line.** The default,
  /// [PlaceholderAlignment.bottom], hangs the box below the surrounding
  /// baseline and grows the line box by roughly the font's ascent.
  static WidgetSpan _inlineSpan({
    required Widget child,
    PlaceholderAlignment alignment = PlaceholderAlignment.middle,
  }) => WidgetSpan(
    alignment: alignment,
    child: MediaQuery.withNoTextScaling(child: child),
  );

  /// Ensures a [MarkdownTextFormatter] is always present in the formatters list.
  ///
  /// - If [formatters] is null or empty, returns `[MarkdownTextFormatter()]`.
  /// - If [formatters] already contains a [MarkdownTextFormatter], returns as-is.
  /// - Otherwise, prepends a [MarkdownTextFormatter] so markdown is processed first.
  static List<CometChatTextFormatter> ensureMarkdownFormatter(
    List<CometChatTextFormatter>? formatters,
  ) {
    if (formatters == null || formatters.isEmpty) {
      return [MarkdownTextFormatter()];
    }
    if (formatters.any((f) => f is MarkdownTextFormatter)) {
      return formatters;
    }
    return [MarkdownTextFormatter(), ...formatters];
  }

  /// Builds a list of widgets that properly handles block-level elements (code blocks, blockquotes)
  /// Returns a list of widgets that can be arranged in a Column for proper block rendering
  static List<Widget> buildTextContent(
    String text,
    List<CometChatTextFormatter>? formatters,
    BuildContext context,
    BubbleAlignment? alignment, {
    TextStyle? textStyle,
  }) {
    final List<Widget> widgets = [];
    List<AttributedText> attributedTexts = [];

    // Collect all attributed texts from formatters
    for (CometChatTextFormatter formatter in formatters ?? []) {
      attributedTexts = formatter.getAttributedText(
        text,
        context,
        alignment,
        existingAttributes: attributedTexts,
        forConversation: false,
      );
    }

    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);

    final defaultTextStyle =
        textStyle ??
        TextStyle(
          color: alignment == BubbleAlignment.right
              ? colorPalette.white
              : colorPalette.textPrimary,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
          fontFamily: typography.body?.regular?.fontFamily,
        );

    // Sort attributed texts by start position
    attributedTexts.sort((a, b) => a.start.compareTo(b.start));

    // Separate block elements from inline elements
    final blockElements = attributedTexts
        .where((a) => a.isBlockElement)
        .toList();
    final inlineElements = attributedTexts
        .where((a) => !a.isBlockElement)
        .toList();

    if (blockElements.isEmpty) {
      // No block elements - use traditional RichText approach
      widgets.add(
        RichText(
          text: TextSpan(
            style: defaultTextStyle,
            children: buildTextSpan(
              text,
              formatters,
              context,
              alignment,
              textStyle: textStyle,
            ),
          ),
        ),
      );
      return widgets;
    }

    // Process text with block elements
    int currentPos = 0;

    for (final blockAttr in blockElements) {
      // Validate indices
      if (blockAttr.start < 0 ||
          blockAttr.end > text.length ||
          blockAttr.start > blockAttr.end) {
        continue;
      }

      // Add text before this block element
      if (currentPos < blockAttr.start) {
        final beforeText = text.substring(currentPos, blockAttr.start).trim();
        if (beforeText.isNotEmpty) {
          // Build inline spans for text before block
          final beforeSpans = _buildInlineSpans(
            beforeText,
            inlineElements,
            currentPos,
            blockAttr.start,
            context,
            alignment,
            defaultTextStyle,
          );
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RichText(
                text: TextSpan(style: defaultTextStyle, children: beforeSpans),
              ),
            ),
          );
        }
      }

      // Add the block element widget
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _buildBlockWidget(
            blockAttr,
            context,
            alignment,
            colorPalette,
            typography,
          ),
        ),
      );

      currentPos = blockAttr.end;
    }

    // Add remaining text after last block element
    if (currentPos < text.length) {
      final afterText = text.substring(currentPos).trim();
      if (afterText.isNotEmpty) {
        final afterSpans = _buildInlineSpans(
          afterText,
          inlineElements,
          currentPos,
          text.length,
          context,
          alignment,
          defaultTextStyle,
        );
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: RichText(
              text: TextSpan(style: defaultTextStyle, children: afterSpans),
            ),
          ),
        );
      }
    }

    return widgets.isEmpty ? [const SizedBox.shrink()] : widgets;
  }

  /// Builds a proper block-level widget for code blocks and blockquotes (Slack-style)
  static Widget _buildBlockWidget(
    AttributedText attr,
    BuildContext context,
    BubbleAlignment? alignment,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
  ) {
    final displayText = attr.underlyingText ?? '';

    // Check if this has a left border (Slack-style accent bar)
    final hasLeftBorder = attr.border != null;

    // Check if this is a blockquote (italic style) vs code block (monospace)
    final isBlockquote = attr.style?.fontStyle == FontStyle.italic;

    if (hasLeftBorder) {
      // Slack-style block with left accent bar (for both code blocks and blockquotes)
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: attr.backgroundColor,
          borderRadius: BorderRadius.circular(attr.borderRadius ?? 6),
          border: attr.border,
        ),
        child: Padding(
          padding:
              attr.padding ??
              const EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 12),
          child: Text(
            displayText,
            style:
                attr.style ??
                TextStyle(
                  fontFamily: isBlockquote ? null : 'monospace',
                  fontStyle: isBlockquote ? FontStyle.italic : null,
                  color: alignment == BubbleAlignment.right
                      ? colorPalette.white
                      : isBlockquote
                      ? colorPalette.textSecondary
                      : colorPalette.textPrimary,
                  fontSize: typography.body?.regular?.fontSize,
                ),
          ),
        ),
      );
    } else {
      // Fallback: block without left border
      return Container(
        width: double.infinity,
        padding: attr.padding ?? const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: attr.backgroundColor ?? colorPalette.background3,
          borderRadius: BorderRadius.circular(attr.borderRadius ?? 6),
        ),
        child: Text(
          displayText,
          style:
              attr.style ??
              TextStyle(
                fontFamily: 'monospace',
                color: alignment == BubbleAlignment.right
                    ? colorPalette.white
                    : colorPalette.textPrimary,
                fontSize: typography.body?.regular?.fontSize,
              ),
        ),
      );
    }
  }

  /// Builds inline spans for text segments, applying inline formatters
  static List<InlineSpan> _buildInlineSpans(
    String segmentText,
    List<AttributedText> inlineElements,
    int segmentStart,
    int segmentEnd,
    BuildContext context,
    BubbleAlignment? alignment,
    TextStyle defaultStyle,
  ) {
    final List<InlineSpan> spans = [];

    // Filter inline elements that fall within this segment
    final relevantInlines = inlineElements
        .where((attr) => attr.start >= segmentStart && attr.end <= segmentEnd)
        .toList();

    if (relevantInlines.isEmpty) {
      spans.add(TextSpan(text: segmentText, style: defaultStyle));
      return spans;
    }

    int pos = 0;
    for (final attr in relevantInlines) {
      final relativeStart = attr.start - segmentStart;
      final relativeEnd = attr.end - segmentStart;

      if (pos < relativeStart) {
        spans.add(
          TextSpan(
            text: segmentText.substring(pos, relativeStart),
            style: defaultStyle,
          ),
        );
      }

      spans.add(
        _inlineSpan(
          child: Container(
            padding: attr.padding,
            decoration: BoxDecoration(
              color: attr.backgroundColor,
              borderRadius: BorderRadius.circular(attr.borderRadius ?? 0),
            ),
            child: Text(
              attr.underlyingText ??
                  segmentText.substring(relativeStart, relativeEnd),
              style: attr.style ?? defaultStyle,
            ),
          ),
        ),
      );

      pos = relativeEnd;
    }

    if (pos < segmentText.length) {
      spans.add(
        TextSpan(text: segmentText.substring(pos), style: defaultStyle),
      );
    }

    return spans;
  }

  ///[buildTextSpan] is a method which is used to style the text in the message bubble and the conversation subtitle
  ///It takes [text], [formatters], [theme], [alignment] and [forConversation] as a parameter
  ///[text] is a string which needs to be styled
  ///[formatters] is a list of [CometChatTextFormatter] which is used to style the text
  ///[theme] is a object of [CometChatTheme] which is used to style the text
  ///[alignment] is a object of [BubbleAlignment] which is used to style the text
  ///[forConversation] is a boolean which is used to style the text in the conversation subtitle
  static List<InlineSpan> buildTextSpan(
    String text,
    List<CometChatTextFormatter>? formatters,
    BuildContext context,
    BubbleAlignment? alignment, {
    bool forConversation = false,
    TextStyle? textStyle,
  }) {
    List<InlineSpan> textSpan = [];
    List<AttributedText> attributedTexts = [];
    for (CometChatTextFormatter formatter in formatters ?? []) {
      attributedTexts = formatter.getAttributedText(
        text,
        context,
        alignment,
        existingAttributes: attributedTexts,
        forConversation: forConversation,
      );
    }
    CometChatColorPalette colorPalette = CometChatThemeHelper.getColorPalette(
      context,
    );
    CometChatTypography typography = CometChatThemeHelper.getTypography(
      context,
    );

    int start = 0;

    for (AttributedText attributedText in attributedTexts) {
      // Validate indices before substring operations
      if (attributedText.start < 0 ||
          attributedText.start > text.length ||
          attributedText.end < 0 ||
          attributedText.end > text.length ||
          attributedText.start > attributedText.end ||
          start > text.length ||
          start > attributedText.start ||
          start < 0) {
        continue; // Skip invalid attributed text
      }

      // Additional safety check for substring operation
      String beforeText = '';
      if (start < attributedText.start &&
          start >= 0 &&
          attributedText.start <= text.length) {
        beforeText = text.substring(start, attributedText.start);
      }

      textSpan.add(
        TextSpan(
          text: beforeText,
          style: TextStyle(
            color: alignment == BubbleAlignment.right
                ? colorPalette.white
                : forConversation
                ? colorPalette.textSecondary
                : colorPalette.textPrimary,
            fontWeight: typography.body?.regular?.fontWeight,
            fontSize: typography.body?.regular?.fontSize,
            fontFamily: typography.body?.regular?.fontFamily,
          ).merge(textStyle),
        ),
      );

      // Check if this attributed text needs special widget styling (padding, border, background)
      // or if it's a simple inline text replacement
      final needsWidgetSpan =
          attributedText.padding != null ||
          attributedText.border != null ||
          attributedText.backgroundColor != null ||
          attributedText.isBlockElement;

      if (needsWidgetSpan) {
        // For conversation subtitles, flatten block elements (code blocks, blockquotes)
        // into simple inline TextSpans to avoid inflating the list item height.
        if (forConversation) {
          final displayText =
              attributedText.underlyingText ??
              (attributedText.start >= 0 &&
                      attributedText.end <= text.length &&
                      attributedText.start <= attributedText.end
                  ? text.substring(attributedText.start, attributedText.end)
                  : '');
          // For code blocks / block elements: show first line in a compact
          // code-block style container with "..." if there's more content.
          final lines = displayText
              .split('\n')
              .where((l) => l.trim().isNotEmpty)
              .toList();
          final firstLine = lines.isNotEmpty
              ? lines.first.trim()
              : displayText.trim();
          final hasMore = lines.length > 1;
          final truncatedText = hasMore ? '$firstLine ...' : firstLine;

          textSpan.add(
            _inlineSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: attributedText.backgroundColor,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  truncatedText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (attributedText.style ??
                              const TextStyle(fontFamily: 'monospace'))
                          .copyWith(
                            fontSize:
                                (typography.body?.regular?.fontSize ?? 14) - 1,
                          ),
                ),
              ),
            ),
          );
        } else if (!attributedText.isBlockElement &&
            attributedText.border == null) {
          // Inline elements with background/padding (mentions, inline code)
          final displayText =
              attributedText.underlyingText ??
              (attributedText.start >= 0 &&
                      attributedText.end <= text.length &&
                      attributedText.start <= attributedText.end
                  ? text.substring(attributedText.start, attributedText.end)
                  : '');

          textSpan.add(
            _inlineSpan(
              child: Container(
                padding: attributedText.padding,
                decoration: BoxDecoration(
                  color: attributedText.backgroundColor,
                  borderRadius: BorderRadius.circular(
                    attributedText.borderRadius ?? 0,
                  ),
                ),
                child: attributedText.onTap != null
                    ? GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (attributedText.start >= 0 &&
                              attributedText.end <= text.length &&
                              attributedText.start <= attributedText.end) {
                            attributedText.onTap!(
                              text.substring(
                                attributedText.start,
                                attributedText.end,
                              ),
                            );
                          }
                        },
                        child: Text(
                          displayText,
                          style:
                              attributedText.style ??
                              TextStyle(
                                color: alignment == BubbleAlignment.right
                                    ? colorPalette.white
                                    : colorPalette.textPrimary,
                                fontWeight:
                                    typography.body?.regular?.fontWeight,
                                fontSize: typography.body?.regular?.fontSize,
                                fontFamily:
                                    typography.body?.regular?.fontFamily,
                              ).merge(textStyle),
                        ),
                      )
                    : Text(
                        displayText,
                        style:
                            attributedText.style ??
                            TextStyle(
                              color: alignment == BubbleAlignment.right
                                  ? colorPalette.white
                                  : colorPalette.textPrimary,
                              fontWeight: typography.body?.regular?.fontWeight,
                              fontSize: typography.body?.regular?.fontSize,
                              fontFamily: typography.body?.regular?.fontFamily,
                            ).merge(textStyle),
                      ),
              ),
            ),
          );
        } else {
          // Block elements (code blocks, blockquotes) — need WidgetSpan for
          // full-width layout, borders, and multi-line content
          textSpan.add(
            _inlineSpan(
              child: Container(
                padding: attributedText.padding,
                decoration: BoxDecoration(
                  color: attributedText.backgroundColor,
                  borderRadius: BorderRadius.circular(
                    attributedText.borderRadius ?? 0,
                  ),
                  border: attributedText.border,
                ),
                child: attributedText.onTap != null
                    ? GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          // Add safety check for substring operation
                          if (attributedText.start >= 0 &&
                              attributedText.end <= text.length &&
                              attributedText.start <= attributedText.end) {
                            attributedText.onTap!(
                              text.substring(
                                attributedText.start,
                                attributedText.end,
                              ),
                            );
                          }
                        },
                        child: _buildAttributedTextContent(
                          attributedText: attributedText,
                          originalText: text,
                          formatters: formatters,
                          context: context,
                          alignment: alignment,
                          forConversation: forConversation,
                          textStyle: textStyle,
                          colorPalette: colorPalette,
                          typography: typography,
                        ),
                      )
                    : _buildAttributedTextContent(
                        attributedText: attributedText,
                        originalText: text,
                        formatters: formatters,
                        context: context,
                        alignment: alignment,
                        forConversation: forConversation,
                        textStyle: textStyle,
                        colorPalette: colorPalette,
                        typography: typography,
                      ),
              ),
            ),
          );
        }
      } else {
        // Simple inline text replacement - use TextSpan for proper inline flow
        final displayText =
            attributedText.underlyingText ??
            (attributedText.start >= 0 &&
                    attributedText.end <= text.length &&
                    attributedText.start <= attributedText.end
                ? text.substring(attributedText.start, attributedText.end)
                : '');

        if (forConversation) {
          // For conversation subtitles, always use TextSpan so the parent
          // RichText's maxLines/overflow can truncate properly.
          final collapsedText = displayText
              .replaceAll(RegExp(r'\n+'), ' ')
              .trim();
          final spanStyle =
              attributedText.style ??
              TextStyle(
                color: colorPalette.textSecondary,
                fontWeight: typography.body?.regular?.fontWeight,
                fontSize: typography.body?.regular?.fontSize,
                fontFamily: typography.body?.regular?.fontFamily,
              ).merge(textStyle);
          textSpan.add(
            TextSpan(
              text: collapsedText,
              style: spanStyle,
              recognizer: attributedText.onTap != null
                  ? (TapGestureRecognizer()
                      ..onTap = () {
                        if (attributedText.start >= 0 &&
                            attributedText.end <= text.length &&
                            attributedText.start <= attributedText.end) {
                          attributedText.onTap!(
                            text.substring(
                              attributedText.start,
                              attributedText.end,
                            ),
                          );
                        }
                      })
                  : null,
            ),
          );
        } else if (attributedText.onTap != null) {
          textSpan.add(
            _inlineSpan(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => attributedText.onTap!(displayText),
                child: Text(
                  displayText,
                  style:
                      attributedText.style ??
                      TextStyle(
                        color: alignment == BubbleAlignment.right
                            ? colorPalette.white
                            : colorPalette.textPrimary,
                        fontWeight: typography.body?.regular?.fontWeight,
                        fontSize: typography.body?.regular?.fontSize,
                        fontFamily: typography.body?.regular?.fontFamily,
                      ).merge(textStyle),
                ),
              ),
            ),
          );
        } else {
          textSpan.add(
            TextSpan(
              text: displayText,
              style:
                  attributedText.style ??
                  TextStyle(
                    color: alignment == BubbleAlignment.right
                        ? colorPalette.white
                        : colorPalette.textPrimary,
                    fontWeight: typography.body?.regular?.fontWeight,
                    fontSize: typography.body?.regular?.fontSize,
                    fontFamily: typography.body?.regular?.fontFamily,
                  ).merge(textStyle),
            ),
          );
        }
      }
      start = attributedText.end;
    }

    // Validate final substring
    if (start <= text.length) {
      textSpan.add(
        TextSpan(
          text: text.substring(start),
          style: TextStyle(
            color: alignment == BubbleAlignment.right
                ? colorPalette.white
                : forConversation
                ? colorPalette.textSecondary
                : colorPalette.textPrimary,
            fontWeight: typography.body?.regular?.fontWeight,
            fontSize: typography.body?.regular?.fontSize,
            fontFamily: typography.body?.regular?.fontFamily,
          ).merge(textStyle),
        ),
      );
    }

    return textSpan;
  }

  static List<InlineSpan> buildConversationTextSpan(
    String text,
    List<CometChatTextFormatter>? formatters,
    BuildContext context,
    TextStyle? textStyle,
  ) {
    List<InlineSpan> textSpan = [];
    List<AttributedText> attributedTexts = [];
    for (CometChatTextFormatter formatter in formatters ?? []) {
      attributedTexts = formatter.getAttributedText(
        text,
        context,
        BubbleAlignment.left,
        existingAttributes: attributedTexts,
        forConversation: true,
      );
    }
    CometChatColorPalette colorPalette = CometChatThemeHelper.getColorPalette(
      context,
    );
    CometChatTypography typography = CometChatThemeHelper.getTypography(
      context,
    );

    int start = 0;

    for (AttributedText attributedText in attributedTexts) {
      // Validate indices before substring operations
      if (attributedText.start < 0 ||
          attributedText.start > text.length ||
          attributedText.end < 0 ||
          attributedText.end > text.length ||
          attributedText.start > attributedText.end ||
          start > text.length ||
          start > attributedText.start ||
          start < 0) {
        continue; // Skip invalid attributed text
      }

      // Additional safety check for substring operation
      String beforeText = '';
      if (start < attributedText.start &&
          start >= 0 &&
          attributedText.start <= text.length) {
        beforeText = text.substring(start, attributedText.start);
      }

      textSpan.add(
        TextSpan(
          text: beforeText,
          style: TextStyle(
            color: colorPalette.textSecondary,
            fontWeight: typography.body?.regular?.fontWeight,
            fontSize: typography.body?.regular?.fontSize,
            fontFamily: typography.body?.regular?.fontFamily,
          ).merge(textStyle),
        ),
      );

      // Get the display text for this attributed segment
      String displayText =
          attributedText.underlyingText ??
          (attributedText.start >= 0 &&
                  attributedText.end <= text.length &&
                  attributedText.start <= attributedText.end
              ? text.substring(attributedText.start, attributedText.end)
              : '');

      // Truncate URLs for better display in conversation subtitles
      displayText = _truncateUrlForConversation(displayText);

      // Collapse newlines so formatted text stays on a single line
      displayText = displayText.replaceAll(RegExp(r'\n+'), ' ').trim();

      final spanStyle =
          attributedText.style ??
          TextStyle(
            color: colorPalette.textSecondary,
            fontWeight: typography.body?.regular?.fontWeight,
            fontSize: typography.body?.regular?.fontSize,
            fontFamily: typography.body?.regular?.fontFamily,
          ).merge(textStyle);

      // Use TextSpan instead of WidgetSpan so the parent RichText's
      // maxLines/overflow can truncate properly without height expansion.
      textSpan.add(
        TextSpan(
          text: displayText,
          style: spanStyle,
          recognizer: attributedText.onTap != null
              ? (TapGestureRecognizer()
                  ..onTap = () {
                    attributedText.onTap!(
                      attributedText.underlyingText ??
                          text.substring(
                            attributedText.start,
                            attributedText.end,
                          ),
                    );
                  })
              : null,
        ),
      );
      start = attributedText.end;
    }

    // Validate final substring
    if (start <= text.length && start >= 0) {
      textSpan.add(
        TextSpan(
          text: text.substring(start),
          style: TextStyle(
            color: colorPalette.textSecondary,
            fontWeight: typography.body?.regular?.fontWeight,
            fontSize: typography.body?.regular?.fontSize,
            fontFamily: typography.body?.regular?.fontFamily,
          ).merge(textStyle),
        ),
      );
    }

    return textSpan;
  }

  /// Truncates a URL for display in conversation subtitles.
  ///
  /// URLs longer than [maxLength] characters are shortened to show the domain
  /// and a truncated path (e.g., "https://example.com/very/long/path" becomes
  /// "example.com/very/...").
  static String _truncateUrlForConversation(String text, {int maxLength = 25}) {
    // Check if this looks like a URL
    final urlRegex = RegExp(r'^https?://[^\s]+$', caseSensitive: false);
    if (!urlRegex.hasMatch(text)) {
      return text; // Not a URL, return as-is
    }

    if (text.length <= maxLength) {
      return text;
    }

    try {
      final uri = Uri.parse(text);
      final domain = uri.host;
      final path = uri.path;

      // Remove www. prefix for cleaner display
      final cleanDomain = domain.startsWith('www.')
          ? domain.substring(4)
          : domain;

      // If just the domain fits, show domain + truncated path
      if (cleanDomain.length < maxLength - 3) {
        final remainingLength =
            maxLength - cleanDomain.length - 3; // -3 for "..."
        if (path.isNotEmpty && remainingLength > 0) {
          final truncatedPath = path.length > remainingLength
              ? '${path.substring(0, remainingLength)}...'
              : path;
          return '$cleanDomain$truncatedPath';
        }
        return '$cleanDomain...';
      }

      // Domain itself is too long, truncate it
      return '${cleanDomain.substring(0, maxLength - 3)}...';
    } catch (e) {
      // If URL parsing fails, just truncate the raw text
      return '${text.substring(0, maxLength - 3)}...';
    }
  }

  /// Builds the content widget for an AttributedText
  /// For block elements with underlyingText, applies inline formatters to the content
  static Widget _buildAttributedTextContent({
    required AttributedText attributedText,
    required String originalText,
    required List<CometChatTextFormatter>? formatters,
    required BuildContext context,
    required BubbleAlignment? alignment,
    required bool forConversation,
    required TextStyle? textStyle,
    required CometChatColorPalette colorPalette,
    required CometChatTypography typography,
  }) {
    final displayText =
        attributedText.underlyingText ??
        (attributedText.start >= 0 &&
                attributedText.end <= originalText.length &&
                attributedText.start <= attributedText.end
            ? originalText.substring(attributedText.start, attributedText.end)
            : '');

    final defaultStyle =
        attributedText.style ??
        TextStyle(
          color: alignment == BubbleAlignment.right
              ? colorPalette.white
              : colorPalette.textPrimary,
          fontWeight: typography.body?.regular?.fontWeight,
          fontSize: typography.body?.regular?.fontSize,
          fontFamily: typography.body?.regular?.fontFamily,
        ).merge(textStyle);

    // If this is a block element with underlyingText, apply inline formatters
    if (attributedText.isBlockElement &&
        attributedText.underlyingText != null &&
        formatters != null) {
      // Filter to only inline formatters (not block-level like blockquote, code block)
      final inlineFormatters = formatters.where((f) {
        // Skip block-level formatters to avoid infinite recursion
        final pattern = f.pattern?.pattern ?? '';
        return !pattern.contains(r'^>') && // blockquote
            !pattern.contains(r'^```') && // code block
            !pattern.contains(r'^- ') && // bullet list
            !pattern.contains(r'^\d+\.'); // ordered list
      }).toList();

      if (inlineFormatters.isNotEmpty) {
        // Apply inline formatters to the underlying text
        List<AttributedText> inlineAttrs = [];
        for (final formatter in inlineFormatters) {
          inlineAttrs = formatter.getAttributedText(
            displayText,
            context,
            alignment,
            existingAttributes: inlineAttrs,
            forConversation: forConversation,
          );
        }

        if (inlineAttrs.isNotEmpty) {
          // Build RichText with inline formatting
          return RichText(
            text: TextSpan(
              style: defaultStyle,
              children: _buildInlineSpansFromAttrs(
                displayText,
                inlineAttrs,
                defaultStyle,
              ),
            ),
          );
        }
      }
    }

    // Default: plain text
    return Text(displayText, style: defaultStyle);
  }

  /// Builds inline spans from a list of AttributedText
  static List<InlineSpan> _buildInlineSpansFromAttrs(
    String text,
    List<AttributedText> attrs,
    TextStyle defaultStyle,
  ) {
    final List<InlineSpan> spans = [];
    attrs.sort((a, b) => a.start.compareTo(b.start));

    int currentPos = 0;
    for (final attr in attrs) {
      if (attr.start < 0 || attr.end > text.length || attr.start > attr.end) {
        continue;
      }

      // Add text before this attributed segment
      if (currentPos < attr.start) {
        spans.add(
          TextSpan(
            text: text.substring(currentPos, attr.start),
            style: defaultStyle,
          ),
        );
      }

      // Add the attributed segment
      final segmentText =
          attr.underlyingText ?? text.substring(attr.start, attr.end);
      spans.add(TextSpan(text: segmentText, style: attr.style ?? defaultStyle));

      currentPos = attr.end;
    }

    // Add remaining text
    if (currentPos < text.length) {
      spans.add(
        TextSpan(text: text.substring(currentPos), style: defaultStyle),
      );
    }

    return spans;
  }
}
