import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../../shared_ui/cometchat_uikit_shared.dart';
import '../../../../../../shared_ui/src/rich_text_formatting/domain/entities/format_type.dart';
import 'rich_text_editing_controller.dart';
import 'segment_composer_controller.dart';

// ════════════════════════════════════════════════════════════════════════════════
// SEGMENT COMPOSER WIDGET
// ════════════════════════════════════════════════════════════════════════════════

/// A widget that renders segment-based rich text composition.
///
/// Displays a list of segments (normal text and code blocks) with independent
/// text fields for each segment. Code blocks have a distinct visual style
/// with dark background and monospace font.
class SegmentComposerWidget extends StatefulWidget {
  final SegmentComposerController controller;
  final String placeholder;
  final CometChatColorPalette? colorPalette;
  final CometChatSpacing? spacing;
  final CometChatTypography? typography;
  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;
  final double maxHeight;
  final ValueChanged<String>? onChange;
  final ValueChanged<KeyboardInsertedContent>? onContentInserted;

  /// Pastes a clipboard image (returns true when handled). See
  /// [CometChatMessageInput.onPasteImage].
  final Future<bool> Function()? onPasteImage;

  const SegmentComposerWidget({
    super.key,
    required this.controller,
    this.placeholder = 'Message',
    this.colorPalette,
    this.spacing,
    this.typography,
    this.textStyle,
    this.placeholderStyle,
    this.maxHeight = 320,
    this.onChange,
    this.onContentInserted,
    this.onPasteImage,
  });

  @override
  State<SegmentComposerWidget> createState() => _SegmentComposerWidgetState();
}

class _SegmentComposerWidgetState extends State<SegmentComposerWidget> {
  @override
  void initState() {
    super.initState();
    // After each rebuild triggered by the controller, check for pending focus
    widget.controller.addListener(_handlePendingFocus);
  }

  @override
  void didUpdateWidget(covariant SegmentComposerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handlePendingFocus);
      widget.controller.addListener(_handlePendingFocus);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handlePendingFocus);
    super.dispose();
  }

  void _handlePendingFocus() {
    // Schedule focus request after the frame so the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = widget.controller.consumePendingFocus();
      if (target != null) {
        target.focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        widget.colorPalette ?? CometChatThemeHelper.getColorPalette(context);
    final space = widget.spacing ?? CometChatThemeHelper.getSpacing(context);
    final typo =
        widget.typography ?? CometChatThemeHelper.getTypography(context);

    // Check if there are any code blocks
    final hasCodeBlocks = widget.controller.segments.any(
      (s) => s.type == SegmentType.code,
    );
    final segmentCount = widget.controller.segments.length;

    // Check if any segment has pending focus (needs to be visible even if empty)
    final pendingFocusId = widget.controller.pendingFocusSegmentId;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.controller.segments.asMap().entries.map((entry) {
            final index = entry.key;
            final segment = entry.value;

            if (segment.type == SegmentType.normal) {
              final isEmpty = segment.controller.text.isEmpty;
              final isOnlySegment = segmentCount == 1;
              final hasFocus = segment.focusNode.hasFocus;
              final isPendingFocus = segment.id == pendingFocusId;

              // Don't hide if this segment is about to receive focus
              if (isEmpty &&
                  hasCodeBlocks &&
                  !isOnlySegment &&
                  !hasFocus &&
                  !isPendingFocus) {
                return SizedBox.shrink(key: ValueKey('${segment.id}_hidden'));
              }

              final showPlaceholder =
                  (index == 0 && !hasCodeBlocks) || isOnlySegment;

              return _NormalSegmentWidget(
                key: ValueKey(segment.id),
                segment: segment,
                controller: widget.controller,
                placeholder: showPlaceholder ? widget.placeholder : null,
                colorPalette: palette,
                spacing: space,
                typography: typo,
                textStyle: widget.textStyle,
                placeholderStyle: widget.placeholderStyle,
                onChange: widget.onChange,
                onContentInserted: widget.onContentInserted,
                onPasteImage: widget.onPasteImage,
              );
            } else {
              return _CodeSegmentWidget(
                key: ValueKey(segment.id),
                segment: segment,
                controller: widget.controller,
                colorPalette: palette,
                spacing: space,
                typography: typo,
              );
            }
          }).toList(),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// NORMAL SEGMENT WIDGET
// ════════════════════════════════════════════════════════════════════════════════

/// Widget for rendering a normal text segment.
class _NormalSegmentWidget extends StatefulWidget {
  final ComposerSegment segment;
  final SegmentComposerController controller;
  final String? placeholder;
  final CometChatColorPalette colorPalette;
  final CometChatSpacing spacing;
  final CometChatTypography typography;
  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;
  final ValueChanged<String>? onChange;
  final ValueChanged<KeyboardInsertedContent>? onContentInserted;
  final Future<bool> Function()? onPasteImage;

  const _NormalSegmentWidget({
    super.key,
    required this.segment,
    required this.controller,
    this.placeholder,
    required this.colorPalette,
    required this.spacing,
    required this.typography,
    this.textStyle,
    this.placeholderStyle,
    this.onChange,
    this.onContentInserted,
    this.onPasteImage,
  });

  @override
  State<_NormalSegmentWidget> createState() => _NormalSegmentWidgetState();
}

class _NormalSegmentWidgetState extends State<_NormalSegmentWidget> {
  /// URL pattern for detecting pasted URLs
  static final RegExp _urlPattern = RegExp(
    r'^https?://\S+$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    widget.segment.focusNode.onKeyEvent = _handleKeyEvent;
  }

  @override
  void didUpdateWidget(covariant _NormalSegmentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segment != widget.segment) {
      widget.segment.focusNode.onKeyEvent = _handleKeyEvent;
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (widget.segment.controller.text.isEmpty) {
        final handled = widget.controller.handleBackspaceOnEmptyNormalSegment();
        if (handled) return KeyEventResult.handled;
      }
    }

    // Intercept Cmd+V / Ctrl+V for image paste, then paste-URL-on-selection.
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      final isModifierPressed =
          HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isControlPressed;
      if (isModifierPressed) {
        final controller = widget.segment.controller;

        // Image paste first — stage a clipboard image if one is present. Since
        // the key handler must return synchronously, we claim the event and do
        // the async work, falling back to the existing text-paste behaviour.
        if (widget.onPasteImage != null) {
          final selection = controller.selection;
          widget.onPasteImage!().then((handledImage) {
            if (handledImage) return;
            if (controller is RichTextEditingController &&
                selection.isValid &&
                !selection.isCollapsed) {
              _tryPasteAsLink(controller, selection).then((handled) {
                if (!handled) _performDefaultPaste(controller, selection);
              });
            } else {
              final safe = selection.isValid
                  ? selection
                  : TextSelection.collapsed(offset: controller.text.length);
              _performDefaultPaste(controller, safe);
            }
          });
          return KeyEventResult.handled;
        }

        if (controller is RichTextEditingController) {
          final selection = controller.selection;
          if (selection.isValid && !selection.isCollapsed) {
            // Text is selected — check clipboard async, handle if URL
            _tryPasteAsLink(controller, selection).then((handled) {
              if (!handled) {
                // Not a URL — perform default paste
                _performDefaultPaste(controller, selection);
              }
            });
            return KeyEventResult.handled;
          }
        }
      }
    }

    return KeyEventResult.ignored;
  }

  /// Attempt to handle paste as a link-on-selection.
  /// If clipboard contains a URL, applies link formatting to the selected text.
  /// Skips link formatting if the selection is inside inline code.
  /// Returns true if link formatting was applied, false if caller should do normal paste.
  Future<bool> _tryPasteAsLink(
    RichTextEditingController controller,
    TextSelection selection,
  ) async {
    if (!selection.isValid || selection.isCollapsed) return false;

    // Skip link formatting if selection is inside inline code
    final formatsAtSelection = controller.spanManager.getFormatsAt(
      selection.start,
    );
    if (formatsAtSelection.contains(FormatType.inlineCode)) return false;

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = clipboardData?.text?.trim() ?? '';

    if (clipboardText.isNotEmpty && _urlPattern.hasMatch(clipboardText)) {
      // Apply link formatting: selected text becomes display text, URL is the link
      final selectedText = controller.text.substring(
        selection.start,
        selection.end,
      );
      controller.applyLinkFormat(selectedText, clipboardText);
      return true;
    }
    return false;
  }

  /// Perform a default paste operation (replace selection with clipboard text).
  /// Used as fallback when Cmd+V is intercepted but clipboard is not a URL.
  Future<void> _performDefaultPaste(
    TextEditingController controller,
    TextSelection selection,
  ) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = clipboardData?.text ?? '';
    if (clipboardText.isEmpty) return;

    final newText =
        controller.text.substring(0, selection.start) +
        clipboardText +
        controller.text.substring(selection.end);
    final newCursor = selection.start + clipboardText.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  /// Invoked by the TextField's `onTap` callback. Schedules a post-frame
  /// link-at-cursor check on the segment's [RichTextEditingController].
  /// The controller's selection-change listener does not reliably fire on
  /// iOS when the user taps an unfocused field, so we use the tap callback
  /// as a more reliable trigger on both platforms.
  void _handleTap() {
    final controller = widget.segment.controller;
    if (controller is! RichTextEditingController) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.checkLinkAtCursor();
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.segment.controller,
      focusNode: widget.segment.focusNode,
      textCapitalization: TextCapitalization.sentences,
      keyboardAppearance: CometChatThemeHelper.getBrightness(context),
      cursorColor: widget.colorPalette.primary ?? Colors.blue,
      scrollPhysics: const ClampingScrollPhysics(),
      contentInsertionConfiguration: widget.onContentInserted != null
          ? ContentInsertionConfiguration(
              allowedMimeTypes: const [
                'image/gif',
                'image/png',
                'image/jpeg',
                'image/webp',
              ],
              onContentInserted: widget.onContentInserted!,
            )
          : null,
      maxLines: null,
      minLines: 1,
      onChanged: widget.onChange,
      onTap: _handleTap,
      contextMenuBuilder: _buildContextMenu,
      style:
          widget.textStyle ??
          TextStyle(
            fontSize: widget.typography.body?.regular?.fontSize ?? 15,
            color: widget.colorPalette.textPrimary,
            height: 1.4,
          ),
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle:
            widget.placeholderStyle ??
            TextStyle(
              color: widget.colorPalette.textTertiary,
              fontSize: widget.typography.body?.regular?.fontSize ?? 15,
            ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          vertical: widget.spacing.padding1 ?? 4,
        ),
      ),
    );
  }

  /// Custom context menu that intercepts Paste to apply link formatting
  /// when text is selected and clipboard contains a URL.
  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final buttonItems = editableTextState.contextMenuButtonItems;
    final controller = widget.segment.controller;

    // Wrap the paste button: try a clipboard image first (staged into the
    // tray), then the link-on-selection behaviour (rich controller only), then
    // the normal text paste. Image paste applies to every controller type, so
    // we no longer early-return for plain controllers.
    final updatedItems = buttonItems.map((item) {
      if (item.type == ContextMenuButtonType.paste) {
        return ContextMenuButtonItem(
          label: item.label,
          type: item.type,
          onPressed: () async {
            editableTextState.hideToolbar();

            if (widget.onPasteImage != null && await widget.onPasteImage!()) {
              return;
            }

            final selection = controller.selection;
            if (controller is RichTextEditingController &&
                selection.isValid &&
                !selection.isCollapsed) {
              final handled = await _tryPasteAsLink(controller, selection);
              if (handled) return;
            }
            unawaited(
              editableTextState.pasteText(SelectionChangedCause.toolbar),
            );
          },
        );
      }
      return item;
    }).toList();

    // Flutter gates the Paste button on ClipboardStatus (Clipboard.hasStrings),
    // so an image-only clipboard yields no Paste item to wrap — the image hook
    // above would never fire and no Paste showed at all (notably on iOS). Add
    // one when the host wants image paste; label stays null so it localises.
    if (widget.onPasteImage != null &&
        !updatedItems.any((i) => i.type == ContextMenuButtonType.paste)) {
      updatedItems.add(
        ContextMenuButtonItem(
          type: ContextMenuButtonType.paste,
          onPressed: () async {
            editableTextState.hideToolbar();
            if (await widget.onPasteImage!()) return;
            unawaited(
              editableTextState.pasteText(SelectionChangedCause.toolbar),
            );
          },
        ),
      );
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: updatedItems,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// CODE SEGMENT WIDGET
// ════════════════════════════════════════════════════════════════════════════════

/// Widget for rendering a code block segment.
///
/// Features:
/// - Dark background with monospace font
/// - Grows with content (starts as 1 line)
/// - Backspace on empty removes the code block
/// - Triple-Enter exits code block mode
class _CodeSegmentWidget extends StatefulWidget {
  final ComposerSegment segment;
  final SegmentComposerController controller;
  final CometChatColorPalette colorPalette;
  final CometChatSpacing spacing;
  final CometChatTypography typography;

  const _CodeSegmentWidget({
    super.key,
    required this.segment,
    required this.controller,
    required this.colorPalette,
    required this.spacing,
    required this.typography,
  });

  @override
  State<_CodeSegmentWidget> createState() => _CodeSegmentWidgetState();
}

class _CodeSegmentWidgetState extends State<_CodeSegmentWidget> {
  /// URL pattern for detecting pasted URLs
  static final RegExp _urlPattern = RegExp(
    r'^https?://\S+$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Only handle key down events
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Check for backspace on empty code block
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (widget.segment.controller.text.isEmpty) {
        // Remove the empty code block
        widget.controller.handleBackspaceOnEmptyCodeBlock();
        return KeyEventResult.handled;
      }
    }

    // Intercept Cmd+V / Ctrl+V for paste-URL-on-selection in code block
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      final isModifierPressed =
          HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isControlPressed;
      if (isModifierPressed) {
        final controller = widget.segment.controller;
        final selection = controller.selection;
        if (selection.isValid && !selection.isCollapsed) {
          _tryPasteAsRawLink(controller, selection).then((handled) {
            if (!handled) {
              _performDefaultPaste(controller, selection);
            }
          });
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  /// In a code block, paste URL on selected text as raw markdown `[text](url)`.
  /// The send bubble will render this as a clickable link.
  /// Returns true if handled, false for normal paste.
  Future<bool> _tryPasteAsRawLink(
    TextEditingController controller,
    TextSelection selection,
  ) async {
    if (!selection.isValid || selection.isCollapsed) return false;

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = clipboardData?.text?.trim() ?? '';

    if (clipboardText.isNotEmpty && _urlPattern.hasMatch(clipboardText)) {
      final selectedText = controller.text.substring(
        selection.start,
        selection.end,
      );
      final linkMarkdown = '[$selectedText]($clipboardText)';
      final newText =
          controller.text.substring(0, selection.start) +
          linkMarkdown +
          controller.text.substring(selection.end);
      final newCursor = selection.start + linkMarkdown.length;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
      return true;
    }
    return false;
  }

  /// Perform a default paste operation.
  Future<void> _performDefaultPaste(
    TextEditingController controller,
    TextSelection selection,
  ) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = clipboardData?.text ?? '';
    if (clipboardText.isEmpty) return;

    final newText =
        controller.text.substring(0, selection.start) +
        clipboardText +
        controller.text.substring(selection.end);
    final newCursor = selection.start + clipboardText.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  /// Custom context menu for code block — intercepts Paste for URL-on-selection.
  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final buttonItems = editableTextState.contextMenuButtonItems;
    final controller = widget.segment.controller;

    final updatedItems = buttonItems.map((item) {
      if (item.type == ContextMenuButtonType.paste) {
        return ContextMenuButtonItem(
          label: item.label,
          type: item.type,
          onPressed: () {
            editableTextState.hideToolbar();
            final selection = controller.selection;
            if (selection.isValid && !selection.isCollapsed) {
              _tryPasteAsRawLink(controller, selection).then((handled) {
                if (!handled) {
                  editableTextState.pasteText(SelectionChangedCause.toolbar);
                }
              });
            } else {
              editableTextState.pasteText(SelectionChangedCause.toolbar);
            }
          },
        );
      }
      return item;
    }).toList();

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: updatedItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    final codeBackgroundColor =
        widget.colorPalette.background3 ?? const Color(0xFF2A2D31);
    final borderColor =
        widget.colorPalette.borderDark ?? const Color(0xFF565856);
    final textColor =
        widget.colorPalette.textPrimary ?? const Color(0xFFD1D2D3);

    // Set up key event handler on the focus node
    widget.segment.focusNode.onKeyEvent = _handleKeyEvent;

    return Container(
      margin: EdgeInsets.symmetric(vertical: widget.spacing.padding1 ?? 4),
      decoration: BoxDecoration(
        color: codeBackgroundColor,
        borderRadius: BorderRadius.circular(widget.spacing.radius1 ?? 5),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: TextField(
        controller: widget.segment.controller,
        focusNode: widget.segment.focusNode,
        maxLines: null,
        minLines: 1,
        contextMenuBuilder: _buildContextMenu,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: textColor,
          height: 1.4,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: widget.spacing.padding2 ?? 8,
            vertical: widget.spacing.padding2 ?? 8,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// CODE BLOCK BUTTON
// ════════════════════════════════════════════════════════════════════════════════

/// A custom button widget for inserting code blocks.
/// Displays {|} icon similar to Slack's code block button.
class CodeBlockButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color? iconColor;
  final double? iconSize;

  const CodeBlockButton({
    super.key,
    required this.onTap,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? const Color(0xFF9B9EA4);
    final size = iconSize ?? 14.0;

    return Tooltip(
      message: 'Code block',
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '{',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: size,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Container(
                width: 2,
                height: size * 0.8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: color,
              ),
              Text(
                '}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: size,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
