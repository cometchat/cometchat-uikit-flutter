import '../../../../../../cometchat_uikit_shared.dart';
import 'package:flutter/material.dart';

/// A Flutter widget for creating a single select element with multiple options.
class CometChatSingleSelect extends StatefulWidget {
  const CometChatSingleSelect({
    super.key,
    required this.options,
    this.selectedValue,
    this.onChanged,
    this.optionBackground,
    this.selectedOptionBackground,
    this.optionTextStyle,
    this.selectedOptionsTextStyle,
    this.decoration,
  });

  /// A list of options to display for selection.
  final List<OptionElement> options;

  /// The currently selected value from the list of options.
  final String? selectedValue;

  /// A callback function called when the selection changes.
  final ValueChanged<String>? onChanged;

  /// Text style for the selected option.
  final TextStyle? selectedOptionsTextStyle;

  /// Text style for the options.
  final TextStyle? optionTextStyle;

  /// Background color for the selected option.
  final Color? selectedOptionBackground;

  /// Background color for the options.
  final Color? optionBackground;

  /// Custom decoration for the widget.
  final Decoration? decoration;

  @override
  State<CometChatSingleSelect> createState() => _CometChatSingleSelectState();
}

class _CometChatSingleSelectState extends State<CometChatSingleSelect> {
  late String? selectedValue;

  @override
  void initState() {
    super.initState();
    selectedValue = widget.selectedValue;
  }

  @override
  Widget build(BuildContext context) {
    final lessThanThreeOptions = widget.options.length < 3;
    Widget wrapping;
    if (lessThanThreeOptions) {
      wrapping = Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(widget.options.length, (index) {
          final option = widget.options[index];
          return Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: index > 0
                    ? const Border(left: BorderSide(width: 1))
                    : null,
              ),
              // The button used to sit inside a Row(mainAxisSize: max), which
              // lays a non-flex child out with unbounded width — so the label
              // never wrapped and the row overflowed by up to 157px at 200%
              // text scale. The Expanded above already gives this slot a tight
              // width; handing it straight to the button is what lets the text
              // wrap. ENG-39112.
              child: CometChatSingleSelectButton(
                selectedOptionsTextStyle: widget.selectedOptionsTextStyle,
                optionBackground: widget.optionBackground,
                optionTextStyle: widget.optionTextStyle,
                selectedOptionBackground: widget.selectedOptionBackground,
                selected: selectedValue == option.value,
                label: option.label,
                onSelected: () {
                  setState(() {
                    selectedValue = option.value;
                  });
                  if (widget.onChanged != null) {
                    widget.onChanged!(option.value);
                  }
                },
              ),
            ),
          );
        }),
      );
    } else {
      wrapping = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(widget.options.length, (index) {
          final option = widget.options[index];
          return DecoratedBox(
            decoration: BoxDecoration(
              border: index > 0
                  ? const Border(left: BorderSide(width: 1))
                  : null,
            ),
            child: CometChatSingleSelectButton(
              selected: selectedValue == option.value,
              label: option.label,
              onSelected: () {
                setState(() {
                  selectedValue = option.value;
                });
                if (widget.onChanged != null) {
                  widget.onChanged!(option.value);
                }
              },
            ),
          );
        }),
      );
    }

    return Container(decoration: widget.decoration, child: wrapping);
  }
}

class CometChatSingleSelectButton extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onSelected;
  final TextStyle? selectedOptionsTextStyle;
  final TextStyle? optionTextStyle;
  final Color? selectedOptionBackground;
  final Color? optionBackground;

  const CometChatSingleSelectButton({
    super.key,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.optionBackground,
    this.selectedOptionBackground,
    this.optionTextStyle,
    this.selectedOptionsTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    const selectedTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    const optionTextStyle = TextStyle(
      fontWeight: FontWeight.normal,
      color: Colors.black,
    );

    final TextStyle containerTextStyle = selected
        ? (selectedOptionsTextStyle ?? selectedTextStyle)
        : (optionTextStyle);

    return GestureDetector(
      onTap: onSelected,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        // A Wrap sized this label to its own intrinsic width, so a long option
        // at a large text scale ran past the slot instead of wrapping inside
        // it. ENG-39112.
        child: Text(
          label,
          style: containerTextStyle,
          textAlign: TextAlign.center,
          softWrap: true,
        ),
      ),
    );
  }
}
