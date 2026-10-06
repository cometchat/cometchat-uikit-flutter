import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
// Redundant from gpt_markdown 1.2, which re-exports it. 1.1.x, still allowed
// by our ^1.1.2 constraint, does not provide what this file uses without it.
// ignore: unnecessary_import
import 'package:gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../cometchat_uikit_shared.dart';

class CometChatAiAssistantTableBuilder extends StatefulWidget {
  final List<CustomTableRow> tableRows;
  final GptMarkdownConfig? config;
  final CometChatTypography? typography;
  final CometChatColorPalette? colorPalette;
  final CometChatSpacing? spacing;

  const CometChatAiAssistantTableBuilder({
    super.key,
    required this.tableRows,
    this.config,
    this.typography,
    this.colorPalette,
    this.spacing,
  });

  @override
  State<CometChatAiAssistantTableBuilder> createState() =>
      _CometChatAiAssistantTableBuilderState();
}

class _CometChatAiAssistantTableBuilderState
    extends State<CometChatAiAssistantTableBuilder> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _containsMarkdown(String text) {
    final markdownRegex = RegExp(
      r'((?<!\*)\*[^*]+\*(?!\*)|_.*?_|\~\~.*?\~\~|\`.*?\`|\[.*?\]\(.*?\)|\!?\[.*?\]\(.*?\)|^(\s*[-*+] |\d+\.)|:[a-z_]+:)',
      multiLine: true,
      caseSensitive: false,
    );
    return markdownRegex.hasMatch(text);
  }

  String _stripMarkdownLinks(String text) {
    final linkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    return text.replaceAllMapped(linkRegex, (match) => match.group(1) ?? '');
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _isBoldMarkdown(String text) {
    final boldRegex = RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)');
    return boldRegex.hasMatch(text);
  }

  String _stripBoldMarkdown(String text) {
    return text.replaceAll(RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'), r'$1');
  }

  Widget _buildCell(
    BuildContext context,
    String text,
    bool isHeader,
    TextAlign align, {
    double? maxWidth,
  }) {
    text = text.trim();
    Widget content;

    final containsMarkdown = _containsMarkdown(text);
    final isBoldMarkdown = _isBoldMarkdown(text);
    final strippedText = _stripBoldMarkdown(text);

    if (containsMarkdown && !isBoldMarkdown) {
      final linkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
      final matches = linkRegex.allMatches(text);

      if (matches.isNotEmpty) {
        final List<InlineSpan> spans = [];
        int lastEnd = 0;

        for (final match in matches) {
          if (match.start > lastEnd) {
            spans.add(
              TextSpan(
                text: text.substring(lastEnd, match.start),
                style: TextStyle(
                  fontSize: widget.typography?.caption1?.regular?.fontSize,
                  fontWeight: isHeader
                      ? widget.typography?.caption1?.medium?.fontWeight
                      : widget.typography?.caption1?.regular?.fontWeight,
                  color: isHeader
                      ? widget.colorPalette?.textPrimary
                      : widget.colorPalette?.textSecondary,
                ),
              ),
            );
          }

          final linkText = match.group(1) ?? '';
          final linkUrl = match.group(2) ?? '';
          spans.add(
            WidgetSpan(
              child: GestureDetector(
                onTap: () => _launchUrl(linkUrl),
                child: Text(
                  linkText,
                  style: TextStyle(
                    color: widget.colorPalette?.textHighlight,
                    decoration: TextDecoration.underline,
                    fontSize: widget.typography?.caption1?.medium?.fontSize,
                    fontWeight: widget.typography?.caption1?.medium?.fontWeight,
                  ),
                ),
              ),
            ),
          );

          lastEnd = match.end;
        }

        if (lastEnd < text.length) {
          spans.add(
            TextSpan(
              text: text.substring(lastEnd),
              style: TextStyle(
                fontSize: widget.typography?.caption1?.regular?.fontSize,
                fontWeight: isHeader
                    ? widget.typography?.caption1?.medium?.fontWeight
                    : widget.typography?.caption1?.regular?.fontWeight,
                color: isHeader
                    ? widget.colorPalette?.textPrimary
                    : widget.colorPalette?.textSecondary,
              ),
            ),
          );
        }

        content = RichText(
          text: TextSpan(children: spans),
          textAlign: align,
        );
      } else {
        final cleanedText = _stripMarkdownLinks(text);
        // gpt_markdown 1.3.0 deprecates MdWidget in favour of GptMarkdown. It stays
        // until 2.0.0, which our ^1.1.2 constraint excludes; migrate when the
        // package's floor moves to 1.3.0.
        // ignore: deprecated_member_use
        content = MdWidget(
          context,
          cleanedText,
          false,
          config: widget.config ?? const GptMarkdownConfig(),
        );
      }
    } else {
      content = Text(
        strippedText,
        style: TextStyle(
          fontSize: widget.typography?.caption1?.medium?.fontSize,
          fontWeight: isBoldMarkdown
              ? widget.typography?.caption1?.medium?.fontWeight
              : (isHeader
                    ? widget.typography?.caption1?.medium?.fontWeight
                    : widget.typography?.caption1?.regular?.fontWeight),
          color: isBoldMarkdown
              ? widget.colorPalette?.textPrimary ??
                    widget.colorPalette?.textSecondary
              : (isHeader
                    ? widget.colorPalette?.textPrimary
                    : widget.colorPalette?.textSecondary),
        ),
        textAlign: align,
        softWrap: true,
      );
    }

    content = Padding(
      padding: EdgeInsets.only(
        top: isHeader
            ? (widget.spacing?.padding2 ?? 2)
            : (widget.spacing?.padding3 ?? 8),
        bottom: isHeader
            ? (widget.spacing?.padding2 ?? 2)
            : (widget.spacing?.padding3 ?? 8),
        left: widget.spacing?.padding2 ?? 6,
        right: widget.spacing?.padding2 ?? 6,
      ),
      child: content,
    );

    switch (align) {
      case TextAlign.center:
        content = Center(child: content);
        break;
      case TextAlign.right:
        content = Align(alignment: Alignment.centerRight, child: content);
        break;
      case TextAlign.left:
      default:
        content = Align(alignment: Alignment.centerLeft, child: content);
        break;
    }

    if (maxWidth != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      );
    }

    return content;
  }

  List<double> _calculateColumnWidths(BuildContext context) {
    final List<double> colWidths = [];
    final textStyle = widget.typography?.caption1?.medium ?? const TextStyle();

    for (int col = 0; col < widget.tableRows.first.fields.length; col++) {
      double maxWidth = 0;
      for (final row in widget.tableRows) {
        final cellText = row.fields[col].data;
        final TextPainter tp = TextPainter(
          text: TextSpan(text: cellText, style: textStyle),
          maxLines: null,
          textDirection: widget.config?.textDirection ?? TextDirection.ltr,
        )..layout(minWidth: 0, maxWidth: double.infinity);

        if (tp.width > maxWidth) maxWidth = tp.width;
      }
      colWidths.add(maxWidth + 16);
    }

    return colWidths;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tableRows.isEmpty) return const SizedBox();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final colCount = widget.tableRows.first.fields.length;
    final maxColumnWidth = screenWidth / colCount;
    final colWidths = _calculateColumnWidths(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.colorPalette?.borderDark ?? Colors.grey,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(widget.spacing?.radius3 ?? 12),
      ),
      clipBehavior: Clip.hardEdge,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.spacing?.radius3 ?? 12),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          thickness: 3,
          radius: Radius.circular(widget.spacing?.radiusMax ?? 0),
          interactive: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Table(
              columnWidths: {
                for (int i = 0; i < colCount; i++)
                  i: FixedColumnWidth(colWidths[i].clamp(0, maxColumnWidth)),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder.symmetric(
                inside: BorderSide(
                  color: widget.colorPalette?.borderDark ?? Colors.grey,
                  width: 1,
                ),
              ),
              children: widget.tableRows.map((row) {
                return TableRow(
                  decoration: row.isHeader
                      ? BoxDecoration(
                          color: widget.colorPalette?.background4,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(
                              widget.spacing?.radius3 ?? 12,
                            ),
                            topRight: Radius.circular(
                              widget.spacing?.radius3 ?? 12,
                            ),
                          ),
                        )
                      : BoxDecoration(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(
                              widget.spacing?.radius3 ?? 12,
                            ),
                            bottomRight: Radius.circular(
                              widget.spacing?.radius3 ?? 12,
                            ),
                          ),
                        ),
                  children: row.fields.map((field) {
                    return _buildCell(
                      context,
                      field.data,
                      row.isHeader,
                      field.alignment,
                      maxWidth: maxColumnWidth,
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
