import 'dart:async';
import 'package:flutter/material.dart';
import "../../../../clean_architecture.dart";

///[CometChatMessageInput] is a component that provides a skeleton layout for contents of [CometChatMessageComposer] like TextField, auxiliary options, primary button view and attachment options.
///
/// Two layout modes are supported, controlled by [layout]:
///
/// * [CometChatComposerLayout.singleLine] (default) — single-row inline layout:
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │ [+] │ Type your message...          │ [😊] [🎤] [✨] │ [➤] │
/// └─────────────────────────────────────────────────────────────┘
///   Sec    Text Input                      Auxiliary      Send
/// ```
///
/// * [CometChatComposerLayout.doubleLine] — classic v5 two-row layout: text
///   field on its own row, buttons on a second row below a divider:
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │ Type your message...                                        │
/// ├─────────────────────────────────────────────────────────────┤
/// │ [+] [🎤]                              [😊] [✨]      [➤]   │
/// └─────────────────────────────────────────────────────────────┘
/// ```
///
/// ```dart
///   CometChatMessageInput(
///    placeholderText: "some placeholder",
///    primaryButtonView: Container(),
///    secondaryButtonView: GestureDetector(
///      onTap: () {},
///      child: Container(),
///    ),
///    auxiliaryButtonView: Row(
///      children: <Widget>[],
///    ),
///    auxiliaryButtonsAlignment: AuxiliaryButtonsAlignment.right,
///    layout: CometChatComposerLayout.doubleLine,
///  );
/// ```
class CometChatMessageInput extends StatefulWidget {
  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Callback for an Enter key press.
  @Deprecated(
    'Has no effect. Enter inserts a new line, as on the other UI Kits; messages are sent with the send button. Will be removed in 7.0.0.',
  )
  final bool Function(String text, TextSelection selection)? onEnterPressed;

  const CometChatMessageInput({
    super.key,
    this.text,
    this.placeholderText,
    this.onChange,
    this.style,
    this.maxLine,
    this.secondaryButtonView,
    this.auxiliaryButtonView,
    this.primaryButtonView,
    this.auxiliaryButtonsAlignment = AuxiliaryButtonsAlignment.right,
    this.textEditingController,
    this.focusNode,
    this.hideBottomView,
    this.padding,
    this.margin,
    this.height,
    this.width,
    this.showCodeBlockIndicator = false,
    this.codeBlockIndicatorColor,
    this.codeBlockContent,
    this.onContentInserted,
    this.onPasteImage,
    this.onTap,
    this.layout = CometChatComposerLayout.singleLine,
    this.onEnterPressed,
  });

  ///[text] initial text for the input field
  final String? text;

  ///[placeholderText] hint text for input field
  final String? placeholderText;

  ///[onChange] callback to handle change in value of text in the input field
  final Function(String val)? onChange;

  ///[style] provides style to this widget
  final CometChatMessageInputStyle? style;

  ///[maxLine] maximum lines allowed to increase in the input field
  final int? maxLine;

  ///[secondaryButtonView] additional ui component apart from primary
  final Widget? secondaryButtonView;

  ///[auxiliaryButtonView] additional ui component apart from primary and secondary
  final Widget? auxiliaryButtonView;

  ///[primaryButtonView] is a ui component that would trigger basic functionality
  final Widget? primaryButtonView;

  ///[auxiliaryButtonsAlignment] controls position auxiliary button view
  final AuxiliaryButtonsAlignment? auxiliaryButtonsAlignment;

  ///[textEditingController] provides control of the input field
  final TextEditingController? textEditingController;

  ///[focusNode] allows to dismiss platform and CometChat UI elements
  final FocusNode? focusNode;

  ///[hideBottomView] hide the bottom toolbar for message input
  final bool? hideBottomView;

  ///[height] defines the height of the widget
  final double? height;

  ///[width] defines the width of the widget
  final double? width;

  ///[padding] defines the padding of the widget
  final EdgeInsetsGeometry? padding;

  ///[margin] defines the margin of the widget
  final EdgeInsetsGeometry? margin;

  ///[showCodeBlockIndicator] shows a Slack-style left accent bar when true
  ///Used to indicate code block formatting in the input
  final bool showCodeBlockIndicator;

  ///[codeBlockIndicatorColor] color for the code block indicator bar
  final Color? codeBlockIndicatorColor;

  ///[codeBlockContent] the extracted code content without backticks
  ///When provided, displays this instead of raw text with backticks
  final String? codeBlockContent;

  ///[onContentInserted] callback when keyboard inserts media content (e.g. GIF)
  final ValueChanged<KeyboardInsertedContent>? onContentInserted;

  ///[onPasteImage] pastes an image from the system clipboard. Returns true when
  ///an image was found and handled (so the default text paste is suppressed),
  ///false when the clipboard held no image (normal text paste proceeds).
  final Future<bool> Function()? onPasteImage;

  ///[onTap] callback invoked when the text field is tapped. Used by the
  ///composer to detect taps on link-formatted spans on iOS, where the
  ///selection-change listener does not reliably fire on the first tap.
  final VoidCallback? onTap;

  ///[layout] controls the skeleton layout of the input.
  ///
  /// Defaults to [CometChatComposerLayout.singleLine] — the text field and all
  /// buttons share a single row.
  ///
  /// Pass [CometChatComposerLayout.doubleLine] for the classic v5 layout where
  /// the text field occupies its own row and the buttons sit on a second row
  /// below a divider.
  final CometChatComposerLayout layout;

  @override
  State<CometChatMessageInput> createState() => _CometChatMessageInputState();
}

class _CometChatMessageInputState extends State<CometChatMessageInput> {
  TextEditingController? _textEditingController;
  bool _isOwnController = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (widget.textEditingController != null) {
      _textEditingController = widget.textEditingController;
      _isOwnController = false;
    } else {
      // In code-block mode the extracted content (without the backticks) is
      // what the field should hold.
      _textEditingController = TextEditingController(
        text: widget.showCodeBlockIndicator
            ? (widget.codeBlockContent ?? widget.text)
            : widget.text,
      );
      _isOwnController = true;
    }
  }

  @override
  void dispose() {
    if (_isOwnController) {
      _textEditingController?.dispose();
    }
    _textEditingController = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CometChatMessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle controller change
    if (widget.textEditingController != oldWidget.textEditingController) {
      if (_isOwnController) {
        _textEditingController?.dispose();
      }
      _initController();
    } else if (widget.text != oldWidget.text &&
        widget.text != null &&
        _textEditingController != null) {
      // Only update text if controller hasn't changed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _textEditingController != null) {
          _textEditingController!.text = widget.text ?? '';
          _textEditingController!.selection = TextSelection.collapsed(
            offset: _textEditingController!.text.length,
          );
        }
      });
    }

    // Update style if changed
    if (widget.style != oldWidget.style && widget.style != null) {
      messageInputStyle =
          CometChatThemeHelper.getTheme<CometChatMessageInputStyle>(
            context: context,
            defaultTheme: CometChatMessageInputStyle.of,
          ).merge(widget.style);
    }
  }

  late CometChatMessageInputStyle messageInputStyle;
  late CometChatColorPalette colorPalette;
  late CometChatSpacing spacing;
  late CometChatTypography typography;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only initialize theme once to avoid expensive lookups during keyboard animation
    // But re-initialize when brightness changes (dark mode toggle)
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (_themeInitialized && !brightnessChanged) return;
    _cachedBrightness = currentBrightness;
    _themeInitialized = true;

    messageInputStyle =
        CometChatThemeHelper.getTheme<CometChatMessageInputStyle>(
          context: context,
          defaultTheme: CometChatMessageInputStyle.of,
        ).merge(widget.style);
    colorPalette = CometChatThemeHelper.getColorPalette(context);
    spacing = CometChatThemeHelper.getSpacing(context);
    typography = CometChatThemeHelper.getTypography(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDoubleLine = widget.layout == CometChatComposerLayout.doubleLine;
    return Container(
      height: widget.height,
      width: widget.width,
      margin: widget.margin,
      // Figma spec (double-line): outer padding = 0; single-line keeps 16h inline padding.
      padding:
          widget.padding ??
          (isDoubleLine
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 16)),
      decoration: BoxDecoration(
        color: messageInputStyle.backgroundColor,
        border: messageInputStyle.border,
        borderRadius:
            messageInputStyle.borderRadius ??
            BorderRadius.circular(spacing.radius2 ?? 0),
      ),
      child: isDoubleLine ? _buildDoubleLineLayout() : _buildSingleLineLayout(),
    );
  }

  /// Default single-row layout: secondary buttons | input | auxiliary | send.
  Widget _buildSingleLineLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Secondary buttons (left side - attachment button)
        if (widget.secondaryButtonView != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: widget.secondaryButtonView!,
          ),

        // Auxiliary buttons (left alignment option)
        if (widget.auxiliaryButtonsAlignment ==
                AuxiliaryButtonsAlignment.left &&
            widget.auxiliaryButtonView != null &&
            widget.hideBottomView != true)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: widget.auxiliaryButtonView!,
          ),

        // Text input (center, expanded)
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.padding2 ?? 8,
              vertical: 12,
            ),
            child: _textEditingController != null
                ? _buildRegularInput()
                : const SizedBox.shrink(),
          ),
        ),

        // Auxiliary buttons (right alignment - default)
        if (widget.auxiliaryButtonsAlignment ==
                AuxiliaryButtonsAlignment.right &&
            widget.auxiliaryButtonView != null &&
            widget.hideBottomView != true)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: widget.auxiliaryButtonView!,
          ),

        // Primary/Send button (far right)
        if (widget.primaryButtonView != null && widget.hideBottomView != true)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 12, bottom: 12),
            child: widget.primaryButtonView!,
          ),
      ],
    );
  }

  /// Classic v5 two-row layout: text field on row 1, buttons on row 2.
  ///
  /// Matches v5 spacing exactly:
  /// - Input row: `padding3` horizontal, no vertical (TextField's intrinsic padding provides height)
  /// - Toolbar row: `padding3` horizontal, `padding2` vertical
  /// - Icon cluster spacing: `margin4` between adjacent icons
  Widget _buildDoubleLineLayout() {
    final horizontalPadding = spacing.padding3 ?? 12.0;
    final toolbarVerticalPadding = spacing.padding2 ?? 8.0;
    final clusterIconGap = spacing.margin4 ?? 4.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end, // justify-content: flex-end
      crossAxisAlignment: CrossAxisAlignment.stretch, // align-self: stretch
      children: [
        // ── Row 1: Text input (horizontal padding only, like v5) ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: _textEditingController != null
              ? _buildRegularInput()
              : const SizedBox.shrink(),
        ),

        // ── Divider ──
        if (widget.hideBottomView != true)
          Divider(
            height: messageInputStyle.dividerHeight ?? 1,
            thickness: messageInputStyle.dividerHeight ?? 1,
            color: messageInputStyle.dividerTint,
            indent: horizontalPadding,
            endIndent: horizontalPadding,
          ),

        // ── Row 2: Button toolbar ──
        if (widget.hideBottomView != true)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: toolbarVerticalPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT cluster: secondary buttons + (optionally) left-aligned auxiliary
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.secondaryButtonView != null)
                        widget.secondaryButtonView!,
                      if (widget.auxiliaryButtonsAlignment ==
                              AuxiliaryButtonsAlignment.left &&
                          widget.auxiliaryButtonView != null)
                        Padding(
                          padding: EdgeInsets.only(
                            left: widget.secondaryButtonView != null
                                ? clusterIconGap
                                : 0,
                          ),
                          child: widget.auxiliaryButtonView!,
                        ),
                    ],
                  ),
                ),

                // RIGHT cluster: right-aligned auxiliary + primary (send)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.auxiliaryButtonsAlignment ==
                              AuxiliaryButtonsAlignment.right &&
                          widget.auxiliaryButtonView != null)
                        widget.auxiliaryButtonView!,
                      if (widget.primaryButtonView != null)
                        Padding(
                          padding: EdgeInsets.only(left: clusterIconGap),
                          child: widget.primaryButtonView!,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Context menu that adds image-paste to the standard toolbar: tapping
  /// "Paste" first tries to stage a clipboard image; if there's none it falls
  /// back to the normal text paste, so text paste is unaffected.
  Widget _buildPasteContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final items = editableTextState.contextMenuButtonItems.map((item) {
      if (item.type == ContextMenuButtonType.paste &&
          widget.onPasteImage != null) {
        return ContextMenuButtonItem(
          label: item.label,
          type: item.type,
          onPressed: () async {
            editableTextState.hideToolbar();
            final handled = await widget.onPasteImage!();
            if (!handled) {
              unawaited(
                editableTextState.pasteText(SelectionChangedCause.toolbar),
              );
            }
          },
        );
      }
      return item;
    }).toList();

    // Flutter only offers Paste when the clipboard holds TEXT — the button is
    // gated on ClipboardStatus, which comes from Clipboard.hasStrings(). With
    // an image-only clipboard there is no Paste item to wrap, so the hook above
    // could never fire and the toolbar showed no Paste at all (most visibly on
    // iOS, which is strict about clipboard access). Add our own when the host
    // wants image paste; the label is left null so the toolbar localises it.
    if (widget.onPasteImage != null &&
        !items.any((i) => i.type == ContextMenuButtonType.paste)) {
      items.add(
        ContextMenuButtonItem(
          type: ContextMenuButtonType.paste,
          onPressed: () async {
            editableTextState.hideToolbar();
            final handled = await widget.onPasteImage!();
            // Nothing on the clipboard we can stage — fall back to text paste,
            // which is a no-op when there are no strings either.
            if (!handled) {
              unawaited(
                editableTextState.pasteText(SelectionChangedCause.toolbar),
              );
            }
          },
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  /// Builds the regular text input field
  Widget _buildRegularInput() {
    // Check if we're in code block mode (WYSIWYG)
    // Show code block visual even when text is empty (codeBlockContent can be null or empty string)
    if (widget.showCodeBlockIndicator) {
      return _buildCodeBlockInput();
    }

    // In double-line mode, use Flutter's default Material input density so the
    // TextField has its natural ~48dp intrinsic height (matches v5). In
    // single-line mode, keep the dense decoration because the outer Row owns
    // vertical sizing.
    final isDoubleLine = widget.layout == CometChatComposerLayout.doubleLine;

    // Regular text input
    return TextFormField(
      key: ValueKey(_textEditingController.hashCode),
      textCapitalization: TextCapitalization.sentences,
      textAlignVertical: TextAlignVertical.center,
      keyboardAppearance: CometChatThemeHelper.getBrightness(context),
      cursorColor: colorPalette.primary ?? Colors.blue,
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
      style:
          TextStyle(
                color: colorPalette.textPrimary,
                fontSize: typography.body?.regular?.fontSize,
                fontWeight: typography.body?.regular?.fontWeight,
                fontFamily: typography.body?.regular?.fontFamily,
              )
              .merge(messageInputStyle.textStyle)
              .copyWith(color: messageInputStyle.textColor),
      onChanged: widget.onChange,
      onTap: widget.onTap,
      controller: _textEditingController,
      contextMenuBuilder: _buildPasteContextMenu,
      minLines: 1,
      maxLines: widget.maxLine ?? 4,
      decoration: InputDecoration(
        filled: messageInputStyle.filledColor != null,
        fillColor: messageInputStyle.filledColor,
        isDense: !isDoubleLine,
        contentPadding: isDoubleLine
            ? null
            : EdgeInsets.symmetric(vertical: spacing.padding1 ?? 4),
        hintText:
            widget.placeholderText ?? Translations.of(context).typeYourMessage,
        hintStyle:
            TextStyle(
                  color: colorPalette.textTertiary,
                  fontSize: typography.body?.regular?.fontSize,
                  fontWeight: typography.body?.regular?.fontWeight,
                  fontFamily: typography.body?.regular?.fontFamily,
                )
                .merge(messageInputStyle.placeholderTextStyle)
                .copyWith(color: messageInputStyle.placeholderColor),
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
      ),
      focusNode: widget.focusNode,
    );
  }

  /// Builds the code block styled input field
  /// Shows a dark container with monospace font, scrollable for long content
  Widget _buildCodeBlockInput() {
    // Use theme colors for code block
    final codeBackgroundColor =
        colorPalette.background3 ?? const Color(0xFF1E1E1E);
    // The caller-supplied indicator colour outlines the code block; the
    // composer already passes one.
    final borderColor =
        widget.codeBlockIndicatorColor ??
        colorPalette.borderDark ??
        const Color(0xFF404040);
    final textColor = colorPalette.textPrimary ?? Colors.white;
    final hintColor = colorPalette.textTertiary ?? Colors.grey;

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 200, // Max height before scrolling
      ),
      decoration: BoxDecoration(
        color: codeBackgroundColor,
        borderRadius: BorderRadius.circular(spacing.radius2 ?? 8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.padding3 ?? 12),
        child: TextFormField(
          key: ValueKey('codeblock_${_textEditingController.hashCode}'),
          textCapitalization: TextCapitalization.none,
          keyboardAppearance: CometChatThemeHelper.getBrightness(context),
          style: TextStyle(
            color: textColor,
            fontSize: typography.body?.regular?.fontSize ?? 14,
            fontWeight: FontWeight.w400,
            fontFamily: 'monospace',
            height: 1.5,
          ),
          onChanged: widget.onChange,
          controller: _textEditingController,
          minLines: 1,
          maxLines: null, // Allow unlimited lines, container handles scrolling
          decoration: InputDecoration(
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            hintText: widget.placeholderText ?? 'Enter code...',
            hintStyle: TextStyle(
              color: hintColor,
              fontSize: typography.body?.regular?.fontSize ?? 14,
              fontWeight: FontWeight.w400,
              fontFamily: 'monospace',
            ),
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
          ),
          focusNode: widget.focusNode,
        ),
      ),
    );
  }
}
