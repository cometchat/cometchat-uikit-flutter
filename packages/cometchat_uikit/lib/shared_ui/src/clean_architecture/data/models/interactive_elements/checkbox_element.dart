import '../../../../../cometchat_uikit_shared.dart'
    show UIElementTypeConstants, ModelFieldConstants;
import 'base_input_element.dart';
import 'option_element.dart';

/// Represents a checkbox model class , used to draw checkbox .
class CheckBoxElement extends BaseInputElement<List<String>> {
  CheckBoxElement({
    super.elementType = UIElementTypeConstants.checkbox,
    required super.elementId,
    required this.label,
    required this.options,
    this.isChecked,
    super.defaultValue,
    List<String>? response,
    bool? optional,
  }) : super(optional: optional ?? true);

  String label;
  List<OptionElement> options;
  Map<String, bool>? isChecked;

  @override
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = super.toMap();
    map[ModelFieldConstants.optional] = optional;
    map[ModelFieldConstants.label] = label;
    map[ModelFieldConstants.options] = options
        .map((option) => option.toMap())
        .toList();
    return map;
  }

  factory CheckBoxElement.fromMap(dynamic map) {
    return CheckBoxElement(
      elementType: map[ModelFieldConstants.elementType],
      elementId: map[ModelFieldConstants.elementId],
      optional: map[ModelFieldConstants.optional] ?? true,
      label: map[ModelFieldConstants.label],
      defaultValue: map[ModelFieldConstants.defaultValue]
          ?.map<String>((e) => e.toString())
          .toList(),
      options: (map[ModelFieldConstants.options])
          .map<OptionElement>((optionMap) => OptionElement.fromMap(optionMap))
          .toList(),
    );
  }

  @override
  bool validateResponse() {
    if (response == null || response!.isEmpty) return false;
    return true;
  }
}

T? cast<T>(Object? x) => x is T ? x : null;
