import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../../../cometchat_uikit_shared.dart';
import '../no_intrinsic_card_wrapper.dart';

/// Renders a completed AI assistant message with full markdown support.
///
/// Supports code blocks, tables, links, and highlighted text via [GptMarkdown].
/// When [message] has non-empty `getElements()`, renders the ordered blocks
/// (text → GptMarkdown, card → CometChatCardView) inline. Falls back to
/// the existing `getText()` → GptMarkdown render when elements is empty/null.
class CometChatAIAssistantBubble extends StatelessWidget {
  const CometChatAIAssistantBubble({
    super.key,
    this.text,
    this.message,
    this.style,
    this.width,
    this.height,
    this.alignment,
  });

  final String? text;
  final AIAssistantMessage? message;
  final CometChatAIAssistantBubbleStyle? style;
  final double? width;
  final double? height;
  final BubbleAlignment? alignment;

  @override
  Widget build(BuildContext context) {
    final aiAssistantBubbleStyle =
        CometChatThemeHelper.getTheme<CometChatAIAssistantBubbleStyle>(
          context: context,
          defaultTheme: CometChatAIAssistantBubbleStyle.of,
        ).merge(style);

    final typography = CometChatThemeHelper.getTypography(context);
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final spacing = CometChatThemeHelper.getSpacing(context);

    // Check for elements — if present, render blocks in order
    final elements = message?.getElements();
    final hasElements = elements != null && elements.isNotEmpty;

    // Fallback text content (used when elements is empty/null)
    final String contentText = message?.text ?? text ?? '';

    return Container(
      height: height,
      width: width ?? MediaQuery.sizeOf(context).width * 0.7,
      decoration: BoxDecoration(
        border: aiAssistantBubbleStyle.border,
        borderRadius: aiAssistantBubbleStyle.borderRadius ?? BorderRadius.zero,
        color:
            aiAssistantBubbleStyle.backgroundColor ?? colorPalette.transparent,
      ),
      padding: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.0058),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasElements)
            ..._buildElementBlocks(
              context,
              elements,
              colorPalette,
              typography,
              spacing,
              aiAssistantBubbleStyle,
            )
          else
            _buildTextContent(
              context,
              contentText,
              colorPalette,
              typography,
              spacing,
              aiAssistantBubbleStyle,
            ),
          // Copy button at bottom-left (only for text content)
          if (!hasElements && contentText.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: spacing.padding2 ?? 8),
              child: Semantics(
                button: true,
                label: Translations.of(context).copy,
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: contentText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: colorPalette.background3,
                        content: Text(
                          'Copied to clipboard',
                          style: TextStyle(color: colorPalette.textPrimary),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.content_copy_rounded,
                    size: 18,
                    color: colorPalette.iconSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Renders the ordered element blocks from getElements().
  /// - "text" → GptMarkdown
  /// - "card" → CometChatCardView
  /// - other → skip (future-proofed)
  List<Widget> _buildElementBlocks(
    BuildContext context,
    List<AIAssistantElement> elements,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
    CometChatAIAssistantBubbleStyle aiAssistantBubbleStyle,
  ) {
    final List<Widget> widgets = [];

    for (final element in elements) {
      final type = element.getType();
      final data = element.getData();

      switch (type) {
        case 'text':
          // Render text block through existing GptMarkdown
          final textContent = data?.toString() ?? '';
          if (textContent.isNotEmpty) {
            widgets.add(
              _buildTextContent(
                context,
                textContent,
                colorPalette,
                typography,
                spacing,
                aiAssistantBubbleStyle,
              ),
            );
          }
          break;

        case 'card':
          // Render card block via CometChatCardView
          if (data is Map<String, dynamic> && data['card'] != null) {
            final cardData = data['card'];
            final cardJson = jsonEncode(cardData);
            final resolvedThemeMode =
                Theme.of(context).brightness == Brightness.dark
                ? CometChatCardThemeMode.dark
                : CometChatCardThemeMode.light;
            final cardWidth = MediaQuery.sizeOf(context).width * 0.65;

            // Wrap in _NoIntrinsicSizeWidget to prevent IntrinsicWidth
            // from querying LayoutBuilder inside CometChatCardView
            widgets.add(
              Padding(
                padding: EdgeInsets.symmetric(vertical: spacing.padding2 ?? 4),
                child: NoIntrinsicCardWrapper(
                  width: cardWidth,
                  child: CometChatCardView(
                    cardJson: cardJson,
                    themeMode: resolvedThemeMode,
                    onAction: (CometChatCardActionEvent action) {
                      // Agent card: emit event only (no prop path for nested cards)
                      if (message != null) {
                        CometChatUIEvents.ccCardActionClicked(message!, action);
                      }
                    },
                  ),
                ),
              ),
            );
          }
          break;

        default:
          // Future element types — skip gracefully
          break;
      }
    }

    return widgets;
  }

  /// Builds the existing GptMarkdown text rendering.
  Widget _buildTextContent(
    BuildContext context,
    String contentText,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
    CometChatAIAssistantBubbleStyle aiAssistantBubbleStyle,
  ) {
    return NoIntrinsicScroll(
      child: GptMarkdownTheme(
        gptThemeData: GptMarkdownThemeData(
          brightness: Theme.of(context).brightness,
          highlightColor: colorPalette.background4,
          h3: TextStyle(
            color: colorPalette.textPrimary,
            fontWeight: typography.body?.bold?.fontWeight,
            fontSize: typography.body?.bold?.fontSize,
            fontFamily: typography.body?.bold?.fontFamily,
          ),
        ),
        child: GptMarkdown(
          contentText,
          style:
              TextStyle(
                    color: colorPalette.textPrimary,
                    fontWeight: typography.body?.regular?.fontWeight,
                    fontSize: typography.body?.regular?.fontSize,
                    fontFamily: typography.body?.regular?.fontFamily,
                  )
                  .merge(aiAssistantBubbleStyle.textStyle)
                  .copyWith(color: aiAssistantBubbleStyle.textColor),
          codeBuilder: (context, name, code, closed) {
            return NoIntrinsicScroll(
              child: CometChatAiAssistantCodeBlock(
                language: name,
                codes: code,
                colorPalette: colorPalette,
                spacing: spacing,
                typography: typography,
              ),
            );
          },
          tableBuilder: (context, tableRows, textStyle, config) {
            return NoIntrinsicScroll(
              child: CometChatAiAssistantTableBuilder(
                tableRows: tableRows,
                colorPalette: colorPalette,
                spacing: spacing,
                typography: typography,
                config: config,
              ),
            );
          },
          // `inlineCodeBuilder` only exists from gpt_markdown 1.2; our ^1.1.2 still
          // resolves 1.1.x, where this is the only option. Removed in 2.0.
          // ignore: deprecated_member_use
          highlightBuilder: (context, text, style) {
            return CometchatHighlightBuilder(
              text: text,
              style: style,
              typography: typography,
              spacing: spacing,
              colorPalette: colorPalette,
            );
          },
          // gpt_markdown 1.3.0 deprecates linkBuilder in favour of inlineLinkBuilder,
          // which only exists from 1.3.0. linkBuilder stays until 2.0.0, which our
          // ^1.1.2 constraint excludes; migrate when the package's floor moves to 1.3.0.
          // ignore: deprecated_member_use
          linkBuilder: (context, text, url, style) {
            return CometchatLinkBuilder(
              text: text,
              url: url,
              style: style,
              typography: typography,
              spacing: spacing,
              colorPalette: colorPalette,
            );
          },
        ),
      ),
    );
  }
}
