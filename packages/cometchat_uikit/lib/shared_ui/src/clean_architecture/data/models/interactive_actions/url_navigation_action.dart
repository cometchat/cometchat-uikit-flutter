import '../../../../../cometchat_uikit_shared.dart'
    show ActionTypeConstants, ModelFieldConstants;
import 'action_entity.dart';

/// Represents an action for URL navigation within a chat application.
///
/// This action is used to handle URL navigation actions, specifying the target URL to navigate to.
/// It inherits the common 'actionType' property from the [ActionEntity] class.
class URLNavigationAction extends ActionEntity {
  String url;

  URLNavigationAction({required this.url, String? type})
    : super(actionType: type ?? ActionTypeConstants.urlNavigation);

  @override
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = super.toMap();
    map['url'] = url;
    return map;
  }

  factory URLNavigationAction.fromMap(dynamic map) {
    return URLNavigationAction(
      url: map['url'],
      // toMap writes `actionType`; reading `type` here meant a round trip
      // silently reset the field to the default.
      type: map[ModelFieldConstants.actionType] ?? map['type'],
    );
  }
}
