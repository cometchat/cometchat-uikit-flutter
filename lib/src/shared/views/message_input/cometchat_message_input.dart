import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class CometChatMessageInput extends StatefulWidget {
  const CometChatMessageInput({
    Key? key,
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
  }) : super(key: key);

  ///[text] initial text for the input field
  final String? text;

  ///[placeholderText] hint text for input field
  final String? placeholderText;

  ///[onChange] callback to handle change in value of text in the input field
  final Function(String)? onChange;

  ///[style] provides style to this widget
  final MessageInputStyle? style;

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


  @override
  State<CometChatMessageInput> createState() => _CometChatMessageInputState();
}

class _CometChatMessageInputState extends State<CometChatMessageInput> {
  late TextEditingController _textEditingController;
  late CometChatTheme _theme;

  @override
  void initState() {
    super.initState();
    if (widget.textEditingController != null) {
      _textEditingController = widget.textEditingController!;
    } else {
      _textEditingController = TextEditingController(text: widget.text);
    }

    _theme = cometChatTheme;
  }

  @override
  void dispose() {
    if (widget.textEditingController == null) {
      _textEditingController.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CometChatMessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && widget.text != null) {
      _textEditingController.text = widget.text ?? '';
      _textEditingController.selection =
          TextSelection.collapsed(offset: _textEditingController.text.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: widget.style?.border,
        borderRadius: BorderRadius.all(
            Radius.circular(widget.style?.borderRadius ?? 8.0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(left: 12.0, right: 12),
            decoration: BoxDecoration(
                color: widget.style?.gradient == null
                    ? widget.style?.background
                    : null,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(widget.style?.borderRadius ?? 8),
                    topRight: Radius.circular(widget.style?.borderRadius ?? 8)),
                gradient: widget.style?.gradient),
            child: TextFormField(
              keyboardAppearance: _theme.palette.mode==PaletteThemeModes.light?Brightness.light:Brightness.dark,
              style:  TextStyle(
                      color: _theme.palette.getAccent600(),
                      fontSize: _theme.typography.body.fontSize,
                      fontWeight: _theme.typography.body.fontWeight,
                      fontFamily: _theme.typography.body.fontFamily).merge(widget.style?.textStyle) 
                 ,
              onChanged: widget.onChange,
              controller: _textEditingController,
              minLines: 1,
              maxLines: widget.maxLine ?? 4,
              decoration: InputDecoration(
                hintText:
                    widget.placeholderText ?? Translations.of(context).enter_your_message_here,
                hintStyle: TextStyle(
                              color: _theme.palette.getAccent600(),
                              fontSize: _theme.typography.body.fontSize,
                              fontFamily: _theme.typography.body.fontFamily,
                              fontWeight: _theme.typography.body.fontWeight,
                            ).merge(widget.style?.placeholderTextStyle),
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
            ),
          ),
          Divider(height: 1, color: widget.style?.dividerTint),
          Container(
            height: 40,
            padding: const EdgeInsets.only(left: 10.0, right: 10),
            decoration: BoxDecoration(
                color: widget.style?.gradient == null
                    ? widget.style?.background
                    : null,
                gradient: widget.style?.gradient,
                borderRadius: BorderRadius.only(
                    bottomLeft:
                        Radius.circular(widget.style?.borderRadius ?? 8),
                    bottomRight:
                        Radius.circular(widget.style?.borderRadius ?? 8))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                //-----show add to chat bottom sheet-----
                if (widget.secondaryButtonView != null)
                  widget.secondaryButtonView!,

                if (widget.auxiliaryButtonsAlignment ==
                        AuxiliaryButtonsAlignment.left &&
                    widget.auxiliaryButtonView != null)
                  widget.auxiliaryButtonView!,

                const Spacer(),

                //-----show auxilary buttons -----
                if (widget.auxiliaryButtonsAlignment ==
                        AuxiliaryButtonsAlignment.right &&
                    widget.auxiliaryButtonView != null)
                  widget.auxiliaryButtonView!,

                //  -----show send button-----
                if (widget.primaryButtonView != null) widget.primaryButtonView!,
              ],
            ),
          )
        ],
      ),
    );
  }
}
